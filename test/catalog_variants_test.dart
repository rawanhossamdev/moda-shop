import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/models/cart.dart';
import 'package:moda_shop/models/product.dart';
import 'package:moda_shop/models/catalog_query.dart';
import 'package:moda_shop/screens/product_details_screen.dart';
import 'package:moda_shop/screens/product_image_screen.dart';
import 'package:moda_shop/screens/home_screen.dart';
import 'package:moda_shop/screens/catalog_screen.dart';
import 'package:moda_shop/screens/checkout_screen.dart';
import 'package:moda_shop/screens/order_screens.dart';
import 'package:moda_shop/widgets/product_gallery.dart';
import 'package:moda_shop/widgets/product_image.dart';
import 'package:moda_shop/theme/moda_theme.dart';
import 'cart_persistence_test.dart' show MemoryLocalStore;
import 'commerce_test.dart' show app, authFixture;
import 'support/fake_product_repository.dart';
import 'support/fake_commerce.dart';

List<Map<String, dynamic>> catalogJson() =>
    (jsonDecode(File('test/support/catalog_fixture.json').readAsStringSync())
            as List)
        .cast<Map<String, dynamic>>();
List<Product> catalog() => catalogJson().map(Product.fromApi).toList();
ProductVariant choice(Product product, String color, String size) =>
    product.variants.firstWhere(
      (v) =>
          v.colorId == product.colors.firstWhere((c) => c.key == color).id &&
          v.size == size,
    );
Widget detail(Product product, Cart cart) => MaterialApp(
  theme: ModaStyle.theme,
  home: ProductDetailsScreen(
    product: product,
    cart: cart,
    repository: FakeProductRepository(items: [product]),
  ),
);

void main() {
  testWidgets(
    'Success SnackBar auto-dismisses and repeated cart adds replace queued messages',
    (tester) async {
      final dress = catalog().firstWhere((p) => p.id == 'wrap-midi-dress');
      final cart = Cart();
      addTearDown(cart.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(detail(dress, cart));
      await tester.pumpAndSettle();

      Future<void> addSelectedVariant() async {
        await tester.tap(find.text('ADD TO CART'));
        await tester.pump();
      }

      await addSelectedVariant();
      expect(
        find.text('Wrap Midi Dress · Dusty Rose / Size M added to cart'),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 600));
      await addSelectedVariant();
      await tester.pump(const Duration(milliseconds: 600));
      await addSelectedVariant();
      await tester.pumpAndSettle();

      expect(cart.count, 3);
      expect(
        find.text('Wrap Midi Dress · Dusty Rose / Size M added to cart'),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.text('Wrap Midi Dress · Dusty Rose / Size M added to cart'),
        findsNothing,
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'Bag variants override a stale clothing-size summary and add the selected color as One Size',
    (tester) async {
      final source = catalogJson().firstWhere((p) => p['id'] == 'shoulder-bag');
      source['availableSizes'] = ['S', 'M', 'L'];
      final bag = Product.fromApi(source);
      expect(bag.availableSizes, ['ONE_SIZE']);
      expect(bag.isOneSize, isTrue);
      final cart = Cart();
      addTearDown(cart.dispose);
      await tester.pumpWidget(detail(bag, cart));
      await tester.pumpAndSettle();
      expect(find.text('One Size'), findsOneWidget);
      for (final size in ['S', 'M', 'L', 'ONE_SIZE']) {
        expect(find.widgetWithText(OutlinedButton, size), findsNothing);
      }
      await tester.ensureVisible(find.byKey(const Key('color-brown')));
      await tester.tap(find.byKey(const Key('color-brown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ADD TO CART'));
      await tester.pumpAndSettle();
      expect(cart.items.single.size, 'ONE_SIZE');
      expect(cart.items.single.colorName, 'Brown');
      expect(cart.items.single.label, 'Brown / One Size');
      expect(cart.total, 6500);
      expect(() => cart.add(bag, 'M'), throwsArgumentError);
    },
  );

  test(
    'Clothing sizes follow available variants and an unavailable one-size item cannot be added',
    () {
      final source = catalogJson().firstWhere((p) => p['id'] == 'knit-sweater');
      for (final v in source['variants'] as List) {
        v['isAvailable'] = v['size'] == 'L';
      }
      final clothing = Product.fromApi(source);
      expect(clothing.availableSizes, ['L']);
      expect(clothing.selectVariant('M'), isNull);
      final bagSource = catalogJson().firstWhere(
        (p) => p['id'] == 'shoulder-bag',
      );
      for (final v in bagSource['variants'] as List) {
        v['isAvailable'] = false;
      }
      final bag = Product.fromApi(bagSource);
      expect(bag.isOneSize, isTrue);
      expect(bag.availableSizes, isEmpty);
      final cart = Cart();
      expect(() => cart.add(bag), throwsArgumentError);
      expect(cart.items, isEmpty);
      cart.dispose();
    },
  );

  test(
    'Expanded API contract has 24 products, all categories and only approved local image paths',
    () {
      final items = catalog();
      expect(items, hasLength(24));
      expect(items.map((p) => p.id).toSet(), hasLength(24));
      expect(
        items.where((p) => p.category == ProductCategory.clothing),
        hasLength(8),
      );
      for (final category in [
        ProductCategory.bags,
        ProductCategory.shoes,
        ProductCategory.jewelry,
        ProductCategory.accessories,
      ]) {
        expect(items.where((p) => p.category == category), hasLength(4));
      }
      for (final product in items) {
        expect(product.isDemo, true);
        expect(
          product.variants.map((v) => v.id).toSet().length,
          product.variants.length,
        );
        for (final color in product.colors) {
          for (final media in color.images) {
            expect(Product.isBundledImage(media.path), true);
            expect(File(media.path).existsSync(), true);
          }
        }
      }
      expect(
        items.firstWhere((p) => p.id == 'classic-loafers').selectVariant('M'),
        isNull,
      );
      expect(
        items.firstWhere((p) => p.id == 'pendant-necklace').isOneSize,
        true,
      );
      expect(sizeLabel('EU_39'), 'EU 39');
    },
  );

  test(
    'Variant cart lines separate colors, merge exact IDs, restore current prices and settle only the purchased variant',
    () async {
      final items = catalog(),
          bag = items.firstWhere((p) => p.id == 'shoulder-bag'),
          store = MemoryLocalStore();
      final cart = Cart(store: store);
      addTearDown(cart.dispose);
      await cart.restore(FakeProductRepository(items: items));
      cart.addVariant(bag, choice(bag, 'black', 'ONE_SIZE'));
      cart.addVariant(bag, choice(bag, 'brown', 'ONE_SIZE'));
      cart.addVariant(bag, choice(bag, 'brown', 'ONE_SIZE'));
      await cart.flush();
      expect(cart.items, hasLength(2));
      expect(cart.count, 3);
      expect(cart.total, 19500);
      expect(cart.items.first.image, bag.image);
      expect(
        cart.items.last.image,
        contains('shoulder-bag_brown_front.jpg'),
      ); // Brown must use its own generated photo.
      final updated = Product.fromApi({
        ...catalogJson().firstWhere((p) => p['id'] == bag.id),
        'priceInCents': 7000,
      });
      final restored = Cart(store: store);
      addTearDown(restored.dispose);
      await restored.restore(FakeProductRepository(items: [updated]));
      expect(restored.total, 21000);
      expect(restored.items.map((i) => i.colorName), ['Black', 'Brown']);
      final body = {
        'clientRequestId': '37a06452-2265-47e8-8349-9716b68093d6',
        'addressId': '27a06452-2265-47e8-8349-9716b68093d6',
        'paymentMethod': 'COD',
        'expectedTotalInCents': 7200,
        'items': [restored.items.last.request..['quantity'] = 1],
      };
      await restored.prepareCheckout('member', body);
      await restored.completeCheckout(
        'member',
        'colored-order',
        (body['items'] as List).cast<Map<String, dynamic>>(),
      );
      expect(restored.items.map((i) => i.quantity), [1, 1]);
      final restarted = Cart(store: store);
      addTearDown(restarted.dispose);
      await restarted.restore(FakeProductRepository(items: [updated]));
      await restarted.completeCheckout(
        'member',
        'colored-order',
        (body['items'] as List).cast<Map<String, dynamic>>(),
      );
      expect(restarted.items.map((i) => i.quantity), [1, 1]);
      expect(
        restarted.items.last.variantId,
        choice(bag, 'brown', 'ONE_SIZE').id,
      );
    },
  );

  test(
    'Legacy size-only saved cart/pending body upgrades to the original color; legacy settlement never consumes another color',
    () async {
      final bag = catalog().firstWhere((p) => p.id == 'shoulder-bag'),
          store = MemoryLocalStore();
      final legacy = {'productId': bag.id, 'size': 'ONE_SIZE', 'quantity': 1};
      final pending = {
        'clientRequestId': '37a06452-2265-47e8-8349-9716b68093d6',
        'addressId': '27a06452-2265-47e8-8349-9716b68093d6',
        'paymentMethod': 'COD',
        'expectedTotalInCents': 6700,
        'items': [legacy],
      };
      store.value = jsonEncode({
        'version': 1,
        'items': [
          {
            ...legacy,
            'variantId': choice(bag, 'brown', 'ONE_SIZE').id,
            'colorId': bag.colors.last.id,
          },
          {...legacy, 'quantity': 2},
        ],
        'pending': {'member': pending},
        'settled': [],
      });
      final cart = Cart(store: store);
      addTearDown(cart.dispose);
      await cart.restore(FakeProductRepository(items: [bag]));
      expect(cart.items.map((i) => i.colorName), ['Brown', 'Black']);
      expect(cart.pendingCheckout('member'), pending);
      await cart.completeCheckout('member', 'legacy-order', [legacy]);
      expect(cart.items.map((i) => i.quantity), [1, 1]);
      expect(cart.items.first.colorName, 'Brown');
    },
  );

  test(
    'An unavailable saved color variant is removed without substituting the default color',
    () async {
      final bag = catalog().firstWhere((p) => p.id == 'shoulder-bag'),
          store = MemoryLocalStore();
      final cart = Cart(store: store);
      addTearDown(cart.dispose);
      await cart.restore(FakeProductRepository(items: [bag]));
      cart.addVariant(bag, choice(bag, 'brown', 'ONE_SIZE'));
      await cart.flush();
      final json = catalogJson().firstWhere((p) => p['id'] == bag.id);
      json['variants'] = (json['variants'] as List)
          .map(
            (v) => {
              ...(v as Map<String, dynamic>),
              'isAvailable': !(v['colorId'] as String).endsWith(':brown'),
            },
          )
          .toList();
      final restored = Cart(store: store);
      addTearDown(restored.dispose);
      await restored.restore(
        FakeProductRepository(items: [Product.fromApi(json)]),
      );
      expect(restored.items, isEmpty);
      expect(restored.notice, contains('1 unavailable'));
    },
  );

  testWidgets(
    'Gallery swipes, thumbnails, fullscreen index and color switching use only that color images',
    (tester) async {
      final sweater = catalog().first, cart = Cart();
      addTearDown(cart.dispose);
      await tester.pumpWidget(detail(sweater, cart));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.drag(find.byType(PageView).first, const Offset(-350, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('gallery-thumbnail-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gallery-thumbnail-0')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('gallery-thumbnail-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gallery-thumbnail-1')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.ensureVisible(find.byType(ProductGallery));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('product-image-fullscreen')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProductImageScreen), findsOneWidget);
      expect(find.textContaining('2 / 3'), findsOneWidget);
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
            .maxScale,
        5,
      );
      await tester.drag(find.byType(PageView).first, const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 / 3'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('color-mocha')));
      await tester.tap(find.byKey(const Key('color-mocha')));
      await tester.pumpAndSettle();
      expect(find.text('COLOR / Mocha'), findsOneWidget);
      expect(
        find.text('Mocha / AI-generated demo product / front'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'M'))
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'S'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'S'));
      await tester.pump();
      await tester.tap(find.text('ADD TO CART'));
      await tester.pumpAndSettle();
      expect(cart.items.single.colorName, 'Mocha');
      expect(cart.items.single.size, 'S');
      expect(cart.items.single.image, contains('_mocha_'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Image-less color shows an honest fallback and still adds the valid one-size variant',
    (tester) async {
      final source = catalogJson().firstWhere((p) => p['id'] == 'shoulder-bag');
      for (final color in source['colors'] as List) {
        if (color['key'] == 'brown') color['images'] = [];
      }
      final bag = Product.fromApi(source), cart = Cart();
      addTearDown(cart.dispose);
      await tester.pumpWidget(detail(bag, cart));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('color-brown')));
      await tester.tap(find.byKey(const Key('color-brown')));
      await tester.pumpAndSettle();
      expect(find.text('No approved images for Brown.'), findsOneWidget);
      expect(find.byType(ProductImage), findsNothing);
      await tester.tap(find.text('ADD TO CART'));
      await tester.pumpAndSettle();
      expect(cart.items.single.colorName, 'Brown');
      expect(cart.items.single.size, 'ONE_SIZE');
      expect(cart.items.single.image, isEmpty);
    },
  );

  testWidgets(
    'Footwear color/size matrix disables unavailable EU 38 and accepts EU 39',
    (tester) async {
      final shoe = catalog().firstWhere((p) => p.id == 'classic-loafers'),
          cart = Cart();
      addTearDown(cart.dispose);
      await tester.pumpWidget(detail(shoe, cart));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'EU 38'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'EU 38'));
      await tester.ensureVisible(find.byKey(const Key('color-brown')));
      await tester.tap(find.byKey(const Key('color-brown')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'EU 38'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'EU 39'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'EU 39'));
      await tester.pump();
      expect(find.text('SIZE — EU 39'), findsOneWidget);
      await tester.tap(find.text('ADD TO CART'));
      await tester.pumpAndSettle();
      expect(cart.items.single.size, 'EU_39');
      expect(cart.items.single.colorName, 'Brown');
    },
  );

  testWidgets(
    'Five categories work from home and with search/size/sort filters in catalog',
    (tester) async {
      final items = catalog(),
          cart = Cart(),
          repository = FakeProductRepository(items: catalog());
      addTearDown(cart.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: HomeScreen(cart: cart, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ActionChip, 'Shoes'));
      await tester.tap(find.widgetWithText(ActionChip, 'Shoes'));
      await tester.pumpAndSettle();
      expect(find.text('SHOES'), findsOneWidget);
      expect(
        tester
            .widget<SliverGrid>(find.byType(SliverGrid))
            .delegate
            .estimatedChildCount,
        4,
      );
      final filtered = await repository.fetchProducts(
        query: const CatalogQuery(
          category: 'shoes',
          search: 'loafer',
          size: 'EU_39',
          sort: 'price_desc',
        ),
      );
      expect(filtered.single.id, 'classic-loafers');
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: CatalogScreen(cart: cart, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      for (final category in [
        'Clothing',
        'Bags',
        'Shoes',
        'Jewelry',
        'Accessories',
      ]) {
        expect(find.widgetWithText(ChoiceChip, category), findsOneWidget);
      }
      expect(items.length, 24);
    },
  );

  testWidgets(
    'Mixed-color order history and details remain readable with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = await authFixture(),
          repo = FakeCommerceRepository(),
          cart = Cart();
      addTearDown(cart.dispose);
      final data = {
        ...repo.current.data,
        'items': [
          {
            ...repo.current.items.first,
            'colorName': 'Cream',
            'colorId': 'knit-sweater:cream',
            'variantId': 'knit-sweater:cream:M',
          },
          {
            ...repo.current.items.first,
            'colorName': 'Mocha',
            'size': 'L',
            'colorId': 'knit-sweater:mocha',
            'variantId': 'knit-sweater:mocha:L',
          },
        ],
      };
      repo.onHistory = () async => {
        'orders': [data],
        'nextCursor': null,
      };
      await tester.pumpWidget(
        app(const OrderHistoryScreen(), auth, repo, cart, scaled: true),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Cream / Size M'), findsOneWidget);
      expect(find.textContaining('Mocha / Size L'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Failed gallery image is handled without an unhandled asset exception',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: ProductGallery(
                name: 'Missing asset',
                images: const [
                  ProductMedia(
                    id: 'missing',
                    path: 'assets/images/catalog/not-supplied.png',
                    kind: 'photo',
                    label: 'Missing approved image',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Color variants, footwear and galleries fit $width with large text',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final shoe = catalog().firstWhere((p) => p.id == 'classic-loafers'),
            cart = Cart();
        addTearDown(cart.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ModaStyle.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: ProductDetailsScreen(
              product: shoe,
              cart: cart,
              repository: FakeProductRepository(items: [shoe]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('color-brown')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('color-brown')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(OutlinedButton, 'EU 39'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'EU 39'));
        await tester.pump();
        await tester.tap(find.text('ADD TO CART'));
        await tester.pumpAndSettle();
        expect(cart.items.single.colorName, 'Brown');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Colored cart flows into COD checkout and immutable variant snapshots',
    (tester) async {
      final items = catalog(),
          bag = items.firstWhere((p) => p.id == 'shoulder-bag'),
          cart = Cart();
      addTearDown(cart.dispose);
      cart.addVariant(bag, choice(bag, 'black', 'ONE_SIZE'));
      cart.addVariant(bag, choice(bag, 'brown', 'ONE_SIZE'));
      final auth = await authFixture(),
          repo = FakeCommerceRepository()..catalog = items;
      await repo.saveAddress({
        'fullName': 'MODA Member',
        'mobile': '01012345678',
        'governorate': 'Cairo',
        'city': 'Maadi',
        'streetAddress': '25 Test street',
        'buildingDetails': 'Apartment 4',
        'deliveryNotes': '',
        'isDefault': true,
      });
      await tester.pumpWidget(
        app(CheckoutScreen(cart: cart), auth, repo, cart),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Black / One Size'), findsOneWidget);
      expect(find.textContaining('Brown / One Size'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('place-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('place-order')));
      await tester.pumpAndSettle();
      expect(cart.items, isEmpty);
      expect(repo.current.items.map((i) => i['colorName']), ['Black', 'Brown']);
      expect(
        repo.current.items.last['productImage'],
        contains('shoulder-bag_brown_front.jpg'),
      );
      expect(repo.current.items.every((i) => i['variantId'] != null), true);
    },
  );

  test(
    'Colorless variants work and a retired default never silently converts a legacy cart to another color',
    () async {
      final source = catalogJson().first;
      final plain = Product.fromApi({
        ...source,
        'colors': [],
        'defaultColorId': null,
        'images': (source['colors'] as List).first['images'],
        'availableSizes': ['S'],
        'variants': [
          {'id': 'plain:S', 'colorId': null, 'size': 'S', 'isAvailable': true},
        ],
      });
      expect(plain.availableColors, isEmpty);
      expect(plain.selectVariant('S')!.id, 'plain:S');
      expect(plain.galleryFor(null), isNotEmpty);
      final bagSource = catalogJson().firstWhere(
        (p) => p['id'] == 'shoulder-bag',
      );
      bagSource['variants'] = (bagSource['variants'] as List)
          .map(
            (v) => {
              ...(v as Map<String, dynamic>),
              'isAvailable': !(v['colorId'] as String).endsWith(':black'),
            },
          )
          .toList();
      final bag = Product.fromApi(bagSource), store = MemoryLocalStore();
      store.value = jsonEncode({
        'version': 1,
        'items': [
          {'productId': bag.id, 'size': 'ONE_SIZE', 'quantity': 1},
        ],
        'pending': {},
        'settled': [],
      });
      final cart = Cart(store: store);
      addTearDown(cart.dispose);
      await cart.restore(FakeProductRepository(items: [bag]));
      expect(cart.items, isEmpty);
      expect(cart.notice, contains('unavailable'));
    },
  );
}
