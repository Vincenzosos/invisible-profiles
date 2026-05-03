// mailto: helper. Per RFC 6068 the body and subject should be percent-encoded
// with %20 for spaces (not '+', which is form-urlencoded — some mail clients
// render '+' literally inside a body), so we use encodeURIComponent rather
// than URLSearchParams.

const CONTACT_EMAIL = 'vincenzopiosilvestri.vs@gmail.com';

export function buildMailto(opts?: { subject?: string; body?: string }): string {
  const subject = encodeURIComponent(
    opts?.subject ?? 'Invisible Profiles - inquiry',
  );
  const body = encodeURIComponent(opts?.body ?? 'Hi Vincenzo,\n\n');
  return `mailto:${CONTACT_EMAIL}?subject=${subject}&body=${body}`;
}
