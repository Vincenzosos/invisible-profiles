import { useState } from 'react';
import playbooks from '../data/playbooks.json';
import { formatIndividuals } from '../lib/format';

type Vertical = (typeof playbooks.verticals)[number];
type SkipEntry = { profile: string; reason?: string; rationale?: string };
type Range = { low: number; central: number; high: number };

export default function OpportunityExplorer() {
  const [activeId, setActiveId] = useState(playbooks.verticals[0].id);
  const active = playbooks.verticals.find((v) => v.id === activeId)!;

  return (
    <section className="space-y-12">
      <header className="space-y-6 max-w-4xl">
        <p className="eyebrow">Opportunity Explorer</p>
        <h1 className="display-1 text-slate-900">Pick a vertical. Get the play.</h1>
        <p className="text-lg text-stone-700 leading-relaxed max-w-3xl">
          Each playbook ranks the five Italian profiles by commercial fit,
          sizes the addressable market with sourced low / central / high
          ranges, names the targets to skip, and exports the criteria you can
          plug into a CRM. Sources are documented in the Methods page.
        </p>
      </header>

      <nav className="flex flex-wrap gap-2">
        {playbooks.verticals.map((v) => (
          <button
            key={v.id}
            type="button"
            onClick={() => setActiveId(v.id)}
            className={[
              'rounded-full border px-5 py-2.5 text-sm transition-colors',
              activeId === v.id
                ? 'bg-slate-900 text-white border-slate-900'
                : 'bg-white text-stone-700 border-stone-300 hover:border-slate-500 hover:text-slate-900',
            ].join(' ')}
          >
            {v.label}
          </button>
        ))}
      </nav>

      <PlaybookView vertical={active} />
    </section>
  );
}

function PlaybookView({ vertical: v }: { vertical: Vertical }) {
  const total = v.addressable_total_eur_m_per_year as Range;
  return (
    <div className="space-y-10">
      <article className="rounded-2xl bg-white border border-stone-200 p-8 space-y-5">
        <div className="flex items-baseline justify-between flex-wrap gap-4">
          <div>
            <p className="eyebrow">{v.tagline}</p>
            <h2 className="display-2 text-slate-900 mt-2">{v.label}</h2>
          </div>
          <div className="text-right">
            <p className="eyebrow text-amber-700">Total addressable</p>
            <p className="metric-hero text-amber-800 mt-2">
              €{total.central}M
            </p>
            <p className="text-xs text-stone-500 mt-1">
              €{total.low}M low · €{total.high}M high · per year
            </p>
          </div>
        </div>
        <p className="text-base text-stone-700 leading-relaxed max-w-3xl">
          {v.summary}
        </p>
      </article>

      <section className="space-y-4">
        <h3 className="display-3 text-slate-900">Top targets</h3>
        {v.targets.map((t, i) => {
          const range = t.addressable_market_eur_m_per_year as Range;
          return (
            <article
              key={t.profile}
              className={[
                'rounded-2xl border p-6 space-y-4',
                i === 0
                  ? 'bg-amber-50 border-amber-200'
                  : 'bg-white border-stone-200',
              ].join(' ')}
            >
              <header className="flex items-baseline justify-between flex-wrap gap-3">
                <div>
                  <p className="eyebrow">
                    Rank {i + 1} · fit {t.fit_score}/10
                  </p>
                  <h4 className="display-3 text-slate-900 mt-1">{t.profile}</h4>
                </div>
                <div className="text-right">
                  <p className="eyebrow">Addressable</p>
                  <p className="metric text-slate-900 mt-1">
                    €{range.central}M / y
                  </p>
                  <p className="text-xs text-stone-500 mt-0.5">
                    €{range.low}M – €{range.high}M
                  </p>
                  <p className="text-xs text-stone-500 mt-0.5">
                    {formatIndividuals(t.addressable_market_individuals)} individuals
                  </p>
                </div>
              </header>
              <p className="text-sm text-stone-700 leading-relaxed">
                {t.rationale}
              </p>
              <p className="text-xs text-stone-500 italic">
                {t.addressable_market_eur_assumption}
              </p>
              {t.sources && t.sources.length > 0 && (
                <p className="text-xs text-stone-500">
                  Sources:{' '}
                  {t.sources.map((s, idx) => (
                    <span key={s}>
                      <code className="bg-stone-100 px-1.5 py-0.5 rounded">{s}</code>
                      {idx < t.sources.length - 1 && ' · '}
                    </span>
                  ))}
                </p>
              )}
            </article>
          );
        })}
      </section>

      {v.skip.length > 0 && (
        <section className="space-y-4">
          <h3 className="display-3 text-slate-900">Skip</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {v.skip.map((s) => (
              <SkipCard key={s.profile} item={s as SkipEntry} />
            ))}
          </div>
        </section>
      )}

      {v.context_notes && v.context_notes.length > 0 && (
        <section className="rounded-2xl bg-white border border-stone-200 p-6 space-y-3">
          <p className="eyebrow">Context</p>
          <ul className="text-sm text-stone-700 space-y-1.5 leading-relaxed">
            {v.context_notes.map((n, i) => (
              <li key={i} className="flex items-start gap-2">
                <span className="text-amber-600 mt-0.5">▸</span>
                <span>{n}</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="rounded-2xl bg-slate-900 text-white p-8 space-y-5">
        <p className="eyebrow text-amber-400">Plug into your CRM</p>
        <h3 className="display-3 text-white">Targeting criteria</h3>
        <ul className="text-sm space-y-2 max-w-3xl">
          {v.crm_criteria.map((c, i) => (
            <li key={i} className="flex items-start gap-3 text-stone-200">
              <span className="text-amber-400 mt-0.5">▸</span>
              <span>{c}</span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

function SkipCard({ item }: { item: SkipEntry }) {
  const text = item.reason ?? item.rationale ?? '';
  return (
    <div className="rounded-xl bg-white border border-stone-200 p-4 space-y-1">
      <p className="text-sm font-medium text-slate-900">{item.profile}</p>
      <p className="text-xs text-stone-600 leading-relaxed">{text}</p>
    </div>
  );
}
