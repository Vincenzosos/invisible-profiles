import killer from '../data/killer_numbers.json';
import sources from '../data/sources.json';
import { formatIndividuals } from '../lib/format';

export default function Methods() {
  const it = killer.country_aggregates.italy;
  const se = killer.country_aggregates.sweden;
  return (
    <section className="space-y-12 max-w-4xl">
      <header className="space-y-4">
        <p className="eyebrow">Methods & data</p>
        <h1 className="display-1 text-slate-900">How we built this</h1>
        <p className="text-lg text-zinc-700 leading-relaxed">
          The Italian Silver Atlas is built on the Survey of Health, Ageing and
          Retirement in Europe (SHARE), Wave&nbsp;9, fielded 2021–2022. Profile
          shares are projected to the national over-65 population using
          Istat (Italy) 2024 totals. Per-segment metrics are direct
          measurements; aggregate € figures derived from "median × individual
          count" formulas have been deliberately removed because their
          methodology cannot be defended cell-by-cell.
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
          rates between K-means and LCA range 60–96% across profiles.
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

      <Section title="Numbers we deliberately do not show">
        <p className="text-sm text-zinc-700 leading-relaxed">
          We could compute aggregate € figures by multiplying SHARE-derived
          per-household medians by Istat individual counts (e.g. €17,190 ×
          14.18M = €243.8B). We choose not to display these numbers because
          their methodology has documented bias: medians under-state means
          for skewed distributions, and household-level values multiplied by
          individual counts double-count multi-senior households.
        </p>
        <p className="text-sm text-zinc-700 leading-relaxed">
          We also do not display single-point opportunity €. Sizing requires
          conversion-rate and penetration assumptions that are vertical-
          specific elasticity questions, not stable industry constants. The
          Opportunity Explorer reports{' '}
          <span className="font-medium">sourced market premium ranges</span>{' '}
          (e.g. €150–500 / year for Italian individual senior dental
          insurance) and the segment size in individuals; the operator
          multiplying these against their own conversion model is the right
          place for that calculation.
        </p>
      </Section>

      <Section title="Sourced market premium ranges">
        <p className="text-sm text-zinc-700 leading-relaxed">
          Where the Opportunity Explorer surfaces a € range, it comes from
          one of the published sources below. Ranges are reported as data
          points, not as multiplicands.
        </p>
        <div className="rounded-xl bg-zinc-50 border border-zinc-200 p-4 mt-3">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left border-b border-zinc-200">
                <th className="py-2 pr-3 eyebrow">Item</th>
                <th className="py-2 pr-3 eyebrow text-right">Range</th>
                <th className="py-2 pr-3 eyebrow">Sources</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              <tr>
                <td className="py-2 pr-3 text-slate-900">Senior individual dental insurance</td>
                <td className="py-2 pr-3 text-right tabular-nums">€150–500 / yr</td>
                <td className="py-2 pr-3 text-xs text-zinc-600">ANIA, ANDI, GIMBE</td>
              </tr>
              <tr>
                <td className="py-2 pr-3 text-slate-900">Private specialist consultation</td>
                <td className="py-2 pr-3 text-right tabular-nums">€100–450 / yr</td>
                <td className="py-2 pr-3 text-xs text-zinc-600">Censis 2024, market reviewers</td>
              </tr>
              <tr>
                <td className="py-2 pr-3 text-slate-900">Senior OTC + adherence per individual</td>
                <td className="py-2 pr-3 text-right tabular-nums">€60–180 / yr</td>
                <td className="py-2 pr-3 text-xs text-zinc-600">AIFA OsMed</td>
              </tr>
              <tr>
                <td className="py-2 pr-3 text-slate-900">Wealth-management all-in fee</td>
                <td className="py-2 pr-3 text-right tabular-nums">0.5–1.5% AUM / yr</td>
                <td className="py-2 pr-3 text-xs text-zinc-600">AIPB, asset_mgmt_fees</td>
              </tr>
              <tr>
                <td className="py-2 pr-3 text-slate-900">RSA / senior living monthly</td>
                <td className="py-2 pr-3 text-right tabular-nums">€1,500–3,000 / mo</td>
                <td className="py-2 pr-3 text-xs text-zinc-600">RSA market 2024</td>
              </tr>
            </tbody>
          </table>
        </div>
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
            Cross-sectional design: SHARE Wave 9 is a snapshot. Cross-wave
            replication is documented as future work.
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
          <li>
            Customer-level integration (CSV import, API scoring) is documented
            as architecture in chapter 8 of the underlying thesis but not
            implemented in this build.
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
          The full R pipeline (22 numbered scripts) and the Python market-
          sizing script (<code className="text-xs bg-zinc-100 rounded px-1.5 py-0.5">
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
    <div className="flex items-baseline justify-between gap-4 py-2 border-b border-zinc-100">
      <span className="text-sm text-zinc-700">{k}</span>
      <span className="text-sm font-medium text-slate-900 tabular-nums">{v}</span>
    </div>
  );
}
