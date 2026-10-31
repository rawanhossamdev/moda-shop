import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/controllers/auth_controller.dart';
import 'package:moda_shop/main.dart';
import 'package:moda_shop/screens/auth_screen.dart';
import 'package:moda_shop/screens/home_screen.dart';
import 'package:moda_shop/screens/product_details_screen.dart';
import 'package:moda_shop/services/products_api.dart';
import 'package:moda_shop/widgets/session_check.dart';
import 'support/fake_auth.dart';
import 'support/fake_product_repository.dart';

class DeferredTokenStore extends MemoryTokenStore {
  final pending = Completer<String?>();
  @override
  Future<String?> read() => pending.future;
}

class UnavailableTokenStore extends MemoryTokenStore {
  @override
  Future<String?> read() async => throw StateError('Storage unavailable');
}

void main() {
  for (final failure in [
    const ApiException('Offline', code: 'NETWORK_ERROR'),
    const ApiException('Unavailable', statusCode: 503),
    const ApiException('Invalid response', code: 'INVALID_RESPONSE'),
    const ApiException('Rate limit', statusCode: 429),
  ]) {
    testWidgets(
      'Startup ${failure.code ?? failure.statusCode} retains token and permits Login',
      (tester) async {
        final store = MemoryTokenStore()..token = 'saved-token';
        final repository = FakeAuthRepository()..error = failure;
        final auth = AuthController(repository: repository, store: store);
        addTearDown(auth.dispose);
        await tester.pumpWidget(
          ModaShop(auth: auth, repository: FakeProductRepository()),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SessionCheck), findsOneWidget);
        expect(auth.restoreError, contains('retained'));
        await tester.tap(find.text('SIGN IN INSTEAD'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(store.token, 'saved-token');
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        repository.error = null;
        await auth.authenticate(
          register: false,
          email: testUser.email,
          password: 'test password',
        );
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(store.token, isNot('saved-token'));
      },
    );
  }

  testWidgets('Secure storage read failure is distinct and can leave startup', (
    tester,
  ) async {
    final store = UnavailableTokenStore()..token = 'saved-token';
    final auth = AuthController(repository: FakeAuthRepository(), store: store);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ModaShop(auth: auth, repository: FakeProductRepository()),
    );
    await tester.pumpAndSettle();
    expect(auth.restoreError, contains('secure session storage'));
    await tester.tap(find.text('SIGN IN INSTEAD'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(store.token, 'saved-token');
  });

  test(
    'Invalid session clear failure reports storage error; retry clears only token',
    () async {
      final store = MemoryTokenStore()
        ..token = 'legacy-token'
        ..failClear = true;
      final repository = FakeAuthRepository()
        ..error = const ApiException('Invalid', statusCode: 401);
      final auth = AuthController(repository: repository, store: store);
      addTearDown(auth.dispose);
      await auth.restore();
      expect(auth.restoreError, contains('Unable to clear'));
      expect(store.token, 'legacy-token');
      store.failClear = false;
      await auth.restore();
      expect(auth.restoreError, isNull);
      expect(store.token, isNull);
      expect(repository.logouts, 0);
    },
  );

  testWidgets(
    'Hung secure storage read times out with a recoverable startup error',
    (tester) async {
      final store = DeferredTokenStore();
      final auth = AuthController(
        repository: FakeAuthRepository(),
        store: store,
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        ModaShop(auth: auth, repository: FakeProductRepository()),
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(auth.restoreError, contains('secure session storage'));
      expect(find.text('SIGN IN INSTEAD'), findsOneWidget);
      store.pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(SessionCheck), findsOneWidget);
    },
  );

  testWidgets(
    'First launch shows only splash until secure storage resolves, then Login',
    (tester) async {
      final store = DeferredTokenStore();
      final auth = AuthController(
        repository: FakeAuthRepository(),
        store: store,
      );
      final products = FakeProductRepository();
      addTearDown(auth.dispose);
      await tester.pumpWidget(ModaShop(auth: auth, repository: products));
      expect(find.byType(SessionCheck), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
      expect(products.listRequests, isEmpty);
      store.pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(products.listRequests, isEmpty);
    },
  );

  testWidgets(
    'Saved valid session opens Home directly and survives app recreation',
    (tester) async {
      final store = MemoryTokenStore()..token = 'saved-token';
      final first = AuthController(
        repository: FakeAuthRepository(),
        store: store,
      );
      addTearDown(first.dispose);
      await tester.pumpWidget(
        ModaShop(auth: first, repository: FakeProductRepository()),
      );
      expect(find.byType(LoginScreen), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      final second = AuthController(
        repository: FakeAuthRepository(),
        store: store,
      );
      addTearDown(second.dispose);
      expect(second.user, isNull);
      await tester.pumpWidget(
        ModaShop(auth: second, repository: FakeProductRepository()),
      );
      expect(find.byType(LoginScreen), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(second.user, testUser);
      expect(store.token, 'saved-token');
    },
  );

  for (final registration in [false, true]) {
    testWidgets(
      'Successful ${registration ? 'Sign Up' : 'Login'} replaces auth navigation with Home',
      (tester) async {
        final auth = createTestAuth(signedIn: false);
        await tester.pumpWidget(
          ModaShop(auth: auth, repository: FakeProductRepository()),
        );
        await tester.pumpAndSettle();
        if (registration) {
          final signUp = find.text('New to MODA? Create an account');
          await tester.ensureVisible(signUp);
          await tester.tap(signUp);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('auth-name')),
            'MODA Member',
          );
        }
        await tester.enterText(
          find.byKey(const Key('auth-email')),
          testUser.email,
        );
        await tester.enterText(
          find.byKey(const Key('auth-password')),
          'test-password-123',
        );
        if (registration) {
          await tester.enterText(
            find.byKey(const Key('auth-confirm')),
            'test-password-123',
          );
        }
        await tester.ensureVisible(find.byKey(const Key('auth-submit')));
        await tester.tap(find.byKey(const Key('auth-submit')));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(SignUpScreen), findsNothing);
        expect(
          Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
          isFalse,
        );
      },
    );
  }

  testWidgets(
    'Logout clears secure storage and replaces Home with root Login',
    (tester) async {
      final store = MemoryTokenStore()..token = 'saved-token';
      final auth = AuthController(
        repository: FakeAuthRepository(),
        store: store,
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        ModaShop(auth: auth, repository: FakeProductRepository()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-logout')));
      await tester.pumpAndSettle();
      expect(store.token, isNull);
      expect(auth.user, isNull);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );
    },
  );

  testWidgets('Invalid or expired saved token clears storage and opens Login', (
    tester,
  ) async {
    final store = MemoryTokenStore()..token = 'invalid-or-expired-token';
    final repository = FakeAuthRepository()
      ..error = const ApiException('Please sign in again.', statusCode: 401);
    final auth = AuthController(repository: repository, store: store);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ModaShop(auth: auth, repository: FakeProductRepository()),
    );
    await tester.pumpAndSettle();
    expect(store.token, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets(
    'Network failure preserves session for retry without flashing Login or Home',
    (tester) async {
      final store = MemoryTokenStore()..token = 'saved-token';
      final repository = FakeAuthRepository()
        ..error = const ApiException('Offline');
      final auth = AuthController(repository: repository, store: store);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        ModaShop(auth: auth, repository: FakeProductRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SessionCheck), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
      expect(store.token, 'saved-token');
      repository.error = null;
      await tester.tap(find.text('RETRY'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Valid resume keeps Product Details; expired resume removes protected route stack',
    (tester) async {
      final repository = FakeAuthRepository();
      final auth = AuthController(
        repository: repository,
        store: MemoryTokenStore()..token = 'saved-token',
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        ModaShop(auth: auth, repository: FakeProductRepository()),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ribbed Knit Sweater').hitTestable(),
        150,

        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('Ribbed Knit Sweater'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('S'));
      await tester.tap(find.text('S'));
      await tester.pump();
      await auth.restore();
      await tester.pumpAndSettle();
      expect(find.byType(ProductDetailsScreen), findsOneWidget);
      expect(find.text('SIZE — S'), findsOneWidget);
      repository.error = const ApiException('Expired', statusCode: 401);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ProductDetailsScreen), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );
    },
  );
}
