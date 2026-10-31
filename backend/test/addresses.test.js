import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID, randomBytes } from 'node:crypto';
import { once } from 'node:events';
import jwt from 'jsonwebtoken';
import { addressInput } from '../src/services/address.service.js';
import { createAddressesRepository } from '../src/repositories/addresses.repository.js';
import { createApp } from '../src/app.js';
import { readAuthConfig } from '../src/config/env.js';

const fields = { fullName: 'MODA Member', mobile: '01012345678', governorate: 'Cairo', city: 'Maadi',
  streetAddress: '25 Test street', buildingDetails: 'Building 25, apartment 4', deliveryNotes: '' };

test('Egyptian address validation trims fields, normalizes mobile prefixes and rejects unsafe/incomplete input', () => {
  for (const mobile of ['01012345678', '+201012345678', '00201012345678', '010 1234 5678', '01112345678', '01212345678', '01512345678']) {
    const value = addressInput({ ...fields, mobile, fullName: ' MODA Member ', userId: 'attacker' });
    assert.match(value.mobile, /^\+201[0125]\d{8}$/);
    assert.equal(value.fullName, 'MODA Member');
    assert.equal(value.userId, undefined);
  }
  for (const mobile of ['01312345678', '0101234567', '+12012345678', '02012345678', '010123456789', '010abcdef78']) {
    assert.throws(() => addressInput({ ...fields, mobile }), { code: 'INVALID_MOBILE' });
  }
  for (const key of ['fullName', 'mobile', 'governorate', 'city', 'streetAddress', 'buildingDetails']) {
    assert.throws(() => addressInput({ ...fields, [key]: '' }), { status: 400 });
  }
  assert.throws(() => addressInput({ ...fields, fullName: 'A\nB' }), { code: 'INVALID_ADDRESS' });
  assert.throws(() => addressInput({ ...fields, isDefault: 'yes' }), { code: 'INVALID_ADDRESS' });
  assert.throws(() => addressInput({ ...fields, buildingDetails: 'a'.repeat(201) }), { code: 'INVALID_ADDRESS' });
  assert.equal(addressInput({ ...fields, deliveryNotes: undefined }).deliveryNotes, '');
});

// Exercise repository ownership/default behavior with a transactional in-memory adapter.
function fixture() {
  let rows = [];
  const matches = (row, where) => Object.entries(where).every(([key, value]) => row[key] === value);
  const table = {
    async findMany({ where }) { return rows.filter(r => matches(r, where)); },
    async findFirst({ where }) { return rows.find(r => matches(r, where)) ?? null; },
    async count({ where }) { return rows.filter(r => matches(r, where)).length; },
    async create({ data }) { const row = { ...data, id: randomUUID() }; rows.push(row); return row; },
    async updateMany({ where, data }) { rows.filter(r => matches(r, where)).forEach(r => Object.assign(r, data)); },
    async update({ where, data }) { const row = rows.find(r => matches(r, where)); Object.assign(row, data); return row; },
    async delete({ where }) { rows = rows.filter(r => !matches(r, where)); },
  };
  const db = { shippingAddress: table, async $queryRaw() {}, async $transaction(action) {
    const before = structuredClone(rows);
    try { return await action(db); } catch (error) { rows = before; throw error; }
  } };
  return createAddressesRepository(() => db);
}

test('Addresses are scoped to their owner; defaults move without touching other accounts', async () => {
  const repo = fixture(), alice = randomUUID(), bob = randomUUID();
  const first = await repo.save(alice, addressInput(fields));
  const second = await repo.save(alice, addressInput({ ...fields, city: 'Heliopolis' }));
  const other = await repo.save(bob, addressInput(fields));
  assert.equal(first.isDefault, true);
  assert.equal(second.isDefault, false);
  assert.equal(other.isDefault, true);
  await assert.rejects(repo.save(bob, addressInput(fields), first.id), { code: 'ADDRESS_NOT_FOUND' });
  await assert.rejects(repo.remove(bob, first.id), { code: 'ADDRESS_NOT_FOUND' });
  assert.deepEqual((await repo.list(bob)).map(a => a.id), [other.id]);
  await repo.save(alice, addressInput({ ...fields, isDefault: true }), second.id);
  assert.equal((await repo.list(alice)).filter(a => a.isDefault).length, 1);
  assert.equal((await repo.list(alice)).find(a => a.id === second.id).isDefault, true);
  await repo.remove(alice, second.id);
  assert.equal((await repo.list(alice))[0].isDefault, true);
  await repo.remove(alice, first.id);
  assert.deepEqual(await repo.list(alice), []);
  assert.equal((await repo.list(bob))[0].isDefault, true);
});

test('Address HTTP routes authenticate, ignore supplied owner IDs, validate and protect foreign addresses', async t => {
  const user = { id: randomUUID(), email: 'address@example.test', name: 'Member', authVersion: 0, passwordHash: 'present' };
  const repo = fixture(), config = readAuthConfig({ JWT_SECRET: randomBytes(48).toString('hex') });
  const foreign = await repo.save(randomUUID(), addressInput(fields));
  const server = createApp({ addressesRepository: repo, authRepository: { async findById() { return user; } }, authConfig: () => config }).listen(0, '127.0.0.1');
  await once(server, 'listening'); t.after(() => new Promise(resolve => server.close(resolve)));
  const token = jwt.sign({ ver: 0 }, config.secret, { subject: user.id, issuer: config.issuer, audience: config.audience, expiresIn: 600 });
  const request = (method, path = '', body, authenticated = true) => fetch(`http://127.0.0.1:${server.address().port}/api/addresses${path}`, {
    method, headers: { 'content-type': 'application/json', ...(authenticated ? { authorization: `Bearer ${token}` } : {}) },
    ...(body && method !== 'GET' ? { body: JSON.stringify(body) } : {}),
  });
  for (const [method, path] of [['GET', ''], ['POST', ''], ['PUT', `/${foreign.id}`], ['DELETE', `/${foreign.id}`]]) {
    assert.equal((await request(method, path, fields, false)).status, 401);
  }
  assert.equal((await request('POST', '', { ...fields, mobile: 'invalid' })).status, 400);
  assert.equal((await request('PUT', `/${foreign.id}`, fields)).status, 404);
  assert.equal((await request('DELETE', `/${foreign.id}`)).status, 404);
  assert.equal((await request('DELETE', '/invalid')).status, 400);
  const created = await request('POST', '', { ...fields, userId: randomUUID() });
  assert.equal(created.status, 201);
  const address = (await created.json()).data.address;
  assert.equal(address.mobile, '+201012345678');
  assert.equal('userId' in address, false);
  const listed = await request('GET');
  assert.equal(listed.headers.get('cache-control'), 'no-store');
  assert.deepEqual((await listed.json()).data.addresses.map(a => a.id), [address.id]);
  assert.equal((await request('PUT', `/${address.id}`, { ...fields, city: 'Alexandria' })).status, 200);
  assert.equal((await request('DELETE', `/${address.id}`)).status, 200);
  assert.deepEqual((await (await request('GET')).json()).data.addresses, []);
});
