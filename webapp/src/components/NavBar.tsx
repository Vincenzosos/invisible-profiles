import type { View } from '../types';

const TABS: { id: View; label: string }[] = [
  { id: 'home',        label: 'Overview' },
  { id: 'atlas',       label: 'Atlas' },
  { id: 'benchmark',   label: 'Benchmark' },
  { id: 'opportunity', label: 'Opportunity' },
  { id: 'profiler',    label: 'Profiler' },
];

type Props = {
  active: View;
  onNavigate: (v: View) => void;
};

export default function NavBar({ active, onNavigate }: Props) {
  return (
    <nav className="border-b border-stone-200 bg-stone-50/95 backdrop-blur sticky top-0 z-10">
      <div className="max-w-6xl mx-auto px-5 sm:px-8">
        <div className="flex items-center justify-between py-4">
          <button
            type="button"
            onClick={() => onNavigate('home')}
            className="flex items-baseline gap-3 text-left group"
          >
            <span className="text-base font-semibold tracking-tight text-slate-900 group-hover:text-amber-700 transition-colors">
              Italian Silver Atlas
            </span>
            <span className="hidden sm:inline text-xs text-stone-500">
              Silver economy intelligence
            </span>
          </button>
        </div>
        <div className="flex flex-wrap gap-0 -mb-px">
          {TABS.map((t) => (
            <button
              key={t.id}
              type="button"
              onClick={() => onNavigate(t.id)}
              className={[
                'px-4 sm:px-5 py-3 text-sm border-b-2 -mb-px transition-colors',
                active === t.id || (active === 'methods' && t.id === 'home')
                  ? 'border-amber-500 text-slate-900 font-medium'
                  : 'border-transparent text-stone-600 hover:text-slate-900',
              ].join(' ')}
            >
              {t.label}
            </button>
          ))}
        </div>
      </div>
    </nav>
  );
}
