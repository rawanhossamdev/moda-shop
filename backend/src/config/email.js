// Pure validation: never sends mail or prints private values.
export function mailbox(value) {
  if (typeof value !== 'string' || value.length > 254 || /[\s<>\r\n]/.test(value)) return null;
  return value.split('@')[0].length <= 64 && /^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$/.test(value) ? value.toLowerCase() : null;
}
export function readEmailConfig(source = process.env) {
  const mode = source.EMAIL_MODE ?? 'development';
  const from = (source.EMAIL_FROM ?? '').trim();
  const match = /^(?:[^<>\r\n]+\s<([^<>]+)>|([^<>\s]+))$/.exec(from);
  const sender = match ? mailbox(match[1] ?? match[2]) : null;
  const testRecipient = mailbox((source.EMAIL_TEST_RECIPIENT ?? '').trim());
  const key = source.RESEND_API_KEY;
  let reason = null;
  if (source.EMAIL_DELIVERY_ENABLED !== 'true') reason = 'DELIVERY_DISABLED';
  else if (typeof key !== 'string' || !key.trim() || /\s/.test(key)) reason = 'API_KEY_MISSING_OR_INVALID';
  else if (!['development', 'production'].includes(mode)) reason = 'INVALID_EMAIL_MODE';
  else if (!sender || /[\x00-\x1f\x7f]/.test(from)) reason = 'SENDER_MISSING_OR_INVALID';
  else if (source.NODE_ENV === 'production' && mode !== 'production') reason = 'PRODUCTION_MODE_REQUIRED';
  else {
    const domain = sender.split('@')[1];
    const testDomain = domain === 'resend.dev' || domain.endsWith('.resend.dev');
    if (testDomain && (mode !== 'development' || sender !== 'onboarding@resend.dev')) reason = 'TEST_SENDER_NOT_ALLOWED';
    else if (!testDomain && source.EMAIL_DOMAIN_VERIFIED !== 'true') reason = 'CUSTOM_DOMAIN_CONFIRMATION_REQUIRED';
    else if (mode === 'development' && !testRecipient) reason = 'AUTHORIZED_TEST_RECIPIENT_REQUIRED';
  }
  return { enabled: reason === null, reason, mode, from, testRecipient, apiKey: key };
}
