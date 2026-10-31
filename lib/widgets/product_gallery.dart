import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/product_variant.dart';
import '../screens/product_image_screen.dart';
import '../theme/moda_theme.dart';
import 'product_image.dart';

class ProductGallery extends StatefulWidget {
  const ProductGallery({
    super.key,
    required this.images,
    required this.name,
    this.colorName,
  });
  final List<ProductMedia> images;
  final String name;
  final String? colorName;
  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  final _pages = PageController();
  int _index = 0;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final reserved = widget.images.length > 1 ? 112.0 : 48.0;
      final width = constraints.hasBoundedHeight
          ? math.min(
              constraints.maxWidth,
              math.max(1.0, constraints.maxHeight - reserved) *
                  ProductPhotoStyle.aspectRatio,
            )
          : constraints.maxWidth;
      return Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: SizedBox(width: width, child: _gallery(context)),
      );
    },
  );

  Widget _gallery(BuildContext context) {
    if (widget.images.isEmpty) {
      return AspectRatio(
        aspectRatio: ProductPhotoStyle.aspectRatio,
        child: ColoredBox(
          color: ModaStyle.cream,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image_not_supported_outlined, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'No approved images for ${widget.colorName ?? 'this selection'}.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Another color is not substituted.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ModaStyle.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: ProductPhotoStyle.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ProductPhotoStyle.radius),
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final media = widget.images[index];
                return Semantics(
                  button: true,
                  label:
                      'View ${widget.name}, ${widget.colorName ?? ''}, image ${index + 1} fullscreen',
                  child: GestureDetector(
                    key: const Key('product-image-fullscreen'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ProductImageScreen(
                          asset: media.path,
                          name: widget.name,
                          images: widget.images,
                          initialIndex: index,
                        ),
                      ),
                    ),
                    child: ProductImage(
                      asset: media.path,
                      semanticLabel: media.label,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            widget.images[_index].isIllustration
                ? 'Original demo illustration / not product photography'
                : widget.images[_index].label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: ModaStyle.muted),
          ),
        ),
        if (widget.images.length > 1)
          SizedBox(
            height: 64,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${_index + 1} / ${widget.images.length}',
                      key: const Key('gallery-counter'),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => Semantics(
                      selected: index == _index,
                      child: InkWell(
                        key: Key('gallery-thumbnail-$index'),
                        onTap: () => _pages.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                        child: Container(
                          width: 48,
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: index == _index
                                  ? ModaStyle.gold
                                  : ModaStyle.beige,
                              width: index == _index ? 2 : 1,
                            ),
                          ),
                          child: ProductImage(
                            asset: widget.images[index].path,
                            semanticLabel: 'Show image ${index + 1}',
                            cacheWidth: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
