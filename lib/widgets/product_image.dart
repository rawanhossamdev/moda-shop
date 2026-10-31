import 'package:flutter/material.dart';
import '../theme/moda_theme.dart';

/// Shared framing for current catalog photography. Fullscreen intentionally
/// uses contain so the full reframed photograph remains available for zoom.
abstract final class ProductPhotoStyle {
  static const aspectRatio = 3 / 4;
  static const radius = 8.0;
}

/// Keeps local photography resilient across all shopping surfaces.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.asset,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.cacheWidth = 800,
  });
  final String asset;
  final BoxFit fit;
  final Alignment alignment;
  final String? semanticLabel;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    cacheWidth: cacheWidth,
    fit: fit,
    alignment: alignment,
    semanticLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
    errorBuilder: (context, error, stackTrace) => Semantics(
      label:
          'Image unavailable${semanticLabel == null ? '' : ' for $semanticLabel'}',
      child: const ColoredBox(
        color: ModaStyle.cream,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: ModaStyle.muted,
            size: 28,
          ),
        ),
      ),
    ),
  );
}
