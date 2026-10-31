import 'package:flutter/widgets.dart';
import '../controllers/auth_controller.dart';
import '../repositories/commerce_repository.dart';
import '../models/cart.dart';

class CommerceScope extends InheritedWidget {
  const CommerceScope({
    super.key,
    required this.auth,
    required this.repository,
    required this.cart,
    required super.child,
  });
  final AuthController auth;
  final CommerceRepository repository;
  final Cart cart;
  static CommerceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CommerceScope>();
  static CommerceScope of(BuildContext context) => maybeOf(context)!;
  @override
  bool updateShouldNotify(CommerceScope oldWidget) =>
      auth != oldWidget.auth || repository != oldWidget.repository;
}
