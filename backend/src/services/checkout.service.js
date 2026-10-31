import { createHash } from 'node:crypto';
import { resolveVariant, sizeValues } from './product-variants.js';
import { AuthError } from './auth.service.js';

export const uuid = (value) => typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
export function requireVerified(user) {
  if (!user.emailVerifiedAt) throw new AuthError(403, 'EMAIL_NOT_VERIFIED', 'Please verify your email before checkout.');
}
export function cartInput(value) {
  if (!Array.isArray(value) || !value.length || value.length > 40) throw new AuthError(400, 'INVALID_CART', 'Your cart must contain 1 to 40 pieces.');
  const keys = new Set();
  return value.map((item) => {
    if (!item || typeof item.productId !== 'string' || !/^[a-zA-Z0-9_-]{1,80}$/.test(item.productId) ||
      !sizeValues.includes(item.size) || !Number.isInteger(item.quantity) || item.quantity < 1 || item.quantity > 20) throw new AuthError(400, 'INVALID_CART', 'Choose valid sizes and quantities from 1 to 20.');
    if ((item.variantId !== undefined && (typeof item.variantId !== 'string' || !/^[a-zA-Z0-9:_-]{1,160}$/.test(item.variantId))) ||
      (item.colorId !== undefined && (typeof item.colorId !== 'string' || !/^[a-zA-Z0-9:_-]{1,160}$/.test(item.colorId) || !item.variantId))) throw new AuthError(400, 'INVALID_CART', 'Choose a valid product variant.');
    const key = `${item.productId}:${item.variantId ?? item.size}`;
    if (keys.has(key)) throw new AuthError(400, 'INVALID_CART', 'Combine matching products and sizes before checkout.');
    keys.add(key);
    return { productId: item.productId, size: item.size, quantity: item.quantity, ...(item.variantId ? { variantId: item.variantId } : {}), ...(item.colorId ? { colorId: item.colorId } : {}) };
  }).sort((a, b) => `${a.productId}:${a.variantId ?? a.size}`.localeCompare(`${b.productId}:${b.variantId ?? b.size}`));
}
export function calculateQuote(items, products, config) {
  let subtotalInCents = 0;
  const resolvedKeys = new Set();
  const lines = items.map((item) => {
    const product = products.find((p) => p.id === item.productId && p.isActive);
    const selection = resolveVariant(product, item);
    const resolvedKey = `${item.productId}:${selection.variantId ?? item.size}`;
    if (resolvedKeys.has(resolvedKey)) throw new AuthError(400, 'INVALID_CART', 'Combine matching product variants before checkout.');
    resolvedKeys.add(resolvedKey);
    if (product.currency !== config.currency) throw new AuthError(409, 'CURRENCY_MISMATCH', 'The store currency has changed. Checkout is unavailable until catalog pricing is configured.');
    if (!Number.isInteger(selection.unitPriceInCents) || selection.unitPriceInCents < 0) throw new AuthError(409, 'CART_UNAVAILABLE', 'Product pricing is unavailable.');
    subtotalInCents += selection.unitPriceInCents * item.quantity;
    return { ...item, productName: product.name, ...selection };
  });
  const totalInCents = subtotalInCents + config.shippingFeeInCents;
  if (!Number.isSafeInteger(totalInCents) || totalInCents > 2147483647) throw new AuthError(400, 'INVALID_TOTAL', 'Please reduce the quantity in your cart.');
  return { currency: config.currency, subtotalInCents, shippingFeeInCents: config.shippingFeeInCents, totalInCents, items: lines };
}
export function orderInput(body, config) {
  if (!uuid(body?.clientRequestId)) throw new AuthError(400, 'INVALID_REQUEST_ID', 'A valid checkout request identifier is required.');
  const paymentMethod = body.paymentMethod;
  if (paymentMethod !== 'COD') throw new AuthError(503, 'PAYMENTS_DISABLED', 'This payment method is not configured. Please use Cash on Delivery.');
  if (!Number.isSafeInteger(body.expectedTotalInCents) || body.expectedTotalInCents < 0) throw new AuthError(400, 'INVALID_TOTAL', 'Review your order total before placing it.');
  if (!uuid(body?.addressId)) throw new AuthError(400, 'INVALID_ADDRESS', 'Choose a saved shipping address.');
  const data = { items: cartInput(body.items), addressId: body.addressId, paymentMethod,
    expectedTotalInCents: body.expectedTotalInCents };
  return { ...data, clientRequestId: body.clientRequestId,
    requestHash: createHash('sha256').update(JSON.stringify(data)).digest('hex') };
}
