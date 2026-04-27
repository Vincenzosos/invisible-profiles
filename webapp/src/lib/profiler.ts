import centroidsData from '../data/centroids.json';

export type CentroidsJson = typeof centroidsData;
export type Country = 'italy' | 'sweden';

export type ProfileMatch = {
  name: string;
  distance: number;
  zScores: Record<string, number>;
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

export function matchProfile(
  country: Country,
  answers: Record<string, number>,
  data: CentroidsJson,
): { best: ProfileMatch; ranking: ProfileMatch[] } {
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

  const ranking: ProfileMatch[] = subset.profiles
    .map((p) => ({
      name: p.name,
      distance: euclidean(userVec, p.center),
      zScores,
    }))
    .sort((a, b) => a.distance - b.distance);

  return { best: ranking[0], ranking };
}
