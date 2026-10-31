import { addressSnapshot } from '../services/address.service.js';
import { missingAddress } from './addresses.repository.js';
import { getDatabase } from '../config/database.js';
import { AuthError } from '../services/auth.service.js';
import { calculateQuote } from '../services/checkout.service.js';

export const publicOrder = (order) => ({
  id: order.id, status: order.status, currency: order.currency,
  subtotalInCents: order.subtotalInCents, shippingFeeInCents: order.shippingFeeInCents,
  totalInCents: order.totalInCents, paymentMethod: order.paymentMethod, paymentStatus: order.paymentStatus,
  shippingName: order.shippingName, shippingPhone: order.shippingPhone, shippingAddress: order.shippingAddress,
  shippingCity: order.shippingCity, shippingSnapshot: order.shippingSnapshot, deliveryNotes: order.deliveryNotes, createdAt: order.createdAt,
  items: order.items.map(({ productId, productName, productImage, variantId, colorId, colorName, size, unitPriceInCents, quantity }) => ({ productId, productName, productImage, variantId, colorId, colorName, size, unitPriceInCents, quantity })),
});
const include = { items: true };
const missing = () => new AuthError(404, 'ORDER_NOT_FOUND', 'This order is not available.');
export function createOrdersRepository(database = getDatabase) {
  const owned = async (tx, id, userId) => {
    const value = await tx.order.findFirst({ where: { id, userId }, include });
    if (!value) throw missing();
    return value;
  };
  return {
    async quote(items, config) {
      const products = await database().product.findMany({ where: { id: { in: items.map((item) => item.productId) } }, include: { sizes: true, variants: true, colors: { orderBy: { sortOrder: 'asc' }, include: { media: { where: { kind: { notIn: ['archived_art', 'archived_photo'] } }, orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] } } }, media: { where: { kind: { notIn: ['archived_art', 'archived_photo'] } }, orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] } } });
      return calculateQuote(items, products, config);
    },
    async create(userId, input, config) {
      const existing = await database().order.findUnique({ where: { userId_clientRequestId: { userId, clientRequestId: input.clientRequestId } }, include });
      const check = (value) => {
        if (value.requestHash !== input.requestHash) throw new AuthError(409, 'REQUEST_CONFLICT', 'This request already placed a different order. Check your order history.');
        return publicOrder(value);
      };
      if (existing) return check(existing);
      try {
        return await database().$transaction(async (tx) => {
          // Serialize the same account/request before validation as well as insertion.
          // A retry cannot reject changed catalog data while an earlier copy commits.
          await tx.$queryRaw`SELECT 1 AS locked FROM pg_advisory_xact_lock(hashtextextended(${userId + ':' + input.clientRequestId}, 0))`;
          const committed = await tx.order.findUnique({ where: { userId_clientRequestId: { userId, clientRequestId: input.clientRequestId } }, include });
          if (committed) return check(committed);
          const products = await tx.product.findMany({ where: { id: { in: input.items.map((item) => item.productId) } }, include: { sizes: true, variants: true, colors: { orderBy: { sortOrder: 'asc' }, include: { media: { where: { kind: { notIn: ['archived_art', 'archived_photo'] } }, orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] } } }, media: { where: { kind: { notIn: ['archived_art', 'archived_photo'] } }, orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] } } });
          const quote = calculateQuote(input.items, products, config);
          if (quote.totalInCents !== input.expectedTotalInCents) throw new AuthError(409, 'PRICE_CHANGED', 'Your order total changed. Review the updated summary before confirming.');
          const address = await tx.shippingAddress.findFirst({ where: { id: input.addressId, userId } });
          if (!address) throw missingAddress();
          const shippingSnapshot = addressSnapshot(address);
          const { clientRequestId, requestHash, paymentMethod } = input;
          const cod = paymentMethod === 'COD';
          const order = await tx.order.create({ data: {
            userId, clientRequestId, requestHash, paymentMethod, shippingSnapshot,
            shippingName: address.fullName, shippingPhone: address.mobile, shippingAddress: address.streetAddress,
            shippingCity: address.city, deliveryNotes: address.deliveryNotes,
            currency: quote.currency, subtotalInCents: quote.subtotalInCents, shippingFeeInCents: quote.shippingFeeInCents,
            totalInCents: quote.totalInCents, status: 'PENDING', paymentStatus: cod ? 'UNPAID' : 'PENDING',
            items: { create: quote.items },
          }, include });
          if (cod) await tx.orderEvent.create({ data: { orderId: order.id, eventKey: `cod:${order.id}`, kind: 'COD_PLACED' } });
          return publicOrder(order);
        });
      } catch (error) {
        if (error.code !== 'P2002') throw error;
        const duplicate = await database().order.findUnique({ where: { userId_clientRequestId: { userId, clientRequestId: input.clientRequestId } }, include });
        if (!duplicate) throw error;
        return check(duplicate);
      }
    },
    async list(userId, cursor) {
      if (cursor) await owned(database(), cursor, userId);
      const values = await database().order.findMany({ where: { userId }, include,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], take: 21,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}) });
      return { orders: values.slice(0, 20).map(publicOrder), nextCursor: values.length > 20 ? values[19].id : null };
    },
    async findRequest(userId, clientRequestId) {
      const order = await database().order.findUnique({ where: { userId_clientRequestId: { userId, clientRequestId } }, include });
      if (!order) throw missing();
      return publicOrder(order);
    },
    async detail(id, userId) { return publicOrder(await owned(database(), id, userId)); },
    async cancel(id, userId) {
      return database().$transaction(async (tx) => {
        await tx.$queryRaw`SELECT "id" FROM "Order" WHERE "id" = ${id}::uuid FOR UPDATE`;
        const order = await owned(tx, id, userId);
        const active = await tx.paymentAttempt.count({ where: { orderId: id, status: { in: ['PENDING', 'UNKNOWN', 'PAID'] } } });
        if (active || order.paymentStatus === 'PAID' || !['PENDING', 'CONFIRMED', 'CANCELLED'].includes(order.status)) throw new AuthError(409, 'CANNOT_CANCEL', 'This order cannot be cancelled while payment or fulfilment is in progress.');
        return publicOrder(await tx.order.update({ where: { id }, data: { status: 'CANCELLED', paymentStatus: 'CANCELLED' }, include }));
      });
    },
    async reservePayment(id, userId, integrationId) {
      return database().$transaction(async (tx) => {
        await tx.$queryRaw`SELECT "id" FROM "Order" WHERE "id" = ${id}::uuid FOR UPDATE`;
        const order = await owned(tx, id, userId);
        if (order.status === 'CANCELLED' || order.paymentMethod === 'COD' || order.paymentStatus === 'PAID') throw new AuthError(409, 'PAYMENT_UNAVAILABLE', 'This order does not need an online payment.');
        const previous = await tx.paymentAttempt.findFirst({ where: { orderId: id }, orderBy: { createdAt: 'desc' } });
        if (previous) return { order, attempt: previous, fresh: false };
        const attempt = await tx.paymentAttempt.create({ data: { orderId: id, integrationId, expiresAt: new Date(Date.now() + 15 * 60000) } });
        return { order, attempt, fresh: true };
      });
    },
    savePayment(id, data) { return database().paymentAttempt.update({ where: { id }, data }); },
    async paymentUnknown(id) {
      await database().$transaction(async (tx) => {
        const attempt = await tx.paymentAttempt.update({ where: { id }, data: { status: 'UNKNOWN' } });
        await tx.order.updateMany({ where: { id: attempt.orderId, paymentStatus: 'PENDING' }, data: { paymentStatus: 'UNKNOWN' } });
      });
    },
    async callback(event) {
      try {
        return await database().$transaction(async (tx) => {
          const attempt = await tx.paymentAttempt.findUnique({ where: { providerOrderId: event.providerOrderId } });
          if (!attempt) throw new AuthError(503, 'PAYMENT_NOT_LINKED', 'Payment has not been linked yet. Retry the callback.');
          await tx.$queryRaw`SELECT "id" FROM "Order" WHERE "id" = ${attempt.orderId}::uuid FOR UPDATE`;
          const order = await tx.order.findUnique({ where: { id: attempt.orderId } });
          if (attempt.integrationId !== event.integrationId || order.currency !== event.currency || order.totalInCents !== event.amount) throw new AuthError(400, 'PAYMENT_MISMATCH', 'Payment amount, currency or integration does not match.');
          await tx.paymentEvent.create({ data: { id: event.id, attemptId: attempt.id, transactionId: event.transactionId, status: event.status } });
          // A late pending/failure callback must never undo an established paid state.
          const current = await tx.paymentAttempt.findUnique({ where: { id: attempt.id } });
          if (order.paymentStatus === 'PAID' || (event.status === 'PENDING' && ['FAILED', 'CANCELLED'].includes(current.status))) return;
          await tx.paymentAttempt.update({ where: { id: attempt.id }, data: { status: event.status } });
          await tx.order.update({ where: { id: order.id }, data: {
            paymentStatus: event.status,
            ...(event.status === 'PAID' && order.status !== 'CANCELLED' ? { status: 'CONFIRMED' } : {}),
            ...(event.status === 'CANCELLED' ? { status: 'CANCELLED' } : {}),
          } });
          if (event.status === 'PAID') await tx.orderEvent.upsert({ where: { eventKey: `paid:${order.id}` }, update: {},
            create: { orderId: order.id, eventKey: `paid:${order.id}`, kind: order.status === 'CANCELLED' ? 'PAYMENT_REVIEW' : 'PAYMENT_CONFIRMED' } });
        });
      } catch (error) {
        if (error.code !== 'P2002') throw error; // duplicate signed event = committed no-op
      }
    },
  };
}
