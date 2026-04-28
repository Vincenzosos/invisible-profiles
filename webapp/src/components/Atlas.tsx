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

  // Sort by aggregate income desc, hero profiles always first
  const sorted = [...profiles].sort((a, b) => {
    const aHero = HERO_PROFILES.has(a.profile) ? 1 : 0;
    const bHero = HERO_PROFILES.has(b.profile) ? 1 : 0;
    if (aHero !== bHero) return bHero - aHero;
    return (b.aggregate_annual_income_eur_billions ?? 0) -
           (a.aggregate_annual_income_eur_billions ?? 0);
  });

  const heroes = sorted.filter((p) => HERO_PROFILES.has(p.profile));
  const supporting = sorted.filter((p) => !HERO_PROFILES.has(p.profile));

  const totalAggIncome = profiles.reduce(
    (acc, p) => acc + (p.aggregate_annual_income_eur_billions ?? 0),
    0,
  );
  const totalAggWealth = profiles.reduce(
    (acc, p) => acc + (p.aggregate_networth_eur_billions ?? 0),
    0,
  );

  return (
    <section className="space-y-16">
      <header className="space-y-6 max-w-4xl">
        <p className="eyebrow">Atlas · Italy</p>
        <h1 className="display-1 text-slate-900">Five segments. Each one a market.</h1>
        <p className="text-lg text-stone-700 leading-relaxed max-w-3xl">
          The Italian over-65 population partitions into five behaviourally and
          economically distinct profiles. Two of them &mdash; Connected Active
          and Moderate Isolated &mdash; together hold{' '}
          {formatEUR((heroes[0]?.aggregate_networth_eur_billions ?? 0) * 1e9 +
            (heroes[1]?.aggregate_networth_eur_billions ?? 0) * 1e9)}{' '}
          of household wealth. Click any segment for the full profile.
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

      <section className="rounded-2xl bg-white border border-stone-200 p-8">
        <p className="eyebrow">Italy 65+ · totals</p>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 mt-4">
          <Total
            label="Individuals"
            value={formatIndividuals(italy_total_individuals(profiles))}
          />
          <Total label="Annual income flow" value={`€${totalAggIncome.toFixed(1)}B`} />
          <Total
            label="Household net wealth"
            value={`€${(totalAggWealth / 1000).toFixed(2)}T`}
          />
        </div>
      </section>

      {openProfile && (
        <DrilldownModal
          profile={profiles.find((p) => p.profile === openProfile)!}
          onClose={() => setOpenProfile(null)}
        />
      )}
    </section>
  );
}

function italy_total_individuals(profiles: Profile[]): number {
  return profiles.reduce((acc, p) => acc + p.market_size_individuals, 0);
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
        'rounded-2xl bg-white border p-6 space-y-5 hover:border-amber-400 transition-colors cursor-pointer group',
        hero ? 'border-stone-300' : 'border-stone-200',
      ].join(' ')}
      onClick={onOpen}
    >
      <header className="space-y-2">
        <p className="eyebrow">
          {formatPct(p.share_of_country_pct)} · {formatIndividuals(p.market_size_individuals)} individuals
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
          label="Income / yr"
          value={`€${(p.aggregate_annual_income_eur_billions ?? 0).toFixed(1)}B`}
          big={hero}
        />
        <Metric
          label="Net wealth"
          value={`€${(p.aggregate_networth_eur_billions ?? 0).toFixed(0)}B`}
          big={hero}
        />
        <Metric
          label="Median income"
          value={formatEUR(p.median_income_eur, { abbreviated: false })}
        />
        <Metric
          label="Median net worth"
          value={formatEUR(p.median_networth_eur, { abbreviated: false })}
        />
        <Metric label="Internet 7d" value={formatPct(p.internet_pct)} />
        <Metric label="Dentist 12m" value={formatPct(p.dentist_12m_pct)} />
      </div>

      {signal && (
        <p className="text-sm text-stone-700 leading-relaxed border-t border-stone-100 pt-4">
          <span className="font-medium text-slate-900">{signal.headline}</span>
        </p>
      )}

      <p className="text-xs text-amber-700 group-hover:translate-x-1 transition-transform">
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

function Total({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="eyebrow">{label}</p>
      <p className="metric-hero text-slate-900 mt-2">{value}</p>
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
              {formatPct(p.share_of_country_pct)} · {formatIndividuals(p.market_size_individuals)} individuals
            </p>
            <h2 className="display-2 text-slate-900">{p.profile}</h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="text-stone-400 hover:text-slate-900 text-2xl leading-none -mt-1"
            aria-label="Close"
          >
            ×
          </button>
        </header>

        {signal && (
          <div className="rounded-xl bg-amber-50 border border-amber-200 p-5">
            <p className="font-medium text-slate-900 mb-2">
              {signal.headline}
            </p>
            <p className="text-sm text-stone-700 leading-relaxed">{signal.detail}</p>
          </div>
        )}

        <Section label="Market size">
          <DetailRow
            label="Individuals (national projection)"
            value={`${formatIndividuals(p.market_size_individuals)} (${p.market_size_thousands.toFixed(0)}K)`}
          />
          <DetailRow
            label="Aggregate annual income"
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
      <div className="border-t border-stone-200 divide-y divide-stone-100">
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
      <span className="text-sm text-stone-700">{label}</span>
      <span className="text-sm font-medium text-slate-900 text-right tabular-nums">
        {value}
        {ci && (
          <span className="block text-xs text-stone-400 font-normal">
            CI 95%: {ci}
          </span>
        )}
      </span>
    </div>
  );
}
