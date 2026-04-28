import robust from '../data/robustness.json';
import type { View } from '../types';

type Props = {
  onNavigate?: (v: View) => void;
};

export default function Robustness({ onNavigate }: Props) {
  const sens = robust.sensitivity_4d_vs_5d;
  const conv = robust.kmeans_lca_convergence;
  const fa = robust.factor_analysis_stability;
  const ma = robust.multi_algorithm;

  return (
    <section className="space-y-16 max-w-4xl">
      <header className="space-y-4">
        <p className="eyebrow">03 · Robustness</p>
        <h1 className="display-1 text-slate-900">
          Does the segmentation survive every reasonable alternative?
        </h1>
        <p className="text-lg text-zinc-700 leading-relaxed">
          Five robustness checks documented in chapter&nbsp;6 of the underlying
          thesis. The 4D-vs-5D sensitivity is the methodologically central
          one: it tests whether including subjective wellbeing as a clustering
          input is empirically justified, or whether the same partition would
          emerge from objective indicators alone.
        </p>
      </header>

      <Section title="4D vs 5D sensitivity">
        <p className="text-sm text-zinc-700 leading-relaxed">
          {sens.description}
        </p>
        <div className="rounded-xl bg-white border border-zinc-200 overflow-hidden mt-3">
          <table className="w-full text-sm">
            <thead className="bg-zinc-50 border-b border-zinc-200">
              <tr className="text-left">
                <th className="py-2.5 px-3 eyebrow">Country</th>
                <th className="py-2.5 px-3 eyebrow">Specification</th>
                <th className="py-2.5 px-3 eyebrow text-right">k</th>
                <th className="py-2.5 px-3 eyebrow text-right">Silhouette</th>
                <th className="py-2.5 px-3 eyebrow text-right">Within R²</th>
                <th className="py-2.5 px-3 eyebrow text-right">F (life sat.)</th>
                <th className="py-2.5 px-3 eyebrow text-right">ARI vs 5D</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {sens.rows.map((r, i) => (
                <tr
                  key={`${r.country}-${r.specification}`}
                  className={
                    r.specification.startsWith('5D')
                      ? 'bg-emerald-50'
                      : i % 2 === 0
                        ? 'bg-white'
                        : 'bg-zinc-50/40'
                  }
                >
                  <td className="py-2.5 px-3 text-slate-900 font-medium">
                    {r.country}
                  </td>
                  <td className="py-2.5 px-3 text-zinc-700">{r.specification}</td>
                  <td className="py-2.5 px-3 text-right tabular-nums">{r.k}</td>
                  <td className="py-2.5 px-3 text-right tabular-nums text-zinc-700">
                    {r.silhouette.toFixed(3)}
                  </td>
                  <td className="py-2.5 px-3 text-right tabular-nums text-zinc-700">
                    {r.within_r2.toFixed(3)}
                  </td>
                  <td className="py-2.5 px-3 text-right tabular-nums font-medium text-slate-900">
                    {r.anova_f_lifesat.toFixed(1)}
                  </td>
                  <td className="py-2.5 px-3 text-right tabular-nums text-zinc-700">
                    {r.ari_vs_5d !== null ? r.ari_vs_5d.toFixed(3) : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="text-sm text-zinc-700 leading-relaxed mt-3">
          {sens.interpretation}
        </p>
      </Section>

      <Section title="K-means / LCA convergence">
        <p className="text-sm text-zinc-700 leading-relaxed">
          {conv.description}
        </p>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-3">
          <ConvergenceTable country="Italy" rows={conv.italy} />
          <ConvergenceTable country="Sweden" rows={conv.sweden} />
        </div>
        <p className="text-sm text-zinc-700 leading-relaxed mt-4">
          {conv.interpretation}
        </p>
      </Section>

      <Section title="Multi-algorithm comparison">
        <p className="text-sm text-zinc-700 leading-relaxed">
          {ma.description}
        </p>
        <div className="rounded-xl bg-zinc-50 border border-zinc-200 p-4 mt-3">
          <p className="text-sm text-zinc-700 leading-relaxed">
            {ma.summary}
          </p>
        </div>
        <p className="text-sm text-zinc-700 leading-relaxed mt-4">
          <span className="font-medium">Duda–Hart cut-off corroboration:</span>{' '}
          {ma.duda_hart.comment}
        </p>
      </Section>

      <Section title="Factor analysis adequacy">
        <div className="rounded-xl bg-white border border-zinc-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-zinc-50 border-b border-zinc-200">
              <tr className="text-left">
                <th className="py-2.5 px-3 eyebrow">Diagnostic</th>
                <th className="py-2.5 px-3 eyebrow text-right">Italy</th>
                <th className="py-2.5 px-3 eyebrow text-right">Sweden</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              <tr>
                <td className="py-2.5 px-3 text-zinc-700">
                  Kaiser–Meyer–Olkin (≥ 0.80 meritorious)
                </td>
                <td className="py-2.5 px-3 text-right tabular-nums font-medium text-slate-900">
                  {fa.kmo_italy.toFixed(3)}
                </td>
                <td className="py-2.5 px-3 text-right tabular-nums font-medium text-slate-900">
                  {fa.kmo_sweden.toFixed(3)}
                </td>
              </tr>
              <tr>
                <td className="py-2.5 px-3 text-zinc-700">
                  Bartlett's χ² (df), p&nbsp;&lt;&nbsp;10⁻³⁰⁰
                </td>
                <td className="py-2.5 px-3 text-right tabular-nums text-zinc-700">
                  {fa.bartlett_chi2_italy.toLocaleString()} ({fa.bartlett_df_italy})
                </td>
                <td className="py-2.5 px-3 text-right tabular-nums text-zinc-700">
                  {fa.bartlett_chi2_sweden.toLocaleString()} ({fa.bartlett_df_sweden})
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <p className="text-sm text-zinc-700 leading-relaxed mt-3">
          <span className="font-medium">Heywood case (Sweden):</span>{' '}
          {fa.heywood_case}
        </p>
      </Section>

      <p className="text-xs text-zinc-500 leading-relaxed border-t border-zinc-200 pt-6">
        All robustness tables are reproductions of figures and tables in
        chapter&nbsp;6 of the underlying thesis. Source data: SHARE Wave 9
        release 9.0.0; pipeline scripts in <code className="text-xs bg-zinc-100 rounded px-1.5 py-0.5">v9/</code>.
      </p>

      {onNavigate && (
        <button
          type="button"
          onClick={() => onNavigate('profiler')}
          className="block w-full text-left rounded-2xl border border-emerald-200 bg-emerald-50 hover:bg-emerald-100 hover:border-emerald-400 transition-colors p-8 group"
        >
          <p className="eyebrow text-emerald-700">Continue · 04</p>
          <p className="display-2 text-slate-900 mt-3">
            OK, now try the model.
          </p>
          <p className="mt-3 text-base text-zinc-700 leading-relaxed max-w-3xl">
            Score yourself with ten plain-language questions, or upload a CSV
            of your cohort and get the full segmentation in one go.
          </p>
          <p className="mt-6 text-sm font-medium text-emerald-700 group-hover:translate-x-1 transition-transform inline-flex items-center gap-2">
            Try the model →
          </p>
        </button>
      )}
    </section>
  );
}

function ConvergenceTable({
  country,
  rows,
}: {
  country: string;
  rows: { profile: string; n: number; modal_lca: number; convergence_pct: number }[];
}) {
  return (
    <div className="rounded-xl bg-white border border-zinc-200 overflow-hidden">
      <div className="bg-zinc-50 border-b border-zinc-200 px-3 py-2 eyebrow">
        {country}
      </div>
      <table className="w-full text-sm">
        <thead className="border-b border-zinc-200">
          <tr className="text-left">
            <th className="py-2 px-3 eyebrow">Profile</th>
            <th className="py-2 px-3 eyebrow text-right">n</th>
            <th className="py-2 px-3 eyebrow text-right">Convergence</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-zinc-100">
          {rows.map((r) => (
            <tr key={r.profile}>
              <td className="py-2 px-3 text-zinc-800">{r.profile}</td>
              <td className="py-2 px-3 text-right tabular-nums text-zinc-600">
                {r.n}
              </td>
              <td className="py-2 px-3 text-right tabular-nums">
                <span
                  className={
                    r.convergence_pct >= 75
                      ? 'text-emerald-700 font-medium'
                      : r.convergence_pct >= 60
                        ? 'text-zinc-800'
                        : 'text-zinc-500'
                  }
                >
                  {r.convergence_pct.toFixed(1)}%
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="space-y-3">
      <h2 className="display-3 text-slate-900">{title}</h2>
      <div className="space-y-3">{children}</div>
    </section>
  );
}
