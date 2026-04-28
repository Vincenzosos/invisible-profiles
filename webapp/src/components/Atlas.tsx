import { useState } from 'react';
import killer from '../data/killer_numbers.json';
import signals from '../data/business_signals.json';
import {
  formatEUR,
  formatIndividuals,
  formatNum,
  formatPct,
} from '../lib/format';

type Profile = (typeof killer.italy_profiles)[number];

const ITALY_BUSINESS_SIGNALS = signals.italy as Record<
  string,
  { headline: string; detail: string }
>;

const HERO_PROFILES = new Set([
  'Connected Active',
  'Moderate Isolated',
]);

export default function Atlas() {
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
        <p className="eyebrow">Atlas · Italy</p>
        <h1 className="display-1 text-slate-900">
          Five segments. Each one a market.
        </h1>
        <p className="text-lg text-zinc-700 leading-relaxed max-w-3xl">
          K-means clustering with k=5 on 29 standardised SHARE Wave 9
          indicators (n = {killer.country_aggregates.italy.n_sample}). Profile
          shares projected to{' '}
          {formatIndividuals(
            killer.country_aggregates.italy.national_over65_individuals,
          )}{' '}
          Italian over-65 individuals (Istat 2024). Click any segment for the
          full profile drilldown.
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
  const signal = ITALY_BUSINESS_SIGNALS[p.profile] ?? null;
  return (
    <article
      className={[
        'rounded-2xl bg-white border p-6 space-y-5 hover:border-emerald-400 transition-colors cursor-pointer group',
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

      {signal && (
        <p className="text-sm text-zinc-700 leading-relaxed border-t border-zinc-100 pt-4">
          <span className="font-medium text-slate-900">{signal.headline}</span>
        </p>
      )}

      <p className="text-xs text-emerald-700 group-hover:translate-x-1 transition-transform">
        Full profile &rarr;
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
  const signal = ITALY_BUSINESS_SIGNALS[p.profile] ?? null;

  return (
    <div
      className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-start sm:items-center justify-center z-30 p-4 overflow-y-auto"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-2xl max-w-3xl w-full p-8 sm:p-10 shadow-xl space-y-8 mt-4 sm:mt-0"
        onClick={(e) => e.stopPropagation()}
      >
        <header className="flex items-start justify-between gap-4">
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
            className="text-zinc-400 hover:text-slate-900 text-2xl leading-none -mt-1"
            aria-label="Close"
          >
            ×
          </button>
        </header>

        {signal && (
          <div className="rounded-xl bg-emerald-50 border border-emerald-200 p-5">
            <p className="font-medium text-slate-900 mb-2">{signal.headline}</p>
            <p className="text-sm text-zinc-700 leading-relaxed">{signal.detail}</p>
          </div>
        )}

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

        <Section label="Healthcare engagement (12 months)">
          <DetailRow label="Visited a dentist" value={formatPct(p.dentist_12m_pct)} />
          <DetailRow
            label="Doctor visits (mean)"
            value={formatNum(p.doctor_visits_mean, 2)}
          />
          <DetailRow
            label="GP contacts (mean)"
            value={formatNum(p.gp_contacts_mean, 2)}
          />
          <DetailRow
            label="Specialist contacts (mean)"
            value={formatNum(p.specialist_contacts_mean, 2)}
          />
          <DetailRow
            label="Forgone care for cost"
            value={formatPct(p.forgone_care_for_cost_pct)}
          />
          <DetailRow label="Hospitalised (any)" value={formatPct(p.hospitalised_pct)} />
        </Section>

        <Section label="Demographics">
          <DetailRow label="Mean age" value={`${p.mean_age_years} years`} />
          <DetailRow label="Female share" value={formatPct(p.share_female)} />
        </Section>

        <p className="text-xs text-zinc-500 leading-relaxed pt-2 border-t border-zinc-100">
          Sources: SHARE Wave 9 release 9.0.0 (fielded 2021–2022) for all
          per-segment metrics; Istat 2024 for the national over-65 projection.
          Confidence intervals: 2,000-iteration percentile bootstrap (seed = 42).
        </p>
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
