import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/models/product.dart';
import 'package:moda_shop/theme/moda_theme.dart';
import 'package:moda_shop/widgets/category_strip.dart';
import 'package:moda_shop/widgets/demo_catalog_notice.dart';
import 'package:moda_shop/widgets/product_card.dart';
import 'package:moda_shop/widgets/product_image.dart';

void main() {
  for (final scale in [1.0, 1.5]) {
    testWidgets(
      'Readable aligned cards and visible demo disclosure at text scale $scale',
      (tester) async {
        final rows =
            (jsonDecode(
                      File(
                        'test/support/catalog_fixture.json',
                      ).readAsStringSync(),
                    )
                    as List)
                .take(2)
                .map((row) => Product.fromApi(Map<String, dynamic>.from(row)))
                .toList();
        await tester.pumpWidget(
          MaterialApp(
            theme: ModaStyle.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    const DemoCatalogNotice(),
                    Row(
                      children: [
                        for (final product in rows)
                          SizedBox(
                            width: 144,
                            height:
                                144 / ProductPhotoStyle.aspectRatio +
                                ProductCard.textExtent(context),
                            child: ProductCard(product: product, onTap: () {}),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final product in rows) {
          expect(
            tester.widget<Text>(find.text(product.name)).style!.fontSize,
            16,
          );
          expect(
            tester.widget<Text>(find.text(product.price)).style!.fontSize,
            18,
          );
        }
        expect(find.textContaining('/ sample'), findsNothing);
        expect(find.textContaining('No real merchandise.'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text(rows.first.price)).dy,
          closeTo(tester.getTopLeft(find.text(rows.last.price)).dy, .001),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'Category arrows discover hidden choices and work with reduced motion $reducedMotion',
      (tester) async {
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: ModaStyle.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reducedMotion),
              child: child!,
            ),
            home: Scaffold(
              body: SizedBox(
                width: 240,
                child: CategoryStrip(
                  child: Row(
                    children: [
                      for (final label in [
                        'Clothing',
                        'Bags',
                        'Shoes',
                        'Jewelry',
                        'Accessories',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(label),
                            onPressed: () => selected = label,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('More categories'), findsOneWidget);
        expect(find.byTooltip('Previous categories'), findsNothing);
        for (
          var i = 0;
          i < 10 && find.byTooltip('More categories').evaluate().isNotEmpty;
          i++
        ) {
          await tester.tap(find.byTooltip('More categories'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Accessories').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Accessories'));
        expect(selected, 'Accessories');
        expect(find.byTooltip('Previous categories'), findsOneWidget);
        for (
          var i = 0;
          i < 10 && find.byTooltip('Previous categories').evaluate().isNotEmpty;
          i++
        ) {
          await tester.tap(find.byTooltip('Previous categories'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Clothing').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
