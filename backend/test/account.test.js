import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { randomBytes, randomUUID } from 'node:crypto';
import bcrypt from 'bcrypt';
import { createApp } from '../src/app.js';
import { readAuthConfig } from '../src/config/env.js';
import { createAuthService } from '../src/services/auth.service.js';
import { accountEmail, accountName } from '../src/services/account-validation.js';
import { authRateLimit } from '../src/middleware/auth-rate-limit.js';

const password = 'original considered passphrase';
function fixture() {
  const users = [];
  const copy = (user) => user ? structuredClone(user) : null;
  const repository = {
    async findByEmail(email) { return copy(users.find((user) => user.email === email)); },
    async findById(id) { return copy(users.find((user) => user.id === id)); },
    async create(data) { const user = { id: randomUUID(), ...data, authVersion: 0, emailVerifiedAt: null }; users.push(user); return copy(user); },
    async updateProfile(snapshot, data, changed) {
      const user = users.find((user) => user.id === snapshot.id && user.authVersion === snapshot.authVersion && user.passwordHash === snapshot.passwordHash);
      if (!user) return null;
      if (users.some((other) => other.id !== user.id && other.email === data.email)) throw Object.assign(new Error('duplicate'), { code: 'P2002' });
      Object.assign(user, data);
      if (changed) Object.assign(user, { emailVerifiedAt: null, verificationHash: null, verificationExpiresAt: null,
        verificationSentAt: null, verificationAttempts: 0, resetTokenHash: null, resetExpiresAt: null, authVersion: user.authVersion + 1 });
      return copy(user);
    },
    async changePassword(snapshot, passwordHash) {
      const user = users.find((user) => user.id === snapshot.id && user.authVersion === snapshot.authVersion && user.passwordHash === snapshot.passwordHash);
      if (!user) return { count: 0 };
      Object.assign(user, { passwordHash, authVersion: user.authVersion + 1, resetTokenHash: null, resetExpiresAt: null }); return { count: 1 };
    },
  };
  return { users, repository };
}
async function serve(t, options = {}) {
  const f = fixture(); const config = readAuthConfig({ JWT_SECRET: randomBytes(48).toString('base64url') });
  const server = createApp({ authRepository: f.repository, authConfig: () => config, screenPassword: async () => {},
    verificationOptions: { mailer: { configured: false } }, ...options }).listen(0, '127.0.0.1');
  await once(server, 'listening'); t.after(() => new Promise((resolve) => server.close(resolve)));
  const request = (path, body, token, method = path === 'me' ? 'GET' : path === 'profile' ? 'PATCH' : 'POST') => fetch(
    `http://127.0.0.1:${server.address().port}/api/auth/${path}`, { method,
      headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
  const result = await request('register', { name: 'MODA Member', email: 'owner@example.test', password });
  assert.equal(result.status, 201);
  return { ...f, config, request, session: (await result.json()).data };
}
test('Account validation accepts case/plus addressing without changing typed passwords and rejects malformed/control inputs', () => {
  assert.equal(accountEmail(' Owner+Tag@Example.Test '), 'owner+tag@example.test');
  for (const value of ['', null, 'owner@@example.test', 'owner..tag@example.test', '.owner@example.test',
    'owner@example..test', 'owner@-example.test', 'owner@example.test\r\nBcc:other@example.test']) assert.equal(accountEmail(value), null);
  assert.equal(accountName('  عضو MODA  '), 'عضو MODA');
  for (const value of ['', 'X', 'Member\nAdmin', 'a'.repeat(121)]) assert.equal(accountName(value), null);
});
test('Profile requires authentication and validates all fields without mass assignment', async (t) => {
  const api = await serve(t);
  assert.equal((await api.request('profile', {})).status, 401);
  for (const body of [{}, { name: 'X', email: 'owner@example.test' }, { name: 'Member', email: 'owner..name@example.test' }]) {
    assert.equal((await api.request('profile', body, api.session.token)).status, 400);
  }
  const response = await api.request('profile', { name: ' New Name ', email: ' OWNER@EXAMPLE.TEST ', emailVerifiedAt: 'forged', authVersion: 99, id: randomUUID() }, api.session.token);
  assert.equal(response.status, 200); const data = (await response.json()).data;
  assert.equal(data.user.name, 'New Name'); assert.equal(data.user.id, api.session.user.id);
  assert.equal(data.user.emailVerified, false); assert.equal(api.users[0].authVersion, 0);
  assert.equal(response.headers.get('cache-control'), 'no-store');
});
test('Email changes require current password, clear verification/reset codes and rotate the session', async (t) => {
  const api = await serve(t); const user = api.users[0];
  Object.assign(user, { emailVerifiedAt: new Date(), verificationHash: 'old-code', resetTokenHash: 'old-reset', resetExpiresAt: new Date() });
  const body = { name: 'MODA Member', email: 'new@example.test', currentPassword: 'wrong' };
  const rejected = await api.request('profile', body, api.session.token);
  assert.equal(rejected.status, 403); assert.equal((await rejected.json()).error.code, 'CURRENT_PASSWORD_INCORRECT');
  assert.equal((await api.request('me', undefined, api.session.token)).status, 200);
  const response = await api.request('profile', { ...body, currentPassword: password }, api.session.token);
  assert.equal(response.status, 200); const updated = (await response.json()).data;
  assert.equal(updated.user.email, 'new@example.test'); assert.equal(updated.user.emailVerified, false);
  assert.equal(updated.verificationEmail.status, 'unavailable');
  assert.equal(user.resetTokenHash, null); assert.equal(user.verificationHash, null); assert.equal(user.authVersion, 1);
  assert.equal((await api.request('me', undefined, api.session.token)).status, 401);
  assert.equal((await api.request('me', undefined, updated.token)).status, 200);
});
test('Duplicate profile emails return 409 without changing account identity or credentials', async (t) => {
  const api = await serve(t);
  api.users.push({ id: randomUUID(), email: 'other@example.test', name: 'Other member' });
  const response = await api.request('profile', { name: 'Member', email: 'OTHER@example.test', currentPassword: password }, api.session.token);
  assert.equal(response.status, 409); assert.equal(api.users[0].email, 'owner@example.test');
  assert.equal((await api.request('me', undefined, api.session.token)).status, 200);
});
test('Password changes enforce current password, policy, confirmation and a different password', async (t) => {
  const api = await serve(t);
  for (const [body, status] of [
    [{ currentPassword: 'wrong', password: 'another considered passphrase', confirmPassword: 'another considered passphrase' }, 403],
    [{ currentPassword: password, password: 'password', confirmPassword: 'password' }, 400],
    [{ currentPassword: password, password: 'another considered passphrase', confirmPassword: 'different' }, 400],
    [{ currentPassword: password, password, confirmPassword: password }, 400],
  ]) assert.equal((await api.request('change-password', body, api.session.token)).status, status);
  assert.equal(api.users[0].authVersion, 0);
  const next = 'another considered passphrase';
  api.users[0].resetTokenHash = 'outstanding-reset';
  assert.equal((await api.request('change-password', { currentPassword: password, password: next, confirmPassword: next }, api.session.token)).status, 204);
  assert.equal(api.users[0].authVersion, 1); assert.equal(api.users[0].resetTokenHash, null);
  assert.equal(bcrypt.getRounds(api.users[0].passwordHash), 12); assert.ok(await bcrypt.compare(next, api.users[0].passwordHash));
  assert.equal((await api.request('me', undefined, api.session.token)).status, 401);
  assert.equal((await api.request('login', { email: 'owner@example.test', password })).status, 401);
  assert.equal((await api.request('login', { email: 'owner@example.test', password: next })).status, 200);
});
test('Concurrent credential changes are rejected rather than restoring a stale credential snapshot', async () => {
  const f = fixture(); const config = readAuthConfig({ JWT_SECRET: randomBytes(48).toString('hex') });
  const service = createAuthService(f.repository, () => config, async () => {});
  const session = await service.register({ name: 'Member', email: 'owner@example.test', password });
  const stale = await service.authenticate(`Bearer ${session.token}`);
  f.users[0].authVersion++;
  await assert.rejects(service.updateProfile(stale, { name: 'Updated', email: stale.email }), { code: 'ACCOUNT_CHANGED' });
  await assert.rejects(service.changePassword(stale, { currentPassword: password, password: 'another considered passphrase', confirmPassword: 'another considered passphrase' }), { code: 'ACCOUNT_CHANGED' });
  assert.equal(f.users[0].name, 'Member'); assert.ok(await bcrypt.compare(password, f.users[0].passwordHash));
});
test('Authenticated account mutations reuse the credential endpoint rate limiter', async (t) => {
  const api = await serve(t, { authLimiter: authRateLimit({ limit: 2 }) });
  assert.equal((await api.request('profile', { name: 'Updated', email: 'owner@example.test' }, api.session.token)).status, 200);
  assert.equal((await api.request('change-password', {}, api.session.token)).status, 429);
});
