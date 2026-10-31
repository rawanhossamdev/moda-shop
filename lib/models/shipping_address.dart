const addressLabels = {
  'fullName': 'Full name',
  'mobile': 'Egyptian mobile number',
  'governorate': 'Governorate',
  'city': 'City / area',
  'streetAddress': 'Street address',
  'buildingDetails': 'Building / apartment details',
  'deliveryNotes': 'Delivery notes (optional)',
};
const addressLimits = {
  'fullName': 120,
  'mobile': 30,
  'governorate': 100,
  'city': 100,
  'streetAddress': 500,
  'buildingDetails': 200,
  'deliveryNotes': 1000,
};

String? validateAddressField(String key, String? value) {
  final text = value?.trim() ?? '';
  final min = key == 'deliveryNotes'
      ? 0
      : key == 'streetAddress'
      ? 5
      : key == 'buildingDetails'
      ? 1
      : 2;
  if (text.length < min) {
    return 'Please enter your ${addressLabels[key]!.toLowerCase()}.';
  }
  if (text.length > addressLimits[key]! ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(text)) {
    return 'Please check this field.';
  }
  if (key == 'mobile' &&
      !RegExp(
        r'^(?:0|\+20|0020)1[0125]\d{8}$',
      ).hasMatch(text.replaceAll(RegExp(r'[ ()-]'), ''))) {
    return 'Enter an Egyptian mobile number, e.g. 01012345678.';
  }
  return null;
}

class ShippingAddress {
  ShippingAddress(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  bool get isDefault => data['isDefault'] == true;
  String get summary => addressSummary(data);
  Map<String, dynamic> get fields => {
    for (final key in addressLabels.keys) key: data[key],
    'isDefault': isDefault,
  };
  factory ShippingAddress.fromJson(dynamic value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['isDefault'] is! bool ||
        addressLabels.keys.any((key) => value[key] is! String)) {
      throw const FormatException('Invalid shipping address');
    }
    return ShippingAddress(Map.unmodifiable(value));
  }
}

String addressSummary(Map<dynamic, dynamic> data) => [
  for (final key in addressLabels.keys)
    if (data[key] is String && (data[key] as String).isNotEmpty) data[key],
].join('\n');
