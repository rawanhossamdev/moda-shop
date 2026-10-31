import 'support/fake_auth.dart';
import 'support/fake_product_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/main.dart';
import 'package:moda_shop/data/products.dart';
import 'package:moda_shop/models/cart.dart';
import 'package:moda_shop/screens/product_details_screen.dart';
import 'package:moda_shop/screens/cart_screen.dart';
import 'package:moda_shop/screens/home_screen.dart';
import 'package:moda_shop/theme/moda_theme.dart';

void main() {
  test('Cart merges matching sizes and calculates quantities and totals', () {
    final cart = Cart();
    addTearDown(cart.dispose);
    cart.add(products.first, 'M');
    cart.add(products.first, 'M');
    cart.add(products.first, 'S');
    cart.add(products[1], 'L');
    expect(cart.items.length, 3);
    expect(cart.count, 4);
    expect(cart.total, 16000);
    cart.setQuantity(cart.items.first, 3);
    expect(cart.total, 19500);
    cart.setQuantity(cart.items.first, 0);
    expect(cart.items.first.quantity, 3);
    cart.remove(cart.items.last);
    expect(cart.total, 14000);
    expect(() => cart.add(products.first, 'XL'), throwsArgumentError);
  });

  testWidgets(
    'Shopping flow supports size, add, quantity, removal and navigation',
    (tester) async {
      await tester.pumpWidget(
        ModaShop(auth: createTestAuth(), repository: FakeProductRepository()),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('EXPLORE COLLECTION').hitTestable(),
        200,

        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('EXPLORE COLLECTION'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('new-arrival-section'))).dy,
        closeTo(64, 2),
      );
      await tester.scrollUntilVisible(
        find.text(products.first.name).hitTestable(),
        150,

        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text(products.first.name));
      await tester.pumpAndSettle();
      expect(find.byType(ProductDetailsScreen), findsOneWidget);
      expect(find.text(products.first.name), findsOneWidget);
      expect(find.text(products.first.price), findsOneWidget);
      await tester.ensureVisible(find.text('S'));
      await tester.tap(find.text('S'));
      await tester.pump();
      expect(find.text('SIZE — S'), findsOneWidget);
      await tester.ensureVisible(find.text('ADD TO CART'));
      await tester.tap(find.text('ADD TO CART'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open cart'));
      await tester.pumpAndSettle();
      expect(find.text('Size S'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('cart-total')),
        150,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('cart-total'))).data,
        '\$35.00',
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Decrease quantity',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byTooltip('Increase quantity'));
      await tester.tap(find.byTooltip('Increase quantity'));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('cart-total'))).data,
        '\$70.00',
      );
      await tester.tap(find.byTooltip('Decrease quantity'));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('cart-total'))).data,
        '\$35.00',
      );
      await tester.ensureVisible(
        find.byTooltip('Remove Ribbed Knit Sweater, size S'),
      );
      await tester.tap(find.byTooltip('Remove Ribbed Knit Sweater, size S'));
      await tester.pumpAndSettle();
      expect(find.text('Your cart is empty'), findsOneWidget);
      await tester.tap(find.text('EXPLORE COLLECTION'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductDetailsScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 360.0, 390.0, 412.0]) {
    testWidgets('Phone $width keeps two columns and opens selected product', (
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
      await tester.scrollUntilVisible(
        find.text('EXPLORE COLLECTION').hitTestable(),
        150,

        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('EXPLORE COLLECTION'));
      await tester.pumpAndSettle();
      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        2,
      );
      await tester.tap(find.text('See All'));
      await tester.pumpAndSettle();
      expect(find.text('SHOP ALL'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(products[1].name).hitTestable(),
        100,

        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text(products[1].name));
      await tester.pumpAndSettle();
      expect(find.text(products[1].price), findsOneWidget);
      expect(find.text('ADD TO CART').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 360.0, 390.0, 412.0, 768.0, 1200.0]) {
    testWidgets('Home and shopping screens fit width $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget scaled(Widget child) => MaterialApp(
        theme: ModaStyle.theme,
        builder: (context, widget) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: widget!,
        ),
        home: child,
      );
      final cart = Cart()..add(products.first, 'M');
      addTearDown(cart.dispose);
      await tester.pumpWidget(
        scaled(HomeScreen(cart: cart, repository: FakeProductRepository())),
      );
      await tester.scrollUntilVisible(
        find.text('EXPLORE COLLECTION').hitTestable(),
        150,

        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('EXPLORE COLLECTION'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('new-arrival-section'))).dy,
        // Wide screens show the whole compact collection without enough
        // overflow to pin its heading to the top. It must remain visible.
        width >= 1000 ? inInclusiveRange(64, 450) : closeTo(64, 2),
      );
      await tester.scrollUntilVisible(
        find.text(products.first.name).hitTestable(),
        150,

        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        scaled(
          ProductDetailsScreen(
            product: products.first,
            cart: cart,
            repository: FakeProductRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ADD TO CART'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(scaled(CartScreen(cart: cart)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('cart-total')).hitTestable(),
        150,

        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
