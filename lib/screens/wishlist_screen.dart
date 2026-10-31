import '../theme/moda_icons.dart';
import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../services/products_api.dart';
import '../theme/moda_theme.dart';
import '../widgets/wishlist_scope.dart';
import '../widgets/catalog_state.dart';
import '../widgets/product_image.dart';
import 'product_details_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({
    super.key,
    required this.repository,
    required this.cart,
  });
  final ProductRepository repository;
  final Cart cart;
  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final Map<String, Future<Product>> _requests = {};
  @override
  Widget build(BuildContext context) {
    final wishlist = WishlistScope.maybeOf(context)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: SafeArea(
        child: wishlist.loading || wishlist.error != null
            ? Center(
                child: CatalogState(
                  message: wishlist.error,
                  onRetry: wishlist.restore,
                ),
              )
            : wishlist.ids.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(ModaIcons.wishlist, size: 32),
                      const SizedBox(height: 16),
                      Text(
                        'Your edit starts here.',
                        style: ModaStyle.editorial.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Save pieces you love using the heart icon.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('EXPLORE THE COLLECTION'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  setState(_requests.clear);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Saved on this device. Portfolio demo: sample products and USD prices; no real merchandise.',
                        style: TextStyle(color: ModaStyle.muted),
                      ),
                    ),
                    for (final id in wishlist.ids)
                      FutureBuilder<Product>(
                        future: _requests.putIfAbsent(
                          id,
                          () => widget.repository.fetchProduct(id),
                        ),
                        builder: (context, snapshot) {
                          final product = snapshot.data;
                          return Card(
                            color: ModaStyle.cream,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  if (product != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        ProductPhotoStyle.radius,
                                      ),
                                      child: SizedBox(
                                        width: 64,
                                        height:
                                            64 / ProductPhotoStyle.aspectRatio,
                                        child: ProductImage(
                                          asset: product.image,
                                          fit: BoxFit.cover,
                                          cacheWidth: 160,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: product != null
                                        ? InkWell(
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    ProductDetailsScreen(
                                                      product: product,
                                                      cart: widget.cart,
                                                      repository:
                                                          widget.repository,
                                                    ),
                                              ),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(product.name),
                                                  const SizedBox(height: 6),
                                                  Text(product.price),
                                                ],
                                              ),
                                            ),
                                          )
                                        : snapshot.hasError
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                snapshot.error
                                                            is ApiException &&
                                                        (snapshot.error
                                                                    as ApiException)
                                                                .statusCode ==
                                                            404
                                                    ? 'This saved piece is no longer available.'
                                                    : 'Unable to load this saved piece.',
                                              ),
                                              TextButton(
                                                onPressed: () => setState(
                                                  () => _requests.remove(id),
                                                ),
                                                child: const Text('RETRY'),
                                              ),
                                            ],
                                          )
                                        : const LinearProgressIndicator(),
                                  ),
                                  WishlistButton(productId: id),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
