import 'package:moda_shop/data/products.dart';
import 'package:moda_shop/models/product.dart';
import 'package:moda_shop/models/catalog_query.dart';
import 'package:moda_shop/repositories/product_repository.dart';
import 'package:moda_shop/services/products_api.dart';

class FakeProductRepository implements ProductRepository {
  FakeProductRepository({this.items = products});
  final List<Product> items;
  final List<ProductCategory?> listRequests = [];
  final List<String> detailRequests = [];
  Future<List<Product>> Function(ProductCategory?)? onList;
  Future<Product> Function(String)? onDetail;
  @override
  Future<List<Product>> fetchProducts({
    ProductCategory? category,
    CatalogQuery? query,
  }) async {
    listRequests.add(category);
    if (onList != null) return onList!(category);
    final result = items
        .where((product) => category == null || product.category == category)
        .where(
          (p) =>
              query == null ||
              (p.name.toLowerCase().contains(
                    query.search.trim().toLowerCase(),
                  ) &&
                  (query.category == null ||
                      (p.categorySlug ?? p.category.name) == query.category) &&
                  (query.minPrice == null ||
                      p.priceInCents >= query.minPrice!) &&
                  (query.maxPrice == null ||
                      p.priceInCents <= query.maxPrice!) &&
                  (query.size == null ||
                      (p.variants.isEmpty
                          ? p.availableSizes.contains(query.size)
                          : p.variants.any(
                              (v) => v.isAvailable && v.size == query.size,
                            )))),
        )
        .toList();
    if (query?.sort == 'price_asc') {
      result.sort((a, b) => a.priceInCents.compareTo(b.priceInCents));
    }
    if (query?.sort == 'price_desc') {
      result.sort((a, b) => b.priceInCents.compareTo(a.priceInCents));
    }
    if (query?.sort == 'newest') {
      result.sort(
        (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
          a.createdAt ?? DateTime(1970),
        ),
      );
    }
    if (query?.sort == 'name') result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  @override
  Future<List<CatalogCategory>> fetchCategories() async => const [
    CatalogCategory(id: 'clothing', name: 'Clothing', slug: 'clothing'),
    CatalogCategory(id: 'bags', name: 'Bags', slug: 'bags'),
    CatalogCategory(id: 'shoes', name: 'Shoes', slug: 'shoes'),
    CatalogCategory(id: 'jewelry', name: 'Jewelry', slug: 'jewelry'),
    CatalogCategory(
      id: 'accessories',
      name: 'Accessories',
      slug: 'accessories',
    ),
  ];

  @override
  Future<Product> fetchProduct(String id) async {
    detailRequests.add(id);
    if (onDetail != null) return onDetail!(id);
    return items.firstWhere(
      (product) => product.id == id,
      orElse: () => throw const ApiException(
        'This product is no longer available.',
        statusCode: 404,
      ),
    );
  }

  @override
  void close() {}
}
