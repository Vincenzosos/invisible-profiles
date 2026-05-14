// External-validation data layer.
//
// The segmentation is built on a small set of conceptual dimensions
// (financial, social, cognitive, subjective, digital). Held-out
// behavioural and outcome variables — dentist visits, forgone care,
// hospitalisations, life satisfaction — act as external validators:
// if the partition captures real structure, it should *predict* these
// variables even though they were not used to fit it.
//
// This module exposes pure functions over the per-profile aggregates
// in killer_numbers.json:
//
//   buildValidationMatrix(country) -> cluster × variable cells, with
//     each cell's value, the matching national baseline, the signed
//     delta and a relative effect magnitude (for colour saturation in
//     the UI heat map).
//
//   cohortForecast(country, cohortShares) -> share-weighted projection
//     of cluster-level rates onto each external variable. Conditional
//     on the cohort's distributional skew (see ks_test pre-flight).

import killer from '../data/killer_numbers.json';
import type { Country } from './profiler';

// ----- Public surface --------------------------------------------------------

export type ExternalVariable = {
  key: string;
  label: string;
  unit: 'pct' | 'count' | 'score';
  orientation: 'higher_better' | 'lower_better' | 'neutral';
  description: string;
  hint?: string;
};

// Curated list of external (held-out) variables. Anything not carried
// by the per-profile aggregates is filtered out at matrix-build time —
// keeps the layer safe across pipeline regenerations.
export const EXTERNAL_VARS: ExternalVariable[] = [
  {
    key: 'dentist_12m_pct',
    label: 'Dentist visit (12m)',
    unit: 'pct',
    orientation: 'higher_better',
    description:
      'Share of cluster that visited a dentist in the past 12 months.',
  },
  {
    key: 'doctor_visits_mean',
    label: 'Doctor visits / year',
    unit: 'count',
    orientation: 'higher_better',
    description:
      'Mean doctor visits in the past 12 months. Higher values indicate engagement with primary care.',
    hint:
      'Care-seeking proxy; very high values can also indicate chronic-condition burden.',
  },
  {
    key: 'specialist_contacts_mean',
    label: 'Specialist contacts',
    unit: 'count',
    orientation: 'higher_better',
    description:
      'Mean specialist contacts in the past 12 months.',
  },
  {
    key: 'forgone_care_for_cost_pct',
    label: 'Forgone care for cost',
    unit: 'pct',
    orientation: 'lower_better',
    description:
      'Share of cluster who skipped needed care due to cost.',
  },
  {
    key: 'hospitalised_pct',
    label: 'Hospitalised (12m)',
    unit: 'pct',
    orientation: 'lower_better',
    description:
      'Share of cluster hospitalised in the past 12 months. Lower-is-better on this scale captures the absence-of-acute-event reading; this metric is dual-use and we surface it as such.',
  },
  {
    key: 'casp_mean',
    label: 'CASP-12 quality of life',
    unit: 'score',
    orientation: 'higher_better',
    description:
      'Mean CASP-12 score (12–48 scale, higher = better). Held out only under the 4D specification; reported here for completeness.',
  },
  {
    key: 'lifesat_mean',
    label: 'Life satisfaction',
    unit: 'score',
    orientation: 'higher_better',
    description:
      'Mean life-satisfaction self-report on the 0–10 scale (SHARE item AC012). Held out from clustering — used as the primary external validator throughout the thesis.',
  },
];

export type ClusterValidationCell = {
  cluster: string;
  varKey: string;
  value: number;
  national: number;
  delta: number;
  effect: number;
};

export type ValidationMatrix = {
  country: Country;
  clusters: string[];
  variables: ExternalVariable[];
  cells: ClusterValidationCell[];
};

export type CohortForecastEntry = {
  varKey: string;
  label: string;
  unit: 'pct' | 'count' | 'score';
  orientation: 'higher_better' | 'lower_better' | 'neutral';
  cohortExpected: number;
  national: number;
  delta: number;
};

// ----- Internals -------------------------------------------------------------

type ProfileRow = Record<string, unknown> & {
  profile: string;
  share_of_country_pct: number;
};

function profilesFor(country: Country): ProfileRow[] {
  return (
    country === 'italy' ? killer.italy_profiles : killer.sweden_profiles
  ) as unknown as ProfileRow[];
}

function countryAggregate(country: Country): Record<string, unknown> {
  return (
    country === 'italy'
      ? killer.country_aggregates.italy
      : killer.country_aggregates.sweden
  ) as unknown as Record<string, unknown>;
}

// country_aggregates carries CASP and lifesat under a different key
// shape than the per-profile aggregates (mean_casp vs casp_mean). The
// dentist and forgone-care fields share the same key. Anything else
// (doctor visits, specialist contacts, hospitalisations) is only at
// profile level, so we fall back to a share-weighted national mean.
const AGG_KEY_OVERRIDES: Record<string, string> = {
  casp_mean: 'mean_casp',
  lifesat_mean: 'mean_lifesat',
};

function readNumeric(row: Record<string, unknown>, key: string): number | null {
  const v = row[key];
  return typeof v === 'number' && Number.isFinite(v) ? v : null;
}

function nationalFor(country: Country, varKey: string): number | null {
  const agg = countryAggregate(country);
  const directKey = AGG_KEY_OVERRIDES[varKey] ?? varKey;
  const direct = readNumeric(agg, directKey);
  if (direct !== null) return direct;

  // Fallback: share-weighted national mean across profiles that carry
  // the variable. share_of_country_pct is in [0,1] already.
  let totalShare = 0;
  let weighted = 0;
  for (const p of profilesFor(country)) {
    const v = readNumeric(p, varKey);
    if (v === null) continue;
    totalShare += p.share_of_country_pct;
    weighted += v * p.share_of_country_pct;
  }
  return totalShare > 0 ? weighted / totalShare : null;
}

const EFFECT_EPS = 1e-9;

// ----- Public API ------------------------------------------------------------

export function buildValidationMatrix(country: Country): ValidationMatrix {
  const profiles = profilesFor(country);
  const clusters = profiles.map((p) => p.profile);

  // Keep only variables carried by at least one profile.
  const variables = EXTERNAL_VARS.filter((v) =>
    profiles.some((p) => readNumeric(p, v.key) !== null),
  );

  const cells: ClusterValidationCell[] = [];
  for (const variable of variables) {
    const national = nationalFor(country, variable.key);
    if (national === null) continue;
    for (const profile of profiles) {
      const value = readNumeric(profile, variable.key);
      if (value === null) continue;
      const delta = value - national;
      const denom = Math.max(Math.abs(national), EFFECT_EPS);
      const effect = delta / denom;
      cells.push({
        cluster: profile.profile,
        varKey: variable.key,
        value,
        national,
        delta,
        effect,
      });
    }
  }

  return { country, clusters, variables, cells };
}

// Share-weighted projection. cohortShares values should sum to ~1; any
// drift (rounding from row counts) is tolerated. A variable is skipped
// when less than half of the cohort's share lands on profiles that
// carry it — projecting from a sliver of the cohort would be noise.
export function cohortForecast(
  country: Country,
  cohortShares: Map<string, number>,
): CohortForecastEntry[] {
  const profiles = profilesFor(country);
  const profileByName = new Map(profiles.map((p) => [p.profile, p]));

  const entries: CohortForecastEntry[] = [];
  for (const variable of EXTERNAL_VARS) {
    let coveredShare = 0;
    let weighted = 0;
    for (const [clusterName, share] of cohortShares) {
      const profile = profileByName.get(clusterName);
      if (!profile) continue;
      const v = readNumeric(profile, variable.key);
      if (v === null) continue;
      coveredShare += share;
      weighted += v * share;
    }
    if (coveredShare < 0.5) continue;
    const cohortExpected = weighted / coveredShare;
    const national = nationalFor(country, variable.key);
    if (national === null) continue;
    entries.push({
      varKey: variable.key,
      label: variable.label,
      unit: variable.unit,
      orientation: variable.orientation,
      cohortExpected,
      national,
      delta: cohortExpected - national,
    });
  }

  return entries;
}
