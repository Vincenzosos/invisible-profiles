import { useMemo, useState } from 'react';
import type { CentroidsJson, Country } from '../lib/profiler';
import { matchProfile } from '../lib/profiler';
import signals from '../data/business_signals.json';

type Narratives = {
  italy: Record<string, string>;
  sweden: Record<string, string>;
};

type Props = {
  country: Country;
  answers: Record<string, number>;
  data: CentroidsJson;
  narratives: Narratives;
  onRestart: () => void;
};

const Z_CAP = 3;

const SIGNALS = signals as {
  italy: Record<string, { headline: string; detail: string }>;
  sweden: Record<string, { headline: string; detail: string }>;
};

export default function Result({
  country,
  answers,
  data,
  narratives,
  onRestart,
}: Props) {
  const [showAll, setShowAll] = useState(false);
  const result = useMemo(
    () => matchProfile(country, answers, data),
    [country, answers, data],
  );
  const { best, ranking, membership, twinName, twinDistance } = result;

  const narrative = narratives[country][best.name] ?? '';
  const keyVars = data.key_variables;
  const otherCountry: Country = country === 'italy' ? 'sweden' : 'italy';
  const twinNarrative = twinName ? narratives[otherCountry][twinName] : '';
  const businessSignal = SIGNALS[country][best.name];

  return (
    <section className="space-y-8 max-w-3xl">
      <header className="space-y-3">
        <p className="text-xs uppercase tracking-wide text-slate-500">
          {country} · Closest profile (K-means hard match)
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-slate-900">
          {best.name}
        </h1>
        <p className="text-slate-600 leading-relaxed">{narrative}</p>
        <p className="text-xs text-slate-400">
          Distance to centroid: {best.distance.toFixed(2)} (z-score units)
        </p>
      </header>

      <article className="rounded-2xl bg-white border border-slate-200 p-6 shadow-sm space-y-4">
        <h2 className="text-sm font-medium uppercase tracking-wide text-slate-500">
          Membership distribution (soft assignment)
        </h2>
        <p className="text-xs text-slate-500 leading-relaxed">
          A probabilistic view of profile membership based on softmax of
          negative squared distances to all centroids. Functionally equivalent
          to the LCA posterior used in the thesis methodology — useful for
          B2B propensity scoring where a hard label discards information.
        </p>
        <div className="space-y-2">
          {membership.map((m, i) => (
            <div
              key={m.name}
              className="grid grid-cols-12 gap-3 items-center"
            >
              <div
                className={[
                  'col-span-5 text-sm truncate',
                  i === 0
                    ? 'font-medium text-slate-900'
                    : 'text-slate-700',
                ].join(' ')}
              >
                {m.name}
              </div>
              <div className="col-span-6 relative h-4 bg-slate-100 rounded">
                <div
                  className={[
                    'absolute inset-y-0 left-0 rounded',
                    i === 0 ? 'bg-slate-900' : 'bg-slate-400',
                  ].join(' ')}
                  style={{ width: `${(m.probability * 100).toFixed(1)}%` }}
                />
              </div>
              <div className="col-span-1 text-right text-xs tabular-nums text-slate-700">
                {(m.probability * 100).toFixed(0)}%
              </div>
            </div>
          ))}
        </div>
      </article>

      <article className="rounded-2xl bg-white border border-slate-200 p-6 shadow-sm space-y-4">
        <h2 className="text-sm font-medium uppercase tracking-wide text-slate-500">
          Your z-scores (10 visible quiz dimensions)
        </h2>
        <div className="space-y-2.5">
          {keyVars.map((kv) => {
            const z = best.zScores[kv.var] ?? 0;
            const capped = Math.max(-Z_CAP, Math.min(Z_CAP, z));
            const pct = (Math.abs(capped) / Z_CAP) * 50;
            const isPos = z >= 0;
            return (
              <div
                key={kv.var}
                className="grid grid-cols-12 gap-3 items-center"
              >
                <div
                  className="col-span-3 text-sm text-slate-700 truncate"
                  title={kv.label}
                >
                  {kv.var}
                </div>
                <div className="col-span-8 relative h-5 bg-slate-100 rounded">
                  <div className="absolute inset-y-0 left-1/2 w-px bg-slate-400" />
                  <div
                    className={[
                      'absolute inset-y-0 rounded',
                      isPos
                        ? 'bg-sky-500 left-1/2'
                        : 'bg-amber-500 right-1/2',
                    ].join(' ')}
                    style={{ width: `${pct}%` }}
                  />
                </div>
                <div className="col-span-1 text-right text-xs tabular-nums text-slate-600">
                  {z >= 0 ? '+' : ''}
                  {z.toFixed(1)}
                </div>
              </div>
            );
          })}
        </div>
        <p className="text-xs text-slate-500 leading-relaxed pt-2">
          Bars compare your standardised answers to the over-65 country mean.
          Right (blue) is above average on the raw variable; left (amber) is
          below. Display capped at ±{Z_CAP}.
        </p>
      </article>

      {twinName && twinDistance !== null && (
        <article className="rounded-2xl bg-emerald-50 border border-emerald-200 p-6 space-y-2">
          <h2 className="text-sm font-medium uppercase tracking-wide text-emerald-800">
            Cross-country twin
          </h2>
          <p className="text-slate-900">
            If you were in {otherCountry === 'sweden' ? 'Sweden' : 'Italy'}, you
            would be most similar to <strong>{twinName}</strong> (distance{' '}
            {twinDistance.toFixed(2)}).
          </p>
          {twinNarrative && (
            <p className="text-sm text-slate-700 leading-relaxed">
              {twinNarrative}
            </p>
          )}
        </article>
      )}

      {businessSignal && (
        <article className="rounded-2xl bg-white border border-slate-200 p-6 space-y-2">
          <h2 className="text-sm font-medium uppercase tracking-wide text-slate-500">
            Business signal
          </h2>
          <p className="font-medium text-slate-900">{businessSignal.headline}</p>
          <p className="text-sm text-slate-700 leading-relaxed">
            {businessSignal.detail}
          </p>
        </article>
      )}

      <div className="p-4 rounded-lg bg-slate-50 border border-slate-200 text-sm text-slate-600 italic">
        Note: this match comes from a simplified 10-question profiler. The
        full thesis segmentation uses 31 variables across health, economic,
        social/digital, cognitive and subjective dimensions. Some profiles
        are best characterised by variables — e.g. property and financial
        assets, civic participation, family structure — that are not asked
        in this short form.
      </div>

      <details
        className="rounded-2xl bg-white border border-slate-200 p-6 shadow-sm group"
        open={showAll}
      >
        <summary
          className="cursor-pointer text-sm font-medium text-slate-700 select-none"
          onClick={(e) => {
            e.preventDefault();
            setShowAll((v) => !v);
          }}
        >
          {showAll ? 'Hide' : 'Show'} all profiles ranked
        </summary>
        <ul className="mt-4 space-y-2">
          {ranking.map((m, i) => (
            <li
              key={m.name}
              className={[
                'flex items-center justify-between rounded-lg px-3 py-2',
                i === 0
                  ? 'bg-slate-100 font-medium text-slate-900'
                  : 'text-slate-700',
              ].join(' ')}
            >
              <span>
                {i + 1}. {m.name}
              </span>
              <span className="text-xs tabular-nums text-slate-500">
                d = {m.distance.toFixed(2)}
              </span>
            </li>
          ))}
        </ul>
      </details>

      <div className="flex justify-end">
        <button
          type="button"
          onClick={onRestart}
          className="rounded-xl border border-slate-300 px-5 py-2.5 text-slate-700 hover:bg-white"
        >
          Start over
        </button>
      </div>
    </section>
  );
}
