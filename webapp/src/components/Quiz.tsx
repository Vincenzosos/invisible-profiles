import { useState } from 'react';
import questionsData from '../data/profiler_questions.json';
import type { Country } from '../lib/profiler';

type ChoiceOption = { label: string; value: number };

type Question =
  | {
      var: string;
      dim: string;
      prompt: string;
      helper?: string;
      type: 'choices';
      options: ChoiceOption[];
    }
  | {
      var: string;
      dim: string;
      prompt: string;
      helper?: string;
      type: 'count';
    };

const QUESTIONS = questionsData.questions as Question[];

type Props = {
  country: Country;
  onComplete: (answers: Record<string, number>) => void;
  onBack: () => void;
};

export default function Quiz({ country, onComplete, onBack }: Props) {
  const [idx, setIdx] = useState(0);
  const [answers, setAnswers] = useState<Record<string, number>>({});

  const total = QUESTIONS.length;
  const q = QUESTIONS[idx];
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
    <section className="space-y-8 max-w-2xl">
      <div className="flex items-center justify-between text-xs">
        <span className="eyebrow">{country}</span>
        <span className="eyebrow">
          Question {idx + 1} of {total}
        </span>
      </div>
      <div className="h-1 w-full bg-zinc-200 rounded-full overflow-hidden">
        <div
          className="h-full bg-emerald-600 transition-all"
          style={{ width: `${((idx + 1) / total) * 100}%` }}
        />
      </div>

      <article className="rounded-2xl bg-white border border-zinc-200 p-8 space-y-6">
        <p className="eyebrow">{q.dim} dimension</p>
        <h2 className="display-3 text-slate-900">{q.prompt}</h2>
        {q.helper && (
          <p className="text-sm text-zinc-600 leading-relaxed">{q.helper}</p>
        )}

        {q.type === 'choices' && (
          <div className="grid grid-cols-1 gap-2.5">
            {q.options.map((opt) => {
              const selected = answers[q.var] === opt.value;
              return (
                <button
                  key={opt.label}
                  type="button"
                  onClick={() => setAns(opt.value)}
                  className={[
                    'rounded-xl px-5 py-3.5 border text-left transition-colors',
                    selected
                      ? 'border-slate-900 bg-slate-900 text-white'
                      : 'border-zinc-300 bg-white text-slate-900 hover:border-slate-500',
                  ].join(' ')}
                >
                  {opt.label}
                </button>
              );
            })}
          </div>
        )}

        {q.type === 'count' && (
          <div className="space-y-2">
            <input
              type="number"
              min={0}
              max={100}
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
              className="w-full rounded-xl border border-zinc-300 px-4 py-3 text-lg text-slate-900 focus:outline-none focus:border-emerald-500"
              placeholder="Type a number"
            />
            <p className="text-xs text-zinc-500">
              Adults typically name 10–25 different animals in 60 seconds.
            </p>
          </div>
        )}
      </article>

      <div className="flex items-center justify-between gap-3">
        <button
          type="button"
          onClick={back}
          className="rounded-xl border border-zinc-300 px-5 py-2.5 text-zinc-700 hover:bg-white hover:text-slate-900 transition-colors"
        >
          {idx === 0 ? 'Cancel' : 'Back'}
        </button>
        <button
          type="button"
          onClick={next}
          disabled={!answered}
          className="rounded-xl bg-slate-900 text-white px-6 py-2.5 hover:bg-slate-700 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
        >
          {idx === total - 1 ? 'See result' : 'Next'}
        </button>
      </div>
    </section>
  );
}
