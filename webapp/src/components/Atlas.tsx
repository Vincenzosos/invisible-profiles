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

export default function Atlas() {
  const [openProfile, setOpenProfile] = useState<string | null>(null);
  const profiles = killer.italy_profiles;
  const country = killer.country_aggregates.italy;

  const totalAggIncome = profiles.reduce(
    (acc, p) => acc + (p.aggregate_annual_income_eur_billions ?? 0),
    0,
  );
  const totalAggWealth = profiles.reduce(
    (acc, p) => acc + (p.aggregate_networth_eur_billions ?? 0),
    0,
  );
  const totalSize = profiles.reduce((acc, p) => acc + p.market_size_individuals, 0);

  return (
    <section className="space-y-8">
      <header className="space-y-3 max-w-4xl">
        <p className="text-xs uppercase tracking-wide text-slate-500">
          Atlas · Italy · 5 segments
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-slate-900">
          The five segments of the Italian over-65 population
        </h1>
        <p className="text-slate-700 leading-relaxed">
          Each segment is sized in individuals (Istat 2024 × SHARE share),
          income (€B aggregate annual flow), and household net wealth (€B
          aggregate). All metrics carry 95% bootstrap confidence intervals.
          Click a card for the full 31-indicator drilldown.
        </p>
      </header>

      <section className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-4">
        {profiles.map((p) => (
          <ProfileCard
            key={p.profile}
            p={p}
            onOpen={() => setOpenProfile(p.profile)}
          />
        ))}
      </section>

      <footer className="rounded-2xl bg-white border border-slate-200 p-6">
        <p className="text-xs uppercase tracking-wide text-slate-500 mb-2">
          Italy · 65+ silver economy total
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <Total label="Individuals" value={formatIndividuals(totalSize)} />
          <Total
            label="Aggregate annual income"
            value={`€${totalAggIncome.toFixed(1)}B`}
          />
          <Total
            label="Aggregate household wealth"
            value={`€${(totalAggWealth / 1000).toFixed(2)}T`}
          />
        </div>
        <p className="text-xs text-slate-500 mt-4 leading-relaxed">
          Country median household income: {formatEUR(country.median_household_income_eur, { abbreviated: false })} per year ·{' '}
          median household net wealth:{' '}
          {formatEUR(country.median_household_networth_eur, { abbreviated: false })}.
          Profile shares estimated on SHARE W9 (n = {country.n_sample});
          population projection uses Istat over-65 total (Italy, 2024).
        </p>
      </footer>

      {openProfile && (
        <DrilldownModal
          profile={profiles.find((p) => p.profile === openProfile)!}
          onClose={() => setOpenProfile(null)}
        />
      )}
    </section>
  );
}

function ProfileCard({ p, onOpen }: { p: Profile; onOpen: () => void }) {
  const signal = ITALY_BUSINESS_SIGNALS[p.profile] ?? null;
  return (
    <article className="rounded-2xl bg-white border border-slate-200 p-5 space-y-4 hover:shadow-md transition-shadow">
      <header className="space-y-1">
        <h2 className="text-lg font-semibold tracking-tight text-slate-900">
          {p.profile}
        </h2>
        <p className="text-xs text-slate-500">
          {formatPct(p.share_of_country_pct)} of Italian over-65 ·{' '}
          {formatIndividuals(p.market_size_individuals)} individuals · sample n =
          {' '}
          {p.n_sample}
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 text-sm">
        <Metric
          label="Median income"
          value={formatEUR(p.median_income_eur, { abbreviated: false })}
        />
        <Metric
          label="Median net worth"
          value={formatEUR(p.median_networth_eur, { abbreviated: false })}
        />
        <Metric
          label="Aggregate income"
          value={`€${(p.aggregate_annual_income_eur_billions ?? 0).toFixed(1)}B/y`}
        />
        <Metric
          label="Aggregate wealth"
          value={`€${(p.aggregate_networth_eur_billions ?? 0).toFixed(0)}B`}
        />
        <Metric
          label="Internet 7d"
          value={formatPct(p.internet_pct)}
        />
        <Metric
          label="Home owners"
          value={formatPct(p.homeownership_pct)}
        />
        <Metric label="CASP-12" value={formatNum(p.casp_mean, 1)} />
        <Metric
          label="Dentist 12m"
          value={formatPct(p.dentist_12m_pct)}
        />
      </section>

      {signal && (
        <div className="rounded-xl bg-slate-50 border border-slate-200 p-3 text-xs text-slate-700">
          <p className="font-medium text-slate-900 mb-1">{signal.headline}</p>
          <p className="leading-relaxed">{signal.detail}</p>
        </div>
      )}

      <button
        type="button"
        onClick={onOpen}
        className="text-sm text-slate-700 hover:text-slate-900 underline-offset-4 hover:underline"
      >
        Full segment drilldown →
      </button>
    </article>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs text-slate-500">{label}</p>
      <p className="font-medium text-slate-900 tabular-nums">{value}</p>
    </div>
  );
}

function Total({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs uppercase text-slate-500 tracking-wide">{label}</p>
      <p className="text-2xl font-semibold tracking-tight text-slate-900 tabular-nums">
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
        className="bg-white rounded-2xl max-w-3xl w-full p-6 sm:p-8 shadow-xl space-y-6 mt-4 sm:mt-0"
        onClick={(e) => e.stopPropagation()}
      >
        <header className="flex items-start justify-between gap-4">
          <div className="space-y-1">
            <p className="text-xs uppercase tracking-wide text-slate-500">
              Italy · {p.profile}
            </p>
            <h2 className="text-2xl font-semibold tracking-tight text-slate-900">
              {p.profile}
            </h2>
            <p className="text-sm text-slate-600">
              Sample n = {p.n_sample} · {formatPct(p.share_of_country_pct)} of country ·{' '}
              {formatIndividuals(p.market_size_individuals)} individuals nationally
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="text-slate-500 hover:text-slate-900 text-xl leading-none -mt-1"
            aria-label="Close"
          >
            ×
          </button>
        </header>

        {signal && (
          <div className="rounded-xl bg-amber-50 border border-amber-200 p-4 text-sm">
            <p className="font-medium text-slate-900 mb-1">
              Business signal: {signal.headline}
            </p>
            <p className="text-slate-700 leading-relaxed">{signal.detail}</p>
          </div>
        )}

        <Section label="Market size">
          <DetailRow label="Sample share" value={formatPct(p.share_of_country_pct)} />
          <DetailRow
            label="Individuals (national projection)"
            value={`${formatIndividuals(p.market_size_individuals)} (${p.market_size_thousands.toFixed(0)}K)`}
          />
          <DetailRow
            label="Aggregate annual income flow"
            value={`€${p.aggregate_annual_income_eur_billions}B`}
          />
          <DetailRow
            label="Aggregate household net wealth"
            value={`€${p.aggregate_networth_eur_billions.toFixed(1)}B`}
          />
        </Section>

        <Section label="Economic snapshot">
          <DetailRow
            label="Median household income"
            value={formatEUR(p.median_income_eur, { abbreviated: false })}
            ci={`CI 95%: ${formatEUR(p.median_income_eur_ci[0], { abbreviated: false })}–${formatEUR(p.median_income_eur_ci[1], { abbreviated: false })}`}
          />
          <DetailRow
            label="Median household net worth"
            value={formatEUR(p.median_networth_eur, { abbreviated: false })}
            ci={`CI 95%: ${formatEUR(p.median_networth_eur_ci[0], { abbreviated: false })}–${formatEUR(p.median_networth_eur_ci[1], { abbreviated: false })}`}
          />
          <DetailRow
            label="Median pension income"
            value={formatEUR(p.median_pension_eur, { abbreviated: false })}
          />
          <DetailRow
            label="Home owners"
            value={formatPct(p.homeownership_pct)}
          />
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
            label="Verbal fluency (animals/60s, mean)"
            value={formatNum(p.fluency_mean, 1)}
          />
          <DetailRow
            label="CASP-12 quality of life (mean)"
            value={formatNum(p.casp_mean, 2)}
            ci={`CI 95%: ${p.casp_mean_ci[0].toFixed(2)}–${p.casp_mean_ci[1].toFixed(2)}`}
          />
          <DetailRow
            label="Life satisfaction 0-10 (mean)"
            value={formatNum(p.lifesat_mean, 2)}
          />
          <DetailRow
            label="Hope for the future"
            value={formatPct(p.hope_future_pct)}
          />
          <DetailRow
            label="EURO-D depression score (mean)"
            value={formatNum(p.eurod_mean, 2)}
          />
        </Section>

        <Section label="Healthcare engagement (12 months)">
          <DetailRow
            label="Visited a dentist"
            value={formatPct(p.dentist_12m_pct)}
          />
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
          <DetailRow
            label="Hospitalised (any)"
            value={formatPct(p.hospitalised_pct)}
          />
        </Section>

        <Section label="Demographics">
          <DetailRow label="Mean age" value={`${p.mean_age_years} years`} />
          <DetailRow label="Female share" value={formatPct(p.share_female)} />
        </Section>

        <p className="text-xs text-slate-500 leading-relaxed">
          Source: SHARE Wave 9 release 9.0.0. National projection uses Istat 2024
          over-65 total (14.18M individuals). Confidence intervals from 2,000-iter
          percentile bootstrap.
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
    <section className="space-y-2">
      <h3 className="text-xs uppercase tracking-wide text-slate-500 font-medium">
        {label}
      </h3>
      <div className="border-t border-slate-200 divide-y divide-slate-100">
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
    <div className="flex items-baseline justify-between py-2 gap-4">
      <span className="text-sm text-slate-700">{label}</span>
      <span className="text-sm font-medium text-slate-900 text-right tabular-nums">
        {value}
        {ci && (
          <span className="block text-xs text-slate-500 font-normal">{ci}</span>
        )}
      </span>
    </div>
  );
}
