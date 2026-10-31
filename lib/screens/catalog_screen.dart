import '../theme/moda_icons.dart';
import 'dart:async';
import '../controllers/search_history.dart';
import '../services/local_store.dart';
import 'package:flutter/material.dart';
import '../models/catalog_query.dart';
import '../models/cart.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../services/products_api.dart';
import '../theme/moda_theme.dart';
import '../widgets/catalog_state.dart';
import '../widgets/product_card.dart';
import '../widgets/product_image.dart';
import '../widgets/category_strip.dart';
import '../widgets/demo_catalog_notice.dart';
import '../widgets/cart_button.dart';
import '../widgets/wishlist_scope.dart';
import 'product_details_screen.dart';
import 'wishlist_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.repository,
    required this.cart,
    this.initialCategory,
    this.historyStore,
  });
  final ProductRepository repository;
  final Cart cart;
  final String? initialCategory;
  final LocalStore? historyStore;
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final SearchHistory _history;
  void _historyChanged() {
    if (mounted) setState(() {});
  }

  void _submitSearch(String text) {
    _search.text = text;
    unawaited(_history.add(text));
    _setQuery(_withSearch());
  }

  final _search = TextEditingController();
  Timer? _debounce;
  late CatalogQuery _query;
  List<Product> _products = [];
  List<CatalogCategory> _categories = [];
  bool _loading = true;
  String? _error, _categoryError;
  int _generation = 0;
  bool _categoriesLoading = false;
  String? _pendingQuery;
  @override
  void initState() {
    super.initState();
    _history = SearchHistory(
      widget.historyStore ?? const SecureLocalStore('moda_search_history_v1'),
    );
    _history.addListener(_historyChanged);
    unawaited(_history.restore());
    _query = CatalogQuery(category: widget.initialCategory);
    _loadCategories();
    _load();
  }

  Future<void> _loadCategories() async {
    if (_categoriesLoading) return;
    _categoriesLoading = true;
    setState(() => _categoryError = null);
    try {
      final categories = await widget.repository.fetchCategories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      if (mounted) {
        setState(() => _categoryError = 'Categories are unavailable.');
      }
    } finally {
      _categoriesLoading = false;
    }
  }

  Future<void> _load() async {
    final key = _query.parameters.toString();
    if (_loading && _pendingQuery == key) return;
    _pendingQuery = key;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await widget.repository.fetchProducts(query: _query);
      if (mounted && generation == _generation) {
        setState(() {
          _products = products;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = e is ApiException
              ? e.message
              : 'Unable to load the collection. Please retry.';
        });
      }
    } finally {
      if (generation == _generation) _pendingQuery = null;
    }
  }

  void _setQuery(CatalogQuery query) {
    _debounce?.cancel();
    _query = query;
    _load();
  }

  CatalogQuery _withSearch() => CatalogQuery(
    search: _search.text,
    category: _query.category,
    minPrice: _query.minPrice,
    maxPrice: _query.maxPrice,
    size: _query.size,
    sort: _query.sort,
  );
  void _reset() {
    _search.clear();
    _setQuery(const CatalogQuery());
  }

  Future<void> _filters() async {
    final query = await showModalBottomSheet<CatalogQuery>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ModaStyle.ivory,
      builder: (_) => _Filters(query: _withSearch(), categories: _categories),
    );
    if (mounted && query != null) {
      FocusScope.of(context).unfocus();
      _setQuery(query);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _history.removeListener(_historyChanged);
    _history.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('The collection'),
      actions: [
        if (WishlistScope.maybeOf(context) != null)
          IconButton(
            tooltip: 'Wishlist',
            icon: const Icon(ModaIcons.wishlist),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => WishlistScreen(
                  repository: widget.repository,
                  cart: widget.cart,
                ),
              ),
            ),
          ),
        CartButton(cart: widget.cart),
      ],
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns =
              constraints.maxWidth < 300 ||
                  scale > 1.3 && constraints.maxWidth < 450
              ? 1
              : constraints.maxWidth > 700
              ? 3
              : 2;
          final width =
              (constraints.maxWidth - 32 - (columns - 1) * 12) / columns;
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const Key('catalog-search'),
                        controller: _search,
                        maxLength: 160,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: 'Search by product name',
                          prefixIcon: const Icon(ModaIcons.search),
                          counterText: '',
                          suffixIcon: IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _search.clear();
                              _setQuery(_withSearch());
                            },
                            icon: const Icon(ModaIcons.close),
                          ),
                        ),
                        onChanged: (_) {
                          _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 350),
                            () => _setQuery(_withSearch()),
                          );
                        },
                        onSubmitted: _submitSearch,
                      ),
                      const SizedBox(height: 12),
                      if (_history.terms.isNotEmpty) ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'RECENT SEARCHES',
                                style: ModaStyle.label,
                              ),
                            ),
                            TextButton(
                              key: const Key('clear-search-history'),
                              onPressed: _history.clear,
                              child: const Text('CLEAR HISTORY'),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final term in _history.terms)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth - 32,
                                ),
                                child: ActionChip(
                                  label: Text(
                                    term,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onPressed: () => _submitSearch(term),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_history.error != null)
                        Text(
                          _history.error!,
                          style: const TextStyle(color: ModaStyle.muted),
                        ),
                      if (_categoryError != null)
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(_categoryError!),
                            TextButton(
                              onPressed: _loadCategories,
                              child: const Text('RETRY CATEGORIES'),
                            ),
                          ],
                        ),
                      CategoryStrip(
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('All'),
                              selected: _query.category == null,
                              onSelected: (_) => _setQuery(
                                CatalogQuery(
                                  search: _search.text,
                                  minPrice: _query.minPrice,
                                  maxPrice: _query.maxPrice,
                                  size: _query.size,
                                  sort: _query.sort,
                                ),
                              ),
                            ),
                            for (final category in _categories)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: ChoiceChip(
                                  avatar: ModaIcon(
                                    ModaIcons.category(category.slug),
                                    size: 20,
                                    color: _query.category == category.slug
                                        ? ModaStyle.gold
                                        : ModaStyle.charcoal,
                                  ),
                                  label: Text(category.name),
                                  selected: _query.category == category.slug,
                                  onSelected: (_) => _setQuery(
                                    CatalogQuery(
                                      search: _search.text,
                                      category: category.slug,
                                      minPrice: _query.minPrice,
                                      maxPrice: _query.maxPrice,
                                      size: _query.size,
                                      sort: _query.sort,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _filters,
                            icon: const Icon(ModaIcons.filters, size: 18),
                            label: const Text('FILTER & SORT'),
                          ),
                          TextButton(
                            onPressed: _reset,
                            child: const Text('RESET'),
                          ),
                        ],
                      ),
                      Text(
                        _loading
                            ? 'Finding your edit…'
                            : _error != null
                            ? 'Collection unavailable'
                            : '${_products.length} pieces',
                        style: const TextStyle(color: ModaStyle.muted),
                      ),
                      if (_query.minPrice != null ||
                          _query.maxPrice != null ||
                          _query.size != null ||
                          _query.sort != 'featured')
                        Text(
                          [
                            if (_query.minPrice != null)
                              'From ${formatPrice(_query.minPrice!)}',
                            if (_query.maxPrice != null)
                              'Up to ${formatPrice(_query.maxPrice!)}',
                            if (_query.size != null) 'Size ${_query.size}',
                            if (_query.sort != 'featured')
                              _query.sort.replaceAll('_', ' '),
                          ].join(' · '),
                          style: const TextStyle(color: ModaStyle.muted),
                        ),
                    ],
                  ),
                ),
              ),
              if (_products.any((product) => product.isDemo))
                const SliverToBoxAdapter(child: DemoCatalogNotice()),
              if (_loading || _error != null)
                SliverToBoxAdapter(
                  child: CatalogState(message: _error, onRetry: _load),
                )
              else if (_products.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'No pieces found.',
                          style: ModaStyle.editorial.copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 12),
                        const Text('Try another name or refine your filters.'),
                        TextButton(
                          onPressed: _reset,
                          child: const Text('RESET FILTERS'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      mainAxisExtent:
                          width / ProductPhotoStyle.aspectRatio +
                          ProductCard.textExtent(context),
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final product = _products[index];
                      return ProductCard(
                        product: product,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ProductDetailsScreen(
                              product: product,
                              cart: widget.cart,
                              repository: widget.repository,
                            ),
                          ),
                        ),
                      );
                    }, childCount: _products.length),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _Filters extends StatefulWidget {
  const _Filters({required this.query, required this.categories});
  final CatalogQuery query;
  final List<CatalogCategory> categories;
  @override
  State<_Filters> createState() => _FiltersState();
}

class _FiltersState extends State<_Filters> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _min, _max;
  late String? _category, _size;
  late String _sort;
  @override
  void initState() {
    super.initState();
    final q = widget.query;
    _min = TextEditingController(
      text: q.minPrice == null ? '' : (q.minPrice! / 100).toStringAsFixed(2),
    );
    _max = TextEditingController(
      text: q.maxPrice == null ? '' : (q.maxPrice! / 100).toStringAsFixed(2),
    );
    _category = q.category;
    _size = q.size;
    _sort = q.sort;
  }

  int? _cents(String value) {
    if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(value.trim())) return null;
    final parts = value.trim().split('.');
    final result =
        int.parse(parts.first) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
    return result <= 2147483647 ? result : null;
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Refine your edit',
                    style: ModaStyle.editorial.copyWith(fontSize: 28),
                  ),
                ),
                IconButton(
                  tooltip: 'Close filters',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(ModaIcons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: widget.categories.any((c) => c.slug == _category)
                  ? _category
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All categories'),
                ),
                for (final c in widget.categories)
                  DropdownMenuItem(value: c.slug, child: Text(c.name)),
              ],
              onChanged: (v) => _category = v,
            ),
            const SizedBox(height: 16),
            for (final entry in [
              (_min, 'Minimum price (USD)'),
              (_max, 'Maximum price (USD)'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  controller: entry.$1,
                  decoration: InputDecoration(labelText: entry.$2),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (_cents(v) == null) {
                      return 'Enter a valid USD amount, with at most 2 decimals.';
                    }
                    if (_min.text.isNotEmpty &&
                        _max.text.isNotEmpty &&
                        _cents(_min.text) != null &&
                        _cents(_max.text) != null &&
                        _cents(_min.text)! > _cents(_max.text)!) {
                      return 'Maximum must be at least minimum.';
                    }
                    return null;
                  },
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _size,
              decoration: const InputDecoration(labelText: 'Size'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All sizes')),
                for (final size in Product.validSizes)
                  DropdownMenuItem(
                    value: size,
                    child: Text(
                      size == 'ONE_SIZE'
                          ? 'One size'
                          : size.startsWith('EU_')
                          ? 'EU ${size.substring(3)}'
                          : size,
                    ),
                  ),
              ],
              onChanged: (v) => _size = v,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _sort,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sort by'),
              items: [
                for (final item in const {
                  'featured': 'MODA edit',
                  'price_asc': 'Price: low to high',
                  'price_desc': 'Price: high to low',
                  'name': 'Name: A–Z',
                  'newest': 'Newest added',
                }.entries)
                  DropdownMenuItem(value: item.key, child: Text(item.value)),
              ],
              onChanged: (v) => _sort = v!,
            ),
            const SizedBox(height: 16),
            const CheckboxListTile(
              value: false,
              onChanged: null,
              contentPadding: EdgeInsets.zero,
              title: Text('In stock only'),
              subtitle: Text(
                'Stock tracking is not available in this catalog. Sizes do not confirm stock.',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(
                    context,
                    CatalogQuery(
                      search: widget.query.search,
                      category: _category,
                      minPrice: _cents(_min.text),
                      maxPrice: _cents(_max.text),
                      size: _size,
                      sort: _sort,
                    ),
                  );
                }
              },
              child: const Text('APPLY FILTERS'),
            ),
          ],
        ),
      ),
    ),
  );
}
