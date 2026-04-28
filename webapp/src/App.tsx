import { useState } from 'react';
import NavBar from './components/NavBar';
import Home from './components/Home';
import Atlas from './components/Atlas';
import Benchmark from './components/Benchmark';
import OpportunityExplorer from './components/OpportunityExplorer';
import ProfilerFlow from './components/ProfilerFlow';
import type { View } from './types';

export default function App() {
  const [view, setView] = useState<View>('home');

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      <NavBar active={view} onNavigate={setView} />
      <main className="max-w-6xl mx-auto py-8 sm:py-12 px-4 sm:px-6">
        {view === 'home' && <Home onNavigate={setView} />}
        {view === 'atlas' && <Atlas />}
        {view === 'benchmark' && <Benchmark />}
        {view === 'opportunity' && <OpportunityExplorer />}
        {view === 'profiler' && <ProfilerFlow />}
      </main>
      <footer className="border-t border-slate-200 mt-16 py-6 text-center text-xs text-slate-500">
        Italian Silver Atlas · MSc thesis (Bocconi EMIT, course 20570) ·
        Built on SHARE Wave 9, Istat 2024, SCB 2024 ·{' '}
        <a
          className="underline-offset-4 hover:underline"
          href="https://github.com/Vincenzosos/invisible-profiles"
          target="_blank"
          rel="noopener noreferrer"
        >
          source
        </a>
      </footer>
    </div>
  );
}
