import type { View } from '../types';

const TABS: { id: View; label: string; description: string }[] = [
  { id: 'home',        label: 'Overview',   description: 'Italy\'s silver economy at a glance' },
  { id: 'atlas',       label: 'Atlas',      description: '5 segments, sized in € and individuals' },
  { id: 'benchmark',   label: 'Benchmark',  description: 'Italy ↔ Sweden gap signals' },
  { id: 'opportunity', label: 'Opportunity',description: 'Vertical playbooks for operators' },
  { id: 'profiler',    label: 'Profiler',   description: '10-question demo of the engine' },
];

type Props = {
  active: View;
  onNavigate: (v: View) => void;
};

export default function NavBar({ active, onNavigate }: Props) {
  return (
    <nav className="border-b border-slate-200 bg-white sticky top-0 z-10">
      <div className="max-w-6xl mx-auto px-4 sm:px-6">
        <div className="flex items-center justify-between py-3">
          <button
            type="button"
            onClick={() => onNavigate('home')}
            className="flex items-baseline gap-2 text-left"
          >
            <span className="text-base font-semibold tracking-tight text-slate-900">
              Italian Silver Atlas
            </span>
            <span className="hidden sm:inline text-xs text-slate-500">
              SHARE Wave 9 · Italy + Sweden · 5+6 evidence-based segments
            </span>
          </button>
        </div>
        <div className="flex flex-wrap gap-1 -mb-px">
          {TABS.map((t) => (
            <button
              key={t.id}
              type="button"
              onClick={() => onNavigate(t.id)}
              className={[
                'px-3 sm:px-4 py-2.5 text-sm border-b-2 transition-colors',
                active === t.id
                  ? 'border-slate-900 text-slate-900 font-medium'
                  : 'border-transparent text-slate-600 hover:text-slate-900 hover:border-slate-300',
              ].join(' ')}
              title={t.description}
            >
              {t.label}
            </button>
          ))}
        </div>
      </div>
    </nav>
  );
}
