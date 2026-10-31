import 'dart:convert';
import '../services/local_store.dart';
import '../services/products_api.dart';
import '../repositories/product_repository.dart';
import 'package:flutter/foundation.dart';
import 'product.dart';

class CartItem {
  const CartItem({
    required this.product,
    required this.size,
    this.quantity = 1,
    this.variant,
  });
  final Product product;
  final String size;
  final int quantity;
  final ProductVariant? variant;
  String? get variantId => variant?.id;
  String? get colorId => variant?.colorId;
  String? get colorName => product.colorFor(variant)?.name;
  String get label => variantLabel(size, colorName);
  String get image => variant == null
      ? product.image
      : product.galleryFor(colorId).firstOrNull?.path ?? '';
  int get unitPriceInCents => variant?.priceInCents ?? product.priceInCents;
  int get subtotal => unitPriceInCents * quantity;
  Map<String, dynamic> get request => {
    'productId': product.id,
    'size': size,
    'quantity': quantity,
    if (variantId != null) 'variantId': variantId,
    if (colorId != null) 'colorId': colorId,
    if (colorName != null) 'colorName': colorName,
  };
  bool matches(Map<String, dynamic> bought) =>
      product.id == bought['productId'] &&
      size == bought['size'] &&
      (bought['variantId'] != null
          ? variantId == bought['variantId']
          : variantId == product.selectVariant(size)?.id);
}

class Cart extends ChangeNotifier {
  Cart({LocalStore? store}) : _store = store;
  final LocalStore? _store;
  Future<void> _writes = Future.value();
  ProductRepository? _repository;
  Future<void> retryRestore() async {
    if (_repository != null) await restore(_repository!);
  }

  bool restoring = false, _disposed = false, _loaded = false;
  String? restoreError, storageError, notice;
  final Map<String, Map<String, dynamic>> _requests = {};
  final Set<String> _settled = {};
  bool checkoutBusy = false;
  void setCheckoutBusy(bool value) {
    checkoutBusy = value;
    _notify();
  }

  bool get ready => !restoring && restoreError == null;
  Map<String, dynamic>? pendingCheckout(String userId) =>
      _requests[userId] == null
      ? null
      : jsonDecode(jsonEncode(_requests[userId])) as Map<String, dynamic>;
  List<Map<String, dynamic>> get _lines => _items
      .map(
        (item) => <String, dynamic>{
          ...item.request,
          if (item.colorId != null) 'colorId': item.colorId,
        },
      )
      .toList();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _save() {
    if (_disposed || _store == null || !_loaded || !ready) return;
    // One storage value commits cart settlement and its durable marker together.
    final encoded = jsonEncode({
      'version': 1,
      'items': _lines,
      'pending': _requests,
      'settled': _settled.toList(),
    });
    _writes = _writes.then((_) async {
      try {
        await _store.write(encoded);
        storageError = null;
      } catch (_) {
        storageError =
            'Unable to save your cart safely. Retry saving before checkout.';
      }
      _notify();
    });
  }

  Future<void> flush() async {
    if (!ready) throw StateError('Restore the cart before checkout.');
    _save();
    await _writes;
    if (storageError != null) throw StateError(storageError!);
  }

  Future<void> restore(ProductRepository repository) async {
    if (restoring || _store == null) return;
    _repository = repository;
    restoring = true;
    restoreError = null;
    _notify();
    try {
      await _writes;
      final raw = await _store.read().timeout(const Duration(seconds: 8));
      final data = raw == null
          ? <String, dynamic>{
              'version': 1,
              'items': [],
              'pending': {},
              'settled': [],
            }
          : jsonDecode(raw);
      if (data is! Map ||
          data['version'] != 1 ||
          data['items'] is! List ||
          data['pending'] is! Map ||
          data['settled'] is! List) {
        throw const FormatException();
      }
      final saved = (data['items'] as List).map((line) {
        if (line is! Map ||
            line['productId'] is! String ||
            !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(line['productId']) ||
            !Product.validSizes.contains(line['size']) ||
            line['quantity'] is! int ||
            line['quantity'] < 1 ||
            (line['variantId'] != null && line['variantId'] is! String) ||
            (line['colorId'] != null && line['colorId'] is! String)) {
          throw const FormatException();
        }
        return Map<String, dynamic>.from(line);
      }).toList();
      final restoredRequests = <String, Map<String, dynamic>>{};
      for (final entry in (data['pending'] as Map).entries) {
        if (entry.key is! String ||
            entry.value is! Map ||
            entry.value['clientRequestId'] is! String ||
            entry.value['items'] is! List ||
            entry.value['paymentMethod'] != 'COD' ||
            entry.value['addressId'] is! String ||
            entry.value['expectedTotalInCents'] is! int ||
            entry.value['expectedTotalInCents'] < 0 ||
            (entry.value['items'] as List).isEmpty ||
            (entry.value['items'] as List).any(
              (line) =>
                  line is! Map ||
                  line['productId'] is! String ||
                  !Product.validSizes.contains(line['size']) ||
                  line['quantity'] is! int ||
                  line['quantity'] < 1,
            )) {
          throw const FormatException();
        }
        restoredRequests[entry.key as String] = Map<String, dynamic>.from(
          entry.value as Map,
        );
      }
      if ((data['settled'] as List).any((id) => id is! String)) {
        throw const FormatException();
      }
      final products = <String, Product?>{};
      for (final id
          in saved.map((line) => line['productId'] as String).toSet()) {
        try {
          products[id] = await repository.fetchProduct(id);
        } on ApiException catch (error) {
          if (error.statusCode == 404) {
            products[id] = null;
          } else {
            rethrow;
          }
        }
      }
      final restored = <CartItem>[];
      var removed = 0;
      for (final line in saved) {
        final product = products[line['productId']];
        final variant = product?.selectVariant(
          line['size'] as String,
          variantId: line['variantId'] as String?,
          colorId: line['colorId'] as String?,
        );
        if (product == null || variant == null) {
          removed++;
          continue;
        }
        final existingIndex = restored.indexWhere(
          (item) =>
              item.product.id == product.id &&
              item.variantId == variant.id &&
              item.size == variant.size,
        );
        if (existingIndex >= 0) {
          final existing = restored[existingIndex];
          restored[existingIndex] = CartItem(
            product: product,
            size: variant.size,
            variant: variant,
            quantity: existing.quantity + (line['quantity'] as int),
          );
        } else {
          restored.add(
            CartItem(
              product: product,
              size: variant.size,
              variant: variant,
              quantity: line['quantity'] as int,
            ),
          );
        }
      }
      _items
        ..clear()
        ..addAll(restored);
      _requests
        ..clear()
        ..addAll(restoredRequests);
      _settled
        ..clear()
        ..addAll((data['settled'] as List).cast<String>());
      _loaded = true;
      notice = removed > 0
          ? '$removed unavailable cart ${removed == 1 ? 'item was' : 'items were'} removed. Available items use current catalog prices.'
          : saved.isEmpty
          ? null
          : 'Cart restored with current catalog prices and available variants.';
    } catch (_) {
      restoreError =
          'Unable to restore your saved cart. Check your connection and retry. Saved items have been kept.';
    } finally {
      restoring = false;
      if (restoreError == null) _save();
      _notify();
    }
  }

  Future<Map<String, dynamic>> prepareCheckout(
    String userId,
    Map<String, dynamic> body, {
    bool revise = false,
  }) async {
    if (!ready) throw StateError('Restore the cart before checkout.');
    final previous = _requests[userId];
    if (previous == null || revise) {
      _requests[userId] =
          jsonDecode(
                jsonEncode({
                  ...body,
                  if (previous != null)
                    'clientRequestId': previous['clientRequestId'],
                }),
              )
              as Map<String, dynamic>;
    }
    _notify();
    await flush(); // Must finish BEFORE sending an order request.
    return pendingCheckout(userId)!;
  }

  Future<void> completeCheckout(
    String userId,
    String orderId,
    List<Map<String, dynamic>> purchased,
  ) async {
    if (!ready) {
      throw StateError('Restore your cart before settling this order.');
    }
    if (!_requests.containsKey(userId) && !_settled.contains(orderId)) {
      throw StateError('No pending checkout belongs to this account.');
    }
    if (_settled.add(orderId)) {
      for (final bought in purchased) {
        final index = _items.indexWhere((item) => item.matches(bought));
        if (index < 0) continue;
        final current = _items[index];
        final remaining = current.quantity - (bought['quantity'] as int);
        if (remaining <= 0) {
          _items.removeAt(index);
        } else {
          _items[index] = CartItem(
            product: current.product,
            size: current.size,
            variant: current.variant,
            quantity: remaining,
          );
        }
      }
    }
    _requests.remove(userId);
    _notify();
    await flush();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  final Map<String, List<CartItem>> _pendingOrders = {};
  void rememberCheckout(String id, List<CartItem> purchased) {
    _pendingOrders[id] = List.of(purchased);
  }

  void settleCheckout(String id) {
    final purchased = _pendingOrders.remove(id);
    if (purchased != null) completePurchase(purchased);
  }

  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);
  int get count => _items.fold(0, (sum, item) => sum + item.quantity);
  int get total => _items.fold(0, (sum, item) => sum + item.subtotal);
  void add(Product product, [String? selectedSize]) =>
      addSelection(product, size: selectedSize);

  void addVariant(Product product, ProductVariant variant) => addSelection(
    product,
    size: variant.size,
    variantId: variant.id,
    colorId: variant.colorId,
  );

  void addSelection(
    Product product, {
    String? size,
    String? variantId,
    String? colorId,
  }) {
    if (!ready) {
      throw StateError('Restore your saved cart before adding items.');
    }
    size ??= product.isOneSize ? 'ONE_SIZE' : null;
    final variant = size == null
        ? null
        : product.selectVariant(size, variantId: variantId, colorId: colorId);
    if (size == null || variant == null) {
      throw ArgumentError.value(size, 'size');
    }
    final index = _items.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.size == size &&
          item.variantId == variant.id,
    );
    if (index < 0) {
      _items.add(CartItem(product: product, size: size, variant: variant));
    } else {
      setQuantity(_items[index], _items[index].quantity + 1);
      return;
    }
    _save();
    _notify();
  }

  void setQuantity(CartItem item, int quantity) {
    final index = _items.indexOf(item);
    if (!ready || index < 0 || quantity < 1) return;
    _items[index] = CartItem(
      product: item.product,
      size: item.size,
      variant: item.variant,
      quantity: quantity,
    );
    _save();
    _notify();
  }

  void remove(CartItem item) {
    if (_items.remove(item)) {
      _save();
      _notify();
    }
  }

  void completePurchase(List<CartItem> purchased) {
    for (final bought in purchased) {
      final index = _items.indexWhere(
        (item) =>
            item.product.id == bought.product.id &&
            item.size == bought.size &&
            item.variantId == bought.variantId,
      );
      if (index < 0) continue;
      final current = _items[index];
      final remaining = current.quantity - bought.quantity;
      if (remaining <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = CartItem(
          product: current.product,
          size: current.size,
          variant: current.variant,
          quantity: remaining,
        );
      }
    }
    _save();
    _notify();
  }
}
