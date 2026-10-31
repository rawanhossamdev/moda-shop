import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import bcrypt from 'bcrypt';
import { createPasswordResetService, recoveryMessage } from '../src/services/password-reset.service.js';
import { createAuthService } from '../src/services/auth.service.js';
import { readAuthConfig } from '../src/config/env.js';
import { createResetMailer } from '../src/services/reset-mailer.js';
import { createApp } from '../src/app.js';
import { authRateLimit } from '../src/middleware/auth-rate-limit.js';

function fixture() {
  const user = { id: randomUUID(), email: 'member@example.test', name: 'Member', authVersion: 0 };
  const sent = [];
  let time = new Date('2026-10-28T12:00:00Z');
  let failures = 0;
  const repository = {
    async findByEmail(email) { return email === user.email ? user : null; },
    async findById(id) { return id === user.id ? user : null; },
    async setReset(id, resetTokenHash, resetExpiresAt) { Object.assign(user, { resetTokenHash, resetExpiresAt }); },
    async consumeReset(hash, passwordHash, now) {
      if (user.resetTokenHash !== hash || user.resetExpiresAt <= now) return { count: 0 };
      Object.assign(user, { passwordHash, resetTokenHash: null, resetExpiresAt: null, authVersion: user.authVersion + 1 });
      return { count: 1 };
    },
  };
  const options = {
    screenPassword: async () => {},
    mailer: { configured: true, async send(email, token) { sent.push({ email, token }); } },
    now: () => time, reportFailure: () => failures++,
  };
  return { user, repository, options, sent, get failures() { return failures; },
    advance(ms) { time = new Date(time.getTime() + ms); },
    service: createPasswordResetService(repository, options) };
}
const body = (token, password = 'linen breeze in autumn') => ({ token, password, confirmPassword: password });

test('Recovery responses do not reveal account existence; store only a digest and throttle resends', async () => {
  const f = fixture();
  assert.equal(f.service.request({ email: ' MEMBER@EXAMPLE.TEST ' }), recoveryMessage);
  assert.equal(f.service.request({ email: 'absent@example.test' }), recoveryMessage);
  assert.equal(f.sent.length, 0); // Lookup/delivery are deferred off the request path.
  await f.service.drain();
  assert.equal(f.sent.length, 1);
  assert.ok(/^[A-Za-z0-9_-]{43}$/.test(f.sent[0].token));
  assert.ok(f.user.resetTokenHash === createHash('sha256').update(f.sent[0].token).digest('hex'));
  assert.equal(f.user.resetExpiresAt.toISOString(), '2026-10-28T12:15:00.000Z');
  assert.equal(f.service.request({ email: f.user.email }), recoveryMessage);
  await f.service.drain();
  assert.equal(f.sent.length, 1);
});

test('Reset consumes the code once, hashes the new password and invalidates existing JWT sessions', async () => {
  const f = fixture();
  f.user.passwordHash = await bcrypt.hash('previous password', 4);
  const config = readAuthConfig({ JWT_SECRET: randomBytes(48).toString('base64url') });
  const auth = createAuthService(f.repository, () => config);
  const old = await auth.login({ email: f.user.email, password: 'previous password' });
  f.service.request({ email: f.user.email }); await f.service.drain();
  await f.service.reset(body(f.sent[0].token));
  assert.ok(await bcrypt.compare('linen breeze in autumn', f.user.passwordHash));
  assert.equal(bcrypt.getRounds(f.user.passwordHash), 12);
  assert.equal(f.user.resetTokenHash, null);
  assert.equal(f.user.resetExpiresAt, null);
  await assert.rejects(f.service.reset(body(f.sent[0].token)), { code: 'INVALID_RESET' });
  await assert.rejects(auth.authenticate(`Bearer ${old.token}`), { status: 401 });
  await assert.rejects(auth.login({ email: f.user.email, password: 'previous password' }), { status: 401 });
  assert.ok((await auth.login({ email: f.user.email, password: 'linen breeze in autumn' })).user.id === f.user.id);
});

test('Concurrent resets succeed once; expiry and newer requests invalidate old codes', async () => {
  const f = fixture();
  f.service.request({ email: f.user.email }); await f.service.drain();
  const old = f.sent[0].token;
  f.advance(61 * 1000);
  f.service.request({ email: f.user.email }); await f.service.drain();
  await assert.rejects(f.service.reset(body(old)), { code: 'INVALID_RESET' });
  const results = await Promise.allSettled([f.service.reset(body(f.sent[1].token)), f.service.reset(body(f.sent[1].token))]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert.equal(f.user.authVersion, 1);
  f.advance(61 * 1000);
  f.service.request({ email: f.user.email }); await f.service.drain();
  f.advance(15 * 60 * 1000);
  await assert.rejects(f.service.reset(body(f.sent[2].token)), { code: 'INVALID_RESET' });
});

test('Policy, confirmation and malformed reset inputs fail without consuming a valid code', async () => {
  const f = fixture();
  f.service.request({ email: f.user.email }); await f.service.drain();
  for (const value of [null, {}, body('wrong'), body(f.sent[0].token, 'password'),
    { ...body(f.sent[0].token), confirmPassword: 'different' }]) {
    await assert.rejects(f.service.reset(value), { status: 400 });
  }
  assert.equal(f.user.authVersion, 0);
  await f.service.reset(body(f.sent[0].token));
});

test('Missing email configuration is explicit; delivery failures never change the generic response', async () => {
  const f = fixture();
  const disabled = createPasswordResetService(f.repository, { mailer: { configured: false } });
  for (const email of [f.user.email, 'absent@example.test']) {
    assert.throws(() => disabled.request({ email }), { code: 'RECOVERY_UNAVAILABLE', status: 503 });
  }
  f.options.mailer.send = async () => { throw new Error('private provider payload'); };
  const failed = createPasswordResetService(f.repository, f.options);
  assert.equal(failed.request({ email: f.user.email }), recoveryMessage);
  await failed.drain();
  assert.equal(f.failures, 1);
});

test('Mailer uses HTTPS, a timeout and a plain-text code; provider errors are sanitized', async () => {
  let calls = 0;
  const mailer = createResetMailer({ EMAIL_DELIVERY_ENABLED: 'true', RESEND_API_KEY: 'test-private-key',
    EMAIL_FROM: 'MODA Shop <onboarding@resend.dev>', EMAIL_TEST_RECIPIENT: 'member@example.test' }, async (url, options) => {
    calls++;
    assert.equal(url, 'https://api.resend.com/emails');
    assert.ok(options.signal instanceof AbortSignal);
    const payload = JSON.parse(options.body);
    assert.ok(payload.text.includes('a'.repeat(43)));
    assert.ok(payload.html.includes('#FAF7F2'));
    assert.deepEqual(payload.to, ['member@example.test']);
    return { ok: false };
  });
  assert.equal(mailer.configured, true);
  await assert.rejects(mailer.send('member@example.test', 'a'.repeat(43)), { code: 'EMAIL_DELIVERY_FAILED' });
  assert.equal(calls, 1);
  assert.equal(createResetMailer({}).configured, false);
});

test('HTTP recovery validates requests, returns 202 without secrets, handles reset and rate limits', async (t) => {
  const f = fixture();
  const server = createApp({ authRepository: f.repository, recoveryOptions: f.options,
    authLimiter: authRateLimit({ limit: 6 }) }).listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const request = (path, body) => fetch(`http://127.0.0.1:${server.address().port}/api/auth/${path}`, {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body),
  });
  assert.equal((await request('forgot-password', { email: 'invalid' })).status, 400);
  const known = await request('forgot-password', { email: f.user.email });
  const unknown = await request('forgot-password', { email: 'absent@example.test' });
  assert.equal(known.status, 202); assert.equal(unknown.status, 202);
  assert.equal(known.headers.get('cache-control'), 'no-store');
  assert.deepEqual(await known.json(), await unknown.json());
  // Wait for the injected local delivery; no external email is sent in tests.
  for (let attempt = 0; f.sent.length === 0 && attempt < 20; attempt++) await new Promise(setImmediate);
  assert.equal(f.sent.length, 1);
  assert.equal((await request('reset-password', body(f.sent[0].token))).status, 204);
  assert.equal((await request('reset-password', body(f.sent[0].token))).status, 400);
  await request('forgot-password', { email: f.user.email });
  assert.equal((await request('forgot-password', { email: f.user.email })).status, 429);
});
