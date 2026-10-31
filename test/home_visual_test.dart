import 'support/fake_auth.dart';
import 'support/fake_product_repository.dart';
import 'support/fake_commerce.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/main.dart';
import 'package:moda_shop/screens/auth_screen.dart';
import 'package:moda_shop/screens/account_management_screen.dart';
import 'package:moda_shop/screens/checkout_screen.dart';
import 'package:moda_shop/screens/verify_email_screen.dart';
import 'package:moda_shop/screens/order_screens.dart';
import 'package:moda_shop/controllers/auth_controller.dart';
import 'package:moda_shop/models/cart.dart';
import 'package:moda_shop/data/products.dart';
import 'package:moda_shop/widgets/commerce_scope.dart';
import 'package:moda_shop/theme/moda_theme.dart';
import 'package:moda_shop/controllers/wishlist_controller.dart';
import 'package:moda_shop/widgets/wishlist_scope.dart';
import 'package:moda_shop/screens/catalog_screen.dart';
import 'package:moda_shop/screens/wishlist_screen.dart';

/// Optional visual review: supply local font paths and an output directory
/// through --dart-define. Regular test runs do not access host-specific files.
void main() {
  const output = String.fromEnvironment('MODA_CAPTURE_DIR');
  const serif = String.fromEnvironment('MODA_SERIF_FONT');
  const sans = String.fromEnvironment('MODA_SANS_FONT');
  testWidgets(
    'Capture Home at 390 logical pixels for visual review',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
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
        final icons = FontLoader('MaterialIcons');
        icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ModaShop(
            auth: createTestAuth(),
            repository: FakeProductRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Image decoding completes outside the fake test clock.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Future<void> capture(String filename) async {
        // Fully repaint retained editable/ink layers when swapping preview apps.
        void repaint(RenderObject object) {
          object.markNeedsPaint();
          object.visitChildren(repaint);
        }

        repaint(boundaryKey.currentContext!.findRenderObject()!);
        await tester.pump();
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final bitmap = await boundary.toImage(pixelRatio: 2);
          final png = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File(
            '$output/$filename',
          ).writeAsBytes(png!.buffer.asUint8List());
          bitmap.dispose();
        });
      }

      await capture('home-390.png');
      await tester.tap(find.text('EXPLORE COLLECTION'));
      await tester.pumpAndSettle();
      await capture('home-grid-390.png');
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await capture('account-390.png');
      await tester.tap(find.byKey(const Key('account-logout')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await capture('login-390.png');
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await capture('forgot-password-390.png');
      await tester.tap(find.text('I have a reset code'));
      await tester.pumpAndSettle();
      await capture('reset-password-390.png');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('New to MODA? Create an account'));
      await tester.pumpAndSettle();
      expect(find.byType(SignUpScreen), findsOneWidget);
      await capture('signup-390.png');
      final auth = AuthController(
        repository: FakeAuthRepository()..verified = true,
        store: MemoryTokenStore(),
      );
      addTearDown(auth.dispose);
      await auth.authenticate(
        register: false,
        email: testUser.email,
        password: 'test password',
      );
      final commerce = FakeCommerceRepository();
      final wishlist = WishlistController(store: DeviceWishlistStore());
      addTearDown(wishlist.dispose);
      await wishlist.restore();
      final cart = Cart()..add(products.first, 'M');
      addTearDown(cart.dispose);
      Future<void> mount(Widget screen) async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ModaStyle.theme,
              builder: (context, child) => CommerceScope(
                auth: auth,
                repository: commerce,
                cart: cart,
                child: WishlistScope(controller: wishlist, child: child!),
              ),
              home: screen,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount(VerifyEmailScreen(auth: auth));
      await capture('verify-email-390.png');
      await mount(CheckoutScreen(cart: cart));
      await capture('checkout-390.png');
      await tester.ensureVisible(find.byKey(const Key('place-order')));
      await capture('checkout-summary-390.png');
      await mount(OrderDetailScreen(order: testOrder()));
      await capture('order-390.png');
      await mount(AccountManagementScreen(auth: auth));
      await capture('edit-profile-390.png');
      await mount(AccountManagementScreen(auth: auth, changePassword: true));
      await capture('change-password-390.png');
      await mount(
        CatalogScreen(repository: FakeProductRepository(), cart: cart),
      );
      await capture('catalog-390.png');
      await tester.tap(find.text('FILTER & SORT'));
      await tester.pumpAndSettle();
      await capture('filters-390.png');
      await tester.tap(find.byTooltip('Close filters'));
      await tester.pumpAndSettle();
      await wishlist.toggle(products.first.id);
      await mount(
        WishlistScreen(repository: FakeProductRepository(), cart: cart),
      );
      await capture('wishlist-390.png');
      expect(tester.takeException(), isNull);
    },
    skip: output.isEmpty || serif.isEmpty || sans.isEmpty,
  );
}
