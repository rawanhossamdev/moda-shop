import { createHmac, createHash, timingSafeEqual, randomBytes, createCipheriv, createDecipheriv } from 'node:crypto';
import { AuthError } from './auth.service.js';

const fields = ['amount_cents', 'created_at', 'currency', 'error_occured', 'has_parent_transaction', 'id', 'integration_id', 'is_3d_secure', 'is_auth', 'is_capture', 'is_refunded', 'is_standalone_payment', 'is_voided', 'order.id', 'owner', 'pending', 'source_data.pan', 'source_data.sub_type', 'source_data.type', 'success'];
export function callbackText(obj) {
  return fields.map((path) => {
    const value = path.split('.').reduce((item, key) => item?.[key], obj);
    // Fail closed for undocumented null/missing wallet fields; merchant sandbox
    // payloads must be validated before enabling that integration.
    if (!['string', 'number', 'boolean'].includes(typeof value)) throw new AuthError(401, 'INVALID_HMAC', 'Invalid payment signature.');
    return String(value);
  }).join('');
}
export function verifyCallback(body, signature, config) {
  if (!config.enabled) throw new AuthError(503, 'PAYMENTS_DISABLED', 'Online payments are disabled.');
  if (body?.type !== 'TRANSACTION' || typeof signature !== 'string' || !/^[a-f0-9]{128}$/i.test(signature)) throw new AuthError(401, 'INVALID_HMAC', 'Invalid payment signature.');
  const text = callbackText(body.obj);
  const expected = createHmac('sha512', config.hmacSecret).update(text).digest();
  if (!timingSafeEqual(expected, Buffer.from(signature, 'hex'))) throw new AuthError(401, 'INVALID_HMAC', 'Invalid payment signature.');
  const obj = body.obj;
  const flags = ['error_occured', 'has_parent_transaction', 'is_3d_secure', 'is_auth', 'is_capture', 'is_refunded', 'is_standalone_payment', 'is_voided', 'pending', 'success'];
  if (flags.some((key) => typeof obj[key] !== 'boolean') || !Number.isSafeInteger(obj.amount_cents) || obj.amount_cents < 0 ||
    !Object.values(config.methods).includes(obj.integration_id) || String(obj.owner) !== config.ownerId || obj.is_live === true ||
    !/^[0-9]+$/.test(String(obj.id)) || !/^[0-9]+$/.test(String(obj.order.id))) throw new AuthError(400, 'INVALID_PAYMENT_EVENT', 'Payment event does not match the test merchant.');
  const status = obj.pending ? 'PENDING' : obj.is_voided ? 'CANCELLED' :
    obj.success && !obj.error_occured && !obj.is_refunded && (!obj.is_auth || obj.is_capture) &&
      (!obj.has_parent_transaction || obj.is_capture) ? 'PAID' :
    obj.success && obj.is_auth ? 'PENDING' : 'FAILED';
  return { id: createHash('sha256').update(text).digest('hex'), transactionId: String(obj.id),
    providerOrderId: String(obj.order.id), integrationId: obj.integration_id,
    amount: obj.amount_cents, currency: obj.currency, status };
}

const key = (secret) => createHash('sha256').update(`moda-paymob-checkout:${secret}`).digest();
export function sealCheckout(url, secret) {
  const iv = randomBytes(12); const cipher = createCipheriv('aes-256-gcm', key(secret), iv);
  const data = Buffer.concat([cipher.update(url, 'utf8'), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), data]).toString('base64');
}
export function openCheckout(value, secret) {
  const bytes = Buffer.from(value, 'base64');
  const cipher = createDecipheriv('aes-256-gcm', key(secret), bytes.subarray(0, 12));
  cipher.setAuthTag(bytes.subarray(12, 28));
  return Buffer.concat([cipher.update(bytes.subarray(28)), cipher.final()]).toString('utf8');
}

export function createPaymobClient(send = fetch) {
  return {
    async create(order, user, attempt, config) {
      const names = order.shippingName.trim().split(/\s+/);
      const response = await send('https://accept.paymob.com/v1/intention/', {
        method: 'POST', signal: AbortSignal.timeout(10000),
        headers: { authorization: `Token ${config.secret}`, 'content-type': 'application/json' },
        body: JSON.stringify({ amount: order.totalInCents, currency: order.currency,
          payment_methods: [attempt.integrationId], special_reference: attempt.id,
          expiration: 900, notification_url: config.notificationUrl, redirection_url: config.returnUrl,
          items: [...order.items.map((item) => ({ name: item.productName, amount: item.unitPriceInCents, quantity: item.quantity })),
            ...(order.shippingFeeInCents ? [{ name: 'Shipping', amount: order.shippingFeeInCents, quantity: 1 }] : [])],
          billing_data: { first_name: names[0], last_name: names.slice(1).join(' ') || names[0],
            phone_number: order.shippingPhone, email: user.email, street: order.shippingAddress,
            city: order.shippingCity, state: order.shippingCity, country: 'EGY' },
        }),
      });
      // Even a timeout/error can be ambiguous. Never automatically retry an
      // intention POST: it could create a second chargeable checkout.
      if (response.status !== 201) throw new Error('Payment creation not confirmed.');
      const value = await response.json();
      if (typeof value.id !== 'string' || !/^csk_test_/.test(value.client_secret ?? '') ||
        !Number.isSafeInteger(value.intention_order_id)) throw new Error('Invalid test intention response.');
      const url = new URL('https://accept.paymob.com/unifiedcheckout/');
      url.searchParams.set('publicKey', config.publicKey); url.searchParams.set('clientSecret', value.client_secret);
      return { intentionId: value.id, providerOrderId: String(value.intention_order_id), url: url.toString() };
    },
  };
}
