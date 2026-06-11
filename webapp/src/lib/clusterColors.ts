// Cluster colours, sampled at the pixel from the thesis figures
// (Fig 4.1 Italy / Fig 5.1 Sweden). Keyed by the exact profile name used
// across the app so the on-screen palette stays sovrapponibile to the
// printed figures. Use clusterColor(name) everywhere a per-cluster colour
// is needed instead of hardcoding hex.

export const CLUSTER_COLORS: Record<string, string> = {
  // Italy — Fig 4.1
  'Fragile Resigned':   '#c8302a',
  'Fragile Depressed':  '#e27858',
  'Moderate Isolated':  '#888888',
  'Traditional Social': '#4a8fbe',
  'Connected Active':   '#143e72',

  // Sweden — Fig 5.1
  'Fragile':            '#a6190e',
  'Social Decline':     '#e07a5f',
  'Moderate':           '#8c8c8c',
  'Asset Rich':         '#9dbdd9',
  'Wealthy Digital':    '#4a82b5',
  'Connected Wealthy':  '#1b3f73',
};

export const CLUSTER_COLOR_FALLBACK = '#6b7280';

export function clusterColor(name: string): string {
  return CLUSTER_COLORS[name] ?? CLUSTER_COLOR_FALLBACK;
}
