import killer from '../data/killer_numbers.json';
import { formatEUR, formatIndividuals } from '../lib/format';
import type { View } from '../types';

type Props = {
  onNavigate: (v: View) => void;
};

const italy = killer.country_aggregates.italy;
const sweden = killer.country_aggregates.sweden;
const internetGapPP = Math.round(
  (sweden.internet_penetration_pct - italy.internet_penetration_pct) * 100,
);
const dentalGapPP = Math.round(
  (sweden.dentist_12m_pct - italy.dentist_12m_pct) * 100,
);

export default function Home({ onNavigate }: Props) {
  return (
    <section className="space-y-20">
      <header className="space-y-8 max-w-4xl">
        <p className="eyebrow">Italian Silver Atlas</p>
        <h1 className="display-1 text-slate-900">
          Italy's silver economy is{' '}
          <span className="text-amber-700">€2.3 trillion</span>.
          <br />
          The current service infrastructure can't see it.
        </h1>
        <p className="text-xl text-stone-700 leading-relaxed max-w-3xl">
          {formatIndividuals(italy.national_over65_individuals)} individuals
          aged&nbsp;65+, served as a single block by insurance, banking,
          retail, healthcare and public administration. They are not one block.
          They are five distinct segments &mdash; with different economics,
          digital reach, healthcare engagement and willingness to pay.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Hero
          eyebrow="Annual income flow"
          value={formatEUR(italy.aggregate_annual_income_flow_eur)}
          context={`across ${formatIndividuals(italy.national_over65_individuals)} individuals`}
        />
        <Hero
          eyebrow="Household net wealth"
          value={formatEUR(italy.aggregate_household_networth_eur)}
          context="property, savings, financial assets"
        />
        <Hero
          eyebrow="Internet gap to Sweden"
          value={`+${internetGapPP}pp`}
          context={`Italy ${Math.round(italy.internet_penetration_pct * 100)}% · Sweden ${Math.round(sweden.internet_penetration_pct * 100)}%`}
          accent
        />
        <Hero
          eyebrow="Preventive dental gap"
          value={`+${dentalGapPP}pp`}
          context={`Italy ${Math.round(italy.dentist_12m_pct * 100)}% · Sweden ${Math.round(sweden.dentist_12m_pct * 100)}%`}
          accent
        />
      </section>

      <section className="space-y-6">
        <h2 className="display-3 text-slate-900">Three places to start</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <NavCard
            label="Atlas"
            title="Five segments, sized."
            desc="Each profile in individuals, € of income, € of wealth, with full economic and behavioural depth."
            onClick={() => onNavigate('atlas')}
          />
          <NavCard
            label="Benchmark"
            title="Italy ↔ Sweden, where it pays."
            desc="Matched-pair gaps ranked by addressable opportunity in €. Sweden as the operationally mature comparator."
            onClick={() => onNavigate('benchmark')}
          />
          <NavCard
            label="Opportunity Explorer"
            title="Pick a vertical. Get the play."
            desc="Health insurance, wealth management, senior living, pharma. Targets, channels, CRM criteria."
            onClick={() => onNavigate('opportunity')}
          />
        </div>
        <p className="text-sm text-stone-600 max-w-3xl pt-2">
          Or try the engine on yourself or a customer profile in the{' '}
          <button
            onClick={() => onNavigate('profiler')}
            className="text-amber-700 hover:underline underline-offset-4"
          >
            Profiler &rarr;
          </button>
        </p>
      </section>
    </section>
  );
}

function Hero({
  eyebrow,
  value,
  context,
  accent,
}: {
  eyebrow: string;
  value: string;
  context: string;
  accent?: boolean;
}) {
  return (
    <div
      className={[
        'rounded-2xl border p-8 space-y-3',
        accent
          ? 'bg-amber-50 border-amber-200'
          : 'bg-white border-stone-200',
      ].join(' ')}
    >
      <p className="eyebrow">{eyebrow}</p>
      <p
        className={[
          'metric-hero',
          accent ? 'text-amber-800' : 'text-slate-900',
        ].join(' ')}
      >
        {value}
      </p>
      <p className="text-sm text-stone-600">{context}</p>
    </div>
  );
}

function NavCard({
  label,
  title,
  desc,
  onClick,
}: {
  label: string;
  title: string;
  desc: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="text-left rounded-2xl bg-white border border-stone-200 p-6 hover:border-amber-400 transition-colors group"
    >
      <p className="eyebrow text-amber-700">{label}</p>
      <p className="display-3 text-slate-900 mt-3">{title}</p>
      <p className="mt-3 text-sm text-stone-600 leading-relaxed">{desc}</p>
      <p className="mt-5 text-sm text-amber-700 group-hover:translate-x-1 transition-transform">
        Open &rarr;
      </p>
    </button>
  );
}
