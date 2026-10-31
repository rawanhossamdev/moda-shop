class ProductMedia {
  const ProductMedia({
    required this.id,
    required this.path,
    required this.kind,
    required this.label,
  });
  final String id, path, kind, label;
  bool get isIllustration => kind == 'illustration';
  factory ProductMedia.fromJson(
    Map<String, dynamic> json,
    bool Function(String) approved,
  ) {
    if (json['id'] is! String ||
        json['path'] is! String ||
        !approved(json['path']) ||
        !['photo', 'ai_photo', 'illustration'].contains(json['kind']) ||
        json['label'] is! String) {
      throw const FormatException('Invalid product image');
    }
    return ProductMedia(
      id: json['id'],
      path: json['path'],
      kind: json['kind'],
      label: json['label'],
    );
  }
}

class ProductColor {
  const ProductColor({
    required this.id,
    required this.key,
    required this.name,
    required this.hex,
    this.images = const [],
  });
  final String id, key, name, hex;
  final List<ProductMedia> images;
  factory ProductColor.fromJson(
    Map<String, dynamic> json,
    bool Function(String) approved,
  ) {
    if (['id', 'key', 'name', 'hex'].any((key) => json[key] is! String) ||
        !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(json['hex']) ||
        json['images'] is! List) {
      throw const FormatException('Invalid product color');
    }
    return ProductColor(
      id: json['id'],
      key: json['key'],
      name: json['name'],
      hex: json['hex'],
      images: List.unmodifiable(
        (json['images'] as List).map(
          (image) => ProductMedia.fromJson(
            Map<String, dynamic>.from(image as Map),
            approved,
          ),
        ),
      ),
    );
  }
}

class ProductVariant {
  const ProductVariant({
    this.id,
    this.colorId,
    required this.size,
    this.isAvailable = true,
    this.priceInCents,
  });
  final String? id, colorId;
  final String size;
  final bool isAvailable;
  final int? priceInCents;
  factory ProductVariant.fromJson(
    Map<String, dynamic> json,
    List<String> validSizes,
  ) {
    if (json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        (json['colorId'] != null && json['colorId'] is! String) ||
        !validSizes.contains(json['size']) ||
        json['isAvailable'] is! bool ||
        (json['priceInCents'] != null &&
            (json['priceInCents'] is! int || json['priceInCents'] < 0))) {
      throw const FormatException('Invalid product variant');
    }
    return ProductVariant(
      id: json['id'],
      colorId: json['colorId'],
      size: json['size'],
      isAvailable: json['isAvailable'],
      priceInCents: json['priceInCents'],
    );
  }
}
