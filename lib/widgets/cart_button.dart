import '../theme/moda_icons.dart';
import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../screens/cart_screen.dart';
import '../theme/moda_theme.dart';

class CartButton extends StatelessWidget {
  const CartButton({super.key, required this.cart});
  final Cart cart;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: cart,
    builder: (context, _) => IconButton(
      tooltip: 'Open cart',
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => CartScreen(cart: cart))),
      icon: Badge(
        backgroundColor: ModaStyle.charcoal,
        textColor: ModaStyle.ivory,
        isLabelVisible: cart.count > 0,
        label: Text('${cart.count}'),
        child: const Icon(ModaIcons.cart),
      ),
    ),
  );
}
