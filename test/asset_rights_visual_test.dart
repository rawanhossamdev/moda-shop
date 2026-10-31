import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/main.dart';
import 'package:moda_shop/models/product.dart';
import 'support/fake_auth.dart';
import 'support/fake_product_repository.dart';

void main() {
  const output = String.fromEnvironment('MODA_CAPTURE_DIR');
  const serif = String.fromEnvironment('MODA_SERIF_FONT');
  const sans = String.fromEnvironment('MODA_SANS_FONT');
  testWidgets(
    'Capture refreshed Home from actual Flutter rendering without private data',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        for (final entry in {
          'serif': serif,
          'Roboto': sans,
          'Ahem': sans,
        }.entries) {
          final loader = FontLoader(entry.key);
          loader.addFont(
            Future.value(
              ByteData.sublistView(await File(entry.value).readAsBytes()),
            ),
          );
          await loader.load();
        }
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      final items =
          (jsonDecode(
                    File(
                      'test/support/catalog_fixture.json',
                    ).readAsStringSync(),
                  )
                  as List)
              .map((row) => Product.fromApi(Map<String, dynamic>.from(row)))
              .toList();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ModaShop(
            auth: createTestAuth(),
            repository: FakeProductRepository(items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      expect(find.text('The art of\neveryday\ndressing.'), findsOneWidget);
      expect(find.textContaining('AI-generated imagery'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output).create(recursive: true);
        await File('$output/home.png').writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.text('EXPLORE COLLECTION'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('new-arrival-section'))).dy,
        closeTo(64, 2),
      );
      expect(tester.takeException(), isNull);
    },
    skip: output.isEmpty || serif.isEmpty || sans.isEmpty,
  );
}
