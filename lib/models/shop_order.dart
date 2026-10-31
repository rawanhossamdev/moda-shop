String orderMoney(int cents, String currency) =>
    '${currency == 'USD' ? r'$' : '$currency '}${(cents / 100).toStringAsFixed(2)}';

class ShopOrder {
  ShopOrder(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get currency => data['currency'] as String;
  String get status => data['status'] as String;
  String get paymentStatus => data['paymentStatus'] as String;
  String get paymentMethod => data['paymentMethod'] as String;
  int get total => data['totalInCents'] as int;
  List<Map<String, dynamic>> get items =>
      (data['items'] as List).cast<Map<String, dynamic>>();
  factory ShopOrder.fromJson(dynamic value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(value['id'] as String) ||
        value['currency'] is! String ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(value['currency'] as String) ||
        value['totalInCents'] is! int ||
        (value['totalInCents'] as int) < 0 ||
        value['status'] is! String ||
        value['paymentStatus'] is! String ||
        value['paymentMethod'] is! String ||
        value['items'] is! List ||
        (value['items'] as List).any(
          (item) =>
              item is! Map<String, dynamic> ||
              item['productName'] is! String ||
              item['size'] is! String ||
              item['quantity'] is! int ||
              item['unitPriceInCents'] is! int,
        )) {
      throw const FormatException('Invalid order response');
    }
    return ShopOrder(value);
  }
}
