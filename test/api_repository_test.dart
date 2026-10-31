import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/models/product.dart';
import 'package:moda_shop/services/products_api.dart';
import 'package:moda_shop/repositories/product_repository.dart';

class FakeTransport implements ApiTransport {
  late Future<ApiResponse> Function(Uri) handler;
  bool closed = false;
  @override
  Future<ApiResponse> get(Uri uri) => handler(uri);
  @override
  void close() {
    closed = true;
  }
}

Map<String, dynamic> productJson() => {
  'id': 'knit-sweater',
  'name': 'Ribbed Knit Sweater',
  'image': 'assets/images/knit_sweater.png',
  'priceInCents': 3500,
  'currency': 'USD',
  'category': {'slug': 'clothing', 'name': 'Clothing'},
  'availableSizes': ['S', 'M', 'L'],
};
void main() {
  test(
    'Repository preserves integer cents and local assets and sends category to the API',
    () async {
      final transport = FakeTransport();
      transport.handler = (uri) async {
        expect(uri.path, '/api/products');
        expect(uri.queryParameters, {'category': 'clothing'});
        return ApiResponse(
          200,
          jsonEncode({
            'data': [productJson()],
          }),
        );
      };
      final repository = ApiProductRepository(
        api: ProductsApi(
          transport: transport,
          baseUrl: 'http://test.local/api/',
        ),
      );
      final result = await repository.fetchProducts(
        category: ProductCategory.clothing,
      );
      expect(result.single.priceInCents, 3500);
      expect(result.single.price, '\$35.00');
      expect(result.single.image, 'assets/images/knit_sweater.png');
      expect(result.single.availableSizes, ['S', 'M', 'L']);
      repository.close();
      expect(transport.closed, isTrue);
    },
  );
  test('Detail mapping uses requested ID and available sizes', () async {
    final transport = FakeTransport();
    transport.handler = (uri) async {
      expect(uri.path, '/api/products/knit-sweater');
      return ApiResponse(
        200,
        jsonEncode({
          'data': productJson()..['availableSizes'] = ['L'],
        }),
      );
    };
    final repository = ApiProductRepository(
      api: ProductsApi(transport: transport, baseUrl: 'http://test.local/api'),
    );
    expect((await repository.fetchProduct('knit-sweater')).availableSizes, [
      'L',
    ]);
  });
  test(
    'Malformed products, unsupported currency and noninteger prices fail clearly',
    () async {
      final transport = FakeTransport();
      final repository = ApiProductRepository(
        api: ProductsApi(transport: transport),
      );
      for (final changes in [
        {'priceInCents': 35.5},
        {'priceInCents': '3500'},
        {'currency': 'EUR'},
        {'image': '../unknown.png'},
        {
          'category': {'slug': 'unsupported'},
        },
        {
          'availableSizes': ['XL'],
        },
      ]) {
        transport.handler = (_) async => ApiResponse(
          200,
          jsonEncode({
            'data': {...productJson(), ...changes},
          }),
        );
        await expectLater(
          repository.fetchProduct('knit-sweater'),
          throwsA(isA<ApiException>()),
        );
      }
      transport.handler = (_) async => const ApiResponse(200, 'invalid json');
      await expectLater(
        repository.fetchProduct('knit-sweater'),
        throwsA(isA<ApiException>()),
      );
      transport.handler = (_) async => const ApiResponse(200, '{"data": {}}');
      await expectLater(
        repository.fetchProducts(),
        throwsA(isA<ApiException>()),
      );
    },
  );
  test('HTTP and network errors become safe user-facing failures', () async {
    final transport = FakeTransport();
    final repository = ApiProductRepository(
      api: ProductsApi(transport: transport),
    );
    transport.handler = (_) async =>
        const ApiResponse(404, 'private server details');
    await expectLater(
      repository.fetchProduct('missing'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'HTTP status',
          404,
        ),
      ),
    );
    transport.handler = (_) async =>
        const ApiResponse(500, 'private server details');
    await expectLater(
      repository.fetchProducts(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message.contains('private'),
          'redacted',
          false,
        ),
      ),
    );
    transport.handler = (_) async => throw Exception('private network details');
    await expectLater(repository.fetchProducts(), throwsA(isA<ApiException>()));
  });
}
