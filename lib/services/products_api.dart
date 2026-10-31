import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../config/api_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code;
  @override
  String toString() => message;
}

class ApiResponse {
  const ApiResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

abstract interface class ApiTransport {
  Future<ApiResponse> get(Uri uri);
  void close();
}

abstract interface class AuthTransport {
  Future<ApiResponse> send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  });
  void close();
}

class IoApiTransport implements ApiTransport, AuthTransport {
  IoApiTransport({HttpClient? client}) : _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 8);
  }
  final HttpClient _client;
  @override
  Future<ApiResponse> get(Uri uri) => send('GET', uri);

  @override
  Future<ApiResponse> send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    HttpClientRequest? request;
    try {
      return await (() async {
        final outgoing = await _client.openUrl(method, uri);
        request = outgoing;
        outgoing.headers.set(HttpHeaders.acceptHeader, 'application/json');
        headers?.forEach(outgoing.headers.set);
        if (body != null) {
          outgoing.headers.contentType = ContentType.json;
          outgoing.write(jsonEncode(body));
        }
        final response = await outgoing.close();
        final responseBody = await utf8.decoder.bind(response).join();
        return ApiResponse(response.statusCode, responseBody);
      })().timeout(const Duration(seconds: 12));
    } catch (_) {
      request?.abort();
      rethrow;
    }
  }

  @override
  void close() => _client.close(force: true);
}

class ProductsApi {
  ProductsApi({ApiTransport? transport, String baseUrl = ApiConfig.baseUrl})
    : _transport = transport ?? IoApiTransport(),
      _base = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/') {
    if (!['http', 'https'].contains(_base.scheme) ||
        _base.host.isEmpty ||
        _base.hasQuery ||
        _base.hasFragment) {
      throw ArgumentError('API_BASE_URL must be an HTTP(S) API base URL.');
    }
  }
  final ApiTransport _transport;
  final Uri _base;

  Future<Object?> get(String path, {Map<String, String>? query}) async {
    try {
      final response = await _transport
          .get(_base.resolve(path).replace(queryParameters: query))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw ApiException(
          response.statusCode == 404
              ? 'This product is no longer available.'
              : 'The collection is unavailable. Please try again.',
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || !decoded.containsKey('data')) {
        throw const FormatException('Missing data envelope');
      }
      return decoded['data'];
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException('The server returned invalid product data.');
    } catch (_) {
      throw const ApiException(
        'Unable to reach MODA. Check your connection and try again.',
      );
    }
  }

  void close() => _transport.close();
}
