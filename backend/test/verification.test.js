import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { once } from 'node:events';
import { createVerificationService } from '../src/services/verification.service.js';
import { createVerificationMailer } from '../src/services/verification-mailer.js';
import { createResetMailer } from '../src/services/reset-mailer.js';
import { createApp } from '../src/app.js';
import { readAuthConfig } from '../src/config/env.js';
import jwt from 'jsonwebtoken';

function fixture() {
  let time = new Date('2026-10-28T10:00:00Z');
  const user = { id: randomUUID(), name: 'Member', email: 'member@example.test', authVersion: 0, passwordHash: 'present', emailVerifiedAt: null, verificationAttempts: 0 };
  const codes = [];
  const config = readAuthConfig({ JWT_SECRET: randomBytes(48).toString('hex') });
  const repository = {
    async findById(id) { return id === user.id ? user : null; },
    async issueVerification(id, hash, now, expires) {
      if (user.emailVerifiedAt || (user.verificationSentAt && now - user.verificationSentAt < 60000)) return { count: 0 };
      Object.assign(user, { verificationHash: hash, verificationSentAt: now, verificationExpiresAt: expires, verificationAttempts: 0 });
      return { count: 1 };
    },
    async consumeVerification(id, hash, now) {
      if (user.emailVerifiedAt || !user.verificationExpiresAt || now >= user.verificationExpiresAt || user.verificationAttempts >= 5) return { count: 0 };
      if (hash !== user.verificationHash) { user.verificationAttempts++; return { count: 0 }; }
      Object.assign(user, { emailVerifiedAt: now, verificationHash: null, verificationExpiresAt: null });
      return { count: 1 };
    },
  };
  const options = { config: () => config, now: () => time, mailer: { configured: true, async send(_email, code) { codes.push(code); } } };
  return { user, codes, repository, options, config, service: createVerificationService(repository, options), advance(ms) { time = new Date(time.getTime() + ms); } };
}
test('Verification hashes codes, expires them, limits resends, and supports confirmation without changing credentials', async () => {
  const f = fixture();
  await f.service.send(f.user);
  assert.equal(f.codes.length, 1); assert.ok(/^\d{6}$/.test(f.codes[0]));
  assert.ok(f.user.verificationHash.length === 64 && f.user.verificationHash !== f.codes[0]);
  await assert.rejects(f.service.send(f.user), { status: 429 });
  f.advance(15 * 60000);
  await assert.rejects(f.service.verify(f.user, { code: f.codes[0] }), { status: 400 });
  await f.service.send(f.user);
  const result = await f.service.verify(f.user, { code: f.codes[1] });
  assert.equal(result.emailVerified, true); assert.equal(f.user.verificationHash, null);
  assert.equal(f.user.authVersion, 0); assert.equal(f.user.passwordHash, 'present');
  // Already verified is an idempotent success, not another code consumption.
  await f.service.verify(f.user, { code: f.codes[1] });
  await f.service.send(f.user); assert.equal(f.codes.length, 2);
});
test('Five wrong attempts lock a code; a fresh request invalidates the previous code', async () => {
  const f = fixture(); await f.service.send(f.user);
  const wrong = f.codes[0] === '000000' ? '000001' : '000000';
  for (let i = 0; i < 5; i++) await assert.rejects(f.service.verify(f.user, { code: wrong }), { status: 400 });
  await assert.rejects(f.service.verify(f.user, { code: f.codes[0] }), { status: 400 });
  assert.equal(f.user.verificationAttempts, 5);
  f.advance(60001); await f.service.send(f.user);
  assert.equal((await f.service.verify(f.user, { code: f.codes[1] })).emailVerified, true);
});
test('Missing/disabled email is explicit, even if credentials exist; failures never log tokens', async () => {
  let sends = 0;
  const mailer = createVerificationMailer({ RESEND_API_KEY: 'private-test-key', EMAIL_FROM: 'sender@example.test' }, async () => { sends++; });
  assert.equal(mailer.configured, false);
  await assert.rejects(mailer.send('member@example.test', '000000'));
  assert.equal(sends, 0);
  assert.equal(createResetMailer({ RESEND_API_KEY: 'private-test-key', RESET_EMAIL_FROM: 'sender@example.test' }).configured, false);
  const f = fixture(); f.options.mailer.configured = false;
  await assert.rejects(createVerificationService(f.repository, f.options).send(f.user), { code: 'EMAIL_UNAVAILABLE' });
  f.options.mailer.configured = true; f.options.mailer.send = async () => { throw new Error('secret provider body'); };
  await assert.rejects(createVerificationService(f.repository, f.options).send(f.user), { code: 'EMAIL_DELIVERY_FAILED' });
});
test('Verification HTTP endpoints require a session and never return a code/digest', async (t) => {
  const f = fixture();
  const server = createApp({ authRepository: f.repository, authConfig: () => f.config, verificationOptions: f.options }).listen(0, '127.0.0.1');
  await once(server, 'listening'); t.after(() => new Promise((resolve) => server.close(resolve)));
  const token = jwt.sign({ ver: 0 }, f.config.secret, { subject: f.user.id, issuer: f.config.issuer, audience: f.config.audience, expiresIn: 600 });
  const request = (path, body, authenticated = true) => fetch(`http://127.0.0.1:${server.address().port}/api/auth/${path}`, {
    method: 'POST', headers: { 'content-type': 'application/json', ...(authenticated ? { authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(body),
  });
  assert.equal((await request('send-verification', {}, false)).status, 401);
  const response = await request('send-verification', {}); assert.equal(response.status, 200);
  assert.deepEqual(Object.keys((await response.json()).data), ['message']);
  const verified = await request('verify-email', { code: f.codes[0] }); assert.equal(verified.status, 200);
  assert.equal((await verified.json()).data.user.emailVerified, true);
});
