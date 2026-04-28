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
        <p className="text-lg text-stone-700 leading-relaxed">
          The Italian Silver Atlas is built on the Survey of Health, Ageing and
          Retirement in Europe (SHARE), Wave&nbsp;9, fielded 2021–2022. Profile
          shares are projected to the national over-65 population using Istat
          (Italy) and SCB (Sweden) 2024 totals. Opportunity sizing uses
          €-per-uptake ranges sourced from public Italian and European
          authorities listed in the bibliography below.
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

      <Section title="Opportunity sizing — sourced ranges">
        <p className="text-sm text-stone-700 leading-relaxed">
          For each matched pair (Italy ↔ Sweden) we compute the gap on
          dimensions where uptake monetisation has a defensible €-per-uptake
          range. Each range is derived from public Italian and European
          authorities (full bibliography below):
        </p>
        <div className="rounded-xl bg-stone-50 border border-stone-200 p-4 mt-3">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left border-b border-stone-200">
                <th className="py-2 pr-3 eyebrow">Dimension</th>
                <th className="py-2 pr-3 eyebrow text-right">Low</th>
                <th className="py-2 pr-3 eyebrow text-right">Central</th>
                <th className="py-2 pr-3 eyebrow text-right">High</th>
                <th className="py-2 pr-3 eyebrow">Sources</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-stone-100">
              <tr>
                <td className="py-2 pr-3 text-stone-900">Dental insurance / yr</td>
                <td className="py-2 pr-3 text-right tabular-nums">€150</td>
                <td className="py-2 pr-3 text-right tabular-nums font-semibold">€300</td>
                <td className="py-2 pr-3 text-right tabular-nums">€500</td>
                <td className="py-2 pr-3 text-xs text-stone-600">
                  ANIA, ANDI, GIMBE
                </td>
              </tr>
              <tr>
                <td className="py-2 pr-3 text-stone-900">Specialist consult / yr</td>
                <td className="py-2 pr-3 text-right tabular-nums">€100</td>
                <td className="py-2 pr-3 text-right tabular-nums font-semibold">€250</td>
                <td className="py-2 pr-3 text-right tabular-nums">€450</td>
                <td className="py-2 pr-3 text-xs text-stone-600">
                  Censis, market reviewers
                </td>
              </tr>
              <tr>
                <td className="py-2 pr-3 text-stone-900">OTC / pharma adherence / yr</td>
                <td className="py-2 pr-3 text-right tabular-nums">€60</td>
                <td className="py-2 pr-3 text-right tabular-nums font-semibold">€100</td>
                <td className="py-2 pr-3 text-right tabular-nums">€180</td>
                <td className="py-2 pr-3 text-xs text-stone-600">AIFA OsMed</td>
              </tr>
              <tr>
                <td className="py-2 pr-3 text-stone-900">Wealth mgmt all-in fee / yr</td>
                <td className="py-2 pr-3 text-right tabular-nums">0.5%</td>
                <td className="py-2 pr-3 text-right tabular-nums font-semibold">1.0%</td>
                <td className="py-2 pr-3 text-right tabular-nums">1.5%</td>
                <td className="py-2 pr-3 text-xs text-stone-600">AIPB, asset_mgmt_fees</td>
              </tr>
              <tr>
                <td className="py-2 pr-3 text-stone-900">Senior living / month</td>
                <td className="py-2 pr-3 text-right tabular-nums">€1,500</td>
                <td className="py-2 pr-3 text-right tabular-nums font-semibold">€2,000</td>
                <td className="py-2 pr-3 text-right tabular-nums">€3,000</td>
                <td className="py-2 pr-3 text-xs text-stone-600">RSA market 2024</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p className="text-sm text-stone-700 leading-relaxed mt-3">
          Opportunity size = max(0, gap) × Italian segment size × premium /
          fee. Three scenarios (low / central / high) are computed for each
          opportunity and surfaced in the Benchmark and Opportunity Explorer
          views.
        </p>
      </Section>

      <Section title="Time-to-maturity — Eurostat-calibrated">
        <p className="text-sm text-stone-700 leading-relaxed">
          Italy's 65–74 internet-use rate moved from 60.4% (2023) to 65.6%
          (2024) per Eurostat, a +5.2 pp / year jump that reflects post-pandemic
          acceleration. The pre-pandemic trend (2018-2022) was closer to +2 to
          +3 pp / year. Sweden's 65–74 rate is approximately 87%. Three rate
          scenarios are reported:
        </p>
        <ul className="text-sm text-stone-700 leading-relaxed space-y-1 list-disc pl-5">
          <li>conservative 1 pp / year ≈ {killer.time_to_maturity.estimates_years_to_close.internet_overall.high} years to close the gap</li>
          <li>central 3 pp / year ≈ {killer.time_to_maturity.estimates_years_to_close.internet_overall.central} years</li>
          <li>recent post-pandemic 5 pp / year ≈ {killer.time_to_maturity.estimates_years_to_close.internet_overall.low} years</li>
        </ul>
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
            Willingness-to-pay is proxied via income, net worth, financial
            distress and sourced premium ranges. Commercial pricing requires
            vertical-specific elasticity work and stakeholder interviews.
          </li>
          <li>
            Customer-level integration (CSV import, API scoring) is documented
            as architecture in chapter 8 of the underlying thesis but not
            implemented in this build.
          </li>
        </ul>
      </Section>

      <Section title="Sources">
        <p className="text-sm text-stone-700 leading-relaxed">
          The product is built on primary survey data, official national
          statistics, industry-association reports, and market reviewers.
          Each opportunity-sizing assumption cites at least one source from
          the bibliography below.
        </p>
        <div className="space-y-3 mt-4">
          {sources.sources.map((s) => (
            <article
              key={s.id}
              className="rounded-xl bg-stone-50 border border-stone-200 p-4 space-y-1"
            >
              <div className="flex items-baseline justify-between flex-wrap gap-2">
                <p className="font-medium text-slate-900 text-sm">
                  {s.publisher}
                </p>
                <code className="text-xs bg-white px-2 py-0.5 rounded border border-stone-200 text-stone-600">
                  {s.id}
                </code>
              </div>
              <p className="text-sm text-stone-700">{s.title}</p>
              <p className="text-xs text-stone-500">
                {s.kind} · {s.year}
                {' '}
                · <a
                  href={s.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-amber-700 hover:underline underline-offset-4"
                >
                  link
                </a>
              </p>
              <p className="text-xs text-stone-600 leading-relaxed pt-1">
                <span className="font-medium">Informs:</span> {s.informs}
              </p>
            </article>
          ))}
        </div>
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
