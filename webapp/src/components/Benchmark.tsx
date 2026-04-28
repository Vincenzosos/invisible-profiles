import { useMemo } from 'react';
import killer from '../data/killer_numbers.json';
import signals from '../data/business_signals.json';
import {
  formatEUR,
  formatIndividuals,
  formatNum,
  formatPP,
} from '../lib/format';

type Pair = (typeof killer.matched_pairs)[number];

const SWEDEN_BUSINESS_SIGNALS = signals.sweden as Record<
  string,
  { headline: string; detail: string }
>;
const ITALY_BUSINESS_SIGNALS = signals.italy as Record<
  string,
  { headline: string; detail: string }
>;

const DIMENSION_LABELS: Record<string, string> = {
  dentist_12m: 'Preventive dental care (12m)',
  internet: 'Internet penetration',
  forgone_cost: 'Forgone care for cost',
  specialist: 'Private specialist contacts',
  casp: 'CASP-12 quality of life',
  internet_banking: 'Online banking',
  online_purchase: 'E-commerce / online purchase',
};

export default function Benchmark() {
  const pairs = killer.matched_pairs;
  const opportunities = useMemo(() => buildOpportunityRanking(pairs), [pairs]);

  return (
    <section className="space-y-10">
      <header className="space-y-3 max-w-4xl">
        <p className="text-xs uppercase tracking-wide text-slate-500">
          Benchmark · Italy ↔ Sweden
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-slate-900">
          Operational gaps to Europe's most mature elderly-services market
        </h1>
        <p className="text-slate-700 leading-relaxed">
          For each Italian profile, we identify the closest Swedish counterpart
          (matched-pair design from chapter 5) and quantify the gap on the
          dimensions that map onto market headroom: dental coverage, digital
          reach, private specialist consultation, online banking and
          e-commerce, and subjective quality of life. Where a sensible
          €-per-uptake assumption exists, we size the addressable
          opportunity.
        </p>
      </header>

      <section className="rounded-2xl bg-white border border-slate-200 p-6 space-y-4">
        <h2 className="text-lg font-semibold text-slate-900">
          Top opportunities, ranked
        </h2>
        <p className="text-sm text-slate-600 max-w-3xl">
          Opportunity size = max(0, Sweden − Italy gap) × Italian segment size ×
          €-per-uptake assumption. Computed only on dimensions where uptake
          monetisation is a defensible single-product proxy (dental, specialist
          consultation). Other gaps are reported below for context but not
          monetised here.
        </p>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-xs uppercase tracking-wide text-slate-500 border-b border-slate-200">
                <th className="py-2.5 pr-3">Rank</th>
                <th className="py-2.5 pr-3">Pair</th>
                <th className="py-2.5 pr-3">Dimension</th>
                <th className="py-2.5 pr-3 text-right">Gap</th>
                <th className="py-2.5 pr-3 text-right">Segment size</th>
                <th className="py-2.5 pr-3 text-right">Opportunity €/y</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {opportunities.map((o, i) => (
                <tr key={`${o.pair}-${o.dimension}`}>
                  <td className="py-2.5 pr-3 text-slate-500 tabular-nums">
                    {i + 1}
                  </td>
                  <td className="py-2.5 pr-3 text-slate-900">{o.pair}</td>
                  <td className="py-2.5 pr-3 text-slate-700">
                    {DIMENSION_LABELS[o.dimension] ?? o.dimension}
                  </td>
                  <td className="py-2.5 pr-3 text-right tabular-nums">
                    {formatPP(o.gap)}
                  </td>
                  <td className="py-2.5 pr-3 text-right tabular-nums text-slate-700">
                    {formatIndividuals(o.italianSegmentSize)}
                  </td>
                  <td className="py-2.5 pr-3 text-right tabular-nums font-medium text-slate-900">
                    {formatEUR(o.opportunityEur)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="text-xs text-slate-500 leading-relaxed">
          Assumptions: dental — €80/individual/year (mid-range private dental
          insurance premium for Italian over-65, pre-tax); specialist
          consultation — €130/individual/year (median full-cost private
          specialist visit times observed Sweden mean uptake delta). These are
          single-anchor proxies for board-memo sizing; commercial pricing
          requires stakeholder-specific elasticity work.
        </p>
      </section>

      <section className="space-y-4">
        <h2 className="text-lg font-semibold text-slate-900">
          Matched pairs in detail
        </h2>
        {pairs.map((p) => (
          <PairCard key={p.matched_pair_label} pair={p} />
        ))}
      </section>

      <section className="rounded-2xl bg-white border border-slate-200 p-6 space-y-4">
        <h2 className="text-lg font-semibold text-slate-900">
          Welfare-regime-specific profiles (no cross-country counterpart)
        </h2>
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
          <UnmatchedCard
            country="Italy"
            profileName="Moderate Isolated"
            signal={ITALY_BUSINESS_SIGNALS['Moderate Isolated']}
          />
          <UnmatchedCard
            country="Sweden"
            profileName="Asset Rich"
            signal={SWEDEN_BUSINESS_SIGNALS['Asset Rich']}
          />
          <UnmatchedCard
            country="Sweden"
            profileName="Wealthy Digital"
            signal={SWEDEN_BUSINESS_SIGNALS['Wealthy Digital']}
          />
        </div>
      </section>

      <footer className="border-t border-slate-200 pt-6 text-xs text-slate-500 max-w-3xl space-y-1.5">
        <p>
          Time-to-maturity (digital indicators): under a 1pp/year linear-closure
          assumption (calibrated against Eurostat ICT-individuals 2018–2024
          Italy trend), the Italy–Sweden internet-penetration gap of{' '}
          {formatPP(
            killer.country_aggregates.sweden.internet_penetration_pct -
              killer.country_aggregates.italy.internet_penetration_pct,
            0,
          )}{' '}
          would close in approximately{' '}
          {killer.time_to_maturity.estimates.internet_overall_years_to_close}{' '}
          years; the dentist-coverage gap of{' '}
          {formatPP(
            killer.country_aggregates.sweden.dentist_12m_pct -
              killer.country_aggregates.italy.dentist_12m_pct,
            0,
          )}{' '}
          in approximately{' '}
          {killer.time_to_maturity.estimates.dentist_overall_years_to_close}{' '}
          years. These are indicative single-rate extrapolations; a
          proper estimate requires a cross-wave SHARE regression.
        </p>
      </footer>
    </section>
  );
}

function PairCard({ pair }: { pair: Pair }) {
  return (
    <article className="rounded-2xl bg-white border border-slate-200 p-5 space-y-3">
      <header className="flex items-baseline justify-between flex-wrap gap-2">
        <div>
          <p className="text-xs uppercase tracking-wide text-slate-500">
            {pair.matched_pair_label}
          </p>
          <h3 className="text-base font-semibold text-slate-900">
            🇮🇹 {pair.italian_profile} ↔ 🇸🇪 {pair.swedish_profile}
          </h3>
        </div>
        <p className="text-xs text-slate-500 tabular-nums">
          IT segment size: {formatIndividuals(pair.italian_market_size_individuals)}
        </p>
      </header>

      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs uppercase tracking-wide text-slate-500 border-b border-slate-200">
              <th className="py-2 pr-3">Dimension</th>
              <th className="py-2 pr-3 text-right">🇮🇹 IT</th>
              <th className="py-2 pr-3 text-right">🇸🇪 SE</th>
              <th className="py-2 pr-3 text-right">Gap</th>
              <th className="py-2 pr-3 text-right">€/y opportunity</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {pair.dimensions.map((d) => {
              const isBinary = d.scale.startsWith('binary');
              const oppEur =
                'opportunity_size_eur' in d ? d.opportunity_size_eur : null;
              return (
                <tr key={d.dimension}>
                  <td className="py-2 pr-3 text-slate-700">
                    {DIMENSION_LABELS[d.dimension] ?? d.dimension}
                  </td>
                  <td className="py-2 pr-3 text-right tabular-nums text-slate-700">
                    {isBinary
                      ? `${(d.italy_mean * 100).toFixed(0)}%`
                      : formatNum(d.italy_mean)}
                  </td>
                  <td className="py-2 pr-3 text-right tabular-nums text-slate-700">
                    {isBinary
                      ? `${(d.sweden_mean * 100).toFixed(0)}%`
                      : formatNum(d.sweden_mean)}
                  </td>
                  <td
                    className={[
                      'py-2 pr-3 text-right tabular-nums font-medium',
                      d.gap_se_minus_it > 0
                        ? 'text-emerald-700'
                        : d.gap_se_minus_it < 0
                          ? 'text-amber-700'
                          : 'text-slate-500',
                    ].join(' ')}
                  >
                    {isBinary
                      ? formatPP(d.gap_se_minus_it, 0)
                      : (d.gap_se_minus_it >= 0 ? '+' : '') +
                        d.gap_se_minus_it.toFixed(2)}
                  </td>
                  <td className="py-2 pr-3 text-right tabular-nums text-slate-900">
                    {oppEur !== null && oppEur !== undefined && oppEur > 0
                      ? formatEUR(oppEur as number)
                      : '—'}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </article>
  );
}

function UnmatchedCard({
  country,
  profileName,
  signal,
}: {
  country: 'Italy' | 'Sweden';
  profileName: string;
  signal: { headline: string; detail: string } | undefined;
}) {
  if (!signal) return null;
  return (
    <article className="rounded-xl bg-slate-50 border border-slate-200 p-4 space-y-2">
      <p className="text-xs uppercase tracking-wide text-slate-500">
        {country === 'Italy' ? '🇮🇹' : '🇸🇪'} {country}
      </p>
      <h3 className="text-base font-semibold text-slate-900">{profileName}</h3>
      <p className="text-xs text-slate-700 font-medium">{signal.headline}</p>
      <p className="text-xs text-slate-600 leading-relaxed">{signal.detail}</p>
    </article>
  );
}

type Opportunity = {
  pair: string;
  dimension: string;
  gap: number;
  italianSegmentSize: number;
  opportunityEur: number;
};

function buildOpportunityRanking(pairs: Pair[]): Opportunity[] {
  const out: Opportunity[] = [];
  for (const p of pairs) {
    for (const d of p.dimensions) {
      const oppEur = 'opportunity_size_eur' in d ? d.opportunity_size_eur : null;
      if (oppEur !== null && oppEur !== undefined && (oppEur as number) > 0) {
        out.push({
          pair: p.matched_pair_label,
          dimension: d.dimension,
          gap: d.gap_se_minus_it,
          italianSegmentSize: p.italian_market_size_individuals,
          opportunityEur: oppEur as number,
        });
      }
    }
  }
  out.sort((a, b) => b.opportunityEur - a.opportunityEur);
  return out;
}
