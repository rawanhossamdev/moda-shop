import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createOrdersRepository } from '../src/repositories/orders.repository.js';
import { orderInput } from '../src/services/checkout.service.js';
import { readCommerceConfig } from '../src/config/commerce.js';

const config = readCommerceConfig({ SHIPPING_FEE_CENTS: '200' });
const userId = randomUUID();
const address = { id: randomUUID(), userId, fullName: 'MODA Member', mobile: '+201012345678', governorate: 'Cairo',
  city: 'Maadi', streetAddress: 'Test street', buildingDetails: 'Apartment 4', deliveryNotes: '' };
const product = { id: 'shoulder-bag', name: 'Shoulder Bag', image: 'assets/images/shoulder_bag.png',
  isActive: true, priceInCents: 6500, currency: 'USD', sizes: [{ size: 'ONE_SIZE', isAvailable: true }] };
const body = () => ({ clientRequestId: randomUUID(), addressId: address.id, paymentMethod: 'COD',
  expectedTotalInCents: 13200, items: [{ productId: product.id, size: 'ONE_SIZE', quantity: 2 }] });

test('Order requests ignore client snapshots/prices and reject online methods even when configured', () => {
  const value = body();
  assert.deepEqual(orderInput(value, config), orderInput({ ...value, totalInCents: 1, shippingName: 'Forged', items: [{ ...value.items[0], priceInCents: 1 }] }, config));
  assert.throws(() => orderInput({ ...value, paymentMethod: 'PAYMOB_CARD' }, { ...config, paymob: { methods: { PAYMOB_CARD: 1 } } }), { code: 'PAYMENTS_DISABLED' });
  assert.throws(() => orderInput({ ...value, addressId: 'invalid' }, config), { code: 'INVALID_ADDRESS' });
});

test('Concurrent identical submissions resolve a unique-key race to the same persisted order', async () => {
  let stored, creates = 0;
  let arrivals = 0, release;
  const bothArrived = new Promise(resolve => { release = resolve; });
  const db = {
    async $queryRaw() {},
    product: { async findMany() { return [product]; } },
    shippingAddress: { async findFirst({ where }) { return where.id === address.id && where.userId === userId ? address : null; } },
    order: {
      async findUnique({ where }) {
        assert.equal(where.userId_clientRequestId.userId, userId);
        return stored ?? null;
      },
      async create({ data }) {
        if (++arrivals === 2) release();
        await bothArrived;
        if (stored) throw Object.assign(new Error('unique request'), { code: 'P2002' });
        creates++;
        stored = { ...data, id: randomUUID(), createdAt: new Date(), items: data.items.create };
        return stored;
      },
      async findFirst({ where }) { return stored?.id === where.id && stored.userId === where.userId ? stored : null; },
      async findMany({ where }) { return stored?.userId === where.userId ? [stored] : []; },
    },
    orderEvent: { async create() {} },
    async $transaction(action) { return action(db); },
  };
  const repo = createOrdersRepository(() => db), input = orderInput(body(), config);
  const [first, duplicate] = await Promise.all([repo.create(userId, input, config), repo.create(userId, input, config)]);
  assert.equal(first.id, duplicate.id);
  assert.equal(creates, 1);
  assert.equal(first.status, 'PENDING');
  assert.equal(first.paymentStatus, 'UNPAID');
  assert.equal(first.totalInCents, 13200);
  assert.equal(first.items[0].unitPriceInCents, 6500);
  assert.equal(first.items[0].size, 'ONE_SIZE');
  address.city = 'Changed after placement';
  assert.equal((await repo.detail(first.id, userId)).shippingSnapshot.city, 'Maadi');
  assert.equal((await repo.list(userId)).orders[0].id, first.id);
  assert.equal((await repo.create(userId, input, config)).id, first.id);
  await assert.rejects(repo.create(userId, { ...input, requestHash: 'different' }, config), { code: 'REQUEST_CONFLICT' });
  await assert.rejects(repo.detail(first.id, randomUUID()), { code: 'ORDER_NOT_FOUND' });
  await assert.rejects(repo.list(randomUUID(), first.id), { code: 'ORDER_NOT_FOUND' });
  assert.deepEqual((await repo.list(randomUUID())).orders, []);
});
