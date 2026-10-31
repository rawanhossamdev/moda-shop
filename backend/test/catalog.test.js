import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { categories, products, sizes } from '../prisma/catalog.js';

test('Seed products retain original identities and use approved photorealistic assets', () => {
  const flutter = readFileSync(new URL('../../lib/data/products.dart', import.meta.url), 'utf8');
  const entries = [...flutter.matchAll(/Product\(([\s\S]*?)\)/g)].map(([, block]) => ({
    id: /id: '([^']+)'/.exec(block)[1],
    name: /name: '([^']+)'/.exec(block)[1],
    image: /image: '([^']+)'/.exec(block)[1],
    priceInCents: Number(/priceInCents: (\d+)/.exec(block)[1]),
    categorySlug: /category: ProductCategory\.(\w+)/.exec(block)[1],
    availableSizes: [...block.matchAll(/'((?:ONE_SIZE)|[SML])'/g)].map(m => m[1]),
  }));
  assert.deepEqual(products.slice(0,4).map(({id,name,priceInCents,categorySlug,availableSizes})=>({id,name,priceInCents,categorySlug,availableSizes})), entries.map(({image,...entry})=>entry));
  assert.equal(products.length,24);
  assert.equal(new Set(products.map(p=>p.id)).size,24);
  assert.deepEqual(categories.map(c=>c.slug), ['clothing','bags','shoes','jewelry','accessories']);
  assert.deepEqual(sizes, ['S', 'M', 'L']);
  for (const product of products) {
    assert.ok(categories.some((category) => category.slug === product.categorySlug));
    assert.ok(existsSync(new URL(`../../${product.image}`, import.meta.url)));
    assert.equal(product.isDemo,true);
    for (const color of product.colors) for (const image of color.images) {
      assert.ok(existsSync(new URL(`../../${image.path}`, import.meta.url)),image.path);
      assert.ok(image.kind==='ai_photo');
    }
    assert.equal(new Set(product.variants.map(v=>v.id)).size,product.variants.length);
  }
});

