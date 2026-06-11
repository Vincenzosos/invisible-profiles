// Specifications for the 10 profiler variables. Centralised so that
// CsvUpload, Quiz, and the Profiler engine can all reason about
// expected ranges, accepted string values, and SHARE means/SDs from a
// single source.
//
// Coding follows SHARE Wave 9 conventions. Where users might supply
// labels in plain language, we accept English and Italian variants.

export type VarSpec = {
  var: string;
  dim: string;
  label: string;          // human-readable name shown to users
  higherIsBetter: boolean; // true when a higher SHARE value is "good for the person"
  min: number;          // expected min in SHARE coding
  max: number;
  isBinary?: boolean;   // exactly 0/1
  // Lower-cased string keys → SHARE numeric value
  stringMap?: Record<string, number>;
  // Display-friendly hint for the user
  rangeHint: string;
};

export const VAR_SPECS: Record<string, VarSpec> = {
  sphus: {
    var: 'sphus',
    dim: 'Health',
    label: 'Self-rated health',
    higherIsBetter: false,
    min: 1, max: 5,
    rangeHint: '1 (excellent) — 5 (poor)',
    stringMap: {
      excellent: 1, 'very good': 2, 'verygood': 2, good: 3, fair: 4, poor: 5,
      eccellente: 1, 'molto buona': 2, 'molto_buona': 2, buona: 3,
      discreta: 4, scarsa: 5, cattiva: 5, ottima: 1,
    },
  },
  eurod: {
    var: 'eurod',
    dim: 'Health',
    label: 'Depression score (EURO-D)',
    higherIsBetter: false,
    min: 0, max: 12,
    rangeHint: '0 (no symptoms) — 12 (severe)',
  },
  iadl: {
    var: 'iadl',
    dim: 'Health',
    label: 'IADL limitations',
    higherIsBetter: false,
    min: 0, max: 7,
    rangeHint: '0 (independent) — 7 (full assistance)',
  },
  fdistress: {
    var: 'fdistress',
    dim: 'Economic',
    label: 'Financial ease',
    higherIsBetter: true,
    min: 1, max: 4,
    rangeHint: '1 (great difficulty) — 4 (easily)',
    stringMap: {
      'with great difficulty': 1, 'great difficulty': 1,
      'with some difficulty': 2, 'some difficulty': 2,
      'fairly easily': 3, easily: 4,
      'molta difficolta': 1, 'molta difficoltà': 1,
      'qualche difficolta': 2, 'qualche difficoltà': 2,
      'abbastanza facilmente': 3, facilmente: 4,
    },
  },
  internet: {
    var: 'internet',
    dim: 'Digital',
    label: 'Internet use',
    higherIsBetter: true,
    min: 0, max: 1, isBinary: true,
    rangeHint: '0 (no) / 1 (yes, in past 7 days)',
    stringMap: {
      yes: 1, no: 0, y: 1, n: 0,
      true: 1, false: 0, t: 1, f: 0,
      'sì': 1, si: 1, 'no.': 0,
    },
  },
  sn_size_w9: {
    var: 'sn_size_w9',
    dim: 'Social',
    label: 'Social network size',
    higherIsBetter: true,
    min: 0, max: 7,
    rangeHint: '0 — 7 close confidants',
  },
  fluency: {
    var: 'fluency',
    dim: 'Cognitive',
    label: 'Verbal fluency',
    higherIsBetter: true,
    min: 0, max: 50,
    rangeHint: 'count of animals named in 60s (typical 8–30)',
  },
  casp: {
    var: 'casp',
    dim: 'Subjective',
    label: 'Quality of life (CASP-12)',
    higherIsBetter: true,
    min: 12, max: 48,
    rangeHint: '12 — 48 (CASP-12 sum, higher = better quality of life)',
  },
  loneliness: {
    var: 'loneliness',
    dim: 'Subjective',
    label: 'Loneliness',
    higherIsBetter: false,
    min: 3, max: 9,
    rangeHint: '3 (rarely) — 9 (often)',
  },
  hope_future: {
    var: 'hope_future',
    dim: 'Subjective',
    label: 'Hope for the future',
    higherIsBetter: true,
    min: 0, max: 1, isBinary: true,
    rangeHint: '0 (no) / 1 (yes)',
    stringMap: {
      yes: 1, no: 0, y: 1, n: 0,
      true: 1, false: 0, t: 1, f: 0,
      'sì': 1, si: 1,
    },
  },
};

export const VAR_LIST: VarSpec[] = Object.values(VAR_SPECS);

// ---- Single source of truth for user-facing variable naming ----------------
// Use these everywhere a SHARE codename would otherwise be shown to a user.
// The codename (e.g. "sphus") is kept available for tooltips / secondary text.

/** Human-readable label, e.g. "Self-rated health". Falls back to the code. */
export function varLabel(code: string): string {
  return VAR_SPECS[code]?.label ?? code;
}

/** Label with the SHARE coding range in parentheses, e.g.
 *  "Self-rated health (1 (excellent) — 5 (poor))". Falls back to the code. */
export function varLabelWithRange(code: string): string {
  const spec = VAR_SPECS[code];
  if (!spec) return code;
  return `${spec.label} (${spec.rangeHint})`;
}

// Synonym tokens used by the auto-mapper to resolve common header
// variants. Kept short and high-signal — the Jaccard similarity in
// csv-mapping.ts handles fuzzy matches beyond this list.
export const SYNONYMS: Record<string, string[]> = {
  sphus: ['sphus', 'self_rated_health', 'selfratedhealth', 'health_rating', 'sph', 'general_health'],
  eurod: ['eurod', 'eurod_score', 'depression', 'depression_score', 'depressive_score'],
  iadl: ['iadl', 'iadl_score', 'iadl_count', 'adl_instr', 'adl_iadl', 'limitations_iadl'],
  fdistress: ['fdistress', 'financial_distress', 'ends_meet', 'co007_', 'making_ends_meet', 'finance_diff'],
  internet: ['internet', 'internet_use', 'internet_7d', 'internet_use_7d', 'it005_', 'web_use', 'online'],
  sn_size_w9: ['sn_size_w9', 'sn_size', 'social_network', 'network_size', 'confidants', 'close_circle'],
  fluency: ['fluency', 'animals_60s', 'verbal_fluency', 'cf016tot', 'animal_naming', 'animals_named'],
  casp: ['casp', 'casp12', 'casp_12', 'quality_of_life', 'qol_casp', 'qol_score'],
  loneliness: ['loneliness', 'ucla_loneliness', 'lone_score', 'ucla', 'lonely_score'],
  hope_future: ['hope_future', 'hope', 'hopes_future', 'mh032_', 'forward_hope', 'future_hope'],
};
