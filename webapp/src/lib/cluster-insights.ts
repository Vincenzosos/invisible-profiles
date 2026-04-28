// Cluster-level insights derived dynamically from the trained
// centroids and the per-cluster aggregates in killer_numbers.json.
//
// Used by Result.tsx (single-mode profile passport) and CsvUpload.tsx
// (batch-mode cluster dossier) so that the same data layer feeds both
// surfaces.

import killer from '../data/killer_numbers.json';
import passport from '../data/profile_passport.json';
import type { CentroidsJson, Country } from './profiler';

// Friendly labels for the variables that matter most to a non-specialist
// reader. We surface up to 3 strengths and 3 pressure points; the rest
// stay implicit.
const VAR_LABEL: Record<string, { label: string; higherIsBetter: boolean }> = {
  sphus:        { label: 'Self-rated health',     higherIsBetter: false }, // 1 best, 5 worst
  eurod:        { label: 'Depression score',      higherIsBetter: false },
  iadl:         { label: 'IADL limitations',      higherIsBetter: false },
  fdistress:    { label: 'Financial ease',        higherIsBetter: true  },
  internet:     { label: 'Internet use',          higherIsBetter: true  },
  sn_size_w9:   { label: 'Social network size',   higherIsBetter: true  },
  fluency:      { label: 'Verbal fluency',        higherIsBetter: true  },
  casp:         { label: 'Quality of life (CASP)',higherIsBetter: true  },
  loneliness:   { label: 'Loneliness',            higherIsBetter: false },
  hope_future:  { label: 'Hope for the future',   higherIsBetter: true  },
};

// ---- Strengths / pressure points -------------------------------------------

export type ClusterTrait = {
  variable: string;
  label: string;
  zScore: number;       // raw z-score on country-mean scale
  signedScore: number;  // positive when "good for the person"
};

// Read the centroid in z-space for the given country/profile and the
// 10-key-vars subset, then rank the dimensions by oriented effect size.
// "higherIsBetter" inverts loneliness/EURO-D/IADL/sphus so that a
// strength is always a positive signedScore.
export function clusterTraits(
  country: Country,
  profileName: string,
  data: CentroidsJson,
): { strengths: ClusterTrait[]; pressurePoints: ClusterTrait[] } {
  const subset = country === 'italy' ? data.italy_subset : data.sweden_subset;
  const profile = subset.profiles.find((p) => p.name === profileName);
  if (!profile) return { strengths: [], pressurePoints: [] };
  const order = profile.vars;
  const center = profile.center;

  const traits: ClusterTrait[] = order.map((v, i) => {
    const z = center[i];
    const meta = VAR_LABEL[v];
    const sign = meta?.higherIsBetter ? 1 : -1;
    return {
      variable: v,
      label: meta?.label ?? v,
      zScore: z,
      signedScore: z * sign,
    };
  });

  const sorted = [...traits].sort((a, b) => b.signedScore - a.signedScore);
  // Filter by sign so we never call a positive deviation a "pressure
  // point" or vice versa. No hard magnitude threshold — the most
  // informative items in each direction surface even when the cluster
  // hovers close to the country mean.
  const strengths = sorted.filter((t) => t.signedScore > 0).slice(0, 3);
  const pressurePoints = sorted
    .filter((t) => t.signedScore < 0)
    .reverse() // most negative first
    .slice(0, 3);
  return { strengths, pressurePoints };
}

// ---- Within-cluster percentile ---------------------------------------------

// Given the user's z-scores against the country mean, and the cluster's
// own centroid in the same z-space, the user's deviation from the
// cluster centroid is (userZ - centroidZ). Treating that residual as an
// approximately normal random variable with unit variance (which is the
// standard within-cluster assumption for K-means in z-space), the
// percentile within the cluster is Φ((userZ - centroidZ) / σ_within).
//
// We use σ_within = 0.7 as a conservative pooled estimate — for the
// SHARE Wave 9 trained partitions the residuals have mean SD ≈ 0.65.
// The result is a percentile rank: 50 = at the centroid, 90 = upper
// tail relative to other people in the same cluster.

const SIGMA_WITHIN = 0.7;

export function withinClusterPercentile(
  userZScores: Record<string, number>,
  country: Country,
  profileName: string,
  data: CentroidsJson,
): { variable: string; label: string; pct: number; orientation: 'higher' | 'lower' }[] {
  const subset = country === 'italy' ? data.italy_subset : data.sweden_subset;
  const profile = subset.profiles.find((p) => p.name === profileName);
  if (!profile) return [];
  const order = profile.vars;
  const center = profile.center;
  return order.map((v, i) => {
    const userZ = userZScores[v] ?? 0;
    const resid = userZ - center[i];
    const z = resid / SIGMA_WITHIN;
    const pct = normalCdf(z) * 100;
    const meta = VAR_LABEL[v];
    return {
      variable: v,
      label: meta?.label ?? v,
      pct,
      orientation: meta?.higherIsBetter ? 'higher' : 'lower',
    };
  });
}

function normalCdf(x: number): number {
  // Abramowitz & Stegun 26.2.17
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

// ---- Healthcare fingerprint -----------------------------------------------

export type HealthcareIndicator = {
  key: string;
  label: string;
  cluster: number;
  national: number;
  unit: 'pct' | 'count';
  orientation: 'higher_is_engaged' | 'lower_is_better';
};

// Pull a small set of healthcare-engagement indicators for the given
// cluster vs the country average. country_aggregates only carries the
// two binary indicators directly; for the count/proportion indicators
// that exist only at profile level, we compute a share-weighted
// national mean across all profiles.
export function healthcareFingerprint(
  country: Country,
  profileName: string,
): HealthcareIndicator[] {
  const profiles =
    country === 'italy' ? killer.italy_profiles : killer.sweden_profiles;
  const agg =
    country === 'italy'
      ? killer.country_aggregates.italy
      : killer.country_aggregates.sweden;
  const profile = profiles.find((p) => p.profile === profileName);
  if (!profile || !agg) return [];

  const weightedMean = (key: keyof typeof profile): number => {
    let totalShare = 0;
    let weighted = 0;
    for (const p of profiles) {
      const v = (p as Record<string, unknown>)[key as string];
      if (typeof v !== 'number') continue;
      totalShare += p.share_of_country_pct;
      weighted += v * p.share_of_country_pct;
    }
    return totalShare === 0 ? 0 : weighted / totalShare;
  };

  return [
    {
      key: 'dentist_12m',
      label: 'Visited dentist (12m)',
      cluster: profile.dentist_12m_pct,
      national: agg.dentist_12m_pct,
      unit: 'pct',
      orientation: 'higher_is_engaged',
    },
    {
      key: 'doctor_visits',
      label: 'Doctor visits / year',
      cluster: profile.doctor_visits_mean,
      national: weightedMean('doctor_visits_mean'),
      unit: 'count',
      orientation: 'higher_is_engaged',
    },
    {
      key: 'specialist',
      label: 'Specialist contacts',
      cluster: profile.specialist_contacts_mean,
      national: weightedMean('specialist_contacts_mean'),
      unit: 'count',
      orientation: 'higher_is_engaged',
    },
    {
      key: 'forgone_care_for_cost',
      label: 'Forgone care for cost',
      cluster: profile.forgone_care_for_cost_pct,
      national: agg.forgone_care_for_cost_pct,
      unit: 'pct',
      orientation: 'lower_is_better',
    },
    {
      key: 'hospitalised',
      label: 'Hospitalised (12m)',
      cluster: profile.hospitalised_pct ?? 0,
      national: weightedMean('hospitalised_pct'),
      unit: 'pct',
      orientation: 'lower_is_better',
    },
  ];
}

// ---- Welfare gap -----------------------------------------------------------

export type WelfareGapDimension = {
  dimension: string;
  label: string;
  italyValue: number;
  swedenValue: number;
  gap: number;             // SE - IT
  ci?: [number, number];
  unit: 'pct' | 'score' | 'count';
};

export type WelfareGap = {
  pairLabel: string;
  italianProfile: string;
  swedishProfile: string;
  dimensions: WelfareGapDimension[];
} | null;

// Resolve the matched-pair entry for the given Italian-or-Swedish
// profile name. Returns null when the profile has no analogue in the
// other country (Moderate Isolated, Asset Rich, Wealthy Digital).
export function welfareGap(
  country: Country,
  profileName: string,
): WelfareGap {
  const pairs = killer.matched_pairs ?? [];
  const found = pairs.find((p) =>
    country === 'italy'
      ? p.italian_profile === profileName
      : p.swedish_profile === profileName,
  );
  if (!found) return null;

  const dimensionLabels: Record<string, { label: string; unit: WelfareGapDimension['unit'] }> = {
    dentist_12m:       { label: 'Dentist visit (12m)',           unit: 'pct' },
    internet:          { label: 'Internet use (7d)',             unit: 'pct' },
    forgone_cost:      { label: 'Forgone care for cost',         unit: 'pct' },
    specialist:        { label: 'Specialist contacts (count)',   unit: 'count' },
    casp:              { label: 'CASP-12 quality of life',       unit: 'score' },
    internet_banking:  { label: 'Online banking / health',       unit: 'pct' },
    online_shopping:   { label: 'Online shopping',               unit: 'pct' },
  };

  const dims: WelfareGapDimension[] = [];
  for (const d of found.dimensions ?? []) {
    const meta = dimensionLabels[d.dimension] ?? {
      label: d.dimension,
      unit: 'pct' as const,
    };
    dims.push({
      dimension: d.dimension,
      label: meta.label,
      italyValue: d.italy_mean,
      swedenValue: d.sweden_mean,
      gap: d.gap_se_minus_it,
      ci: d.gap_ci as [number, number] | undefined,
      unit: meta.unit,
    });
  }

  return {
    pairLabel: found.matched_pair_label,
    italianProfile: found.italian_profile,
    swedishProfile: found.swedish_profile,
    dimensions: dims,
  };
}

// ---- Passport copy access ---------------------------------------------------

export type PassportCopy = {
  headline: string;
  tagline: string;
  action_signals: string[];
  welfare_pair: string | null;
  twin?: string | null;
};

export function passportFor(
  country: Country,
  profileName: string,
): PassportCopy | null {
  const block =
    country === 'italy'
      ? (passport.italy as Record<string, PassportCopy & { twin_swedish_profile?: string | null; twin_italian_profile?: string | null }>)
      : (passport.sweden as Record<string, PassportCopy & { twin_swedish_profile?: string | null; twin_italian_profile?: string | null }>);
  const entry = block[profileName];
  if (!entry) return null;
  return {
    headline: entry.headline,
    tagline: entry.tagline,
    action_signals: entry.action_signals,
    welfare_pair: entry.welfare_pair,
    twin:
      country === 'italy'
        ? entry.twin_swedish_profile ?? null
        : entry.twin_italian_profile ?? null,
  };
}
