import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { randomBytes, randomUUID } from 'node:crypto';
import { readEmailConfig } from '../src/config/email.js';
import { createEmailService } from '../src/services/email.service.js';
import { createVerificationMailer } from '../src/services/verification-mailer.js';
import { createResetMailer } from '../src/services/reset-mailer.js';
import { verificationEmail, passwordResetEmail } from '../src/emails/templates.js';
import { createVerificationService } from '../src/services/verification.service.js';
import { createPasswordResetService, recoveryMessage } from '../src/services/password-reset.service.js';
import { readAuthConfig } from '../src/config/env.js';
import { createApp } from '../src/app.js';

// All codes, recipients, keys and provider responses here are synthetic. No
// test calls a real provider, database, or local .env-dependent mail transport.
const source = { NODE_ENV: 'test', EMAIL_DELIVERY_ENABLED: 'true', EMAIL_MODE: 'development',
  EMAIL_FROM: 'MODA Shop <onboarding@resend.dev>', EMAIL_TEST_RECIPIENT: 'owner@example.test', RESEND_API_KEY: 're_fixture_only' };
const resetCode = 'a'.repeat(43);
function mockResend() {
  const payloads = [];
  return { payloads, client: { emails: { async send(payload) { payloads.push(payload); return { data: { id: 'fixture-message-id' } }; } } } };
}

test('Email configuration fails closed for missing values, header injection and invalid production/test senders', () => {
  assert.equal(readEmailConfig(source).enabled, true);
  for (const patch of [
    { EMAIL_DELIVERY_ENABLED: 'false' }, { RESEND_API_KEY: '' }, { EMAIL_FROM: '' }, { EMAIL_TEST_RECIPIENT: '' },
    { EMAIL_MODE: 'unknown' }, { EMAIL_FROM: 'MODA\r\nBcc: customer@example.test <onboarding@resend.dev>' },
    { EMAIL_FROM: 'MODA <another@resend.dev>' }, { EMAIL_MODE: 'production' },
    { NODE_ENV: 'production' }, { EMAIL_FROM: 'MODA <help@unverified.example>' },
  ]) assert.equal(readEmailConfig({ ...source, ...patch }).enabled, false);
  assert.equal(readEmailConfig({ ...source, EMAIL_FROM: 'MODA <help@verified.example>', EMAIL_DOMAIN_VERIFIED: 'true', EMAIL_MODE: 'production' }).enabled, true);
});

test('Development sending accepts only the exact authorized account address and never redirects mail', async () => {
  const mock = mockResend(); const service = createEmailService({ source, client: mock.client });
  await assert.rejects(service.sendVerification('customer@example.test', '123456'), { code: 'EMAIL_RECIPIENT_RESTRICTED' });
  await assert.rejects(service.sendPasswordReset('owner+alias@example.test', resetCode), { code: 'EMAIL_RECIPIENT_RESTRICTED' });
  assert.equal(mock.payloads.length, 0);
  assert.deepEqual(await service.sendVerification(' OWNER@EXAMPLE.TEST ', '123456'), { accepted: true });
  assert.deepEqual(mock.payloads[0].to, ['owner@example.test']);
  assert.equal(mock.payloads[0].from, source.EMAIL_FROM);
  assert.equal(mock.payloads[0].bcc, undefined); assert.equal(mock.payloads[0].cc, undefined);
});

test('Verification and recovery share EMAIL_FROM and branded HTML/plain-text delivery', async () => {
  const mock = mockResend();
  const verify = createVerificationMailer(source, undefined, mock.client);
  const reset = createResetMailer(source, undefined, mock.client);
  await verify.send('owner@example.test', '123456');
  await reset.send('owner@example.test', resetCode);
  assert.equal(mock.payloads.length, 2);
  for (const payload of mock.payloads) {
    assert.equal(payload.from, source.EMAIL_FROM);
    for (const color of ['#FAF7F2', '#F2ECE3', '#252320', '#A58A57']) assert.ok(payload.html.includes(color));
    assert.ok(payload.html.includes('role="presentation"') && payload.html.includes('lang="en"'));
    assert.ok(payload.html.includes('viewport') && payload.text.includes('15 minutes'));
    assert.ok(!JSON.stringify(payload).includes(source.RESEND_API_KEY));
  }
  assert.ok(mock.payloads[0].html.includes('123456'));
  assert.ok(mock.payloads[1].text.includes(resetCode));
  assert.ok(mock.payloads[1].html.includes('word-break:break-all'));
  assert.throws(() => verificationEmail('<script>'));
  assert.throws(() => passwordResetEmail('<script>'));
});

test('Provider acceptance requires a message ID; SDK errors, thrown errors, malformed data and timeouts are sanitized', async () => {
  for (const result of [{ error: { message: 'private provider details' } }, {}, { data: {} }, { data: { id: '' } }]) {
    const service = createEmailService({ source, client: { emails: { async send() { return result; } } } });
    await assert.rejects(service.sendVerification('owner@example.test', '123456'), (error) =>
      error.code === 'EMAIL_DELIVERY_FAILED' && !String(error).includes('private') && error.cause === undefined);
  }
  const throws = createEmailService({ source, client: { emails: { async send() { throw new Error('private key and code'); } } } });
  await assert.rejects(throws.sendVerification('owner@example.test', '123456'), { message: 'The email provider did not confirm acceptance.' });
  const timeout = createEmailService({ source, timeoutMs: 5, client: { emails: { send() { return new Promise(() => {}); } } } });
  await assert.rejects(timeout.sendVerification('owner@example.test', '123456'), { code: 'EMAIL_DELIVERY_FAILED' });
});

test('HTTP Resend adapter uses HTTPS, backend auth and timeout, validates acceptance and discards provider errors', async () => {
  let calls = 0;
  const service = createEmailService({ source, send: async (url, options) => {
    calls++; assert.equal(url, 'https://api.resend.com/emails');
    assert.ok(options.headers.authorization === `Bearer ${source.RESEND_API_KEY}`);
    assert.ok(options.signal instanceof AbortSignal);
    assert.ok(!options.body.includes(source.RESEND_API_KEY));
    return { ok: true, json: async () => ({ id: 'fixture-message-id' }) };
  } });
  assert.deepEqual(await service.sendPasswordReset('owner@example.test', resetCode), { accepted: true });
  assert.equal(calls, 1);
  const rejected = createEmailService({ source, send: async () => ({ ok: false,
    json() { throw new Error('Provider error body must not be read.'); } }) });
  await assert.rejects(rejected.sendVerification('owner@example.test', '123456'), { code: 'EMAIL_DELIVERY_FAILED' });
  const malformed = createEmailService({ source, send: async () => ({ ok: true, json: async () => ({ message: 'not an acceptance' }) }) });
  await assert.rejects(malformed.sendVerification('owner@example.test', '123456'), { code: 'EMAIL_DELIVERY_FAILED' });
});

test('Recipient guards run before verification/reset code issuance or account lookup', async () => {
  const mock = mockResend(); let writes = 0; let lookups = 0;
  const repository = { async issueVerification() { writes++; }, async findByEmail() { lookups++; } };
  const verify = createVerificationService(repository, { mailer: createVerificationMailer(source, undefined, mock.client) });
  await assert.rejects(verify.send({ id: randomUUID(), email: 'customer@example.test' }), { code: 'EMAIL_RECIPIENT_RESTRICTED' });
  const recovery = createPasswordResetService(repository, { mailer: createResetMailer(source, undefined, mock.client) });
  assert.throws(() => recovery.request({ email: 'customer@example.test' }), { code: 'EMAIL_RECIPIENT_RESTRICTED' });
  assert.equal(writes, 0); assert.equal(lookups, 0); assert.equal(mock.payloads.length, 0);
});

test('Recovery generic response never claims a sent email; delivery failures are reported without details', async () => {
  let failures = 0;
  const user = { id: randomUUID(), email: 'owner@example.test' };
  const recovery = createPasswordResetService({ async findByEmail(email) { return email === user.email ? user : null; }, async setReset() {} }, {
    mailer: createResetMailer(source, undefined, { emails: { async send() { throw new Error('private response'); } } }),
    reportFailure: () => failures++,
  });
  assert.equal(recovery.request({ email: user.email }), recoveryMessage);
  assert.ok(!recoveryMessage.includes('was sent'));
  await recovery.drain(); assert.equal(failures, 1);
});

async function registrationServer(t, client) {
  const users = [];
  const authConfig = readAuthConfig({ JWT_SECRET: randomBytes(48).toString('hex') });
  const repository = {
    async findByEmail(email) { return users.find((user) => user.email === email); },
    async findById(id) { return users.find((user) => user.id === id); },
    async create(data) { const user = { ...data, id: randomUUID(), authVersion: 0 }; users.push(user); return user; },
    async issueVerification(id, hash, now, expires) {
      const user = users.find((u) => u.id === id);
      if (user.sentAt && now - user.sentAt < 60000) return { count: 0 };
      Object.assign(user, { verificationHash: hash, sentAt: now, expires }); return { count: 1 };
    },
  };
  const server = createApp({ authRepository: repository, authConfig: () => authConfig, screenPassword: async () => {},
    verificationOptions: { mailer: createVerificationMailer(source, undefined, client) } }).listen(0, '127.0.0.1');
  await once(server, 'listening'); t.after(() => new Promise((resolve) => server.close(resolve)));
  return { users, request(path, body, token) { return fetch(`http://127.0.0.1:${server.address().port}/api/auth/${path}`, {
    method: 'POST', headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(body),
  }); } };
}
const registration = { name: 'MODA Member', email: 'owner@example.test', password: 'a considered passphrase' };

test('Signup automatically sends a verification email through the shared service; resend uses the same policy', async (t) => {
  const mock = mockResend(); const api = await registrationServer(t, mock.client);
  const response = await api.request('register', registration); assert.equal(response.status, 201);
  const data = (await response.json()).data;
  assert.equal(data.verificationEmail.status, 'accepted'); assert.equal(data.user.emailVerified, false);
  assert.equal(mock.payloads.length, 1); assert.ok(mock.payloads[0].html.includes('MODA'));
  assert.ok(!JSON.stringify(data).includes(api.users[0].verificationHash));
  const cooldown = await api.request('send-verification', {}, data.token); assert.equal(cooldown.status, 429);
  api.users[0].sentAt = new Date(0); // Synthetic fixture only, never real accounts.
  const resend = await api.request('send-verification', {}, data.token); assert.equal(resend.status, 200);
  assert.equal(mock.payloads.length, 2);
});

test('Signup mail failure preserves the created account and reports failure separately, not a false delivery success', async (t) => {
  const api = await registrationServer(t, { emails: { async send() { return { error: { message: 'private provider body' } }; } } });
  const response = await api.request('register', registration); assert.equal(response.status, 201);
  const data = (await response.json()).data;
  assert.equal(data.verificationEmail.status, 'failed'); assert.equal(api.users.length, 1);
  assert.ok(!JSON.stringify(data).includes('private provider body'));
  assert.equal((await api.request('register', registration)).status, 409);
});

test('Test sender never sends signup verification to arbitrary customers', async (t) => {
  const mock = mockResend(); const api = await registrationServer(t, mock.client);
  const response = await api.request('register', { ...registration, email: 'customer@example.test' });
  const data = (await response.json()).data;
  assert.equal(response.status, 201); assert.equal(data.verificationEmail.status, 'restricted');
  assert.equal(mock.payloads.length, 0); assert.equal(api.users[0].verificationHash, undefined);
});
