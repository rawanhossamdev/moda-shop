import '../theme/moda_icons.dart';
import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../models/product.dart';
import '../theme/moda_theme.dart';
import '../widgets/product_image.dart';
import '../widgets/commerce_scope.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, required this.cart});
  final Cart cart;
  void _home(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('YOUR CART', style: ModaStyle.label.copyWith(fontSize: 12)),
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: cart,
        builder: (context, _) {
          if (!cart.ready) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cart.restoring)
                      const CircularProgressIndicator()
                    else ...[
                      Text(cart.restoreError!),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: cart.retryRestore,
                        child: const Text('RESTORE CART'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          if (cart.items.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: const BoxDecoration(
                        color: ModaStyle.cream,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(ModaIcons.cart, size: 44),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Your cart is empty',
                      textAlign: TextAlign.center,
                      style: ModaStyle.editorial.copyWith(fontSize: 30),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Make room for a new favorite.\nDiscover your next MODA look.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ModaStyle.muted, height: 1.7),
                    ),
                    if (cart.notice != null)
                      Text(cart.notice!, textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: () => _home(context),
                      child: const Text('EXPLORE COLLECTION'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (cart.storageError != null) ...[
                            Text(
                              cart.storageError!,
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await cart.flush();
                                } catch (_) {
                                  /* Error remains visible. */
                                }
                              },
                              child: const Text('RETRY SAVING'),
                            ),
                          ],
                          if (cart.notice != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                cart.notice!,
                                style: const TextStyle(color: ModaStyle.muted),
                              ),
                            ),
                          if (cart.storageError != null) ...[
                            Text(cart.storageError!),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await cart.flush();
                                } catch (_) {
                                  /* Error stays visible. */
                                }
                              },
                              child: const Text('RETRY SAVING'),
                            ),
                          ],
                          Text(
                            'YOUR PERSONAL EDIT',
                            style: ModaStyle.label.copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Well chosen.',
                            style: ModaStyle.editorial.copyWith(fontSize: 34),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${cart.count} ${cart.count == 1 ? 'piece' : 'pieces'} in your collection',
                            style: const TextStyle(color: ModaStyle.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.builder(
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width:
                                        MediaQuery.sizeOf(context).width < 350
                                        ? 76
                                        : 96,
                                    child: AspectRatio(
                                      aspectRatio: 3 / 4,
                                      child: ProductImage(
                                        asset: item.image,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.product.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip:
                                                  'Remove ${item.product.name}, ${item.colorName != null
                                                      ? item.label
                                                      : item.size == 'ONE_SIZE'
                                                      ? 'One Size'
                                                      : 'size ${item.size}'}',
                                              onPressed: () =>
                                                  cart.remove(item),
                                              icon: const Icon(
                                                ModaIcons.delete,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          item.label,
                                          style: const TextStyle(
                                            color: ModaStyle.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          formatPrice(item.subtotal),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: ModaStyle.beige,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Wrap(
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              IconButton(
                                                tooltip: 'Decrease quantity',
                                                onPressed: item.quantity > 1
                                                    ? () => cart.setQuantity(
                                                        item,
                                                        item.quantity - 1,
                                                      )
                                                    : null,
                                                icon: const Icon(
                                                  ModaIcons.remove,
                                                  size: 16,
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                child: Semantics(
                                                  label:
                                                      'Quantity ${item.quantity}',
                                                  child: Text(
                                                    '${item.quantity}',
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Increase quantity',
                                                onPressed: () =>
                                                    cart.setQuantity(
                                                      item,
                                                      item.quantity + 1,
                                                    ),
                                                icon: const Icon(
                                                  ModaIcons.add,
                                                  size: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Divider(),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      padding: const EdgeInsets.all(24),
                      color: ModaStyle.cream,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'YOUR SELECTION',
                            style: ModaStyle.label.copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 24,
                            runSpacing: 12,
                            children: [
                              const Text(
                                'TOTAL',
                                style: TextStyle(
                                  fontSize: 16,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                formatPrice(cart.total),
                                key: const Key('cart-total'),
                                style: ModaStyle.editorial.copyWith(
                                  fontSize: 28,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (CommerceScope.maybeOf(context) != null) ...[
                            FilledButton(
                              key: const Key('checkout-button'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CheckoutScreen(cart: cart),
                                ),
                              ),
                              child: const Text('CHECKOUT'),
                            ),
                            const SizedBox(height: 12),
                          ],
                          FilledButton(
                            onPressed: () => _home(context),
                            child: const Text('CONTINUE SHOPPING'),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Cash on Delivery · Payment due on delivery.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: ModaStyle.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
