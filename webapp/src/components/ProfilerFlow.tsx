import { useState } from 'react';
import centroidsData from '../data/centroids.json';
import narrativesData from '../data/profile_narratives.json';
import Quiz from './Quiz';
import Result from './Result';
import CsvUpload from './CsvUpload';
import type { Country } from '../lib/profiler';

const narratives = narrativesData as {
  italy: Record<string, string>;
  sweden: Record<string, string>;
};

type Mode = 'single' | 'batch';
type Step = 'mode' | 'quiz' | 'result' | 'csv';

export default function ProfilerFlow() {
  const [step, setStep] = useState<Step>('mode');
  const [country, setCountry] = useState<Country | null>(null);
  const [answers, setAnswers] = useState<Record<string, number>>({});

  const handleStart = (m: Mode, c: Country) => {
    setCountry(c);
    setAnswers({});
    setStep(m === 'single' ? 'quiz' : 'csv');
  };

  const handleQuizComplete = (a: Record<string, number>) => {
    setAnswers(a);
    setStep('result');
  };

  const handleRestart = () => {
    setStep('mode');
    setCountry(null);
    setAnswers({});
  };

  return (
    <div className="max-w-4xl mx-auto">
      {step === 'mode' && <ModePicker onStart={handleStart} />}
      {step === 'quiz' && country && (
        <Quiz
          country={country}
          onComplete={handleQuizComplete}
          onBack={handleRestart}
        />
      )}
      {step === 'result' && country && (
        <Result
          country={country}
          answers={answers}
          data={centroidsData}
          narratives={narratives}
          onRestart={handleRestart}
        />
      )}
      {step === 'csv' && country && (
        <CsvUpload country={country} onBack={handleRestart} />
      )}
    </div>
  );
}

function ModePicker({
  onStart,
}: {
  onStart: (m: Mode, c: Country) => void;
}) {
  const [mode, setMode] = useState<Mode>('single');

  return (
    <section className="space-y-12 max-w-3xl">
      <header className="space-y-4">
        <p className="eyebrow">Try the model</p>
        <h1 className="display-1 text-slate-900">
          Score yourself, or score a whole dataset.
        </h1>
        <p className="text-lg text-zinc-700 leading-relaxed max-w-2xl">
          The same K-means engine that powers the Atlas, exposed two ways.
          Pick the mode that fits the question you're bringing.
        </p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <ModeCard
          active={mode === 'single'}
          eyebrow="Single profile"
          title="Ten plain-language questions."
          desc="A short questionnaire across health, economics, digital reach, social network and subjective wellbeing. Returns the closest profile and a soft-membership distribution. Suitable for trying the model on yourself or a single client."
          onClick={() => setMode('single')}
        />
        <ModeCard
          active={mode === 'batch'}
          eyebrow="Batch · CSV"
          title="Score a whole cohort."
          desc="Upload a CSV with one row per individual, map your columns to the ten profiler variables, and download a scored file with the predicted profile and soft-membership for each row. Designed for researchers and analysts."
          onClick={() => setMode('batch')}
        />
      </div>

      <div className="space-y-4">
        <p className="eyebrow">Reference population</p>
        <p className="text-sm text-zinc-600 max-w-2xl">
          The classifier compares your input to the country-specific centroids
          built from SHARE Wave 9. Pick the population you want to be matched
          against.
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <button
            type="button"
            onClick={() => onStart(mode, 'italy')}
            className="rounded-2xl bg-white border border-zinc-200 px-6 py-8 text-left hover:border-emerald-400 transition-colors group"
          >
            <p className="text-lg font-medium text-slate-900">
              Score against Italy
            </p>
            <p className="text-xs text-zinc-500 mt-1">
              5 segments · 14.18M individuals
            </p>
            <p className="text-sm text-emerald-700 mt-4 group-hover:translate-x-1 transition-transform">
              Start &rarr;
            </p>
          </button>
          <button
            type="button"
            onClick={() => onStart(mode, 'sweden')}
            className="rounded-2xl bg-white border border-zinc-200 px-6 py-8 text-left hover:border-emerald-400 transition-colors group"
          >
            <p className="text-lg font-medium text-slate-900">
              Score against Sweden
            </p>
            <p className="text-xs text-zinc-500 mt-1">
              6 segments · 2.05M individuals
            </p>
            <p className="text-sm text-emerald-700 mt-4 group-hover:translate-x-1 transition-transform">
              Start &rarr;
            </p>
          </button>
        </div>
      </div>
    </section>
  );
}

function ModeCard({
  active,
  eyebrow,
  title,
  desc,
  onClick,
}: {
  active: boolean;
  eyebrow: string;
  title: string;
  desc: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={[
        'text-left rounded-2xl p-6 transition-colors border',
        active
          ? 'bg-emerald-50 border-emerald-300'
          : 'bg-white border-zinc-200 hover:border-emerald-400',
      ].join(' ')}
    >
      <p className={['eyebrow', active ? 'text-emerald-700' : ''].join(' ')}>
        {eyebrow}
      </p>
      <p className="display-3 text-slate-900 mt-3">{title}</p>
      <p className="mt-3 text-sm text-zinc-600 leading-relaxed">{desc}</p>
    </button>
  );
}
