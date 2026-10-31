class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.slug,
  });
  final String id, name, slug;
  factory CatalogCategory.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['name'] is! String ||
        value['slug'] is! String ||
        (value['slug'] as String).isEmpty) {
      throw const FormatException('Invalid category');
    }
    return CatalogCategory(
      id: value['id'],
      name: value['name'],
      slug: value['slug'],
    );
  }
}

class CatalogQuery {
  const CatalogQuery({
    this.search = '',
    this.category,
    this.minPrice,
    this.maxPrice,
    this.size,
    this.sort = 'featured',
  });
  final String search, sort;
  final String? category, size;
  final int? minPrice, maxPrice;
  Map<String, String> get parameters => {
    if (search.trim().isNotEmpty) 'search': search.trim(),
    'category': ?category,
    'size': ?size,
    if (minPrice != null) 'minPrice': '$minPrice',
    if (maxPrice != null) 'maxPrice': '$maxPrice',
    'sort': sort,
  };
}
