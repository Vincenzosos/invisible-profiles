import robust from '../data/robustness.json';
import crossWave from '../data/cross_wave_stability.json';
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
                      ? 'bg-blue-50'
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

      <CrossWaveSection />

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
          className="block w-full text-left rounded-2xl border border-blue-200 bg-blue-50 hover:bg-blue-100 hover:border-blue-400 transition-colors p-8 group"
        >
          <p className="eyebrow text-blue-700">Continue · 04</p>
          <p className="display-2 text-slate-900 mt-3">
            OK, now try the model.
          </p>
          <p className="mt-3 text-base text-zinc-700 leading-relaxed max-w-3xl">
            Score yourself with fifteen plain-language questions, or upload a CSV
            of your cohort and get the full segmentation in one go.
          </p>
          <p className="mt-6 text-sm font-medium text-blue-700 group-hover:translate-x-1 transition-transform inline-flex items-center gap-2">
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
                      ? 'text-blue-700 font-medium'
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

function ariBadge(ari: number): { text: string; cls: string } {
  if (ari >= 0.4)
    return {
      text: 'Substantial stability',
      cls: 'inline-block rounded-full bg-blue-50 text-blue-700 text-xs font-medium px-2.5 py-1',
    };
  if (ari >= 0.2)
    return {
      text: 'Moderate stability',
      cls: 'inline-block rounded-full bg-zinc-100 text-zinc-700 text-xs font-medium px-2.5 py-1',
    };
  return {
    text: 'Weak panel stability',
    cls: 'inline-block rounded-full bg-rose-50 text-rose-700 text-xs font-medium px-2.5 py-1',
  };
}

function CrossWaveSection() {
  return (
    <section className="space-y-6">
      <h2 className="display-3 text-slate-900">
        Cross-wave stability (W8 vs W9)
      </h2>
      <p className="text-sm text-zinc-700 leading-relaxed max-w-3xl">
        SHARE Wave 8 (2019&ndash;2020, pre-COVID) and Wave 9 (2021&ndash;2022,
        post-COVID) were processed independently through the full segmentation
        pipeline. Two complementary tests of stability are reported: (a) panel
        Adjusted Rand Index between W8 and W9 cluster assignments for the same
        individuals (test&ndash;retest stability under a pandemic shock); (b)
        Hungarian-matched centroid distance between W8 and W9 cluster centers
        in standardized space (structural replicability).
      </p>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {(['italy', 'sweden'] as const).map((c) => {
          const d = crossWave[c];
          const badge = ariBadge(d.ari);
          return (
            <article
              key={c}
              className="rounded-2xl bg-white border border-zinc-200 p-6 space-y-3"
            >
              <p className="eyebrow capitalize">{c}</p>
              <p className="metric-hero text-slate-900">
                ARI {d.ari.toFixed(3)}
              </p>
              <p className="text-xs text-zinc-500">
                95% CI [{d.ari_ci_low.toFixed(3)}, {d.ari_ci_high.toFixed(3)}]
                &nbsp;·&nbsp; panel n = {d.panel_n.toLocaleString()}
              </p>
              <span className={badge.cls}>{badge.text}</span>
            </article>
          );
        })}
      </div>

      <div className="space-y-6 mt-8">
        {(['italy', 'sweden'] as const).map((c) => {
          const d = crossWave[c];
          const nVars =
            c === 'italy'
              ? crossWave.meta.common_vars_italy.length
              : crossWave.meta.common_vars_sweden.length;
          return (
            <div key={c}>
              <h3 className="display-3 text-slate-900 capitalize">
                {c} &mdash; structural match
              </h3>
              <p className="text-xs text-zinc-500 mb-3">
                Hungarian-optimal pairing between W8 and W9 centroids in
                standardized space. Distance is Euclidean on the {nVars} common
                variables.
              </p>
              <div className="overflow-x-auto rounded-xl border border-zinc-200 bg-white">
                <table className="w-full text-sm">
                  <thead className="text-xs text-zinc-500 uppercase tracking-wider bg-zinc-50">
                    <tr className="border-b border-zinc-200">
                      <th className="text-left py-2 px-3">Profile W8</th>
                      <th className="text-left py-2 px-3">Profile W9 (Hungarian)</th>
                      <th className="text-right py-2 px-3">Distance</th>
                      <th className="text-right py-2 px-3">Share W8</th>
                      <th className="text-right py-2 px-3">Share W9</th>
                      <th className="text-right py-2 px-3">Δ pp</th>
                      <th className="text-center py-2 px-3">Match</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-zinc-100">
                    {d.structural_match.map((m, i) => (
                      <tr key={i}>
                        <td className="py-2 px-3 text-slate-900">
                          {m.profile_w8}
                        </td>
                        <td className="py-2 px-3 text-slate-900">
                          {m.profile_w9}
                        </td>
                        <td className="py-2 px-3 text-right tabular-nums text-zinc-700">
                          {m.centroid_distance.toFixed(2)}
                        </td>
                        <td className="py-2 px-3 text-right tabular-nums text-zinc-700">
                          {m.share_w8_pct.toFixed(1)}%
                        </td>
                        <td className="py-2 px-3 text-right tabular-nums text-zinc-700">
                          {m.share_w9_pct.toFixed(1)}%
                        </td>
                        <td
                          className={
                            'py-2 px-3 text-right tabular-nums ' +
                            (m.delta_share_pp > 0
                              ? 'text-blue-700'
                              : m.delta_share_pp < 0
                                ? 'text-rose-700'
                                : 'text-zinc-500')
                          }
                        >
                          {m.delta_share_pp > 0 ? '+' : ''}
                          {m.delta_share_pp.toFixed(1)}
                        </td>
                        <td
                          className={
                            'py-2 px-3 text-center ' +
                            (m.match_consistent_with_naming
                              ? 'text-blue-700'
                              : 'text-rose-700')
                          }
                        >
                          {m.match_consistent_with_naming ? '✓' : '⤬'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          );
        })}
      </div>

      <article className="rounded-2xl bg-blue-50 border border-blue-200 p-6 space-y-3 mt-8">
        <p className="eyebrow text-blue-700">Interpretation</p>
        <p className="text-sm text-zinc-800 leading-relaxed">
          The panel ARI is substantially lower in Italy than in Sweden,
          consistent with the differential pandemic shock on the over-65
          population (excess mortality, prolonged isolation). The
          Hungarian-matched centroid distances, by contrast, show that 4 out of
          5 Italian and 5 out of 6 Swedish archetypes have a structural twin
          across waves with Euclidean distance ≤ 1.32 on standardized
          variables. The two countries' boundary profiles (Moderate Isolated ↔
          Traditional Social in Italy; Social Decline ↔ Asset Rich in Sweden)
          re-name across waves but the overall typological scaffolding is
          preserved.
        </p>
        <p className="text-sm text-zinc-700 leading-relaxed">
          The contribution of this thesis is the structural typology, not the
          per-individual classifier. The cross-wave evidence confirms the
          typology replicates while documenting honestly that pandemic
          disruption rearranged individual cluster memberships, more sharply
          in Italy than in Sweden.
        </p>
      </article>
    </section>
  );
}
