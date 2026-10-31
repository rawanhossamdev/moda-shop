import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/moda_theme.dart';
import 'product_image.dart';
import 'wishlist_scope.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});
  static double textExtent(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return 8 + scaler.scale(16) * 1.35 * 2 + 4 + scaler.scale(18) * 1.35 + 2;
  }

  final Product product;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    const nameLines = 2;
    return Semantics(
      button: true,
      label: 'View ${product.name}, ${product.price}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: ProductPhotoStyle.aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ProductPhotoStyle.radius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ProductImage(
                        asset: product.image,
                        fit: BoxFit.cover,
                        cacheWidth: 480,
                        alignment: Alignment.center,
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: WishlistButton(productId: product.id),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: scale.scale(16) * 1.35 * nameLines,
                child: Text(
                  product.name,
                  maxLines: nameLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    color: ModaStyle.charcoal,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.price,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: ModaStyle.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
