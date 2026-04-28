// Shared formatting helpers used across Atlas, Benchmark, and Opportunity
// Explorer screens.

export function formatEUR(value: number | null | undefined, opts?: {
  abbreviated?: boolean;
}): string {
  if (value === null || value === undefined || Number.isNaN(value)) return '—';
  const abbreviated = opts?.abbreviated ?? true;
  if (!abbreviated) {
    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'EUR',
      maximumFractionDigits: 0,
    }).format(value);
  }
  if (Math.abs(value) >= 1e12) return `€${(value / 1e12).toFixed(2)}T`;
  if (Math.abs(value) >= 1e9) return `€${(value / 1e9).toFixed(1)}B`;
  if (Math.abs(value) >= 1e6) return `€${(value / 1e6).toFixed(1)}M`;
  if (Math.abs(value) >= 1e3) return `€${(value / 1e3).toFixed(1)}K`;
  return `€${value.toFixed(0)}`;
}

export function formatPct(value: number | null | undefined, digits = 1): string {
  if (value === null || value === undefined || Number.isNaN(value)) return '—';
  return `${(value * 100).toFixed(digits)}%`;
}

export function formatPP(value: number | null | undefined, digits = 1): string {
  if (value === null || value === undefined || Number.isNaN(value)) return '—';
  const v = value * 100;
  const sign = v >= 0 ? '+' : '';
  return `${sign}${v.toFixed(digits)}pp`;
}

export function formatNum(value: number | null | undefined, digits = 2): string {
  if (value === null || value === undefined || Number.isNaN(value)) return '—';
  return value.toFixed(digits);
}

export function formatThousands(value: number | null | undefined): string {
  if (value === null || value === undefined || Number.isNaN(value)) return '—';
  return new Intl.NumberFormat('en-GB').format(Math.round(value));
}

export function formatIndividuals(value: number | null | undefined): string {
  if (value === null || value === undefined || Number.isNaN(value)) return '—';
  if (Math.abs(value) >= 1e6) return `${(value / 1e6).toFixed(2)}M`;
  if (Math.abs(value) >= 1e3) return `${(value / 1e3).toFixed(0)}K`;
  return `${Math.round(value)}`;
}
