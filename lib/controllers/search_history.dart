import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/local_store.dart';

class SearchHistory extends ChangeNotifier {
  SearchHistory(this.store);
  final LocalStore store;
  List<String> _terms = [];
  List<String> get terms => List.unmodifiable(_terms);
  Future<void> _tail = Future.value();
  bool loading = false, _disposed = false;
  String? error;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() {
    loading = true;
    _tail = _tail.then((_) async {
      try {
        final raw = await store.read();
        final value = raw == null ? [] : jsonDecode(raw);
        if (value is! List ||
            value.any(
              (term) => term is! String || term.isEmpty || term.length > 160,
            )) {
          throw const FormatException();
        }
        _terms = value.cast<String>().take(8).toList();
        error = null;
      } catch (_) {
        error =
            'Recent searches are unavailable. You can still search the catalog.';
      }
      loading = false;
      _notify();
    });
    return _tail;
  }

  Future<void> add(String term) => _change(term.trim());
  Future<void> clear() => _change(null);
  Future<void> _change(String? term) {
    _tail = _tail.then((_) async {
      if (term != null && (term.isEmpty || term.length > 160)) return;
      final next = term == null
          ? <String>[]
          : [
              term,
              ..._terms.where(
                (value) => value.toLowerCase() != term.toLowerCase(),
              ),
            ].take(8).toList();
      try {
        await store.write(jsonEncode(next));
        _terms = next;
        error = null;
      } catch (_) {
        error =
            'Unable to save recent searches. Your catalog search still works.';
      }
      _notify();
    });
    return _tail;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
