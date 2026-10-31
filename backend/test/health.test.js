import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createApp } from '../src/app.js';

test('HTTP liveness, not-found and malformed JSON responses', async (t) => {
  const server = createApp().listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;
  const healthy = await fetch(`${base}/api/health`);
  assert.equal(healthy.status, 200);
  assert.match(healthy.headers.get('content-type'), /application\/json/);
  assert.equal(healthy.headers.get('x-powered-by'), null);
  assert.deepEqual(await healthy.json(), { status: 'ok', service: 'moda-shop-api' });
  const missing = await fetch(`${base}/api/missing`);
  assert.equal(missing.status, 404);
  assert.deepEqual(await missing.json(), { error: { code: 'NOT_FOUND', message: 'Route not found' } });
  const invalid = await fetch(`${base}/api/health`, {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: '{',
  });
  assert.equal(invalid.status, 400);
  assert.deepEqual(await invalid.json(), { error: { code: 'INVALID_REQUEST', message: 'Invalid request' } });
});

