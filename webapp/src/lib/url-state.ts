// Persist (section, profile) into the URL so deep links survive a tab copy
// or a browser refresh. Uses native History API + URLSearchParams — no
// router dependency. URLSearchParams encodes spaces as '+', which is the
// canonical x-www-form-urlencoded form, so a profile name like
// "Moderate Isolated" round-trips as ?profile=Moderate+Isolated.

import type { View } from '../types';

const VALID_VIEWS: readonly View[] = [
  'home',
  'atlas',
  'benchmark',
  'opportunity',
  'profiler',
  'robustness',
  'methods',
];

export type UrlState = {
  section: View;
  profile: string | null;
};

export function readUrlState(): UrlState {
  const params = new URLSearchParams(window.location.search);
  const sParam = params.get('section');
  const pParam = params.get('profile');
  const section: View =
    sParam && (VALID_VIEWS as readonly string[]).includes(sParam)
      ? (sParam as View)
      : 'home';
  return { section, profile: pParam || null };
}

export function writeUrlState(state: UrlState, replace = false): void {
  const params = new URLSearchParams();
  if (state.section !== 'home') params.set('section', state.section);
  if (state.profile) params.set('profile', state.profile);
  const qs = params.toString();
  const url = qs ? `${window.location.pathname}?${qs}` : window.location.pathname;
  if (replace) window.history.replaceState(null, '', url);
  else window.history.pushState(null, '', url);
}
