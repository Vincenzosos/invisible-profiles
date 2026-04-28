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
    <section className="space-y-12 max-w-3xl">
      <header className="space-y-4">
        <p className="eyebrow">{country} · closest profile</p>
        <h1 className="display-1 text-slate-900">{best.name}</h1>
        <p className="text-lg text-stone-700 leading-relaxed">{narrative}</p>
      </header>

      <article className="rounded-2xl bg-white border border-stone-200 p-7 space-y-5">
        <header>
          <p className="eyebrow">Membership distribution</p>
          <p className="text-sm text-stone-600 leading-relaxed mt-2 max-w-2xl">
            Soft assignment over all profiles &mdash; the output an operator
            consumes for propensity scoring.
          </p>
        </header>
        <div className="space-y-2.5">
          {membership.map((m, i) => (
            <div
              key={m.name}
              className="grid grid-cols-12 gap-3 items-center"
            >
              <div
                className={[
                  'col-span-5 text-sm truncate',
                  i === 0
                    ? 'font-semibold text-slate-900'
                    : 'text-stone-600',
                ].join(' ')}
              >
                {m.name}
              </div>
              <div className="col-span-6 relative h-3 bg-stone-100 rounded-full overflow-hidden">
                <div
                  className={[
                    'absolute inset-y-0 left-0 rounded-full',
                    i === 0 ? 'bg-amber-500' : 'bg-stone-400',
                  ].join(' ')}
                  style={{ width: `${(m.probability * 100).toFixed(1)}%` }}
                />
              </div>
              <div className="col-span-1 text-right text-xs tabular-nums text-stone-700 font-medium">
                {(m.probability * 100).toFixed(0)}%
              </div>
            </div>
          ))}
        </div>
      </article>

      <article className="rounded-2xl bg-white border border-stone-200 p-7 space-y-5">
        <p className="eyebrow">Your z-scores · 10 quiz dimensions</p>
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
                  className="col-span-3 text-sm text-stone-700 truncate"
                  title={kv.label}
                >
                  {kv.var}
                </div>
                <div className="col-span-8 relative h-4 bg-stone-100 rounded">
                  <div className="absolute inset-y-0 left-1/2 w-px bg-stone-300" />
                  <div
                    className={[
                      'absolute inset-y-0 rounded',
                      isPos
                        ? 'bg-emerald-500 left-1/2'
                        : 'bg-amber-500 right-1/2',
                    ].join(' ')}
                    style={{ width: `${pct}%` }}
                  />
                </div>
                <div className="col-span-1 text-right text-xs tabular-nums text-stone-600">
                  {z >= 0 ? '+' : ''}
                  {z.toFixed(1)}
                </div>
              </div>
            );
          })}
        </div>
        <p className="text-xs text-stone-500 leading-relaxed">
          Standardised against the country mean. Display capped at ±{Z_CAP}.
        </p>
      </article>

      {twinName && twinDistance !== null && (
        <article className="rounded-2xl bg-emerald-50 border border-emerald-200 p-7 space-y-3">
          <p className="eyebrow text-emerald-700">Cross-country twin</p>
          <p className="display-3 text-slate-900">
            In {otherCountry === 'sweden' ? 'Sweden' : 'Italy'}, you would be{' '}
            <span className="text-emerald-700">{twinName}</span>.
          </p>
          {twinNarrative && (
            <p className="text-sm text-stone-700 leading-relaxed">
              {twinNarrative}
            </p>
          )}
        </article>
      )}

      {businessSignal && (
        <article className="rounded-2xl bg-white border border-stone-200 p-7 space-y-3">
          <p className="eyebrow">Business signal</p>
          <p className="display-3 text-slate-900">{businessSignal.headline}</p>
          <p className="text-sm text-stone-700 leading-relaxed">
            {businessSignal.detail}
          </p>
        </article>
      )}

      <details
        className="rounded-2xl bg-white border border-stone-200 p-6"
        open={showAll}
      >
        <summary
          className="cursor-pointer text-sm font-medium text-stone-700 select-none"
          onClick={(e) => {
            e.preventDefault();
            setShowAll((v) => !v);
          }}
        >
          {showAll ? 'Hide' : 'Show'} all profiles ranked by distance
        </summary>
        <ul className="mt-4 space-y-1.5">
          {ranking.map((m, i) => (
            <li
              key={m.name}
              className={[
                'flex items-center justify-between rounded-lg px-3 py-2',
                i === 0
                  ? 'bg-amber-50 font-medium text-slate-900'
                  : 'text-stone-700',
              ].join(' ')}
            >
              <span>
                {i + 1}. {m.name}
              </span>
              <span className="text-xs tabular-nums text-stone-500">
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
          className="rounded-xl border border-stone-300 px-5 py-2.5 text-stone-700 hover:bg-white hover:text-slate-900 transition-colors"
        >
          Start over
        </button>
      </div>
    </section>
  );
}
