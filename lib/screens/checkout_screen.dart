import 'dart:math';
import '../models/shipping_address.dart';
import '../models/product.dart';
import '../widgets/product_image.dart';
import 'address_screens.dart';
import 'auth_screen.dart';
import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../models/shop_order.dart';
import '../services/products_api.dart';
import '../theme/moda_theme.dart';
import '../widgets/commerce_scope.dart';
import 'verify_email_screen.dart';
import 'order_screens.dart';
import 'checkout_recovery_screen.dart';

String checkoutRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.cart,
    this.reviewPending = false,
  });
  final Cart cart;
  final bool reviewPending;
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  ShippingAddress? _address;
  late final List<CartItem> _snapshot = widget.cart.items;
  List<Map<String, dynamic>> get _items =>
      _snapshot.map((item) => item.request).toList();
  Map<String, dynamic>? _config;
  Map<String, dynamic>? _quote;
  Map<String, dynamic>? _submitted;
  bool _started = false;
  bool _busy = false;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _chooseAddress() async {
    final address = await Navigator.of(context).push<ShippingAddress>(
      MaterialPageRoute(builder: (_) => const AddressBookScreen(select: true)),
    );
    if (mounted) {
      // Reload also handles edits/deletes made before returning without selecting.
      if (address != null) _address = address;
      await _load();
    }
  }

  Future<void> _load() async {
    if (_busy) return;
    final scope = CommerceScope.of(context);
    if (scope.auth.user != null &&
        scope.cart.pendingCheckout(scope.auth.user!.id) != null &&
        !widget.reviewPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const CheckoutRecoveryScreen(),
            ),
          );
        }
      });
      return;
    }
    if (_snapshot.isEmpty || scope.auth.user == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _quote = null;
    });
    try {
      final config = await scope.repository.configuration();
      final addresses = await scope.repository.addresses();
      final selected = addresses.where((a) => a.id == _address?.id).firstOrNull;
      final address =
          selected ?? addresses.where((a) => a.isDefault).firstOrNull;
      final quote =
          scope.auth.user?.emailVerified == true && _snapshot.isNotEmpty
          ? await scope.repository.quote(_items)
          : null;
      if (mounted) {
        setState(() {
          _config = config;
          _address = address;
          _quote = quote;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Unable to prepare checkout. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _place() async {
    if (_busy ||
        _quote == null ||
        widget.cart.checkoutBusy ||
        !widget.cart.ready) {
      return;
    }
    if (_address == null) {
      setState(
        () => _error =
            'Choose or add a shipping address before placing your order.',
      );
      return;
    }
    final scope = CommerceScope.of(context);
    final userId = scope.auth.user!.id;
    FocusScope.of(context).unfocus();
    _submitted ??= {
      'addressId': _address!.id,
      'items': _items,
      'paymentMethod': 'COD',
      'expectedTotalInCents': _quote!['totalInCents'],
      'clientRequestId': checkoutRequestId(),
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    scope.cart.setCheckoutBusy(true);
    try {
      _submitted = await scope.cart.prepareCheckout(
        userId,
        _submitted!,
        revise: widget.reviewPending,
      );
      final order = await scope.repository.place(_submitted!);
      if (!mounted) return;
      await scope.cart.completeCheckout(userId, order.id, order.items);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OrderDetailScreen(order: order),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.code == 'REQUEST_CONFLICT') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const CheckoutRecoveryScreen(),
          ),
        );
        return;
      }
      final rejected =
          error is ApiException &&
          [
            'PRICE_CHANGED',
            'INVALID_SHIPPING',
            'INVALID_ADDRESS',
            'ADDRESS_NOT_FOUND',
            'CART_UNAVAILABLE',
            'INVALID_CART',
          ].contains(error.code);
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'Unable to confirm your order safely. Retry this request or check order history.';
        if (rejected) {
          _submitted = null;
          _quote = null;
        }
      });
    } finally {
      scope.cart.setCheckoutBusy(false);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = CommerceScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('CHECKOUT', style: ModaStyle.label.copyWith(fontSize: 12)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Your considered selection.',
                      style: ModaStyle.editorial.copyWith(fontSize: 32),
                    ),
                    const SizedBox(height: 20),
                    if (_snapshot.isEmpty)
                      const Text(
                        'Your cart is empty. Add a piece before checkout.',
                      )
                    else if (scope.auth.user == null) ...[
                      const Text('Please sign in before checkout.'),
                      FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LoginScreen(auth: scope.auth),
                          ),
                        ),
                        child: const Text('SIGN IN'),
                      ),
                    ] else if (scope.auth.user?.emailVerified != true) ...[
                      const Text(
                        'Please verify your email before placing an order.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        VerifyEmailScreen(auth: scope.auth),
                                  ),
                                );
                                if (mounted) _load();
                              },
                        child: const Text('VERIFY EMAIL'),
                      ),
                    ] else if (_config != null && _quote != null) ...[
                      const Text('SHIPPING ADDRESS', style: ModaStyle.label),
                      const SizedBox(height: 12),
                      if (_address != null)
                        Text(
                          _address!.summary,
                          key: const Key('selected-address'),
                          style: const TextStyle(height: 1.6),
                        )
                      else
                        const Text('Choose or add a shipping address.'),
                      OutlinedButton(
                        key: const Key('choose-address'),
                        onPressed: _busy || _submitted != null
                            ? null
                            : _chooseAddress,
                        child: Text(
                          _address == null
                              ? 'ADD OR CHOOSE ADDRESS'
                              : 'CHANGE ADDRESS',
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('PAYMENT METHOD', style: ModaStyle.label),
                      const SizedBox(height: 12),
                      const Text('Cash on Delivery'),
                      const SizedBox(height: 8),
                      const Text(
                        'Payment is due on delivery. Placing an order does not mark it as paid.',
                        style: TextStyle(color: ModaStyle.muted),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: ModaStyle.cream,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('ORDER SUMMARY', style: ModaStyle.label),
                            const SizedBox(height: 14),
                            for (final item in _quote!['items'] as List)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 56,
                                      height: 74,
                                      child: ProductImage(
                                        asset:
                                            item['productImage'] as String? ??
                                            '',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${item['productName']} · ${variantLabel(item['size'] as String, item['colorName'] as String?)} × ${item['quantity']}\nUnit price ${orderMoney(item['unitPriceInCents'] as int, _quote!['currency'] as String)}\nLine total ${orderMoney((item['unitPriceInCents'] as int) * (item['quantity'] as int), _quote!['currency'] as String)}',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              'Subtotal  ${orderMoney(_quote!['subtotalInCents'] as int, _quote!['currency'] as String)}',
                            ),
                            Text(
                              'Configured shipping fee (placeholder)  ${orderMoney(_quote!['shippingFeeInCents'] as int, _quote!['currency'] as String)}',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Total  ${orderMoney(_quote!['totalInCents'] as int, _quote!['currency'] as String)}',
                              key: const Key('checkout-total'),
                              style: ModaStyle.editorial.copyWith(fontSize: 26),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Calculated by MODA. No currency conversion is applied.',
                              style: TextStyle(color: ModaStyle.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const Key('place-order'),
                        onPressed: _busy ? null : _place,
                        child: Text(
                          _submitted == null
                              ? 'PLACE ORDER'
                              : 'RETRY SAME ORDER REQUEST',
                        ),
                      ),
                    ],
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    if (!_busy &&
                        _quote == null &&
                        scope.auth.user?.emailVerified == true &&
                        _snapshot.isNotEmpty)
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('REFRESH SUMMARY'),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const OrderHistoryScreen(),
                              ),
                            ),
                      child: const Text('View order history'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
