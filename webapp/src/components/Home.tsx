import killer from '../data/killer_numbers.json';
import { formatEUR, formatIndividuals } from '../lib/format';
import type { View } from '../types';

type Props = {
  onNavigate: (v: View) => void;
};

const italy = killer.country_aggregates.italy;
const sweden = killer.country_aggregates.sweden;

export default function Home({ onNavigate }: Props) {
  return (
    <section className="space-y-12">
      <header className="space-y-4 max-w-3xl">
        <p className="text-xs uppercase tracking-wide text-slate-500">
          Silver economy intelligence · Italy + Sweden
        </p>
        <h1 className="text-4xl sm:text-5xl font-semibold tracking-tight text-slate-900 leading-tight">
          The first evidence-based map of Italy's silver economy.
        </h1>
        <p className="text-lg text-slate-700 leading-relaxed">
          Italy hosts {formatIndividuals(italy.national_over65_individuals)} individuals
          aged 65+ — a heterogeneous segment worth{' '}
          <span className="font-medium text-slate-900">
            {formatEUR(italy.aggregate_annual_income_flow_eur)} in annual household income flow
          </span>{' '}
          and{' '}
          <span className="font-medium text-slate-900">
            {formatEUR(italy.aggregate_household_networth_eur)} in household net wealth
          </span>
          . The current service infrastructure treats it as a monolithic block. This
          tool partitions it into {killer.italy_profiles.length} distinct,
          methodologically rigorous segments and benchmarks each one against Sweden,
          Europe's most operationally mature elderly-services market.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Stat
          label="Italian over-65 segment"
          big={formatEUR(italy.aggregate_annual_income_flow_eur_billions * 1e9)}
          sub="aggregate annual household income flow"
          source={`${formatIndividuals(italy.national_over65_individuals)} individuals · Istat 2024`}
        />
        <Stat
          label="Aggregate household wealth"
          big={formatEUR(italy.aggregate_household_networth_eur_trillions * 1e12)}
          sub="aggregate household net worth"
          source="SHARE W9 median × Istat 2024 over-65 total"
        />
        <Stat
          label="Internet penetration gap"
          big={`${Math.round((sweden.internet_penetration_pct - italy.internet_penetration_pct) * 100)}pp`}
          sub={`Sweden ${Math.round(sweden.internet_penetration_pct * 100)}% vs Italy ${Math.round(italy.internet_penetration_pct * 100)}%`}
          source="Digital reach headroom for Italian operators"
        />
        <Stat
          label="Preventive dental gap"
          big={`${Math.round((sweden.dentist_12m_pct - italy.dentist_12m_pct) * 100)}pp`}
          sub={`Sweden ${Math.round(sweden.dentist_12m_pct * 100)}% vs Italy ${Math.round(italy.dentist_12m_pct * 100)}% (12m)`}
          source="Private dental insurance opportunity"
        />
      </section>

      <section className="grid grid-cols-1 sm:grid-cols-2 gap-3 max-w-4xl">
        <NavCard
          title="Atlas"
          desc="5 Italian profiles with size in €/individuals, economic depth, behavioural and digital profile, and business signal per segment."
          onClick={() => onNavigate('atlas')}
        />
        <NavCard
          title="Benchmark"
          desc="Italy ↔ Sweden matched-pair gap with opportunity ranking by € addressable headroom."
          onClick={() => onNavigate('benchmark')}
        />
        <NavCard
          title="Opportunity Explorer"
          desc="Vertical playbooks for health insurance, wealth management, senior living, and pharma marketing."
          onClick={() => onNavigate('opportunity')}
        />
        <NavCard
          title="Profiler (demo)"
          desc="10-question quiz returning hard match + soft membership distribution. Showcase of the engine."
          onClick={() => onNavigate('profiler')}
        />
      </section>

      <footer className="border-t border-slate-200 pt-8 text-xs text-slate-500 max-w-3xl space-y-1.5 leading-relaxed">
        <p>
          Method: K-means clustering with k=5 on 29 standardised SHARE W9 indicators
          (Italy n={italy.n_sample}); k=6 on 31 indicators (Sweden n={sweden.n_sample}). Profiles
          validated by Latent Class Analysis triangulation, multi-algorithm robustness
          and 4D-vs-5D sensitivity (chapter 6 of the underlying thesis).
        </p>
        <p>
          National projections use Istat 2024 over-65 total ({formatIndividuals(italy.national_over65_individuals)})
          and SCB 2024 over-65 total ({formatIndividuals(sweden.national_over65_individuals)}). Income and net-worth
          aggregates are SHARE-derived medians × national counts; income figures are
          treated as EUR (SHARE harmonised).
        </p>
        <p>
          Confidence intervals at 95% reported per profile in Atlas. Source data:
          SHARE Wave 9 release 9.0.0, fielded 2021–2022. Last refresh:{' '}
          {killer.meta.generated_at_utc.slice(0, 10)}.
        </p>
      </footer>
    </section>
  );
}

function Stat({
  label,
  big,
  sub,
  source,
}: {
  label: string;
  big: string;
  sub: string;
  source: string;
}) {
  return (
    <div className="rounded-2xl bg-white border border-slate-200 p-6 space-y-1">
      <p className="text-xs uppercase tracking-wide text-slate-500">{label}</p>
      <p className="text-3xl font-semibold tracking-tight text-slate-900 tabular-nums">
        {big}
      </p>
      <p className="text-sm text-slate-700">{sub}</p>
      <p className="text-xs text-slate-400 pt-1">{source}</p>
    </div>
  );
}

function NavCard({
  title,
  desc,
  onClick,
}: {
  title: string;
  desc: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="text-left rounded-2xl bg-white border border-slate-200 p-5 hover:border-slate-400 hover:bg-slate-50 transition-colors"
    >
      <p className="font-medium text-slate-900">{title}</p>
      <p className="mt-1.5 text-sm text-slate-600 leading-relaxed">{desc}</p>
      <p className="mt-3 text-xs text-slate-500">Open →</p>
    </button>
  );
}
