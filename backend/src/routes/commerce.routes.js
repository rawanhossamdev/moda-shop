import { Router } from 'express';
import { addressInput } from '../services/address.service.js';
import { AuthError, createAuthService } from '../services/auth.service.js';
import { requireVerified, cartInput, orderInput, uuid } from '../services/checkout.service.js';
import { readCommerceConfig } from '../config/commerce.js';
import { verifyCallback } from '../services/paymob.js';
import { authRateLimit } from '../middleware/auth-rate-limit.js';

export function createCommerceRouter(authRepository, repository, { authConfig, commerceConfig = readCommerceConfig, addressesRepository } = {}) {
  const router = Router();
  const auth = createAuthService(authRepository, authConfig);
  const settings = () => { try { return commerceConfig(); } catch { throw new AuthError(503, 'CHECKOUT_UNAVAILABLE', 'Checkout configuration is unavailable.'); } };
  router.use((_req, res, next) => { res.set('Cache-Control', 'no-store'); next(); });
  router.post('/payments/paymob/webhook', async (req, res) => {
    const event = verifyCallback(req.body, req.query.hmac, settings().paymob);
    await repository.callback(event);
    res.json({ data: { received: true } });
  });
  // Redirect parameters are deliberately ignored; they never mutate orders.
  router.get('/payments/paymob/return', (_req, res) => {
    res.type('text').send('Return to MODA and refresh your order. Payment is confirmed only by a verified server callback.');
  });
  router.use(['/checkout', '/orders', '/addresses'], async (req, _res, next) => { req.user = await auth.authenticate(req.get('authorization')); next(); });
  const addressId = (req) => {
    if (!uuid(req.params.id)) throw new AuthError(400, 'INVALID_ADDRESS', 'Invalid address identifier.');
    return req.params.id;
  };
  router.get('/addresses', async (req, res) => res.json({ data: { addresses: await addressesRepository.list(req.user.id) } }));
  router.post('/addresses', async (req, res) => res.status(201).json({ data: { address: await addressesRepository.save(req.user.id, addressInput(req.body)) } }));
  router.put('/addresses/:id', async (req, res) => res.json({ data: { address: await addressesRepository.save(req.user.id, addressInput(req.body), addressId(req)) } }));
  router.delete('/addresses/:id', async (req, res) => res.json({ data: await addressesRepository.remove(req.user.id, addressId(req)) }));
  router.get('/checkout/config', (_req, res) => {
    const config = settings();
    res.json({ data: { currency: config.currency, shippingFeeInCents: config.shippingFeeInCents,
      paymentMethods: ['COD'], testMode: true,
      shippingFeeLabel: 'Configured shipping fee (placeholder; no carrier rates)',
      onlinePaymentMessage: 'Cash on Delivery only. Payment is due when your order is delivered.' } });
  });
  router.post('/checkout/quote', async (req, res) => {
    requireVerified(req.user);
    res.json({ data: await repository.quote(cartInput(req.body?.items), settings()) });
  });
  const limiter = authRateLimit({ limit: 40 });
  router.post('/orders', limiter, async (req, res) => {
    requireVerified(req.user);
    const config = settings();
    res.status(201).json({ data: { order: await repository.create(req.user.id, orderInput(req.body, config), config) } });
  });
  router.get('/orders', async (req, res) => {
    if (req.query.cursor !== undefined && !uuid(req.query.cursor)) throw new AuthError(400, 'INVALID_ORDER', 'Invalid order cursor.');
    res.json({ data: await repository.list(req.user.id, req.query.cursor) });
  });
  const id = (req) => { if (!uuid(req.params.id)) throw new AuthError(400, 'INVALID_ORDER', 'Invalid order identifier.'); return req.params.id; };
  router.get('/orders/request/:requestId', async (req, res) => {
    if (!uuid(req.params.requestId)) throw new AuthError(400, 'INVALID_REQUEST_ID', 'Invalid checkout request identifier.');
    res.json({ data: { order: await repository.findRequest(req.user.id, req.params.requestId) } });
  });
  router.get('/orders/:id', async (req, res) => { res.json({ data: { order: await repository.detail(id(req), req.user.id) } }); });
  router.post('/orders/:id/cancel', limiter, async (req, res) => { res.json({ data: { order: await repository.cancel(id(req), req.user.id) } }); });
  router.post('/orders/:id/payment', limiter, async (req, res) => {
    throw new AuthError(503, 'PAYMENTS_DISABLED', 'Online payments are unavailable in this phase.');
  });
  router.use((error, _req, res, next) => {
    if (!(error instanceof AuthError)) return next(error);
    if (error.status === 401) res.set('WWW-Authenticate', 'Bearer');
    res.status(error.status).json({ error: { code: error.code, message: error.message } });
  });
  return router;
}
