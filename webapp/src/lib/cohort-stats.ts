// Cohort-level statistics for the CSV scoring pipeline.
//
// Functions here are pure / deterministic — they take the scored rows
// and the SHARE benchmark distribution, and return the inputs for the
// analytics UI block (cohort-vs-benchmark bars, chi-square test,
// subgroup pivot).

import killer from '../data/killer_numbers.json';

export type ProfileShare = { name: string; share: number };

export function benchmarkShares(country: 'italy' | 'sweden'): ProfileShare[] {
  const profiles =
    country === 'italy' ? killer.italy_profiles : killer.sweden_profiles;
  return profiles.map((p) => ({
    name: p.profile,
    share: p.share_of_country_pct,           // 0–1 fraction (unweighted sample share)
  }));
}

// Distribution of the user's cohort — count + share per profile.
export function cohortDistribution(
  predictions: string[],
  benchmark: ProfileShare[],
): { name: string; n: number; share: number; benchmarkShare: number; deltaPp: number }[] {
  const total = predictions.length;
  const counts = new Map<string, number>();
  for (const p of predictions) counts.set(p, (counts.get(p) ?? 0) + 1);

  // Use the benchmark as the canonical profile order (so the rendered
  // bars are aligned with the Atlas ordering, not whatever order the
  // cohort happens to produce).
  return benchmark.map((b) => {
    const n = counts.get(b.name) ?? 0;
    const share = total === 0 ? 0 : n / total;
    return {
      name: b.name,
      n,
      share,
      benchmarkShare: b.share,
      deltaPp: (share - b.share) * 100,
    };
  });
}

// Pearson chi-square test of cohort distribution vs benchmark.
//   Observed   = cohort counts per profile
//   Expected   = total_n × benchmark_share
//   chi²       = sum( (O - E)² / E )
//   df         = k - 1
// Returns p-value via a chi-square survival approximation (Wilson–Hilferty).
export function chiSquareVsBenchmark(
  predictions: string[],
  benchmark: ProfileShare[],
): { chi2: number; df: number; p: number; n: number } {
  const total = predictions.length;
  const counts = new Map<string, number>();
  for (const p of predictions) counts.set(p, (counts.get(p) ?? 0) + 1);

  let chi2 = 0;
  let nonzeroExpected = 0;
  for (const b of benchmark) {
    const o = counts.get(b.name) ?? 0;
    const e = total * b.share;
    if (e <= 0) continue;
    nonzeroExpected++;
    chi2 += ((o - e) ** 2) / e;
  }
  const df = Math.max(1, nonzeroExpected - 1);
  const p = chiSquarePValue(chi2, df);
  return { chi2, df, p, n: total };
}

// Wilson–Hilferty approximation: for χ²_df, the variable
//   z = ((χ²/df)^(1/3) − (1 − 2/(9df))) / sqrt(2/(9df))
// is approximately standard normal. Adequate for df ≥ 1 and the
// reporting precision we need ("p < 0.001 / 0.01 / 0.05 / n.s.").
function chiSquarePValue(chi2: number, df: number): number {
  if (chi2 <= 0 || df <= 0) return 1;
  const t = chi2 / df;
  const a = 2 / (9 * df);
  const z = (Math.cbrt(t) - (1 - a)) / Math.sqrt(a);
  // Right-tail of the standard normal → 1 − Φ(z)
  return 1 - normalCdf(z);
}

function normalCdf(x: number): number {
  // Abramowitz & Stegun 26.2.17 approximation
  const sign = x < 0 ? -1 : 1;
  const ax = Math.abs(x) / Math.SQRT2;
  const t = 1 / (1 + 0.3275911 * ax);
  const y =
    1 -
    (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t -
      0.284496736) *
      t +
      0.254829592) *
      t *
      Math.exp(-ax * ax);
  return 0.5 * (1 + sign * y);
}

// Format a p-value into a publication-grade string.
export function formatPValue(p: number): string {
  if (p < 0.001) return 'p < 0.001';
  if (p < 0.01) return 'p < 0.01';
  if (p < 0.05) return `p = ${p.toFixed(3)}`;
  if (p < 0.1) return `p = ${p.toFixed(2)} (n.s.)`;
  return 'n.s.';
}

// Confidence bucket from soft-membership top1/top2 split.
export function confidenceBucket(top1: number, top2: number): 'confident' | 'borderline' | 'weak' {
  if (top1 >= 0.6 || top1 - top2 >= 0.25) return 'confident';
  if (top1 - top2 >= 0.1) return 'borderline';
  return 'weak';
}

// Within-cohort percentile (0–100) of a single value, given the full vector.
export function percentile(value: number, vector: number[]): number {
  if (vector.length === 0) return 0;
  let below = 0;
  for (const v of vector) if (v < value) below++;
  return (below / vector.length) * 100;
}

// Bucket a numeric column into roughly equal-sized bands. Used for
// subgroup pivots over continuous variables (age, income, …).
export function autoBuckets(values: number[], n = 4): string[] {
  if (values.length === 0) return values.map(() => '—');
  const sorted = [...values].sort((a, b) => a - b);
  const cuts: number[] = [];
  for (let i = 1; i < n; i++) {
    cuts.push(sorted[Math.floor((sorted.length * i) / n)]);
  }
  const fmt = (v: number) =>
    Number.isInteger(v) ? String(v) : v.toFixed(1);
  return values.map((v) => {
    let i = 0;
    while (i < cuts.length && v > cuts[i]) i++;
    if (i === 0) return `≤ ${fmt(cuts[0])}`;
    if (i === cuts.length) return `> ${fmt(cuts[cuts.length - 1])}`;
    return `${fmt(cuts[i - 1])}–${fmt(cuts[i])}`;
  });
}

// Build a 2-D pivot: rows = profile, cols = subgroup level. Returns a
// matrix of within-subgroup shares so columns sum to 1.
export function pivotByGroup(
  predictions: string[],
  group: (string | undefined)[],
  profiles: string[],
): { levels: string[]; matrix: number[][]; counts: number[] } {
  const levels = Array.from(new Set(group.filter((g): g is string => !!g))).sort();
  const counts: number[] = levels.map(() => 0);
  const matrix: number[][] = profiles.map(() => levels.map(() => 0));

  predictions.forEach((p, i) => {
    const g = group[i];
    if (!g) return;
    const ci = levels.indexOf(g);
    const ri = profiles.indexOf(p);
    if (ci < 0 || ri < 0) return;
    matrix[ri][ci]++;
    counts[ci]++;
  });

  // normalise columns to shares
  const shares = matrix.map((row) =>
    row.map((cell, ci) => (counts[ci] === 0 ? 0 : cell / counts[ci])),
  );
  return { levels, matrix: shares, counts };
}
