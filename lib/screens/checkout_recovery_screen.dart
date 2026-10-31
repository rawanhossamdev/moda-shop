import 'package:flutter/material.dart';
import '../models/shop_order.dart';
import '../models/product.dart';
import '../services/products_api.dart';
import '../theme/moda_theme.dart';
import '../widgets/commerce_scope.dart';
import 'order_screens.dart';
import 'checkout_screen.dart';

class CheckoutRecoveryScreen extends StatefulWidget {
  const CheckoutRecoveryScreen({super.key});
  @override
  State<CheckoutRecoveryScreen> createState() => _CheckoutRecoveryScreenState();
}

class _CheckoutRecoveryScreenState extends State<CheckoutRecoveryScreen> {
  bool _started = false, _busy = false;
  bool _notFound = false;
  String? _error;
  ShopOrder? _foundOrder;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recover();
      });
    }
  }

  Future<void> _recover({bool submit = false}) async {
    if (_busy || CommerceScope.of(context).cart.checkoutBusy) return;
    final scope = CommerceScope.of(context);
    final userId = scope.auth.user?.id;
    if (userId == null) return;
    final request = scope.cart.pendingCheckout(userId);
    if (request == null && _foundOrder == null) return;
    scope.cart.setCheckoutBusy(true);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!scope.cart.ready) {
        throw const ApiException(
          'Restore your saved cart before recovering checkout.',
        );
      }
      await scope.cart.flush();
      final ShopOrder order;
      if (_foundOrder != null) {
        order = _foundOrder!;
      } else if (submit) {
        order = await scope.repository.place(request!);
      } else {
        order = await scope.repository.findRequest(
          request!['clientRequestId'] as String,
        );
      }
      if (!mounted || scope.auth.user?.id != userId) return;
      _foundOrder = order;
      await scope.cart.completeCheckout(userId, order.id, order.items);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OrderDetailScreen(order: order),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      if (!submit && error is ApiException && error.statusCode == 404) {
        setState(() => _notFound = true);
      } else if (submit &&
          error is ApiException &&
          [
            'PRICE_CHANGED',
            'INVALID_ADDRESS',
            'ADDRESS_NOT_FOUND',
            'CART_UNAVAILABLE',
            'INVALID_CART',
          ].contains(error.code)) {
        setState(
          () => _error =
              '${error.message} Review an updated cart and address; the original request number will be retained.',
        );
      } else {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Unable to recover checkout safely. Retry; the original request has been kept.',
        );
      }
    } finally {
      scope.cart.setCheckoutBusy(false);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = CommerceScope.of(context);
    final request = scope.cart.pendingCheckout(scope.auth.user?.id ?? '');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CHECKOUT RECOVERY',
          style: ModaStyle.label.copyWith(fontSize: 12),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Your order, safely recovered.',
                  style: ModaStyle.editorial.copyWith(fontSize: 30),
                ),
                const SizedBox(height: 20),
                const Text(
                  'We check the original order request before trying again. Retrying uses the same request and cannot create a second order for it.',
                ),
                if (request != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Original total: ${orderMoney(request['expectedTotalInCents'] as int, 'USD')} · Cash on Delivery',
                  ),
                  for (final item in request['items'] as List)
                    Text(
                      '${item['productId']} · ${variantLabel(item['size'] as String, item['colorName'] is String ? item['colorName'] as String : null)} × ${item['quantity']}',
                    ),
                ],
                if (_notFound)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No confirmed order was found yet. Retry the original order safely, or check again. Do not start a separate checkout.',
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (_busy)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (!_busy && (request != null || _foundOrder != null)) ...[
                  OutlinedButton(
                    onPressed: () => _recover(),
                    child: Text(
                      _foundOrder == null
                          ? 'CHECK ORIGINAL ORDER'
                          : 'RETRY SAVING',
                    ),
                  ),
                  if (_notFound && request != null)
                    FilledButton(
                      key: const Key('retry-original-checkout'),
                      onPressed: () => _recover(submit: true),
                      child: const Text('RETRY ORIGINAL ORDER'),
                    ),
                ],
                if (!_busy && _notFound && request != null)
                  OutlinedButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CheckoutScreen(
                          cart: scope.cart,
                          reviewPending: true,
                        ),
                      ),
                    ),
                    child: const Text('REVIEW UPDATED CART'),
                  ),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('BACK'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CheckoutRecoveryNotice extends StatelessWidget {
  const CheckoutRecoveryNotice({
    super.key,
    required this.child,
    required this.onReview,
  });
  final Widget child;
  final VoidCallback onReview;
  @override
  Widget build(BuildContext context) {
    final scope = CommerceScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.auth, scope.cart]),
      builder: (context, _) {
        final pending = scope.cart.pendingCheckout(scope.auth.user?.id ?? '');
        if (pending == null) return child;
        return Column(
          children: [
            SafeArea(
              bottom: false,
              child: Material(
                color: ModaStyle.cream,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('An order request needs confirmation.'),
                      TextButton(
                        onPressed: scope.cart.ready && !scope.cart.checkoutBusy
                            ? onReview
                            : null,
                        child: const Text('REVIEW CHECKOUT'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
