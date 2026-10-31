import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createApp } from '../src/app.js';
import { createProductsRepository } from '../src/repositories/products.repository.js';
import { products, sizes, categories } from '../prisma/catalog.js';

const fixtures = products.map(({ categorySlug, availableSizes, ...product }) => ({
  ...product, currency: 'USD', isActive: true,
  category: { id: categorySlug, slug: categorySlug, name: categories.find(c => c.slug === categorySlug).name },
  colors: product.colors.map(c => ({...c, media: c.images})),
  sizes: availableSizes.map((size) => ({ size })),
}));
async function serve(t, repository) {
  const server = createApp({ productsRepository: repository }).listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return (path) => fetch(`http://127.0.0.1:${server.address().port}/api/products${path}`);
}
function repositoryFixture() {
  return createProductsRepository(() => ({ product: {
    async findMany(query) {
      assert.equal(query.where.isActive, true);
      let rows = [...fixtures];
      if (query.where.category) {
        const filters = query.where.category.is.OR;
        assert.equal(filters[0].name.mode, 'insensitive');
        const category = filters[0].name.equals.toLowerCase();
        rows = rows.filter((row) => row.category.name.toLowerCase() === category || row.category.slug === category);
      }
      if (query.where.name) rows = rows.filter((r) => r.name.toLowerCase().includes(query.where.name.contains.toLowerCase()));
      if (query.where.priceInCents) rows = rows.filter((r) => r.priceInCents >= (query.where.priceInCents.gte ?? 0) && r.priceInCents <= (query.where.priceInCents.lte ?? Infinity));
      if (query.where.OR) rows = rows.filter(r => r.variants.some(v => v.isAvailable && v.size === query.where.OR[0].variants.some.size));
      const order = query.orderBy[0];
      if (order.priceInCents) rows.sort((a,b) => (a.priceInCents - b.priceInCents) * (order.priceInCents === 'asc' ? 1 : -1));
      if (order.name) rows.sort((a,b) => a.name.localeCompare(b.name));
      return rows;
    },
    async findFirst(query) {
      assert.equal(query.where.isActive, true);
      return fixtures.find((row) => row.id === query.where.id) ?? null;
    },
  }, category: { async findMany(query) { assert.deepEqual(query.select, { id: true, name: true, slug: true }); return categories.map(c => ({...c, id:c.slug})); } } }));
}
test('Lists active products with explicit category, sizes, asset identifiers and integer prices', async (t) => {
  const get = await serve(t, repositoryFixture());
  const response = await get('');
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.meta.count, 24);
  assert.deepEqual(body.data.map((row) => row.id), products.map((row) => row.id));
  assert.deepEqual(body.data.map((row) => row.priceInCents), products.map(p => p.priceInCents));
  for (const row of body.data) {
    assert.equal(row.currency, 'USD');
    assert.ok(Number.isInteger(row.priceInCents));
    assert.ok(row.image.startsWith('assets/images/'));
    assert.deepEqual(row.availableSizes, products.find(p => p.id === row.id).availableSizes);
    assert.equal('isActive' in row, false);
  }
  assert.equal((await get('/')).status, 200);
});
test('Filters by case-insensitive category name or slug; unknown categories are empty', async (t) => {
  const get = await serve(t, repositoryFixture());
  assert.equal((await (await get('?category=Clothing')).json()).data.length, 8);
  assert.equal((await (await get('?category=cLoThInG')).json()).data.length, 8);
  assert.deepEqual((await (await get('?category=accessories')).json()).data.map((row) => row.id), products.filter(p=>p.categorySlug==='accessories').map(p=>p.id));
  assert.deepEqual((await (await get('?category=unknown')).json()).data, []);
});
test('Rejects malformed category filters', async (t) => {
  const get = await serve(t, repositoryFixture());
  for (const path of ['?category=', '?category=a&category=b', '?category=' + 'a'.repeat(81)]) {
    const response = await get(path);
    assert.equal(response.status, 400);
    assert.equal((await response.json()).error.code, 'INVALID_CATEGORY');
  }
});

test('Search is partial and case-insensitive, composes with category/cents/size and sorts by database price/name', async (t) => {
  const get = await serve(t, repositoryFixture());
  assert.deepEqual((await (await get('?search=KNIT')).json()).data.map(p => p.id), ['knit-sweater']);
  assert.equal((await (await get('?search=doesnotexist')).json()).data.length, 0);
  assert.deepEqual((await (await get('?category=clothing&minPrice=5000&maxPrice=9000&size=M&sort=price_desc')).json()).data.map(p => p.priceInCents), products.filter(p=>p.categorySlug==='clothing' && p.priceInCents>=5000 && p.priceInCents<=9000).map(p=>p.priceInCents).sort((a,b)=>b-a));
  assert.deepEqual((await (await get('?sort=price_asc')).json()).data.map(p => p.priceInCents), products.map(p=>p.priceInCents).sort((a,b)=>a-b));
  const names = (await (await get('?sort=name')).json()).data.map(p => p.name);
  assert.deepEqual(names, [...names].sort((a,b) => a.localeCompare(b)));
  assert.equal((await (await get('?size=ONE_SIZE')).json()).data.length, 12);
});

test('Rejects unsafe, repeated, unsupported, reversed and non-integer filters', async (t) => {
  const get = await serve(t, repositoryFixture());
  for (const query of ['search=a&search=b', 'search=', 'search='+'a'.repeat(161), 'size=XL', 'sort=random', 'minPrice=-1', 'minPrice=1.5', 'maxPrice=2147483648', 'minPrice=6000&maxPrice=3000', 'inStock=true', 'search[x]=x']) {
    assert.equal((await get('?'+query)).status, 400, query);
  }
});

test('Categories are database backed and routed before product ID matching', async (t) => {
  const get = await serve(t, repositoryFixture());
  const response = await get('/categories');
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.deepEqual(body.data.map(c => c.name), categories.map(c=>c.name));
  assert.equal(body.meta.inventoryTracked, false);
});

test('Newest sorting uses stored creation dates and a stable ID tie breaker', async () => {
  let seen;
  const repo = createProductsRepository(() => ({ product: { findMany(query) { seen = query; return []; } } }));
  await repo.list(undefined, { sort: 'newest', search: 'Knit', size: 'M', minPrice: 0, maxPrice: 6500 });
  assert.deepEqual(seen.orderBy, [{ createdAt: 'desc' }, { id: 'asc' }]);
  assert.deepEqual(seen.where.name, { contains: 'Knit', mode: 'insensitive' });
  assert.deepEqual(seen.where.priceInCents, { gte: 0, lte: 6500 });
  assert.deepEqual(seen.where.OR[0], { variants: { some: { size: 'M', isAvailable: true } } });
});
test('Returns selected product detail; unavailable IDs are 404 and malformed IDs are 400', async (t) => {
  const get = await serve(t, repositoryFixture());
  const detail = await get('/shoulder-bag');
  assert.equal(detail.status, 200);
  const body = await detail.json();
  assert.equal(body.data.name, 'Shoulder Bag');
  assert.equal(body.data.priceInCents, 6500);
  assert.equal(body.data.category.slug, 'bags');
  assert.equal((await get('/missing-product')).status, 404);
  assert.equal((await get('/bad%20id')).status, 400);
  assert.equal((await get('/' + 'a'.repeat(81))).status, 400);
});
test('Does not disclose database failures', async (t) => {
  const get = await serve(t, { list: async () => { throw new Error('private database connection details'); } });
  const response = await get('');
  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), { error: { code: 'INTERNAL_ERROR', message: 'Internal server error' } });
});
test('Queries exclude inactive products for both listing and detail', async () => {
  let seen = 0;
  const repo = createProductsRepository(() => ({ product: {
    async findMany({ where }) { assert.deepEqual(where, { isActive: true }); seen++; return []; },
    async findFirst({ where }) { assert.deepEqual(where, { id: 'archived', isActive: true }); seen++; return null; },
  } }));
  assert.deepEqual(await repo.list(), []);
  assert.equal(await repo.find('archived'), null);
  assert.equal(seen, 2);
});



test('Optional product information is mapped from stored fields and explicitly labels sample content', async t => {
  const product = { ...fixtures[3], description: 'Portfolio sample.', materials: 'Composition not verified.',
    careInstructions: 'Follow the actual care label.', sizeAndFit: 'One Size; dimensions not verified.', informationIsSample: true };
  const get = await serve(t, { async find() { return product; } });
  const result = (await (await get('/shoulder-bag')).json()).data;
  assert.equal(result.description, product.description);
  assert.equal(result.materials, product.materials);
  assert.equal(result.careInstructions, product.careInstructions);
  assert.equal(result.sizeAndFit, product.sizeAndFit);
  assert.equal(result.informationIsSample, true);
  assert.deepEqual(result.availableSizes, ['ONE_SIZE']);
});
