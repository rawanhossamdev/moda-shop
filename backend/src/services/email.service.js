import { readEmailConfig, mailbox } from '../config/email.js';
import { verificationEmail, passwordResetEmail } from '../emails/templates.js';

export class EmailDeliveryError extends Error {
  constructor(code) {
    super(code === 'EMAIL_RECIPIENT_RESTRICTED'
      ? 'Development email is restricted to the configured Resend account test recipient.'
      : code === 'EMAIL_UNAVAILABLE' ? 'Email delivery is disabled or not configured.' : 'The email provider did not confirm acceptance.');
    this.code = code;
  }
}
// SDK-shaped seam for mock clients, using built-in fetch without an extra package.
export function createResendClient(apiKey, send = fetch) {
  return { emails: { async send(payload) {
    const response = await send('https://api.resend.com/emails', {
      method: 'POST', signal: AbortSignal.timeout(10000),
      headers: { authorization: `Bearer ${apiKey}`, 'content-type': 'application/json' }, body: JSON.stringify(payload),
    });
    if (!response.ok) return { error: { code: 'PROVIDER_REJECTED' } };
    const data = await response.json();
    return { data: { id: data?.id } };
  } } };
}
export function createEmailService({ source = process.env, client, send = fetch, timeoutMs = 10000 } = {}) {
  function recipient(email) {
    const config = readEmailConfig(source);
    if (!config.enabled) throw new EmailDeliveryError('EMAIL_UNAVAILABLE');
    const address = mailbox(typeof email === 'string' ? email.trim() : email);
    if (!address || (config.mode === 'development' && address !== config.testRecipient)) throw new EmailDeliveryError('EMAIL_RECIPIENT_RESTRICTED');
    return { config, address };
  }
  async function deliver(email, template) {
    const { config, address } = recipient(email);
    let timer;
    try {
      const resend = client ?? createResendClient(config.apiKey, send);
      const result = await Promise.race([
        resend.emails.send({ from: config.from, to: [address], ...template }),
        new Promise((_, reject) => { timer = setTimeout(() => reject(new EmailDeliveryError('EMAIL_DELIVERY_FAILED')), timeoutMs); }),
      ]);
      if (result?.error || typeof result?.data?.id !== 'string' || !result.data.id.trim()) throw new EmailDeliveryError('EMAIL_DELIVERY_FAILED');
      // Acceptance is not delivery. Never return/log provider IDs or bodies.
      return { accepted: true };
    } catch (_) { throw new EmailDeliveryError('EMAIL_DELIVERY_FAILED'); }
    finally { clearTimeout(timer); }
  }
  return {
    get configured() { return readEmailConfig(source).enabled; },
    assertRecipient(email) { recipient(email); },
    sendVerification(email, code) { return deliver(email, verificationEmail(code)); },
    sendPasswordReset(email, code) { return deliver(email, passwordResetEmail(code)); },
  };
}
