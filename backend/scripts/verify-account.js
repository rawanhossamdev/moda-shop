// Tests only a synthetic user inside an ALWAYS-ROLLED-BACK transaction.
// No email, external password screening, Paymob or existing account changes.
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { getDatabase, disconnectDatabase } from '../src/config/database.js';
import { createAuthRepository } from '../src/repositories/auth.repository.js';
import { createAuthService } from '../src/services/auth.service.js';
import { readAuthConfig } from '../src/config/env.js';

const rollback = new Error('Intentional account verification rollback');
const db = getDatabase();
try {
  const before = await db.user.count();
  try {
    await db.$transaction(async (tx) => {
      const adapter = new Proxy(tx, { get(target, key) { return key === '$transaction' ? async (action) => {
        await target.$executeRawUnsafe('SAVEPOINT account_verify');
        try { const value = await action(target); await target.$executeRawUnsafe('RELEASE SAVEPOINT account_verify'); return value; }
        catch (error) { await target.$executeRawUnsafe('ROLLBACK TO SAVEPOINT account_verify'); await target.$executeRawUnsafe('RELEASE SAVEPOINT account_verify'); throw error; }
      } : Reflect.get(target, key); } });
      const repository = createAuthRepository(() => adapter);
      const config = readAuthConfig({ JWT_SECRET: randomBytes(48).toString('base64url') });
      const service = createAuthService(repository, () => config, async () => {});
      const email = `account-check-${randomUUID()}@example.test`;
      const nextEmail = `account-check-${randomUUID()}@example.test`;
      const password = randomBytes(24).toString('base64url');
      const nextPassword = randomBytes(24).toString('base64url');
      const session = await service.register({ name: 'Temporary member', email, password });
      await tx.user.update({ where: { id: session.user.id }, data: { emailVerifiedAt: new Date() } });
      let user = await service.authenticate(`Bearer ${session.token}`);
      const named = await service.updateProfile(user, { name: 'Updated temporary member', email });
      assert.equal(named.user.name, 'Updated temporary member'); assert.equal(named.user.emailVerified, true);
      user = await service.authenticate(`Bearer ${named.token}`);
      await repository.setReset(user.id, 'a'.repeat(64), new Date(Date.now() + 60000));
      const changed = await service.updateProfile(user, { name: named.user.name, email: nextEmail, currentPassword: password });
      assert.equal(changed.user.emailVerified, false);
      await assert.rejects(service.authenticate(`Bearer ${session.token}`), { status: 401 });
      user = await service.authenticate(`Bearer ${changed.token}`);
      assert.equal(user.resetTokenHash, null); assert.equal(user.verificationHash, null);
      await service.changePassword(user, { currentPassword: password, password: nextPassword, confirmPassword: nextPassword });
      await assert.rejects(service.authenticate(`Bearer ${changed.token}`), { status: 401 });
      await assert.rejects(service.login({ email: nextEmail, password }), { status: 401 });
      const loggedIn = await service.login({ email: nextEmail, password: nextPassword });
      assert.ok(loggedIn.user.id === session.user.id);
      throw rollback;
    }, { timeout: 30000 });
  } catch (error) { if (error !== rollback) throw error; }
  assert.equal(await db.user.count(), before);
  console.log('PostgreSQL account checks passed: profile persistence, email reverification, password replacement and session revocation. All synthetic writes rolled back; persisted user count unchanged.');
} catch (error) {
  console.error(`Account database verification failed (${error.code ?? error.name}). No private values printed.`);
  process.exitCode = 1;
} finally { await disconnectDatabase(); }
