import type { Country } from '../lib/profiler';

type Props = {
  onSelectCountry: (country: Country) => void;
};

export default function Landing({ onSelectCountry }: Props) {
  return (
    <section className="space-y-10">
      <header className="space-y-4 text-center">
        <h1 className="text-4xl font-semibold tracking-tight text-slate-900">
          Invisible Profiles
        </h1>
        <p className="text-slate-600 leading-relaxed">
          A 10-question profiler that places you among the over-65 segments derived
          from SHARE Wave 9 data for Italy and Sweden. Pick a country to begin.
        </p>
      </header>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <button
          type="button"
          onClick={() => onSelectCountry('italy')}
          className="rounded-2xl bg-white border border-slate-200 px-6 py-10 text-lg font-medium text-slate-900 shadow-sm hover:border-slate-400 hover:shadow-md transition"
        >
          Italy
        </button>
        <button
          type="button"
          onClick={() => onSelectCountry('sweden')}
          className="rounded-2xl bg-white border border-slate-200 px-6 py-10 text-lg font-medium text-slate-900 shadow-sm hover:border-slate-400 hover:shadow-md transition"
        >
          Sweden
        </button>
      </div>
      <p className="text-xs text-center text-slate-400 leading-relaxed">
        Five Italian and six Swedish profiles, fitted with K-means on standardised
        SHARE W9 indicators across health, economic, digital/social, cognitive, and
        subjective dimensions.
      </p>
    </section>
  );
}
