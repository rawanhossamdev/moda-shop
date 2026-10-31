import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/controllers/auth_controller.dart';
import 'package:moda_shop/data/products.dart';
import 'package:moda_shop/main.dart';
import 'package:moda_shop/models/cart.dart';
import 'package:moda_shop/screens/auth_screen.dart';
import 'package:moda_shop/screens/home_screen.dart';
import 'package:moda_shop/theme/moda_theme.dart';
import 'package:moda_shop/widgets/account_sheet.dart';
import 'support/fake_auth.dart';
import 'support/fake_product_repository.dart';

void main() {
  testWidgets('Signed-out launch opens Login with working Sign Up navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      ModaShop(
        auth: createTestAuth(signedIn: false),
        repository: FakeProductRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Account'), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    final signUp = find.text('New to MODA? Create an account');
    await tester.ensureVisible(signUp);
    await tester.tap(signUp);
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
  });

  testWidgets(
    'Account sheet shows identity, logs out securely and preserves the cart',
    (tester) async {
      final repository = FakeAuthRepository();
      final store = MemoryTokenStore();
      final auth = AuthController(repository: repository, store: store);
      addTearDown(auth.dispose);
      await auth.authenticate(
        register: false,
        email: testUser.email,
        password: 'test password',
      );
      final cart = Cart()..add(products.first, 'M');
      addTearDown(cart.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: HomeScreen(
            cart: cart,
            repository: FakeProductRepository(),
            auth: auth,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.text(testUser.name), findsOneWidget);
      expect(find.text(testUser.email), findsOneWidget);
      await tester.tap(find.byKey(const Key('account-logout')));
      await tester.pumpAndSettle();
      expect(find.byType(AccountSheet), findsNothing);
      expect(auth.user, isNull);
      expect(store.token, isNull);
      expect(repository.logouts, 1);
      expect(cart.count, 1);
      expect(cart.total, 3500);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open cart'));
      await tester.pumpAndSettle();
      expect(find.text('Ribbed Knit Sweater'), findsOneWidget);
      expect(find.text('Size M'), findsOneWidget);
    },
  );

  testWidgets(
    'Account logout storage failure remains visible and can be retried',
    (tester) async {
      final store = MemoryTokenStore();
      final auth = AuthController(
        repository: FakeAuthRepository(),
        store: store,
      );
      addTearDown(auth.dispose);
      await auth.authenticate(
        register: false,
        email: testUser.email,
        password: 'test password',
      );
      store.failClear = true;
      await tester.pumpWidget(
        ModaShop(auth: auth, repository: FakeProductRepository()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-logout')));
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to clear your saved session. Please retry.'),
        findsOneWidget,
      );
      expect(auth.user, isNotNull);
      store.failClear = false;
      await tester.tap(find.byKey(const Key('account-logout')));
      await tester.pumpAndSettle();
      expect(find.byType(AccountSheet), findsNothing);
      expect(auth.user, isNull);
    },
  );

  for (final width in [320.0, 390.0]) {
    testWidgets('Account header and sheet fit $width with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = createTestAuth();
      await auth.authenticate(
        register: false,
        email: testUser.email,
        password: 'test password',
      );
      await tester.pumpWidget(
        ModaShop(auth: auth, repository: FakeProductRepository()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('account-logout')));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close account'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountSheet), findsNothing);
    });
  }
}
