class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    this.emailVerified = false,
  });
  final String id;
  final String email;
  final String name;
  final bool emailVerified;
  factory AuthUser.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        value['email'] is! String ||
        value['name'] is! String) {
      throw const FormatException('Invalid account response');
    }
    return AuthUser(
      id: value['id'] as String,
      email: value['email'] as String,
      name: value['name'] as String,
      emailVerified: value['emailVerified'] == true,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    this.verificationNotice,
  });
  final String token;
  final AuthUser user;
  final String? verificationNotice;
}
