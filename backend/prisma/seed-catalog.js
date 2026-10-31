import { categories, products } from './catalog.js';

// Shared by the real seed and rollback-only idempotency checks. Never deletes,
// renames, reprices, or reactivates existing records. Only missing rows are added.
export async function seedCatalog(tx) {
  const categoryIds = new Map();
  for (const category of categories) {
    const row = await tx.category.upsert({ where: { slug: category.slug }, create: category, update: {} });
    categoryIds.set(category.slug, row.id);
  }
  let managed = 0;
  for (const [index, entry] of products.entries()) {
    const { categorySlug, colors, variants, availableSizes, type, ...fields } = entry;
    const existing = await tx.product.findUnique({ where: { id: entry.id } });
    if (existing && !existing.isDemo) continue; // Do not claim an owner-created ID collision.
    await tx.product.upsert({ where: { id: entry.id }, create: { ...fields, currency: 'USD', categoryId: categoryIds.get(categorySlug),
      createdAt: new Date(Date.UTC(2026, 9, 30, 0, index)) }, update: {} });
    managed++;
    for (const color of colors) {
      const { images, ...data } = color;
      const saved = await tx.productColor.upsert({ where: { productId_key: { productId: entry.id, key: color.key } },
        create: { ...data, productId: entry.id }, update: {} });
      for (const media of images) {
        await tx.productMedia.upsert({ where: { id: media.id }, create: { ...media, productId: entry.id, colorId: saved.id }, update: {} });
      }
      for (const variant of variants.filter(v => v.colorId === color.id)) {
        const legacy = color.key === entry.defaultColorKey ? await tx.productSize.findUnique({ where: { productId_size: { productId: entry.id, size: variant.size } } }) : null;
        await tx.productVariant.upsert({ where: { productId_colorId_size: { productId: entry.id, colorId: saved.id, size: variant.size } },
          create: { ...variant, id: legacy?.id ?? variant.id, productId: entry.id, colorId: saved.id,
            isAvailable: legacy ? legacy.isAvailable : variant.isAvailable }, update: {} });
      }
    }
    // Retain the old size projection for older clients; never revive a retired size.
    for (const size of availableSizes) {
      await tx.productSize.upsert({ where: { productId_size: { productId: entry.id, size } },
        create: { productId: entry.id, size }, update: {} });
    }
  }
  return { products: managed, categories: categories.length };
}
