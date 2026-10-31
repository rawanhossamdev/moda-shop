import test from 'node:test';
import assert from 'node:assert/strict';
import { getDatabase, disconnectDatabase } from '../src/config/database.js';

test('Generated JavaScript client constructs with the PostgreSQL adapter offline', async () => {
  const previousUrl = process.env.DATABASE_URL;
  // This deliberately unused endpoint is never connected to in this test.
  process.env.DATABASE_URL = 'postgresql://unused:placeholder@127.0.0.1:1/unused';
  try {
    const client = getDatabase();
    assert.equal(getDatabase(), client);
    assert.equal(typeof client.product.findMany, 'function');
    assert.equal(typeof client.order.create, 'function');
  } finally {
    await disconnectDatabase();
    if (previousUrl === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = previousUrl;
  }
});
