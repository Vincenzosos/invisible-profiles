// B2B cohort scoring dashboard.
//
// Headline output of the upload flow: a KPI strip surfacing the
// Isolation Paradox flag and the digital-addressability split, a
// cluster-distribution chart with click-to-drill semantics, and an
// aggregate-metrics panel that compares the cohort to the SHARE national
// baselines on the dimensions that matter for outreach planning
// (CASP-12, internet, social-mediation share). The dossier slide-over
// (ClusterDossier) is reused unchanged.

import { useMemo } from 'react';
import killer from '../data/killer_numbers.json';
import ClusterDossier from './ClusterDossier';
import {
  benchmarkShares,
  chiSquareVsBenchmark,
  cohortDistribution,
  formatPValue,
} from '../lib/cohort-stats';
import type { Country } from '../lib/profiler';
import type { Evidence } from '../lib/evidence';

type Confidence = 'confident' | 'borderline' | 'weak';

export type CohortRow = {
  inputRow: Record<string, string>;
  predicted_profile: string;
  best_distance: number;
  membership_top1_pct: number;
  membership_top2_profile: string;
  membership_top2_pct: number;
  zScores: Record<string, number>;
  twin_country_profile: string;
  twin_country_distance: number;
  confidence: Confidence;
  distance_percentile: number;
  coerced: Record<string, number>;
  validation: { var: string; reason: string; detail: string }[];
  coverage?: { observed: number; total: number };
  evidence?: Evidence;
  imputation_top1_share?: number;
};

type Props = {
  country: Country;
  rows: CohortRow[];
  unmappedColumns: string[];
  selectedCluster: string | null;
  onSelectCluster: (cluster: string | null) => void;
  onDownloadCsv: () => void;
  onPrintReport: () => void;
};

// Cluster categorisation by country. Defines which clusters count as
// "intermediated need", "digitally addressable", and which one carries
// the Isolation Paradox flag. Sweden has no Italian-style paradox; we
// use "welfare-attached" as the analogue.
const CATEGORIES: Record<
  Country,
  {
    isolationFlag: { name: string; label: string } | null;
    digital: string[];
    intermediated: string[];
  }
> = {
  italy: {
    isolationFlag: { name: 'Moderate Isolated', label: 'Isolation Paradox' },
    digital: ['Connected Active', 'Traditional Social'],
    intermediated: ['Fragile Resigned', 'Fragile Depressed'],
  },
  sweden: {
    isolationFlag: null,
    digital: ['Connected Wealthy', 'Wealthy Digital', 'Asset Rich', 'Moderate'],
    intermediated: ['Fragile', 'Social Decline'],
  },
};

// Cluster colours — keep aligned with the rest of the app palette.
const CLUSTER_COLOR: Record<string, string> = {
  'Fragile Resigned':   '#7c2d12',  // deep red-brown
  'Fragile Depressed':  '#b91c1c',  // red
  'Moderate Isolated':  '#d97706',  // amber (the paradox highlight)
  'Traditional Social': '#0891b2',  // cyan
  'Connected Active':   '#1d4ed8',  // blue (anchor of digital pole)
  'Fragile':            '#7c2d12',
  'Social Decline':     '#b91c1c',
  'Moderate':           '#d97706',
  'Asset Rich':         '#0891b2',
  'Wealthy Digital':    '#1d4ed8',
  'Connected Wealthy':  '#1e40af',
};

export default function CohortDashboard({
  country,
  rows,
  unmappedColumns,
  selectedCluster,
  onSelectCluster,
  onDownloadCsv,
  onPrintReport,
}: Props) {
  const cat = CATEGORIES[country];
  const total = rows.length;

  const benchmark = useMemo(() => benchmarkShares(country), [country]);
  const predictions = useMemo(() => rows.map((r) => r.predicted_profile), [rows]);
  const dist = useMemo(
    () => cohortDistribution(predictions, benchmark),
    [predictions, benchmark],
  );
  const chi = useMemo(
    () => chiSquareVsBenchmark(predictions, benchmark),
    [predictions, benchmark],
  );

  const nationalBaseline = country === 'italy'
    ? killer.country_aggregates.italy
    : killer.country_aggregates.sweden;

  // ---------- KPI strip values --------------------------------------------

  const shareInClusters = (names: string[]) => {
    const s = dist
      .filter((d) => names.includes(d.name))
      .reduce((acc, d) => acc + d.share, 0);
    return s;
  };
  const benchmarkShareInClusters = (names: string[]) => {
    const s = benchmark
      .filter((b) => names.includes(b.name))
      .reduce((acc, b) => acc + b.share, 0);
    return s;
  };

  const isolationShare = cat.isolationFlag
    ? dist.find((d) => d.name === cat.isolationFlag!.name)?.share ?? 0
    : 0;
  const isolationBenchmark = cat.isolationFlag
    ? benchmark.find((b) => b.name === cat.isolationFlag!.name)?.share ?? 0
    : 0;
  const digitalShare = shareInClusters(cat.digital);
  const digitalBenchmark = benchmarkShareInClusters(cat.digital);
  const intermediatedShare = shareInClusters(cat.intermediated);
  const intermediatedBenchmark = benchmarkShareInClusters(cat.intermediated);

  // ---------- Aggregate cohort means --------------------------------------

  const cohortMeans = useMemo(() => {
    const acc = {
      casp: { sum: 0, n: 0 },
      internet: { sum: 0, n: 0 },
      loneliness: { sum: 0, n: 0 },
      hope: { sum: 0, n: 0 },
    };
    for (const r of rows) {
      if (typeof r.coerced.casp === 'number') {
        acc.casp.sum += r.coerced.casp;
        acc.casp.n++;
      }
      if (typeof r.coerced.internet === 'number') {
        acc.internet.sum += r.coerced.internet;
        acc.internet.n++;
      }
      if (typeof r.coerced.loneliness === 'number') {
        acc.loneliness.sum += r.coerced.loneliness;
        acc.loneliness.n++;
      }
      if (typeof r.coerced.hope_future === 'number') {
        acc.hope.sum += r.coerced.hope_future;
        acc.hope.n++;
      }
    }
    return {
      casp: acc.casp.n > 0 ? acc.casp.sum / acc.casp.n : null,
      internet: acc.internet.n > 0 ? acc.internet.sum / acc.internet.n : null,
      loneliness: acc.loneliness.n > 0 ? acc.loneliness.sum / acc.loneliness.n : null,
      hope: acc.hope.n > 0 ? acc.hope.sum / acc.hope.n : null,
    };
  }, [rows]);

  // ---------- Cohort reliability stats (partial-mapping cohorts) ---------

  const reliability = useMemo(() => {
    if (rows.length === 0) return null;
    const totalRows = rows.length;
    const totalVars = rows[0]?.coverage?.total ?? 10;
    const anyPartial = rows.some(
      (r) => (r.coverage?.observed ?? 10) < (r.coverage?.total ?? 10),
    );
    if (!anyPartial) return null;
    const avgCoverage =
      rows.reduce((s, r) => s + (r.coverage?.observed ?? 10), 0) / totalRows;
    const strongCount = rows.filter((r) => r.evidence === 'strong').length;
    const highImpCount = rows.filter(
      (r) => (r.imputation_top1_share ?? 0) >= 0.7,
    ).length;
    const strongPct = Math.round((strongCount / totalRows) * 100);
    const highImpPct = Math.round((highImpCount / totalRows) * 100);
    return {
      total: totalRows,
      totalVars,
      avgCoverage,
      strongCount,
      strongPct,
      highImpCount,
      highImpPct,
    };
  }, [rows]);

  // ---------- Coverage subtitle (partial-mapping cohorts) ----------------

  const coverageLine = useMemo(() => {
    if (rows.length === 0) return null;
    let sum = 0;
    let totalSum = 0;
    let anyPartial = false;
    for (const r of rows) {
      const obs = r.coverage?.observed ?? 10;
      const tot = r.coverage?.total ?? 10;
      sum += obs;
      totalSum += tot;
      if (obs < tot) anyPartial = true;
    }
    if (!anyPartial) return null;
    const avgObs = (sum / rows.length).toFixed(1);
    const tot = Math.round(totalSum / rows.length);
    return `Average coverage: ${avgObs} / ${tot} variables observed across cohort.`;
  }, [rows]);

  // ---------- Render ------------------------------------------------------

  return (
    <section className="space-y-8">
      {coverageLine && (
        <p className="text-xs text-zinc-600 -mt-4">{coverageLine}</p>
      )}
      {/* (a) KPI strip */}
      <KpiStrip
        total={total}
        isolationFlag={cat.isolationFlag}
        isolationShare={isolationShare}
        isolationBenchmark={isolationBenchmark}
        digitalShare={digitalShare}
        digitalBenchmark={digitalBenchmark}
        intermediatedShare={intermediatedShare}
        intermediatedBenchmark={intermediatedBenchmark}
      />

      <div className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-2">
        <p className="eyebrow">Statistical fit · cohort vs SHARE Wave 9 baseline</p>
        <p className="text-sm text-zinc-700">
          {chi.n.toLocaleString()} rows scored · Pearson χ²({chi.df}) ={' '}
          {chi.chi2.toFixed(2)},{' '}
          <span className="font-medium">{formatPValue(chi.p)}</span> against
          the{' '}
          <span className="capitalize">{country}</span> national distribution.
          {chi.p < 0.05
            ? ' The cohort distribution differs significantly from the national baseline.'
            : ' The cohort distribution is statistically indistinguishable from the national baseline.'}
        </p>
      </div>

      {reliability && (
        <article className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-4">
          <p className="eyebrow">Cohort reliability</p>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <p className="text-[10px] uppercase tracking-wider text-zinc-500">
                Mean coverage
              </p>
              <p className="text-2xl font-semibold tabular-nums text-slate-900 mt-1">
                {reliability.avgCoverage.toFixed(1)} / {reliability.totalVars}
              </p>
              <p className="text-xs text-zinc-600 mt-1">
                variables observed per row
              </p>
            </div>
            <div>
              <p className="text-[10px] uppercase tracking-wider text-zinc-500">
                Strong evidence rows
              </p>
              <p className="text-2xl font-semibold tabular-nums text-slate-900 mt-1">
                {reliability.strongCount} / {reliability.total} (
                {reliability.strongPct}%)
              </p>
              <p className="text-xs text-zinc-600 mt-1">
                actionable assignments
              </p>
            </div>
            <div>
              <p className="text-[10px] uppercase tracking-wider text-zinc-500">
                High imputation top-1
              </p>
              <p className="text-2xl font-semibold tabular-nums text-slate-900 mt-1">
                {reliability.highImpCount} / {reliability.total} (
                {reliability.highImpPct}%)
              </p>
              <p className="text-xs text-zinc-600 mt-1">
                top-1 imputation share ≥ 70%
              </p>
            </div>
          </div>
        </article>
      )}

      {/* (b) Cluster distribution chart */}
      <DistributionChart
        country={country}
        dist={dist}
        total={total}
        selected={selectedCluster}
        onSelect={onSelectCluster}
      />

      {/* (c) Drill-down — slide-over via ClusterDossier (reused) +
          B2B action card with placeholder operational moves. */}
      {selectedCluster && (
        <>
          <ClusterDossier
            country={country}
            cluster={selectedCluster}
            rows={rows}
            unmappedColumns={unmappedColumns}
            onClose={() => onSelectCluster(null)}
          />
          <ActionCard cluster={selectedCluster} />
        </>
      )}

      {/* (d) Aggregate cohort metrics */}
      <AggregatePanel
        country={country}
        cohortMeans={cohortMeans}
        nationalBaseline={nationalBaseline}
        digitalShare={digitalShare}
        intermediatedShare={intermediatedShare}
        isolationShare={isolationShare}
        isolationFlag={cat.isolationFlag}
      />

      {/* (e) Export */}
      <ExportPanel
        onDownloadCsv={onDownloadCsv}
        onPrintReport={onPrintReport}
      />
    </section>
  );
}

// ============================================================================
//  KPI strip
// ============================================================================

function KpiStrip({
  total,
  isolationFlag,
  isolationShare,
  isolationBenchmark,
  digitalShare,
  digitalBenchmark,
  intermediatedShare,
  intermediatedBenchmark,
}: {
  total: number;
  isolationFlag: { name: string; label: string } | null;
  isolationShare: number;
  isolationBenchmark: number;
  digitalShare: number;
  digitalBenchmark: number;
  intermediatedShare: number;
  intermediatedBenchmark: number;
}) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
      <KpiCard
        eyebrow="Cohort size"
        value={`${total.toLocaleString()}`}
        unit="records scored"
        sub="Sample analysed in this report."
        tone="neutral"
      />
      {isolationFlag ? (
        <KpiCard
          eyebrow={isolationFlag.label}
          value={`${(isolationShare * 100).toFixed(1)}%`}
          unit={isolationFlag.name}
          sub={
            <>
              Δ vs national{' '}
              <span className="tabular-nums">
                {(isolationBenchmark * 100).toFixed(1)}%
              </span>
              :{' '}
              <DeltaPp
                value={(isolationShare - isolationBenchmark) * 100}
              />
            </>
          }
          tone="flag"
          icon={<IsolationIcon />}
        />
      ) : (
        <KpiCard
          eyebrow="Welfare-attached"
          value={`—`}
          unit="(not surfaced for Sweden)"
          sub="The Isolation Paradox is an Italian-typology finding."
          tone="neutral"
        />
      )}
      <KpiCard
        eyebrow="Digitally addressable"
        value={`${(digitalShare * 100).toFixed(1)}%`}
        unit="of cohort"
        sub={
          <>
            Δ vs national{' '}
            <span className="tabular-nums">
              {(digitalBenchmark * 100).toFixed(1)}%
            </span>
            :{' '}
            <DeltaPp value={(digitalShare - digitalBenchmark) * 100} />
          </>
        }
        tone="positive"
      />
      <KpiCard
        eyebrow="Intermediated need"
        value={`${(intermediatedShare * 100).toFixed(1)}%`}
        unit="of cohort"
        sub={
          <>
            Δ vs national{' '}
            <span className="tabular-nums">
              {(intermediatedBenchmark * 100).toFixed(1)}%
            </span>
            :{' '}
            <DeltaPp value={(intermediatedShare - intermediatedBenchmark) * 100} />
          </>
        }
        tone="caution"
      />
    </div>
  );
}

function KpiCard({
  eyebrow,
  value,
  unit,
  sub,
  tone,
  icon,
}: {
  eyebrow: string;
  value: string;
  unit: string;
  sub: React.ReactNode;
  tone: 'neutral' | 'flag' | 'positive' | 'caution';
  icon?: React.ReactNode;
}) {
  const TONES: Record<typeof tone, string> = {
    neutral:  'bg-white border-zinc-200',
    flag:     'bg-amber-50 border-amber-300',
    positive: 'bg-blue-50 border-blue-200',
    caution:  'bg-rose-50 border-rose-200',
  };
  const VALUE_COLOR: Record<typeof tone, string> = {
    neutral:  'text-slate-900',
    flag:     'text-amber-900',
    positive: 'text-blue-900',
    caution:  'text-rose-900',
  };
  return (
    <article
      className={[
        'rounded-2xl border p-5 space-y-2 flex flex-col justify-between min-h-[8rem]',
        TONES[tone],
      ].join(' ')}
    >
      <div className="flex items-start justify-between gap-2">
        <p className="eyebrow whitespace-nowrap">{eyebrow}</p>
        {icon}
      </div>
      <div>
        <p className={`text-3xl font-semibold tabular-nums ${VALUE_COLOR[tone]}`}>
          {value}
        </p>
        <p className="text-xs text-zinc-600 mt-0.5">{unit}</p>
      </div>
      <p className="text-xs text-zinc-600 leading-relaxed">{sub}</p>
    </article>
  );
}

function DeltaPp({ value }: { value: number }) {
  const tone =
    Math.abs(value) < 2
      ? 'text-zinc-500'
      : value > 0
      ? 'text-amber-700'
      : 'text-blue-700';
  return (
    <span className={`tabular-nums font-medium ${tone}`}>
      {value >= 0 ? '+' : ''}
      {value.toFixed(1)}pp
    </span>
  );
}

function IsolationIcon() {
  // Inline SVG — small warning triangle with a question mark, signalling
  // "person at risk of being missed by the addressable market".
  return (
    <svg
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      className="text-amber-700 shrink-0"
      aria-hidden="true"
    >
      <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
      <line x1="12" y1="9" x2="12" y2="13" />
      <line x1="12" y1="17" x2="12.01" y2="17" />
    </svg>
  );
}

// ============================================================================
//  (b) Distribution chart
// ============================================================================

function DistributionChart({
  country,
  dist,
  total,
  selected,
  onSelect,
}: {
  country: Country;
  dist: ReturnType<typeof cohortDistribution>;
  total: number;
  selected: string | null;
  onSelect: (name: string | null) => void;
}) {
  const max = Math.max(...dist.map((d) => Math.max(d.share, d.benchmarkShare)), 0.01);
  return (
    <article className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-4">
      <div className="flex items-baseline justify-between gap-3 flex-wrap">
        <div>
          <p className="eyebrow">Cluster distribution · click to drill down</p>
          <p className="text-sm text-zinc-600 mt-2">
            Top thick bar: your cohort. Thin bar below: SHARE Wave 9{' '}
            <span className="capitalize">{country}</span> baseline. Click any
            row to open the cluster dossier.
          </p>
        </div>
      </div>
      <div className="space-y-2.5">
        {dist.map((d) => {
          const cohortPct = d.share * 100;
          const benchPct = d.benchmarkShare * 100;
          const dPp = d.deltaPp;
          const isSelected = selected === d.name;
          const colour = CLUSTER_COLOR[d.name] ?? '#3b82f6';
          return (
            <button
              type="button"
              key={d.name}
              onClick={() => onSelect(isSelected ? null : d.name)}
              className={[
                'w-full grid grid-cols-12 gap-3 items-center text-left rounded-lg px-3 py-2 transition-colors border',
                isSelected
                  ? 'bg-blue-50 border-blue-300 ring-1 ring-blue-200'
                  : 'border-transparent hover:bg-zinc-50',
              ].join(' ')}
            >
              <div className="col-span-4 sm:col-span-3 text-sm text-slate-900 truncate flex items-center gap-2">
                <span
                  className="inline-block w-2.5 h-2.5 rounded-full shrink-0"
                  style={{ backgroundColor: colour }}
                />
                <span className={isSelected ? 'font-medium' : ''}>
                  {d.name}
                </span>
              </div>
              <div className="col-span-5 sm:col-span-7 space-y-1">
                <div className="relative h-3 bg-zinc-100 rounded-full overflow-hidden">
                  <div
                    className="absolute inset-y-0 left-0 rounded-full"
                    style={{
                      width: `${(cohortPct / (max * 100)) * 100}%`,
                      backgroundColor: colour,
                    }}
                  />
                </div>
                <div className="relative h-1.5 bg-zinc-50 rounded-full overflow-hidden">
                  <div
                    className="absolute inset-y-0 left-0 bg-zinc-400 rounded-full"
                    style={{ width: `${(benchPct / (max * 100)) * 100}%` }}
                  />
                </div>
              </div>
              <div className="col-span-3 sm:col-span-2 text-right text-xs tabular-nums">
                <div className="text-slate-900 font-medium">
                  {cohortPct.toFixed(1)}%
                </div>
                <div className="text-zinc-500">
                  n = {d.n}
                  {total > 0 && ` of ${total}`}
                </div>
                <DeltaPp value={dPp} />
              </div>
            </button>
          );
        })}
      </div>
    </article>
  );
}

// ============================================================================
//  (d) Aggregate cohort metrics
// ============================================================================

function AggregatePanel({
  country,
  cohortMeans,
  nationalBaseline,
  digitalShare,
  intermediatedShare,
  isolationShare,
  isolationFlag,
}: {
  country: Country;
  cohortMeans: { casp: number | null; internet: number | null; loneliness: number | null; hope: number | null };
  nationalBaseline: typeof killer.country_aggregates.italy | typeof killer.country_aggregates.sweden;
  digitalShare: number;
  intermediatedShare: number;
  isolationShare: number;
  isolationFlag: { name: string; label: string } | null;
}) {
  const socialMediation = isolationShare + intermediatedShare;
  const nonAddressable = 1 - digitalShare;
  return (
    <article className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-5">
      <div>
        <p className="eyebrow">Aggregate cohort metrics · {country}</p>
        <p className="text-sm text-zinc-600 mt-2 max-w-2xl">
          How the cohort compares to the SHARE Wave 9 national baseline on the
          dimensions that matter for outreach planning.
        </p>
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <Metric
          label="Mean CASP-12 (quality of life, 12–48)"
          cohort={cohortMeans.casp}
          national={nationalBaseline.mean_casp}
          format={(v) => v.toFixed(1)}
          higherIsBetter
        />
        <Metric
          label="Internet penetration (% past 7 days)"
          cohort={cohortMeans.internet}
          national={nationalBaseline.internet_penetration_pct}
          format={(v) => `${(v * 100).toFixed(1)}%`}
          higherIsBetter
        />
        <Metric
          label="Digitally non-addressable share"
          cohort={nonAddressable}
          national={null}
          format={(v) => `${(v * 100).toFixed(1)}%`}
          higherIsBetter={false}
          subtitle="Cohort share NOT in a digitally-saturated cluster."
        />
        <Metric
          label="Social-mediation layer required"
          cohort={socialMediation}
          national={null}
          format={(v) => `${(v * 100).toFixed(1)}%`}
          higherIsBetter={false}
          subtitle={
            isolationFlag
              ? `Cohort share in ${isolationFlag.name} + intermediated-need clusters.`
              : 'Cohort share in intermediated-need clusters.'
          }
        />
      </div>
    </article>
  );
}

function Metric({
  label,
  cohort,
  national,
  format,
  higherIsBetter,
  subtitle,
}: {
  label: string;
  cohort: number | null;
  national: number | null;
  format: (v: number) => string;
  higherIsBetter: boolean;
  subtitle?: string;
}) {
  const delta =
    cohort !== null && national !== null ? cohort - national : null;
  const deltaTone =
    delta === null
      ? 'text-zinc-400'
      : Math.abs(delta) < (national && national > 1 ? 0.5 : 0.01)
      ? 'text-zinc-500'
      : (delta > 0) === higherIsBetter
      ? 'text-blue-700'
      : 'text-amber-700';
  return (
    <div className="rounded-xl border border-zinc-200 p-4 bg-zinc-50">
      <p className="text-xs text-zinc-600">{label}</p>
      <div className="mt-2 flex items-baseline gap-3">
        <p className="text-2xl font-semibold tabular-nums text-slate-900">
          {cohort === null ? '—' : format(cohort)}
        </p>
        {national !== null && (
          <p className="text-xs text-zinc-500 tabular-nums">
            national {format(national)}
          </p>
        )}
      </div>
      {delta !== null && (
        <p className={`text-xs tabular-nums mt-1 ${deltaTone}`}>
          Δ {delta >= 0 ? '+' : ''}
          {format(Math.abs(delta)).startsWith('-')
            ? format(delta)
            : delta < 0
            ? `-${format(Math.abs(delta))}`
            : format(delta)}{' '}
          vs national
        </p>
      )}
      {subtitle && (
        <p className="text-[11px] text-zinc-500 mt-2 leading-relaxed">{subtitle}</p>
      )}
    </div>
  );
}

// ============================================================================
//  Action card — operational moves on the selected cluster (placeholders).
// ============================================================================

function ActionCard({ cluster }: { cluster: string }) {
  const noop = () => {
    // Placeholder. Real handlers (CRM push, calendar invite, segment
    // export) live behind the B2B contract layer, not in the open-web
    // demo. The buttons disable themselves visually to signal preview
    // status without breaking the SaaS-like layout.
  };
  const actions: { title: string; sub: string; icon: React.ReactNode }[] = [
    {
      title: 'Plan outreach for this segment',
      sub: 'Compose a campaign brief tailored to the cluster signature, including channel, register and timing recommendations.',
      icon: <ActionIcon kind="megaphone" />,
    },
    {
      title: 'Export segment list',
      sub: 'Download the row IDs assigned to this cluster as a clean CSV, ready for ingestion in your CRM or outreach platform.',
      icon: <ActionIcon kind="download" />,
    },
    {
      title: 'Schedule follow-up',
      sub: 'Book a re-scoring window once new data arrives, so the segment composition stays current under demographic drift.',
      icon: <ActionIcon kind="calendar" />,
    },
  ];
  return (
    <article className="rounded-2xl border border-blue-300 bg-blue-50/50 p-6 space-y-5">
      <div className="flex items-baseline justify-between gap-3 flex-wrap">
        <div>
          <p className="eyebrow text-blue-700">Operational moves · {cluster}</p>
          <p className="text-sm text-zinc-700 mt-1 max-w-2xl">
            Placeholders — the open-web build does not push to external
            systems. Wire your CRM, outreach tool or calendar to these
            handlers in a private deployment.
          </p>
        </div>
        <span className="rounded-full bg-white border border-zinc-300 text-zinc-600 text-[10px] uppercase tracking-wider px-2 py-0.5">
          preview
        </span>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        {actions.map((a) => (
          <button
            key={a.title}
            type="button"
            onClick={noop}
            className="text-left rounded-xl bg-white border border-zinc-200 p-4 hover:border-blue-400 transition-colors space-y-2 group"
          >
            <div className="flex items-center gap-2 text-blue-700 group-hover:text-blue-900">
              {a.icon}
              <span className="text-sm font-medium text-slate-900">
                {a.title}
              </span>
            </div>
            <p className="text-xs text-zinc-600 leading-relaxed">{a.sub}</p>
          </button>
        ))}
      </div>
    </article>
  );
}

function ActionIcon({ kind }: { kind: 'megaphone' | 'download' | 'calendar' }) {
  const common = {
    width: 18,
    height: 18,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 2,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
    className: 'shrink-0',
    'aria-hidden': true,
  };
  if (kind === 'megaphone') {
    return (
      <svg {...common}>
        <path d="m3 11 18-5v12L3 14v-3z" />
        <path d="M11.6 16.8a3 3 0 1 1-5.8-1.6" />
      </svg>
    );
  }
  if (kind === 'download') {
    return (
      <svg {...common}>
        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
        <polyline points="7 10 12 15 17 10" />
        <line x1="12" y1="15" x2="12" y2="3" />
      </svg>
    );
  }
  return (
    <svg {...common}>
      <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
      <line x1="16" y1="2" x2="16" y2="6" />
      <line x1="8" y1="2" x2="8" y2="6" />
      <line x1="3" y1="10" x2="21" y2="10" />
    </svg>
  );
}

// ============================================================================
//  (e) Export
// ============================================================================

function ExportPanel({
  onDownloadCsv,
  onPrintReport,
}: {
  onDownloadCsv: () => void;
  onPrintReport: () => void;
}) {
  return (
    <article className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-4">
      <div>
        <p className="eyebrow">Export</p>
        <p className="text-sm text-zinc-600 mt-2 max-w-2xl">
          Download the scored cohort or generate a printable report of this
          dashboard.
        </p>
      </div>
      <div className="flex flex-wrap gap-3">
        <button
          type="button"
          onClick={onDownloadCsv}
          className="rounded-xl bg-blue-600 text-white px-5 py-2.5 hover:bg-blue-700 transition-colors text-sm"
        >
          Export full results CSV
        </button>
        <button
          type="button"
          onClick={onPrintReport}
          className="rounded-xl border border-zinc-300 bg-white px-5 py-2.5 hover:border-slate-500 transition-colors text-sm text-slate-900"
        >
          Download cohort report PDF
        </button>
      </div>
      <p className="text-[11px] text-zinc-500 leading-relaxed max-w-2xl">
        CSV adds a <code>predicted_profile</code>, soft-membership probabilities,
        confidence bucket and full z-scores per row. PDF uses the browser's print
        dialog (Save as PDF) — preserves the dashboard layout, hides
        navigation chrome.
      </p>
    </article>
  );
}
