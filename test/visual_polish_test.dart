import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/theme/moda_icons.dart';
import 'package:moda_shop/theme/moda_theme.dart';
import 'package:moda_shop/widgets/session_check.dart';

void main() {
  testWidgets(
    'Footwear renders a local vector in default and selected colors',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: const Scaffold(
            body: Row(
              children: [
                ModaIcon(ModaIcons.shoes),
                ModaIcon(ModaIcons.shoes, color: ModaStyle.gold),
              ],
            ),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(ModaIcon),
          matching: find.byType(CustomPaint),
        ),
        findsNWidgets(2),
      );
      expect(find.byIcon(Icons.hiking_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final reduced in [false, true]) {
    testWidgets('Branded session gate respects reduced motion: $reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: const SessionCheck(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 210));
      final opacity = tester
          .widget<Opacity>(find.byType(Opacity).first)
          .opacity;
      expect(opacity, reduced ? equals(1) : allOf(greaterThan(0), lessThan(1)));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
      expect(find.text('Checking your session'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Startup failure retains accessible retry and sign-in controls at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: SessionCheck(
            loading: false,
            message: 'Connection unavailable',
            onRetry: () => retries++,
            onSignIn: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('RETRY'));
      expect(retries, 1);
      expect(find.text('SIGN IN INSTEAD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
