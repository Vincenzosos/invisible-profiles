// Evidence ladder for per-row cohort scoring.
//
// Combines three signals into a single 0-10 score:
//   - coverage  (how many of the 10 profiler variables were observed)
//   - top-1 share of the imputation distribution
//   - top1-top2 margin (decisiveness)
//
// A row labelled "confident" today on a 3/10-coverage cohort would
// produce a high softmax peak inside the 3-variable subspace, but the
// underlying assignment relies on 30% of the available evidence —
// hence the ladder explicitly trades coverage against decisiveness
// instead of conflating them.

export type Evidence = 'strong' | 'moderate' | 'weak';

export type EvidenceInputs = {
  coverageObserved: number;
  coverageTotal: number;
  top1Share: number; // [0, 1]
  top2Share: number; // [0, 1]
};

export const STRONG_THRESHOLD = 7;
export const MODERATE_THRESHOLD = 4.5;

export function computeEvidence(inp: EvidenceInputs): Evidence {
  const coverageScore =
    inp.coverageTotal > 0
      ? (inp.coverageObserved / inp.coverageTotal) * 5
      : 0;
  const margin = Math.max(0, inp.top1Share - inp.top2Share);
  const decisionScore = (inp.top1Share + margin) * 2.5;
  const total = coverageScore + decisionScore;
  if (total >= STRONG_THRESHOLD) return 'strong';
  if (total >= MODERATE_THRESHOLD) return 'moderate';
  return 'weak';
}
