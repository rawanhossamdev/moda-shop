import 'support/fake_auth.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/main.dart';
import 'package:moda_shop/data/products.dart';
import 'package:moda_shop/models/product.dart';
import 'package:moda_shop/models/cart.dart';
import 'package:moda_shop/screens/product_details_screen.dart';
import 'package:moda_shop/services/products_api.dart';
import 'package:moda_shop/theme/moda_theme.dart';
import 'support/fake_product_repository.dart';

void main() {
  testWidgets('Home shows loading, error, retry and recovered data', (
    tester,
  ) async {
    final repository = FakeProductRepository();
    final pending = Completer<List<Product>>();
    repository.onList = (_) => pending.future;
    await tester.pumpWidget(
      ModaShop(auth: createTestAuth(), repository: repository),
    );
    await tester.pump();
    await tester.pump();
    expect(repository.listRequests, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(const ApiException('Collection unavailable'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('RETRY'),
      150,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Collection unavailable'), findsOneWidget);
    repository.onList = null;
    await tester.scrollUntilVisible(
      find.text('RETRY').hitTestable(),
      150,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(repository.listRequests.length, 2);
  });
  testWidgets(
    'Latest category response wins when requests finish out of order',
    (tester) async {
      final repository = FakeProductRepository();
      final pending = Completer<List<Product>>();
      repository.onList = (category) async =>
          category == ProductCategory.clothing
          ? pending.future
          : products.where((p) => p.category == category).toList();
      await tester.pumpWidget(
        ModaShop(auth: createTestAuth(), repository: repository),
      );
      await tester.pumpAndSettle();
      Future<void> choose(String name) async {
        await tester.tap(find.byTooltip('Open menu'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.widgetWithText(ListTile, name));
        // Keep the pending request, but let the drawer animation finish.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      await choose('Clothing');
      await choose('Bags');
      await tester.pumpAndSettle();
      pending.complete(products.take(3).toList());
      await tester.pumpAndSettle();
      expect(find.text('BAGS'), findsOneWidget);
      expect(
        tester
            .widget<SliverGrid>(find.byType(SliverGrid))
            .delegate
            .estimatedChildCount,
        1,
      );
    },
  );
  testWidgets('Detail retries and uses fresh API price and sizes for cart', (
    tester,
  ) async {
    final repository = FakeProductRepository();
    repository.onDetail = (_) async =>
        throw const ApiException('Product unavailable');
    final cart = Cart();
    addTearDown(cart.dispose);
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
    expect(find.text('Product unavailable'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    repository.onDetail = (_) async => Product(
      id: products.first.id,
      name: products.first.name,
      image: products.first.image,
      priceInCents: 3600,
      category: ProductCategory.clothing,
      availableSizes: const ['L'],
    );
    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();
    expect(find.text('\$36.00'), findsOneWidget);
    await tester.tap(find.text('ADD TO CART'));
    await tester.pumpAndSettle();
    expect(cart.items.single.size, 'L');
    expect(cart.total, 3600);
  });
  testWidgets(
    'One-size bag adds without a size choice and cart shows One Size',
    (tester) async {
      final cart = Cart();
      addTearDown(cart.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: ProductDetailsScreen(
            product: products.last,
            cart: cart,
            repository: FakeProductRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('One Size'), findsOneWidget);
      for (final size in ['S', 'M', 'L', 'ONE_SIZE']) {
        expect(find.widgetWithText(OutlinedButton, size), findsNothing);
      }
      await tester.tap(find.text('ADD TO CART'));
      await tester.pumpAndSettle();
      expect(cart.items.single.size, 'ONE_SIZE');
      expect(cart.total, 6500);
      await tester.tap(find.text('VIEW CART'));
      await tester.pumpAndSettle();
      expect(find.text('One Size'), findsOneWidget);
      expect(find.text('Size ONE_SIZE'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'One-size cart defaults its variant, merges quantities and rejects clothing sizes',
    () {
      final cart = Cart();
      addTearDown(cart.dispose);
      cart.add(products.last);
      cart.add(products.last, 'ONE_SIZE');
      expect(cart.items, hasLength(1));
      expect(cart.count, 2);
      expect(cart.total, 13000);
      expect(() => cart.add(products.last, 'M'), throwsArgumentError);
      expect(() => cart.add(products.first), throwsArgumentError);
      cart.setQuantity(cart.items.single, 3);
      expect(cart.total, 19500);
      cart.remove(cart.items.single);
      expect(cart.items, isEmpty);
    },
  );
}
