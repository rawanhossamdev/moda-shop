import '../models/product.dart';

// Retained as deterministic test/seed-parity fixtures only. App screens load
// their catalog through ProductRepository; there is no offline mock fallback.

const products = [
  Product(
    id: 'knit-sweater',
    name: 'Ribbed Knit Sweater',
    image: 'assets/images/knit_sweater.png',
    priceInCents: 3500,
    category: ProductCategory.clothing,
    availableSizes: ['S', 'M', 'L'],
  ),
  Product(
    id: 'wide-leg-trousers',
    name: 'Wide Leg Trousers',
    image: 'assets/images/wide_leg_trousers.png',
    priceInCents: 5500,
    category: ProductCategory.clothing,
    availableSizes: ['S', 'M', 'L'],
  ),
  Product(
    id: 'tailored-blazer',
    name: 'Tailored Blazer',
    image: 'assets/images/tailored_blazer.png',
    priceInCents: 8500,
    category: ProductCategory.clothing,
    availableSizes: ['S', 'M', 'L'],
  ),
  Product(
    id: 'shoulder-bag',
    name: 'Shoulder Bag',
    image: 'assets/images/shoulder_bag.png',
    priceInCents: 6500,
    category: ProductCategory.bags,
    availableSizes: ['ONE_SIZE'],
  ),
];
