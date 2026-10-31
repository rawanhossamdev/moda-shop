import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { randomBytes, randomUUID } from 'node:crypto';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { createApp } from '../src/app.js';
import { readAuthConfig } from '../src/config/env.js';
import { authRateLimit } from '../src/middleware/auth-rate-limit.js';
import { passwordProblem } from '../src/services/password-policy.js';

const password = 'a-long-test-passphrase';
function fixture() {
  const users = [];
  return { users, repository: {
    async findByEmail(email) { return users.find((user) => user.email.toLowerCase() === email.toLowerCase()) ?? null; },
    async findById(id) { return users.find((user) => user.id === id) ?? null; },
    async create(data) {
      if (users.some((user) => user.email.toLowerCase() === data.email.toLowerCase())) throw Object.assign(new Error(), { code: 'P2002' });
      const user = { id: randomUUID(), authVersion: 0, ...data }; users.push(user); return user;
    },
    async revoke(id, version) {
      const user = users.find((user) => user.id === id && user.authVersion === version);
      if (user) user.authVersion++;
      return { count: user ? 1 : 0 };
    },
  } };
}
async function serve(t, options = {}) {
  const { repository, users } = fixture();
  const config = readAuthConfig({ JWT_SECRET: randomBytes(48).toString('base64url') });
  const server = createApp({ authRepository: repository, authConfig: () => config, screenPassword: async () => {},
    verificationOptions: { mailer: { configured: false } }, ...options }).listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return { users, config, async request(path, body, token) {
    return fetch(`http://127.0.0.1:${server.address().port}/api/auth/${path}`, {
      method: path === 'me' ? 'GET' : 'POST',
      headers: { 'content-type': 'application/json', ...(token ? { authorization: 'Bearer ' + token } : {}) },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
  } };
}
async function register(api, email = 'member@example.test') {
  const response = await api.request('register', { name: 'MODA Member', email, password });
  assert.equal(response.status, 201);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  return (await response.json()).data;
}
test('Registers with normalized email and bcrypt cost 12; response never exposes the hash', async (t) => {
  const api = await serve(t);
  const session = await register(api, ' Member@Example.Test ');
  assert.equal(session.user.email, 'member@example.test');
  assert.deepEqual(Object.keys(session.user).sort(), ['email', 'emailVerified', 'id', 'name']);
  assert.equal(session.user.emailVerified, false);
  assert.notEqual(api.users[0].passwordHash, password);
  assert.equal(bcrypt.getRounds(api.users[0].passwordHash), 12);
  assert.ok(await bcrypt.compare(password, api.users[0].passwordHash));
  const payload = jwt.verify(session.token, api.config.secret, { algorithms: ['HS256'], issuer: api.config.issuer, audience: api.config.audience });
  assert.equal(payload.sub, session.user.id);
  assert.equal(payload.exp - payload.iat, 604800);
  assert.equal(payload.ver, 0);
});
test('Login works case-insensitively and /me authenticates the JWT', async (t) => {
  const api = await serve(t);
  await register(api);
  const response = await api.request('login', { email: 'MEMBER@example.test', password });
  assert.equal(response.status, 200);
  const session = (await response.json()).data;
  const me = await api.request('me', undefined, session.token);
  assert.equal(me.status, 200);
  assert.deepEqual((await me.json()).data.user, session.user);
});
test('Duplicate and concurrent registration attempts return 409', async (t) => {
  const api = await serve(t);
  const results = await Promise.all([api.request('register', { name: 'First', email: 'race@example.test', password }),
    api.request('register', { name: 'Second', email: 'RACE@example.test', password })]);
  assert.deepEqual(results.map((result) => result.status).sort(), [201, 409]);
  assert.equal(api.users.length, 1);
});
test('Rejects malformed inputs and bcrypt-truncating passwords', async (t) => {
  const api = await serve(t);
  for (const body of [
    {}, null, { name: 'Member', email: 'invalid', password },
    { name: 'X', email: 'valid@example.test', password },
    { name: 'Member', email: 'valid@example.test', password: 'short' },
    { name: 'Member', email: 'valid@example.test', password: 'a'.repeat(73) },
    { name: 'Member', email: 'valid@example.test', password: '🔒'.repeat(19) },
  ]) {
    const response = await api.request('register', body);
    assert.equal(response.status, 400);
    assert.equal((await response.json()).error.code, body === null ? 'INVALID_REQUEST' :
      body.email === 'valid@example.test' && passwordProblem(body.password) ? 'PASSWORD_POLICY' : 'VALIDATION_ERROR');
  }
  assert.equal(api.users.length, 0);
});
test('Wrong credentials, unknown users and legacy passwordless users have the same error', async (t) => {
  const api = await serve(t);
  await register(api);
  api.users.push({ id: randomUUID(), email: 'legacy@example.test', name: 'Legacy', passwordHash: null, authVersion: 0 });
  for (const body of [
    { email: 'member@example.test', password: 'incorrect-password' },
    { email: 'unknown@example.test', password },
    { email: 'legacy@example.test', password },
  ]) {
    const response = await api.request('login', body);
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), { error: { code: 'INVALID_CREDENTIALS', message: 'Email or password is incorrect.' } });
  }
});
test('Missing, tampered, expired and wrong-audience tokens are rejected', async (t) => {
  const api = await serve(t);
  const session = await register(api);
  const sign = (options) => jwt.sign({ ver: 0 }, api.config.secret, { subject: session.user.id, issuer: api.config.issuer, audience: api.config.audience, ...options });
  for (const token of [undefined, 'broken', session.token.slice(0, -8) + 'tampered',
    sign({ expiresIn: -1 }), sign({ audience: 'other-app', expiresIn: 300 }), sign({ algorithm: 'HS384', expiresIn: 300 })]) {
    assert.equal((await api.request('me', undefined, token)).status, 401);
  }
});
test('Legacy tokens without session version return 401, not a server error', async (t) => {
  const api = await serve(t);
  const session = await register(api);
  const token = jwt.sign({}, api.config.secret, { subject: session.user.id, issuer: api.config.issuer, audience: api.config.audience, expiresIn: 300 });
  const response = await api.request('me', undefined, token);
  assert.equal(response.status, 401);
  assert.equal((await response.json()).error.code, 'UNAUTHENTICATED');
  assert.equal((await api.request('me', undefined, session.token)).status, 200);
});

test('Session verification configuration failure returns 503, not invalid credentials', async (t) => {
  const api = await serve(t, { authConfig: () => { throw new Error('Unavailable'); } });
  const response = await api.request('me', undefined, 'saved-token');
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, 'AUTH_UNAVAILABLE');
});

test('Logout revokes all previously issued tokens for the user', async (t) => {
  const api = await serve(t);
  const first = await register(api);
  const second = (await (await api.request('login', { email: first.user.email, password })).json()).data;
  assert.equal((await api.request('logout', undefined, first.token)).status, 204);
  assert.equal((await api.request('me', undefined, first.token)).status, 401);
  assert.equal((await api.request('me', undefined, second.token)).status, 401);
  const third = (await (await api.request('login', { email: first.user.email, password })).json()).data;
  assert.equal((await api.request('me', undefined, third.token)).status, 200);
});
test('Rate limits credential endpoints', async (t) => {
  const api = await serve(t, { authLimiter: authRateLimit({ limit: 2 }) });
  await api.request('login', {});
  await api.request('register', {});
  const response = await api.request('login', {});
  assert.equal(response.status, 429);
  assert.ok(response.headers.get('retry-after'));
});
test('Missing JWT configuration fails safely before creating a user', async (t) => {
  const api = await serve(t, { authConfig: () => { throw new Error('configuration unavailable'); } });
  const response = await api.request('register', { name: 'Member', email: 'new@example.test', password });
  assert.equal(response.status, 503);
  assert.equal(api.users.length, 0);
});
test('Rejects absent, weak and invalid JWT settings', () => {
  for (const JWT_SECRET of [undefined, 'short']) assert.throws(() => readAuthConfig({ JWT_SECRET }), /JWT_SECRET/);
  assert.throws(() => readAuthConfig({ JWT_SECRET: randomBytes(32).toString('hex'), JWT_TTL_SECONDS: '0' }), /JWT_TTL_SECONDS/);
});

test('Eight-character passwords are accepted without composition rules; common passwords are rejected', async (t) => {
  const api = await serve(t);
  for (const password of ['password', '12345678', 'aaaaaaaa', 'PASSWORD123!']) {
    const response = await api.request('register', { name: 'Member', email: 'policy@example.test', password });
    assert.equal(response.status, 400);
    assert.equal((await response.json()).error.code, 'PASSWORD_POLICY');
  }
  assert.equal((await api.request('register', { name: 'Member', email: 'policy@example.test', password: 'silkfern' })).status, 201);
  // Policy applies to new credentials, not existing accounts signing in.
  api.users[0].passwordHash = await bcrypt.hash('oldpass', 4);
  assert.equal((await api.request('login', { email: 'policy@example.test', password: 'oldpass' })).status, 200);
});
