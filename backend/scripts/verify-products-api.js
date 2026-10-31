import assert from 'node:assert/strict';
import {products as seeded, categories as seededCategories} from '../prisma/catalog.js';
import { once } from 'node:events';
import { spawn } from 'node:child_process';
import { createApp } from '../src/app.js';
import { disconnectDatabase } from '../src/config/database.js';

let server;
try {
  server = createApp().listen(0, '127.0.0.1');
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}/api`;
  async function get(path, status = 200) {
    const response = await fetch(base + path, { signal: AbortSignal.timeout(10000) });
    assert.equal(response.status, status);
    return response.json();
  }
  const all = await get('/products');
  assert.ok(all.data.length >= 24);
  for (const product of seeded) assert.ok(all.data.some(p=>p.id===product.id));
  for (const category of seededCategories) {
    const filtered = await get(`/products?category=${category.slug}`);
    assert.ok(filtered.data.length >= seeded.filter(p=>p.categorySlug===category.slug).length);
    assert.ok(filtered.data.every(p=>p.category.slug===category.slug));
  }
  const categories = await get('/products/categories');
  for (const category of seededCategories) assert.ok(categories.data.some(c=>c.slug===category.slug));
  assert.equal(categories.meta.inventoryTracked, false);
  assert.deepEqual((await get('/products?search=KNIT')).data.map(p => p.id), ['knit-sweater']);
  const combined = (await get('/products?category=clothing&minPrice=5000&maxPrice=9000&size=M&sort=price_desc')).data;
  assert.ok(combined.length > 0);
  assert.ok(combined.every(p=>p.category.slug==='clothing' && p.priceInCents>=5000 && p.priceInCents<=9000 && p.availableSizes.includes('M')));
  const prices = (await get('/products?sort=price_asc')).data.map(p=>p.priceInCents);
  assert.deepEqual(prices,[...prices].sort((a,b)=>a-b));
  const newest = await get('/products?sort=newest');
  for (let i = 1; i < newest.data.length; i++) assert.ok(Date.parse(newest.data[i-1].createdAt) >= Date.parse(newest.data[i].createdAt));
  assert.equal((await get('/products?search=not-a-product')).data.length, 0);
  await get('/products?minPrice=6000&maxPrice=3000', 400);
  assert.equal((await get('/products/shoulder-bag')).data.priceInCents, 6500);
  assert.deepEqual((await get('/products/shoulder-bag')).data.availableSizes, ['ONE_SIZE']);
  assert.ok((await get('/products?size=ONE_SIZE')).data.length >= 12);
  const shoes=(await get('/products?category=shoes&size=EU_38')).data;
  assert.equal(shoes.length,4);
  const bag=(await get('/products/shoulder-bag')).data;
  assert.equal(bag.colors.find(c=>c.key==='brown').images.length,1);
  assert.ok(bag.variants.every(v=>v.id));
  assert.ok(!(await get('/products?size=M')).data.some(p => p.id === 'shoulder-bag'));
  await get('/products/missing-product', 404);
  await get('/products/bad%20id', 400);
  assert.equal((await get('/health')).status, 'ok');
  console.log('Read-only PostgreSQL-backed API verified: search, dynamic categories, combined filters, price/newest sorting, details, invalid queries and health.');
  const dartExecutable = process.argv[2];
  if (dartExecutable) {
    const child = spawn(dartExecutable, ['run', 'tool/verify_products_api.dart', base], {
      cwd: new URL('../../', import.meta.url), stdio: 'inherit',
    });
    const [code] = await once(child, 'exit');
    assert.equal(code, 0, 'Live Dart client verification failed.');
  }
} catch (error) {
  console.error('Live API verification failed (' + (error.code ?? error.name) + '). No database credentials displayed.');
  process.exitCode = 1;
} finally {
  if (server?.listening) await new Promise((resolve) => server.close(resolve));
  await disconnectDatabase();
}

