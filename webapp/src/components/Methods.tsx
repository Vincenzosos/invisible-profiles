import killer from '../data/killer_numbers.json';
import { formatIndividuals } from '../lib/format';

export default function Methods() {
  const it = killer.country_aggregates.italy;
  const se = killer.country_aggregates.sweden;
  return (
    <section className="space-y-12 max-w-3xl">
      <header className="space-y-4">
        <p className="eyebrow">Methods & data</p>
        <h1 className="display-1 text-slate-900">How we built this</h1>
        <p className="text-lg text-stone-700 leading-relaxed">
          The Italian Silver Atlas is built on the Survey of Health, Ageing and
          Retirement in Europe (SHARE), Wave 9, fielded 2021–2022. The
          segmentation is fitted on the SHARE sample and projected to the
          national over-65 population using Istat (Italy) and SCB (Sweden) 2024
          totals.
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
        <Row k="Source" v="SHARE Wave 9 release 9.0.0; Istat 2024; SCB 2024" />
      </Section>

      <Section title="Segmentation pipeline">
        <p className="text-sm text-stone-700 leading-relaxed">
          Thirty-one analytical variables span five conceptual dimensions:
          health (8), economic (5), digital and social (10), cognitive (3),
          subjective wellbeing (5). Eleven are binary; twenty are
          rank-transformed. All are z-standardised. Italy excludes two zero-
          variance items, retaining 29 active variables.
        </p>
        <p className="text-sm text-stone-700 leading-relaxed">
          Clustering uses K-means with k=5 (Italy) and k=6 (Sweden), 100 random
          restarts, fixed seed (42). Latent Class Analysis is fitted on
          tertilised inputs as a probabilistic triangulation: convergence rates
          between K-means and LCA range 60–96% across profiles.
        </p>
        <p className="text-sm text-stone-700 leading-relaxed">
          Methodological commitment: subjective wellbeing measures (CASP-12,
          loneliness, hope for the future, interest, expected survival) enter
          the clustering as inputs, not as validation outcomes. The 4D-vs-5D
          sensitivity analysis confirms that removing the subjective block
          reduces external discriminative power on life satisfaction by 41%
          in Italy and 22% in Sweden.
        </p>
      </Section>

      <Section title="Confidence intervals">
        <p className="text-sm text-stone-700 leading-relaxed">
          Per-profile medians and means are reported with 95% confidence
          intervals from a 2,000-iteration percentile bootstrap (seed = 42).
          Aggregates (€ income flow, € net wealth) are point estimates equal
          to the SHARE-derived per-profile median multiplied by the Istat /
          SCB 2024 national over-65 count and the SHARE-derived profile share.
        </p>
      </Section>

      <Section title="Cross-country opportunity sizing">
        <p className="text-sm text-stone-700 leading-relaxed">
          For each matched pair (Italy ↔ Sweden) we compute the gap on
          dimensions where uptake monetisation has a defensible single-anchor
          proxy: dental coverage at €80 / individual / year, private specialist
          consultation at €130 / individual / year. Opportunity size = max(0,
          Sweden − Italy gap) × Italian segment size × € per uptake. Time-to-
          maturity uses a 1pp / year linear-closure assumption for digital
          indicators, calibrated against Eurostat ICT-individuals 2018–2024
          Italy trend. These are board-memo orientation proxies, not
          commercial pricing.
        </p>
      </Section>

      <Section title="Profiler engine in the browser">
        <p className="text-sm text-stone-700 leading-relaxed">
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
        <ul className="text-sm text-stone-700 leading-relaxed space-y-2 list-disc pl-5">
          <li>
            Cross-sectional design: SHARE Wave 9 is a snapshot. Time-to-maturity
            estimates use linear extrapolation pending cross-wave calibration.
          </li>
          <li>
            Geographic granularity: SHARE does not release sub-national
            geocoding for Italy. Per-region segment shares would require
            integration with Istat regional age-structure tables.
          </li>
          <li>
            Willingness-to-pay is proxied via income, net worth and financial
            distress. Commercial pricing requires vertical-specific elasticity
            work.
          </li>
          <li>
            Customer-level integration (CSV import, API scoring) is documented
            as architecture in chapter 8 of the underlying thesis but not
            implemented in this build.
          </li>
        </ul>
      </Section>

      <Section title="Reproducibility">
        <p className="text-sm text-stone-700 leading-relaxed">
          The full R pipeline (22 numbered scripts) and the Python market-
          sizing script (<code className="text-xs bg-stone-100 rounded px-1.5 py-0.5">
            v9/23_killer_numbers.py
          </code>) are available in the GitHub repository linked from the
          footer. Random seeds are fixed throughout. Total runtime from raw
          SHARE files to webapp data: ~40 minutes on a standard laptop.
        </p>
      </Section>
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
    <div className="flex items-baseline justify-between gap-4 py-2 border-b border-stone-100">
      <span className="text-sm text-stone-700">{k}</span>
      <span className="text-sm font-medium text-slate-900 tabular-nums">{v}</span>
    </div>
  );
}
