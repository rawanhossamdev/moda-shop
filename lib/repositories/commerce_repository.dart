import 'dart:convert';
import '../models/shipping_address.dart';
import '../config/api_config.dart';
import '../controllers/auth_controller.dart';
import '../models/shop_order.dart';
import '../services/products_api.dart';

abstract interface class CommerceRepository {
  Future<List<ShippingAddress>> addresses();
  Future<ShippingAddress> saveAddress(
    Map<String, dynamic> fields, {
    String? id,
  });
  Future<void> deleteAddress(String id);
  Future<Map<String, dynamic>> configuration();
  Future<Map<String, dynamic>> quote(List<Map<String, dynamic>> items);
  Future<ShopOrder> place(Map<String, dynamic> body);
  Future<Map<String, dynamic>> history({String? cursor});
  Future<ShopOrder> findRequest(String requestId);
  Future<ShopOrder> detail(String id);
  Future<ShopOrder> cancel(String id);
  Future<Uri> payment(String id);
  void close();
}

class ApiCommerceRepository implements CommerceRepository {
  ApiCommerceRepository({
    required AuthController auth,
    AuthTransport? transport,
    String baseUrl = ApiConfig.baseUrl,
  }) : _auth = auth,
       _transport = transport ?? IoApiTransport(),
       _base = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/');
  final AuthController _auth;
  final AuthTransport _transport;
  final Uri _base;
  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) => _auth.authorized((token) async {
    try {
      final response = await _transport
          .send(
            method,
            _base.resolve(path),
            body: body,
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));
      if (![200, 201].contains(response.statusCode)) {
        String? code;
        try {
          code = (jsonDecode(response.body)['error']['code']) as String?;
        } catch (_) {
          /* Keep server internals private. */
        }
        final message = switch (code) {
          'EMAIL_NOT_VERIFIED' => 'Please verify your email before checkout.',
          'PRICE_CHANGED' =>
            'Your total changed. Refresh and review the summary.',
          'CART_UNAVAILABLE' =>
            'A selected product or size is unavailable. Review your cart.',
          'CURRENCY_MISMATCH' =>
            'Checkout pricing is unavailable for the configured currency.',
          'PAYMENTS_DISABLED' =>
            'Online payments are unavailable. Please use Cash on Delivery.',
          'PAYMENT_UNKNOWN' || 'PAYMENT_REVIEW' =>
            'Payment confirmation is unresolved. Refresh order history before attempting another payment.',
          'REQUEST_CONFLICT' =>
            'This request already placed an order. Check your order history.',
          'INVALID_ADDRESS' || 'INVALID_MOBILE' =>
            'Please check your address fields and Egyptian mobile number.',
          'ADDRESS_NOT_FOUND' =>
            'This address is no longer available. Choose another address.',
          'ADDRESS_LIMIT' => 'You can save up to 20 shipping addresses.',
          'INVALID_SHIPPING' =>
            'Please check your shipping details and phone number.',
          'CANNOT_CANCEL' =>
            'Payment or fulfilment is in progress. This order cannot be cancelled.',
          _ => switch (response.statusCode) {
            401 => 'Please sign in again.',
            404 => 'This order is not available.',
            429 => 'Too many requests. Please wait and retry.',
            _ =>
              'Unable to complete checkout. Please retry or check your order history.',
          },
        };
        throw ApiException(
          message,
          statusCode: response.statusCode,
          code: code,
        );
      }
      final result = jsonDecode(response.body)['data'];
      if (result is! Map<String, dynamic>) throw const FormatException();
      return result;
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException('The server returned invalid order data.');
    } catch (_) {
      throw const ApiException(
        'Unable to reach MODA. Check your connection and retry.',
      );
    }
  });
  @override
  Future<List<ShippingAddress>> addresses() async =>
      ((await _request('GET', 'addresses'))['addresses'] as List)
          .map(ShippingAddress.fromJson)
          .toList();
  @override
  Future<ShippingAddress> saveAddress(
    Map<String, dynamic> fields, {
    String? id,
  }) async => ShippingAddress.fromJson(
    (await _request(
      id == null ? 'POST' : 'PUT',
      id == null ? 'addresses' : 'addresses/${Uri.encodeComponent(id)}',
      fields,
    ))['address'],
  );
  @override
  Future<void> deleteAddress(String id) async {
    await _request('DELETE', 'addresses/${Uri.encodeComponent(id)}');
  }

  @override
  Future<Map<String, dynamic>> configuration() =>
      _request('GET', 'checkout/config');
  @override
  Future<Map<String, dynamic>> quote(List<Map<String, dynamic>> items) =>
      _request('POST', 'checkout/quote', {'items': items});
  @override
  Future<ShopOrder> place(Map<String, dynamic> body) async =>
      ShopOrder.fromJson((await _request('POST', 'orders', body))['order']);
  @override
  Future<Map<String, dynamic>> history({String? cursor}) => _request(
    'GET',
    'orders${cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}'}',
  );
  @override
  Future<ShopOrder> findRequest(String requestId) async => ShopOrder.fromJson(
    (await _request(
      'GET',
      'orders/request/${Uri.encodeComponent(requestId)}',
    ))['order'],
  );
  @override
  Future<ShopOrder> detail(String id) async => ShopOrder.fromJson(
    (await _request('GET', 'orders/${Uri.encodeComponent(id)}'))['order'],
  );
  @override
  Future<ShopOrder> cancel(String id) async => ShopOrder.fromJson(
    (await _request(
      'POST',
      'orders/${Uri.encodeComponent(id)}/cancel',
    ))['order'],
  );
  @override
  Future<Uri> payment(String id) async {
    final data = await _request(
      'POST',
      'orders/${Uri.encodeComponent(id)}/payment',
    );
    final uri = Uri.tryParse(
      data['checkoutUrl'] is String ? data['checkoutUrl'] as String : '',
    );
    if (data['testMode'] != true ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'accept.paymob.com' ||
        uri.path != '/unifiedcheckout/' ||
        !uri.queryParameters['publicKey'].toString().startsWith('pk_test_') ||
        !uri.queryParameters['clientSecret'].toString().startsWith(
          'csk_test_',
        )) {
      throw const ApiException(
        'A valid Paymob test checkout was not returned.',
      );
    }
    return uri;
  }

  @override
  void close() => _transport.close();
}
