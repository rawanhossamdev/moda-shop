import { createHmac, randomInt } from 'node:crypto';
import { AuthError, publicUser } from './auth.service.js';
import { readAuthConfig } from '../config/env.js';
import { createVerificationMailer } from './verification-mailer.js';

export function createVerificationService(repository, {
  mailer = createVerificationMailer(), config = readAuthConfig, now = () => new Date(),
} = {}) {
  const hash = (user, code) => createHmac('sha256', config().secret).update(`verify:${user.id}:${user.email}:${code}`).digest('hex');
  return {
    async send(user) {
      if (user.emailVerifiedAt) return;
      if (!mailer.configured) throw new AuthError(503, 'EMAIL_UNAVAILABLE', 'Verification email is not enabled or configured. Please try again after MODA enables delivery.');
      try { mailer.assertRecipient?.(user.email); }
      catch { throw new AuthError(403, 'EMAIL_RECIPIENT_RESTRICTED', 'Development email is restricted to the configured Resend account test recipient.'); }
      const code = String(randomInt(0, 1000000)).padStart(6, '0');
      const time = now();
      const result = await repository.issueVerification(user.id, hash(user, code), time, new Date(time.getTime() + 15 * 60000));
      if (!result.count) throw new AuthError(429, 'VERIFY_COOLDOWN', 'Please wait one minute before requesting another code.');
      try { await mailer.send(user.email, code); }
      catch { throw new AuthError(503, 'EMAIL_DELIVERY_FAILED', 'The email provider did not confirm delivery. Please wait a minute and try again.'); }
    },
    async verify(user, body) {
      if (user.emailVerifiedAt) return publicUser(user);
      if (typeof body?.code !== 'string' || !/^\d{6}$/.test(body.code)) throw new AuthError(400, 'INVALID_VERIFICATION', 'Enter the six-digit code from your email.');
      const result = await repository.consumeVerification(user.id, hash(user, body.code), now());
      if (!result.count) throw new AuthError(400, 'INVALID_VERIFICATION', 'The code is incorrect, expired or used. After five attempts, request a new code.');
      return publicUser(await repository.findById(user.id));
    },
  };
}
