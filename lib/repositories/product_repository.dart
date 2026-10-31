import '../models/product.dart';
import '../models/catalog_query.dart';
import '../services/products_api.dart';

abstract interface class ProductRepository {
  Future<List<Product>> fetchProducts({
    ProductCategory? category,
    CatalogQuery? query,
  });
  Future<List<CatalogCategory>> fetchCategories();
  Future<Product> fetchProduct(String id);
  void close();
}

class ApiProductRepository implements ProductRepository {
  ApiProductRepository({ProductsApi? api}) : _api = api ?? ProductsApi();
  final ProductsApi _api;
  @override
  Future<List<Product>> fetchProducts({
    ProductCategory? category,
    CatalogQuery? query,
  }) async {
    final data = await _api.get(
      'products',
      query: {
        ...?query?.parameters,
        if (category != null) 'category': category.name,
      },
    );
    if (data is! List) {
      throw const ApiException('The server returned invalid product data.');
    }
    return List.unmodifiable(data.map(_parse));
  }

  @override
  Future<List<CatalogCategory>> fetchCategories() async {
    final data = await _api.get('products/categories');
    try {
      if (data is! List) throw const FormatException();
      return List.unmodifiable(data.map(CatalogCategory.fromJson));
    } on FormatException {
      throw const ApiException('The server returned invalid category data.');
    }
  }

  @override
  Future<Product> fetchProduct(String id) async {
    final data = await _api.get('products/${Uri.encodeComponent(id)}');
    return _parse(data);
  }

  Product _parse(Object? value) {
    try {
      if (value is! Map<String, dynamic>) throw const FormatException();
      return Product.fromApi(value);
    } on FormatException {
      throw const ApiException('The server returned invalid product data.');
    }
  }

  @override
  void close() => _api.close();
}
