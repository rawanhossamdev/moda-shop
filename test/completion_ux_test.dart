import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/controllers/search_history.dart';
import 'package:moda_shop/data/products.dart';
import 'package:moda_shop/models/cart.dart';
import 'package:moda_shop/models/product.dart';
import 'package:moda_shop/models/shop_order.dart';
import 'package:moda_shop/screens/catalog_screen.dart';
import 'package:moda_shop/screens/checkout_recovery_screen.dart';
import 'package:moda_shop/screens/checkout_screen.dart';
import 'package:moda_shop/screens/help_screen.dart';
import 'package:moda_shop/screens/order_screens.dart';
import 'package:moda_shop/screens/product_details_screen.dart';
import 'package:moda_shop/screens/product_image_screen.dart';
import 'package:moda_shop/screens/home_screen.dart';
import 'package:moda_shop/theme/moda_theme.dart';
import 'package:moda_shop/services/products_api.dart';
import 'commerce_test.dart' show app, authFixture;
import 'cart_persistence_test.dart' show MemoryLocalStore;
import 'phase2_test.dart' show QueryRepository;
import 'support/fake_commerce.dart';
import 'support/fake_product_repository.dart';

Map<String, dynamic> recoveryBody() => {
  'clientRequestId': '37a06452-2265-47e8-8349-9716b68093d6',
  'addressId': '27a06452-2265-47e8-8349-9716b68093d6',
  'paymentMethod': 'COD',
  'expectedTotalInCents': 3700,
  'items': [
    {'productId': products.first.id, 'size': 'M', 'quantity': 1},
  ],
};

void main() {
  testWidgets(
    'Recovery retries a failed settlement save without subtracting cart twice',
    (tester) async {
      final auth = await authFixture(),
          repository = FakeCommerceRepository(),
          store = MemoryLocalStore();
      final cart = Cart(store: store);
      addTearDown(cart.dispose);
      await cart.restore(FakeProductRepository());
      cart.add(products.first, 'M');
      cart.add(products.first, 'M');
      await cart.prepareCheckout(auth.user!.id, recoveryBody());
      repository.onFindRequest = (_) async {
        store.failWrite = true;
        return testOrder();
      };
      await tester.pumpWidget(
        app(const CheckoutRecoveryScreen(), auth, repository, cart),
      );
      await tester.pumpAndSettle();
      expect(cart.count, 1);
      expect(find.text('RETRY SAVING'), findsOneWidget);
      store.failWrite = false;
      await tester.ensureVisible(find.text('RETRY SAVING'));
      await tester.tap(find.text('RETRY SAVING'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(cart.count, 1);
      expect(repository.placements, 0);
    },
  );

  testWidgets(
    'Checkout never contacts placement API before pending request is saved securely',
    (tester) async {
      final auth = await authFixture(),
          repository = FakeCommerceRepository(),
          store = MemoryLocalStore();
      final cart = Cart(store: store);
      addTearDown(cart.dispose);
      await cart.restore(FakeProductRepository());
      cart.add(products.first, 'M');
      await cart.flush();
      await repository.saveAddress({
        'fullName': 'MODA Member',
        'mobile': '01012345678',
        'governorate': 'Cairo',
        'city': 'Maadi',
        'streetAddress': '25 Test street',
        'buildingDetails': 'Apartment 4',
        'deliveryNotes': '',
        'isDefault': true,
      });
      store.failWrite = true;
      await tester.pumpWidget(
        app(CheckoutScreen(cart: cart), auth, repository, cart),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('place-order')));
      await tester.tap(find.byKey(const Key('place-order')));
      await tester.pumpAndSettle();
      expect(repository.placements, 0);
      final key = cart.pendingCheckout(auth.user!.id)!['clientRequestId'];
      store.failWrite = false;
      await tester.ensureVisible(find.byKey(const Key('place-order')));
      await tester.tap(find.byKey(const Key('place-order')));
      await tester.pumpAndSettle();
      expect(repository.placements, 1);
      expect(repository.submitted.single['clientRequestId'], key);
      expect(cart.count, 0);
    },
  );

  testWidgets(
    'A late original order wins a revised request conflict and is recovered without another placement',
    (tester) async {
      final auth = await authFixture(),
          repository = FakeCommerceRepository(),
          cart = Cart();
      addTearDown(cart.dispose);
      cart.add(products.first, 'M');
      await cart.prepareCheckout(auth.user!.id, recoveryBody());
      await repository.saveAddress({
        'fullName': 'MODA Member',
        'mobile': '01012345678',
        'governorate': 'Cairo',
        'city': 'Maadi',
        'streetAddress': '25 Test street',
        'buildingDetails': 'Apartment 4',
        'deliveryNotes': '',
        'isDefault': true,
      });
      repository.onPlace = (_) async => throw const ApiException(
        'Original request already placed',
        statusCode: 409,
        code: 'REQUEST_CONFLICT',
      );
      await tester.pumpWidget(
        app(
          CheckoutScreen(cart: cart, reviewPending: true),
          auth,
          repository,
          cart,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('place-order')));
      await tester.tap(find.byKey(const Key('place-order')));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(repository.placements, 1);
      expect(
        repository.submitted.single['clientRequestId'],
        recoveryBody()['clientRequestId'],
      );
      expect(cart.count, 0);
    },
  );
  test(
    'Search history persists submitted terms, deduplicates, caps and clears',
    () async {
      final store = MemoryLocalStore(),
          history = SearchHistory(MemoryLocalStore());
      addTearDown(history.dispose);
      final saved = SearchHistory(store);
      addTearDown(saved.dispose);
      await saved.restore();
      for (var i = 0; i < 10; i++) {
        await saved.add('Search $i');
      }
      await saved.add('  SEARCH 9  ');
      expect(saved.terms, hasLength(8));
      expect(saved.terms.first, 'SEARCH 9');
      final restarted = SearchHistory(store);
      addTearDown(restarted.dispose);
      await restarted.restore();
      expect(restarted.terms, saved.terms);
      await restarted.clear();
      expect(restarted.terms, isEmpty);
      store.failWrite = true;
      await restarted.add('Knit');
      expect(restarted.error, isNotNull);
      expect(restarted.terms, isEmpty);
    },
  );

  testWidgets('Recent search chips restore a search and can be cleared', (
    tester,
  ) async {
    final store = MemoryLocalStore(),
        cart = Cart(),
        repository = QueryRepository();
    addTearDown(cart.dispose);
    final history = SearchHistory(store);
    await history.restore();
    await history.add('Knit');
    history.dispose();
    await tester.pumpWidget(
      MaterialApp(
        theme: ModaStyle.theme,
        home: CatalogScreen(
          repository: repository,
          cart: cart,
          historyStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Knit'));
    await tester.pumpAndSettle();
    expect(repository.queries.last!.search, 'Knit');
    await tester.tap(find.byKey(const Key('clear-search-history')));
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('New Arrivals uses the existing newest backend query', (
    tester,
  ) async {
    final cart = Cart(), repository = QueryRepository();
    addTearDown(cart.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ModaStyle.theme,
        home: HomeScreen(cart: cart, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'New Arrivals'));
    await tester.pumpAndSettle();
    expect(repository.queries.last!.sort, 'newest');
  });

  testWidgets(
    'Sample information is labeled, optional fields render and photo opens zoom',
    (tester) async {
      final cart = Cart(), repository = FakeProductRepository();
      addTearDown(cart.dispose);
      repository.onDetail = (_) async => Product(
        id: products.last.id,
        name: products.last.name,
        image: products.last.image,
        priceInCents: 6500,
        category: ProductCategory.accessories,
        availableSizes: const ['ONE_SIZE'],
        description: 'Portfolio sample.',
        materials: 'Composition not verified.',
        careInstructions: 'Consult the real label.',
        sizeAndFit: 'Dimensions not verified.',
        informationIsSample: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: ProductDetailsScreen(
            product: products.last,
            cart: cart,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('One Size'), findsOneWidget);
      expect(find.text('SAMPLE PRODUCT INFORMATION'), findsOneWidget);
      await tester.ensureVisible(find.text('Materials'));
      await tester.tap(find.text('Materials'));
      await tester.pumpAndSettle();
      expect(find.text('Composition not verified.'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('product-image-fullscreen')),
      );
      await tester.tap(find.byKey(const Key('product-image-fullscreen')));
      await tester.pumpAndSettle();
      expect(find.byType(ProductImageScreen), findsOneWidget);
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .maxScale,
        5,
      );
    },
  );

  testWidgets(
    'Help provides demonstration information without invented support contacts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: ModaStyle.theme, home: const HelpScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('PORTFOLIO DEMONSTRATION'), findsOneWidget);
      await tester.ensureVisible(find.text('Customer support'));
      await tester.tap(find.text('Customer support'));
      await tester.pumpAndSettle();
      expect(find.textContaining('have not been provided'), findsOneWidget);
    },
  );

  testWidgets(
    'Order details show placement date and available historical image',
    (tester) async {
      final auth = await authFixture(),
          repository = FakeCommerceRepository(),
          cart = Cart();
      addTearDown(cart.dispose);
      final order = ShopOrder.fromJson({
        ...testOrder().data,
        'createdAt': '2026-10-30T12:00:00Z',
        'items': [
          {...testOrder().items.first, 'productImage': products.first.image},
        ],
      });
      await tester.pumpWidget(
        app(OrderDetailScreen(order: order), auth, repository, cart),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('order-date')), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(orderDateLabel('invalid'), isNull);
    },
  );

  testWidgets(
    'Restarted checkout finds its existing order and settles cart without placing again',
    (tester) async {
      final auth = await authFixture(),
          repository = FakeCommerceRepository(),
          store = MemoryLocalStore();
      final original = Cart(store: store);
      await original.restore(FakeProductRepository());
      original.add(products.first, 'M');
      original.add(products.first, 'M');
      await original.prepareCheckout(auth.user!.id, recoveryBody());
      original.dispose();
      final cart = Cart(store: store);
      addTearDown(cart.dispose);
      await cart.restore(FakeProductRepository());
      await tester.pumpWidget(
        app(const CheckoutRecoveryScreen(), auth, repository, cart),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(repository.placements, 0);
      expect(cart.count, 1);
      expect(cart.pendingCheckout(auth.user!.id), isNull);
      await cart.completeCheckout(
        auth.user!.id,
        testOrder().id,
        testOrder().items,
      );
      expect(cart.count, 1);
    },
  );

  testWidgets(
    'Recovery never submits on a missing lookup; explicit retry keeps original UUID and body',
    (tester) async {
      final auth = await authFixture(),
          repository = FakeCommerceRepository(),
          cart = Cart();
      addTearDown(cart.dispose);
      cart.add(products.first, 'M');
      await cart.prepareCheckout(auth.user!.id, recoveryBody());
      repository.onFindRequest = (_) async =>
          throw const ApiException('Not found', statusCode: 404);
      await tester.pumpWidget(
        app(const CheckoutRecoveryScreen(), auth, repository, cart),
      );
      await tester.pumpAndSettle();
      expect(repository.placements, 0);
      await tester.ensureVisible(
        find.byKey(const Key('retry-original-checkout')),
      );
      final action = tester
          .widget<FilledButton>(
            find.byKey(const Key('retry-original-checkout')),
          )
          .onPressed!;
      action();
      action();
      await tester.pumpAndSettle();
      expect(repository.placements, 1);
      expect(repository.submitted.single, recoveryBody());
      expect(cart.count, 0);
    },
  );

  testWidgets(
    'An account cannot recover a different account pending checkout',
    (tester) async {
      final auth = await authFixture(),
          repository = FakeCommerceRepository(),
          cart = Cart();
      addTearDown(cart.dispose);
      await cart.prepareCheckout('other-account', recoveryBody());
      var lookups = 0;
      repository.onFindRequest = (_) async {
        lookups++;
        return testOrder();
      };
      await tester.pumpWidget(
        app(const CheckoutRecoveryScreen(), auth, repository, cart),
      );
      await tester.pumpAndSettle();
      expect(lookups, 0);
      expect(find.byKey(const Key('retry-original-checkout')), findsNothing);
      expect(cart.pendingCheckout('other-account'), isNotNull);
    },
  );
}
