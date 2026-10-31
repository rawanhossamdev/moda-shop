import { getDatabase } from '../config/database.js';

const select = {
  isDemo: true, isFeatured: true, defaultColorKey: true,
  variants: { orderBy: [{ size: 'asc' }, { id: 'asc' }] },
  colors: { orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }], include: { media: { where: { kind: { notIn: ['archived_art', 'archived_photo'] } }, orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] } } },
  media: { where: { kind: { notIn: ['archived_art', 'archived_photo'] } }, orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] },
  description: true, materials: true, careInstructions: true, sizeAndFit: true, informationIsSample: true,
  id: true, name: true, image: true, priceInCents: true, currency: true, createdAt: true,
  category: { select: { id: true, name: true, slug: true } },
  sizes: { where: { isAvailable: true }, select: { size: true } },
};
export function createProductsRepository(database = getDatabase) {
  return {
    categories() {
      return database().category.findMany({ select: { id: true, name: true, slug: true }, orderBy: [{ name: 'asc' }, { id: 'asc' }] });
    },
    list(category, filters = {}) {
      return database().product.findMany({
        where: {
          isActive: true,
          ...(filters.search ? { name: { contains: filters.search, mode: 'insensitive' } } : {}),
          ...(filters.size ? { OR: [{ variants: { some: { size: filters.size, isAvailable: true } } }, { variants: { none: {} }, sizes: { some: { size: filters.size, isAvailable: true } } }] } : {}),
          ...(filters.minPrice !== undefined || filters.maxPrice !== undefined ? { priceInCents: {
            ...(filters.minPrice !== undefined ? { gte: filters.minPrice } : {}),
            ...(filters.maxPrice !== undefined ? { lte: filters.maxPrice } : {}),
          } } : {}),
          ...(category ? { category: { is: { OR: [
            { name: { equals: category, mode: 'insensitive' } },
            { slug: { equals: category, mode: 'insensitive' } },
          ] } } } : {}),
        },
        select, orderBy: filters.sort === 'price_asc' ? [{ priceInCents: 'asc' }, { id: 'asc' }]
          : filters.sort === 'price_desc' ? [{ priceInCents: 'desc' }, { id: 'asc' }]
          : filters.sort === 'name' ? [{ name: 'asc' }, { id: 'asc' }]
          : filters.sort === 'newest' ? [{ createdAt: 'desc' }, { id: 'asc' }]
          : [{ createdAt: 'asc' }, { id: 'asc' }],
      });
    },
    find(id) {
      return database().product.findFirst({ where: { id, isActive: true }, select });
    },
  };
}

