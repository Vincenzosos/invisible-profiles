import { useState } from 'react';
import centroidsData from './data/centroids.json';
import narrativesData from './data/profile_narratives.json';
import Landing from './components/Landing';
import Quiz from './components/Quiz';
import Result from './components/Result';
import type { Country } from './lib/profiler';

type View = 'landing' | 'quiz' | 'result';

const narratives = narrativesData as {
  italy: Record<string, string>;
  sweden: Record<string, string>;
};

export default function App() {
  const [view, setView] = useState<View>('landing');
  const [country, setCountry] = useState<Country | null>(null);
  const [answers, setAnswers] = useState<Record<string, number>>({});

  const handleSelectCountry = (c: Country) => {
    setCountry(c);
    setAnswers({});
    setView('quiz');
  };

  const handleQuizComplete = (a: Record<string, number>) => {
    setAnswers(a);
    setView('result');
  };

  const handleRestart = () => {
    setView('landing');
    setCountry(null);
    setAnswers({});
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      <main className="max-w-2xl mx-auto py-12 px-4">
        {view === 'landing' && <Landing onSelectCountry={handleSelectCountry} />}
        {view === 'quiz' && country && (
          <Quiz
            country={country}
            keyVariables={centroidsData.key_variables}
            onComplete={handleQuizComplete}
            onBack={handleRestart}
          />
        )}
        {view === 'result' && country && (
          <Result
            country={country}
            answers={answers}
            data={centroidsData}
            narratives={narratives}
            onRestart={handleRestart}
          />
        )}
      </main>
    </div>
  );
}
