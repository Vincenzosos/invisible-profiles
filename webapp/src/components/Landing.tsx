import type { Country } from '../lib/profiler';

type Props = {
  onSelectCountry: (country: Country) => void;
};

export default function Landing({ onSelectCountry }: Props) {
  return (
    <section className="space-y-12 max-w-2xl">
      <header className="space-y-5">
        <p className="eyebrow">Profiler</p>
        <h1 className="display-1 text-slate-900">
          Try the engine on yourself or a customer.
        </h1>
        <p className="text-lg text-zinc-700 leading-relaxed">
          Fifteen questions across ten profile dimensions — health, economics,
          digital reach, social network and subjective wellbeing. Returns a hard match (closest profile) and
          a soft membership distribution &mdash; the two outputs an operator
          would consume in a propensity-scoring pipeline.
        </p>
      </header>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <button
          type="button"
          onClick={() => onSelectCountry('italy')}
          className="rounded-2xl bg-white border border-zinc-200 px-6 py-12 text-lg font-medium text-slate-900 hover:border-blue-400 transition-colors"
        >
          Italy
          <span className="block mt-1 text-xs text-zinc-500 font-normal">
            5 segments · 14.18M individuals
          </span>
        </button>
        <button
          type="button"
          onClick={() => onSelectCountry('sweden')}
          className="rounded-2xl bg-white border border-zinc-200 px-6 py-12 text-lg font-medium text-slate-900 hover:border-blue-400 transition-colors"
        >
          Sweden
          <span className="block mt-1 text-xs text-zinc-500 font-normal">
            6 segments · 2.05M individuals
          </span>
        </button>
      </div>
    </section>
  );
}
