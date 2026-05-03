import killer from '../data/killer_numbers.json';
import { formatIndividuals } from '../lib/format';
import type { View } from '../types';
import { Cite } from './Cite';

type Props = {
  onNavigate: (v: View) => void;
};

const italy = killer.country_aggregates.italy;
const sweden = killer.country_aggregates.sweden;

export default function Home({ onNavigate }: Props) {
  return (
    <section className="space-y-20">
      <header className="space-y-8 max-w-4xl">
        <p className="eyebrow">01 · Overview</p>
        <h1 className="display-1 text-slate-900">
          Italy's over-65 population is{' '}
          <span className="text-blue-700">five segments</span>, not one.
        </h1>
        <p className="text-xl text-zinc-700 leading-relaxed max-w-3xl">
          Evidence-based segmentation of the {formatIndividuals(italy.national_over65_individuals)}{' '}
          Italian residents aged 65+, derived from SHARE Wave 9 and
          benchmarked against Sweden. Public reference for academic, policy,
          and analyst audiences.
        </p>
      </header>

      <section className="space-y-6">
        <p className="eyebrow">Findings</p>
        <h2 className="display-2 text-slate-900">
          Three things this segmentation makes visible.
        </h2>
        <div className="space-y-4">
          <Finding
            number="01"
            title="Subjective wellbeing is constitutive of vulnerability, not derived from it."
            evidence={
              <>
                Removing the five subjective variables from the clustering input
                reduces the external ANOVA <em>F</em>-statistic on life
                satisfaction by{' '}
                <Cite
                  metric="External one-way ANOVA F-statistic on life satisfaction (SHARE item AC012, held-out from clustering). Italy 5-dim: 124.6; Italy 4-dim (objective inputs only): 73.8 — a 41% reduction in cluster discrimination on subjective wellbeing."
                  source="SHARE W9, release 9.0.0 · Thesis Ch. 3 §3.7.3, Table 3.4"
                >
                  41% in Italy
                </Cite>{' '}
                (124.6 → 73.8) and{' '}
                <Cite
                  metric="External one-way ANOVA F-statistic on life satisfaction. Sweden 5-dim: 44.3; Sweden 4-dim: 34.6 — a 22% reduction. Smaller than Italy: the subjective block adds less unique discrimination in the Swedish sample."
                  source="SHARE W9, release 9.0.0 · Thesis Ch. 3 §3.7.3, Table 3.4"
                >
                  22% in Sweden
                </Cite>{' '}
                (44.3 → 34.6); the adjusted Rand index between 4D and 5D
                partitions is{' '}
                <Cite
                  metric="Adjusted Rand Index between the 5-dimensional and 4-dimensional cluster partitions (Italy 0.41 / Sweden 0.52). ARI = 1 means identical assignments; ARI = 0 means random. Roughly half of the individual cluster assignments are sensitive to the inclusion of the subjective block."
                  source="SHARE W9 · Thesis Ch. 3 §3.7.3, Table 3.4"
                >
                  0.41 / 0.52
                </Cite>{' '}
                — the two specifications disagree on roughly half of the
                assignments. The 5D solution preserves a Fragile Resigned vs
                Fragile Depressed distinction that the 4D solution collapses.
              </>
            }
            seeMore={{ label: 'See robustness analysis', view: 'robustness' }}
            onNavigate={onNavigate}
          />
          <Finding
            number="02"
            title="A 27% segment of Italian over-65s is invisible to current systems."
            evidence={
              <>
                The Moderate Isolated profile (
                <Cite
                  metric="Moderate Isolated cluster size in the Italian k=5 K-means solution. Largest single archetype by absolute count among the analytical sample (n = 2,378)."
                  source="SHARE W9 · Thesis Ch. 4 §4.3.3 — Moderate Isolated"
                >
                  n = 639, 26.9%
                </Cite>{' '}
                of the Italian sample) reports CASP-12 quality of life of{' '}
                <Cite
                  metric="Mean CASP-12 quality of life raw score (12–48 scale, higher = better). 36.8 places Moderate Isolated above the Italian sample mean — objectively well, yet socially and digitally thin."
                  source="SHARE W9 subjective module · Thesis Ch. 4 §4.7.1 — Empirical signature of the Isolation Paradox"
                >
                  36.8
                </Cite>{' '}
                and{' '}
                <Cite
                  metric="Share of Moderate Isolated reporting any internet use (raw 34.1%). Above the Italian over-65 mean — connectivity is not the binding constraint; social and informational mediation is."
                  source="SHARE W9 social-networks module · Thesis Ch. 4 §4.7.1"
                >
                  34% internet penetration
                </Cite>{' '}
                — objectively healthy and connected — yet visits the dentist{' '}
                <Cite
                  metric="Last-12-months dentist visit rate. Moderate Isolated 21% vs Traditional Social 48% (Δ = −27pp). Forgone-care-for-cost gap between the two profiles is statistically zero, ruling out affordability."
                  source="SHARE W9 healthcare module · Analytical pipeline"
                >
                  27 percentage points less
                </Cite>{' '}
                often than the Traditional Social profile (21% vs 48%) and makes{' '}
                <Cite
                  metric="Mean specialist contacts in past 12 months. Direction matches Thesis Ch. 4 §4.7.2, which reports 0.72 fewer specialist visits per year for Moderate Isolated relative to Traditional Social — systematic disengagement from formal outpatient care."
                  source="SHARE W9 healthcare module · Thesis Ch. 4 §4.7.2 — Healthcare under-utilisation"
                >
                  47% fewer specialist contacts
                </Cite>
                . The gap on forgone care for cost is statistically zero, ruling
                out an affordability explanation.
              </>
            }
            seeMore={{ label: 'See profile in Atlas', view: 'atlas' }}
            onNavigate={onNavigate}
          />
          <Finding
            number="03"
            title="The Italy → Sweden gap concentrates at the vulnerable end of the distribution."
            evidence={
              <>
                Mean CASP-12 difference (Sweden − Italy):{' '}
                <Cite
                  metric="Mean CASP-12 difference, Sweden Fragile − Italy Fragile (matched pair). Positive sign means Swedish counterparts score higher quality of life on the 12–48 scale."
                  source="SHARE W9 subjective module · Cross-country pipeline output"
                >
                  +5.7 points
                </Cite>{' '}
                for the Fragile pair,{' '}
                <Cite
                  metric="Mean CASP-12 difference, Sweden Declining − Italy Declining. Largest welfare gap of the four matched pairs."
                  source="SHARE W9 subjective module · Cross-country pipeline output"
                >
                  +9.6
                </Cite>{' '}
                for the Declining pair,{' '}
                <Cite
                  metric="Mean CASP-12 difference, Sweden Connected − Italy Connected. Modest gap: at the healthy/active end the two systems perform similarly."
                  source="SHARE W9 subjective module · Cross-country pipeline output"
                >
                  +4.3
                </Cite>{' '}
                for the Connected pair, and{' '}
                <Cite
                  metric="Mean CASP-12 difference, Sweden Socially-oriented − Italy Socially-oriented. Negative sign: Italy's family- and community-rich profile slightly outperforms its Swedish counterpart on subjective wellbeing."
                  source="SHARE W9 subjective module · Cross-country pipeline output"
                >
                  −1.4
                </Cite>{' '}
                for the Socially-oriented pair. Internet penetration gap follows
                the same monotonic compression:{' '}
                <Cite
                  metric="Internet penetration percentage-point gap (Sweden − Italy) within the Fragile matched pair. Sweden's universal digital infrastructure reaches even the most vulnerable elderly."
                  source="SHARE W9 social-networks module · Cross-country pipeline output"
                >
                  +55pp for Fragile
                </Cite>
                ,{' '}
                <Cite
                  metric="Internet penetration percentage-point gap (Sweden − Italy) within the Declining matched pair. The widest digital divide of the four matched pairs."
                  source="SHARE W9 social-networks module · Cross-country pipeline output"
                >
                  +81pp for Declining
                </Cite>
                ,{' '}
                <Cite
                  metric="Internet penetration percentage-point gap (Sweden − Italy) within the Connected matched pair. Smallest gap: digitally active elderly converge cross-nationally."
                  source="SHARE W9 social-networks module · Cross-country pipeline output"
                >
                  +24pp for Connected
                </Cite>
                . Universalist welfare compresses the distance between top and
                bottom of the ageing experience.
              </>
            }
            seeMore={{ label: 'See benchmark', view: 'benchmark' }}
            onNavigate={onNavigate}
          />
        </div>
      </section>

      <section className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Stat
          eyebrow="Italian over-65 population"
          value={formatIndividuals(italy.national_over65_individuals)}
          context="Istat 2024 — projected nationally"
          source="Istat, 2024"
          sourceUrl="https://demo.istat.it/"
        />
        <Stat
          eyebrow="SHARE Wave 9 respondents 65+"
          value={`${italy.n_sample.toLocaleString()}`}
          context={`Italian sample · Sweden n = ${sweden.n_sample.toLocaleString()}`}
          source="SHARE Wave 9, release 9.0.0"
        />
        <Stat
          eyebrow="Mean CASP-12 quality of life"
          value={`${italy.mean_casp.toFixed(1)} ↔ ${sweden.mean_casp.toFixed(1)}`}
          context="Italy vs Sweden over-65 (scale 12–48)"
          source="SHARE Wave 9 subjective module"
          accent
        />
      </section>

      <NextStep
        eyebrow="Continue · 02"
        title="Now meet the five segments."
        desc="Each profile in detail: share, household economics, behavioural and digital depth, healthcare engagement, and the matched-pair gap with Sweden."
        cta="The Five Segments"
        onClick={() => onNavigate('atlas')}
      />
    </section>
  );
}

function NextStep({
  eyebrow,
  title,
  desc,
  cta,
  onClick,
}: {
  eyebrow: string;
  title: string;
  desc: string;
  cta: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="block w-full text-left rounded-2xl border border-blue-200 bg-blue-50 hover:bg-blue-100 hover:border-blue-400 transition-colors p-8 group"
    >
      <p className="eyebrow text-blue-700">{eyebrow}</p>
      <p className="display-2 text-slate-900 mt-3">{title}</p>
      <p className="mt-3 text-base text-zinc-700 leading-relaxed max-w-3xl">{desc}</p>
      <p className="mt-6 text-sm font-medium text-blue-700 group-hover:translate-x-1 transition-transform inline-flex items-center gap-2">
        {cta} →
      </p>
    </button>
  );
}

function Finding({
  number,
  title,
  evidence,
  seeMore,
  onNavigate,
}: {
  number: string;
  title: string;
  evidence: React.ReactNode;
  seeMore: { label: string; view: View };
  onNavigate: (v: View) => void;
}) {
  return (
    <article className="rounded-2xl bg-white border border-zinc-200 p-7 space-y-3">
      <div className="flex items-baseline gap-4">
        <span className="text-blue-700 font-mono text-sm tabular-nums">
          {number}
        </span>
        <h3 className="display-3 text-slate-900 flex-1">{title}</h3>
      </div>
      <p className="text-sm text-zinc-700 leading-relaxed pl-10">{evidence}</p>
      <div className="pl-10">
        <button
          type="button"
          onClick={() => onNavigate(seeMore.view)}
          className="cite-link text-sm"
        >
          {seeMore.label} &rarr;
        </button>
      </div>
    </article>
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
          ? 'bg-blue-50 border-blue-200'
          : 'bg-white border-zinc-200',
      ].join(' ')}
    >
      <p className="eyebrow">{eyebrow}</p>
      <p
        className={[
          'metric-hero',
          accent ? 'text-blue-800' : 'text-slate-900',
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
