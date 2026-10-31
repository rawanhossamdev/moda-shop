import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/controllers/auth_controller.dart';
import 'package:moda_shop/main.dart';
import 'package:moda_shop/models/auth_user.dart';
import 'package:moda_shop/screens/account_management_screen.dart';
import 'package:moda_shop/screens/auth_screen.dart';
import 'package:moda_shop/screens/password_recovery_screen.dart';
import 'package:moda_shop/services/products_api.dart';
import 'package:moda_shop/theme/moda_theme.dart';
import 'package:moda_shop/utils/account_validation.dart';
import 'support/fake_auth.dart';
import 'support/fake_product_repository.dart';

Future<AuthController> fixture(
  FakeAuthRepository repository,
  MemoryTokenStore store,
) async {
  final auth = AuthController(repository: repository, store: store);
  addTearDown(auth.dispose);
  await auth.authenticate(
    register: false,
    email: testUser.email,
    password: 'original passphrase',
  );
  return auth;
}

TextField field(WidgetTester tester, String key) => tester.widget<TextField>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)),
);

class PausedClearStore extends MemoryTokenStore {
  final started = Completer<void>();
  final release = Completer<void>();
  final trace = <String>[];
  @override
  Future<void> clear() async {
    trace.add('clear-start');
    started.complete();
    await release.future;
    await super.clear();
    trace.add('clear-end');
  }

  @override
  Future<void> write(String token) async {
    trace.add('write');
    await super.write(token);
  }
}

class PausedRestoreRepository extends FakeAuthRepository {
  final started = Completer<void>();
  final result = Completer<AuthUser>();
  @override
  Future<AuthUser> currentUser(String token) {
    started.complete();
    return result.future;
  }
}

void main() {
  test(
    'An in-flight successful restore cannot resurrect a session invalidated by another request',
    () async {
      final repository = PausedRestoreRepository();
      final store = MemoryTokenStore();
      final auth = await fixture(repository, store);
      final restoring = auth.restore();
      await repository.started.future;
      await expectLater(
        auth.authorized<void>(
          (_) async => throw const ApiException('Expired', statusCode: 401),
        ),
        throwsA(isA<ApiException>()),
      );
      repository.result.complete(testUser);
      await restoring;
      expect(auth.user, isNull);
      expect(store.token, isNull);
    },
  );
  test('Client email/name validation matches supported backend syntax', () {
    expect(AccountValidation.email(' Owner+Tag@Example.Test '), isNull);
    for (final value in [
      '',
      'owner..tag@example.test',
      '.owner@example.test',
      'owner@example..test',
      'owner@-example.test',
      'owner@@example.test',
    ]) {
      expect(AccountValidation.email(value), isNotNull);
    }
    expect(AccountValidation.name(' عضو MODA '), isNull);
    expect(AccountValidation.name('Member\nAdmin'), isNotNull);
  });
  testWidgets(
    'Signup preserves email text, caret and composition through layout rebuilds; Next/Tab follows fields',
    (tester) async {
      final auth = createTestAuth(signedIn: false);
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: SignUpScreen(auth: auth),
        ),
      );
      await tester.enterText(find.byKey(const Key('auth-name')), 'MODA Member');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(field(tester, 'auth-email').focusNode!.hasFocus, isTrue);
      const text = 'Owner+Tag@Example.Test';
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 0, end: 5),
        ),
      );
      await tester.pump();
      tester.view.physicalSize = const Size(800, 650);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pump();
      final email = field(tester, 'auth-email');
      expect(email.controller!.text, text);
      expect(email.controller!.selection.baseOffset, 5);
      expect(
        email.controller!.value.composing,
        const TextRange(start: 0, end: 5),
      );
      expect(email.autocorrect, isFalse);
      expect(email.enableSuggestions, isFalse);
      expect(email.smartQuotesType, SmartQuotesType.disabled);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(field(tester, 'auth-password').focusNode!.hasFocus, isTrue);
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'another considered passphrase',
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(field(tester, 'auth-confirm').focusNode!.hasFocus, isTrue);
      expect(field(tester, 'auth-email').controller!.text, text);
    },
  );
  testWidgets(
    'Recovery preserves punctuation/case and first invalid email receives focus',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: PasswordRecoveryScreen(auth: createTestAuth(signedIn: false)),
        ),
      );
      await tester.tap(find.byKey(const Key('recovery-submit')));
      await tester.pumpAndSettle();
      expect(field(tester, 'recovery-email').focusNode!.hasFocus, isTrue);
      await tester.enterText(
        find.byKey(const Key('recovery-email')),
        'Owner+Test@Example.Test',
      );
      await tester.pumpAndSettle();
      expect(
        field(tester, 'recovery-email').controller!.text,
        'Owner+Test@Example.Test',
      );
      expect(field(tester, 'recovery-email').enableSuggestions, isFalse);
    },
  );
  test(
    'Profile session is securely replaced and restores updated profile after recreation',
    () async {
      final repository = FakeAuthRepository()..verified = true;
      final store = MemoryTokenStore();
      final auth = await fixture(repository, store);
      await auth.updateProfile(
        name: 'Updated member',
        email: 'new@example.test',
        currentPassword: 'original passphrase',
      );
      expect(store.token, 'profile-token');
      expect(auth.user!.emailVerified, isFalse);
      final restarted = AuthController(repository: repository, store: store);
      addTearDown(restarted.dispose);
      await restarted.restore();
      expect(restarted.user!.email, 'new@example.test');
      expect(restarted.user!.name, 'Updated member');
    },
  );
  test('An old request 401 cannot erase a newer profile session', () async {
    final repository = FakeAuthRepository();
    final store = MemoryTokenStore();
    final auth = await fixture(repository, store);
    final pending = Completer<void>();
    final old = auth.authorized((token) => pending.future);
    final expected = expectLater(old, throwsA(isA<ApiException>()));
    await auth.updateProfile(
      name: 'Updated member',
      email: testUser.email,
      currentPassword: '',
    );
    pending.completeError(
      const ApiException('Expired old request', statusCode: 401),
    );
    await expected;
    expect(store.token, 'profile-token');
    expect(auth.user!.name, 'Updated member');
  });
  test(
    'Secure clear/write operations are ordered when an expired request overlaps sign-in',
    () async {
      final repository = FakeAuthRepository();
      final store = PausedClearStore();
      final auth = await fixture(repository, store);
      final old = auth.authorized<void>(
        (_) async => throw const ApiException('Expired', statusCode: 401),
      );
      final expected = expectLater(old, throwsA(isA<ApiException>()));
      await store.started.future;
      final login = auth.authenticate(
        register: false,
        email: testUser.email,
        password: 'original passphrase',
      );
      store.release.complete();
      await expected;
      await login;
      expect(store.token, 'test-token');
      expect(auth.user, isNotNull);
      expect(store.trace, ['write', 'clear-start', 'clear-end', 'write']);
    },
  );
  test(
    'Failure saving a replacement profile token fails closed and revokes the unsaved session',
    () async {
      final repository = FakeAuthRepository();
      final store = MemoryTokenStore();
      final auth = await fixture(repository, store);
      store.failWrite = true;
      await expectLater(
        auth.updateProfile(
          name: 'Updated',
          email: 'new@example.test',
          currentPassword: 'original passphrase',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(auth.user, isNull);
      expect(store.token, isNull);
      expect(repository.logouts, 1);
    },
  );
  test(
    'Wrong current password keeps the session; confirmed password change clears it securely',
    () async {
      final repository = FakeAuthRepository();
      final store = MemoryTokenStore();
      final auth = await fixture(repository, store);
      repository.error = const ApiException(
        'Your current password is incorrect.',
        statusCode: 403,
        code: 'CURRENT_PASSWORD_INCORRECT',
      );
      await expectLater(
        auth.changePassword(
          currentPassword: 'wrong',
          password: 'new considered passphrase',
          confirmPassword: 'new considered passphrase',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(auth.user, isNotNull);
      expect(store.token, 'test-token');
      repository.error = null;
      await auth.changePassword(
        currentPassword: 'original passphrase',
        password: 'new considered passphrase',
        confirmPassword: 'new considered passphrase',
      );
      expect(auth.user, isNull);
      expect(store.token, isNull);
      expect(auth.accountMessage, contains('password is updated'));
    },
  );
  for (final width in [320.0, 360.0, 390.0, 412.0]) {
    testWidgets(
      'Profile editing at $width supports keyboard insets, validation and successful saving',
      (tester) async {
        tester.view.physicalSize = Size(width, 820);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = FakeAuthRepository()..verified = true;
        final auth = await fixture(repository, MemoryTokenStore());
        await tester.pumpWidget(
          MaterialApp(
            theme: ModaStyle.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
                viewInsets: const EdgeInsets.only(bottom: 180),
              ),
              child: child!,
            ),
            home: AccountManagementScreen(auth: auth),
          ),
        );
        await tester.enterText(
          find.byKey(const Key('profile-name')),
          'Updated member',
        );
        await tester.enterText(
          find.byKey(const Key('profile-email')),
          'New+Address@Example.Test',
        );
        final save = find.byKey(const Key('account-save'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(repository.profileUpdates, 0);
        expect(
          field(tester, 'account-current-password').focusNode!.hasFocus,
          isTrue,
        );
        await tester.enterText(
          find.byKey(const Key('account-current-password')),
          'original passphrase',
        );
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(repository.profileUpdates, 1);
        expect(auth.user!.email, 'new+address@example.test');
        expect(auth.user!.emailVerified, isFalse);
        expect(find.textContaining('Profile updated.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Profile requests prevent duplicate submission and display safe errors',
    (tester) async {
      final repository = FakeAuthRepository();
      final auth = await fixture(repository, MemoryTokenStore());
      final pending = Completer<void>();
      repository.onAccountChange = () => pending.future;
      await tester.pumpWidget(
        MaterialApp(
          theme: ModaStyle.theme,
          home: AccountManagementScreen(auth: auth),
        ),
      );
      final save = find.byKey(const Key('account-save'));
      await tester.ensureVisible(save);
      final callback = tester.widget<FilledButton>(save).onPressed!;
      callback();
      callback();
      await tester.pump();
      expect(repository.profileUpdates, 1);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      pending.completeError(
        const ApiException(
          'An account with this email already exists.',
          statusCode: 409,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('An account with this email already exists.'),
        findsOneWidget,
      );
      expect(auth.user, isNotNull);
    },
  );
  testWidgets(
    'Password change fields toggle correctly and successful change returns the app to root Login',
    (tester) async {
      final repository = FakeAuthRepository();
      final store = MemoryTokenStore();
      final auth = await fixture(repository, store);
      await tester.pumpWidget(
        ModaShop(auth: auth, repository: FakeProductRepository()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('change-password')));
      await tester.tap(find.byKey(const Key('change-password')));
      await tester.pumpAndSettle();
      for (final entry in {
        'account-current-password': 'original passphrase',
        'account-new-password': 'new considered passphrase',
        'account-confirm-password': 'new considered passphrase',
      }.entries) {
        final input = find.byKey(Key(entry.key));
        expect(field(tester, entry.key).obscureText, isTrue);
        await tester.enterText(input, entry.value);
        final off = find.descendant(
          of: input,
          matching: find.byIcon(Icons.visibility_off_outlined),
        );
        await tester.ensureVisible(off);
        await tester.tap(off);
        await tester.pumpAndSettle();
        expect(field(tester, entry.key).obscureText, isFalse);
        await tester.tap(
          find.descendant(
            of: input,
            matching: find.byIcon(Icons.visibility_outlined),
          ),
        );
        await tester.pumpAndSettle();
        expect(field(tester, entry.key).obscureText, isTrue);
        expect(field(tester, entry.key).controller!.text, entry.value);
      }
      await tester.ensureVisible(find.byKey(const Key('account-save')));
      await tester.tap(find.byKey(const Key('account-save')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(store.token, isNull);
      expect(find.textContaining('Your password is updated.'), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );
      expect(repository.passwordChanges, 1);
    },
  );
}
