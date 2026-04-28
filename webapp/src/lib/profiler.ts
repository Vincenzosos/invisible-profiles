// Profiler engine for the Italian Silver Atlas webapp.
//
// Two outputs per quiz submission:
//   1. Hard match: closest K-means centroid (Euclidean distance in z-space).
//   2. Soft membership: softmax of negative squared distances, used as a
//      runtime equivalent of the LCA posterior. The canonical LCA fit lives
//      in the v9 R pipeline; this softmax view is the operational
//      approximation that the browser ships, documented in chapter 8.

import centroidsData from '../data/centroids.json';

export type CentroidsJson = typeof centroidsData;
export type Country = 'italy' | 'sweden';

export type ProfileMatch = {
  name: string;
  distance: number;
  zScores: Record<string, number>;
};

export type SoftMembership = {
  name: string;
  probability: number; // [0, 1]
  distance: number;
};

export type MatchResult = {
  best: ProfileMatch;
  ranking: ProfileMatch[];
  membership: SoftMembership[]; // sorted by probability desc
  twinName: string | null;       // closest profile in the OTHER country
  twinDistance: number | null;
};

export function standardize(raw: number, mean: number, sd: number): number {
  if (sd === 0) return 0;
  return (raw - mean) / sd;
}

export function euclidean(a: number[], b: number[]): number {
  const n = Math.min(a.length, b.length);
  let s = 0;
  for (let i = 0; i < n; i++) {
    const d = a[i] - b[i];
    s += d * d;
  }
  return Math.sqrt(s);
}

// Softmax with temperature: tau controls sharpness.
// Smaller tau -> harder assignment; larger tau -> softer.
// Empirically tau = 1 (squared-distance scale) gives ~K-means hard
// behaviour for well-separated profiles and informative softness for
// profiles near the decision boundary.
function softmaxNegSqDist(distances: number[], tau = 1.0): number[] {
  const negSq = distances.map((d) => -(d * d) / Math.max(tau, 1e-9));
  const m = Math.max(...negSq);
  const exps = negSq.map((x) => Math.exp(x - m));
  const z = exps.reduce((a, b) => a + b, 0);
  return exps.map((e) => e / z);
}

function buildUserVec(
  country: Country,
  answers: Record<string, number>,
  data: CentroidsJson,
): { userVec: number[]; varOrder: string[]; zScores: Record<string, number> } {
  const subset = country === 'italy' ? data.italy_subset : data.sweden_subset;
  const full = country === 'italy' ? data.italy_full : data.sweden_full;

  const stats = new Map<string, { mean: number; sd: number }>();
  for (const v of full.variables) {
    stats.set(v.name, { mean: v.raw_mean, sd: v.raw_sd });
  }

  const varOrder = subset.profiles[0].vars;
  const zScores: Record<string, number> = {};
  for (const v of varOrder) {
    const s = stats.get(v);
    const ans = answers[v];
    if (!s || ans === undefined) {
      zScores[v] = 0;
    } else {
      zScores[v] = standardize(ans, s.mean, s.sd);
    }
  }
  const userVec = varOrder.map((v) => zScores[v]);
  return { userVec, varOrder, zScores };
}

export function matchProfile(
  country: Country,
  answers: Record<string, number>,
  data: CentroidsJson,
): MatchResult {
  const subset = country === 'italy' ? data.italy_subset : data.sweden_subset;
  const { userVec, zScores } = buildUserVec(country, answers, data);

  const ranking: ProfileMatch[] = subset.profiles
    .map((p) => ({
      name: p.name,
      distance: euclidean(userVec, p.center),
      zScores,
    }))
    .sort((a, b) => a.distance - b.distance);

  // Soft membership distribution (softmax of negative squared distances)
  const probs = softmaxNegSqDist(ranking.map((r) => r.distance));
  const membership: SoftMembership[] = ranking
    .map((r, i) => ({
      name: r.name,
      probability: probs[i],
      distance: r.distance,
    }))
    .sort((a, b) => b.probability - a.probability);

  // Cross-country twin: closest profile in the OTHER country, computed on
  // the SAME 10-key-vars subset (so distances are comparable).
  const otherCountry: Country = country === 'italy' ? 'sweden' : 'italy';
  const otherSubset =
    otherCountry === 'italy' ? data.italy_subset : data.sweden_subset;
  // Re-standardise the user against the OTHER country's marginal distributions
  const { userVec: userVecOther } = buildUserVec(otherCountry, answers, data);
  const twinScores = otherSubset.profiles.map((p) => ({
    name: p.name,
    distance: euclidean(userVecOther, p.center),
  }));
  twinScores.sort((a, b) => a.distance - b.distance);
  const twin = twinScores[0] ?? null;

  return {
    best: ranking[0],
    ranking,
    membership,
    twinName: twin ? twin.name : null,
    twinDistance: twin ? twin.distance : null,
  };
}
