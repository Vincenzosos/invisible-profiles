// External-validation explorer.
//
// Renders the cluster × held-out-variable matrix as a colour-coded
// heat map per country. Cell sign respects each variable's
// orientation (higher_better, lower_better, neutral); cell saturation
// scales with |effect| (relative magnitude vs national baseline).
// Hovering a cell surfaces the variable description plus exact values
// and delta.
//
// Data layer is in lib/external-validation.ts — same source of truth
// as the cohort outcome forecast card in CohortDashboard.

import { useMemo, useState } from 'react';
import {
  buildValidationMatrix,
  type ClusterValidationCell,
  type ExternalVariable,
} from '../lib/external-validation';
import type { Country } from '../lib/profiler';
import type { View } from '../types';

type Props = {
  onNavigate?: (v: View) => void;
};

export default function ExternalValidation({ onNavigate }: Props) {
  const [country, setCountry] = useState<Country>('italy');
  const matrix = useMemo(() => buildValidationMatrix(country), [country]);

  // Index cells by (cluster, varKey) for O(1) grid lookup.
  const cellLookup = useMemo(() => {
    const m = new Map<string, ClusterValidationCell>();
    for (const c of matrix.cells) m.set(`${c.cluster}::${c.varKey}`, c);
    return m;
  }, [matrix.cells]);

  return (
    <section className="space-y-12">
      <header className="space-y-6 max-w-4xl">
        <p className="eyebrow">External validation</p>
        <h1 className="display-1 text-slate-900">
          Does the segmentation predict variables it was never trained on?
        </h1>
        <p className="text-lg text-zinc-700 leading-relaxed max-w-3xl">
          Variables that were{' '}
          <span className="font-medium text-slate-900">not</span> used as
          clustering inputs. These act as external validators: if the
          segmentation captures meaningful structure, it should predict
          behaviour and outcomes that were held out from the clustering
          pipeline.
        </p>
      </header>

      <div className="flex flex-wrap items-center gap-3">
        <p className="eyebrow mr-2">Country</p>
        <CountryToggle country={country} onChange={setCountry} />
      </div>

      <HeatMap matrix={matrix} cellLookup={cellLookup} />

      <p className="text-xs text-zinc-500 max-w-3xl leading-relaxed">
        Heat values are the cluster's mean (or rate) on each held-out
        variable. Δ is the difference from the country aggregate. Effect
        magnitude is mapped onto colour saturation; the sign of the
        colour respects each variable's directional orientation
        (e.g. forgone-care-for-cost is lower-is-better, so a cluster
        below the national rate renders blue, above renders rose).
      </p>

      {onNavigate && (
        <button
          type="button"
          onClick={() => onNavigate('profiler')}
          className="block w-full text-left rounded-2xl border border-blue-200 bg-blue-50 hover:bg-blue-100 hover:border-blue-400 transition-colors p-8 group"
        >
          <p className="eyebrow text-blue-700">Continue · Try the model</p>
          <p className="display-2 text-slate-900 mt-3">
            See the validators applied to a real cohort.
          </p>
          <p className="mt-3 text-base text-zinc-700 leading-relaxed max-w-3xl">
            Upload a customer file. The dashboard projects this cohort's
            expected rate on each held-out variable from its cluster mix.
          </p>
          <p className="mt-6 text-sm font-medium text-blue-700 group-hover:translate-x-1 transition-transform inline-flex items-center gap-2">
            Try the model →
          </p>
        </button>
      )}
    </section>
  );
}

function CountryToggle({
  country,
  onChange,
}: {
  country: Country;
  onChange: (c: Country) => void;
}) {
  const options: { id: Country; label: string }[] = [
    { id: 'italy', label: 'Italy' },
    { id: 'sweden', label: 'Sweden' },
  ];
  return (
    <div className="inline-flex rounded-full border border-zinc-300 p-1 bg-white">
      {options.map((o) => {
        const isActive = country === o.id;
        return (
          <button
            key={o.id}
            type="button"
            onClick={() => onChange(o.id)}
            className={[
              'rounded-full px-4 py-1.5 text-sm transition-colors',
              isActive
                ? 'bg-slate-900 text-white'
                : 'text-zinc-700 hover:text-slate-900',
            ].join(' ')}
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}

// ---- Heat map ---------------------------------------------------------------

const COLOUR = {
  // Blue (above national, good given orientation) and rose (below national,
  // bad). Same palette as the rest of the app.
  positive: { r: 29, g: 78, b: 216 },   // blue-700
  negative: { r: 190, g: 18, b: 60 },   // rose-700
} as const;

function HeatMap({
  matrix,
  cellLookup,
}: {
  matrix: ReturnType<typeof buildValidationMatrix>;
  cellLookup: Map<string, ClusterValidationCell>;
}) {
  const { clusters, variables } = matrix;
  return (
    <div className="rounded-2xl bg-white border border-zinc-200 p-4 sm:p-6 overflow-x-auto">
      <table className="w-full text-sm border-separate border-spacing-0">
        <thead>
          <tr>
            <th className="text-left align-bottom p-2 text-xs text-zinc-500 font-normal w-44 min-w-[10rem]">
              Cluster ↓ &nbsp; / &nbsp; Variable →
            </th>
            {variables.map((v) => (
              <th
                key={v.key}
                scope="col"
                className="text-left align-bottom p-2 text-xs text-slate-900 font-medium min-w-[7.5rem]"
              >
                <span className="block leading-tight">{v.label}</span>
                <span className="block text-[10px] text-zinc-500 mt-0.5 font-normal">
                  {orientationLabel(v.orientation)}
                </span>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {clusters.map((cluster) => (
            <tr key={cluster}>
              <th
                scope="row"
                className="text-left p-2 text-sm font-medium text-slate-900 align-middle"
              >
                {cluster}
              </th>
              {variables.map((v) => {
                const cell = cellLookup.get(`${cluster}::${v.key}`);
                return (
                  <td key={v.key} className="p-1 align-middle">
                    <HeatCell cell={cell} variable={v} />
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function HeatCell({
  cell,
  variable,
}: {
  cell: ClusterValidationCell | undefined;
  variable: ExternalVariable;
}) {
  if (!cell) {
    return (
      <div className="rounded-lg bg-zinc-50 border border-zinc-200 px-2.5 py-2 text-center text-xs text-zinc-400">
        —
      </div>
    );
  }
  const isPositive = orientedSign(cell.delta, variable.orientation) >= 0;
  const magnitude = Math.min(1, Math.abs(cell.effect));
  // Alpha scales with magnitude but caps low to keep text readable.
  const alpha = 0.08 + magnitude * 0.5;
  const colour =
    variable.orientation === 'neutral'
      ? 'rgba(100, 116, 139, ' + alpha.toFixed(3) + ')'
      : isPositive
      ? `rgba(${COLOUR.positive.r}, ${COLOUR.positive.g}, ${COLOUR.positive.b}, ${alpha.toFixed(3)})`
      : `rgba(${COLOUR.negative.r}, ${COLOUR.negative.g}, ${COLOUR.negative.b}, ${alpha.toFixed(3)})`;
  const title = buildTooltip(cell, variable);
  return (
    <div
      title={title}
      className="rounded-lg border border-zinc-200 px-2.5 py-2 text-center cursor-default"
      style={{ backgroundColor: colour }}
    >
      <div className="text-sm font-semibold tabular-nums text-slate-900">
        {formatValue(cell.value, variable.unit)}
      </div>
      <div className="text-[10px] tabular-nums text-zinc-600 mt-0.5">
        {formatDelta(cell.delta, variable.unit)}
      </div>
    </div>
  );
}

function orientedSign(
  delta: number,
  orientation: ExternalVariable['orientation'],
): number {
  if (orientation === 'lower_better') return -delta;
  return delta;
}

function orientationLabel(o: ExternalVariable['orientation']): string {
  if (o === 'higher_better') return 'higher = better';
  if (o === 'lower_better') return 'lower = better';
  return 'directional read N/A';
}

function formatValue(v: number, unit: ExternalVariable['unit']): string {
  if (unit === 'pct') return `${(v * 100).toFixed(0)}%`;
  if (unit === 'count') return v.toFixed(1);
  return v.toFixed(1);
}

function formatDelta(d: number, unit: ExternalVariable['unit']): string {
  const sign = d >= 0 ? '+' : '−';
  const abs = Math.abs(d);
  if (unit === 'pct') return `${sign}${(abs * 100).toFixed(0)}pp`;
  return `${sign}${abs.toFixed(1)}`;
}

function buildTooltip(
  cell: ClusterValidationCell,
  variable: ExternalVariable,
): string {
  const parts = [
    `${variable.label}`,
    variable.description,
    `Cluster: ${formatValue(cell.value, variable.unit)}`,
    `National: ${formatValue(cell.national, variable.unit)}`,
    `Δ: ${formatDelta(cell.delta, variable.unit)}`,
  ];
  if (variable.hint) parts.push(variable.hint);
  return parts.join('\n');
}
