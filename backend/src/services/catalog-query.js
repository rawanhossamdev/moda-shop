import { sizeValues } from './product-variants.js';
const sizes = new Set(sizeValues);
const sorts = new Set(['featured', 'price_asc', 'price_desc', 'name', 'newest']);
export function catalogQuery(query) {
  const result = {};
  for (const key of Object.keys(query)) {
    if (!['category', 'search', 'minPrice', 'maxPrice', 'size', 'sort'].includes(key)) throw new Error('INVALID_FILTER');
    const value = query[key];
    if (typeof value !== 'string' || !value.trim()) throw new Error(key === 'category' ? 'INVALID_CATEGORY' : 'INVALID_FILTER');
    result[key] = value.trim();
  }
  if (result.category?.length > 80) throw new Error('INVALID_CATEGORY');
  if (result.search?.length > 160) throw new Error('INVALID_FILTER');
  for (const key of ['minPrice', 'maxPrice']) {
    if (result[key] !== undefined) {
      if (!/^\d{1,10}$/.test(result[key]) || Number(result[key]) > 2147483647) throw new Error('INVALID_FILTER');
      result[key] = Number(result[key]);
    }
  }
  if (result.minPrice !== undefined && result.maxPrice !== undefined && result.minPrice > result.maxPrice) throw new Error('INVALID_FILTER');
  if (result.size && !sizes.has(result.size)) throw new Error('INVALID_FILTER');
  if (result.sort && !sorts.has(result.sort)) throw new Error('INVALID_FILTER');
  return result;
}
