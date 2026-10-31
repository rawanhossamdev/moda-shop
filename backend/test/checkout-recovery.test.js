import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID, randomBytes } from 'node:crypto';
import { once } from 'node:events';
import jwt from 'jsonwebtoken';
import { createApp } from '../src/app.js';
import { createOrdersRepository } from '../src/repositories/orders.repository.js';
import { readAuthConfig } from '../src/config/env.js';
import { AuthError } from '../src/services/auth.service.js';

const userId = randomUUID(), requestId = randomUUID();
const stored = { id: randomUUID(), userId, clientRequestId: requestId, requestHash: 'same', status: 'PENDING',
  paymentStatus: 'UNPAID', paymentMethod: 'COD', currency: 'USD', totalInCents: 3500, items: [] };

test('Request lookup uses the authenticated account and returns identical 404s for foreign/missing keys', async () => {
  const repo = createOrdersRepository(() => ({ order: { async findUnique({ where }) {
    const key = where.userId_clientRequestId;
    return key.userId === userId && key.clientRequestId === requestId ? stored : null;
  } } }));
  assert.equal((await repo.findRequest(userId, requestId)).id, stored.id);
  await assert.rejects(repo.findRequest(randomUUID(), requestId), { code: 'ORDER_NOT_FOUND', status: 404 });
  await assert.rejects(repo.findRequest(userId, randomUUID()), { code: 'ORDER_NOT_FOUND', status: 404 });
});

test('A retry checks for a committed copy AFTER locking and before catalog/address validation', async () => {
  let locked = false, productsRead = false;
  const db = {
    async $queryRaw(parts, value) {
      assert.ok(parts.join('?').includes('pg_advisory_xact_lock'));
      assert.equal(value, `${userId}:${requestId}`);
      locked = true;
    },
    order: { async findUnique() { return locked ? stored : null; } },
    product: { async findMany() { productsRead = true; throw new Error('Catalog changed after original commit'); } },
    async $transaction(action) { return action(db); },
  };
  const order = await createOrdersRepository(() => db).create(userId, { clientRequestId: requestId, requestHash: 'same' }, {});
  assert.equal(order.id, stored.id);
  assert.equal(productsRead, false);
});

test('Recovery HTTP endpoint authenticates and validates keys without creating or changing orders', async t => {
  const authConfig = readAuthConfig({ JWT_SECRET: randomBytes(48).toString('hex') });
  const user = { id: userId, email: 'recovery@example.test', name: 'Member', passwordHash: 'present', authVersion: 0 };
  let lookups = 0;
  const server = createApp({ authRepository: { async findById() { return user; } }, authConfig: () => authConfig,
    ordersRepository: { async findRequest(owner, key) {
      assert.equal(owner, userId); lookups++;
      if (key !== requestId) throw new AuthError(404, 'ORDER_NOT_FOUND', 'This order is not available.');
      return { id: stored.id };
    } },
  }).listen(0, '127.0.0.1');
  await once(server, 'listening'); t.after(() => new Promise(resolve => server.close(resolve)));
  const token = jwt.sign({ ver: 0 }, authConfig.secret, { subject: userId, issuer: authConfig.issuer, audience: authConfig.audience, expiresIn: 600 });
  const get = (key, authenticated = true) => fetch(`http://127.0.0.1:${server.address().port}/api/orders/request/${key}`, { headers: authenticated ? { authorization: `Bearer ${token}` } : {} });
  assert.equal((await get(requestId, false)).status, 401);
  assert.equal((await get('invalid')).status, 400);
  assert.equal(lookups, 0);
  const response = await get(requestId);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal((await response.json()).data.order.id, stored.id);
  assert.equal((await get(randomUUID())).status, 404);
  assert.equal(lookups, 2);
});
