import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:moda_shop/controllers/auth_controller.dart';
import 'package:moda_shop/main.dart';
import 'package:moda_shop/repositories/auth_repository.dart';
import 'package:moda_shop/screens/auth_screen.dart';
import 'package:moda_shop/services/auth_api.dart';
import 'package:moda_shop/services/products_api.dart';
import 'package:moda_shop/services/token_store.dart';
import 'package:moda_shop/theme/moda_theme.dart';
import 'support/fake_auth.dart';
import 'support/fake_product_repository.dart';

class FakeAuthTransport implements AuthTransport {
  late Future<ApiResponse> Function(
    String,
    Uri,
    Map<String, String>?,
    Map<String, dynamic>?,
  )
  handler;
  @override
  Future<ApiResponse> send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) => handler(method, uri, headers, body);
  @override
  void close() {}
}

void main() {
  test(
    'Restoration distinguishes transport, response format and HTTP errors',
    () async {
      final transport = FakeAuthTransport();
      final api = AuthApi(transport: transport);
      final repository = ApiAuthRepository(api: api);
      addTearDown(repository.close);
      transport.handler = (_, _, _, _) async =>
          throw StateError('Connection refused');
      await expectLater(
        repository.currentUser('saved-token'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'NETWORK_ERROR'),
        ),
      );
      for (final body in ['not-json', '{"data":{}}']) {
        transport.handler = (_, _, _, _) async => ApiResponse(200, body);
        await expectLater(
          repository.currentUser('saved-token'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'INVALID_RESPONSE',
            ),
          ),
        );
      }
      for (final status in [401, 403, 429, 500, 503]) {
        transport.handler = (_, _, _, _) async => ApiResponse(status, '{}');
        await expectLater(
          repository.currentUser('saved-token'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', status),
          ),
        );
      }
    },
  );

  for (final register in [false, true]) {
    testWidgets(
      '${register ? 'Sign Up' : 'Login'} password icons reflect visibility',
      (tester) async {
        final auth = createTestAuth(signedIn: false);
        await tester.pumpWidget(
          MaterialApp(
            theme: ModaStyle.theme,
            home: register ? SignUpScreen(auth: auth) : LoginScreen(auth: auth),
          ),
        );
        final keys = ['auth-password', if (register) 'auth-confirm'];
        TextField input(String key) => tester.widget<TextField>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(TextField),
          ),
        );
        Finder icon(String key, IconData data) => find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byIcon(data),
        );
        for (final key in keys) {
          expect(input(key).obscureText, isTrue);
          expect(icon(key, Icons.visibility_off_outlined), findsOneWidget);
          await tester.enterText(find.byKey(Key(key)), 'test-password-123');
        }
        for (final key in keys) {
          final toggle = find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(IconButton),
          );
          await tester.ensureVisible(toggle);
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(input(key).obscureText, isFalse);
          expect(icon(key, Icons.visibility_outlined), findsOneWidget);
          expect(icon(key, Icons.visibility_off_outlined), findsNothing);
          expect(input(key).controller!.text, 'test-password-123');
          for (final other in keys.where((other) => other != key)) {
            expect(input(other).obscureText, isTrue);
          }
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(input(key).obscureText, isTrue);
          expect(icon(key, Icons.visibility_off_outlined), findsOneWidget);
          expect(icon(key, Icons.visibility_outlined), findsNothing);
          expect(input(key).controller!.text, 'test-password-123');
        }
      },
    );
  }
  test(
    'Auth API normalizes email, preserves password, and uses the configured base URL',
    () async {
      final transport = FakeAuthTransport();
      transport.handler = (method, uri, headers, body) async {
        expect(method, 'POST');
        expect(uri.toString(), 'http://test.local/api/auth/register');
        expect(body, {
          'name': 'Member',
          'email': 'member@example.test',
          'password': 'untrimmed password ',
        });
        return ApiResponse(
          201,
          jsonEncode({
            'data': {
              'token': 'test-token',
              'user': {
                'id': testUser.id,
                'email': testUser.email,
                'name': testUser.name,
              },
            },
          }),
        );
      };
      final repository = ApiAuthRepository(
        api: AuthApi(transport: transport, baseUrl: 'http://test.local/api'),
      );
      final result = await repository.register(
        name: ' Member ',
        email: ' MEMBER@example.test ',
        password: 'untrimmed password ',
      );
      expect(result.user.email, testUser.email);
      transport.handler = (method, uri, headers, body) async {
        expect(headers, {'Authorization': 'Bearer test-token'});
        expect(uri.path, '/api/auth/me');
        return ApiResponse(
          200,
          jsonEncode({
            'data': {
              'user': {
                'id': testUser.id,
                'email': testUser.email,
                'name': testUser.name,
              },
            },
          }),
        );
      };
      expect((await repository.currentUser(result.token)).id, testUser.id);
    },
  );
  test('Auth HTTP errors are safe, and logout supports 204', () async {
    final transport = FakeAuthTransport();
    final api = AuthApi(transport: transport);
    for (final status in [400, 401, 409, 429, 500]) {
      transport.handler = (_, uri, headers, body) async =>
          ApiResponse(status, 'private server details');
      await expectLater(
        api.request('POST', 'login'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            status,
          ),
        ),
      );
    }
    transport.handler = (_, uri, headers, body) async =>
        const ApiResponse(204, '');
    expect(await api.request('POST', 'logout', token: 'test-token'), isEmpty);
    transport.handler = (_, uri, headers, body) async =>
        const ApiResponse(200, '{}');
    await expectLater(api.request('GET', 'me'), throwsA(isA<ApiException>()));
  });
  test(
    'Persistent login restores through /me and clears expired tokens',
    () async {
      final repository = FakeAuthRepository();
      final store = MemoryTokenStore()..token = 'saved-token';
      final auth = AuthController(repository: repository, store: store);
      addTearDown(auth.dispose);
      await auth.restore();
      expect(auth.user, testUser);
      repository.error = const ApiException('Expired', statusCode: 401);
      await auth.restore();
      expect(auth.user, isNull);
      expect(store.token, isNull);
    },
  );
  test('Network failure preserves saved token for retry', () async {
    final repository = FakeAuthRepository()
      ..error = const ApiException('Offline');
    final store = MemoryTokenStore()..token = 'saved-token';
    final auth = AuthController(repository: repository, store: store);
    addTearDown(auth.dispose);
    await auth.restore();
    expect(store.token, 'saved-token');
    expect(auth.restoreError, isNotNull);
    repository.error = null;
    await auth.restore();
    expect(auth.user, testUser);
    expect(auth.restoreError, isNull);
  });
  test(
    'Login writes token only; logout clears it and revokes the server session',
    () async {
      final repository = FakeAuthRepository();
      final store = MemoryTokenStore();
      final auth = AuthController(repository: repository, store: store);
      addTearDown(auth.dispose);
      await auth.authenticate(
        register: false,
        email: testUser.email,
        password: 'test password',
      );
      expect(store.token, 'test-token');
      expect(auth.user, testUser);
      await auth.logout();
      expect(store.token, isNull);
      expect(auth.user, isNull);
      expect(repository.logouts, 1);
    },
  );
  test(
    'Storage failures fail closed and do not claim successful persistent login',
    () async {
      final repository = FakeAuthRepository();
      final store = MemoryTokenStore()..failWrite = true;
      final auth = AuthController(repository: repository, store: store);
      addTearDown(auth.dispose);
      await expectLater(
        auth.authenticate(
          register: false,
          email: testUser.email,
          password: 'test password',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(auth.user, isNull);
      expect(repository.logouts, 1);
    },
  );
  test(
    'Offline logout clears local session and reports server revocation failure',
    () async {
      final repository = FakeAuthRepository();
      final store = MemoryTokenStore();
      final auth = AuthController(repository: repository, store: store);
      addTearDown(auth.dispose);
      await auth.authenticate(
        register: false,
        email: testUser.email,
        password: 'test password',
      );
      repository.error = const ApiException('Offline');
      expect(await auth.logout(), contains('this device'));
      expect(store.token, isNull);
      expect(auth.user, isNull);
    },
  );
  testWidgets('SecureTokenStore uses the secure storage plugin', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureTokenStore();
    await store.write('plugin-test-token');
    expect(await store.read(), 'plugin-test-token');
    await store.clear();
    expect(await store.read(), isNull);
  });
  testWidgets(
    'Sign Up validates fields and shows duplicate registration errors',
    (tester) async {
      final repository = FakeAuthRepository()
        ..error = const ApiException(
          'An account with this email already exists.',
          statusCode: 409,
        );
      final auth = AuthController(
        repository: repository,
        store: MemoryTokenStore(),
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: SignUpScreen(auth: auth),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('auth-submit')).hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(repository.registrations, 0);
      await tester.enterText(find.byKey(const Key('auth-name')), 'Member');
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        testUser.email,
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'test-password-123',
      );
      await tester.enterText(
        find.byKey(const Key('auth-confirm')),
        'test-password-123',
      );
      await tester.ensureVisible(find.byKey(const Key('auth-submit')));
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('An account with this email already exists.'),
        findsOneWidget,
      );
    },
  );
  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets('Auth screens fit width $width with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = createTestAuth();
      Widget scaled(Widget screen) => MaterialApp(
        theme: ModaStyle.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: screen,
      );
      await tester.pumpWidget(scaled(SignUpScreen(auth: auth)));
      await tester.scrollUntilVisible(
        find.byKey(const Key('auth-submit')).hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(scaled(LoginScreen(auth: auth)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('auth-submit')));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Drawer login, logout, and browsing preserve the existing cart', (
    tester,
  ) async {
    final auth = createTestAuth(signedIn: false);
    await tester.pumpWidget(
      ModaShop(repository: FakeProductRepository(), auth: auth),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.enterText(find.byKey(const Key('auth-email')), testUser.email);
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'test-password-123',
    );
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(auth.user, testUser);
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
    await tester.tap(find.text('ADD TO CART'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    final logout = find.widgetWithText(ListTile, 'Logout');
    await tester.scrollUntilVisible(
      logout.hitTestable(),
      150,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(logout);
    await tester.pumpAndSettle();
    expect(auth.user, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.enterText(find.byKey(const Key('auth-email')), testUser.email);
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'test-password-123',
    );
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open cart'));
    await tester.pumpAndSettle();
    expect(find.text('Ribbed Knit Sweater'), findsOneWidget);
    expect(find.text('Size M'), findsOneWidget);
  });
}
