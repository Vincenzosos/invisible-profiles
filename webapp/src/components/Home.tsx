import killer from '../data/killer_numbers.json';
import { formatIndividuals } from '../lib/format';
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
const fcCostPP = Math.round(
  (italy.forgone_care_for_cost_pct - sweden.forgone_care_for_cost_pct) * 100,
);

export default function Home({ onNavigate }: Props) {
  return (
    <section className="space-y-20">
      <header className="space-y-8 max-w-4xl">
        <p className="eyebrow">Italian Silver Atlas</p>
        <h1 className="display-1 text-slate-900">
          Italy's over-65 population is{' '}
          <span className="text-emerald-700">five segments</span>, not one.
        </h1>
        <p className="text-xl text-zinc-700 leading-relaxed max-w-3xl">
          {formatIndividuals(italy.national_over65_individuals)} individuals served
          today as a single block by insurance, banking, retail, healthcare and
          public administration. Five behaviourally and economically distinct
          segments emerge from a multidimensional segmentation on{' '}
          <a
            className="cite-link"
            href="https://share-eric.eu/data/data-set-details/share-wave-9"
            target="_blank"
            rel="noopener noreferrer"
          >
            SHARE Wave 9
          </a>
          . Sweden serves as the operationally mature benchmark.
        </p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Stat
          eyebrow="Italian over-65 population"
          value={formatIndividuals(italy.national_over65_individuals)}
          context="2024"
          source="Istat, 2024"
          sourceUrl="https://demo.istat.it/"
        />
        <Stat
          eyebrow="SHARE respondents 65+"
          value={`${italy.n_sample.toLocaleString()}`}
          context={`Italian sample, post Mahalanobis screen (Sweden n = ${sweden.n_sample.toLocaleString()})`}
          source="SHARE Wave 9, release 9.0.0"
          sourceUrl="https://share-eric.eu/data/data-set-details/share-wave-9"
        />
        <Stat
          eyebrow="Internet-use gap (Italy → Sweden)"
          value={`+${internetGapPP}pp`}
          context={`Italy ${Math.round(italy.internet_penetration_pct * 100)}% · Sweden ${Math.round(sweden.internet_penetration_pct * 100)}% · SHARE 65+`}
          source="SHARE Wave 9"
          sourceUrl="https://share-eric.eu/data/data-set-details/share-wave-9"
          accent
        />
        <Stat
          eyebrow="12-month dentist gap"
          value={`+${dentalGapPP}pp`}
          context={`Italy ${Math.round(italy.dentist_12m_pct * 100)}% · Sweden ${Math.round(sweden.dentist_12m_pct * 100)}%`}
          source="SHARE Wave 9 healthcare module"
          sourceUrl="https://share-eric.eu/data/data-set-details/share-wave-9"
          accent
        />
        <Stat
          eyebrow="Forgone care for cost"
          value={`+${fcCostPP}pp`}
          context={`Italy ${Math.round(italy.forgone_care_for_cost_pct * 100)}% · Sweden ${Math.round(sweden.forgone_care_for_cost_pct * 100)}%`}
          source="SHARE Wave 9 healthcare module"
          sourceUrl="https://share-eric.eu/data/data-set-details/share-wave-9"
        />
        <Stat
          eyebrow="Mean CASP-12 quality of life"
          value={`${italy.mean_casp.toFixed(1)} ↔ ${sweden.mean_casp.toFixed(1)}`}
          context="Italy vs Sweden over-65 mean (scale 12-48)"
          source="SHARE Wave 9 subjective module"
          sourceUrl="https://share-eric.eu/data/data-set-details/share-wave-9"
        />
      </section>

      <section className="space-y-6">
        <h2 className="display-3 text-slate-900">Three places to start</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <NavCard
            label="Atlas"
            title="The five segments."
            desc="Profile by profile: share, individuals, household income and net worth medians, behavioural and digital depth — all with 95% confidence intervals."
            onClick={() => onNavigate('atlas')}
          />
          <NavCard
            label="Benchmark"
            title="Italy ↔ Sweden gaps."
            desc="Matched-pair gaps in percentage points with confidence intervals. The structural difference between the two welfare regimes, profile by profile."
            onClick={() => onNavigate('benchmark')}
          />
          <NavCard
            label="Opportunity Explorer"
            title="Vertical playbooks."
            desc="Health insurance, wealth management, senior living, pharma. Profile fit + sourced market premium ranges + CRM criteria."
            onClick={() => onNavigate('opportunity')}
          />
        </div>
        <p className="text-sm text-zinc-600 max-w-3xl pt-2">
          Or try the engine on yourself or a customer profile in the{' '}
          <button
            onClick={() => onNavigate('profiler')}
            className="cite-link"
          >
            Profiler &rarr;
          </button>
          {'  ·  '}
          <button
            onClick={() => onNavigate('methods')}
            className="cite-link"
          >
            Methods &amp; data &rarr;
          </button>
        </p>
      </section>
    </section>
  );
}

function Stat({
  eyebrow,
  value,
  context,
  source,
  sourceUrl,
  accent,
}: {
  eyebrow: string;
  value: string;
  context: string;
  source: string;
  sourceUrl?: string;
  accent?: boolean;
}) {
  return (
    <div
      className={[
        'rounded-2xl border p-7 space-y-3',
        accent
          ? 'bg-emerald-50 border-emerald-200'
          : 'bg-white border-zinc-200',
      ].join(' ')}
    >
      <p className="eyebrow">{eyebrow}</p>
      <p
        className={[
          'metric-hero',
          accent ? 'text-emerald-800' : 'text-slate-900',
        ].join(' ')}
      >
        {value}
      </p>
      <p className="text-sm text-zinc-700">{context}</p>
      <p className="text-xs text-zinc-500">
        Source:{' '}
        {sourceUrl ? (
          <a
            href={sourceUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="cite-link"
          >
            {source}
          </a>
        ) : (
          source
        )}
      </p>
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
      className="text-left rounded-2xl bg-white border border-zinc-200 p-6 hover:border-emerald-400 transition-colors group"
    >
      <p className="eyebrow text-emerald-700">{label}</p>
      <p className="display-3 text-slate-900 mt-3">{title}</p>
      <p className="mt-3 text-sm text-zinc-600 leading-relaxed">{desc}</p>
      <p className="mt-5 text-sm text-emerald-700 group-hover:translate-x-1 transition-transform">
        Open &rarr;
      </p>
    </button>
  );
}
