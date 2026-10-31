import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/controllers/auth_controller.dart';
import 'package:moda_shop/models/auth_user.dart';
import 'package:moda_shop/repositories/auth_repository.dart';
import 'package:moda_shop/services/products_api.dart';
import 'package:moda_shop/services/token_store.dart';

const testUser = AuthUser(
  id: 'test-user',
  email: 'member@example.test',
  name: 'MODA Member',
);

class MemoryTokenStore implements TokenStore {
  String? token;
  bool failWrite = false;
  bool failClear = false;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('Storage failed');
    token = value;
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('Storage failed');
    token = null;
  }
}

class FakeAuthRepository implements AuthRepository {
  String profileName = testUser.name;
  String profileEmail = testUser.email;
  int profileUpdates = 0;
  int passwordChanges = 0;
  Future<void> Function()? onAccountChange;
  @override
  Future<AuthSession> updateProfile(
    String token, {
    required String name,
    required String email,
    required String currentPassword,
  }) async {
    profileUpdates++;
    if (error != null) throw error!;
    await onAccountChange?.call();
    if (email.toLowerCase() != profileEmail) verified = false;
    profileName = name.trim();
    profileEmail = email.trim().toLowerCase();
    return AuthSession(token: 'profile-token', user: current);
  }

  @override
  Future<void> changePassword(
    String token, {
    required String currentPassword,
    required String password,
    required String confirmPassword,
  }) async {
    passwordChanges++;
    if (error != null) throw error!;
    await onAccountChange?.call();
  }

  bool verified = false;
  int verificationRequests = 0;
  int verifications = 0;
  AuthUser get current => AuthUser(
    id: testUser.id,
    email: profileEmail,
    name: profileName,
    emailVerified: verified,
  );
  @override
  Future<void> sendVerification(String token) async {
    verificationRequests++;
    if (error != null) throw error!;
    await onRecovery?.call();
  }

  @override
  Future<AuthUser> verifyEmail(String token, String code) async {
    verifications++;
    if (error != null) throw error!;
    verified = true;
    return current;
  }

  ApiException? error;
  int logins = 0;
  int registrations = 0;
  int logouts = 0;
  int resetRequests = 0;
  int resets = 0;
  Future<void> Function()? onRecovery;
  @override
  Future<void> requestPasswordReset(String email) async {
    resetRequests++;
    if (error != null) throw error!;
    await onRecovery?.call();
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    resets++;
    if (error != null) throw error!;
    await onRecovery?.call();
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    logins++;
    if (error != null) throw error!;
    return AuthSession(
      token: 'test-token',
      user: verified ? current : testUser,
    );
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    registrations++;
    if (error != null) throw error!;
    return AuthSession(
      token: 'test-token',
      user: verified ? current : testUser,
    );
  }

  @override
  Future<AuthUser> currentUser(String token) async {
    if (error != null) throw error!;
    return verified ||
            profileName != testUser.name ||
            profileEmail != testUser.email
        ? current
        : testUser;
  }

  @override
  Future<void> logout(String token) async {
    logouts++;
    if (error != null) throw error!;
  }

  @override
  void close() {}
}

AuthController createTestAuth({bool signedIn = true}) {
  final auth = AuthController(
    repository: FakeAuthRepository(),
    store: MemoryTokenStore()..token = signedIn ? 'test-token' : null,
  );
  addTearDown(auth.dispose);
  return auth;
}
