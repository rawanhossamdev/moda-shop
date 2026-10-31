import 'package:flutter/material.dart';
import '../models/product_variant.dart';
import '../widgets/product_image.dart';
import '../theme/moda_theme.dart';

class ProductImageScreen extends StatefulWidget {
  const ProductImageScreen({
    super.key,
    required this.asset,
    required this.name,
    this.images = const [],
    this.initialIndex = 0,
  });
  final String asset, name;
  final List<ProductMedia> images;
  final int initialIndex;
  @override
  State<ProductImageScreen> createState() => _ProductImageScreenState();
}

class _ProductImageScreenState extends State<ProductImageScreen> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images.isEmpty
        ? [
            ProductMedia(
              id: 'primary',
              path: widget.asset,
              kind: 'photo',
              label: widget.name,
            ),
          ]
        : widget.images;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Pinch to zoom. Drag to explore.  ${_index + 1} / ${images.length}',
                style: const TextStyle(color: ModaStyle.muted),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: images.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (_, index) => _ZoomImage(media: images[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                images[_index].label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ModaStyle.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomImage extends StatefulWidget {
  const _ZoomImage({required this.media});
  final ProductMedia media;
  @override
  State<_ZoomImage> createState() => _ZoomImageState();
}

class _ZoomImageState extends State<_ZoomImage> {
  final _transform = TransformationController();
  bool _zoomed = false;
  @override
  void initState() {
    super.initState();
    _transform.addListener(_changed);
  }

  void _changed() {
    final value = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (value != _zoomed) setState(() => _zoomed = value);
  }

  @override
  void dispose() {
    _transform.removeListener(_changed);
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    transformationController: _transform,
    minScale: 1,
    maxScale: 5,
    panEnabled: _zoomed,
    child: Center(
      child: ProductImage(
        asset: widget.media.path,
        semanticLabel: widget.media.label,
        fit: BoxFit.contain,
        cacheWidth: null,
      ),
    ),
  );
}
