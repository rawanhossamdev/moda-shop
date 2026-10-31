import 'package:flutter/material.dart';
import '../theme/moda_theme.dart';
import 'editorial_image.dart';

/// Original editorial still life, with the wardrobe right of the copy.
class HomeEditorialHero extends StatelessWidget {
  const HomeEditorialHero({super.key, required this.onExplore});
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final phone = bounds.maxWidth < 600;
      final typeSize = phone
          ? (bounds.maxWidth * .073).clamp(23.0, 30.0)
          : 46.0;
      final inset = phone ? 22.0 : 40.0;
      final copyWidth = phone ? bounds.maxWidth * .54 : bounds.maxWidth * .48;
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, frame) {
                  // Keep the blazer/bag grouping visible on narrow phones while
                  // the existing gradient protects the left editorial copy.
                  final imageWidth = frame.maxHeight * 3;
                  final overflow = imageWidth - frame.maxWidth;
                  final alignment = overflow > 0
                      ? (2 *
                                    (.80 * imageWidth - .68 * frame.maxWidth) /
                                    overflow -
                                1)
                            .clamp(-1.0, 1.0)
                      : 0.0;
                  return EditorialImage(
                    asset: 'assets/images/moda_banner.png',
                    fit: BoxFit.cover,
                    cacheWidth: null,
                    alignment: Alignment(alignment, -1),
                  );
                },
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xCFF2E8D8),
                      Color(0x9EF2E8D8),
                      Color(0x00F2E8D8),
                    ],
                    stops: [0, .35, .68],
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: bounds.maxWidth * (phone ? .63 : .35),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  inset,
                  phone ? 24 : 40,
                  0,
                  phone ? 18 : 40,
                ),
                child: SizedBox(
                  width: copyWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'THE MODA EDIT / 01',
                        style: ModaStyle.label.copyWith(
                          fontSize: phone ? 8 : 11,
                          letterSpacing: phone ? 1.35 : 2.2,
                          color: ModaStyle.charcoal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The art of\neveryday\ndressing.',
                        style: ModaStyle.editorial.copyWith(
                          fontSize: typeSize,
                          height: 1.02,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const SizedBox(
                        width: 28,
                        child: Divider(color: ModaStyle.gold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'An expression of you.\nA wardrobe of possibility.',
                        style: TextStyle(
                          fontSize: phone ? 10 : 14,
                          height: 1.35,
                          color: ModaStyle.charcoal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: onExplore,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          side: const BorderSide(color: ModaStyle.gold),
                          backgroundColor: const Color(0x30FAF7F2),
                          textStyle: TextStyle(
                            fontSize: phone ? 8 : 11,
                            letterSpacing: phone ? 1.1 : 1.5,
                          ),
                        ),
                        child: Text(
                          'EXPLORE COLLECTION',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: phone ? 8 : 11,
                            letterSpacing: phone ? 1.1 : 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
