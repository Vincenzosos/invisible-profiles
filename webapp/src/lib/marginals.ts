// Loader for the SHARE Wave 9 reference marginals consumed by the
// cohort-upload KS pre-flight (CsvUpload.tsx).
//
// Schema lives in src/data/share_marginals.json: 500 equally-spaced
// empirical quantiles per profiler variable per country. Ships with a
// uniform-distribution placeholder; v9/29_marginals_export.R overwrites
// with the empirical SHARE quantiles. The runtime guards on
// meta.placeholder so the pre-flight panel can downgrade itself when
// the empirical data isn't yet available.

import marginalsData from '../data/share_marginals.json';
import type { Country } from './profiler';

export type MarginalsModel = typeof marginalsData;

export function isPlaceholder(): boolean {
  return Boolean(marginalsData.meta.placeholder);
}

export function getQuantiles(country: Country, varName: string): number[] | null {
  const block = country === 'italy' ? marginalsData.italy : marginalsData.sweden;
  const entry = (block as Record<string, { quantiles: number[] } | undefined>)[varName];
  return entry?.quantiles ?? null;
}

export const N_QUANTILES = marginalsData.meta.n_quantiles ?? 500;
