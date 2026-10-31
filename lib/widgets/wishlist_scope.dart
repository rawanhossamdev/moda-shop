import '../theme/moda_icons.dart';
import 'package:flutter/material.dart';
import '../controllers/wishlist_controller.dart';

class WishlistScope extends InheritedNotifier<WishlistController> {
  const WishlistScope({
    super.key,
    required WishlistController controller,
    required super.child,
  }) : super(notifier: controller);
  static WishlistController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WishlistScope>()?.notifier;
}

class WishlistButton extends StatelessWidget {
  const WishlistButton({super.key, required this.productId});
  final String productId;
  @override
  Widget build(BuildContext context) {
    final wishlist = WishlistScope.maybeOf(context);
    if (wishlist == null) return const SizedBox.shrink();
    final saved = wishlist.contains(productId);
    return IconButton(
      tooltip: saved ? 'Remove from wishlist' : 'Save to wishlist',
      isSelected: saved,
      onPressed: wishlist.loading || wishlist.saving
          ? null
          : () async {
              if (wishlist.error != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(wishlist.error!)));
                return;
              }
              try {
                await wishlist.toggle(productId);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unable to save your wishlist. Please retry.',
                      ),
                    ),
                  );
                }
              }
            },
      icon: Icon(
        ModaIcons.wishlist,
        color: saved ? const Color(0xFFA58A57) : null,
      ),
    );
  }
}
