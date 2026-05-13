// Smart CSV column → profiler-variable mapping.
//
// Strategy (in order of confidence):
//   1. Exact synonym match in SYNONYMS dict          → "synonym"
//   2. Fuzzy header match via Jaccard on bigrams      → "fuzzy"
//   3. Range-of-values match against the var spec     → "range"
//   4. Manual user choice                             → "manual"
//
// Each suggestion comes with a confidence score so the UI can show
// which mappings are guesses vs reliable matches.

import { SYNONYMS, VAR_LIST, VAR_SPECS, type VarSpec } from './var-specs';

// ---- string utilities ------------------------------------------------------

function normalize(s: string): string {
  return s
    .toLowerCase()
    .replace(/[À-ſ]/g, (c) =>
      c.normalize('NFD').replace(/[̀-ͯ]/g, ''),
    )
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '');
}

function bigrams(s: string): Set<string> {
  const norm = s.replace(/_/g, '');
  if (norm.length < 2) return new Set([norm]);
  const out = new Set<string>();
  for (let i = 0; i < norm.length - 1; i++) out.add(norm.slice(i, i + 2));
  return out;
}

function jaccard(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let inter = 0;
  for (const x of a) if (b.has(x)) inter++;
  const union = a.size + b.size - inter;
  return union === 0 ? 0 : inter / union;
}

export function similarity(headerName: string, target: string): number {
  return jaccard(bigrams(normalize(headerName)), bigrams(normalize(target)));
}

// ---- range detection -------------------------------------------------------

// Returns true when MOST of the column's parseable numeric values fall
// within (or close to) the variable's expected SHARE range.
export function valuesFitRange(values: string[], spec: VarSpec): {
  fits: boolean;
  ratio: number;          // share of cells inside the expanded range
  uniqueCount: number;
} {
  const nums: number[] = [];
  for (const v of values) {
    if (v === '' || v === undefined) continue;
    const n = Number(v);
    if (!Number.isNaN(n)) nums.push(n);
  }
  if (nums.length === 0) return { fits: false, ratio: 0, uniqueCount: 0 };
  const slack = Math.max((spec.max - spec.min) * 0.05, 0.5);
  const lo = spec.min - slack;
  const hi = spec.max + slack;
  let inside = 0;
  for (const n of nums) if (n >= lo && n <= hi) inside++;
  const ratio = inside / nums.length;
  const unique = new Set(nums).size;
  // For binary vars, also require uniqueCount ≤ 3 (allows 0/1 plus stray)
  if (spec.isBinary && unique > 3) return { fits: false, ratio, uniqueCount: unique };
  return { fits: ratio >= 0.85, ratio, uniqueCount: unique };
}

// ---- value coercion --------------------------------------------------------

export type CoerceOk = { ok: true; value: number };
export type CoerceFail = {
  ok: false;
  reason: 'empty' | 'out_of_range' | 'unparseable';
  detail: string;
};
export type CoerceResult = CoerceOk | CoerceFail;

// Coerce a single cell string to a numeric SHARE-coded value, given a
// variable specification. Strings like "Yes" / "Excellent" are mapped
// via the spec.stringMap. Numbers are validated against the expected
// range.
export function coerceValue(raw: string, spec: VarSpec): CoerceResult {
  if (raw === undefined || raw === null) {
    return { ok: false, reason: 'empty', detail: 'missing' };
  }
  const trimmed = String(raw).trim();
  if (trimmed === '') {
    return { ok: false, reason: 'empty', detail: 'missing' };
  }
  // Numeric path
  const num = Number(trimmed);
  if (!Number.isNaN(num)) {
    if (num < spec.min - 0.5 || num > spec.max + 0.5) {
      return {
        ok: false,
        reason: 'out_of_range',
        detail: `${num} not in ${spec.min}–${spec.max}`,
      };
    }
    return { ok: true, value: num };
  }
  // String path
  if (spec.stringMap) {
    const key = trimmed.toLowerCase();
    if (key in spec.stringMap) {
      return { ok: true, value: spec.stringMap[key] };
    }
  }
  return { ok: false, reason: 'unparseable', detail: trimmed };
}

// ---- mapping orchestration -------------------------------------------------

export type MappingSource = 'synonym' | 'fuzzy' | 'range' | 'manual' | 'rank_quantile' | 'none';

// ---- rank-quantile rescaling -----------------------------------------------
//
// Opt-in mapping mode for proxy variables on arbitrary scales (NPS,
// credit score, login counts, Likert 1-7…). Rescales a column onto a
// SHARE variable's coded range via empirical CDF, preserving the
// monotonic order of the column. Optionally inverts direction.

export type RescalingRule = {
  mode: 'rank_quantile';
  invert: boolean;
  sortedCohortValues: number[]; // pre-sorted ascending, NaN dropped
};

// Variables whose SHARE coding is integer ordinal/count.
// Binary vars are handled separately via spec.isBinary.
const INTEGER_CODED_VARS = new Set([
  'eurod',
  'iadl',
  'casp',
  'loneliness',
  'sn_size_w9',
  'fluency',
  'fdistress',
  'sphus',
]);

export function precomputeECDF(values: string[]): number[] {
  const nums: number[] = [];
  for (const v of values) {
    if (v === undefined || v === null) continue;
    const s = String(v).trim();
    if (s === '') continue;
    const n = Number(s);
    if (!Number.isNaN(n)) nums.push(n);
  }
  nums.sort((a, b) => a - b);
  return nums;
}

// Average-rank lookup (ties → mean of their index range). Returns a
// rank in [0, n-1]. Binary search bounds.
function averagedRank(sorted: number[], x: number): number {
  let lo = 0;
  let hi = sorted.length;
  // lower_bound
  let l = lo;
  let h = hi;
  while (l < h) {
    const m = (l + h) >>> 1;
    if (sorted[m] < x) l = m + 1;
    else h = m;
  }
  const lower = l;
  // upper_bound
  l = lo;
  h = hi;
  while (l < h) {
    const m = (l + h) >>> 1;
    if (sorted[m] <= x) l = m + 1;
    else h = m;
  }
  const upper = l;
  if (upper === lower) {
    // value not present; place at the lower boundary
    return lower;
  }
  return (lower + upper - 1) / 2;
}

export function applyRescaling(
  rawValue: string,
  rule: RescalingRule,
  spec: VarSpec,
): number | null {
  if (rawValue === undefined || rawValue === null) return null;
  const trimmed = String(rawValue).trim();
  if (trimmed === '') return null;
  const x = Number(trimmed);
  if (Number.isNaN(x)) return null;
  const n = rule.sortedCohortValues.length;
  if (n === 0) return null;
  const rank = averagedRank(rule.sortedCohortValues, x);
  let q = (rank + 1) / (n + 1);
  if (rule.invert) q = 1 - q;
  let mapped = spec.min + q * (spec.max - spec.min);
  if (spec.isBinary) {
    return mapped >= 0.5 ? 1 : 0;
  }
  if (INTEGER_CODED_VARS.has(spec.var)) {
    const rounded = Math.round(mapped);
    return Math.min(spec.max, Math.max(spec.min, rounded));
  }
  return mapped;
}

export type ColumnSuggestion = {
  header: string | null;
  source: MappingSource;
  confidence: number;     // 0–1
  reason: string;
};

const FUZZY_THRESHOLD = 0.45;

function bestSynonymMatch(
  varName: string,
  normalizedHeaders: { raw: string; norm: string }[],
): { header: string; norm: string } | null {
  const targets = SYNONYMS[varName] ?? [varName];
  const targetNorms = targets.map(normalize);
  for (const h of normalizedHeaders) {
    if (targetNorms.includes(h.norm)) return { header: h.raw, norm: h.norm };
  }
  return null;
}

function bestFuzzyMatch(
  varName: string,
  normalizedHeaders: { raw: string; norm: string }[],
): { header: string; score: number } | null {
  const targets = SYNONYMS[varName] ?? [varName];
  let best: { header: string; score: number } | null = null;
  for (const h of normalizedHeaders) {
    let score = 0;
    for (const t of targets) {
      const s = jaccard(bigrams(h.norm), bigrams(normalize(t)));
      if (s > score) score = s;
    }
    if (!best || score > best.score) {
      best = { header: h.raw, score };
    }
  }
  if (best && best.score >= FUZZY_THRESHOLD) return best;
  return null;
}

// Build a column suggestion for every profiler variable, given a CSV.
// columnsValues is a map header → first-N values (used for range
// detection; pass at least a few hundred rows for reliability).
export function suggestMapping(
  headers: string[],
  columnsValues: Record<string, string[]>,
): Record<string, ColumnSuggestion> {
  const normalizedHeaders = headers.map((h) => ({
    raw: h,
    norm: normalize(h),
  }));
  const claimed = new Set<string>(); // headers already used for a higher-confidence var
  const out: Record<string, ColumnSuggestion> = {};

  // Pass 1 — exact synonym matches (highest confidence, claim first)
  for (const spec of VAR_LIST) {
    const m = bestSynonymMatch(spec.var, normalizedHeaders);
    if (m && !claimed.has(m.header)) {
      claimed.add(m.header);
      out[spec.var] = {
        header: m.header,
        source: 'synonym',
        confidence: 1.0,
        reason: 'exact name match',
      };
    }
  }

  // Pass 2 — fuzzy header match (Jaccard ≥ 0.45)
  for (const spec of VAR_LIST) {
    if (out[spec.var]) continue;
    const remaining = normalizedHeaders.filter((h) => !claimed.has(h.raw));
    if (remaining.length === 0) continue;
    const f = bestFuzzyMatch(spec.var, remaining);
    if (f) {
      claimed.add(f.header);
      out[spec.var] = {
        header: f.header,
        source: 'fuzzy',
        confidence: f.score,
        reason: `~${(f.score * 100).toFixed(0)}% header similarity`,
      };
    }
  }

  // Pass 3 — value-range match for any var still unmapped
  for (const spec of VAR_LIST) {
    if (out[spec.var]) continue;
    let bestHeader: string | null = null;
    let bestRatio = 0;
    for (const h of normalizedHeaders) {
      if (claimed.has(h.raw)) continue;
      const vs = columnsValues[h.raw] ?? [];
      const r = valuesFitRange(vs, spec);
      if (r.fits && r.ratio > bestRatio) {
        bestRatio = r.ratio;
        bestHeader = h.raw;
      }
    }
    if (bestHeader) {
      claimed.add(bestHeader);
      out[spec.var] = {
        header: bestHeader,
        source: 'range',
        confidence: bestRatio * 0.7, // discounted because content alone is weaker
        reason: `values match expected range (${(bestRatio * 100).toFixed(0)}% in ${
          VAR_SPECS[spec.var].rangeHint
        })`,
      };
    }
  }

  // Anything still unmapped — fill with empty suggestion
  for (const spec of VAR_LIST) {
    if (!out[spec.var]) {
      out[spec.var] = {
        header: null,
        source: 'none',
        confidence: 0,
        reason: 'no automatic match found',
      };
    }
  }
  return out;
}
