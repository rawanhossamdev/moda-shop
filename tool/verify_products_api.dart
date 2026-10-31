import 'dart:io';
import 'package:moda_shop/repositories/product_repository.dart';
import 'package:moda_shop/services/products_api.dart';
import 'package:moda_shop/models/product.dart';

/// Read-only smoke check for the real Dart client against a running API.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    throw ArgumentError('Pass the API base URL as the only argument.');
  }
  final repository = ApiProductRepository(
    api: ProductsApi(baseUrl: arguments.single),
  );
  try {
    final all = await repository.fetchProducts();
    if (all.length < 24) {
      throw StateError('Expected the expanded demo catalog.');
    }
    final clothing = await repository.fetchProducts(
      category: ProductCategory.clothing,
    );
    final accessories = await repository.fetchProducts(
      category: ProductCategory.bags,
    );
    if (clothing.length < 8 || accessories.length < 4) {
      throw StateError('Unexpected category results.');
    }
    final bag = await repository.fetchProduct('shoulder-bag');
    if (bag.priceInCents != 6500 ||
        bag.image != 'assets/images/photography/shoulder-bag_black_front.jpg' ||
        !bag.isOneSize ||
        bag.variants.isEmpty ||
        bag.colors.length < 2) {
      throw StateError('Product detail mapping failed.');
    }
    stdout.writeln(
      'Live Dart repository passed: expanded catalog, categories, local assets, variant IDs and bag One Size.',
    );
  } finally {
    repository.close();
  }
}
