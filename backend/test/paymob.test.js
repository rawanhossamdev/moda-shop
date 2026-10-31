import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { randomUUID, randomBytes } from 'node:crypto';
import { once } from 'node:events';
import jwt from 'jsonwebtoken';
import { createApp } from '../src/app.js';
import { readAuthConfig } from '../src/config/env.js';
import { readCommerceConfig } from '../src/config/commerce.js';
import { callbackText, verifyCallback, createPaymobClient, sealCheckout, openCheckout } from '../src/services/paymob.js';

export function testSettings() {
  return readCommerceConfig({ PAYMOB_ENABLED: 'true', PAYMOB_MODE: 'test', PAYMOB_SECRET_KEY: 'sk_test_fixture',
    PAYMOB_PUBLIC_KEY: 'pk_test_fixture', PAYMOB_HMAC_SECRET: 'fixture-hmac', PAYMOB_OWNER_ID: '4705',
    PAYMOB_CURRENCY: 'USD', PAYMOB_CARD_INTEGRATION_ID: '6741', PAYMOB_WALLET_INTEGRATION_ID: '6742',
    PAYMOB_NOTIFICATION_URL: 'https://example.test/api/payments/paymob/webhook', PAYMOB_RETURN_URL: 'https://example.test/api/payments/paymob/return' });
}
export function callback(overrides = {}) {
  return { type: 'TRANSACTION', obj: { amount_cents: 100, created_at: '2020-03-25T18:39:44.719228', currency: 'USD',
    error_occured: false, has_parent_transaction: false, id: 2556706, integration_id: 6741, is_3d_secure: true,
    is_auth: false, is_capture: false, is_refunded: false, is_standalone_payment: true, is_voided: false,
    order: { id: 4778239 }, owner: 4705, pending: false,
    source_data: { pan: '2346', sub_type: 'MasterCard', type: 'card' }, success: true, ...overrides } };
}
export function signature(body, config = testSettings().paymob) { return createHmac('sha512', config.hmacSecret).update(callbackText(body.obj)).digest('hex'); }

test('Configuration disables missing, live and mismatched currencies without conversion', () => {
  assert.equal(readCommerceConfig({}).paymob.enabled, false);
  const config = testSettings(); assert.equal(config.paymob.enabled, true); assert.equal(config.currency, 'USD');
  for (const overrides of [{ PAYMOB_MODE: 'live' }, { PAYMOB_SECRET_KEY: 'sk_live_forbidden' }, { PAYMOB_CURRENCY: 'EGP' }, { PAYMOB_NOTIFICATION_URL: 'http://localhost/callback' }]) {
    const source = { PAYMOB_ENABLED: 'true', PAYMOB_MODE: 'test', PAYMOB_SECRET_KEY: 'sk_test_fixture', PAYMOB_PUBLIC_KEY: 'pk_test_fixture',
      PAYMOB_HMAC_SECRET: 'fixture-hmac', PAYMOB_OWNER_ID: '4705', PAYMOB_CURRENCY: 'USD', PAYMOB_CARD_INTEGRATION_ID: '6741',
      PAYMOB_NOTIFICATION_URL: 'https://example.test/callback', PAYMOB_RETURN_URL: 'https://example.test/return', ...overrides };
    assert.equal(readCommerceConfig(source).paymob.enabled, false);
  }
});
test('HMAC uses documented order, rejects tampering/null fields and distinguishes signed states', () => {
  const config = testSettings().paymob;
  const body = callback();
  assert.equal(callbackText(body.obj), '1002020-03-25T18:39:44.719228USDfalsefalse25567066741truefalsefalsefalsetruefalse47782394705false2346MasterCardcardtrue');
  assert.equal(verifyCallback(body, signature(body), config).status, 'PAID');
  assert.throws(() => verifyCallback(callback({ amount_cents: 101 }), signature(body), config), { status: 401 });
  for (const bad of ['', 'wrong', null]) assert.throws(() => verifyCallback(body, bad, config), { status: 401 });
  assert.throws(() => verifyCallback(callback({ source_data: {} }), signature(body), config), { status: 401 });
  for (const [fields, status] of [[{ pending: true }, 'PENDING'], [{ success: false }, 'FAILED'], [{ is_voided: true }, 'CANCELLED'], [{ is_auth: true }, 'PENDING'], [{ has_parent_transaction: true }, 'FAILED']]) {
    const event = callback(fields); assert.equal(verifyCallback(event, signature(event), config).status, status);
  }
  const live = callback({ is_live: true }); assert.throws(() => verifyCallback(live, signature(live), config), { status: 400 });
});

test('HTTP webhook verifies HMAC before persistence and return redirect cannot mutate payment', async (t) => {
  const config = testSettings(); let events = 0;
  const server = createApp({ commerceConfig: () => config, ordersRepository: { async callback() { events++; } } }).listen(0, '127.0.0.1');
  await once(server, 'listening'); t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}/api/payments/paymob`;
  const body = callback();
  const post = (hmac, value = body) => fetch(`${base}/webhook?hmac=${hmac}`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(value) });
  assert.equal((await post('invalid')).status, 401); assert.equal(events, 0);
  assert.equal((await post(signature(body), callback({ amount_cents: 1 }))).status, 401); assert.equal(events, 0);
  assert.equal((await post(signature(body))).status, 200); assert.equal(events, 1);
  assert.equal((await fetch(`${base}/return?success=true`)).status, 200); assert.equal(events, 1);
});

test('Phase 3A blocks online initiation even with valid test gateway settings', async (t) => {
  const config = testSettings(); const authConfig = readAuthConfig({ JWT_SECRET: randomBytes(48).toString('hex') });
  const user = { id: randomUUID(), email: 'member@example.test', name: 'Member', authVersion: 0, passwordHash: 'present', emailVerifiedAt: new Date() };
  const order = { id: randomUUID(), paymentMethod: 'PAYMOB_CARD', paymentStatus: 'PENDING', currency: 'USD' };
  let attempt; let creations = 0; let fail = false;
  const repository = {
    async detail() { return order; },
    async reservePayment() {
      if (attempt) return { order, attempt, fresh: false };
      attempt = { id: randomUUID(), status: 'PENDING', integrationId: 6741, expiresAt: new Date(Date.now() + 900000) };
      return { order, attempt, fresh: true };
    },
    async savePayment(_id, value) { Object.assign(attempt, value); },
    async paymentUnknown() { attempt.status = 'UNKNOWN'; },
  };
  const server = createApp({ commerceConfig: () => config, authConfig: () => authConfig,
    authRepository: { async findById() { return user; } }, ordersRepository: repository,
    paymob: { async create() { creations++; if (fail) throw new Error('private provider response');
      return { intentionId: 'test-intention', providerOrderId: '4778239', url: 'https://accept.paymob.com/unifiedcheckout/?publicKey=pk_test_fixture&clientSecret=csk_test_fixture' }; } },
  }).listen(0, '127.0.0.1');
  await once(server, 'listening'); t.after(() => new Promise((resolve) => server.close(resolve)));
  const token = jwt.sign({ ver: 0 }, authConfig.secret, { subject: user.id, issuer: authConfig.issuer, audience: authConfig.audience, expiresIn: 600 });
  const request = () => fetch(`http://127.0.0.1:${server.address().port}/api/orders/${order.id}/payment`, {
    method: 'POST', headers: { authorization: `Bearer ${token}` },
  });
  const response = await request();
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, 'PAYMENTS_DISABLED');
  assert.equal((await request()).status, 503);
  const base = `http://127.0.0.1:${server.address().port}/api`;
  const headers = { authorization: `Bearer ${token}`, 'content-type': 'application/json' };
  const settings = await (await fetch(`${base}/checkout/config`, { headers })).json();
  assert.deepEqual(settings.data.paymentMethods, ['COD']);
  const onlineOrder = await fetch(`${base}/orders`, { method: 'POST', headers, body: JSON.stringify({
    clientRequestId: randomUUID(), addressId: randomUUID(), paymentMethod: 'PAYMOB_CARD', expectedTotalInCents: 3700,
    items: [{ productId: 'knit-sweater', size: 'M', quantity: 1 }],
  }) });
  assert.equal(onlineOrder.status, 503);
  assert.equal((await onlineOrder.json()).error.code, 'PAYMENTS_DISABLED');
  assert.equal(creations, 0);
  assert.equal(attempt, undefined);
});

test('Intention client uses server totals, merchant method, test secrets and hosted checkout only', async () => {
  const config = testSettings().paymob;
  const client = createPaymobClient(async (url, options) => {
    assert.equal(url, 'https://accept.paymob.com/v1/intention/');
    assert.ok(options.headers.authorization.startsWith('Token sk_test_'));
    const body = JSON.parse(options.body);
    assert.equal(body.amount, 3700); assert.equal(body.currency, 'USD');
    assert.deepEqual(body.payment_methods, [6741]); assert.equal(body.billing_data.country, 'EGY');
    assert.equal(body.items.reduce((sum, item) => sum + item.amount * item.quantity, 0), 3700);
    assert.ok(!JSON.stringify(body).includes('card_number'));
    return { status: 201, json: async () => ({ id: 'intention-test', intention_order_id: 4778239, client_secret: 'csk_test_fixture' }) };
  });
  const result = await client.create({ shippingName: 'MODA Member', shippingPhone: '+201000000000', shippingAddress: 'Test street', shippingCity: 'Cairo',
    totalInCents: 3700, currency: 'USD', shippingFeeInCents: 200, items: [{ productName: 'Sweater', unitPriceInCents: 3500, quantity: 1 }] },
  { email: 'member@example.test' }, { id: 'attempt', integrationId: 6741 }, config);
  const uri = new URL(result.url); assert.equal(uri.pathname, '/unifiedcheckout/');
  const encrypted = sealCheckout(result.url, 'test-encryption-secret');
  assert.ok(!encrypted.includes('csk_test_')); assert.ok(openCheckout(encrypted, 'test-encryption-secret') === result.url);
  assert.throws(() => openCheckout(encrypted, 'different-secret'));
});
