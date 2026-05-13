// Two-sample Kolmogorov-Smirnov test.
//
// Used by the cohort upload pre-flight to check whether each mapped
// variable's marginal distribution differs meaningfully from the
// SHARE Wave 9 reference. The reference is shipped as 500 equally-
// spaced empirical quantiles per variable per country, which acts
// as a discretised empirical sample of size 500 for KS purposes.

export type KSResult = {
  D: number;  // KS statistic in [0, 1]
  p: number;  // asymptotic p-value
  nA: number;
  nB: number;
};

// Two-pointer ECDF merge over two ascending arrays. Handles ties by
// advancing both pointers simultaneously and only sampling D after
// each step (post-advance), which is the standard textbook form.
export function ksTwoSample(sampleA: number[], sortedB: number[]): KSResult {
  const cleanA: number[] = [];
  for (const v of sampleA) {
    if (v === undefined || v === null) continue;
    if (typeof v !== 'number' || Number.isNaN(v)) continue;
    cleanA.push(v);
  }
  cleanA.sort((a, b) => a - b);
  const nA = cleanA.length;
  const nB = sortedB.length;
  if (nA === 0 || nB === 0) {
    return { D: 0, p: 1, nA, nB };
  }
  let i = 0;
  let j = 0;
  let D = 0;
  while (i < nA && j < nB) {
    const a = cleanA[i];
    const b = sortedB[j];
    if (a < b) {
      i++;
    } else if (b < a) {
      j++;
    } else {
      // Tie — advance ALL matching entries on both sides so the gap is
      // measured after the tie block resolves (otherwise repeated values
      // produce spurious mid-block deviations).
      const tie = a;
      while (i < nA && cleanA[i] === tie) i++;
      while (j < nB && sortedB[j] === tie) j++;
    }
    const fA = i / nA;
    const fB = j / nB;
    const d = Math.abs(fA - fB);
    if (d > D) D = d;
  }
  // After exhausting one side, the unresolved tail contributes at most
  // its share to the gap — explicitly check both endpoint conditions.
  const tailGap = Math.max(Math.abs(1 - j / nB), Math.abs(i / nA - 1));
  if (tailGap > D) D = tailGap;
  const nEff = (nA * nB) / (nA + nB);
  const p = Math.min(1, Math.max(0, 2 * Math.exp(-2 * nEff * D * D)));
  return { D, p, nA, nB };
}

export function ksTwoSampleUnsorted(sampleA: number[], sampleB: number[]): KSResult {
  const sortedB: number[] = [];
  for (const v of sampleB) {
    if (v === undefined || v === null) continue;
    if (typeof v !== 'number' || Number.isNaN(v)) continue;
    sortedB.push(v);
  }
  sortedB.sort((a, b) => a - b);
  return ksTwoSample(sampleA, sortedB);
}
