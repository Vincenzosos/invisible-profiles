import killer from '../data/killer_numbers.json';
import sources from '../data/sources.json';
import { formatIndividuals } from '../lib/format';
import type { View } from '../types';

type Props = {
  onNavigate?: (v: View) => void;
};

export default function Methods({ onNavigate }: Props) {
  const it = killer.country_aggregates.italy;
  const se = killer.country_aggregates.sweden;
  return (
    <section className="space-y-12 max-w-4xl">
      <header className="space-y-4">
        <p className="eyebrow">03 · Methodology</p>
        <h1 className="display-1 text-slate-900">How the segmentation was built.</h1>
        <p className="text-lg text-zinc-700 leading-relaxed">
          The Italian Silver Atlas is built on the Survey of Health, Ageing and
          Retirement in Europe (SHARE), Wave&nbsp;9, fielded 2021–2022. Profile
          shares are projected to the national over-65 population using Istat
          (Italy) 2024 totals.
        </p>
      </header>

      <Section title="Sample">
        <Row k="Italian respondents 65+" v={`n = ${it.n_sample}`} />
        <Row k="Swedish respondents 65+" v={`n = ${se.n_sample}`} />
        <Row
          k="Italian over-65 national projection"
          v={formatIndividuals(it.national_over65_individuals)}
        />
        <Row
          k="Swedish over-65 national projection"
          v={formatIndividuals(se.national_over65_individuals)}
        />
      </Section>

      <Section title="Segmentation pipeline">
        <p className="text-sm text-zinc-700 leading-relaxed">
          Thirty-one analytical variables span five conceptual dimensions:
          health (8), economic (5), digital and social (10), cognitive (3),
          subjective wellbeing (5). Eleven are binary; twenty are
          rank-transformed. All are z-standardised. Italy excludes two zero-
          variance items, retaining 29 active variables.
        </p>
        <p className="text-sm text-zinc-700 leading-relaxed">
          Clustering uses K-means with k=5 (Italy) and k=6 (Sweden), 100
          random restarts, fixed seed (42). Latent Class Analysis is fitted
          on tertilised inputs as a probabilistic triangulation: convergence
          rates between K-means and LCA range 49–96% across profiles
          (corner archetypes converge well above chance; middle-stratum
          profiles sit in transitional regions of the latent space where
          boundaries are intrinsically fuzzy).
        </p>
        <p className="text-sm text-zinc-700 leading-relaxed">
          Methodological commitment: subjective wellbeing measures (CASP-12,
          loneliness, hope for the future, interest, expected survival) enter
          the clustering as inputs, not as validation outcomes. The 4D-vs-5D
          sensitivity analysis confirms that removing the subjective block
          reduces external discriminative power on life satisfaction by 41%
          in Italy and 22% in Sweden.
        </p>
      </Section>

      <Section title="Confidence intervals">
        <p className="text-sm text-zinc-700 leading-relaxed">
          Per-profile medians and means are reported with 95% confidence
          intervals from a 2,000-iteration percentile bootstrap (seed = 42).
          Cross-country gap CIs are computed on the difference of means /
          shares across the two SHARE samples, same bootstrap procedure.
        </p>
      </Section>

      <Section title="Profiler engine in the browser">
        <p className="text-sm text-zinc-700 leading-relaxed">
          The Profiler ships the K-means centroids and per-variable raw means
          and standard deviations as a static JSON. The browser computes the
          z-distance from the user's answers to each centroid (hard match =
          closest centroid) and a soft membership distribution as the softmax
          of negative squared distances. The softmax is functionally equivalent
          to the LCA posterior used in the methodology chapters and is
          documented as a deployment approximation.
        </p>
      </Section>

      <Section title="Limitations">
        <ul className="text-sm text-zinc-700 leading-relaxed space-y-2 list-disc pl-5">
          <li>
            Single multiple-imputation replicate: K-means is not invariant
            to imputation noise and consensus algorithms for high-dimensional
            clustering are not yet well established. Bootstrap diagnostics
            quantify the residual sensitivity to the imputation draw.
          </li>
          <li>
            Proxy interviews excluded: biases the typology toward respondents
            capable of self-reporting on the subjective block; the Fragile
            Resigned cluster underestimates the prevalence of the most
            adverse configurations (severe cognitive impairment,
            institutionalisation).
          </li>
          <li>
            Cross-sectional design: SHARE Wave 9 is a snapshot. Cross-wave
            panel stability (W8 ↔ W9) is documented in the Robustness section.
          </li>
          <li>
            Geographic granularity: SHARE does not release sub-national
            geocoding for Italy. Per-region segment shares would require
            integration with Istat regional age-structure tables.
          </li>
          <li>
            Currency: SHARE thinc and hnetw are reported in local currency
            (EUR for Italy; in Sweden harmonised to EUR per SHARE codebook).
            Verified for plausibility against SCB 2022 over-65 median
            household income.
          </li>
        </ul>
      </Section>

      <Section title="Sources">
        <p className="text-sm text-zinc-700 leading-relaxed">
          Primary survey data, official national statistics, industry-
          association reports, and market reviewers. Each visible metric on
          the site cites at least one of the sources below.
        </p>
        <div className="space-y-3 mt-4">
          {sources.sources.map((s) => (
            <article
              key={s.id}
              className="rounded-xl bg-white border border-zinc-200 p-4 space-y-1"
            >
              <div className="flex items-baseline justify-between flex-wrap gap-2">
                <p className="font-medium text-slate-900 text-sm">
                  {s.publisher}
                </p>
                <code className="text-xs bg-zinc-100 px-2 py-0.5 rounded border border-zinc-200 text-zinc-600">
                  {s.id}
                </code>
              </div>
              <p className="text-sm text-zinc-700">{s.title}</p>
              <p className="text-xs text-zinc-500">
                {s.kind} · {s.year}
                {' '}
                · <a
                  href={s.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="cite-link"
                >
                  link
                </a>
              </p>
              <p className="text-xs text-zinc-600 leading-relaxed pt-1">
                <span className="font-medium">Informs:</span> {s.informs}
              </p>
            </article>
          ))}
        </div>
      </Section>

      <Section title="Reproducibility">
        <p className="text-sm text-zinc-700 leading-relaxed">
          The full R pipeline (22 numbered scripts) is available in the GitHub
          repository linked from the footer. Random seeds are fixed throughout.
          Total runtime from raw SHARE files to webapp data: ~40 minutes on a
          standard laptop.
        </p>
      </Section>

      <p className="text-xs text-zinc-500 leading-relaxed pt-4 border-t border-zinc-200">
        <span className="font-medium text-zinc-700">A note on numbers we do not show.</span>{' '}
        Aggregate € figures derived from "median × individual count" formulas
        (e.g. €17,190 × 14.18M = €243.8B) are deliberately removed:
        household-level medians multiplied by individual counts double-count
        multi-senior households and under-state means for skewed distributions.
        Per-segment metrics on the site are direct measurements with
        confidence intervals.
      </p>

      {onNavigate && (
        <button
          type="button"
          onClick={() => onNavigate('profiler')}
          className="block w-full text-left rounded-2xl border border-blue-200 bg-blue-50 hover:bg-blue-100 hover:border-blue-400 transition-colors p-8 group"
        >
          <p className="eyebrow text-blue-700">Continue · 04</p>
          <p className="display-2 text-slate-900 mt-3">
            OK, now try the model.
          </p>
          <p className="mt-3 text-base text-zinc-700 leading-relaxed max-w-3xl">
            Score yourself with fifteen plain-language questions, or upload a CSV
            of your cohort and get the full segmentation in one go: smart
            column mapping, per-row enrichment, cohort vs SHARE benchmark.
          </p>
          <p className="mt-6 text-sm font-medium text-blue-700 group-hover:translate-x-1 transition-transform inline-flex items-center gap-2">
            Try the model →
          </p>
        </button>
      )}
    </section>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="space-y-3">
      <h2 className="display-3 text-slate-900">{title}</h2>
      <div className="space-y-3">{children}</div>
    </section>
  );
}

function Row({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 py-2 border-b border-zinc-100">
      <span className="text-sm text-zinc-700">{k}</span>
      <span className="text-sm font-medium text-slate-900 tabular-nums">{v}</span>
    </div>
  );
}
