import 'package:flutter/material.dart';

/// Built-in Material outline/line icons: no additional font or package required.
enum ModaVector { shoe }

abstract final class ModaIcons {
  static const home = Icons.home_outlined;
  static const search = Icons.search_outlined;
  static const categories = Icons.grid_view_outlined;
  static const clothing = Icons.checkroom_outlined;
  static const bags = Icons.work_outline;
  static const shoes = ModaVector.shoe;
  static const jewelry = Icons.diamond_outlined;
  static const accessories = Icons.watch_outlined;
  static const wishlist = Icons.favorite_border;
  static const cart = Icons.shopping_bag_outlined;
  static const filters = Icons.tune;
  static const profile = Icons.person_outline;
  static const address = Icons.location_on_outlined;
  static const checkout = Icons.local_shipping_outlined;
  static const orders = Icons.receipt_long_outlined;
  static const help = Icons.help_outline;
  static const menu = Icons.menu;
  static const close = Icons.close;
  static const refresh = Icons.refresh;
  static const add = Icons.add;
  static const remove = Icons.remove;
  static const delete = Icons.delete_outline;
  static const next = Icons.chevron_right;
  static const arrivals = Icons.auto_awesome_outlined;
  static Object category(String slug) => switch (slug) {
    'clothing' => clothing,
    'bags' => bags,
    'shoes' => shoes,
    'jewelry' => jewelry,
    'accessories' => accessories,
    _ => categories,
  };
}

/// A small local vector keeps footwear recognizable without another icon font.
class ModaIcon extends StatelessWidget {
  const ModaIcon(this.icon, {super.key, this.size, this.color});
  final Object icon;
  final double? size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final glyph = icon;
    if (glyph is IconData) return Icon(glyph, size: size, color: color);
    final theme = IconTheme.of(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size ?? theme.size ?? 22,
        child: CustomPaint(
          painter: _ShoePainter(
            color ?? theme.color ?? const Color(0xFF252320),
          ),
        ),
      ),
    );
  }
}

class _ShoePainter extends CustomPainter {
  const _ShoePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Pointed-toe slingback: low vamp, raised heel, slender heel post.
    final shoe = Path()
      ..moveTo(2.5, 16)
      ..lineTo(9, 13.5)
      ..quadraticBezierTo(12, 12.2, 14, 7)
      ..lineTo(18.5, 7)
      ..lineTo(21.5, 14)
      ..lineTo(21.5, 17)
      ..lineTo(17.5, 17)
      ..quadraticBezierTo(14, 15.5, 11.5, 17)
      ..lineTo(3, 17)
      ..quadraticBezierTo(1.5, 17, 2.5, 16);
    canvas.drawPath(shoe, pen);
    canvas.drawPath(
      Path()
        ..moveTo(18.5, 17)
        ..lineTo(18, 21)
        ..lineTo(20, 21)
        ..lineTo(21.5, 17),
      pen,
    );
    canvas.drawPath(
      Path()
        ..moveTo(14, 7)
        ..quadraticBezierTo(17, 10, 20, 10.5),
      pen,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShoePainter oldDelegate) => oldDelegate.color != color;
}
