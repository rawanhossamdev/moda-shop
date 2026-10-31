import 'support/fake_auth.dart';
import 'support/fake_product_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/main.dart';
import 'package:moda_shop/data/products.dart';
import 'package:moda_shop/models/product.dart';
import 'package:moda_shop/screens/cart_screen.dart';
import 'package:moda_shop/widgets/product_card.dart';

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open menu'));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String label) async {
  final item = find.widgetWithText(ListTile, label);
  await tester.scrollUntilVisible(
    item.hitTestable(),
    100,
    scrollable: find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(item);
  await tester.pumpAndSettle();
}

void main() {
  test('Catalog contains three clothing products and one shoulder bag', () {
    expect(
      products.where((p) => p.category == ProductCategory.clothing).length,
      3,
    );
    expect(products.where((p) => p.category == ProductCategory.bags), [
      products.last,
    ]);
  });
  for (final width in [360.0, 390.0]) {
    testWidgets('Drawer filters and navigation work on phone $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ModaShop(auth: createTestAuth(), repository: FakeProductRepository()),
      );
      await tester.pumpAndSettle();
      await openMenu(tester);
      expect(find.text('Coming Soon'), findsNothing);
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Wishlist'))
            .onTap,
        isNotNull,
      );
      await choose(tester, 'Bags');
      expect(find.text('No accessories yet'), findsNothing);
      expect(
        tester
            .widget<SliverGrid>(find.byType(SliverGrid))
            .delegate
            .estimatedChildCount,
        1,
      );
      expect(
        tester.widget<ProductCard>(find.byType(ProductCard)).product,
        products.last,
      );
      expect(find.byTooltip('Close menu'), findsNothing);
      await openMenu(tester);
      await choose(tester, 'Shop All');
      expect(
        tester
            .widget<SliverGrid>(find.byType(SliverGrid))
            .delegate
            .estimatedChildCount,
        4,
      );
      await openMenu(tester);
      await choose(tester, 'Clothing');
      expect(find.text('CLOTHING'), findsOneWidget);
      expect(
        tester
            .widget<SliverGrid>(find.byType(SliverGrid))
            .delegate
            .estimatedChildCount,
        3,
      );
      await openMenu(tester);
      await choose(tester, 'New Arrivals');
      expect(
        tester.getTopLeft(find.byKey(const Key('new-arrival-section'))).dy,
        closeTo(64, 2),
      );
      await openMenu(tester);
      await choose(tester, 'My Cart');
      expect(find.byType(CartScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openMenu(tester);
      await choose(tester, 'About MODA');
      expect(
        find.text(
          'An independent Flutter portfolio project with a curated collection.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close about MODA'));
      await tester.pumpAndSettle();
      await openMenu(tester);
      await choose(tester, 'Home');
      expect(tester.getTopLeft(find.byType(CustomScrollView)).dy, 64);
      expect(
        find.text('The art of\neveryday\ndressing.').hitTestable(),
        findsOneWidget,
      );
      await openMenu(tester);
      await tester.tap(find.byTooltip('Close menu'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close menu'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Drawer scrolls with large text in a short viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ModaShop(auth: createTestAuth(), repository: FakeProductRepository()),
    );
    await tester.pumpAndSettle();
    await openMenu(tester);
    await choose(tester, 'About MODA');
    expect(find.byTooltip('Close about MODA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
