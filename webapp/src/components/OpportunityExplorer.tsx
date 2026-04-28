import { useState } from 'react';
import playbooks from '../data/playbooks.json';
import { formatIndividuals } from '../lib/format';

type Vertical = (typeof playbooks.verticals)[number];
type SkipEntry = { profile: string; reason?: string; rationale?: string };

export default function OpportunityExplorer() {
  const [activeId, setActiveId] = useState(playbooks.verticals[0].id);
  const active = playbooks.verticals.find((v) => v.id === activeId)!;

  return (
    <section className="space-y-8">
      <header className="space-y-3 max-w-4xl">
        <p className="text-xs uppercase tracking-wide text-slate-500">
          Opportunity Explorer · vertical playbooks
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-slate-900">
          Translate the segmentation into a vertical-specific go-to-market
        </h1>
        <p className="text-slate-700 leading-relaxed">
          For each vertical, we rank the 5 Italian profiles by commercial fit,
          size the addressable market with explicit single-anchor assumptions,
          identify the targets to skip and the channels to use, and export the
          CRM-ready criteria for segmentation tools. Numbers are derived from
          the Atlas and Benchmark; assumptions are stated transparently.
        </p>
      </header>

      <nav className="flex flex-wrap gap-2">
        {playbooks.verticals.map((v) => (
          <button
            key={v.id}
            type="button"
            onClick={() => setActiveId(v.id)}
            className={[
              'rounded-full border px-4 py-2 text-sm transition-colors',
              activeId === v.id
                ? 'bg-slate-900 text-white border-slate-900'
                : 'bg-white text-slate-700 border-slate-300 hover:border-slate-500',
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
  return (
    <div className="space-y-6">
      <article className="rounded-2xl bg-white border border-slate-200 p-6 space-y-3">
        <div className="flex items-baseline justify-between flex-wrap gap-3">
          <div>
            <h2 className="text-2xl font-semibold tracking-tight text-slate-900">
              {v.label}
            </h2>
            <p className="text-sm text-slate-500">{v.tagline}</p>
          </div>
          <div className="text-right">
            <p className="text-xs uppercase tracking-wide text-slate-500">
              Total addressable
            </p>
            <p className="text-2xl font-semibold text-slate-900 tabular-nums">
              €{v.addressable_total_eur_m_per_year}M / year
            </p>
          </div>
        </div>
        <p className="text-sm text-slate-700 leading-relaxed max-w-3xl">
          {v.summary}
        </p>
      </article>

      <section className="space-y-3">
        <h3 className="text-base font-semibold text-slate-900">
          Top targets, ranked by fit
        </h3>
        {v.targets.map((t, i) => (
          <article
            key={t.profile}
            className="rounded-xl bg-white border border-slate-200 p-5 space-y-3"
          >
            <header className="flex items-baseline justify-between flex-wrap gap-3">
              <div>
                <p className="text-xs text-slate-500">
                  Rank {i + 1} · fit score {t.fit_score}/10
                </p>
                <h4 className="text-lg font-semibold text-slate-900">
                  {t.profile}
                </h4>
              </div>
              <div className="text-right">
                <p className="text-xs uppercase text-slate-500 tracking-wide">
                  Addressable
                </p>
                <p className="font-medium text-slate-900 tabular-nums">
                  {formatIndividuals(t.addressable_market_individuals)} ·{' '}
                  €{t.addressable_market_eur_m_per_year}M/y
                </p>
              </div>
            </header>
            <p className="text-sm text-slate-700 leading-relaxed">
              {t.rationale}
            </p>
            <p className="text-xs text-slate-500 italic leading-relaxed">
              Sizing assumption: {t.addressable_market_eur_assumption}
            </p>
          </article>
        ))}
      </section>

      {v.skip.length > 0 && (
        <section className="space-y-2">
          <h3 className="text-base font-semibold text-slate-900">
            Targets to skip
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {v.skip.map((s) => (
              <SkipCard key={s.profile} item={s} />
            ))}
          </div>
        </section>
      )}

      <section className="rounded-2xl bg-slate-900 text-white p-6 space-y-3">
        <h3 className="text-base font-semibold">CRM-ready criteria</h3>
        <p className="text-xs text-slate-300 max-w-3xl leading-relaxed">
          Plug these criteria into your segmentation / marketing-automation
          tool. Combined with internal customer data, they reproduce a
          first-pass approximation of the targets identified above. Methodology
          and exact thresholds are documented in chapter 8 of the underlying
          thesis.
        </p>
        <ul className="text-sm space-y-1.5 max-w-3xl">
          {v.crm_criteria.map((c, i) => (
            <li key={i} className="flex items-start gap-2">
              <span className="text-slate-400 mt-0.5">▸</span>
              <span>{c}</span>
            </li>
          ))}
        </ul>
        <p className="text-xs text-slate-400 italic">
          Export as JSON / CSV / Salesforce list view: stub — see API
          documentation in chapter 8.
        </p>
      </section>
    </div>
  );
}

function SkipCard({ item }: { item: SkipEntry }) {
  const text = item.reason ?? item.rationale ?? '';
  return (
    <div className="rounded-xl bg-slate-50 border border-slate-200 p-4 space-y-1">
      <p className="text-sm font-medium text-slate-900">{item.profile}</p>
      <p className="text-xs text-slate-700 leading-relaxed">{text}</p>
    </div>
  );
}
