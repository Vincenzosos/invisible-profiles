import killer from '../data/killer_numbers.json';
import signals from '../data/business_signals.json';
import {
  formatNum,
  formatPct,
  formatPP,
} from '../lib/format';
import type { View } from '../types';

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
  specialist: 'Private specialist visits',
  casp: 'CASP-12 wellbeing',
  internet_banking: 'Online banking',
  online_purchase: 'E-commerce',
};

type Props = {
  onNavigate?: (v: View) => void;
};

export default function Benchmark({ onNavigate }: Props) {
  const pairs = killer.matched_pairs;

  return (
    <section className="space-y-16">
      <header className="space-y-6 max-w-4xl">
        <p className="eyebrow">02 · Italy ↔ Sweden</p>
        <h1 className="display-1 text-slate-900">
          The structural gap to a more mature welfare regime.
        </h1>
        <p className="text-lg text-zinc-700 leading-relaxed max-w-3xl">
          For each Italian profile we identify the closest Swedish counterpart
          (matched-pair design) and report the gap on every dimension where
          welfare-state design plausibly intervenes. Gaps are in percentage
          points (or mean differences) with 95% bootstrap confidence intervals
          — drawn directly from the SHARE Wave 9 sample.
        </p>
      </header>

      <section className="space-y-6">
        <h2 className="display-3 text-slate-900">Matched pairs</h2>
        {pairs.map((p) => (
          <PairCard key={p.matched_pair_label} pair={p} />
        ))}
      </section>

      <section className="space-y-4">
        <h2 className="display-3 text-slate-900">Profiles without a counterpart</h2>
        <p className="text-sm text-zinc-600 max-w-3xl">
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

      <p className="text-xs text-zinc-500 max-w-3xl leading-relaxed">
        Source: SHARE Wave 9 release 9.0.0 (fielded 2021–2022) for all per-pair
        metrics. Segment shares are descriptive of the SHARE Wave 9 analytical
        sample (unweighted) and are deliberately not projected to population
        counts. Gap CIs from 2,000-iteration percentile bootstrap (seed = 42).
      </p>

      {onNavigate && (
        <button
          type="button"
          onClick={() => onNavigate('methods')}
          className="block w-full text-left rounded-2xl border border-blue-200 bg-blue-50 hover:bg-blue-100 hover:border-blue-400 transition-colors p-8 group"
        >
          <p className="eyebrow text-blue-700">Continue · 03</p>
          <p className="display-2 text-slate-900 mt-3">
            Now see how it was built.
          </p>
          <p className="mt-3 text-base text-zinc-700 leading-relaxed max-w-3xl">
            Methodology, robustness checks, and the choices made when building
            the segmentation: the variables, the choice of k, the 4D-vs-5D
            sensitivity, and the multi-algorithm comparison.
          </p>
          <p className="mt-6 text-sm font-medium text-blue-700 group-hover:translate-x-1 transition-transform inline-flex items-center gap-2">
            Methodology →
          </p>
        </button>
      )}
    </section>
  );
}

function PairCard({ pair }: { pair: Pair }) {
  const itProfile = killer.italy_profiles.find(
    (p) => p.profile === pair.italian_profile,
  );
  return (
    <article className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-4">
      <header className="flex items-baseline justify-between flex-wrap gap-2">
        <div>
          <p className="eyebrow">{pair.matched_pair_label}</p>
          <h3 className="display-3 text-slate-900 mt-1">
            {pair.italian_profile} <span className="text-zinc-400">↔</span>{' '}
            {pair.swedish_profile}
          </h3>
        </div>
        {itProfile && (
          <p className="text-sm text-zinc-500 tabular-nums">
            IT segment: {formatPct(itProfile.share_of_country_pct)} of sample · n ={' '}
            {itProfile.n_sample}
          </p>
        )}
      </header>

      <div className="overflow-x-auto -mx-2">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-zinc-600 border-b border-zinc-200">
              <th className="py-2 px-2 eyebrow">Dimension</th>
              <th className="py-2 px-2 eyebrow text-right">Italy</th>
              <th className="py-2 px-2 eyebrow text-right">Sweden</th>
              <th className="py-2 px-2 eyebrow text-right">Gap (Sweden − Italy)</th>
              <th className="py-2 px-2 eyebrow text-right">CI 95%</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-100">
            {pair.dimensions.map((d) => {
              const isBinary = d.scale.startsWith('binary');
              const formatGap = (v: number) =>
                isBinary
                  ? formatPP(v, 0)
                  : (v >= 0 ? '+' : '') + v.toFixed(2);
              return (
                <tr key={d.dimension}>
                  <td className="py-2 px-2 text-zinc-700">
                    {DIMENSION_LABELS[d.dimension] ?? d.dimension}
                  </td>
                  <td className="py-2 px-2 text-right tabular-nums text-zinc-700">
                    {isBinary
                      ? `${(d.italy_mean * 100).toFixed(0)}%`
                      : formatNum(d.italy_mean)}
                  </td>
                  <td className="py-2 px-2 text-right tabular-nums text-zinc-700">
                    {isBinary
                      ? `${(d.sweden_mean * 100).toFixed(0)}%`
                      : formatNum(d.sweden_mean)}
                  </td>
                  <td
                    className={[
                      'py-2 px-2 text-right tabular-nums font-medium',
                      d.gap_se_minus_it > 0
                        ? 'text-blue-700'
                        : d.gap_se_minus_it < 0
                          ? 'text-rose-700'
                          : 'text-zinc-500',
                    ].join(' ')}
                  >
                    {formatGap(d.gap_se_minus_it)}
                  </td>
                  <td className="py-2 px-2 text-right tabular-nums text-zinc-500 text-xs">
                    [{formatGap(d.gap_ci[0])}, {formatGap(d.gap_ci[1])}]
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
    <article className="rounded-2xl bg-white border border-zinc-200 p-5 space-y-3">
      <p className="eyebrow">{country}</p>
      <h3 className="display-3 text-slate-900">{profileName}</h3>
      <p className="text-sm font-medium text-slate-900">{signal.headline}</p>
      <p className="text-sm text-zinc-600 leading-relaxed">{signal.detail}</p>
    </article>
  );
}
