import '../theme/moda_icons.dart';
import 'dart:async';
import 'help_screen.dart';
import '../widgets/product_gallery.dart';
import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../models/product.dart';
import '../theme/moda_theme.dart';
import '../widgets/cart_button.dart';
import 'cart_screen.dart';
import '../repositories/product_repository.dart';
import '../services/products_api.dart';
import '../widgets/catalog_state.dart';
import '../widgets/wishlist_scope.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.product,
    required this.cart,
    required this.repository,
  });
  final Product product;
  final Cart cart;
  final ProductRepository repository;
  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  String _size = 'M';
  String? _colorId;
  ProductVariant? get _variant =>
      _product?.selectVariant(_size, colorId: _colorId);
  ProductColor? get _color =>
      _product?.colors.where((c) => c.id == _colorId).firstOrNull;
  List<String> get _colorSizes => _product == null
      ? []
      : _product!.variants.isEmpty
      ? _product!.availableSizes
      : _product!.variants
            .where((v) => v.colorId == _colorId)
            .map((v) => v.size)
            .toSet()
            .toList();
  void _chooseColor(String id) {
    setState(() {
      _colorId = id;
      if (_variant == null) {
        _size =
            _product!.isOneSize &&
                _product!.selectVariant('ONE_SIZE', colorId: id) != null
            ? 'ONE_SIZE'
            : '';
      }
    });
  }

  Product? _product;
  String? _error;
  bool _loading = false;
  bool _adding = false;
  Timer? _addCooldown;
  @override
  void dispose() {
    _addCooldown?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    setState(() {
      _product = null;
      _error = null;
    });
    try {
      final product = await widget.repository.fetchProduct(widget.product.id);
      if (!mounted) return;
      setState(() {
        _product = product;
        if (!product.availableColors.any((c) => c.id == _colorId)) {
          _colorId =
              product.availableColors
                  .where((c) => c.id == product.defaultColorId)
                  .firstOrNull
                  ?.id ??
              product.availableColors.firstOrNull?.id;
        }
        if (product.selectVariant(_size, colorId: _colorId) == null) {
          _size = product.variants.isEmpty
              ? product.availableSizes.firstOrNull ?? ''
              : product.variants
                        .where((v) => v.colorId == _colorId && v.isAvailable)
                        .firstOrNull
                        ?.size ??
                    '';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is ApiException
            ? error.message
            : 'Unable to load this product. Please try again.',
      );
    } finally {
      _loading = false;
    }
  }

  void _add() {
    if (_adding || _product == null || _variant == null) {
      return;
    }
    if (!widget.cart.ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your saved cart is still being restored. Open your cart to retry.',
          ),
        ),
      );
      return;
    }
    setState(() => _adding = true);
    _addCooldown = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _adding = false);
    });
    try {
      if (_product!.variants.isEmpty) {
        widget.cart.add(_product!, _size);
      } else {
        widget.cart.addVariant(_product!, _variant!);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to add this piece. Please select an available size and try again.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${_product!.name} · ${variantLabel(_size, _color?.name)} added to cart',
          ),
          action: SnackBarAction(
            label: 'VIEW CART',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CartScreen(cart: widget.cart),
              ),
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    if (product == null) {
      return Scaffold(
        appBar: AppBar(
          title: const ModaWordmark(),
          actions: [
            CartButton(cart: widget.cart),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: CatalogState(message: _error, onRetry: _load),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(ModaIcons.add, size: 20),
              label: const Text('ADD TO CART'),
            ),
          ),
        ),
      );
    }
    final info = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('THE MODA COLLECTION', style: ModaStyle.label),
          const SizedBox(height: 16),
          Text(product.name, style: ModaStyle.editorial.copyWith(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            product.categoryName,
            style: const TextStyle(color: ModaStyle.muted),
          ),
          const SizedBox(height: 16),
          Text(
            formatPrice(_variant?.priceInCents ?? product.priceInCents),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Divider(),
          ),
          if (product.isDemo)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'SAMPLE USD PRICE / DEMO AVAILABILITY',
                style: ModaStyle.label,
              ),
            ),
          if (product.availableColors.isNotEmpty) ...[
            Text(
              'COLOR / ${_color?.name ?? 'Select a color'}',
              style: ModaStyle.label,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in product.availableColors)
                  Semantics(
                    button: true,
                    selected: color.id == _colorId,
                    label: 'Select color ${color.name}',
                    child: Tooltip(
                      message: color.name,
                      child: InkWell(
                        key: Key('color-${color.key}'),
                        onTap: () => _chooseColor(color.id),
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(
                                  int.parse(
                                    'FF${color.hex.substring(1)}',
                                    radix: 16,
                                  ),
                                ),
                                border: Border.all(
                                  color: color.id == _colorId
                                      ? ModaStyle.gold
                                      : ModaStyle.beige,
                                  width: color.id == _colorId ? 3 : 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          Text(
            _size.isEmpty
                ? (_colorSizes.isEmpty
                      ? 'No sizes available'
                      : 'Select an available size')
                : product.isOneSize
                ? 'One Size'
                : 'SIZE — ${_size.startsWith('EU_') ? sizeLabel(_size) : _size}',
            style: ModaStyle.label,
          ),
          const SizedBox(height: 12),
          if (!product.isOneSize)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colorSizes
                  .map(
                    (size) => Semantics(
                      selected: _size == size,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(54, 50),
                          backgroundColor: _size == size
                              ? ModaStyle.charcoal
                              : Colors.transparent,
                          foregroundColor: _size == size
                              ? ModaStyle.ivory
                              : ModaStyle.charcoal,
                          side: BorderSide(
                            color: _size == size
                                ? ModaStyle.charcoal
                                : ModaStyle.beige,
                          ),
                        ),
                        onPressed:
                            product.selectVariant(size, colorId: _colorId) ==
                                null
                            ? null
                            : () => setState(() => _size = size),
                        child: Text(
                          size == 'ONE_SIZE'
                              ? 'One Size'
                              : size.startsWith('EU_')
                              ? 'EU ${size.substring(3)}'
                              : size,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 28),
          if (product.informationIsSample) ...[
            const Text('SAMPLE PRODUCT INFORMATION', style: ModaStyle.label),
            const SizedBox(height: 8),
            const Text(
              'Portfolio demonstration content, not verified manufacturer specifications.',
              style: TextStyle(color: ModaStyle.muted),
            ),
            const SizedBox(height: 16),
          ],
          for (final entry in <String, String?>{
            'Description': product.description,
            'Materials': product.materials,
            'Care instructions': product.careInstructions,
            'Size & fit': product.sizeAndFit,
          }.entries)
            if (entry.value?.trim().isNotEmpty == true)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(entry.key),
                childrenPadding: const EdgeInsets.only(bottom: 16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      entry.value!,
                      style: const TextStyle(height: 1.7),
                    ),
                  ),
                ],
              ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
            ),
            child: const Text('Shipping, returns & support'),
          ),
          const SizedBox(height: 20),
          const Text('AVAILABILITY', style: ModaStyle.label),
          const SizedBox(height: 12),
          Text(
            product.availableSizes.isEmpty
                ? 'No variants are currently available.'
                : product.isOneSize
                ? 'One Size. Live stock quantities are not tracked.'
                : 'Listed sizes are shown above. Live stock quantities are not tracked.',
            style: TextStyle(height: 1.8, color: ModaStyle.muted),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              SizedBox(width: 28, child: Divider(color: ModaStyle.gold)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Selected by MODA. Styled by you.',
                  style: TextStyle(fontSize: 12, color: ModaStyle.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const ModaWordmark(),
        actions: [
          WishlistButton(productId: product.id),
          CartButton(cart: widget.cart),
          const SizedBox(width: 12),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: ModaStyle.ivory,
          border: Border(top: BorderSide(color: ModaStyle.beige)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _variant == null || _adding ? null : _add,
                    icon: const Icon(ModaIcons.add, size: 20),
                    label: const Text('ADD TO CART'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gallery = ProductGallery(
                    key: ValueKey('${product.id}:$_colorId'),
                    images: product.galleryFor(_colorId),
                    name: product.name,
                    colorName: _color?.name,
                  );
                  return constraints.maxWidth >= 700
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: gallery),
                            Expanded(child: info),
                          ],
                        )
                      : Column(children: [gallery, info]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
