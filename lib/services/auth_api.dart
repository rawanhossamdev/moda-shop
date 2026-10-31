import 'dart:convert';
import '../config/api_config.dart';
import 'products_api.dart';

class AuthApi {
  AuthApi({AuthTransport? transport, String baseUrl = ApiConfig.baseUrl})
    : _transport = transport ?? IoApiTransport(),
      _base = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/') {
    if (!['http', 'https'].contains(_base.scheme) ||
        _base.host.isEmpty ||
        _base.hasQuery ||
        _base.hasFragment) {
      throw ArgumentError('API_BASE_URL must be an HTTP(S) API base URL.');
    }
  }
  final AuthTransport _transport;
  final Uri _base;

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final response = await _transport
          .send(
            method,
            _base.resolve('auth/$path'),
            body: body,
            headers: token == null ? null : {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 204) return {};
      if (![200, 201, 202].contains(response.statusCode)) {
        String? recoveryMessage;
        String? errorCode;
        if (path == 'forgot-password' ||
            path == 'reset-password' ||
            path == 'register' ||
            path == 'send-verification' ||
            path == 'verify-email' ||
            path == 'profile' ||
            path == 'change-password') {
          try {
            final error = (jsonDecode(response.body) as Map)['error'];
            final code = error is Map ? error['code'] : null;
            errorCode = code is String ? code : null;
            recoveryMessage = switch (code) {
              'CURRENT_PASSWORD_INCORRECT' =>
                'Your current password is incorrect.',
              'PASSWORD_UNCHANGED' =>
                'Choose a password different from your current password.',
              'ACCOUNT_CHANGED' =>
                'Your account changed during this request. Please sign in again.',
              'EMAIL_RECIPIENT_RESTRICTED' =>
                'Development email can only be sent to the configured Resend account test recipient.',
              'EMAIL_UNAVAILABLE' =>
                'Verification email is not enabled or configured yet.',
              'EMAIL_DELIVERY_FAILED' =>
                'The email provider could not confirm delivery. Please wait a minute and retry.',
              'VERIFY_COOLDOWN' =>
                'Please wait one minute before requesting another code.',
              'INVALID_VERIFICATION' =>
                'The code is incorrect, expired or used. Request a new code after five attempts.',
              'COMPROMISED_PASSWORD' =>
                'This password has appeared in a data breach. Choose a different passphrase.',
              'SCREENING_UNAVAILABLE' =>
                'Password safety checks are unavailable. Please try again.',
              'RECOVERY_UNAVAILABLE' =>
                'Password recovery email is not configured yet. Please contact MODA support.',
              'INVALID_RESET' =>
                'This reset code is invalid or expired. Request a new code.',
              'PASSWORD_POLICY' =>
                'Choose a less predictable password with 8+ characters and at most 72 UTF-8 bytes.',
              _ => null,
            };
          } catch (_) {
            /* Keep server details private. */
          }
        }
        final message = switch (response.statusCode) {
          400 => 'Check your details and try again.',
          401 =>
            path == 'login'
                ? 'Email or password is incorrect.'
                : 'Please sign in again.',
          409 => 'An account with this email already exists.',
          429 => 'Too many attempts. Please try again later.',
          _ => 'Account services are unavailable. Please try again.',
        };
        throw ApiException(
          recoveryMessage ?? message,
          statusCode: response.statusCode,
          code: errorCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['data'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return decoded['data'] as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException(
        'The server returned invalid account data.',
        code: 'INVALID_RESPONSE',
      );
    } catch (_) {
      throw const ApiException(
        'Unable to reach MODA. Check your connection and try again.',
        code: 'NETWORK_ERROR',
      );
    }
  }

  void close() => _transport.close();
}
