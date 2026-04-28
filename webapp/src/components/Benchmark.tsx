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

type OppRange = { low: number; central: number; high: number };

export default function Benchmark() {
  const pairs = killer.matched_pairs;
  const opportunities = useMemo(() => buildOpportunityRanking(pairs), [pairs]);
  const totalCentral = opportunities.reduce(
    (acc, o) => acc + o.opportunityCentral,
    0,
  );
  const totalLow = opportunities.reduce((acc, o) => acc + o.opportunityLow, 0);
  const totalHigh = opportunities.reduce((acc, o) => acc + o.opportunityHigh, 0);

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
          a defensible €-per-uptake range exists (sourced from ANIA, ANDI,
          GIMBE, Censis), the gap is sized as addressable opportunity for
          Italian operators with low / central / high scenarios.
        </p>
      </header>

      <section className="rounded-2xl bg-amber-50 border border-amber-200 p-8 space-y-6">
        <header>
          <p className="eyebrow text-amber-700">Top opportunities, ranked</p>
          <h2 className="display-3 text-slate-900 mt-2">
            <span className="text-amber-800">€{(totalCentral / 1e6).toFixed(0)}M</span>
            <span className="text-stone-500 text-base font-medium tracking-normal ml-2">
              central · €{(totalLow / 1e6).toFixed(0)}M low · €{(totalHigh / 1e6).toFixed(0)}M high
            </span>
          </h2>
          <p className="text-sm text-stone-600 mt-1">
            addressable from monetised gaps, per year
          </p>
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
                <th className="py-3 px-2 eyebrow text-right">Opportunity (low / central / high)</th>
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
                  <td className="py-3 px-2 text-right tabular-nums">
                    <span className="text-stone-500 text-xs">{formatEUR(o.opportunityLow)}</span>
                    <span className="mx-1 text-stone-400">/</span>
                    <span className="font-semibold text-amber-800">{formatEUR(o.opportunityCentral)}</span>
                    <span className="mx-1 text-stone-400">/</span>
                    <span className="text-stone-500 text-xs">{formatEUR(o.opportunityHigh)}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="text-xs text-stone-600 leading-relaxed">
          Sourced premium ranges (€ per individual per year): dental
          €150-500 (basic prevention to comprehensive senior dental, sources:
          ANIA market review of individual policies, ANDI 2024); private
          specialist consultation €100-450 (Censis 2024 + market reviewers).
          Sizing = max(0, gap) × Italian segment size × premium. See{' '}
          <span className="font-medium">Methods & data</span> for full
          bibliography.
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
              <th className="py-2 px-2 eyebrow text-right">Opportunity (central)</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-stone-100">
            {pair.dimensions.map((d) => {
              const isBinary = d.scale.startsWith('binary');
              const oppRange =
                'opportunity_size_eur' in d
                  ? (d.opportunity_size_eur as OppRange | null)
                  : null;
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
                  <td className="py-2 px-2 text-right tabular-nums">
                    {oppRange &&
                    typeof oppRange === 'object' &&
                    oppRange.central > 0 ? (
                      <span className="text-amber-700 font-medium">
                        {formatEUR(oppRange.central)}
                        <span className="block text-xs text-stone-500 font-normal">
                          {formatEUR(oppRange.low)}–{formatEUR(oppRange.high)}
                        </span>
                      </span>
                    ) : (
                      <span className="text-stone-400">—</span>
                    )}
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
  opportunityLow: number;
  opportunityCentral: number;
  opportunityHigh: number;
};

function buildOpportunityRanking(pairs: Pair[]): Opportunity[] {
  const out: Opportunity[] = [];
  for (const p of pairs) {
    for (const d of p.dimensions) {
      const oppRange =
        'opportunity_size_eur' in d
          ? (d.opportunity_size_eur as OppRange | null)
          : null;
      if (oppRange && typeof oppRange === 'object' && oppRange.central > 0) {
        out.push({
          pair: p.matched_pair_label,
          dimension: d.dimension,
          gap: d.gap_se_minus_it,
          italianSegmentSize: p.italian_market_size_individuals,
          opportunityLow: oppRange.low,
          opportunityCentral: oppRange.central,
          opportunityHigh: oppRange.high,
        });
      }
    }
  }
  out.sort((a, b) => b.opportunityCentral - a.opportunityCentral);
  return out;
}
