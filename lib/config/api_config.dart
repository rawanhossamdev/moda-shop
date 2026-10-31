abstract final class ApiConfig {
  // Android Emulator forwards this address to the development host.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );
}
