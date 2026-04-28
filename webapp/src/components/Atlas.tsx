import { useEffect, useState } from 'react';
import killer from '../data/killer_numbers.json';
import centroids from '../data/centroids.json';
import {
  formatEUR,
  formatIndividuals,
  formatNum,
  formatPct,
} from '../lib/format';
import {
  clusterTraits,
  healthcareFingerprint,
  passportFor,
  welfareGap,
  type HealthcareIndicator,
  type WelfareGapDimension,
} from '../lib/cluster-insights';
import type { View } from '../types';

type Profile = (typeof killer.italy_profiles)[number];

const HERO_PROFILES = new Set([
  'Connected Active',
  'Moderate Isolated',
]);

type Props = {
  onNavigate?: (v: View) => void;
};

export default function Atlas({ onNavigate }: Props) {
  const [openProfile, setOpenProfile] = useState<string | null>(null);
  const profiles = killer.italy_profiles;

  const sorted = [...profiles].sort((a, b) => {
    const aHero = HERO_PROFILES.has(a.profile) ? 1 : 0;
    const bHero = HERO_PROFILES.has(b.profile) ? 1 : 0;
    if (aHero !== bHero) return bHero - aHero;
    return b.market_size_individuals - a.market_size_individuals;
  });

  const heroes = sorted.filter((p) => HERO_PROFILES.has(p.profile));
  const supporting = sorted.filter((p) => !HERO_PROFILES.has(p.profile));

  return (
    <section className="space-y-16">
      <header className="space-y-6 max-w-4xl">
        <p className="eyebrow">02 · The Five Segments</p>
        <h1 className="display-1 text-slate-900">
          Five segments. Each one a different chapter of ageing.
        </h1>
        <p className="text-lg text-zinc-700 leading-relaxed max-w-3xl">
          K-means clustering with k=5 on 29 standardised SHARE Wave 9
          indicators (n = {killer.country_aggregates.italy.n_sample}). Profile
          shares projected to{' '}
          {formatIndividuals(
            killer.country_aggregates.italy.national_over65_individuals,
          )}{' '}
          Italian over-65 individuals (Istat 2024). Click any segment for the
          full passport: economics, healthcare, welfare-state translation.
        </p>
      </header>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {heroes.map((p) => (
          <ProfileCard
            key={p.profile}
            p={p}
            hero
            onOpen={() => setOpenProfile(p.profile)}
          />
        ))}
      </section>

      <section className="space-y-6">
        <p className="eyebrow">Supporting segments</p>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {supporting.map((p) => (
            <ProfileCard
              key={p.profile}
              p={p}
              onOpen={() => setOpenProfile(p.profile)}
            />
          ))}
        </div>
      </section>

      <p className="text-xs text-zinc-500 max-w-3xl leading-relaxed">
        Per-segment medians and means are SHARE-derived with 2,000-iteration
        bootstrap 95% CI (seed = 42). Income and net-worth figures are
        per-household, not per-individual: SHARE samples one financial
        respondent per household. National projections use Istat 2024 over-65
        total. See <span className="font-medium text-zinc-700">Methods &amp; data</span>{' '}
        for variable definitions and the full source bibliography.
      </p>

      {openProfile && (
        <DrilldownModal
          profile={profiles.find((p) => p.profile === openProfile)!}
          onClose={() => setOpenProfile(null)}
        />
      )}

      {onNavigate && (
        <button
          type="button"
          onClick={() => onNavigate('benchmark')}
          className="block w-full text-left rounded-2xl border border-blue-200 bg-blue-50 hover:bg-blue-100 hover:border-blue-400 transition-colors p-8 group"
        >
          <p className="eyebrow text-blue-700">Continue · Italy ↔ Sweden</p>
          <p className="display-2 text-slate-900 mt-3">
            Now compare them across welfare regimes.
          </p>
          <p className="mt-3 text-base text-zinc-700 leading-relaxed max-w-3xl">
            For each Italian profile, the matched Swedish counterpart and the
            structural gap on healthcare, digital reach, and quality of life —
            with 95% bootstrap confidence intervals.
          </p>
          <p className="mt-6 text-sm font-medium text-blue-700 group-hover:translate-x-1 transition-transform inline-flex items-center gap-2">
            Italy ↔ Sweden →
          </p>
        </button>
      )}
    </section>
  );
}

function ProfileCard({
  p,
  hero,
  onOpen,
}: {
  p: Profile;
  hero?: boolean;
  onOpen: () => void;
}) {
  const passport = passportFor('italy', p.profile);
  return (
    <article
      className={[
        'rounded-2xl bg-white border p-6 space-y-5 hover:border-blue-400 transition-colors cursor-pointer group',
        hero ? 'border-zinc-300' : 'border-zinc-200',
      ].join(' ')}
      onClick={onOpen}
    >
      <header className="space-y-2">
        <p className="eyebrow">
          {formatPct(p.share_of_country_pct)} ·{' '}
          {formatIndividuals(p.market_size_individuals)} individuals
        </p>
        <h2
          className={[
            'tracking-tight text-slate-900',
            hero ? 'display-2' : 'display-3',
          ].join(' ')}
        >
          {p.profile}
        </h2>
      </header>

      <div className={hero ? 'grid grid-cols-2 gap-5' : 'grid grid-cols-2 gap-3'}>
        <Metric
          label="Median income (household)"
          value={formatEUR(p.median_income_eur, { abbreviated: false })}
          big={hero}
        />
        <Metric
          label="Median net worth (household)"
          value={formatEUR(p.median_networth_eur, { abbreviated: false })}
          big={hero}
        />
        <Metric label="Internet 7d" value={formatPct(p.internet_pct)} />
        <Metric label="Home owners" value={formatPct(p.homeownership_pct)} />
        <Metric label="Dentist 12m" value={formatPct(p.dentist_12m_pct)} />
        <Metric label="CASP-12 mean" value={formatNum(p.casp_mean, 1)} />
      </div>

      {passport && (
        <p className="text-sm text-zinc-700 leading-relaxed border-t border-zinc-100 pt-4">
          <span className="font-medium text-slate-900">{passport.headline}</span>{' '}
          <span className="text-zinc-600">{passport.tagline}</span>
        </p>
      )}

      <p className="text-xs text-blue-700 group-hover:translate-x-1 transition-transform">
        Full passport &rarr;
      </p>
    </article>
  );
}

function Metric({
  label,
  value,
  big,
}: {
  label: string;
  value: string;
  big?: boolean;
}) {
  return (
    <div>
      <p className="eyebrow">{label}</p>
      <p
        className={[
          'text-slate-900 tabular-nums mt-1',
          big ? 'metric' : 'text-base font-medium',
        ].join(' ')}
      >
        {value}
      </p>
    </div>
  );
}

function DrilldownModal({
  profile: p,
  onClose,
}: {
  profile: Profile;
  onClose: () => void;
}) {
  const passport = passportFor('italy', p.profile);
  const traits = clusterTraits('italy', p.profile, centroids);
  const fingerprint = healthcareFingerprint('italy', p.profile);
  const gap = welfareGap('italy', p.profile);
  const agg = killer.country_aggregates.italy;

  // Esc-to-close + body scroll lock while panel is open.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [onClose]);

  return (
    <>
      {/* Light dim — does not blur the page so the Atlas grid stays readable */}
      <div
        className="fixed inset-0 bg-slate-900/15 z-30"
        onClick={onClose}
        aria-hidden="true"
      />
      <aside
        role="dialog"
        aria-label={`${p.profile} profile dossier`}
        className="fixed top-0 right-0 bottom-0 w-full sm:w-[640px] lg:w-[720px] bg-white shadow-2xl z-40 overflow-y-auto animate-[slideIn_220ms_ease-out]"
      >
        <div className="p-6 sm:p-8 space-y-8">
          <header className="flex items-start justify-between gap-4 sticky top-0 -mx-6 sm:-mx-8 -mt-6 sm:-mt-8 px-6 sm:px-8 pt-6 sm:pt-8 pb-4 bg-white border-b border-zinc-200 z-10">
            <div className="space-y-2">
              <p className="eyebrow">
                {formatPct(p.share_of_country_pct)} ·{' '}
                {formatIndividuals(p.market_size_individuals)} individuals · sample n = {p.n_sample}
              </p>
              <h2 className="display-2 text-slate-900">{p.profile}</h2>
            </div>
            <button
              type="button"
              onClick={onClose}
              className="text-zinc-400 hover:text-slate-900 text-2xl leading-none -mt-1 px-2"
              aria-label="Close"
            >
              ×
            </button>
          </header>

        {passport && (
          <div className="rounded-xl bg-blue-50 border border-blue-200 p-5 space-y-3">
            <p className="font-medium text-slate-900">{passport.headline}</p>
            <p className="text-sm text-zinc-700 italic leading-relaxed">
              {passport.tagline}
            </p>
            {passport.action_signals.length > 0 && (
              <ul className="space-y-2 pt-1">
                {passport.action_signals.map((s, i) => (
                  <li
                    key={i}
                    className="text-sm text-zinc-700 leading-relaxed flex gap-3"
                  >
                    <span className="text-blue-700 font-mono text-xs tabular-nums mt-0.5">
                      {String(i + 1).padStart(2, '0')}
                    </span>
                    <span>{s}</span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}

        {/* Headline metrics — 3 big numbers cluster vs national */}
        <section className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <HeadlineMetric
            label="Median household income"
            cluster={p.median_income_eur}
            national={agg.median_household_income_eur}
            format="eur"
          />
          <HeadlineMetric
            label="Quality of life · CASP-12"
            cluster={p.casp_mean}
            national={agg.mean_casp}
            format="num"
          />
          <HeadlineMetric
            label="Internet last 7 days"
            cluster={p.internet_pct}
            national={agg.internet_penetration_pct}
            format="pct"
          />
        </section>

        {/* Cluster signature: strengths + pressure points */}
        {(traits.strengths.length > 0 || traits.pressurePoints.length > 0) && (
          <section className="rounded-2xl bg-white border border-zinc-200 p-5 space-y-4">
            <p className="eyebrow">Cluster signature</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
              <div>
                <p className="text-xs font-medium text-blue-700 mb-2">Strengths</p>
                {traits.strengths.length === 0 ? (
                  <p className="text-xs text-zinc-500">
                    No dimension scores notably above the country mean.
                  </p>
                ) : (
                  <ul className="space-y-1.5">
                    {traits.strengths.map((t) => (
                      <li
                        key={t.variable}
                        className="text-sm text-zinc-700 flex items-baseline justify-between"
                      >
                        <span>{t.label}</span>
                        <span className="text-xs tabular-nums text-blue-700 font-medium">
                          z = {t.zScore >= 0 ? '+' : ''}{t.zScore.toFixed(2)}
                        </span>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
              <div>
                <p className="text-xs font-medium text-rose-700 mb-2">Pressure points</p>
                {traits.pressurePoints.length === 0 ? (
                  <p className="text-xs text-zinc-500">
                    No dimension scores notably below the country mean.
                  </p>
                ) : (
                  <ul className="space-y-1.5">
                    {traits.pressurePoints.map((t) => (
                      <li
                        key={t.variable}
                        className="text-sm text-zinc-700 flex items-baseline justify-between"
                      >
                        <span>{t.label}</span>
                        <span className="text-xs tabular-nums text-rose-700 font-medium">
                          z = {t.zScore >= 0 ? '+' : ''}{t.zScore.toFixed(2)}
                        </span>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </div>
          </section>
        )}

        {/* Healthcare engagement with comparative bars */}
        {fingerprint.length > 0 && (
          <section className="rounded-2xl bg-white border border-zinc-200 p-5 space-y-4">
            <p className="eyebrow">Healthcare engagement · cluster vs national</p>
            <div className="space-y-2.5">
              {fingerprint.map((f) => (
                <FingerprintRow key={f.key} f={f} />
              ))}
            </div>
          </section>
        )}

        {/* Welfare-state translation: matched-pair gap */}
        {gap && (
          <section className="rounded-2xl bg-blue-50 border border-blue-200 p-5 space-y-3">
            <p className="eyebrow text-blue-700">
              Welfare-state translation · {gap.pairLabel} matched pair
            </p>
            <p className="text-sm text-slate-900">
              In Sweden, this cluster matches{' '}
              <span className="text-blue-700 font-medium">{gap.swedishProfile}</span>.
            </p>
            <div className="space-y-2 pt-1">
              {gap.dimensions.slice(0, 5).map((d) => (
                <GapRow key={d.dimension} d={d} />
              ))}
            </div>
          </section>
        )}

        {!gap && passport && passport.welfare_pair === null && (
          <section className="rounded-2xl bg-zinc-50 border border-zinc-200 p-5">
            <p className="eyebrow mb-2">Country-specific cluster</p>
            <p className="text-sm text-zinc-700 leading-relaxed">
              No analogue in the matched-pair design. Universalist welfare in
              Sweden redistributes this profile across other clusters.
            </p>
          </section>
        )}

        {/* Numbers in detail (collapsible) */}
        <details className="rounded-2xl bg-zinc-50 border border-zinc-200 p-5">
          <summary className="cursor-pointer text-sm font-medium text-slate-900 select-none">
            Numbers in detail
          </summary>
          <div className="space-y-7 pt-5">
            <Section label="Economic snapshot (per household)">
              <DetailRow
                label="Median household income"
                value={formatEUR(p.median_income_eur, { abbreviated: false })}
                ci={`${formatEUR(p.median_income_eur_ci[0], { abbreviated: false })}–${formatEUR(p.median_income_eur_ci[1], { abbreviated: false })}`}
              />
              <DetailRow
                label="Median household net worth"
                value={formatEUR(p.median_networth_eur, { abbreviated: false })}
                ci={`${formatEUR(p.median_networth_eur_ci[0], { abbreviated: false })}–${formatEUR(p.median_networth_eur_ci[1], { abbreviated: false })}`}
              />
              <DetailRow
                label="Median pension income"
                value={formatEUR(p.median_pension_eur, { abbreviated: false })}
              />
              <DetailRow label="Home owners" value={formatPct(p.homeownership_pct)} />
              <DetailRow
                label="Reports financial ease"
                value={formatPct(p.fdistress_easy_pct)}
              />
              <DetailRow
                label="Reports financial distress"
                value={formatPct(p.fdistress_struggling_pct)}
              />
            </Section>

            <Section label="Digital and social">
              <DetailRow label="Internet last 7 days" value={formatPct(p.internet_pct)} />
              <DetailRow
                label="Online banking / health / e-commerce"
                value={formatPct(p.online_banking_health_proxy_pct)}
              />
              <DetailRow
                label="Social network size (mean)"
                value={formatNum(p.social_network_size_mean, 2)}
              />
              <DetailRow
                label="UCLA loneliness (mean)"
                value={formatNum(p.loneliness_mean, 2)}
              />
            </Section>

            <Section label="Cognitive and subjective">
              <DetailRow
                label="Verbal fluency (animals/60s)"
                value={formatNum(p.fluency_mean, 1)}
              />
              <DetailRow
                label="Quality of life · CASP-12"
                value={formatNum(p.casp_mean, 2)}
                ci={`${p.casp_mean_ci[0].toFixed(2)}–${p.casp_mean_ci[1].toFixed(2)}`}
              />
              <DetailRow
                label="Life satisfaction (0-10)"
                value={formatNum(p.lifesat_mean, 2)}
              />
              <DetailRow
                label="Hope for the future"
                value={formatPct(p.hope_future_pct)}
              />
              <DetailRow
                label="EURO-D depression score"
                value={formatNum(p.eurod_mean, 2)}
              />
            </Section>

            <Section label="Demographics">
              <DetailRow label="Mean age" value={`${p.mean_age_years} years`} />
              <DetailRow label="Female share" value={formatPct(p.share_female)} />
            </Section>
          </div>
        </details>

          <p className="text-xs text-zinc-500 leading-relaxed pt-2 border-t border-zinc-100">
            Sources: SHARE Wave 9 release 9.0.0 (fielded 2021–2022) for all
            per-segment metrics; Istat 2024 for the national over-65 projection.
            Confidence intervals: 2,000-iteration percentile bootstrap (seed = 42).
          </p>
        </div>
      </aside>
    </>
  );
}

function HeadlineMetric({
  label,
  cluster,
  national,
  format,
}: {
  label: string;
  cluster: number;
  national: number;
  format: 'eur' | 'pct' | 'num';
}) {
  const fmt = (v: number) =>
    format === 'eur'
      ? formatEUR(v, { abbreviated: false })
      : format === 'pct'
      ? formatPct(v)
      : v.toFixed(1);
  const delta = cluster - national;
  const pct = national === 0 ? 0 : (delta / national) * 100;
  const tone =
    Math.abs(pct) < 5
      ? 'text-zinc-500'
      : pct > 0
      ? 'text-blue-700'
      : 'text-rose-600';
  const sign = delta >= 0 ? '+' : '−';
  const absDelta = Math.abs(delta);
  const fmtDelta =
    format === 'pct'
      ? `${sign}${(absDelta * 100).toFixed(0)}pp`
      : format === 'eur'
      ? `${sign}${formatEUR(absDelta, { abbreviated: true })}`
      : `${sign}${absDelta.toFixed(1)}`;
  return (
    <div className="rounded-2xl bg-white border border-zinc-200 p-4 space-y-1">
      <p className="eyebrow">{label}</p>
      <p className="metric text-slate-900">{fmt(cluster)}</p>
      <p className={`text-xs tabular-nums ${tone}`}>
        {fmtDelta} vs national mean
      </p>
    </div>
  );
}

function FingerprintRow({ f }: { f: HealthcareIndicator }) {
  const fmt = (v: number) =>
    f.unit === 'pct' ? `${(v * 100).toFixed(0)}%` : v.toFixed(1);
  const cohortDelta = f.cluster - f.national;
  const isImprovement =
    f.orientation === 'higher_is_engaged' ? cohortDelta >= 0 : cohortDelta <= 0;
  const tone = isImprovement ? 'text-blue-700' : 'text-rose-600';
  const max = Math.max(f.cluster, f.national, 0.0001);
  return (
    <div className="grid grid-cols-12 gap-3 items-center">
      <div className="col-span-5 text-sm text-zinc-700 truncate">{f.label}</div>
      <div className="col-span-5 space-y-1">
        <div className="relative h-2 bg-zinc-100 rounded-full overflow-hidden">
          <div
            className="absolute inset-y-0 left-0 bg-blue-600 rounded-full"
            style={{ width: `${(f.cluster / max) * 100}%` }}
          />
        </div>
        <div className="relative h-1.5 bg-zinc-50 rounded-full overflow-hidden">
          <div
            className="absolute inset-y-0 left-0 bg-zinc-400 rounded-full"
            style={{ width: `${(f.national / max) * 100}%` }}
          />
        </div>
      </div>
      <div className="col-span-2 text-right text-xs tabular-nums">
        <div className="text-slate-900 font-medium">{fmt(f.cluster)}</div>
        <div className={`${tone}`}>
          {f.unit === 'pct'
            ? `${cohortDelta >= 0 ? '+' : ''}${(cohortDelta * 100).toFixed(0)}pp`
            : `${cohortDelta >= 0 ? '+' : ''}${cohortDelta.toFixed(1)}`}
        </div>
      </div>
    </div>
  );
}

function GapRow({ d }: { d: WelfareGapDimension }) {
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
  const tone = d.gap >= 0 ? 'text-blue-700' : 'text-rose-600';
  return (
    <div className="grid grid-cols-12 gap-3 items-baseline">
      <div className="col-span-5 text-sm text-zinc-700">{d.label}</div>
      <div className="col-span-3 text-right text-sm tabular-nums text-slate-900">
        {fmtVal(d.italyValue)}
      </div>
      <div className="col-span-2 text-right text-sm tabular-nums text-zinc-600">
        {fmtVal(d.swedenValue)}
      </div>
      <div className={`col-span-2 text-right text-sm tabular-nums font-medium ${tone}`}>
        {fmtGap(d.gap)}
      </div>
    </div>
  );
}

function Section({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <section className="space-y-3">
      <p className="eyebrow">{label}</p>
      <div className="border-t border-zinc-200 divide-y divide-zinc-100">
        {children}
      </div>
    </section>
  );
}

function DetailRow({
  label,
  value,
  ci,
}: {
  label: string;
  value: string;
  ci?: string;
}) {
  return (
    <div className="flex items-baseline justify-between py-2.5 gap-4">
      <span className="text-sm text-zinc-700">{label}</span>
      <span className="text-sm font-medium text-slate-900 text-right tabular-nums">
        {value}
        {ci && (
          <span className="block text-xs text-zinc-400 font-normal">
            CI 95%: {ci}
          </span>
        )}
      </span>
    </div>
  );
}
