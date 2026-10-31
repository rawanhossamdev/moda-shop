import 'package:flutter/material.dart';
import 'product_image.dart';

/// A restrained display-only finish: 3% lower contrast, approximately 2%
/// lower saturation, and a barely warmer shadow lift. No blur or asset edits.
class EditorialImage extends StatelessWidget {
  const EditorialImage({
    super.key,
    required this.asset,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.cacheWidth = 800,
  });

  final String asset;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) => ColorFiltered(
    colorFilter: const ColorFilter.matrix([
      .955,
      .014,
      .001,
      0,
      4,
      .004,
      .965,
      .001,
      0,
      4,
      .004,
      .014,
      .952,
      0,
      3,
      0,
      0,
      0,
      1,
      0,
    ]),
    child: ProductImage(
      asset: asset,
      fit: fit,
      alignment: alignment,
      cacheWidth: cacheWidth,
    ),
  );
}
