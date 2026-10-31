import express from 'express';
import { createAddressesRepository } from './repositories/addresses.repository.js';
import { healthRouter } from './routes/health.routes.js';
import { notFound, errorHandler } from './middleware/errors.js';
import { createProductsRepository } from './repositories/products.repository.js';
import { createProductsRouter } from './routes/products.routes.js';
import { createAuthRepository } from './repositories/auth.repository.js';
import { createAuthRouter } from './routes/auth.routes.js';
import { createOrdersRepository } from './repositories/orders.repository.js';
import { createCommerceRouter } from './routes/commerce.routes.js';

export function createApp({ productsRepository = createProductsRepository(), authRepository = createAuthRepository(), authConfig, authLimiter, recoveryOptions, screenPassword,
  verificationOptions, addressesRepository = createAddressesRepository(), ordersRepository = createOrdersRepository(), commerceConfig, paymob } = {}) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '100kb' }));
  app.use('/api', healthRouter);
  app.use('/api/products', createProductsRouter(productsRepository));
  app.use('/api/auth', createAuthRouter(authRepository, authConfig, authLimiter, recoveryOptions, screenPassword, verificationOptions));
  app.use('/api', createCommerceRouter(authRepository, ordersRepository, { authConfig, commerceConfig, paymob, addressesRepository }));
  app.use(notFound);
  app.use(errorHandler);
  return app;
}

