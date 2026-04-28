// Per-cluster dossier surfaced when the user clicks a profile name in
// the batch-mode cohort distribution.
//
// Shows, for the selected cluster within the user's cohort:
//   - Cluster passport (headline, tagline, action signals)
//   - Demographic breakdown (uses unmapped CSV columns when available)
//   - Cohort-vs-SHARE signature on the 10 profiler variables
//   - Healthcare fingerprint (national-level reference)
//   - Welfare-gap matched-pair (when applicable)
//   - Confidence-bucket distribution within the cluster

import { useMemo } from 'react';
import killer from '../data/killer_numbers.json';
import {
  healthcareFingerprint,
  passportFor,
  welfareGap,
  type HealthcareIndicator,
  type WelfareGapDimension,
} from '../lib/cluster-insights';
import { VAR_LIST, VAR_SPECS } from '../lib/var-specs';
import type { Country } from '../lib/profiler';

type Confidence = 'confident' | 'borderline' | 'weak';

type CohortRow = {
  inputRow: Record<string, string>;
  predicted_profile: string;
  best_distance: number;
  membership_top1_pct: number;
  membership_top2_pct: number;
  confidence: Confidence;
  distance_percentile: number;
  coerced: Record<string, number>;
};

type Props = {
  country: Country;
  cluster: string;
  rows: CohortRow[];                 // ALL scored rows (we filter inside)
  unmappedColumns: string[];         // CSV columns NOT mapped to a profiler var
  onClose: () => void;
};

export default function ClusterDossier({
  country,
  cluster,
  rows,
  unmappedColumns,
  onClose,
}: Props) {
  const inCluster = useMemo(
    () => rows.filter((r) => r.predicted_profile === cluster),
    [rows, cluster],
  );
  const passport = passportFor(country, cluster);
  const gap = welfareGap(country, cluster);
  const fingerprint = healthcareFingerprint(country, cluster);

  const benchmarkProfile = useMemo(() => {
    const profiles = country === 'italy' ? killer.italy_profiles : killer.sweden_profiles;
    return profiles.find((p) => p.profile === cluster) ?? null;
  }, [country, cluster]);

  const cohortMeans = useMemo(() => {
    if (inCluster.length === 0) return null;
    const out: Record<string, number> = {};
    for (const v of VAR_LIST) {
      const vals: number[] = [];
      for (const r of inCluster) {
        const x = r.coerced[v.var];
        if (typeof x === 'number') vals.push(x);
      }
      out[v.var] =
        vals.length === 0 ? NaN : vals.reduce((s, x) => s + x, 0) / vals.length;
    }
    return out;
  }, [inCluster]);

  const benchmarkMeans = useMemo<Record<string, number | null>>(() => {
    const empty: Record<string, number | null> = {};
    if (!benchmarkProfile) return empty;
    const out: Record<string, number | null> = {
      sphus: null, // not in killer_numbers profile rows directly
      eurod: benchmarkProfile.eurod_mean,
      iadl: null,
      fdistress: null,
      internet: benchmarkProfile.internet_pct,
      sn_size_w9: benchmarkProfile.social_network_size_mean,
      fluency: benchmarkProfile.fluency_mean,
      casp: benchmarkProfile.casp_mean,
      loneliness: benchmarkProfile.loneliness_mean,
      hope_future: benchmarkProfile.hope_future_pct,
    };
    return out;
  }, [benchmarkProfile]);

  const confidenceCounts = useMemo(() => {
    const c = { confident: 0, borderline: 0, weak: 0 };
    for (const r of inCluster) c[r.confidence]++;
    return c;
  }, [inCluster]);

  const demographics = useMemo(
    () => buildDemographics(inCluster, unmappedColumns),
    [inCluster, unmappedColumns],
  );

  const total = rows.length;
  const inClusterPct = total === 0 ? 0 : inCluster.length / total;
  const benchmarkPct = benchmarkProfile?.share_of_country_pct ?? 0;
  const deltaPp = (inClusterPct - benchmarkPct) * 100;

  return (
    <article className="rounded-2xl bg-zinc-50 border border-emerald-300 p-6 space-y-6">
      <header className="flex items-baseline justify-between gap-4 flex-wrap">
        <div className="space-y-1">
          <p className="eyebrow text-emerald-700">Cluster dossier · {country}</p>
          <h3 className="display-2 text-slate-900">{cluster}</h3>
          {passport && (
            <p className="text-base text-zinc-700 italic max-w-2xl">
              {passport.tagline}
            </p>
          )}
          <p className="text-sm text-zinc-600">
            {inCluster.length.toLocaleString()} of {total.toLocaleString()}{' '}
            scored rows ({(inClusterPct * 100).toFixed(1)}% of cohort) ·
            SHARE benchmark {(benchmarkPct * 100).toFixed(1)}% ·
            Δ{' '}
            <span
              className={[
                'font-medium',
                Math.abs(deltaPp) < 2
                  ? 'text-zinc-500'
                  : deltaPp > 0
                  ? 'text-emerald-700'
                  : 'text-rose-600',
              ].join(' ')}
            >
              {deltaPp >= 0 ? '+' : ''}
              {deltaPp.toFixed(1)}pp
            </span>
          </p>
        </div>
        <button
          type="button"
          onClick={onClose}
          className="text-sm text-zinc-600 hover:text-slate-900 transition-colors"
        >
          Close ✕
        </button>
      </header>

      {passport && passport.action_signals.length > 0 && (
        <section className="space-y-2">
          <p className="eyebrow">What this cluster makes visible</p>
          <ul className="space-y-2">
            {passport.action_signals.map((s, i) => (
              <li key={i} className="text-sm text-zinc-700 leading-relaxed flex gap-3">
                <span className="text-emerald-700 font-mono text-xs tabular-nums mt-0.5">
                  {String(i + 1).padStart(2, '0')}
                </span>
                <span>{s}</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="space-y-2">
          <p className="eyebrow">Confidence in cluster</p>
          <ConfidenceBar counts={confidenceCounts} total={inCluster.length} />
        </div>
        {demographics.length > 0 && (
          <div className="space-y-2">
            <p className="eyebrow">Demographic profile · cohort</p>
            <ul className="text-sm text-zinc-700 space-y-1">
              {demographics.map((d) => (
                <li key={d.label} className="flex items-baseline justify-between">
                  <span>{d.label}</span>
                  <span className="text-xs text-zinc-600 tabular-nums text-right">
                    {d.summary}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </section>

      {cohortMeans && (
        <section className="space-y-3">
          <p className="eyebrow">Cluster signature · cohort vs SHARE benchmark</p>
          <div className="space-y-2">
            {VAR_LIST.map((v) => {
              const cohortMean = cohortMeans[v.var];
              const bench = benchmarkMeans[v.var];
              if (Number.isNaN(cohortMean)) return null;
              return (
                <SignatureRow
                  key={v.var}
                  varName={v.var}
                  label={`${v.var} (${VAR_SPECS[v.var].rangeHint})`}
                  cohort={cohortMean}
                  benchmark={bench}
                  isPct={
                    v.var === 'internet' || v.var === 'hope_future'
                  }
                />
              );
            })}
          </div>
          <p className="text-xs text-zinc-500">
            Top bar: mean of this cluster within your cohort. Bottom thin bar:
            SHARE Wave 9 cluster mean (where available). Dashes mean SHARE
            does not publish that variable at cluster level in killer_numbers.
          </p>
        </section>
      )}

      {fingerprint.length > 0 && (
        <section className="space-y-3">
          <p className="eyebrow">Healthcare engagement (national-level)</p>
          <div className="space-y-2">
            {fingerprint.map((f) => (
              <FingerprintMini key={f.key} f={f} />
            ))}
          </div>
        </section>
      )}

      {gap && (
        <section className="space-y-3">
          <p className="eyebrow">
            Welfare-state translation · {gap.pairLabel} matched pair →{' '}
            {country === 'italy' ? gap.swedishProfile : gap.italianProfile}
          </p>
          <div className="space-y-2">
            {gap.dimensions.slice(0, 5).map((d) => (
              <GapMini key={d.dimension} d={d} country={country} />
            ))}
          </div>
        </section>
      )}

      {!gap && passport && passport.welfare_pair === null && (
        <section className="rounded-xl bg-white border border-zinc-200 p-4">
          <p className="text-xs text-zinc-700 leading-relaxed">
            Country-specific cluster: no analogue in the matched-pair design.
            Universalist welfare in the other country redistributes this
            profile across other clusters.
          </p>
        </section>
      )}
    </article>
  );
}

// ============================================================================
//  Sub-components / helpers
// ============================================================================

function ConfidenceBar({
  counts,
  total,
}: {
  counts: { confident: number; borderline: number; weak: number };
  total: number;
}) {
  const pct = (n: number) => (total === 0 ? 0 : (n / total) * 100);
  return (
    <div className="space-y-1.5">
      <div className="relative h-3 bg-zinc-100 rounded-full overflow-hidden flex">
        <div
          className="bg-emerald-500"
          style={{ width: `${pct(counts.confident)}%` }}
        />
        <div
          className="bg-amber-400"
          style={{ width: `${pct(counts.borderline)}%` }}
        />
        <div
          className="bg-rose-400"
          style={{ width: `${pct(counts.weak)}%` }}
        />
      </div>
      <div className="flex items-center justify-between text-xs text-zinc-600">
        <span>
          <span className="text-emerald-700 font-medium">
            {counts.confident}
          </span>{' '}
          confident
        </span>
        <span>
          <span className="text-amber-700 font-medium">
            {counts.borderline}
          </span>{' '}
          borderline
        </span>
        <span>
          <span className="text-rose-700 font-medium">{counts.weak}</span>{' '}
          weak
        </span>
      </div>
    </div>
  );
}

function buildDemographics(
  rows: CohortRow[],
  unmapped: string[],
): { label: string; summary: string }[] {
  if (rows.length === 0) return [];
  const out: { label: string; summary: string }[] = [];
  for (const col of unmapped) {
    const values: string[] = [];
    for (const r of rows) {
      const v = r.inputRow[col];
      if (v !== undefined && v !== '') values.push(v);
    }
    if (values.length === 0) continue;
    const numeric = values.every((v) => !Number.isNaN(Number(v)));
    if (numeric) {
      const nums = values.map(Number);
      const mean = nums.reduce((s, x) => s + x, 0) / nums.length;
      const min = Math.min(...nums);
      const max = Math.max(...nums);
      out.push({
        label: col,
        summary: `mean ${mean.toFixed(1)} · range ${min}–${max}`,
      });
    } else {
      const counts = new Map<string, number>();
      for (const v of values) counts.set(v, (counts.get(v) ?? 0) + 1);
      const sorted = [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3);
      out.push({
        label: col,
        summary: sorted
          .map(([k, n]) => `${k} (${((n / values.length) * 100).toFixed(0)}%)`)
          .join(' · '),
      });
    }
    if (out.length >= 5) break; // keep the panel compact
  }
  return out;
}

function SignatureRow({
  varName,
  label,
  cohort,
  benchmark,
  isPct,
}: {
  varName: string;
  label: string;
  cohort: number;
  benchmark: number | null;
  isPct: boolean;
}) {
  const fmt = (v: number | null) =>
    v === null
      ? '—'
      : isPct
      ? `${(v * 100).toFixed(0)}%`
      : v.toFixed(1);
  const max = Math.max(
    cohort,
    benchmark ?? 0,
    isPct ? 1 : VAR_SPECS[varName]?.max ?? 1,
  );
  const cohortPct = (cohort / max) * 100;
  const benchPct = benchmark === null ? 0 : (benchmark / max) * 100;
  return (
    <div className="grid grid-cols-12 gap-3 items-center">
      <div className="col-span-5 text-sm text-zinc-700 truncate" title={label}>
        {label}
      </div>
      <div className="col-span-5 space-y-1">
        <div className="relative h-2 bg-zinc-100 rounded-full overflow-hidden">
          <div
            className="absolute inset-y-0 left-0 bg-emerald-600 rounded-full"
            style={{ width: `${cohortPct.toFixed(1)}%` }}
          />
        </div>
        {benchmark !== null && (
          <div className="relative h-1.5 bg-zinc-50 rounded-full overflow-hidden">
            <div
              className="absolute inset-y-0 left-0 bg-zinc-400 rounded-full"
              style={{ width: `${benchPct.toFixed(1)}%` }}
            />
          </div>
        )}
      </div>
      <div className="col-span-2 text-right text-xs tabular-nums">
        <div className="text-slate-900 font-medium">{fmt(cohort)}</div>
        <div className="text-zinc-500">
          {benchmark === null ? '— bench' : fmt(benchmark)}
        </div>
      </div>
    </div>
  );
}

function FingerprintMini({ f }: { f: HealthcareIndicator }) {
  const fmt = (v: number) =>
    f.unit === 'pct' ? `${(v * 100).toFixed(0)}%` : v.toFixed(1);
  const cohortDelta = f.cluster - f.national;
  const isImprovement =
    f.orientation === 'higher_is_engaged' ? cohortDelta >= 0 : cohortDelta <= 0;
  const tone = isImprovement ? 'text-emerald-700' : 'text-rose-600';
  return (
    <div className="grid grid-cols-12 gap-3 items-baseline">
      <div className="col-span-6 text-sm text-zinc-700 truncate">{f.label}</div>
      <div className="col-span-3 text-right text-sm tabular-nums text-slate-900">
        {fmt(f.cluster)}
      </div>
      <div className="col-span-3 text-right text-xs tabular-nums">
        <span className="text-zinc-500">vs {fmt(f.national)} </span>
        <span className={`font-medium ${tone}`}>
          {f.unit === 'pct'
            ? `${cohortDelta >= 0 ? '+' : ''}${(cohortDelta * 100).toFixed(0)}pp`
            : `${cohortDelta >= 0 ? '+' : ''}${cohortDelta.toFixed(1)}`}
        </span>
      </div>
    </div>
  );
}

function GapMini({
  d,
  country,
}: {
  d: WelfareGapDimension;
  country: Country;
}) {
  const userValue = country === 'italy' ? d.italyValue : d.swedenValue;
  const twinValue = country === 'italy' ? d.swedenValue : d.italyValue;
  const gap = country === 'italy' ? d.gap : -d.gap;
  const fmtVal = (v: number) =>
    d.unit === 'pct'
      ? `${(v * 100).toFixed(0)}%`
      : d.unit === 'score'
      ? v.toFixed(1)
      : v.toFixed(2);
  const fmtGap = (v: number) =>
    d.unit === 'pct'
      ? `${v >= 0 ? '+' : ''}${(v * 100).toFixed(0)}pp`
      : d.unit === 'score'
      ? `${v >= 0 ? '+' : ''}${v.toFixed(1)}`
      : `${v >= 0 ? '+' : ''}${v.toFixed(2)}`;
  const tone = gap >= 0 ? 'text-emerald-700' : 'text-rose-600';
  return (
    <div className="grid grid-cols-12 gap-3 items-baseline">
      <div className="col-span-5 text-sm text-zinc-700">{d.label}</div>
      <div className="col-span-3 text-right text-sm tabular-nums text-slate-900">
        {fmtVal(userValue)}
      </div>
      <div className="col-span-2 text-right text-sm tabular-nums text-zinc-600">
        {fmtVal(twinValue)}
      </div>
      <div className={`col-span-2 text-right text-sm tabular-nums font-medium ${tone}`}>
        {fmtGap(gap)}
      </div>
    </div>
  );
}
