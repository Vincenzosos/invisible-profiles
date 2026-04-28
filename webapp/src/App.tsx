import { useState } from 'react';
import NavBar from './components/NavBar';
import Home from './components/Home';
import Atlas from './components/Atlas';
import Benchmark from './components/Benchmark';
import OpportunityExplorer from './components/OpportunityExplorer';
import ProfilerFlow from './components/ProfilerFlow';
import Methods from './components/Methods';
import type { View } from './types';

export default function App() {
  const [view, setView] = useState<View>('home');

  return (
    <div className="min-h-screen text-slate-900">
      <NavBar active={view} onNavigate={setView} />
      <main className="max-w-6xl mx-auto py-12 sm:py-16 px-5 sm:px-8">
        {view === 'home' && <Home onNavigate={setView} />}
        {view === 'atlas' && <Atlas />}
        {view === 'benchmark' && <Benchmark />}
        {view === 'opportunity' && <OpportunityExplorer />}
        {view === 'profiler' && <ProfilerFlow />}
        {view === 'methods' && <Methods />}
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
              Methods & data
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
