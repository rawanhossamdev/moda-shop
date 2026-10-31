import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { once } from 'node:events';
import jwt from 'jsonwebtoken';
import { cartInput, orderInput, calculateQuote, requireVerified } from '../src/services/checkout.service.js';
import { readCommerceConfig } from '../src/config/commerce.js';
import { readAuthConfig } from '../src/config/env.js';
import { createApp } from '../src/app.js';

const product = { id: 'knit-sweater', name: 'Ribbed Knit Sweater', priceInCents: 3500, currency: 'USD', isActive: true, sizes: [{ size: 'M' }] };
const items = [{ productId: product.id, size: 'M', quantity: 2 }];
const shipping = { shippingName: 'MODA Member', shippingPhone: '+201000000000', shippingAddress: '25 Test street', shippingCity: 'Cairo', deliveryNotes: 'Ring bell' };
const config = readCommerceConfig({ SHIPPING_FEE_CENTS: '200' });
test('Quotes use catalog integer prices/sizes/currency and configured shipping, never client prices', () => {
  const quote = calculateQuote(cartInput([{ ...items[0], priceInCents: 1, totalInCents: 2 }]), [product], config);
  assert.equal(quote.subtotalInCents, 7000); assert.equal(quote.shippingFeeInCents, 200); assert.equal(quote.totalInCents, 7200);
  assert.equal(quote.currency, 'USD');
  assert.throws(() => calculateQuote(items, [{ ...product, isActive: false }], config), { status: 409 });
  assert.throws(() => calculateQuote(items, [{ ...product, sizes: [] }], config), { status: 409 });
  assert.throws(() => calculateQuote(items, [product], { ...config, currency: 'EGP' }), { code: 'CURRENCY_MISMATCH' });
});
test('Checkout validates quantity, duplicate lines, shipping, request identifiers and verification', () => {
  for (const value of [[], null, [{ ...items[0], quantity: 0 }], [{ ...items[0], quantity: 21 }], [items[0], items[0]], [{ ...items[0], size: 'XL' }]]) {
    assert.throws(() => cartInput(value), { status: 400 });
  }
  assert.throws(() => requireVerified({}), { status: 403 });
  assert.doesNotThrow(() => requireVerified({ emailVerifiedAt: new Date() }));
  assert.throws(() => orderInput({ clientRequestId: randomUUID(), items, paymentMethod: 'COD', expectedTotalInCents: 7200 }, config), { code: 'INVALID_ADDRESS' });
  const body = { addressId: randomUUID(), items, paymentMethod: 'COD', clientRequestId: randomUUID(), expectedTotalInCents: 7200 };
  const normalized = orderInput(body, config);
  assert.equal(normalized.requestHash.length, 64);
  assert.equal(orderInput({ ...body, totalInCents: 1 }, config).requestHash, normalized.requestHash);
  assert.throws(() => orderInput({ ...body, clientRequestId: 'invalid' }, config), { status: 400 });
  assert.throws(() => orderInput({ ...body, paymentMethod: 'PAYMOB_CARD' }, config), { status: 503 });
});
test('HTTP checkout enforces auth/verification, scopes order access and ignores redirects', async (t) => {
  const user = { id: randomUUID(), email: 'member@example.test', name: 'Member', authVersion: 0, passwordHash: 'present', emailVerifiedAt: null };
  const authConfig = readAuthConfig({ JWT_SECRET: randomBytes(48).toString('hex') });
  const calls = [];
  const orders = {
    async quote(lines) { calls.push('quote'); return calculateQuote(lines, [product], config); },
    async list(userId) { calls.push(userId); return { orders: [], nextCursor: null }; },
    async detail(id, userId) { calls.push(userId); throw Object.assign(new Error('not found'), { status: 404 }); },
    async callback() { calls.push('callback'); },
  };
  const server = createApp({ authRepository: { async findById() { return user; } }, authConfig: () => authConfig,
    ordersRepository: orders, commerceConfig: () => config }).listen(0, '127.0.0.1');
  await once(server, 'listening'); t.after(() => new Promise((resolve) => server.close(resolve)));
  const token = jwt.sign({ ver: 0 }, authConfig.secret, { subject: user.id, issuer: authConfig.issuer, audience: authConfig.audience, expiresIn: 600 });
  const request = (path, body, authenticated = true) => fetch(`http://127.0.0.1:${server.address().port}/api/${path}`, {
    method: body ? 'POST' : 'GET', headers: { 'content-type': 'application/json', ...(authenticated ? { authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  assert.equal((await request('checkout/config', undefined, false)).status, 401);
  const settings = (await (await request('checkout/config')).json()).data;
  assert.deepEqual(settings.paymentMethods, ['COD']); assert.equal(settings.testMode, true);
  assert.ok(!JSON.stringify(settings).includes('secret'));
  assert.equal((await request('checkout/quote', { items })).status, 403);
  assert.equal((await request('orders', { ...shipping, items })).status, 403);
  user.emailVerifiedAt = new Date();
  const quote = await request('checkout/quote', { items }); assert.equal(quote.status, 200);
  assert.equal((await quote.json()).data.totalInCents, 7200);
  assert.equal((await request('orders')).status, 200); assert.ok(calls.includes(user.id));
  const before = calls.length;
  assert.equal((await request('payments/paymob/return?success=true&paid=true')).status, 200);
  assert.equal(calls.length, before);
  assert.equal((await request('payments/paymob/webhook', { type: 'TRANSACTION', obj: {} }, false)).status, 503);
  assert.ok(!calls.includes('callback'));
  assert.equal((await request('orders/not-an-id')).status, 400);
});

test('One-size checkout preserves variant and quantities and rejects retired clothing sizes', () => {
  const bag = { ...product, id: 'shoulder-bag', name: 'Shoulder Bag', priceInCents: 6500,
    sizes: [{ size: 'ONE_SIZE', isAvailable: true }, { size: 'M', isAvailable: false }] };
  const lines = cartInput([{ productId: bag.id, size: 'ONE_SIZE', quantity: 2 }]);
  const quote = calculateQuote(lines, [bag], config);
  assert.equal(quote.items[0].size, 'ONE_SIZE');
  assert.equal(quote.items[0].quantity, 2);
  assert.equal(quote.subtotalInCents, 13000);
  for (const size of ['S', 'M', 'L']) {
    assert.throws(() => calculateQuote([{ ...lines[0], size }], [bag], config), { code: 'CART_UNAVAILABLE' });
  }
  assert.throws(() => calculateQuote([{ ...items[0], size: 'ONE_SIZE' }], [product], config), { code: 'CART_UNAVAILABLE' });
});
