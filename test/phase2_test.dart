import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/controllers/wishlist_controller.dart';
import 'package:moda_shop/data/products.dart';
import 'package:moda_shop/main.dart';
import 'package:moda_shop/models/cart.dart';
import 'package:moda_shop/models/catalog_query.dart';
import 'package:moda_shop/models/product.dart';
import 'package:moda_shop/repositories/product_repository.dart';
import 'package:moda_shop/screens/catalog_screen.dart';
import 'package:moda_shop/screens/product_details_screen.dart';
import 'package:moda_shop/screens/wishlist_screen.dart';
import 'package:moda_shop/services/products_api.dart';
import 'package:moda_shop/theme/moda_theme.dart';
import 'package:moda_shop/widgets/product_card.dart';
import 'package:moda_shop/widgets/wishlist_scope.dart';
import 'support/fake_auth.dart';
import 'support/fake_product_repository.dart';

class MemoryWishlistStore implements WishlistStore {
  String? value;
  bool failRead = false, failWrite = false;
  Completer<void>? pending;
  int writes = 0;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('Read failed');
    return value;
  }

  @override
  Future<void> write(String next) async {
    writes++;
    if (pending != null) await pending!.future;
    if (failWrite) throw StateError('Write failed');
    value = next;
  }
}

class QueryRepository extends FakeProductRepository {
  final queries = <CatalogQuery?>[];
  Future<List<Product>> Function(CatalogQuery?)? queryHandler;
  bool failCategories = false;
  @override
  Future<List<Product>> fetchProducts({
    ProductCategory? category,
    CatalogQuery? query,
  }) {
    queries.add(query);
    return queryHandler?.call(query) ??
        super.fetchProducts(category: category, query: query);
  }

  @override
  Future<List<CatalogCategory>> fetchCategories() async {
    if (failCategories) throw const ApiException('Unavailable');
    return [
      ...await super.fetchCategories(),
      const CatalogCategory(id: 'new', name: 'Archive', slug: 'archive'),
    ];
  }
}

class CatalogTransport implements ApiTransport {
  Uri? requested;
  Object data = [];
  @override
  Future<ApiResponse> get(Uri uri) async {
    requested = uri;
    return ApiResponse(200, jsonEncode({'data': data}));
  }

  @override
  void close() {}
}

void main() {
  test(
    'Products support genuine dynamic categories without inventing unsupported metadata',
    () {
      final p = Product.fromApi({
        'id': 'archive-piece',
        'name': products.first.name,
        'image': products.first.image,
        'priceInCents': 3500,
        'currency': 'USD',
        'availableSizes': <String>[],
        'category': {'name': 'Archive', 'slug': 'archive'},
        'createdAt': '2026-01-01T00:00:00Z',
      });
      expect(p.category, ProductCategory.other);
      expect(p.categoryName, 'Archive');
      expect(p.createdAt, DateTime.utc(2026));
      expect(p.availableSizes, isEmpty);
    },
  );

  test(
    'Repository sends cents, literal search, category, size and sort to existing API',
    () async {
      final transport = CatalogTransport();
      final repo = ApiProductRepository(api: ProductsApi(transport: transport));
      await repo.fetchProducts(
        query: const CatalogQuery(
          search: 'Knit & bag',
          category: 'clothing',
          minPrice: 0,
          maxPrice: 8500,
          size: 'M',
          sort: 'price_desc',
        ),
      );
      expect(transport.requested!.queryParameters, {
        'search': 'Knit & bag',
        'category': 'clothing',
        'minPrice': '0',
        'maxPrice': '8500',
        'size': 'M',
        'sort': 'price_desc',
      });
      transport.data = [
        {'id': 'db-category', 'slug': 'archive', 'name': 'Archive'},
      ];
      expect((await repo.fetchCategories()).single.name, 'Archive');
      expect(transport.requested!.path, '/api/products/categories');
      repo.close();
    },
  );

  test(
    'Wishlist survives recreation and storage failures do not falsely save or overwrite',
    () async {
      final store = MemoryWishlistStore();
      final first = WishlistController(store: store);
      await first.restore();
      await first.toggle(products.first.id);
      final second = WishlistController(store: store);
      await second.restore();
      expect(second.ids, [products.first.id]);
      store.failWrite = true;
      await expectLater(second.toggle(products.last.id), throwsStateError);
      expect(second.ids, [products.first.id]);
      store.failWrite = false;
      await second.toggle(products.first.id);
      expect(jsonDecode(store.value!), isEmpty);
      store.failRead = true;
      await second.restore();
      expect(second.error, isNotNull);
      final writes = store.writes;
      await second.toggle(products.last.id);
      expect(store.writes, writes);
      first.dispose();
      second.dispose();
    },
  );

  test(
    'Wishlist prevents concurrent duplicate writes and rejects malformed saved data',
    () async {
      final store = MemoryWishlistStore()..pending = Completer<void>();
      final wishlist = WishlistController(store: store);
      await wishlist.restore();
      final pending = wishlist.toggle(products.first.id);
      await wishlist.toggle(products.first.id);
      expect(store.writes, 1);
      store.pending!.complete();
      await pending;
      expect(wishlist.ids, [products.first.id]);
      store.value = '{bad';
      await wishlist.restore();
      expect(wishlist.error, isNotNull);
      expect(store.value, '{bad');
      wishlist.dispose();
    },
  );

  Future<void> catalog(
    WidgetTester tester,
    QueryRepository repo, {
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cart = Cart();
    addTearDown(cart.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ModaStyle.theme,
        home: CatalogScreen(repository: repo, cart: cart),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Category failure retries independently while products remain usable',
    (tester) async {
      final repo = QueryRepository()..failCategories = true;
      await catalog(tester, repo);
      expect(find.text('Categories are unavailable.'), findsOneWidget);
      expect(find.byType(SliverGrid), findsOneWidget);
      repo.failCategories = false;
      await tester.tap(find.text('RETRY CATEGORIES'));
      await tester.pumpAndSettle();
      expect(find.text('Categories are unavailable.'), findsNothing);
      expect(find.text('Archive'), findsOneWidget);
    },
  );

  testWidgets(
    'Debounced partial search, dynamic categories, empty and reset work',
    (tester) async {
      final repo = QueryRepository();
      await catalog(tester, repo);
      expect(find.text('Archive'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('catalog-search')), 'kNiT');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<ProductCard>(find.byType(ProductCard))
            .map((c) => c.product.id),
        [products.first.id],
      );
      await tester.enterText(
        find.byKey(const Key('catalog-search')),
        'not-a-product',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('No pieces found.'), findsOneWidget);
      await tester.tap(find.text('RESET'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SliverGrid>(find.byType(SliverGrid))
            .delegate
            .estimatedChildCount,
        4,
      );
      await tester.ensureVisible(find.text('Bags'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bags'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProductCard>(find.byType(ProductCard)).product.id,
        products.last.id,
      );
    },
  );

  testWidgets(
    'Stale responses cannot overwrite newer search; errors retry independently',
    (tester) async {
      final repo = QueryRepository();
      final pending = Completer<List<Product>>();
      repo.queryHandler = (q) async => q?.search == 'old'
          ? pending.future
          : q?.search == 'new'
          ? [products.last]
          : products;
      await catalog(tester, repo);
      await tester.enterText(find.byKey(const Key('catalog-search')), 'old');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.enterText(find.byKey(const Key('catalog-search')), 'new');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      pending.complete([products.first]);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProductCard>(find.byType(ProductCard)).product.id,
        products.last.id,
      );
      repo.queryHandler = (_) async =>
          throw const ApiException('Catalog offline');
      await tester.tap(find.text('RESET'));
      await tester.pumpAndSettle();
      expect(find.text('Catalog offline'), findsOneWidget);
      repo.queryHandler = (_) async => products;
      await tester.tap(find.text('RETRY'));
      await tester.pumpAndSettle();
      expect(find.byType(SliverGrid), findsOneWidget);
    },
  );

  for (final width in [320.0, 360.0, 390.0, 412.0]) {
    testWidgets(
      'Filter form at $width validates price range, sends cents/size/sort and resets',
      (tester) async {
        final repo = QueryRepository();
        await catalog(tester, repo, width: width);
        await tester.tap(find.text('FILTER & SORT'));
        await tester.pumpAndSettle();
        final min = find.widgetWithText(TextFormField, 'Minimum price (USD)');
        final max = find.widgetWithText(TextFormField, 'Maximum price (USD)');
        await tester.enterText(min, '60');
        await tester.enterText(max, '50');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('APPLY FILTERS'));
        await tester.tap(find.text('APPLY FILTERS'));
        await tester.pumpAndSettle();
        expect(find.text('Maximum must be at least minimum.'), findsWidgets);
        await tester.ensureVisible(min);
        await tester.enterText(min, '35.00');
        await tester.enterText(max, '65.00');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        final size = find.widgetWithText(
          DropdownButtonFormField<String>,
          'Size',
        );
        await tester.ensureVisible(size);
        await tester.tap(size);
        await tester.pumpAndSettle();
        await tester.tap(find.text('M').last);
        await tester.pumpAndSettle();
        final sort = find.widgetWithText(
          DropdownButtonFormField<String>,
          'Sort by',
        );
        await tester.ensureVisible(sort);
        await tester.tap(sort);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Price: high to low').last);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CheckboxListTile>(find.byType(CheckboxListTile))
              .onChanged,
          isNull,
        );
        await tester.ensureVisible(find.text('APPLY FILTERS'));
        await tester.tap(find.text('APPLY FILTERS'));
        await tester.pumpAndSettle();
        final q = repo.queries.last!;
        expect(q.minPrice, 3500);
        expect(q.maxPrice, 6500);
        expect(q.size, 'M');
        expect(q.sort, 'price_desc');
        expect(
          tester
              .widgetList<ProductCard>(find.byType(ProductCard))
              .first
              .product
              .priceInCents,
          5500,
        );
        await tester.tap(find.text('RESET'));
        await tester.pumpAndSettle();
        expect(repo.queries.last!.minPrice, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Wishlist save/remove, empty state and unavailable saved product recovery work',
    (tester) async {
      final wishlist = WishlistController(store: MemoryWishlistStore());
      await wishlist.restore();
      addTearDown(wishlist.dispose);
      final repo = FakeProductRepository();
      final cart = Cart();
      addTearDown(cart.dispose);
      await wishlist.toggle(products.first.id);
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          builder: (_, child) =>
              WishlistScope(controller: wishlist, child: child!),
          home: WishlistScreen(repository: repo, cart: cart),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(products.first.name), findsOneWidget);
      await tester.tap(find.byTooltip('Remove from wishlist'));
      await tester.pumpAndSettle();
      expect(find.text('Your edit starts here.'), findsOneWidget);
      repo.onDetail = (_) async =>
          throw const ApiException('Unavailable', statusCode: 404);
      await wishlist.toggle(products.last.id);
      await tester.pumpAndSettle();
      expect(
        find.text('This saved piece is no longer available.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Remove from wishlist'));
      await tester.pumpAndSettle();
      expect(wishlist.ids, isEmpty);
    },
  );

  testWidgets(
    'Guest can browse and save, same wishlist remains after sign-in and logout',
    (tester) async {
      final auth = createTestAuth(signedIn: false);
      final store = MemoryWishlistStore();
      final wishlist = WishlistController(store: store);
      addTearDown(wishlist.dispose);
      await tester.pumpWidget(
        ModaShop(
          auth: auth,
          repository: FakeProductRepository(),
          wishlist: wishlist,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Explore as a guest'));
      await tester.tap(find.text('Explore as a guest'));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Save to wishlist').first);
      await tester.pumpAndSettle();
      expect(wishlist.ids, [products.first.id]);
      await auth.authenticate(
        register: false,
        email: testUser.email,
        password: 'test password',
      );
      await tester.pumpAndSettle();
      expect(wishlist.ids, [products.first.id]);
      await auth.logout();
      await tester.pumpAndSettle();
      expect(wishlist.ids, [products.first.id]);
      final restored = WishlistController(store: store);
      await restored.restore();
      expect(restored.ids, wishlist.ids);
      restored.dispose();
    },
  );

  testWidgets(
    'Details show actual category, prevent unavailable variants and omit invented description/colors',
    (tester) async {
      final repo = FakeProductRepository()
        ..onDetail = (_) async => Product(
          id: products.first.id,
          name: products.first.name,
          image: products.first.image,
          priceInCents: 3500,
          category: ProductCategory.clothing,
          availableSizes: const [],
        );
      final cart = Cart();
      addTearDown(cart.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: ProductDetailsScreen(
            product: products.first,
            cart: cart,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Clothing'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'ADD TO CART'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('No sizes available'), findsOneWidget);
      expect(find.textContaining('A considered addition'), findsNothing);
      expect(cart.items, isEmpty);
    },
  );
}
