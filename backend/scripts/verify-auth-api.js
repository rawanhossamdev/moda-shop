import { once } from 'node:events';
import { randomBytes, randomUUID } from 'node:crypto';
import assert from 'node:assert/strict';
import bcrypt from 'bcrypt';
import { createApp } from '../src/app.js';
import { createAuthRepository } from '../src/repositories/auth.repository.js';
import { getDatabase, disconnectDatabase } from '../src/config/database.js';

class RollBackTest extends Error {}
try {
  const db = getDatabase();
  const before = await db.user.count();
  try {
    await db.$transaction(async (tx) => {
      const server = createApp({ authRepository: createAuthRepository(() => tx),
        verificationOptions: { mailer: { configured: false } } }).listen(0, '127.0.0.1');
      await once(server, 'listening');
      try {
        const base = `http://127.0.0.1:${server.address().port}/api/auth`;
        const email = randomUUID() + '@moda-test.invalid';
        const password = randomBytes(24).toString('base64url');
        async function request(path, body, token) {
          return fetch(base + '/' + path, {
            method: path === 'me' ? 'GET' : 'POST', signal: AbortSignal.timeout(10000),
            headers: { 'content-type': 'application/json', ...(token ? { authorization: 'Bearer ' + token } : {}) },
            ...(body === undefined ? {} : { body: JSON.stringify(body) }),
          });
        }
        const registered = await request('register', { name: 'Transaction-only test', email, password });
        assert.equal(registered.status, 201);
        const session = (await registered.json()).data;
        const stored = await tx.user.findUnique({ where: { id: session.user.id } });
        assert.ok(await bcrypt.compare(password, stored.passwordHash));
        assert.equal(bcrypt.getRounds(stored.passwordHash), 12);
        assert.equal((await request('register', { name: 'Duplicate', email: email.toUpperCase(), password })).status, 409);
        const loggedIn = await request('login', { email, password });
        assert.equal(loggedIn.status, 200);
        const second = (await loggedIn.json()).data;
        assert.equal((await request('me', undefined, session.token)).status, 200);
        assert.equal((await request('logout', undefined, session.token)).status, 204);
        assert.equal((await request('me', undefined, session.token)).status, 401);
        assert.equal((await request('me', undefined, second.token)).status, 401);
        console.log('Real PostgreSQL auth endpoints passed: registration, bcrypt verification, duplicate prevention, login, /me, and token revocation.');
      } finally { await new Promise((resolve) => server.close(resolve)); }
      // Only test writes are rolled back. No existing data is deleted or reset.
      throw new RollBackTest();
    }, { timeout: 60000 });
  } catch (error) { if (!(error instanceof RollBackTest)) throw error; }
  assert.equal(await db.user.count(), before);
  console.log('Transaction rolled back; no test user or test session data was retained.');
} catch (error) {
  console.error('Live authentication verification failed (' + (error.code ?? error.name) + '). No credentials displayed.');
  process.exitCode = 1;
} finally { await disconnectDatabase(); }
