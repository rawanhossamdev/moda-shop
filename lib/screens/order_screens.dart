import '../theme/moda_icons.dart';
import 'package:flutter/material.dart';
import '../models/shop_order.dart';
import '../models/product.dart';
import '../models/shipping_address.dart';
import '../widgets/product_image.dart';
import '../services/products_api.dart';
import '../theme/moda_theme.dart';
import '../widgets/commerce_scope.dart';

String? orderDateLabel(dynamic value) {
  final date = value is String ? DateTime.tryParse(value)?.toLocal() : null;
  if (date == null) return null;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return 'Placed ${date.day} ${months[date.month - 1]} ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} (local time)';
}

String paymentLabel(String value) => switch (value) {
  'PAID' => 'Payment confirmed',
  'UNPAID' => 'Payment due on delivery',
  'FAILED' => 'Payment failed',
  'CANCELLED' => 'Payment cancelled',
  'UNKNOWN' => 'Payment needs review',
  _ => 'Awaiting payment confirmation',
};

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});
  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final List<ShopOrder> _orders = [];
  String? _cursor;
  String? _error;
  bool _busy = false;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    final repository = CommerceScope.of(context).repository;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await repository.history(cursor: more ? _cursor : null);
      final orders = (result['orders'] as List)
          .map(ShopOrder.fromJson)
          .toList();
      if (mounted) {
        setState(() {
          if (!more) _orders.clear();
          _orders.addAll(orders);
          _cursor = result['nextCursor'] as String?;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Unable to load your orders. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('YOUR ORDERS', style: ModaStyle.label.copyWith(fontSize: 12)),
      actions: [
        IconButton(
          tooltip: 'Refresh orders',
          onPressed: _busy ? null : () => _load(),
          icon: const Icon(ModaIcons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Your MODA story.',
                style: ModaStyle.editorial.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 24),
              if (!_busy && _orders.isEmpty && _error == null)
                const Text(
                  'Your first considered purchase is still to come. Your orders will appear here.',
                ),
              for (final order in _orders)
                Card(
                  color: ModaStyle.cream,
                  elevation: 0,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OrderDetailScreen(order: order),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Order ${order.id.substring(0, 8)}',
                                ),
                              ),
                              const Icon(ModaIcons.next),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${order.status.toLowerCase()} / ${paymentLabel(order.paymentStatus)}',
                          ),
                          Text(orderMoney(order.total, order.currency)),
                          const SizedBox(height: 8),
                          for (final item in order.items)
                            Text(
                              '${item['productName']} / ${variantLabel(item['size'] as String, item['colorName'] as String?)}',
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
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
              if (!_busy && _error != null)
                OutlinedButton(
                  onPressed: () => _load(),
                  child: const Text('RETRY'),
                ),
              if (!_busy && _cursor != null)
                OutlinedButton(
                  onPressed: () => _load(more: true),
                  child: const Text('LOAD MORE'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order});
  final ShopOrder order;
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with WidgetsBindingObserver {
  late ShopOrder _order = widget.order;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Unable to update this order. Please refresh its status.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() => _run(() async {
    final scope = CommerceScope.of(context);
    final order = await scope.repository.detail(_order.id);
    if (!mounted) return;
    if (order.paymentStatus == 'PAID' && order.status != 'CANCELLED') {
      scope.cart.settleCheckout(order.id);
    }
    setState(() => _order = order);
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'ORDER DETAILS',
        style: ModaStyle.label.copyWith(fontSize: 12),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _order.status == 'CANCELLED'
                      ? 'Your order was cancelled.'
                      : _order.paymentStatus == 'PAID'
                      ? 'Your order is confirmed.'
                      : _order.paymentMethod == 'COD'
                      ? 'Your order is placed.'
                      : 'Your selection is saved.',
                  style: ModaStyle.editorial.copyWith(fontSize: 32),
                ),
                const SizedBox(height: 16),
                SelectableText('Order ${_order.id}'),
                if (orderDateLabel(_order.data['createdAt']) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      orderDateLabel(_order.data['createdAt'])!,
                      key: const Key('order-date'),
                      style: const TextStyle(color: ModaStyle.muted),
                    ),
                  ),
                const SizedBox(height: 12),
                Text('Order status: ${_order.status.toLowerCase()}'),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    paymentLabel(_order.paymentStatus),
                    key: const Key('order-payment-status'),
                  ),
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
                      for (final item in _order.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item['productImage'] is String &&
                                  Product.isBundledImage(
                                    item['productImage'] as String,
                                  )) ...[
                                SizedBox(
                                  width: 56,
                                  height: 74,
                                  child: ProductImage(
                                    asset: item['productImage'] as String,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Text(
                                  '${item['productName']} · ${variantLabel(item['size'] as String, item['colorName'] as String?)} × ${item['quantity']}\n${orderMoney((item['unitPriceInCents'] as int) * (item['quantity'] as int), _order.currency)}',
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        'Subtotal  ${orderMoney((_order.data['subtotalInCents'] as int?) ?? _order.total, _order.currency)}',
                      ),
                      Text(
                        'Shipping  ${orderMoney((_order.data['shippingFeeInCents'] as int?) ?? 0, _order.currency)}',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Total  ${orderMoney(_order.total, _order.currency)}',
                        style: ModaStyle.editorial.copyWith(fontSize: 26),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_order.data['shippingSnapshot'] is Map)
                  Text(addressSummary(_order.data['shippingSnapshot'] as Map))
                else if (_order.data['shippingName'] != null)
                  Text(
                    '${_order.data['shippingName']}\n${_order.data['shippingPhone']}\n${_order.data['shippingAddress']}\n${_order.data['shippingCity']}',
                  ),
                if (_order.data['shippingSnapshot'] == null &&
                    (_order.data['deliveryNotes'] as String?)?.isNotEmpty ==
                        true)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Delivery notes: ${_order.data['deliveryNotes']}',
                    ),
                  ),
                const SizedBox(height: 24),
                if (_order.paymentMethod != 'COD')
                  const Text(
                    'Historical online payment order. Online payments are unavailable in this phase.',
                    style: TextStyle(color: ModaStyle.muted),
                  ),
                if (_busy)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
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
                OutlinedButton(
                  onPressed: _busy ? null : _refresh,
                  child: const Text('REFRESH ORDER STATUS'),
                ),
                if (['UNPAID', 'FAILED'].contains(_order.paymentStatus) &&
                    ['PENDING', 'CONFIRMED'].contains(_order.status))
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final order = await CommerceScope.of(
                              context,
                            ).repository.cancel(_order.id);
                            if (mounted) setState(() => _order = order);
                          }),
                    child: const Text('Cancel unpaid order'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
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
  );
}
