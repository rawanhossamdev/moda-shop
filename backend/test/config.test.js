import test from 'node:test';
import assert from 'node:assert/strict';
import { readEnvironment, requireDatabaseUrl } from '../src/config/env.js';

test('Environment defaults allow health server without PostgreSQL', () => {
  assert.deepEqual(readEnvironment({}), { port: 3000, host: '127.0.0.1', nodeEnv: 'development' });
  assert.equal(readEnvironment({ PORT: '4000' }).port, 4000);
});
test('Invalid ports and environment values fail clearly', () => {
  for (const PORT of ['0', '-1', '65536', 'abc', '1.5', '']) {
    assert.throws(() => readEnvironment({ PORT }), /PORT/);
  }
  assert.throws(() => readEnvironment({ NODE_ENV: 'invalid' }), /NODE_ENV/);
});
test('Database configuration requires an explicit PostgreSQL URL', () => {
  assert.throws(() => requireDatabaseUrl({}), /DATABASE_URL/);
  assert.throws(() => requireDatabaseUrl({ DATABASE_URL: 'https://example.com' }), /postgres/);
  assert.throws(() => requireDatabaseUrl({ DATABASE_URL: 'not a URL' }), /valid/);
  const DATABASE_URL = 'postgresql://user:placeholder@localhost:5432/moda_shop';
  assert.equal(requireDatabaseUrl({ DATABASE_URL }), DATABASE_URL);
});

