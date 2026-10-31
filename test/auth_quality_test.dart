import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/controllers/auth_controller.dart';
import 'package:moda_shop/models/password_policy.dart';
import 'package:moda_shop/repositories/auth_repository.dart';
import 'package:moda_shop/screens/auth_screen.dart';
import 'package:moda_shop/screens/password_recovery_screen.dart';
import 'package:moda_shop/services/auth_api.dart';
import 'package:moda_shop/services/products_api.dart';
import 'package:moda_shop/theme/moda_theme.dart';
import 'support/fake_auth.dart';

class RecoveryTransport implements AuthTransport {
  int status = 202;
  String code = 'RECOVERY_UNAVAILABLE';
  String? path;
  Map<String, dynamic>? sent;
  @override
  Future<ApiResponse> send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    path = uri.path;
    sent = body;
    return ApiResponse(
      status,
      jsonEncode(
        status == 202
            ? {
                'data': {'message': 'Generic accepted message'},
              }
            : {
                'error': {'code': code, 'message': 'private server details'},
              },
      ),
    );
  }

  @override
  void close() {}
}

void main() {
  test(
    'Policy accepts 8+ characters without composition rules and estimates strength',
    () {
      expect(PasswordPolicy.problem('silkfern'), isNull);
      expect(PasswordPolicy.problem('a long lowercase passphrase'), isNull);
      for (final value in [
        '',
        'short',
        'password',
        'PASSWORD123!',
        'aaaaaaaa',
        '🔒' * 19,
      ]) {
        expect(PasswordPolicy.problem(value), isNotNull);
      }
      expect(PasswordPolicy.strength('silkfern'), 1);
      expect(PasswordPolicy.strength('silkferncloud'), 2);
      expect(PasswordPolicy.strength('linen breeze in autumn'), 3);
    },
  );

  testWidgets(
    'Sign Up provides live strength, common password and matching feedback',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: SignUpScreen(auth: createTestAuth(signedIn: false)),
        ),
      );
      final password = find.byKey(const Key('auth-password'));
      final confirm = find.byKey(const Key('auth-confirm'));
      await tester.enterText(password, 'short');
      await tester.pumpAndSettle();
      expect(find.textContaining('Use at least 8 characters'), findsOneWidget);
      expect(find.text('Password strength: Weak'), findsOneWidget);
      await tester.enterText(password, 'password');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('This password is too common'),
        findsOneWidget,
      );
      await tester.enterText(password, 'silkferncloud');
      await tester.pumpAndSettle();
      expect(find.text('Password strength: Medium'), findsOneWidget);
      await tester.enterText(confirm, 'different');
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await tester.enterText(confirm, 'silkferncloud');
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsNothing);
      await tester.enterText(password, 'linen breeze in autumn');
      await tester.pumpAndSettle();
      expect(find.text('Password strength: Strong'), findsOneWidget);
      expect(find.text('Passwords do not match.'), findsOneWidget);
    },
  );

  test(
    'Recovery API uses existing base URL and never exposes provider errors',
    () async {
      final transport = RecoveryTransport();
      final repository = ApiAuthRepository(
        api: AuthApi(transport: transport, baseUrl: 'http://test.local/api'),
      );
      await repository.requestPasswordReset(' MEMBER@EXAMPLE.TEST ');
      expect(transport.path, '/api/auth/forgot-password');
      expect(transport.sent, {'email': 'member@example.test'});
      transport.status = 503;
      await expectLater(
        repository.requestPasswordReset('member@example.test'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'friendly configuration error',
            contains('not configured'),
          ),
        ),
      );
      transport.status = 403;
      transport.code = 'EMAIL_RECIPIENT_RESTRICTED';
      await expectLater(
        repository.requestPasswordReset('member@example.test'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'development recipient restriction',
            contains('Resend account test recipient'),
          ),
        ),
      );
      transport.status = 400;
      transport.code = 'INVALID_RESET';
      await expectLater(
        repository.resetPassword(
          token: 'code',
          password: 'silkfern',
          confirmPassword: 'silkfern',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'friendly reset error',
            contains('invalid or expired'),
          ),
        ),
      );
      expect(transport.path, '/api/auth/reset-password');
    },
  );

  testWidgets(
    'Forgot Password validates email, reports missing delivery honestly and permits retry',
    (tester) async {
      final repository = FakeAuthRepository()
        ..error = const ApiException(
          'Password recovery email is not configured yet.',
        );
      final auth = AuthController(
        repository: repository,
        store: MemoryTokenStore(),
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: LoginScreen(auth: auth),
        ),
      );
      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.byType(PasswordRecoveryScreen), findsOneWidget);
      final submit = find.byKey(const Key('recovery-submit'));
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(repository.resetRequests, 0);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('recovery-email')),
        testUser.email,
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.textContaining('not configured'), findsOneWidget);
      expect(find.textContaining('If an account exists'), findsNothing);
      repository.error = null;
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.textContaining('If an account exists'), findsOneWidget);
    },
  );

  testWidgets(
    'Recovery prevents duplicate submissions while awaiting the server',
    (tester) async {
      final pending = Completer<void>();
      final repository = FakeAuthRepository()
        ..onRecovery = () => pending.future;
      final auth = AuthController(
        repository: repository,
        store: MemoryTokenStore(),
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: PasswordRecoveryScreen(auth: auth),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('recovery-email')),
        testUser.email,
      );
      final submit = find.byKey(const Key('recovery-submit'));
      final callback = tester.widget<FilledButton>(submit).onPressed!;
      callback();
      callback();
      await tester.pump();
      expect(repository.resetRequests, 1);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    },
  );

  for (final width in [320.0, 360.0, 390.0, 412.0]) {
    testWidgets(
      'Reset form toggles password fields and fits $width with keyboard and large text',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = FakeAuthRepository();
        final auth = AuthController(
          repository: repository,
          store: MemoryTokenStore(),
        );
        addTearDown(auth.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ModaStyle.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
                viewInsets: const EdgeInsets.only(bottom: 240),
              ),
              child: child!,
            ),
            home: PasswordRecoveryScreen(auth: auth),
          ),
        );
        await tester.ensureVisible(find.text('I have a reset code'));
        await tester.tap(find.text('I have a reset code'));
        await tester.pumpAndSettle();
        for (final key in ['recovery-password', 'recovery-confirm']) {
          final field = find.byKey(Key(key));
          TextField input() => tester.widget<TextField>(
            find.descendant(of: field, matching: find.byType(TextField)),
          );
          expect(input().obscureText, isTrue);
          final off = find.descendant(
            of: field,
            matching: find.byIcon(Icons.visibility_off_outlined),
          );
          await tester.ensureVisible(off);
          await tester.tap(off);
          await tester.pumpAndSettle();
          expect(input().obscureText, isFalse);
          final on = find.descendant(
            of: field,
            matching: find.byIcon(Icons.visibility_outlined),
          );
          await tester.tap(on);
          await tester.pumpAndSettle();
          expect(input().obscureText, isTrue);
          await tester.enterText(field, 'linen breeze in autumn');
        }
        await tester.enterText(
          find.byKey(const Key('recovery-code')),
          'a' * 43,
        );
        final submit = find.byKey(const Key('recovery-submit'));
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(repository.resets, 1);
        expect(find.text('BACK TO SIGN IN'), findsOneWidget);
        expect(auth.user, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
