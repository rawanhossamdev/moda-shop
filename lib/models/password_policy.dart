import 'dart:convert';

abstract final class PasswordPolicy {
  static const _common = {
    'password',
    'password1',
    'password123',
    'password123!',
    '12345678',
    '123456789',
    '1234567890',
    'qwerty123',
    'qwertyuiop',
    'letmein123',
    'iloveyou',
    'welcome123',
    'admin123',
    'abcdefgh',
    'modashop123',
  };

  static String? problem(String? value) {
    if (value == null || value.runes.length < 8) {
      return 'Use at least 8 characters. A longer passphrase works well.';
    }
    if (utf8.encode(value).length > 72 || value.contains('\u0000')) {
      return 'Use up to 72 UTF-8 bytes without null characters.';
    }
    if (_common.contains(value.trim().toLowerCase()) ||
        value.runes.toSet().length == 1) {
      return 'This password is too common. Try a less predictable passphrase.';
    }
    return null;
  }

  // Advisory only: variety improves this estimate but is never mandatory.
  static int strength(String value) {
    if (problem(value) != null) return 1;
    final variety = [
      RegExp(r'[a-z]'),
      RegExp(r'[A-Z]'),
      RegExp(r'[0-9]'),
      RegExp(r'[^a-zA-Z0-9]'),
    ].where((pattern) => pattern.hasMatch(value)).length;
    if (value.runes.length >= 20 ||
        (value.runes.length >= 12 && variety >= 3)) {
      return 3;
    }
    if (value.runes.length >= 12 || variety >= 3) return 2;
    return 1;
  }
}
