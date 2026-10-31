import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/data/products.dart';
import 'package:moda_shop/models/cart.dart';
import 'package:moda_shop/models/product.dart';
import 'package:moda_shop/screens/product_details_screen.dart';
import 'package:moda_shop/services/products_api.dart';
import 'package:moda_shop/theme/moda_theme.dart';
import 'package:moda_shop/widgets/catalog_state.dart';
import 'package:moda_shop/widgets/product_image.dart';
import 'support/fake_product_repository.dart';

class RejectingCart extends Cart {
  @override
  void add(Product product, [String? size]) => throw StateError('Unavailable');
}

void main() {
  testWidgets('Unavailable photography has an accessible fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            height: 180,
            child: ProductImage(
              asset: 'assets/images/missing.png',
              semanticLabel: 'Selected piece',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(
      find.bySemanticsLabel('Image unavailable for Selected piece'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Rapid add taps create one item, then permit another deliberate add',
    (tester) async {
      final cart = Cart();
      addTearDown(cart.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: ProductDetailsScreen(
            product: products.first,
            cart: cart,
            repository: FakeProductRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'ADD TO CART');
      final callback = tester.widget<FilledButton>(button).onPressed!;
      callback();
      callback();
      await tester.pump();
      expect(cart.count, 1);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(button);
      await tester.pump();
      expect(cart.count, 2);
      await tester.pump(const Duration(milliseconds: 600));
    },
  );

  testWidgets(
    'Cart failures give a friendly message and leave the product usable',
    (tester) async {
      final cart = RejectingCart();
      addTearDown(cart.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: ProductDetailsScreen(
            product: products.first,
            cart: cart,
            repository: FakeProductRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ADD TO CART'));
      await tester.pump();
      expect(find.textContaining('Unable to add this piece'), findsOneWidget);
      expect(cart.count, 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Repeated detail retries share the in-flight request', (
    tester,
  ) async {
    final cart = Cart();
    addTearDown(cart.dispose);
    final repository = FakeProductRepository()
      ..onDetail = (_) async => throw const ApiException('Try again');
    await tester.pumpWidget(
      MaterialApp(
        theme: ModaStyle.theme,
        home: ProductDetailsScreen(
          product: products.first,
          cart: cart,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pending = Completer<Product>();
    repository.onDetail = (_) => pending.future;
    final retry = tester
        .widget<CatalogState>(find.byType(CatalogState))
        .onRetry!;
    retry();
    retry();
    await tester.pump();
    expect(repository.detailRequests.length, 2);
    pending.complete(products.first);
    await tester.pumpAndSettle();
    expect(find.text(products.first.name), findsOneWidget);
  });
}
