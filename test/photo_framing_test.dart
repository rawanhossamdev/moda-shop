import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/controllers/wishlist_controller.dart';
import 'package:moda_shop/models/product.dart';
import 'package:moda_shop/theme/moda_theme.dart';
import 'package:moda_shop/widgets/product_card.dart';
import 'package:moda_shop/widgets/product_gallery.dart';
import 'package:moda_shop/widgets/product_image.dart';
import 'package:moda_shop/widgets/wishlist_scope.dart';
import 'phase2_test.dart' show MemoryWishlistStore;

Product photoProduct() => Product.fromApi(
  (jsonDecode(File('test/support/catalog_fixture.json').readAsStringSync())
              as List)
          .first
      as Map<String, dynamic>,
);

void main() {
  test(
    'All current studio assets use the same opaque portrait frame',
    () async {
      final entries =
          jsonDecode(
                File(
                  'assets/images/photography/PROVENANCE.json',
                ).readAsStringSync(),
              )
              as List;
      expect(entries.length, 94);
      for (final row in entries) {
        final bytes = File(row['asset'] as String).readAsBytesSync();
        expect(bytes.take(2), [255, 216], reason: row['asset'] as String);
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, 720, reason: row['asset'] as String);
        expect(image.height, 960, reason: row['asset'] as String);
        expect(image.width / image.height, ProductPhotoStyle.aspectRatio);
        image.dispose();
        codec.dispose();
      }
    },
  );
  for (final width in [144.0, 184.0, 300.0]) {
    testWidgets(
      'Card fills its $width portrait frame; corner heart saves without opening details',
      (tester) async {
        final product = photoProduct(),
            wishlist = WishlistController(store: MemoryWishlistStore());
        addTearDown(wishlist.dispose);
        await wishlist.restore();
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ModaStyle.theme,
            home: WishlistScope(
              controller: wishlist,
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    height: width / ProductPhotoStyle.aspectRatio + 90,
                    child: ProductCard(product: product, onTap: () => opened++),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final imageRect = tester.getRect(find.byType(ProductImage));
        expect(imageRect.width, width);
        expect(
          imageRect.height,
          closeTo(width / ProductPhotoStyle.aspectRatio, .001),
        );
        expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
        final heart = find.byTooltip('Save to wishlist'),
            heartRect = tester.getRect(heart);
        expect(heartRect.top, imageRect.top + 4);
        expect(heartRect.right, imageRect.right - 4);
        await tester.tap(heart);
        await tester.pumpAndSettle();
        expect(wishlist.contains(product.id), true);
        expect(opened, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Details gallery uses the full photo width and retains complete portrait framing',
    (tester) async {
      final product = photoProduct();
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: ProductGallery(
                    name: product.name,
                    images: product.colors.first.images,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final page = find.byType(PageView),
          image = find
              .descendant(of: page, matching: find.byType(ProductImage))
              .first;
      expect(tester.getSize(page).width, 320);
      expect(tester.getSize(page).height, 320 / ProductPhotoStyle.aspectRatio);
      expect(tester.getSize(image), tester.getSize(page));
      expect(tester.widget<ProductImage>(image).fit, BoxFit.cover);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
