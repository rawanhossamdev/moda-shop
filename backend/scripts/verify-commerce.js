// Only synthetic writes inside an ALWAYS-ROLLED-BACK transaction.
// No emails, gateway requests, or changes to pre-existing accounts/orders.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { getDatabase, disconnectDatabase } from '../src/config/database.js';
import { createOrdersRepository } from '../src/repositories/orders.repository.js';
import { createAddressesRepository } from '../src/repositories/addresses.repository.js';
import { addressInput } from '../src/services/address.service.js';
import { orderInput } from '../src/services/checkout.service.js';
import { readCommerceConfig } from '../src/config/commerce.js';

const rollback = new Error('Intentional verification rollback');
const db = getDatabase();
const fields = { fullName: 'Temporary member', mobile: '01012345678', governorate: 'Cairo', city: 'Maadi',
  streetAddress: '25 Test street', buildingDetails: 'Building 25, apartment 4', deliveryNotes: 'Ring bell' };
try {
  const counts = () => Promise.all([db.user.count(), db.shippingAddress.count(), db.product.count(), db.order.count(), db.orderItem.count(), db.paymentAttempt.count(), db.orderEvent.count()]);
  const before = await counts();
  try {
    await db.$transaction(async tx => {
      const user = await tx.user.create({ data: { email: `phase3a-${randomUUID()}@example.test`, name: 'Temporary member', emailVerifiedAt: new Date() } });
      const other = await tx.user.create({ data: { email: `phase3a-${randomUUID()}@example.test`, name: 'Other temporary member' } });
      let sequence = 0;
      const adapter = new Proxy(tx, { get(target, key) { return key === '$transaction' ? async action => {
        const savepoint = `moda_verify_${++sequence}`;
        await target.$executeRawUnsafe(`SAVEPOINT ${savepoint}`);
        try { const value = await action(target); await target.$executeRawUnsafe(`RELEASE SAVEPOINT ${savepoint}`); return value; }
        catch (error) { await target.$executeRawUnsafe(`ROLLBACK TO SAVEPOINT ${savepoint}`); await target.$executeRawUnsafe(`RELEASE SAVEPOINT ${savepoint}`); throw error; }
      } : Reflect.get(target, key); } });
      const addresses = createAddressesRepository(() => adapter);
      const first = await addresses.save(user.id, addressInput(fields));
      const second = await addresses.save(user.id, addressInput({ ...fields, city: 'Heliopolis' }));
      assert.equal(first.isDefault, true);
      assert.equal(second.isDefault, false);
      await addresses.save(user.id, addressInput({ ...fields, isDefault: true }), second.id);
      assert.equal((await addresses.list(user.id)).filter(a => a.isDefault).length, 1);
      await assert.rejects(addresses.save(other.id, addressInput(fields), first.id), { code: 'ADDRESS_NOT_FOUND' });
      await assert.rejects(addresses.remove(other.id, first.id), { code: 'ADDRESS_NOT_FOUND' });
      assert.deepEqual(await addresses.list(other.id), []);
      const repo = createOrdersRepository(() => adapter);
      const config = readCommerceConfig({ SHIPPING_FEE_CENTS: '200' });
      const bag = await tx.product.findFirst({ where: { id: 'shoulder-bag', isActive: true }, include: { sizes: true } });
      assert.ok(bag?.sizes.some(s => s.size === 'ONE_SIZE' && s.isAvailable));
      const items = [{ productId: bag.id, size: 'ONE_SIZE', quantity: 2 }];
      const quote = await repo.quote(items, config);
      const body = { addressId: first.id, items, clientRequestId: randomUUID(), paymentMethod: 'COD', expectedTotalInCents: quote.totalInCents };
      const input = orderInput({ ...body, totalInCents: 1, shippingName: 'FORGED' }, config);
      const cod = await repo.create(user.id, input, config);
      assert.equal((await repo.findRequest(user.id, body.clientRequestId)).id, cod.id);
      await assert.rejects(repo.findRequest(other.id, body.clientRequestId), { code: 'ORDER_NOT_FOUND' });
      assert.equal(cod.status, 'PENDING');
      assert.equal(cod.paymentStatus, 'UNPAID');
      assert.equal(cod.currency, bag.currency);
      assert.equal(cod.totalInCents, bag.priceInCents * 2 + 200);
      assert.equal(cod.shippingSnapshot.fullName, fields.fullName);
      assert.equal(cod.shippingSnapshot.governorate, fields.governorate);
      assert.equal(cod.shippingSnapshot.buildingDetails, fields.buildingDetails);
      assert.equal(cod.items[0].productImage, bag.image);
      assert.equal(cod.items[0].unitPriceInCents, bag.priceInCents);
      assert.equal(cod.items[0].size, 'ONE_SIZE');
      assert.equal((await repo.create(user.id, input, config)).id, cod.id);
      await assert.rejects(repo.create(user.id, orderInput({ ...body, expectedTotalInCents: 1 }, config), config), { code: 'REQUEST_CONFLICT' });
      await assert.rejects(repo.detail(cod.id, other.id), { code: 'ORDER_NOT_FOUND' });
      await assert.rejects(repo.list(other.id, cod.id), { code: 'ORDER_NOT_FOUND' });
      assert.deepEqual((await repo.list(other.id)).orders, []);
      const orderCount = await tx.order.count({ where: { userId: user.id } });
      const itemCount = await tx.orderItem.count({ where: { orderId: cod.id } });
      const invalid = async (changes, expected, userId = user.id, options = config) => {
        const data = orderInput({ ...body, clientRequestId: randomUUID(), ...changes }, config);
        await assert.rejects(repo.create(userId, data, options), expected);
        assert.equal(await tx.order.count({ where: { userId: user.id } }), orderCount);
      };
      await invalid({ expectedTotalInCents: 1 }, { code: 'PRICE_CHANGED' });
      await invalid({ addressId: randomUUID() }, { code: 'ADDRESS_NOT_FOUND' });
      await invalid({}, { code: 'ADDRESS_NOT_FOUND' }, other.id);
      await invalid({ items: [{ ...items[0], size: 'M' }] }, { code: 'CART_UNAVAILABLE' });
      await invalid({ items: [{ ...items[0], productId: 'missing-product' }] }, { code: 'CART_UNAVAILABLE' });
      await invalid({}, { code: 'CURRENCY_MISMATCH' }, user.id, { ...config, currency: 'EGP' });
      assert.throws(() => orderInput({ ...body, paymentMethod: 'PAYMOB_CARD' }, { ...config, paymob: { enabled: true, methods: { PAYMOB_CARD: 1 } } }), { code: 'PAYMENTS_DISABLED' });
      assert.equal(await tx.orderItem.count({ where: { orderId: cod.id } }), itemCount);
      // Force a failure AFTER creating the order/items to verify transaction rollback.
      const failing = new Proxy(adapter, { get(target, key) {
        if (key === 'orderEvent') return { create: async () => { throw new Error('Synthetic event failure'); } };
        if (key === '$transaction') return action => target.$transaction(() => action(failing));
        return Reflect.get(target, key);
      } });
      await assert.rejects(createOrdersRepository(() => failing).create(user.id, orderInput({ ...body, clientRequestId: randomUUID() }, config), config), /Synthetic event failure/);
      assert.equal(await tx.order.count({ where: { userId: user.id } }), orderCount);
      // Editing/deleting addresses cannot change stored order snapshots or retries.
      await addresses.save(user.id, addressInput({ ...fields, city: 'Alexandria' }), first.id);
      await addresses.remove(user.id, first.id);
      assert.equal((await repo.detail(cod.id, user.id)).shippingSnapshot.city, 'Maadi');
      assert.equal((await repo.create(user.id, input, config)).id, cod.id);
      assert.equal((await repo.list(user.id)).orders[0].id, cod.id);
      await addresses.remove(user.id, second.id);
      assert.deepEqual(await addresses.list(user.id), []);
      assert.equal((await repo.detail(cod.id, user.id)).shippingSnapshot.buildingDetails, fields.buildingDetails);
      throw rollback;
    }, { timeout: 30000 });
  } catch (error) { if (error !== rollback) throw error; }
  assert.deepEqual(await counts(), before);
  console.log('Phase 3A PostgreSQL verification passed: address ownership/defaults, COD Pending/Unpaid, totals, snapshots, order persistence, idempotency, unavailable variants, currency checks and transaction rollback. All synthetic writes rolled back; existing counts unchanged.');
} catch (error) {
  console.error(`Phase 3A verification failed (${error.code ?? error.name}): ${error.message === 'Intentional verification rollback' ? 'unexpected rollback' : 'Check local migration, catalog and assertions. No private data printed.'}`);
  process.exitCode = 1;
} finally { await disconnectDatabase(); }
