import type { View } from '../types';

// Secondary pill-bar nav rendered at the top of pages that belong to a
// macro-section ("The Five Segments", "Methodology"). Lets the user
// switch between siblings without going back through the primary nav.

type Tab = { id: View; label: string };

type Props = {
  section: 'findings' | 'methodology';
  active: View;
  onNavigate: (v: View) => void;
};

const TABS: Record<Props['section'], { eyebrow: string; tabs: Tab[] }> = {
  findings: {
    eyebrow: 'The Five Segments',
    tabs: [
      { id: 'atlas',       label: 'The profiles' },
      { id: 'benchmark',   label: 'Italy ↔ Sweden' },
      { id: 'validation',  label: 'External validation' },
      { id: 'opportunity', label: 'Vertical playbooks' },
    ],
  },
  methodology: {
    eyebrow: 'Methodology',
    tabs: [
      { id: 'methods',    label: 'Methods & data' },
      { id: 'robustness', label: 'Robustness checks' },
    ],
  },
};

export default function SectionTabs({ section, active, onNavigate }: Props) {
  const cfg = TABS[section];
  return (
    <nav className="space-y-3">
      <p className="eyebrow">{cfg.eyebrow}</p>
      <div className="flex flex-wrap gap-2">
        {cfg.tabs.map((t) => {
          const isActive = t.id === active;
          return (
            <button
              key={t.id}
              type="button"
              onClick={() => onNavigate(t.id)}
              className={[
                'rounded-full px-4 py-2 text-sm border transition-colors',
                isActive
                  ? 'bg-slate-900 text-white border-slate-900'
                  : 'bg-white text-zinc-700 border-zinc-300 hover:border-slate-500',
              ].join(' ')}
            >
              {t.label}
            </button>
          );
        })}
      </div>
    </nav>
  );
}
