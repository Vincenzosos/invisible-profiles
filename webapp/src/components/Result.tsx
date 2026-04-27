import { useMemo, useState } from 'react';
import type { CentroidsJson, Country } from '../lib/profiler';
import { matchProfile } from '../lib/profiler';

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

export default function Result({
  country,
  answers,
  data,
  narratives,
  onRestart,
}: Props) {
  const [showAll, setShowAll] = useState(false);
  const { best, ranking } = useMemo(
    () => matchProfile(country, answers, data),
    [country, answers, data],
  );

  const narrative = narratives[country][best.name] ?? '';
  const keyVars = data.key_variables;

  return (
    <section className="space-y-8">
      <header className="space-y-3">
        <p className="text-xs uppercase tracking-wide text-slate-500">
          {country} · Closest profile
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
          Your z-scores
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
                i === 0 ? 'bg-slate-100 font-medium text-slate-900' : 'text-slate-700',
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
