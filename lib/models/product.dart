import '../data/catalog_assets.dart';
import 'product_variant.dart';
export 'product_variant.dart';

enum ProductCategory { clothing, bags, shoes, jewelry, accessories, other }

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.image,
    required this.priceInCents,
    required this.category,
    required List<String> availableSizes,
    this.categoryLabel,
    this.categorySlug,
    this.createdAt,
    this.description,
    this.materials,
    this.careInstructions,
    this.sizeAndFit,
    this.informationIsSample = false,
    this.isDemo = false,
    this.isFeatured = false,
    this.defaultColorId,
    this.colors = const [],
    this.variants = const [],
    this.images = const [],
  }) : _availableSizes = availableSizes;
  final String id, name, image;
  final int priceInCents;
  final ProductCategory category;
  final String? categoryLabel, categorySlug;
  final DateTime? createdAt;
  final String? description, materials, careInstructions, sizeAndFit;
  final bool informationIsSample;
  final bool isDemo, isFeatured;
  final String? defaultColorId;
  final List<ProductColor> colors;
  final List<ProductVariant> variants;
  final List<ProductMedia> images;
  String get categoryName =>
      categoryLabel ??
      switch (category) {
        ProductCategory.clothing => 'Clothing',
        ProductCategory.bags => 'Bags',
        ProductCategory.shoes => 'Shoes',
        ProductCategory.jewelry => 'Jewelry',
        ProductCategory.accessories => 'Accessories',
        ProductCategory.other => 'Collection',
      };
  List<ProductColor> get availableColors => colors
      .where(
        (color) => variants.any(
          (variant) => variant.colorId == color.id && variant.isAvailable,
        ),
      )
      .toList();
  ProductVariant? selectVariant(
    String size, {
    String? variantId,
    String? colorId,
  }) {
    if (variants.isEmpty) {
      return variantId == null &&
              colorId == null &&
              availableSizes.contains(size)
          ? ProductVariant(size: size)
          : null;
    }
    final selected = variantId != null
        ? variants.where((v) => v.id == variantId).firstOrNull
        : variants
              .where(
                (v) =>
                    v.size == size && v.colorId == (colorId ?? defaultColorId),
              )
              .firstOrNull;
    return selected != null &&
            selected.isAvailable &&
            selected.size == size &&
            (colorId == null || selected.colorId == colorId)
        ? selected
        : null;
  }

  ProductColor? colorFor(ProductVariant? variant) =>
      colors.where((color) => color.id == variant?.colorId).firstOrNull;
  List<ProductMedia> galleryFor(String? colorId) {
    if (colors.isNotEmpty) {
      return colors.where((c) => c.id == colorId).firstOrNull?.images ??
          const [];
    }
    return images.isNotEmpty
        ? images
        : [
            ProductMedia(
              id: 'primary',
              path: image,
              kind: 'photo',
              label: 'Product image',
            ),
          ];
  }

  final List<String> _availableSizes;
  // Detailed variants are authoritative. Legacy size-only products still use
  // their API list; a stale summary must never introduce clothing sizes on bags.
  List<String> get availableSizes => variants.isEmpty
      ? _availableSizes
      : List.unmodifiable(
          variants.where((v) => v.isAvailable).map((v) => v.size).toSet(),
        );
  static const sizes = ['S', 'M', 'L'];
  static const footwearSizes = [
    'EU_36',
    'EU_37',
    'EU_38',
    'EU_39',
    'EU_40',
    'EU_41',
    'EU_42',
  ];
  static const validSizes = [...sizes, 'ONE_SIZE', ...footwearSizes];
  static bool isBundledImage(String asset) => catalogAssets.contains(asset);

  factory Product.fromApi(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final image = json['image'];
    final price = json['priceInCents'];
    final category = json['category'];
    final availableSizes = json['availableSizes'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        image is! String ||
        !isBundledImage(image) ||
        price is! int ||
        price < 0 ||
        json['currency'] != 'USD' ||
        [
          'description',
          'materials',
          'careInstructions',
          'sizeAndFit',
        ].any((key) => json[key] != null && json[key] is! String) ||
        (json['informationIsSample'] != null &&
            json['informationIsSample'] is! bool) ||
        ['colors', 'variants', 'images'].any(
          (key) =>
              json[key] != null &&
              (json[key] is! List ||
                  (json[key] as List).any(
                    (entry) => entry is! Map<String, dynamic>,
                  )),
        ) ||
        (json['defaultColorId'] != null && json['defaultColorId'] is! String) ||
        category is! Map<String, dynamic> ||
        category['name'] is! String ||
        (category['name'] as String).isEmpty ||
        category['slug'] is! String ||
        (category['slug'] as String).isEmpty ||
        availableSizes is! List ||
        availableSizes.any(
          (size) => size is! String || !validSizes.contains(size),
        )) {
      throw const FormatException('Invalid product response');
    }
    final mappedCategory = switch (category['slug']) {
      'clothing' => ProductCategory.clothing,
      'bags' => ProductCategory.bags,
      'shoes' => ProductCategory.shoes,
      'jewelry' => ProductCategory.jewelry,
      'accessories' => ProductCategory.accessories,
      _ => ProductCategory.other,
    };
    final colors = (json['colors'] as List? ?? [])
        .map(
          (c) => ProductColor.fromJson(
            Map<String, dynamic>.from(c as Map),
            isBundledImage,
          ),
        )
        .toList();
    final variants = (json['variants'] as List? ?? [])
        .map(
          (v) => ProductVariant.fromJson(
            Map<String, dynamic>.from(v as Map),
            validSizes,
          ),
        )
        .toList();
    if (colors.map((c) => c.id).toSet().length != colors.length ||
        variants.map((v) => v.id).toSet().length != variants.length ||
        variants.any(
          (v) => v.colorId != null && !colors.any((c) => c.id == v.colorId),
        )) {
      throw const FormatException('Invalid variant/color relationship');
    }
    return Product(
      id: id,
      name: name,
      image: image,
      priceInCents: price,
      category: mappedCategory,
      categoryLabel: category['name'] is String
          ? category['name'] as String
          : null,
      categorySlug: category['slug'] is String
          ? category['slug'] as String
          : null,
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'])
          : null,
      description: json['description'] as String?,
      materials: json['materials'] as String?,
      careInstructions: json['careInstructions'] as String?,
      sizeAndFit: json['sizeAndFit'] as String?,
      colors: List.unmodifiable(colors),
      variants: List.unmodifiable(variants),
      images: List.unmodifiable(
        (json['images'] as List? ?? []).map(
          (m) => ProductMedia.fromJson(
            Map<String, dynamic>.from(m as Map),
            isBundledImage,
          ),
        ),
      ),
      defaultColorId: json['defaultColorId'] as String?,
      isDemo: json['isDemo'] == true,
      isFeatured: json['isFeatured'] == true,
      informationIsSample: json['informationIsSample'] == true,
      availableSizes: List.unmodifiable(availableSizes.cast<String>().toSet()),
    );
  }
  bool get isOneSize {
    final labels = variants.isEmpty
        ? _availableSizes
        : variants.map((v) => v.size).toSet();
    return labels.length == 1 && labels.single == 'ONE_SIZE';
  }

  String get price => formatPrice(priceInCents);
}

String formatPrice(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

String sizeLabel(String size) => size == 'ONE_SIZE'
    ? 'One Size'
    : size.startsWith('EU_')
    ? 'EU ${size.substring(3)}'
    : 'Size $size';
String variantLabel(String size, String? color) =>
    color == null ? sizeLabel(size) : '$color / ${sizeLabel(size)}';
