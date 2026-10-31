import 'package:flutter/material.dart';
import '../theme/moda_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'HELP & SUPPORT',
        style: ModaStyle.label.copyWith(fontSize: 12),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'A little guidance.',
                style: ModaStyle.editorial.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 16),
              const Text('PORTFOLIO DEMONSTRATION', style: ModaStyle.label),
              const SizedBox(height: 12),
              const Text(
                'MODA is a portfolio shopping demonstration. The information below describes this app, not a real store promise or manufacturer policy.',
              ),
              const SizedBox(height: 24),
              const ExpansionTile(
                title: Text('Shipping & delivery'),
                childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  Text(
                    'Checkout supports saved Egyptian shipping addresses. The shipping fee is a configured demonstration placeholder shown before ordering. No carrier rates, dispatch dates or delivery estimates are claimed. Orders remain in the catalog currency (USD); no conversion is applied.',
                  ),
                ],
              ),
              const ExpansionTile(
                title: Text('Returns & cancellations'),
                childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  Text(
                    'No real return window, refund promise or exchange policy is configured for this demonstration. Eligible unpaid orders can be cancelled from Order Details. Cancellation does not imply that a payment or refund has occurred.',
                  ),
                ],
              ),
              const ExpansionTile(
                title: Text('Cash on Delivery & order recovery'),
                childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  Text(
                    'Cash on Delivery is the only active payment method. New orders are Pending and Unpaid. If a connection is lost while ordering, use REVIEW CHECKOUT to check or retry the original request. Avoid starting a separate order until its result is known.',
                  ),
                ],
              ),
              const ExpansionTile(
                title: Text('Product information & sizing'),
                childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  Text(
                    'Choose only the sizes listed for each product. One Size products do not need a clothing-size selection. Sample product information is labeled; manufacturer measurements, fabric composition and fit are not verified unless explicitly supplied.',
                  ),
                ],
              ),
              const ExpansionTile(
                title: Text('Customer support'),
                childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  Text(
                    'A public support email, phone number and live support service have not been provided for this portfolio demonstration. No message is sent from this screen. You can review addresses and order history in your account, or retain your order reference for the project owner.',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
