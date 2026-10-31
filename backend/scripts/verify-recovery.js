// Uses one synthetic account inside a transaction that is ALWAYS rolled back.
// Never changes an existing account and never sends email or prints credentials.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import bcrypt from 'bcrypt';
import { getDatabase, disconnectDatabase } from '../src/config/database.js';
import { createAuthRepository } from '../src/repositories/auth.repository.js';
import { createPasswordResetService } from '../src/services/password-reset.service.js';

const rollback = new Error('Verification rollback');
const db = getDatabase();
try {
  const before = await Promise.all([db.user.count(), db.product.count(), db.order.count()]);
  try {
    await db.$transaction(async (tx) => {
      const email = `recovery-check-${randomUUID()}@example.test`;
      const user = await tx.user.create({ data: { email, name: 'Temporary verification', passwordHash: await bcrypt.hash('previous test password', 4) } });
      let token;
      let failures = 0;
      const repository = createAuthRepository(() => tx);
      const service = createPasswordResetService(repository, {
        screenPassword: async () => {}, // Deterministic: no external screening request.
        mailer: { configured: true, async send(_email, value) { token = value; } },
        reportFailure: () => failures++,
      });
      service.request({ email }); await service.drain();
      assert.ok(token && failures === 0, 'Recovery must prepare a code.');
      const input = { token, password: 'linen breeze in autumn', confirmPassword: 'linen breeze in autumn' };
      const results = await Promise.allSettled([service.reset(input), service.reset(input)]);
      assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
      const changed = await repository.findById(user.id);
      assert.equal(changed.authVersion, 1);
      assert.equal(changed.resetTokenHash, null);
      assert.equal(changed.resetExpiresAt, null);
      assert.ok(await bcrypt.compare(input.password, changed.passwordHash));
      throw rollback;
    }, { timeout: 20000 });
  } catch (error) {
    if (error !== rollback) throw error;
  }
  const after = await Promise.all([db.user.count(), db.product.count(), db.order.count()]);
  assert.deepEqual(after, before);
  console.log('PostgreSQL recovery verified: digest storage, single-use atomic reset, session version revocation, and rollback. Account/product/order counts unchanged.');
} catch (_) {
  console.error('Recovery database verification failed. Check migrations and PostgreSQL availability. No secrets are printed.');
  process.exitCode = 1;
} finally {
  await disconnectDatabase();
}
