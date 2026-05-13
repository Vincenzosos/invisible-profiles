// Conditional-Gaussian imputation for partial-coverage cohort rows.
//
// When a row provides fewer than the full 10 profiler variables, we
// score it by sampling M completed vectors from the empirical
// conditional distribution of the missing variables given the observed
// ones, classifying each draw against the country's K-means centroids,
// and returning the modal cluster plus its imputation-distribution
// probability. Rows with full coverage delegate to the deterministic
// matchProfile in profiler.ts.
//
// All math runs in z-space. Σ comes from src/data/imputation.json — a
// 10×10 correlation matrix per country. We ship with an identity
// placeholder; pipeline/v9/step_28_imputation_export.R writes the
// empirical Σ from SHARE Wave 9. Both shapes are consumed identically.

import imputationData from '../data/imputation.json';
import {
  euclidean,
  matchProfile,
  standardize,
  type CentroidsJson,
  type Country,
  type MatchResult,
  type ProfileMatch,
  type SoftMembership,
} from './profiler';

export const IMPUTATION_DRAWS = 100;
const RIDGE = 1e-6;

export type ImputationModel = typeof imputationData;

export type ImputationDistribution = {
  M: number;
  observedVars: string[];
  imputedVars: string[];
  topClusters: { name: string; probability: number; meanDistance: number }[];
};

export type MatchResultWithImputation = MatchResult & {
  imputation: ImputationDistribution;
  coverage: { observed: number; total: number };
};

// ---- linear algebra primitives --------------------------------------------

export function cholesky(A: number[][]): number[][] {
  const n = A.length;
  const L: number[][] = Array.from({ length: n }, () => new Array(n).fill(0));
  for (let i = 0; i < n; i++) {
    for (let j = 0; j <= i; j++) {
      let s = A[i][j];
      if (i === j) s += RIDGE;
      for (let k = 0; k < j; k++) s -= L[i][k] * L[j][k];
      if (i === j) {
        if (s <= 0) {
          throw new Error(`Cholesky: non-positive pivot (${s}) at i=${i}`);
        }
        L[i][j] = Math.sqrt(s);
      } else {
        L[i][j] = s / L[j][j];
      }
    }
  }
  return L;
}

export function solveLowerTri(L: number[][], b: number[]): number[] {
  const n = L.length;
  const y = new Array(n).fill(0);
  for (let i = 0; i < n; i++) {
    let s = b[i];
    for (let k = 0; k < i; k++) s -= L[i][k] * y[k];
    y[i] = s / L[i][i];
  }
  return y;
}

export function solveUpperTriT(L: number[][], y: number[]): number[] {
  // Solve L^T · x = y, where L is lower-triangular.
  const n = L.length;
  const x = new Array(n).fill(0);
  for (let i = n - 1; i >= 0; i--) {
    let s = y[i];
    for (let k = i + 1; k < n; k++) s -= L[k][i] * x[k];
    x[i] = s / L[i][i];
  }
  return x;
}

export function solveSPD(A: number[][], b: number[]): number[] {
  const L = cholesky(A);
  return solveUpperTriT(L, solveLowerTri(L, b));
}

export function solveSPDMatrix(A: number[][], B: number[][]): number[][] {
  // A · X = B, both column-major in nested-array form (B[i][j] is row i, col j).
  const L = cholesky(A);
  const rows = A.length;
  const cols = B[0]?.length ?? 0;
  const X: number[][] = Array.from({ length: rows }, () => new Array(cols).fill(0));
  for (let c = 0; c < cols; c++) {
    const col = new Array(rows);
    for (let r = 0; r < rows; r++) col[r] = B[r][c];
    const x = solveUpperTriT(L, solveLowerTri(L, col));
    for (let r = 0; r < rows; r++) X[r][c] = x[r];
  }
  return X;
}

export function sampleStandardNormal(n: number, rng: () => number = Math.random): number[] {
  // Box-Muller. Two outputs per pair of uniforms — pull in pairs.
  const out = new Array(n);
  let i = 0;
  while (i < n) {
    const u1 = Math.max(rng(), 1e-12);
    const u2 = rng();
    const r = Math.sqrt(-2 * Math.log(u1));
    const theta = 2 * Math.PI * u2;
    out[i++] = r * Math.cos(theta);
    if (i < n) out[i++] = r * Math.sin(theta);
  }
  return out;
}

// ---- conditional-Gaussian kernel ------------------------------------------

type ImputationKernel = {
  observedIdx: number[];
  missingIdx: number[];
  regressorMatrix: number[][]; // K such that μ_{M|O} = K · z_obs  (|M| × |O|)
  cholCondCov: number[][];     // L : L·L^T = Σ_{M|O}              (|M| × |M|)
};

const kernelCache = new Map<string, ImputationKernel>();

function sliceMatrix(A: number[][], rows: number[], cols: number[]): number[][] {
  const out: number[][] = new Array(rows.length);
  for (let i = 0; i < rows.length; i++) {
    const row = new Array(cols.length);
    const src = A[rows[i]];
    for (let j = 0; j < cols.length; j++) row[j] = src[cols[j]];
    out[i] = row;
  }
  return out;
}

export function precomputeKernel(
  country: Country,
  observedIdx: number[],
  missingIdx: number[],
  model: ImputationModel,
): ImputationKernel {
  const corr = country === 'italy' ? model.italy.corr : model.sweden.corr;
  const SOO = sliceMatrix(corr, observedIdx, observedIdx);
  const SOM = sliceMatrix(corr, observedIdx, missingIdx);   // |O| × |M|
  const SMM = sliceMatrix(corr, missingIdx, missingIdx);
  // K = Σ_{M,O} · Σ_{O,O}^{-1}  →  K^T = Σ_{O,O}^{-1} · Σ_{O,M}
  // Solve SOO · K^T = SOM  →  KT is |O| × |M|
  let KT: number[][];
  if (observedIdx.length === 0) {
    KT = [];
  } else {
    KT = solveSPDMatrix(SOO, SOM);
  }
  // K (|M| × |O|)
  const K: number[][] = Array.from({ length: missingIdx.length }, () =>
    new Array(observedIdx.length).fill(0),
  );
  for (let i = 0; i < observedIdx.length; i++) {
    for (let j = 0; j < missingIdx.length; j++) {
      K[j][i] = KT[i][j];
    }
  }
  // Σ_{M|O} = Σ_{M,M} − K · Σ_{O,M}
  const condCov: number[][] = Array.from({ length: missingIdx.length }, () =>
    new Array(missingIdx.length).fill(0),
  );
  for (let i = 0; i < missingIdx.length; i++) {
    for (let j = 0; j < missingIdx.length; j++) {
      let s = SMM[i][j];
      for (let k = 0; k < observedIdx.length; k++) s -= K[i][k] * SOM[k][j];
      condCov[i][j] = s;
    }
  }
  let L: number[][];
  try {
    L = cholesky(condCov);
  } catch (e) {
    console.warn('cholesky failed once, retrying with larger ridge', e);
    for (let i = 0; i < condCov.length; i++) condCov[i][i] += RIDGE * 100;
    L = cholesky(condCov);
  }
  return { observedIdx, missingIdx, regressorMatrix: K, cholCondCov: L };
}

function getKernel(
  country: Country,
  observedIdx: number[],
  missingIdx: number[],
): ImputationKernel {
  const key = country + ':' + observedIdx.join(',');
  let kernel = kernelCache.get(key);
  if (!kernel) {
    kernel = precomputeKernel(country, observedIdx, missingIdx, imputationData);
    kernelCache.set(key, kernel);
  }
  return kernel;
}

export function sampleConditional(
  zObs: number[],
  kernel: ImputationKernel,
  M: number,
  rng: () => number = Math.random,
): number[][] {
  const fullLen = kernel.observedIdx.length + kernel.missingIdx.length;
  // μ_cond = K · z_obs  (|M|-vector). Same for every draw.
  const muCond = new Array(kernel.missingIdx.length).fill(0);
  for (let i = 0; i < kernel.missingIdx.length; i++) {
    let s = 0;
    for (let j = 0; j < kernel.observedIdx.length; j++) {
      s += kernel.regressorMatrix[i][j] * zObs[j];
    }
    muCond[i] = s;
  }
  const out: number[][] = new Array(M);
  for (let m = 0; m < M; m++) {
    const y = sampleStandardNormal(kernel.missingIdx.length, rng);
    const zMiss = new Array(kernel.missingIdx.length).fill(0);
    for (let i = 0; i < kernel.missingIdx.length; i++) {
      let s = muCond[i];
      for (let k = 0; k <= i; k++) s += kernel.cholCondCov[i][k] * y[k];
      zMiss[i] = s;
    }
    const zFull = new Array(fullLen).fill(0);
    for (let i = 0; i < kernel.observedIdx.length; i++) {
      zFull[kernel.observedIdx[i]] = zObs[i];
    }
    for (let i = 0; i < kernel.missingIdx.length; i++) {
      zFull[kernel.missingIdx[i]] = zMiss[i];
    }
    out[m] = zFull;
  }
  return out;
}

// ---- top-level entry point ------------------------------------------------

function marginalStats(
  country: Country,
  data: CentroidsJson,
): Map<string, { mean: number; sd: number }> {
  const full = country === 'italy' ? data.italy_full : data.sweden_full;
  const stats = new Map<string, { mean: number; sd: number }>();
  for (const v of full.variables) stats.set(v.name, { mean: v.raw_mean, sd: v.raw_sd });
  return stats;
}

function twinFromCompletedVec(
  country: Country,
  observed: Record<string, number>,
  data: CentroidsJson,
): { name: string | null; distance: number | null } {
  // Build the conditional mean for the OTHER country and pick the closest centroid.
  const otherCountry: Country = country === 'italy' ? 'sweden' : 'italy';
  const varOrder = (otherCountry === 'italy' ? data.italy_subset : data.sweden_subset)
    .profiles[0].vars;
  const stats = marginalStats(otherCountry, data);
  const observedIdx: number[] = [];
  const missingIdx: number[] = [];
  const zObs: number[] = [];
  varOrder.forEach((v, i) => {
    const ans = observed[v];
    const s = stats.get(v);
    if (ans !== undefined && s) {
      observedIdx.push(i);
      zObs.push(standardize(ans, s.mean, s.sd));
    } else {
      missingIdx.push(i);
    }
  });
  const completed = new Array(varOrder.length).fill(0);
  if (missingIdx.length === 0) {
    observedIdx.forEach((i, k) => (completed[i] = zObs[k]));
  } else if (observedIdx.length === 0) {
    // All missing in other country too — zero vector (marginal mean in z-space).
  } else {
    const kernel = getKernel(otherCountry, observedIdx, missingIdx);
    observedIdx.forEach((i, k) => (completed[i] = zObs[k]));
    for (let i = 0; i < missingIdx.length; i++) {
      let s = 0;
      for (let j = 0; j < observedIdx.length; j++) s += kernel.regressorMatrix[i][j] * zObs[j];
      completed[missingIdx[i]] = s;
    }
  }
  const otherSubset = otherCountry === 'italy' ? data.italy_subset : data.sweden_subset;
  let best: { name: string; distance: number } | null = null;
  for (const p of otherSubset.profiles) {
    const d = euclidean(completed, p.center);
    if (!best || d < best.distance) best = { name: p.name, distance: d };
  }
  return best ? { name: best.name, distance: best.distance } : { name: null, distance: null };
}

export function matchProfileWithImputation(
  country: Country,
  observed: Record<string, number>,
  data: CentroidsJson,
  M: number = IMPUTATION_DRAWS,
): MatchResultWithImputation {
  const subset = country === 'italy' ? data.italy_subset : data.sweden_subset;
  const varOrder = subset.profiles[0].vars;
  const stats = marginalStats(country, data);

  const observedIdx: number[] = [];
  const missingIdx: number[] = [];
  const zObs: number[] = [];
  varOrder.forEach((v, i) => {
    const ans = observed[v];
    const s = stats.get(v);
    if (ans !== undefined && s) {
      observedIdx.push(i);
      zObs.push(standardize(ans, s.mean, s.sd));
    } else {
      missingIdx.push(i);
    }
  });

  // Full coverage: delegate to deterministic matchProfile and wrap.
  if (missingIdx.length === 0) {
    const inner = matchProfile(country, observed, data);
    return {
      ...inner,
      coverage: { observed: varOrder.length, total: varOrder.length },
      imputation: {
        M: 1,
        observedVars: varOrder.slice(),
        imputedVars: [],
        topClusters: [
          { name: inner.best.name, probability: 1, meanDistance: inner.best.distance },
        ],
      },
    };
  }

  const kernel = getKernel(country, observedIdx, missingIdx);
  const draws = sampleConditional(zObs, kernel, M);

  // Classify each draw, accumulate per-cluster count and distance sum.
  const counts = new Map<string, number>();
  const distSums = new Map<string, number>();
  for (const z of draws) {
    let bestName = '';
    let bestDist = Infinity;
    for (const p of subset.profiles) {
      const d = euclidean(z, p.center);
      if (d < bestDist) {
        bestDist = d;
        bestName = p.name;
      }
    }
    counts.set(bestName, (counts.get(bestName) ?? 0) + 1);
    distSums.set(bestName, (distSums.get(bestName) ?? 0) + bestDist);
  }
  const topClustersAll: { name: string; probability: number; meanDistance: number }[] = [];
  for (const p of subset.profiles) {
    const c = counts.get(p.name) ?? 0;
    if (c === 0) continue;
    topClustersAll.push({
      name: p.name,
      probability: c / M,
      meanDistance: (distSums.get(p.name) ?? 0) / c,
    });
  }
  topClustersAll.sort((a, b) => b.probability - a.probability);
  const topClusters = topClustersAll.slice(0, 5);

  const modal = topClustersAll[0];

  // Build zScores in the conventional shape: observed entries filled, missing set to 0.
  const zScores: Record<string, number> = {};
  for (const v of varOrder) zScores[v] = 0;
  observedIdx.forEach((i, k) => (zScores[varOrder[i]] = zObs[k]));

  const ranking: ProfileMatch[] = subset.profiles
    .map((p) => {
      const entry = topClustersAll.find((c) => c.name === p.name);
      // Profiles never selected by any draw don't have a mean distance from
      // imputation. Fall back to distance from the deterministic conditional-
      // mean completion — keeps ranking well-defined.
      let distance: number;
      if (entry) {
        distance = entry.meanDistance;
      } else {
        const completed = new Array(varOrder.length).fill(0);
        observedIdx.forEach((i, k) => (completed[i] = zObs[k]));
        for (let i = 0; i < missingIdx.length; i++) {
          let s = 0;
          for (let j = 0; j < observedIdx.length; j++) {
            s += kernel.regressorMatrix[i][j] * zObs[j];
          }
          completed[missingIdx[i]] = s;
        }
        distance = euclidean(completed, p.center);
      }
      return { name: p.name, distance, zScores };
    })
    .sort((a, b) => a.distance - b.distance);

  const membership: SoftMembership[] = topClustersAll.map((c) => ({
    name: c.name,
    probability: c.probability,
    distance: c.meanDistance,
  }));

  const twin = twinFromCompletedVec(country, observed, data);

  const best: ProfileMatch = {
    name: modal.name,
    distance: modal.meanDistance,
    zScores,
  };

  return {
    best,
    ranking,
    membership,
    twinName: twin.name,
    twinDistance: twin.distance,
    coverage: { observed: observedIdx.length, total: varOrder.length },
    imputation: {
      M,
      observedVars: observedIdx.map((i) => varOrder[i]),
      imputedVars: missingIdx.map((i) => varOrder[i]),
      topClusters,
    },
  };
}
