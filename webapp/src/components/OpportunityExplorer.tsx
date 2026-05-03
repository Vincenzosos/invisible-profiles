import { useState } from 'react';
import playbooks from '../data/playbooks.json';
import killer from '../data/killer_numbers.json';
import { formatIndividuals } from '../lib/format';
import { downloadFile, writeCSV } from '../lib/csv';

type Vertical = (typeof playbooks.verticals)[number];
type SkipEntry = { profile: string; reason?: string; rationale?: string };

const PREMIUM_RANGES = killer.premium_assumptions;

// Per-vertical premium-range string. Mirrors what MarketRanges renders
// inline. Kept in one place so the CSV export and the on-screen panel
// cannot drift.
function premiumStringFor(verticalId: string): string {
  if (verticalId === 'health_insurance') {
    const d = PREMIUM_RANGES.dental_eur_per_individual_per_year;
    const s = PREMIUM_RANGES.specialist_eur_per_individual_per_year;
    return `Dental €${d.low}-€${d.high}/yr; Specialist €${s.low}-€${s.high}/yr`;
  }
  if (verticalId === 'pharma_otc') {
    const o = PREMIUM_RANGES.otc_pharma_eur_per_individual_per_year;
    return `OTC + adherence €${o.low}-€${o.high}/yr per individual`;
  }
  if (verticalId === 'wealth_management') {
    return '0.5%-1.5% AUM/yr (all-in fee load)';
  }
  if (verticalId === 'senior_living') {
    return 'RSA / independent senior living €1,500-€3,000/month';
  }
  return '';
}

function buildCrmCsv(): string {
  type Row = {
    profile: string;
    vertical: string;
    criteria: string;
    include_or_exclude: 'include' | 'exclude';
    expected_market_premium: string;
  };
  const rows: Row[] = [];
  for (const v of playbooks.verticals) {
    const criteria = v.crm_criteria.join(' | ');
    const premium = premiumStringFor(v.id);
    for (const t of v.targets) {
      rows.push({
        profile: t.profile,
        vertical: v.label,
        criteria,
        include_or_exclude: 'include',
        expected_market_premium: premium,
      });
    }
    for (const s of v.skip) {
      rows.push({
        profile: s.profile,
        vertical: v.label,
        criteria,
        include_or_exclude: 'exclude',
        expected_market_premium: premium,
      });
    }
  }
  const headers = [
    'profile',
    'vertical',
    'criteria',
    'include_or_exclude',
    'expected_market_premium',
  ];
  return writeCSV(headers, rows);
}

export default function OpportunityExplorer() {
  const [activeId, setActiveId] = useState(playbooks.verticals[0].id);
  const active = playbooks.verticals.find((v) => v.id === activeId)!;

  return (
    <section className="space-y-12">
      <header className="space-y-6 max-w-4xl">
        <p className="eyebrow">Opportunity Explorer</p>
        <h1 className="display-1 text-slate-900">
          Pick a vertical. Get the play.
        </h1>
        <p className="text-lg text-zinc-700 leading-relaxed max-w-3xl">
          Each playbook ranks the five Italian profiles by qualitative
          commercial fit, names the targets to skip, and exports the criteria
          you can plug into a CRM. We do not multiply premium × conversion ×
          segment to produce a single addressable € figure: the conversion
          assumption would not survive scrutiny. Instead we report the{' '}
          <span className="text-blue-700 font-medium">sourced market premium ranges</span>{' '}
          and the segment size in individuals, and leave the multiplication
          to the operator who owns their conversion assumptions.
        </p>
        <button
          type="button"
          onClick={() => downloadFile('crm_mapping.csv', buildCrmCsv())}
          className="inline-flex items-center gap-2 rounded-xl border border-blue-300 bg-blue-50 hover:bg-blue-100 hover:border-blue-500 transition-colors px-4 py-2.5 text-sm font-medium text-blue-700"
        >
          <span aria-hidden="true">↓</span> Download CRM mapping (CSV)
        </button>
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
                : 'bg-white text-zinc-700 border-zinc-300 hover:border-slate-500 hover:text-slate-900',
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
    <div className="space-y-10">
      <article className="rounded-2xl bg-white border border-zinc-200 p-8 space-y-4">
        <p className="eyebrow">{v.tagline}</p>
        <h2 className="display-2 text-slate-900">{v.label}</h2>
        <p className="text-base text-zinc-700 leading-relaxed max-w-3xl">
          {v.summary}
        </p>
      </article>

      <MarketRanges verticalId={v.id} />

      <section className="space-y-4">
        <h3 className="display-3 text-slate-900">Top targets, ranked by fit</h3>
        {v.targets.map((t, i) => (
          <article
            key={t.profile}
            className={[
              'rounded-2xl border p-6 space-y-3',
              i === 0
                ? 'bg-blue-50 border-blue-200'
                : 'bg-white border-zinc-200',
            ].join(' ')}
          >
            <header className="flex items-baseline justify-between flex-wrap gap-3">
              <div>
                <p className="eyebrow">
                  Rank {i + 1} · qualitative fit {t.fit_score}/10
                </p>
                <h4 className="display-3 text-slate-900 mt-1">{t.profile}</h4>
              </div>
              <p className="text-sm text-zinc-500 tabular-nums">
                {formatIndividuals(t.addressable_market_individuals)} individuals
              </p>
            </header>
            <p className="text-sm text-zinc-700 leading-relaxed">
              {t.rationale}
            </p>
          </article>
        ))}
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
        <section className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-3">
          <p className="eyebrow">Market context</p>
          <ul className="text-sm text-zinc-700 space-y-1.5 leading-relaxed">
            {v.context_notes.map((n, i) => (
              <li key={i} className="flex items-start gap-2">
                <span className="text-blue-700 mt-0.5">▸</span>
                <span>{n}</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="rounded-2xl bg-slate-900 text-white p-8 space-y-5">
        <p className="eyebrow text-blue-400">Plug into your CRM</p>
        <h3 className="display-3 text-white">Targeting criteria</h3>
        <ul className="text-sm space-y-2 max-w-3xl">
          {v.crm_criteria.map((c, i) => (
            <li key={i} className="flex items-start gap-3 text-zinc-200">
              <span className="text-blue-400 mt-0.5">▸</span>
              <span>{c}</span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

function MarketRanges({ verticalId }: { verticalId: string }) {
  let title: string | null = null;
  let rows: { label: string; range: string; sources: string[] }[] = [];

  if (verticalId === 'health_insurance') {
    title = 'Sourced market premium ranges';
    rows = [
      {
        label: 'Senior individual dental insurance',
        range: `€${PREMIUM_RANGES.dental_eur_per_individual_per_year.low}–€${PREMIUM_RANGES.dental_eur_per_individual_per_year.high} / year`,
        sources: PREMIUM_RANGES.dental_eur_per_individual_per_year.sources,
      },
      {
        label: 'Private specialist consultation',
        range: `€${PREMIUM_RANGES.specialist_eur_per_individual_per_year.low}–€${PREMIUM_RANGES.specialist_eur_per_individual_per_year.high} / year`,
        sources: PREMIUM_RANGES.specialist_eur_per_individual_per_year.sources,
      },
    ];
  }

  if (verticalId === 'pharma_otc') {
    title = 'Sourced market spending ranges';
    rows = [
      {
        label: 'Senior OTC + adherence spend per individual',
        range: `€${PREMIUM_RANGES.otc_pharma_eur_per_individual_per_year.low}–€${PREMIUM_RANGES.otc_pharma_eur_per_individual_per_year.high} / year`,
        sources: PREMIUM_RANGES.otc_pharma_eur_per_individual_per_year.sources,
      },
    ];
  }

  if (verticalId === 'wealth_management') {
    title = 'Sourced fee ranges';
    rows = [
      {
        label: 'All-in wealth-management fee (% AUM)',
        range: '0.5%–1.5% / year',
        sources: ['aipb_2024', 'asset_mgmt_fees_2024'],
      },
    ];
  }

  if (verticalId === 'senior_living') {
    title = 'Sourced market price ranges';
    rows = [
      {
        label: 'RSA / independent senior-living monthly cost',
        range: '€1,500–€3,000 / month',
        sources: ['rsa_costs_2024'],
      },
    ];
  }

  if (!title || rows.length === 0) return null;

  return (
    <section className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-3">
      <p className="eyebrow">{title}</p>
      <div className="border-t border-zinc-200 divide-y divide-zinc-100">
        {rows.map((r) => (
          <div
            key={r.label}
            className="flex items-baseline justify-between gap-4 py-3 flex-wrap"
          >
            <span className="text-sm text-zinc-700">{r.label}</span>
            <span className="text-sm font-medium text-slate-900 tabular-nums">
              {r.range}
              <span className="block text-xs text-zinc-500 font-normal text-right">
                {r.sources.map((s, i) => (
                  <span key={s}>
                    <code className="bg-zinc-100 px-1.5 py-0.5 rounded">{s}</code>
                    {i < r.sources.length - 1 && ' · '}
                  </span>
                ))}
              </span>
            </span>
          </div>
        ))}
      </div>
      <p className="text-xs text-zinc-500 leading-relaxed">
        Source identifiers refer to the bibliography in Methods &amp; data.
        These ranges are market data — not multiplied by segment size or
        conversion to produce an opportunity €.
      </p>
    </section>
  );
}

function SkipCard({ item }: { item: SkipEntry }) {
  const text = item.reason ?? item.rationale ?? '';
  return (
    <div className="rounded-xl bg-white border border-zinc-200 p-4 space-y-1">
      <p className="text-sm font-medium text-slate-900">{item.profile}</p>
      <p className="text-xs text-zinc-600 leading-relaxed">{text}</p>
    </div>
  );
}
