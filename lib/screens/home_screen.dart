import '../theme/moda_icons.dart';
import 'package:flutter/material.dart';
import '../models/catalog_query.dart';
import 'help_screen.dart';
import '../repositories/product_repository.dart';
import '../services/products_api.dart';
import '../widgets/catalog_state.dart';
import '../models/cart.dart';
import '../models/product.dart';
import '../theme/moda_theme.dart';
import '../widgets/cart_button.dart';
import '../widgets/product_card.dart';
import '../widgets/product_image.dart';
import '../widgets/category_strip.dart';
import '../widgets/demo_catalog_notice.dart';
import '../widgets/moda_drawer.dart';
import '../widgets/home_editorial_hero.dart';
import 'cart_screen.dart';
import 'product_details_screen.dart';
import '../controllers/auth_controller.dart';
import 'auth_screen.dart';
import '../widgets/account_sheet.dart';
import 'catalog_screen.dart';
import 'wishlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.cart,
    required this.repository,
    this.auth,
  });
  final Cart cart;
  final ProductRepository repository;
  final AuthController? auth;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();
  final _heroKey = GlobalKey();
  final _categoriesKey = GlobalKey();
  ProductCategory? _category;
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  int _requestId = 0;
  bool _showCollection = false;
  bool _requestPending = false;
  String? _pendingKey;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pendingKey =
        '${_category?.name}:${_selected == ModaDestination.arrivals}';
    if (_requestPending && _pendingKey == pendingKey) return;
    _requestPending = true;
    _pendingKey = pendingKey;
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _products = [];
    });
    try {
      final result = await widget.repository.fetchProducts(
        category: _category,
        query: _selected == ModaDestination.arrivals
            ? const CatalogQuery(sort: 'newest')
            : null,
      );
      if (!mounted || request != _requestId) return;
      setState(() {
        _products = result;
        _loading = false;
      });
      if (_showCollection) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && request == _requestId) _explore();
        });
      }
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Unable to load the collection. Please try again.';
      });
    } finally {
      if (request == _requestId) _requestPending = false;
    }
  }

  ModaDestination _selected = ModaDestination.home;
  String get _sectionLabel => switch (_selected) {
    ModaDestination.clothing => 'CLOTHING',
    ModaDestination.accessories => 'ACCESSORIES',
    ModaDestination.bags => 'BAGS',
    ModaDestination.shoes => 'SHOES',
    ModaDestination.jewelry => 'JEWELRY',
    ModaDestination.shopAll => 'SHOP ALL',
    _ => 'NEW ARRIVAL',
  };

  void _select(ModaDestination destination) {
    if (destination == ModaDestination.help) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
      );
      return;
    }
    if (destination == ModaDestination.wishlist) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              WishlistScreen(repository: widget.repository, cart: widget.cart),
        ),
      );
      return;
    }
    if (destination == ModaDestination.login ||
        destination == ModaDestination.signUp) {
      final auth = widget.auth;
      if (auth != null) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => destination == ModaDestination.login
                ? LoginScreen(auth: auth)
                : SignUpScreen(auth: auth),
          ),
        );
      }
      return;
    }
    if (destination == ModaDestination.logout ||
        destination == ModaDestination.restoreSession) {
      _accountAction(destination);
      return;
    }
    if (destination == ModaDestination.cart) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CartScreen(cart: widget.cart)),
      );
      return;
    }
    if (destination == ModaDestination.about) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: ModaStyle.ivory,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: ModaWordmark()),
                    IconButton(
                      tooltip: 'Close about MODA',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(ModaIcons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Style, on your terms.',
                  style: ModaStyle.editorial.copyWith(fontSize: 30),
                ),
                const SizedBox(height: 16),
                const Text(
                  'A considered edit. An individual expression. MODA brings together looks for your everyday wardrobe.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'An independent Flutter portfolio project with a curated collection.',
                  style: TextStyle(color: ModaStyle.muted),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _selected = destination;
      _showCollection = destination != ModaDestination.home;
      _category = switch (destination) {
        ModaDestination.clothing => ProductCategory.clothing,
        ModaDestination.accessories => ProductCategory.accessories,
        ModaDestination.bags => ProductCategory.bags,
        ModaDestination.shoes => ProductCategory.shoes,
        ModaDestination.jewelry => ProductCategory.jewelry,
        _ => null,
      };
    });
    _load();
    // Rebuild the editorial header before measuring its rendered height.
    _scroll.jumpTo(0);
    if (destination != ModaDestination.home) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _explore();
      });
    }
  }

  Future<void> _accountAction(ModaDestination destination) async {
    final auth = widget.auth;
    if (auth == null) return;
    String? message;
    try {
      if (destination == ModaDestination.restoreSession) {
        await auth.restore();
        message = auth.restoreError;
      } else {
        message = await auth.logout();
      }
    } catch (error) {
      message = error is ApiException
          ? error.message
          : 'Unable to update your session. Please retry.';
    }
    if (mounted && message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openAccount() async {
    final auth = widget.auth;
    if (auth == null || auth.busy) return;
    if (auth.user == null) {
      _select(ModaDestination.login);
      return;
    }
    final message = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ModaStyle.ivory,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => AccountSheet(auth: auth),
    );
    if (mounted && message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _explore() {
    _showCollection = true;
    // A response may have scheduled a layout in the same frame as this tap.
    // Measure after that layout so the loading state's old extent is not used.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showCollection) _scrollToCollection();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _scrollToCollection() {
    final box = _heroKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_scroll.hasClients) return;
    final categoryHeight =
        (_categoriesKey.currentContext?.findRenderObject() as RenderBox?)
            ?.size
            .height ??
        0;
    final target = (box.size.height + categoryHeight).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: widget.auth == null
        ? ModaDrawer(onSelect: _select, selected: _selected)
        : ListenableBuilder(
            listenable: widget.auth!,
            builder: (context, _) => ModaDrawer(
              onSelect: _select,
              selected: _selected,
              auth: widget.auth,
            ),
          ),
    appBar: AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          tooltip: 'Open menu',
          icon: const Icon(ModaIcons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      titleSpacing: 0,
      title: const FittedBox(fit: BoxFit.scaleDown, child: ModaWordmark()),
      actions: [
        if (widget.auth != null)
          ListenableBuilder(
            listenable: widget.auth!,
            builder: (context, _) => IconButton(
              tooltip: 'Account',
              onPressed: widget.auth!.busy ? null : _openAccount,
              icon: const Icon(ModaIcons.profile),
            ),
          ),
        CartButton(cart: widget.cart),
        const SizedBox(width: 8),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final visibleProducts = _products;
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final columns =
                  constraints.maxWidth < 300 ||
                      (scale > 1.3 && constraints.maxWidth < 450)
                  ? 1
                  : constraints.maxWidth >= 1000
                  ? 4
                  : constraints.maxWidth >= 650
                  ? 3
                  : 2;
              final padding = constraints.maxWidth < 360
                  ? 10.0
                  : constraints.maxWidth < 600
                  ? 10.0
                  : 40.0;
              final cardWidth =
                  (constraints.maxWidth - padding * 2 - (columns - 1) * 12) /
                  columns;
              return CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      key: _heroKey,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: HomeEditorialHero(onExplore: _explore),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: CategoryStrip(
                      key: _categoriesKey,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          for (final category
                              in <(String, String, ModaDestination)>[
                                (
                                  'Clothing',
                                  'clothing',
                                  ModaDestination.clothing,
                                ),
                                ('Bags', 'bags', ModaDestination.bags),
                                ('Shoes', 'shoes', ModaDestination.shoes),
                                ('Jewelry', 'jewelry', ModaDestination.jewelry),
                                (
                                  'Accessories',
                                  'accessories',
                                  ModaDestination.accessories,
                                ),
                              ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                avatar: ModaIcon(
                                  ModaIcons.category(category.$2),
                                  size: 20,
                                  color: _selected == category.$3
                                      ? ModaStyle.gold
                                      : ModaStyle.charcoal,
                                ),
                                label: Text(category.$1),
                                onPressed: () => _select(category.$3),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      key: const Key('new-arrival-section'),
                      padding: EdgeInsets.fromLTRB(padding, 4, padding, 0),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 24,
                            child: Divider(color: ModaStyle.gold),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _sectionLabel,
                              style: ModaStyle.editorial.copyWith(
                                fontSize: 12,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          IconButton(
                            tooltip: 'Search and filter products',
                            icon: const Icon(ModaIcons.search, size: 20),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => CatalogScreen(
                                  repository: widget.repository,
                                  cart: widget.cart,
                                  initialCategory: _category?.name,
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _select(ModaDestination.shopAll),
                            style: TextButton.styleFrom(
                              foregroundColor: ModaStyle.charcoal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: const Size(48, 48),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('See All', style: TextStyle(fontSize: 12)),
                                SizedBox(width: 3),
                                Icon(ModaIcons.next, size: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Center(
                        child: CatalogState(message: _error, onRetry: _load),
                      ),
                    ),
                  if (!_loading && _error == null && visibleProducts.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
                        child: Column(
                          children: [
                            const Icon(
                              ModaIcons.bags,
                              size: 36,
                              color: ModaStyle.muted,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _category == ProductCategory.accessories
                                  ? 'No accessories yet'
                                  : 'No products yet',
                              style: ModaStyle.editorial.copyWith(fontSize: 28),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'There are no products in this selection. Explore the collection to find your next look.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: ModaStyle.muted),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton(
                              onPressed: () => _select(ModaDestination.shopAll),
                              child: const Text('SHOP ALL'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (visibleProducts.any((product) => product.isDemo))
                    const SliverToBoxAdapter(child: DemoCatalogNotice()),
                  if (!_loading && _error == null && visibleProducts.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(padding, 0, padding, 32),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          mainAxisExtent:
                              cardWidth / ProductPhotoStyle.aspectRatio +
                              ProductCard.textExtent(context),
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final product = visibleProducts[index];
                          return ProductCard(
                            key: ValueKey(product.id),
                            product: product,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ProductDetailsScreen(
                                  product: product,
                                  cart: widget.cart,
                                  repository: widget.repository,
                                ),
                              ),
                            ),
                          );
                        }, childCount: visibleProducts.length),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Container(
                      color: ModaStyle.cream,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 40,
                      ),
                      child: Column(
                        children: [
                          const ModaWordmark(),
                          const SizedBox(height: 18),
                          Text(
                            'Style, on your terms.',
                            textAlign: TextAlign.center,
                            style: ModaStyle.editorial.copyWith(fontSize: 26),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'A considered edit. An individual expression.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ModaStyle.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
