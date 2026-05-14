import type { View } from '../types';

// 4 macro-sections instead of 6 paritetic tabs.
// Each section maps to a default sub-view; sub-views are reached via
// a secondary pill bar (SectionTabs) rendered inside the page.
const SECTIONS: {
  id: View;            // default view when the section is opened
  label: string;
  members: View[];     // all views that belong to this section (for active state)
}[] = [
  { id: 'home',     label: 'Overview',          members: ['home'] },
  { id: 'atlas',    label: 'The Five Segments', members: ['atlas', 'benchmark', 'opportunity', 'validation'] },
  { id: 'methods',  label: 'Methodology',       members: ['methods', 'robustness'] },
  { id: 'profiler', label: 'Try the model',     members: ['profiler'] },
];

type Props = {
  active: View;
  onNavigate: (v: View) => void;
};

export default function NavBar({ active, onNavigate }: Props) {
  return (
    <nav className="border-b border-zinc-200 bg-zinc-50/95 backdrop-blur sticky top-0 z-10">
      <div className="max-w-6xl mx-auto px-5 sm:px-8">
        <div className="flex items-center justify-between py-4">
          <button
            type="button"
            onClick={() => onNavigate('home')}
            className="flex items-baseline gap-3 text-left group"
          >
            <span className="text-base font-semibold tracking-tight text-slate-900 group-hover:text-blue-700 transition-colors">
              Italian Silver Atlas
            </span>
            <span className="hidden sm:inline text-xs text-zinc-500">
              Evidence-based segmentation of the Italian over-65 population
            </span>
          </button>
        </div>
        <div className="flex flex-wrap gap-0 -mb-px">
          {SECTIONS.map((s) => {
            const isActive = s.members.includes(active);
            return (
              <button
                key={s.id}
                type="button"
                onClick={() => onNavigate(s.id)}
                className={[
                  'px-4 sm:px-5 py-3 text-sm border-b-2 -mb-px transition-colors',
                  isActive
                    ? 'border-blue-700 text-slate-900 font-medium'
                    : 'border-transparent text-zinc-600 hover:text-slate-900',
                ].join(' ')}
              >
                {s.label}
              </button>
            );
          })}
        </div>
      </div>
    </nav>
  );
}
