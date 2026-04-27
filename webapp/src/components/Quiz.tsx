import { useState } from 'react';
import type { Country } from '../lib/profiler';

type KeyVar = { var: string; dim: string; scale: string; label: string };

type Scale =
  | { kind: 'binary' }
  | { kind: 'count' }
  | { kind: 'range'; min: number; max: number };

function parseScale(s: string): Scale {
  if (s === '0/1') return { kind: 'binary' };
  if (s === 'count') return { kind: 'count' };
  const m = s.match(/^(\d+)-(\d+)$/);
  if (m) return { kind: 'range', min: Number(m[1]), max: Number(m[2]) };
  return { kind: 'count' };
}

type Props = {
  country: Country;
  keyVariables: readonly KeyVar[];
  onComplete: (answers: Record<string, number>) => void;
  onBack: () => void;
};

export default function Quiz({ country, keyVariables, onComplete, onBack }: Props) {
  const [idx, setIdx] = useState(0);
  const [answers, setAnswers] = useState<Record<string, number>>({});

  const total = keyVariables.length;
  const q = keyVariables[idx];
  const scale = parseScale(q.scale);
  const answered = q.var in answers;

  const setAns = (v: number) => {
    setAnswers((prev) => ({ ...prev, [q.var]: v }));
  };

  const next = () => {
    if (idx < total - 1) setIdx(idx + 1);
    else onComplete(answers);
  };
  const back = () => {
    if (idx > 0) setIdx(idx - 1);
    else onBack();
  };

  return (
    <section className="space-y-8">
      <div className="flex items-center justify-between text-xs text-slate-500">
        <span className="uppercase tracking-wide">{country}</span>
        <span>
          Question {idx + 1} of {total}
        </span>
      </div>
      <div className="h-1.5 w-full bg-slate-200 rounded-full overflow-hidden">
        <div
          className="h-full bg-slate-700 transition-all"
          style={{ width: `${((idx + 1) / total) * 100}%` }}
        />
      </div>

      <article className="rounded-2xl bg-white border border-slate-200 p-8 shadow-sm space-y-6">
        <p className="text-xs uppercase tracking-wide text-slate-500">
          {q.dim} dimension
        </p>
        <h2 className="text-xl font-medium leading-snug text-slate-900">{q.label}</h2>

        {scale.kind === 'binary' && (
          <div className="grid grid-cols-2 gap-3">
            {[
              { label: 'No', value: 0 },
              { label: 'Yes', value: 1 },
            ].map((opt) => (
              <button
                key={opt.value}
                type="button"
                onClick={() => setAns(opt.value)}
                className={[
                  'rounded-xl px-6 py-4 border transition',
                  answers[q.var] === opt.value
                    ? 'border-slate-900 bg-slate-900 text-white'
                    : 'border-slate-300 bg-white text-slate-900 hover:border-slate-500',
                ].join(' ')}
              >
                {opt.label}
              </button>
            ))}
          </div>
        )}

        {scale.kind === 'count' && (
          <input
            type="number"
            min={0}
            max={50}
            step={1}
            value={answers[q.var] ?? ''}
            onChange={(e) =>
              e.target.value === ''
                ? setAnswers((prev) => {
                    const { [q.var]: _drop, ...rest } = prev;
                    return rest;
                  })
                : setAns(Number(e.target.value))
            }
            className="w-full rounded-xl border border-slate-300 px-4 py-3 text-lg text-slate-900 focus:outline-none focus:border-slate-700"
            placeholder="0 – 50"
          />
        )}

        {scale.kind === 'range' && (
          <div className="space-y-3">
            <input
              type="range"
              min={scale.min}
              max={scale.max}
              step={1}
              value={answers[q.var] ?? Math.round((scale.min + scale.max) / 2)}
              onChange={(e) => setAns(Number(e.target.value))}
              className="w-full accent-slate-900"
            />
            <div className="flex items-center justify-between text-sm text-slate-500">
              <span>{scale.min}</span>
              <span className="text-base font-medium text-slate-900 tabular-nums">
                {answers[q.var] ?? '—'}
              </span>
              <span>{scale.max}</span>
            </div>
          </div>
        )}
      </article>

      <div className="flex items-center justify-between gap-3">
        <button
          type="button"
          onClick={back}
          className="rounded-xl border border-slate-300 px-5 py-2.5 text-slate-700 hover:bg-white"
        >
          {idx === 0 ? 'Cancel' : 'Back'}
        </button>
        <button
          type="button"
          onClick={next}
          disabled={!answered}
          className="rounded-xl bg-slate-900 text-white px-6 py-2.5 hover:bg-slate-700 disabled:opacity-40 disabled:cursor-not-allowed transition"
        >
          {idx === total - 1 ? 'See result' : 'Next'}
        </button>
      </div>
    </section>
  );
}
