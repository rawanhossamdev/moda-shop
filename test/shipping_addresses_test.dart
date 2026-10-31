import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/data/products.dart';
import 'package:moda_shop/models/cart.dart';
import 'package:moda_shop/models/product.dart';
import 'package:moda_shop/models/shipping_address.dart';
import 'package:moda_shop/screens/address_screens.dart';
import 'package:moda_shop/screens/checkout_screen.dart';
import 'package:moda_shop/services/products_api.dart';
import 'commerce_test.dart' show app, authFixture;
import 'support/fake_commerce.dart';

Map<String, dynamic> fields({String city = 'Maadi'}) => {
  'fullName': 'MODA Member',
  'mobile': '01012345678',
  'governorate': 'Cairo',
  'city': city,
  'streetAddress': '25 Test street',
  'buildingDetails': 'Building 25, apartment 4',
  'deliveryNotes': '',
  'isDefault': false,
};

void main() {
  test(
    'Address validation accepts Egyptian mobile prefixes and rejects invalid/required fields',
    () {
      for (final mobile in [
        '01012345678',
        '+201012345678',
        '00201012345678',
        '011 1234 5678',
        '01212345678',
        '01512345678',
      ]) {
        expect(validateAddressField('mobile', mobile), isNull);
      }
      for (final mobile in [
        '01312345678',
        '0101234567',
        '+12012345678',
        '010abcdefgh',
      ]) {
        expect(validateAddressField('mobile', mobile), isNotNull);
      }
      for (final key in addressLabels.keys.where(
        (key) => key != 'deliveryNotes',
      )) {
        expect(validateAddressField(key, ''), isNotNull);
      }
      expect(validateAddressField('deliveryNotes', ''), isNull);
      expect(validateAddressField('fullName', 'A\nB'), isNotNull);
    },
  );

  testWidgets(
    'Address form rejects missing fields and invalid Egyptian mobile numbers',
    (tester) async {
      final auth = await authFixture(),
          repo = FakeCommerceRepository(),
          cart = Cart();
      addTearDown(cart.dispose);
      await tester.pumpWidget(app(const AddressEditScreen(), auth, repo, cart));
      await tester.ensureVisible(find.byKey(const Key('save-address')));
      await tester.tap(find.byKey(const Key('save-address')));
      await tester.pumpAndSettle();
      expect(repo.addressSaves, 0);
      for (final entry in fields().entries.where((e) => e.value is String)) {
        await tester.ensureVisible(find.byKey(Key(entry.key)));
        await tester.enterText(
          find.byKey(Key(entry.key)),
          entry.value as String,
        );
      }
      await tester.enterText(find.byKey(const Key('mobile')), '01312345678');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('save-address')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-address')));
      await tester.pumpAndSettle();
      expect(repo.addressSaves, 0);
      expect(find.textContaining('Enter an Egyptian mobile'), findsOneWidget);
    },
  );

  testWidgets(
    'Address book supports edit, default, selection and deletion with confirmation',
    (tester) async {
      final auth = await authFixture(),
          repo = FakeCommerceRepository(),
          cart = Cart();
      addTearDown(cart.dispose);
      await repo.saveAddress(fields());
      final second = await repo.saveAddress(fields(city: 'Heliopolis'));
      await tester.pumpWidget(app(const AddressBookScreen(), auth, repo, cart));
      await tester.pumpAndSettle();
      expect(find.text('DEFAULT ADDRESS'), findsOneWidget);
      await tester.ensureVisible(find.text('MAKE DEFAULT'));
      await tester.tap(find.text('MAKE DEFAULT'));
      await tester.pumpAndSettle();
      expect(
        repo.savedAddresses.singleWhere((a) => a.id == second.id).isDefault,
        true,
      );
      await tester.ensureVisible(find.text('EDIT').last);
      await tester.tap(find.text('EDIT').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('city')), 'Alexandria');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('save-address')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-address')));
      await tester.pumpAndSettle();
      expect(
        repo.savedAddresses.any((a) => a.data['city'] == 'Alexandria'),
        true,
      );
      await tester.ensureVisible(find.text('DELETE').first);
      await tester.tap(find.text('DELETE').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'KEEP'));
      await tester.pumpAndSettle();
      expect(repo.savedAddresses, hasLength(2));
      await tester.tap(find.text('DELETE').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'DELETE').last);
      await tester.pumpAndSettle();
      expect(repo.savedAddresses, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Address loading, error, retry and empty states', (tester) async {
    final auth = await authFixture(),
        repo = FakeCommerceRepository(),
        cart = Cart();
    addTearDown(cart.dispose);
    final pending = Completer<List<ShippingAddress>>();
    repo.onAddresses = () => pending.future;
    await tester.pumpWidget(app(const AddressBookScreen(), auth, repo, cart));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(const ApiException('Addresses unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Addresses unavailable'), findsOneWidget);
    repo.onAddresses = null;
    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No saved addresses'), findsOneWidget);
  });

  testWidgets(
    'Checkout uses default address and server prices, displays one-size image/quantity and COD only',
    (tester) async {
      final auth = await authFixture(),
          repo = FakeCommerceRepository(),
          cart = Cart();
      addTearDown(cart.dispose);
      final address = await repo.saveAddress(fields());
      // Client catalog pricing can be stale; only the quote drives checkout totals.
      final bag = products.last;
      cart.add(
        Product(
          id: bag.id,
          name: bag.name,
          image: bag.image,
          priceInCents: 1,
          category: bag.category,
          availableSizes: bag.availableSizes,
        ),
      );
      cart.add(bag);
      repo.online = true; // UI must still only offer COD.
      await tester.pumpWidget(
        app(CheckoutScreen(cart: cart), auth, repo, cart),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('selected-address')), findsOneWidget);
      expect(find.textContaining('One Size'), findsOneWidget);
      expect(find.textContaining('Unit price \$65.00'), findsOneWidget);
      expect(find.textContaining('Line total \$130.00'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('Paymob'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('place-order')));
      await tester.tap(find.byKey(const Key('place-order')));
      await tester.pumpAndSettle();
      expect(repo.submitted.single['addressId'], address.id);
      expect(repo.submitted.single['paymentMethod'], 'COD');
      expect(repo.submitted.single['expectedTotalInCents'], 13200);
      expect(repo.submitted.single['items'], [
        {'productId': bag.id, 'size': 'ONE_SIZE', 'quantity': 2},
      ]);
      expect(cart.items, isEmpty);
    },
  );

  testWidgets(
    'Unavailable variants show checkout error with retry and keep cart',
    (tester) async {
      final auth = await authFixture(),
          repo = FakeCommerceRepository(),
          cart = Cart()..add(products.last);
      addTearDown(cart.dispose);
      repo.onQuote = (_) async => throw const ApiException(
        'Variant unavailable',
        code: 'CART_UNAVAILABLE',
      );
      await tester.pumpWidget(
        app(CheckoutScreen(cart: cart), auth, repo, cart),
      );
      await tester.pumpAndSettle();
      expect(find.text('Variant unavailable'), findsOneWidget);
      expect(find.byKey(const Key('place-order')), findsNothing);
      expect(find.text('REFRESH SUMMARY'), findsOneWidget);
      expect(cart.count, 1);
      expect(repo.placements, 0);
    },
  );

  testWidgets('Empty checkout cannot place an order', (tester) async {
    final auth = await authFixture(),
        repo = FakeCommerceRepository(),
        cart = Cart();
    addTearDown(cart.dispose);
    await tester.pumpWidget(app(CheckoutScreen(cart: cart), auth, repo, cart));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your cart is empty'), findsOneWidget);
    expect(find.byKey(const Key('place-order')), findsNothing);
  });
}
