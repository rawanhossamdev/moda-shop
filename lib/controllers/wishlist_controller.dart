import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class WishlistStore {
  Future<String?> read();
  Future<void> write(String value);
}

class DeviceWishlistStore implements WishlistStore {
  final _storage = const FlutterSecureStorage();
  static const key = 'moda_wishlist_v1';
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
}

/// One device-local wishlist, shared across guest/sign-in/sign-out. No account
/// identity or authentication credentials are read or changed here.
class WishlistController extends ChangeNotifier {
  WishlistController({required WishlistStore store}) : _store = store;
  final WishlistStore _store;
  Set<String> _ids = {};
  bool loading = true, saving = false, _disposed = false;
  bool _restoring = false;
  String? error;
  List<String> get ids => List.unmodifiable(_ids);
  bool contains(String id) => _ids.contains(id);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    if (saving || _disposed || _restoring) return;
    _restoring = true;
    loading = true;
    error = null;
    _notify();
    try {
      final raw = await _store.read().timeout(const Duration(seconds: 5));
      final decoded = raw == null ? <dynamic>[] : jsonDecode(raw);
      if (decoded is! List ||
          decoded.length > 500 ||
          decoded.any(
            (id) =>
                id is! String ||
                !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}$').hasMatch(id),
          )) {
        throw const FormatException();
      }
      if (!_disposed) _ids = decoded.cast<String>().toSet();
    } catch (_) {
      error =
          'Unable to load your saved wishlist. Retry before making changes.';
    } finally {
      _restoring = false;
      loading = false;
      _notify();
    }
  }

  Future<void> toggle(String id) async {
    if (loading || saving || _disposed || error != null) return;
    if (!_ids.contains(id) && _ids.length >= 500) {
      throw StateError(
        'Your wishlist is full. Remove a piece before adding another.',
      );
    }
    saving = true;
    _notify();
    final next = {..._ids};
    if (!next.remove(id)) next.add(id);
    try {
      await _store.write(jsonEncode(next.toList()));
      if (!_disposed) _ids = next;
    } catch (_) {
      throw StateError('Unable to save your wishlist. Please retry.');
    } finally {
      saving = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
