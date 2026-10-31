import 'package:moda_shop/models/product.dart';
import 'package:moda_shop/services/products_api.dart';
import 'package:moda_shop/models/shop_order.dart';
import 'package:moda_shop/models/shipping_address.dart';
import 'package:moda_shop/repositories/commerce_repository.dart';
import 'package:moda_shop/data/products.dart';

ShopOrder testOrder({String method = 'COD', String status = 'UNPAID'}) =>
    ShopOrder.fromJson({
      'id': '37a06452-2265-47e8-8349-9716b68093d6',
      'currency': 'USD',
      'status': status == 'PAID' ? 'CONFIRMED' : 'PENDING',
      'paymentMethod': method,
      'paymentStatus': status,
      'subtotalInCents': 3500,
      'shippingFeeInCents': 200,
      'totalInCents': 3700,
      'shippingName': 'MODA Member',
      'shippingPhone': '+201000000000',
      'shippingAddress': '25 Test street',
      'shippingCity': 'Cairo',
      'deliveryNotes': '',
      'items': [
        {
          'productId': products.first.id,
          'productName': products.first.name,
          'size': 'M',
          'unitPriceInCents': 3500,
          'quantity': 1,
        },
      ],
    });

class FakeCommerceRepository implements CommerceRepository {
  List<Product> catalog = products;
  List<ShippingAddress> savedAddresses = [];
  Future<List<ShippingAddress>> Function()? onAddresses;
  int addressSaves = 0;
  @override
  Future<List<ShippingAddress>> addresses() async =>
      onAddresses != null ? onAddresses!() : savedAddresses;
  @override
  Future<ShippingAddress> saveAddress(
    Map<String, dynamic> fields, {
    String? id,
  }) async {
    addressSaves++;
    final value = ShippingAddress.fromJson({
      ...fields,
      'id':
          id ??
          '37a06452-2265-47e8-8349-${addressSaves.toString().padLeft(12, '0')}',
      'isDefault': savedAddresses.isEmpty || fields['isDefault'] == true,
    });
    if (value.isDefault) {
      savedAddresses = savedAddresses
          .map((a) => ShippingAddress({...a.data, 'isDefault': false}))
          .toList();
    }
    savedAddresses.removeWhere((a) => a.id == value.id);
    savedAddresses.add(value);
    return value;
  }

  @override
  Future<void> deleteAddress(String id) async {
    savedAddresses.removeWhere((a) => a.id == id);
  }

  bool online = false;
  int placements = 0;
  int payments = 0;
  int histories = 0;
  List<Map<String, dynamic>> submitted = [];
  Future<ShopOrder> Function(Map<String, dynamic>)? onPlace;
  Future<Map<String, dynamic>> Function()? onHistory;
  ShopOrder current = testOrder();
  @override
  Future<Map<String, dynamic>> configuration() async => {
    'currency': 'USD',
    'shippingFeeInCents': 200,
    'paymentMethods': ['COD', if (online) 'PAYMOB_CARD'],
    'testMode': true,
    'onlinePaymentMessage': online
        ? 'Paymob test checkout only.'
        : 'Online payments are currently unavailable. You can use Cash on Delivery.',
  };
  Future<Map<String, dynamic>> Function(List<Map<String, dynamic>>)? onQuote;
  @override
  Future<Map<String, dynamic>> quote(List<Map<String, dynamic>> items) async {
    if (onQuote != null) return onQuote!(items);
    final lines = items.map((item) {
      final product = catalog.firstWhere((p) => p.id == item['productId']);
      final variant = product.selectVariant(
        item['size'] as String,
        variantId: item['variantId'] as String?,
        colorId: item['colorId'] as String?,
      );
      if (variant == null) {
        throw const ApiException(
          'Variant unavailable',
          code: 'CART_UNAVAILABLE',
        );
      }
      return <String, dynamic>{
        ...item,
        'productName': product.name,
        'productImage': product.galleryFor(variant.colorId).firstOrNull?.path,
        if (variant.id != null) 'variantId': variant.id,
        if (variant.colorId != null) 'colorId': variant.colorId,
        if (product.colorFor(variant) != null)
          'colorName': product.colorFor(variant)!.name,
        'unitPriceInCents': variant.priceInCents ?? product.priceInCents,
      };
    }).toList();
    final subtotal = lines.fold<int>(
      0,
      (sum, line) =>
          sum + (line['unitPriceInCents'] as int) * (line['quantity'] as int),
    );
    return {
      'currency': 'USD',
      'subtotalInCents': subtotal,
      'shippingFeeInCents': 200,
      'totalInCents': subtotal + 200,
      'items': lines,
    };
  }

  @override
  Future<ShopOrder> place(Map<String, dynamic> body) async {
    placements++;
    submitted.add(Map.of(body));
    if (onPlace != null) return onPlace!(body);
    final quoted = await quote(
      (body['items'] as List).cast<Map<String, dynamic>>(),
    );
    return current = ShopOrder.fromJson({
      ...testOrder(method: body['paymentMethod'] as String).data,
      ...quoted,
      'shippingSnapshot': savedAddresses
          .where((a) => a.id == body['addressId'])
          .firstOrNull
          ?.fields,
    });
  }

  @override
  Future<Map<String, dynamic>> history({String? cursor}) async {
    histories++;
    return onHistory != null
        ? onHistory!()
        : {'orders': [], 'nextCursor': null};
  }

  Future<ShopOrder> Function(String)? onFindRequest;
  @override
  Future<ShopOrder> findRequest(String requestId) async =>
      onFindRequest != null ? onFindRequest!(requestId) : current;
  @override
  Future<ShopOrder> detail(String id) async => current;
  @override
  Future<ShopOrder> cancel(String id) async => ShopOrder({
    ...current.data,
    'status': 'CANCELLED',
    'paymentStatus': 'CANCELLED',
  });
  @override
  Future<Uri> payment(String id) async {
    payments++;
    return Uri.parse(
      'https://accept.paymob.com/unifiedcheckout/?publicKey=pk_test_fixture&clientSecret=csk_test_fixture',
    );
  }

  @override
  void close() {}
}
