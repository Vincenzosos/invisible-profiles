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
  dentist_12m: 'Preventive dental (12m)',
  internet: 'Internet penetration',
  forgone_cost: 'Forgone care for cost',
  specialist: 'Private specialist',
  casp: 'CASP-12 wellbeing',
  internet_banking: 'Online banking',
  online_purchase: 'E-commerce',
};

export default function Benchmark() {
  const pairs = killer.matched_pairs;
  const opportunities = useMemo(() => buildOpportunityRanking(pairs), [pairs]);
  const totalEur = opportunities.reduce(
    (acc, o) => acc + o.opportunityEur,
    0,
  );

  return (
    <section className="space-y-16">
      <header className="space-y-6 max-w-4xl">
        <p className="eyebrow">Benchmark · Italy ↔ Sweden</p>
        <h1 className="display-1 text-slate-900">
          Where the gap to the mature market pays.
        </h1>
        <p className="text-lg text-stone-700 leading-relaxed max-w-3xl">
          For each Italian profile we identify the closest Swedish counterpart
          and quantify the gap on dental coverage, digital reach, private
          specialist consultation, online banking and CASP-12 wellbeing. Where
          a defensible €-per-uptake assumption exists, the gap is sized as
          addressable opportunity for Italian operators.
        </p>
      </header>

      <section className="rounded-2xl bg-amber-50 border border-amber-200 p-8 space-y-6">
        <header className="flex items-baseline justify-between flex-wrap gap-4">
          <div>
            <p className="eyebrow text-amber-700">Top opportunities, ranked</p>
            <h2 className="display-3 text-slate-900 mt-2">
              €{(totalEur / 1e6).toFixed(0)}M / year addressable from monetised gaps
            </h2>
          </div>
        </header>
        <div className="overflow-x-auto -mx-2">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-stone-600 border-b border-amber-200">
                <th className="py-3 px-2 eyebrow">#</th>
                <th className="py-3 px-2 eyebrow">Pair</th>
                <th className="py-3 px-2 eyebrow">Dimension</th>
                <th className="py-3 px-2 eyebrow text-right">Gap</th>
                <th className="py-3 px-2 eyebrow text-right">Segment</th>
                <th className="py-3 px-2 eyebrow text-right">Opportunity</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-amber-100">
              {opportunities.map((o, i) => (
                <tr key={`${o.pair}-${o.dimension}`}>
                  <td className="py-3 px-2 text-stone-500 tabular-nums">
                    {i + 1}
                  </td>
                  <td className="py-3 px-2 text-slate-900 font-medium">
                    {o.pair}
                  </td>
                  <td className="py-3 px-2 text-stone-700">
                    {DIMENSION_LABELS[o.dimension] ?? o.dimension}
                  </td>
                  <td className="py-3 px-2 text-right tabular-nums text-stone-700">
                    {formatPP(o.gap)}
                  </td>
                  <td className="py-3 px-2 text-right tabular-nums text-stone-600">
                    {formatIndividuals(o.italianSegmentSize)}
                  </td>
                  <td className="py-3 px-2 text-right tabular-nums font-semibold text-amber-800">
                    {formatEUR(o.opportunityEur)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="text-xs text-stone-600 leading-relaxed">
          Sizing assumptions: dental at €80 / individual / year (mid-range
          private dental insurance premium for Italian over-65); private
          specialist at €130 / individual / year. Single-anchor proxies for
          board-memo orientation.
        </p>
      </section>

      <section className="space-y-6">
        <h2 className="display-3 text-slate-900">Matched pairs</h2>
        {pairs.map((p) => (
          <PairCard key={p.matched_pair_label} pair={p} />
        ))}
      </section>

      <section className="space-y-4">
        <h2 className="display-3 text-slate-900">Profiles without a counterpart</h2>
        <p className="text-sm text-stone-600 max-w-3xl">
          Three segments have no cross-country match. They are the
          welfare-regime-specific signatures of each market.
        </p>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
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
    </section>
  );
}

function PairCard({ pair }: { pair: Pair }) {
  return (
    <article className="rounded-2xl bg-white border border-stone-200 p-6 space-y-4">
      <header className="flex items-baseline justify-between flex-wrap gap-2">
        <div>
          <p className="eyebrow">{pair.matched_pair_label}</p>
          <h3 className="display-3 text-slate-900 mt-1">
            {pair.italian_profile} <span className="text-stone-400">↔</span>{' '}
            {pair.swedish_profile}
          </h3>
        </div>
        <p className="text-sm text-stone-500 tabular-nums">
          IT segment: {formatIndividuals(pair.italian_market_size_individuals)}
        </p>
      </header>

      <div className="overflow-x-auto -mx-2">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-stone-600 border-b border-stone-200">
              <th className="py-2 px-2 eyebrow">Dimension</th>
              <th className="py-2 px-2 eyebrow text-right">Italy</th>
              <th className="py-2 px-2 eyebrow text-right">Sweden</th>
              <th className="py-2 px-2 eyebrow text-right">Gap</th>
              <th className="py-2 px-2 eyebrow text-right">Opportunity</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-stone-100">
            {pair.dimensions.map((d) => {
              const isBinary = d.scale.startsWith('binary');
              const oppEur =
                'opportunity_size_eur' in d ? d.opportunity_size_eur : null;
              return (
                <tr key={d.dimension}>
                  <td className="py-2 px-2 text-stone-700">
                    {DIMENSION_LABELS[d.dimension] ?? d.dimension}
                  </td>
                  <td className="py-2 px-2 text-right tabular-nums text-stone-700">
                    {isBinary
                      ? `${(d.italy_mean * 100).toFixed(0)}%`
                      : formatNum(d.italy_mean)}
                  </td>
                  <td className="py-2 px-2 text-right tabular-nums text-stone-700">
                    {isBinary
                      ? `${(d.sweden_mean * 100).toFixed(0)}%`
                      : formatNum(d.sweden_mean)}
                  </td>
                  <td
                    className={[
                      'py-2 px-2 text-right tabular-nums font-medium',
                      d.gap_se_minus_it > 0
                        ? 'text-emerald-700'
                        : d.gap_se_minus_it < 0
                          ? 'text-amber-700'
                          : 'text-stone-500',
                    ].join(' ')}
                  >
                    {isBinary
                      ? formatPP(d.gap_se_minus_it, 0)
                      : (d.gap_se_minus_it >= 0 ? '+' : '') +
                        d.gap_se_minus_it.toFixed(2)}
                  </td>
                  <td className="py-2 px-2 text-right tabular-nums text-amber-700 font-medium">
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
    <article className="rounded-2xl bg-white border border-stone-200 p-5 space-y-3">
      <p className="eyebrow">{country}</p>
      <h3 className="display-3 text-slate-900">{profileName}</h3>
      <p className="text-sm font-medium text-slate-900">{signal.headline}</p>
      <p className="text-sm text-stone-600 leading-relaxed">{signal.detail}</p>
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
