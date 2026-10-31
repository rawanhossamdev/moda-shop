import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/controllers/auth_controller.dart';
import 'package:moda_shop/models/cart.dart';
import 'package:moda_shop/data/products.dart';
import 'package:moda_shop/models/shop_order.dart';
import 'package:moda_shop/repositories/commerce_repository.dart';
import 'package:moda_shop/screens/checkout_screen.dart';
import 'package:moda_shop/screens/order_screens.dart';
import 'package:moda_shop/screens/verify_email_screen.dart';
import 'package:moda_shop/services/products_api.dart';
import 'package:moda_shop/theme/moda_theme.dart';
import 'package:moda_shop/widgets/commerce_scope.dart';
import 'support/fake_auth.dart';
import 'support/fake_commerce.dart';

Future<AuthController> authFixture({
  bool verified = true,
  FakeAuthRepository? repository,
}) async {
  final repo = repository ?? FakeAuthRepository();
  repo.verified = verified;
  final auth = AuthController(repository: repo, store: MemoryTokenStore());
  addTearDown(auth.dispose);
  await auth.authenticate(
    register: false,
    email: testUser.email,
    password: 'test password',
  );
  return auth;
}

Widget app(
  Widget child,
  AuthController auth,
  FakeCommerceRepository repo,
  Cart cart, {
  bool scaled = false,
}) => MaterialApp(
  theme: ModaStyle.theme,
  builder: (context, child) => CommerceScope(
    auth: auth,
    repository: repo,
    cart: cart,
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scaled ? 1.5 : 1),
        viewInsets: scaled
            ? const EdgeInsets.only(bottom: 200)
            : EdgeInsets.zero,
      ),
      child: child!,
    ),
  ),
  home: child,
);
Future<void> shipping(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('choose-address')));
  await tester.tap(find.byKey(const Key('choose-address')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('add-address')));
  await tester.pumpAndSettle();
  for (final field in {
    'fullName': 'MODA Member',
    'mobile': '+201000000000',
    'governorate': 'Cairo',
    'city': 'Maadi',
    'streetAddress': '25 Test street',
    'buildingDetails': 'Building 25, apartment 4',
  }.entries) {
    await tester.ensureVisible(find.byKey(Key(field.key)));
    await tester.enterText(find.byKey(Key(field.key)), field.value);
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('save-address')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('save-address')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('place-order')));
}

class CommerceTransport implements AuthTransport {
  int status = 200;
  dynamic value = {
    'data': {'orders': [], 'nextCursor': null},
  };
  Uri? uri;
  Map<String, String>? headers;
  @override
  Future<ApiResponse> send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    this.uri = uri;
    this.headers = headers;
    return ApiResponse(status, jsonEncode(value));
  }

  @override
  void close() {}
}

void main() {
  testWidgets(
    'Verification validates codes, shows truthful resend errors, and updates account state',
    (tester) async {
      final repo = FakeAuthRepository();
      final auth = await authFixture(verified: false, repository: repo);
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: VerifyEmailScreen(auth: auth),
        ),
      );
      await tester.tap(find.byKey(const Key('verify-submit')));
      await tester.pumpAndSettle();
      expect(repo.verifications, 0);
      await tester.tap(find.text('Request or resend code'));
      await tester.pumpAndSettle();
      repo.error = const ApiException(
        'Verification email is not enabled or configured yet.',
      );
      await tester.tap(find.text('SEND CODE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not enabled or configured'), findsOneWidget);
      repo.error = null;
      await tester.tap(find.text('SEND CODE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('provider accepted'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('verification-code')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('verify-submit')));
      await tester.pumpAndSettle();
      expect(auth.user!.emailVerified, true);
    },
  );
  testWidgets('Unverified checkout is gated and keeps the cart', (
    tester,
  ) async {
    final auth = await authFixture(verified: false);
    final repo = FakeCommerceRepository();
    final cart = Cart()..add(products.first, 'M');
    addTearDown(cart.dispose);
    await tester.pumpWidget(app(CheckoutScreen(cart: cart), auth, repo, cart));
    await tester.pumpAndSettle();
    expect(find.text('VERIFY EMAIL'), findsOneWidget);
    expect(find.byKey(const Key('place-order')), findsNothing);
    expect(cart.count, 1);
    expect(repo.placements, 0);
  });
  for (final width in [320.0, 360.0, 390.0, 412.0]) {
    testWidgets(
      'COD checkout validates shipping and uses server summary at $width with large text',
      (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = await authFixture();
        final repo = FakeCommerceRepository();
        final cart = Cart()..add(products.first, 'M');
        addTearDown(cart.dispose);
        await tester.pumpWidget(
          app(CheckoutScreen(cart: cart), auth, repo, cart, scaled: true),
        );
        await tester.pumpAndSettle();
        final button = find.byKey(const Key('place-order'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(repo.placements, 0);
        await shipping(tester);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(repo.placements, 1);
        expect(repo.submitted.single['expectedTotalInCents'], 3700);
        expect(repo.submitted.single['items'], [
          {'productId': products.first.id, 'size': 'M', 'quantity': 1},
        ]);
        expect(find.byType(OrderDetailScreen), findsOneWidget);
        expect(cart.count, 0);
        expect(find.text('Payment due on delivery'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Network retries retain idempotency key and duplicate taps cannot place twice',
    (tester) async {
      final auth = await authFixture();
      final repo = FakeCommerceRepository();
      final cart = Cart()..add(products.first, 'M');
      addTearDown(cart.dispose);
      final pending = Completer<ShopOrder>();
      repo.onPlace = (_) => pending.future;
      await tester.pumpWidget(
        app(CheckoutScreen(cart: cart), auth, repo, cart),
      );
      await tester.pumpAndSettle();
      await shipping(tester);
      final button = find.byKey(const Key('place-order'));
      final callback = tester.widget<FilledButton>(button).onPressed!;
      callback();
      callback();
      await tester.pump();
      expect(repo.placements, 1);
      expect(cart.count, 1);
      pending.completeError(const ApiException('Offline'));
      await tester.pumpAndSettle();
      repo.onPlace = (_) async => testOrder();
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        repo.submitted[0]['clientRequestId'],
        repo.submitted[1]['clientRequestId'],
      );
      expect(cart.count, 0);
    },
  );
  testWidgets(
    'Historical online orders remain readable but cannot launch online checkout',
    (tester) async {
      final auth = await authFixture();
      final repo = FakeCommerceRepository();
      final cart = Cart()..add(products.first, 'M');
      addTearDown(cart.dispose);
      final order = testOrder(method: 'PAYMOB_CARD', status: 'PENDING');
      repo.current = order;
      cart.rememberCheckout(order.id, cart.items);
      await tester.pumpWidget(
        app(OrderDetailScreen(order: order), auth, repo, cart),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open-paymob')), findsNothing);
      expect(repo.payments, 0);
      expect(cart.count, 1);
      expect(find.text('Awaiting payment confirmation'), findsOneWidget);
      repo.current = testOrder(method: 'PAYMOB_CARD', status: 'PAID');
      await tester.ensureVisible(find.text('REFRESH ORDER STATUS'));
      await tester.tap(find.text('REFRESH ORDER STATUS'));
      await tester.pumpAndSettle();
      expect(find.text('Payment confirmed'), findsOneWidget);
      expect(cart.count, 0);
      cart.add(products.first, 'M');
      await tester.tap(find.text('REFRESH ORDER STATUS'));
      await tester.pumpAndSettle();
      expect(cart.count, 1);
    },
  );
  testWidgets('Order history has loading, empty, error and retry states', (
    tester,
  ) async {
    final auth = await authFixture();
    final repo = FakeCommerceRepository();
    final cart = Cart();
    addTearDown(cart.dispose);
    repo.onHistory = () async => throw const ApiException('Orders unavailable');
    await tester.pumpWidget(app(const OrderHistoryScreen(), auth, repo, cart));
    await tester.pumpAndSettle();
    expect(find.text('Orders unavailable'), findsOneWidget);
    repo.onHistory = null;
    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Your first considered purchase'),
      findsOneWidget,
    );
  });
  test(
    'Commerce API centralizes base URL, validates test checkout and clears invalid sessions',
    () async {
      final auth = await authFixture();
      final transport = CommerceTransport();
      final repo = ApiCommerceRepository(
        auth: auth,
        transport: transport,
        baseUrl: 'http://test.local/api',
      );
      addTearDown(repo.close);
      await repo.history();
      expect(transport.uri.toString(), 'http://test.local/api/orders');
      expect(transport.headers?['Authorization'], 'Bearer test-token');
      transport.value = {
        'data': {
          'checkoutUrl': 'https://example.test/unsafe',
          'testMode': true,
        },
      };
      await expectLater(
        repo.payment(testOrder().id),
        throwsA(isA<ApiException>()),
      );
      transport.status = 401;
      transport.value = {
        'error': {'code': 'UNAUTHENTICATED'},
      };
      await expectLater(repo.history(), throwsA(isA<ApiException>()));
      expect(auth.user, isNull);
    },
  );
}
