import 'package:flutter/material.dart';
import 'dart:async';
import 'models/cart.dart';
import 'services/local_store.dart';
import 'screens/checkout_recovery_screen.dart';
import 'theme/moda_theme.dart';
import 'screens/home_screen.dart';
import 'repositories/product_repository.dart';
import 'controllers/auth_controller.dart';
import 'repositories/auth_repository.dart';
import 'services/token_store.dart';
import 'screens/auth_screen.dart';
import 'widgets/session_check.dart';
import 'widgets/commerce_scope.dart';
import 'repositories/commerce_repository.dart';
import 'controllers/wishlist_controller.dart';
import 'widgets/wishlist_scope.dart';
import 'screens/catalog_screen.dart';

enum _SessionView { checking, retry, login, home }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ModaShop());
}

class ModaShop extends StatefulWidget {
  const ModaShop({
    super.key,
    this.repository,
    this.auth,
    this.commerce,
    this.wishlist,
  });
  final ProductRepository? repository;
  final AuthController? auth;
  final CommerceRepository? commerce;
  final WishlistController? wishlist;
  @override
  State<ModaShop> createState() => _ModaShopState();
}

class _ModaShopState extends State<ModaShop> with WidgetsBindingObserver {
  late final Cart _cart;
  var _navigatorKey = GlobalKey<NavigatorState>();
  late final ProductRepository _repository;
  late final AuthController _auth;
  late final CommerceRepository _commerce;
  late final WishlistController _wishlist;
  bool _checkingStartup = true;
  _SessionView _sessionView = _SessionView.checking;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiProductRepository();
    _cart = Cart(store: const SecureLocalStore('moda_commerce_v1'));
    unawaited(_cart.restore(_repository));
    _wishlist =
        widget.wishlist ?? WishlistController(store: DeviceWishlistStore());
    unawaited(_wishlist.restore());
    _auth =
        widget.auth ??
        AuthController(
          repository: ApiAuthRepository(),
          store: SecureTokenStore(),
        );
    WidgetsBinding.instance.addObserver(this);
    _commerce = widget.commerce ?? ApiCommerceRepository(auth: _auth);
    _auth.addListener(_sessionChanged);
    unawaited(_restoreOnLaunch());
  }

  Future<void> _restoreOnLaunch() async {
    await _auth.restore();
    if (!mounted) return;
    _checkingStartup = false;
    _sessionChanged();
  }

  void _sessionChanged() {
    if (!mounted || _checkingStartup) return;
    // Keep the retry surface while rechecking an unverified saved token.
    // A normal login request keeps its form mounted until it completes.
    final next = _auth.user != null
        ? _SessionView.home
        : _auth.busy && _sessionView == _SessionView.retry
        ? _SessionView.retry
        : _auth.restoreError != null
        ? _SessionView.retry
        : _SessionView.login;
    if (next != _sessionView) {
      setState(() {
        _sessionView = next;
        _navigatorKey = GlobalKey<NavigatorState>();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_auth.restore());
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(
        _cart.flush().catchError((Object _) {
          /* Cart exposes the storage error for retry. */
        }),
      );
    }
  }

  @override
  void dispose() {
    _cart.dispose();
    if (widget.wishlist == null) _wishlist.dispose();
    if (widget.commerce == null) _commerce.close();
    if (widget.repository == null) _repository.close();
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_sessionChanged);
    if (widget.auth == null) _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    // Replacing the session's navigator clears old detail/cart/auth routes on
    // login/logout/expiry. Cart and repository ownership stay above this key.
    key: ValueKey(_sessionView),
    navigatorKey: _navigatorKey,
    debugShowCheckedModeBanner: false,
    title: 'Moda Shop',
    theme: ModaStyle.theme,
    builder: (context, child) => CommerceScope(
      auth: _auth,
      repository: _commerce,
      cart: _cart,
      child: WishlistScope(
        controller: _wishlist,
        child: CheckoutRecoveryNotice(
          onReview: () => _navigatorKey.currentState?.push(
            MaterialPageRoute<void>(
              builder: (_) => const CheckoutRecoveryScreen(),
            ),
          ),
          child: child!,
        ),
      ),
    ),
    home: switch (_sessionView) {
      _SessionView.checking => const SessionCheck(),
      _SessionView.retry => ListenableBuilder(
        listenable: _auth,
        builder: (context, _) => SessionCheck(
          loading: _auth.busy,
          message: _auth.restoreError,
          onRetry: () => unawaited(_auth.restore()),
          onSignIn: _auth.signInInstead,
        ),
      ),
      _SessionView.login => Builder(
        builder: (context) => LoginScreen(
          auth: _auth,
          onBrowse: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  CatalogScreen(repository: _repository, cart: _cart),
            ),
          ),
        ),
      ),
      _SessionView.home => HomeScreen(
        cart: _cart,
        repository: _repository,
        auth: _auth,
      ),
    },
  );
}
