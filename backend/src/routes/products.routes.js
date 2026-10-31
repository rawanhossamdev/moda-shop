import { Router } from 'express';
import { createProductsController } from '../controllers/products.controller.js';

export function createProductsRouter(repository) {
  const router = Router();
  const controller = createProductsController(repository);
  router.get('/', controller.list);
  router.get('/categories', controller.categories);
  router.get('/:id', controller.detail);
  return router;
}

