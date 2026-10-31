import { AuthError } from './auth.service.js';
export const sizeValues = ['S', 'M', 'L', 'ONE_SIZE', ...Array.from({ length: 7 }, (_, i) => `EU_${i + 36}`)];
const unavailable = () => new AuthError(409, 'CART_UNAVAILABLE', 'A selected product, color or size is no longer available. Please review your cart.');

export function resolveVariant(product, item) {
  if (!product?.isActive) throw unavailable();
  if (product.variants?.length) {
    const colors = product.colors ?? [];
    const defaultColor = colors.find(color => color.key === product.defaultColorKey) ?? colors[0];
    const variant = item.variantId
      ? product.variants.find(v => v.id === item.variantId)
      : product.variants.find(v => v.size === item.size && (v.colorId ?? null) === (defaultColor?.id ?? null));
    if (!variant || !variant.isAvailable || variant.size !== item.size || (item.colorId && variant.colorId !== item.colorId)) throw unavailable();
    const color = colors.find(c => c.id === variant.colorId);
    if (variant.colorId && !color) throw unavailable();
    const images = color ? (color.media ?? color.images ?? []) : (product.media ?? []).filter(m => !m.colorId);
    return { variantId: variant.id, colorId: color?.id ?? null, colorName: color?.name ?? null,
      productImage: images[0]?.path ?? (color ? null : product.image ?? null),
      unitPriceInCents: variant.priceInCents ?? product.priceInCents };
  }
  // Legacy mocks/records without a variant projection retain size-only behavior.
  if (item.variantId || item.colorId || !product.sizes?.some(s => s.size === item.size && s.isAvailable !== false)) throw unavailable();
  return { productImage: product.image ?? null, unitPriceInCents: product.priceInCents };
}
