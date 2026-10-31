import '../models/auth_user.dart';
import '../services/auth_api.dart';
import '../services/products_api.dart';

abstract interface class AuthRepository {
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  });
  Future<AuthSession> login({required String email, required String password});
  Future<AuthUser> currentUser(String token);
  Future<AuthSession> updateProfile(
    String token, {
    required String name,
    required String email,
    required String currentPassword,
  });
  Future<void> changePassword(
    String token, {
    required String currentPassword,
    required String password,
    required String confirmPassword,
  });
  Future<void> logout(String token);
  Future<void> sendVerification(String token);
  Future<AuthUser> verifyEmail(String token, String code);
  Future<void> requestPasswordReset(String email);
  Future<void> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  });
  void close();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({AuthApi? api}) : _api = api ?? AuthApi();
  final AuthApi _api;
  @override
  Future<void> sendVerification(String token) async {
    await _api.request('POST', 'send-verification', token: token);
  }

  @override
  Future<AuthUser> verifyEmail(String token, String code) async => _user(
    await _api.request(
      'POST',
      'verify-email',
      token: token,
      body: {'code': code},
    ),
  );
  AuthSession _session(Map<String, dynamic> value) {
    final token = value['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException(
        'The server returned invalid account data.',
        code: 'INVALID_RESPONSE',
      );
    }
    final delivery = value['verificationEmail'];
    final notice = switch (delivery is Map ? delivery['status'] : null) {
      'accepted' =>
        'The email provider accepted your verification email. Check your inbox and spam folder.',
      'restricted' =>
        'Development email is restricted to the configured Resend account test recipient.',
      'unavailable' || 'failed' =>
        'Verification email was not confirmed. Use Request or resend code when delivery is available.',
      'cooldown' =>
        'Please wait one minute before requesting another verification code.',
      _ => null,
    };
    return AuthSession(
      token: token,
      user: _user(value),
      verificationNotice: notice,
    );
  }

  AuthUser _user(Map<String, dynamic> value) {
    try {
      return AuthUser.fromJson(value['user']);
    } on FormatException {
      throw const ApiException(
        'The server returned invalid account data.',
        code: 'INVALID_RESPONSE',
      );
    }
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async => _session(
    await _api.request(
      'POST',
      'register',
      body: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    ),
  );
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => _session(
    await _api.request(
      'POST',
      'login',
      body: {'email': email.trim().toLowerCase(), 'password': password},
    ),
  );
  @override
  Future<AuthUser> currentUser(String token) async =>
      _user(await _api.request('GET', 'me', token: token));
  @override
  Future<AuthSession> updateProfile(
    String token, {
    required String name,
    required String email,
    required String currentPassword,
  }) async => _session(
    await _api.request(
      'PATCH',
      'profile',
      token: token,
      body: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'currentPassword': currentPassword,
      },
    ),
  );
  @override
  Future<void> changePassword(
    String token, {
    required String currentPassword,
    required String password,
    required String confirmPassword,
  }) async {
    await _api.request(
      'POST',
      'change-password',
      token: token,
      body: {
        'currentPassword': currentPassword,
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
  }

  @override
  Future<void> logout(String token) async {
    await _api.request('POST', 'logout', token: token);
  }

  @override
  void close() => _api.close();

  @override
  Future<void> requestPasswordReset(String email) async {
    await _api.request(
      'POST',
      'forgot-password',
      body: {'email': email.trim().toLowerCase()},
    );
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    await _api.request(
      'POST',
      'reset-password',
      body: {
        'token': token.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
  }
}
