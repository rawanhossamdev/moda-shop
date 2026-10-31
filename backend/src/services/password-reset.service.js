import { createHash, randomBytes } from 'node:crypto';
import bcrypt from 'bcrypt';
import { AuthError, screenNewPassword } from './auth.service.js';
import { passwordProblem } from './password-policy.js';
import { createResetMailer } from './reset-mailer.js';
import { accountEmail } from './account-validation.js';

const digest = (token) => createHash('sha256').update(token).digest('hex');
export const recoveryMessage = 'If an account exists, we will attempt to send a reset code. Check your inbox and spam folder. If it does not arrive, try again later.';

export function createPasswordResetService(repository, {
  mailer = createResetMailer(), now = () => new Date(),
  screenPassword = screenNewPassword,
  reportFailure = () => console.error('Password recovery delivery failed. Check email configuration and service availability.'),
} = {}) {
  const pending = new Set();
  const recipients = new Map();
  return {
    request(body) {
      const email = body?.email;
      if (!accountEmail(email)) {
        throw new AuthError(400, 'VALIDATION_ERROR', 'Enter a valid email address.');
      }
      if (!mailer.configured) throw new AuthError(503, 'RECOVERY_UNAVAILABLE', 'Password recovery email is not configured yet. Please contact MODA support.');
      const address = accountEmail(email);
      // Deployment restriction is checked identically for existing/unknown
      // accounts, before lookup or code rotation. Never redirect customer mail
      // to the developer's inbox.
      try { mailer.assertRecipient?.(address); }
      catch { throw new AuthError(403, 'EMAIL_RECIPIENT_RESTRICTED', 'Development email is restricted to the configured Resend account test recipient.'); }
      const key = digest(address);
      const time = now().getTime();
      for (const [id, until] of recipients) if (until <= time) recipients.delete(id);
      // Return the same response for absent, throttled and existing accounts.
      if (recipients.has(key)) return recoveryMessage;
      if (pending.size >= 20 || recipients.size >= 10000) throw new AuthError(503, 'RECOVERY_BUSY', 'Password recovery is busy. Please try again shortly.');
      recipients.set(key, time + 60 * 1000);
      // Account lookup and delivery happen after responding; provider timing
      // cannot disclose account existence. Bounded, best-effort in-process work.
      const job = new Promise((resolve) => setImmediate(resolve)).then(async () => {
        const user = await repository.findByEmail(address);
        if (!user) return;
        const token = randomBytes(32).toString('base64url');
        await repository.setReset(user.id, digest(token), new Date(now().getTime() + 15 * 60 * 1000));
        await mailer.send(address, token);
      }).catch(() => reportFailure()).finally(() => pending.delete(job));
      pending.add(job);
      return recoveryMessage;
    },
    async reset(body) {
      if (typeof body?.token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(body.token)) {
        throw new AuthError(400, 'INVALID_RESET', 'This reset code is invalid or expired. Request a new code.');
      }
      const problem = passwordProblem(body.password);
      if (problem) throw new AuthError(400, 'PASSWORD_POLICY', problem);
      if (body.confirmPassword !== body.password) throw new AuthError(400, 'VALIDATION_ERROR', 'Passwords do not match.');
      await screenPassword(body.password);
      const passwordHash = await bcrypt.hash(body.password, 12);
      const result = await repository.consumeReset(digest(body.token), passwordHash, now());
      if (result.count !== 1) throw new AuthError(400, 'INVALID_RESET', 'This reset code is invalid or expired. Request a new code.');
      // No automatic login. All old JWTs were revoked by the atomic update.
    },
    async drain() { await Promise.all([...pending]); },
  };
}
