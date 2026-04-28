import { useState } from 'react';
import centroidsData from '../data/centroids.json';
import narrativesData from '../data/profile_narratives.json';
import Landing from './Landing';
import Quiz from './Quiz';
import Result from './Result';
import type { Country } from '../lib/profiler';

const narratives = narrativesData as {
  italy: Record<string, string>;
  sweden: Record<string, string>;
};

type Step = 'country' | 'quiz' | 'result';

export default function ProfilerFlow() {
  const [step, setStep] = useState<Step>('country');
  const [country, setCountry] = useState<Country | null>(null);
  const [answers, setAnswers] = useState<Record<string, number>>({});

  const handleSelectCountry = (c: Country) => {
    setCountry(c);
    setAnswers({});
    setStep('quiz');
  };

  const handleQuizComplete = (a: Record<string, number>) => {
    setAnswers(a);
    setStep('result');
  };

  const handleRestart = () => {
    setStep('country');
    setCountry(null);
    setAnswers({});
  };

  return (
    <div className="max-w-2xl mx-auto">
      {step === 'country' && <Landing onSelectCountry={handleSelectCountry} />}
      {step === 'quiz' && country && (
        <Quiz
          country={country}
          keyVariables={centroidsData.key_variables}
          onComplete={handleQuizComplete}
          onBack={handleRestart}
        />
      )}
      {step === 'result' && country && (
        <Result
          country={country}
          answers={answers}
          data={centroidsData}
          narratives={narratives}
          onRestart={handleRestart}
        />
      )}
    </div>
  );
}
