import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class LocalStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureLocalStore implements LocalStore {
  const SecureLocalStore(this.key);
  final String key;
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
}
