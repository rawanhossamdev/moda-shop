import '../theme/moda_icons.dart';
import 'package:flutter/material.dart';
import '../theme/moda_theme.dart';
import '../controllers/auth_controller.dart';

enum ModaDestination {
  home,
  shopAll,
  clothing,
  bags,
  shoes,
  jewelry,
  accessories,
  arrivals,
  wishlist,
  cart,
  about,
  help,
  login,
  signUp,
  logout,
  restoreSession,
}

class ModaDrawer extends StatelessWidget {
  const ModaDrawer({
    super.key,
    required this.onSelect,
    required this.selected,
    this.auth,
  });
  final ValueChanged<ModaDestination> onSelect;
  final ModaDestination selected;
  final AuthController? auth;

  @override
  Widget build(BuildContext context) {
    Widget item(String title, Object icon, ModaDestination destination) =>
        ListTile(
          leading: ModaIcon(
            icon,
            size: 22,
            color: selected == destination
                ? ModaStyle.gold
                : ModaStyle.charcoal,
          ),
          title: Text(title),
          selected: selected == destination,
          selectedColor: ModaStyle.charcoal,
          selectedTileColor: ModaStyle.cream,
          onTap: () {
            Navigator.of(context).pop();
            onSelect(destination);
          },
        );
    return Drawer(
      width: MediaQuery.sizeOf(context).width * .86 > 340
          ? 340
          : MediaQuery.sizeOf(context).width * .86,
      backgroundColor: ModaStyle.ivory,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 8, 16),
              child: Row(
                children: [
                  const Expanded(child: ModaWordmark()),
                  IconButton(
                    tooltip: 'Close menu',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(ModaIcons.close, size: 22),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  item('Home', ModaIcons.home, ModaDestination.home),
                  item(
                    'Shop All',
                    ModaIcons.categories,
                    ModaDestination.shopAll,
                  ),
                  item(
                    'Clothing',
                    ModaIcons.clothing,
                    ModaDestination.clothing,
                  ),
                  item('Bags', ModaIcons.bags, ModaDestination.bags),
                  item('Shoes', ModaIcons.shoes, ModaDestination.shoes),
                  item('Jewelry', ModaIcons.jewelry, ModaDestination.jewelry),
                  item(
                    'Accessories',
                    ModaIcons.accessories,
                    ModaDestination.accessories,
                  ),
                  item(
                    'New Arrivals',
                    ModaIcons.arrivals,
                    ModaDestination.arrivals,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Divider(),
                  ),
                  item(
                    'Wishlist',
                    ModaIcons.wishlist,
                    ModaDestination.wishlist,
                  ),
                  item('My Cart', ModaIcons.cart, ModaDestination.cart),
                  item('About MODA', Icons.info_outline, ModaDestination.about),
                  item('Help & Support', ModaIcons.help, ModaDestination.help),
                  if (auth != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Divider(),
                    ),
                    if (auth!.busy)
                      const ListTile(
                        leading: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        title: Text('Checking account…'),
                      )
                    else if (auth!.user != null) ...[
                      ListTile(
                        leading: const Icon(ModaIcons.profile),
                        title: Text(auth!.user!.name),
                        subtitle: Text(auth!.user!.email),
                      ),
                      item('Logout', Icons.logout, ModaDestination.logout),
                    ] else ...[
                      item('Login', ModaIcons.profile, ModaDestination.login),
                      item(
                        'Sign Up',
                        Icons.person_add_outlined,
                        ModaDestination.signUp,
                      ),
                    ],
                    if (!auth!.busy && auth!.restoreError != null)
                      ListTile(
                        leading: const Icon(ModaIcons.refresh),
                        title: const Text('Retry saved session'),
                        subtitle: Text(auth!.restoreError!),
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelect(ModaDestination.restoreSession);
                        },
                      ),
                  ],
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Divider(color: ModaStyle.gold),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Style, on your terms.',
                          style: TextStyle(fontFamily: 'serif', fontSize: 21),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'A considered edit.\nAn individual expression.',
                          style: TextStyle(
                            color: ModaStyle.muted,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
