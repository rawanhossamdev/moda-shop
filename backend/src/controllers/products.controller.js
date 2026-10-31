import { products as catalogOrder } from '../../prisma/catalog.js';
import { catalogQuery } from '../services/catalog-query.js';

// Preserve the existing editorial order without using mock data as API results.
const ranks = new Map(catalogOrder.map((product, index) => [product.id, index]));
import { sizeValues } from '../services/product-variants.js';
const sizeOrder = sizeValues;
function serialize(product) {
  return {
    id: product.id, name: product.name, image: product.image,
    priceInCents: product.priceInCents, currency: product.currency,
    category: product.category,
    isDemo: product.isDemo ?? false, isFeatured: product.isFeatured ?? false,
    defaultColorId: (product.colors ?? []).find(c => c.key === product.defaultColorKey)?.id ?? product.colors?.[0]?.id ?? null,
    colors: (product.colors ?? []).map(c => ({ id: c.id, key: c.key, name: c.name, hex: c.hex,
      images: (c.media ?? []).map(({ id, path, kind, label }) => ({ id, path, kind, label })) })),
    images: (product.media ?? []).filter(m => !m.colorId).map(({ id, path, kind, label }) => ({ id, path, kind, label })),
    variants: (product.variants ?? []).map(({ id, colorId, size, isAvailable, priceInCents }) => ({ id, colorId, size, isAvailable, priceInCents })),
    description: product.description ?? null, materials: product.materials ?? null,
    careInstructions: product.careInstructions ?? null, sizeAndFit: product.sizeAndFit ?? null,
    informationIsSample: product.informationIsSample ?? false,
    ...(product.createdAt ? { createdAt: new Date(product.createdAt).toISOString() } : {}),
    availableSizes: [...new Set(product.variants?.length ? product.variants.filter(v => v.isAvailable).map(v => v.size) : product.sizes.filter(s => s.isAvailable !== false).map(({ size }) => size))]
      .sort((a, b) => sizeOrder.indexOf(a) - sizeOrder.indexOf(b)),
  };
}
export function createProductsController(repository) {
  return {
    async categories(_request, response) {
      const data = await repository.categories();
      return response.json({ data, meta: { count: data.length, inventoryTracked: false } });
    },
    async list(request, response) {
      let filters;
      try { filters = catalogQuery(request.query); }
      catch (error) { return response.status(400).json({ error: { code: error.message, message: 'Check the catalog filters. Prices must be integer USD cents; stock filtering is not supported.' } }); }
      const rows = await repository.list(filters.category, filters);
      if (!filters.sort || filters.sort === 'featured') rows.sort((a, b) => (ranks.get(a.id) ?? Infinity) - (ranks.get(b.id) ?? Infinity) || a.name.localeCompare(b.name));
      const data = rows.map(serialize);
      return response.json({ data, meta: { count: data.length } });
    },
    async detail(request, response) {
      const { id } = request.params;
      if (!/^[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}$/.test(id)) {
        return response.status(400).json({ error: { code: 'INVALID_PRODUCT_ID', message: 'Product ID is invalid.' } });
      }
      const row = await repository.find(id);
      if (!row) return response.status(404).json({ error: { code: 'PRODUCT_NOT_FOUND', message: 'Product not found.' } });
      return response.json({ data: serialize(row) });
    },
  };
}

