import { useState } from 'react';
import NavBar from './components/NavBar';
import SectionTabs from './components/SectionTabs';
import Home from './components/Home';
import Atlas from './components/Atlas';
import Benchmark from './components/Benchmark';
import OpportunityExplorer from './components/OpportunityExplorer';
import ProfilerFlow from './components/ProfilerFlow';
import Robustness from './components/Robustness';
import Methods from './components/Methods';
import type { View } from './types';

const FINDINGS: View[] = ['atlas', 'benchmark'];
const METHODOLOGY: View[] = ['methods', 'robustness'];

export default function App() {
  const [view, setView] = useState<View>('home');

  const inFindings = FINDINGS.includes(view);
  const inMethodology = METHODOLOGY.includes(view);

  return (
    <div className="min-h-screen text-slate-900">
      <NavBar active={view} onNavigate={setView} />
      <main className="max-w-6xl mx-auto py-12 sm:py-16 px-5 sm:px-8 space-y-10">
        {inFindings && (
          <SectionTabs section="findings" active={view} onNavigate={setView} />
        )}
        {inMethodology && (
          <SectionTabs section="methodology" active={view} onNavigate={setView} />
        )}

        {view === 'home' && <Home onNavigate={setView} />}
        {view === 'atlas' && <Atlas onNavigate={setView} />}
        {view === 'benchmark' && <Benchmark onNavigate={setView} />}
        {view === 'opportunity' && <OpportunityExplorer />}
        {view === 'profiler' && <ProfilerFlow />}
        {view === 'robustness' && <Robustness onNavigate={setView} />}
        {view === 'methods' && <Methods onNavigate={setView} />}
      </main>
      <footer className="border-t border-zinc-200 mt-20 py-8">
        <div className="max-w-6xl mx-auto px-5 sm:px-8 flex flex-wrap items-center justify-between gap-3 text-xs text-zinc-500">
          <span>Italian Silver Atlas · MSc thesis, Bocconi EMIT</span>
          <div className="flex items-center gap-4">
            <button
              type="button"
              onClick={() => setView('methods')}
              className="hover:text-slate-900 transition-colors"
            >
              Methods &amp; data
            </button>
            <a
              className="hover:text-slate-900 transition-colors"
              href="https://github.com/Vincenzosos/invisible-profiles"
              target="_blank"
              rel="noopener noreferrer"
            >
              Source
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
