import 'package:flutter/foundation.dart';
import '../models/auth_user.dart';
import '../repositories/auth_repository.dart';
import '../services/products_api.dart';
import '../services/token_store.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository repository,
    required TokenStore store,
  }) : _repository = repository,
       _store = store;
  final AuthRepository _repository;
  final TokenStore _store;
  AuthUser? _user;
  String? _token;
  String? _restoreError;
  bool _busy = false;
  bool _disposed = false;
  Future<void> _storageTail = Future<void>.value();
  String? _accountMessage;
  int _sessionRevision = 0;
  bool _deferRestore = false;
  AuthUser? get user => _user;
  String? get restoreError => _restoreError;
  bool get busy => _busy;
  String? get accountMessage => _accountMessage;
  Future<T> _secure<T>(Future<T> Function() action) {
    final pending = _storageTail.then((_) => action());
    _storageTail = pending.then<void>((_) {}, onError: (Object _) {});
    return pending;
  }

  Future<void> _invalidate(String? expectedToken) => _secure(() async {
    if (_disposed || _token != expectedToken) return;
    try {
      await _store.clear();
    } catch (_) {
      _restoreError = 'Unable to clear the expired session. Please retry.';
    }
    _user = null;
    _token = null;
    _sessionRevision++;
  });
  Future<void> _saveSession(AuthSession session) async {
    try {
      await _secure(() async {
        if (_disposed) {
          throw const ApiException(
            'This account request has ended. Please sign in again.',
          );
        }
        await _store.write(session.token);
        _deferRestore = false;
        _token = session.token;
        _user = session.user;
        _restoreError = null;
        _accountMessage = session.verificationNotice;
        _sessionRevision++;
      });
    } catch (_) {
      try {
        await _repository.logout(session.token);
      } catch (_) {}
      await _invalidate(_token);
      throw const ApiException(
        'Unable to securely save your session. Please sign in again.',
      );
    }
  }

  Future<T> authorized<T>(Future<T> Function(String token) action) async {
    final token = _token;
    if (token == null || _disposed) {
      throw const ApiException('Please sign in again.', statusCode: 401);
    }
    try {
      final result = await action(token);
      if (_disposed || _token != token) {
        throw const ApiException(
          'Your session changed. Please retry.',
          statusCode: 401,
        );
      }
      return result;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.code == 'ACCOUNT_CHANGED') {
        // A late response from an older token must not erase a replacement
        // session saved by profile editing or a subsequent sign-in.
        await _invalidate(token);
        _notify();
      }
      rethrow;
    }
  }

  Future<void> sendVerification() =>
      _recovery(() => authorized(_repository.sendVerification));
  Future<void> verifyEmail(String code) => _recovery(() async {
    _user = await authorized((token) => _repository.verifyEmail(token, code));
    _accountMessage = 'Your email is verified.';
  });
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    if (_busy || _disposed || _deferRestore) return;
    _busy = true;
    _restoreError = null;
    final revision = _sessionRevision;
    var readingStorage = true;
    _notify();
    try {
      final token = await _secure(
        () => _store.read().timeout(const Duration(seconds: 5)),
      );
      readingStorage = false;
      if (_disposed || revision != _sessionRevision) return;
      if (token == null || token.isEmpty) {
        _token = null;
        _user = null;
        return;
      }
      _token = token;
      final user = await _repository
          .currentUser(token)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw const ApiException(
              'Connection timed out.',
              code: 'NETWORK_ERROR',
            ),
          );
      if (_disposed || revision != _sessionRevision || _token != token) return;
      _token = token;
      _user = user;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _invalidate(_token);
      } else {
        _restoreError = switch (error.statusCode) {
          429 =>
            'Session checks are temporarily limited. Please wait and retry. Your saved session is retained.',
          int status when status >= 500 =>
            'MODA account services are temporarily unavailable. Please retry. Your saved session is retained.',
          null when error.code == 'NETWORK_ERROR' || error.code == null =>
            'Unable to connect to MODA. Check your connection and that the backend is running, then retry. Your saved session is retained.',
          _ =>
            'MODA could not verify your session response. Please retry. Your saved session is retained.',
        };
      }
    } catch (_) {
      _restoreError = readingStorage
          ? 'Unable to access secure session storage. Please retry or sign in again. No saved credentials were removed.'
          : 'MODA could not verify your session response. Please retry. Your saved session is retained.';
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Exit recovery without deleting a possibly valid saved token.
  void signInInstead() {
    if (_busy || _disposed) return;
    _deferRestore = true;
    _sessionRevision++;
    _token = null;
    _user = null;
    _restoreError = null;
    _notify();
  }

  Future<void> authenticate({
    required bool register,
    String name = '',
    required String email,
    required String password,
  }) async {
    if (_busy || _disposed) {
      throw const ApiException('Please wait for the current account request.');
    }
    _busy = true;
    _accountMessage = null;
    _notify();
    try {
      final session = register
          ? await _repository.register(
              name: name,
              email: email,
              password: password,
            )
          : await _repository.login(email: email, password: password);
      await _saveSession(session);
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<String?> logout() async {
    if (_busy) {
      throw const ApiException('Please wait for the current account request.');
    }
    _busy = true;
    _notify();
    try {
      try {
        await _secure(_store.clear);
      } catch (_) {
        throw const ApiException(
          'Unable to clear your saved session. Please retry.',
        );
      }
      final token = _token;
      _token = null;
      _user = null;
      _restoreError = null;
      _accountMessage = null;
      if (token != null) {
        try {
          await _repository.logout(token);
        } catch (_) {
          return 'Signed out on this device. Server session could not be revoked.';
        }
      }
      return null;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> requestPasswordReset(String email) =>
      _recovery(() => _repository.requestPasswordReset(email));
  Future<void> updateProfile({
    required String name,
    required String email,
    required String currentPassword,
  }) => _recovery(() async {
    final oldEmail = _user?.email;
    final session = await authorized(
      (token) => _repository.updateProfile(
        token,
        name: name,
        email: email,
        currentPassword: currentPassword,
      ),
    );
    await _saveSession(session);
    final changedEmail = oldEmail != session.user.email;
    _accountMessage = changedEmail
        ? 'Profile updated. Please verify your new email. ${session.verificationNotice ?? ''}'
              .trim()
        : 'Your profile is updated.';
  });
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String confirmPassword,
  }) => _recovery(() async {
    await authorized(
      (token) => _repository.changePassword(
        token,
        currentPassword: currentPassword,
        password: password,
        confirmPassword: confirmPassword,
      ),
    );
    await _invalidate(_token);
    _accountMessage =
        'Your password is updated. Please sign in with your new password.';
  });

  Future<void> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) => _recovery(
    () => _repository.resetPassword(
      token: token,
      password: password,
      confirmPassword: confirmPassword,
    ),
  );

  Future<void> _recovery(Future<void> Function() action) async {
    if (_busy || _disposed) {
      throw const ApiException('Please wait for the current account request.');
    }
    _busy = true;
    _notify();
    try {
      await action();
    } finally {
      _busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _repository.close();
    super.dispose();
  }
}
