import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:moda_shop/data/products.dart';
import 'package:moda_shop/models/cart.dart';
import 'package:moda_shop/models/product.dart';
import 'package:moda_shop/services/local_store.dart';
import 'package:moda_shop/services/products_api.dart';
import 'support/fake_product_repository.dart';

class MemoryLocalStore implements LocalStore {
  String? value;
  bool failRead = false, failWrite = false, writeThenFail = false;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('Read failed');
    return value;
  }

  @override
  Future<void> write(String next) async {
    if (failWrite) throw StateError('Write failed');
    value = next;
    if (writeThenFail) throw StateError('Acknowledgement lost');
  }
}

Map<String, dynamic> pendingBody() => {
  'clientRequestId': '37a06452-2265-47e8-8349-9716b68093d6',
  'addressId': '27a06452-2265-47e8-8349-9716b68093d6',
  'paymentMethod': 'COD',
  'expectedTotalInCents': 6700,
  'items': [
    {'productId': products.last.id, 'size': 'ONE_SIZE', 'quantity': 1},
  ],
};

void main() {
  test(
    'Cart persists identifiers only and restores current product prices and quantities',
    () async {
      final store = MemoryLocalStore(), repository = FakeProductRepository();
      final cart = Cart(store: store);
      addTearDown(cart.dispose);
      await cart.restore(repository);
      cart.add(products.last);
      cart.add(products.last);
      await cart.flush();
      expect(store.value, isNot(contains('priceInCents')));
      expect(store.value, isNot(contains('Shoulder Bag')));
      final restored = Cart(store: store);
      addTearDown(restored.dispose);
      repository.onDetail = (_) async => Product(
        id: products.last.id,
        name: products.last.name,
        image: products.last.image,
        priceInCents: 7000,
        category: ProductCategory.accessories,
        availableSizes: const ['ONE_SIZE'],
      );
      await restored.restore(repository);
      expect(restored.count, 2);
      expect(restored.total, 14000);
      expect(restored.items.single.size, 'ONE_SIZE');
      restored.setQuantity(restored.items.single, 3);
      await restored.flush();
      expect((jsonDecode(store.value!)['items'] as List).single['quantity'], 3);
      restored.remove(restored.items.single);
      await restored.flush();
      expect(jsonDecode(store.value!)['items'], isEmpty);
    },
  );

  test(
    'Removed products and unavailable variants are dropped with a visible notice',
    () async {
      final store = MemoryLocalStore(), repository = FakeProductRepository();
      final cart = Cart(store: store);
      addTearDown(cart.dispose);
      await cart.restore(repository);
      cart.add(products.first, 'M');
      cart.add(products.last);
      await cart.flush();
      repository.onDetail = (id) async {
        if (id == products.last.id) {
          throw const ApiException('Removed', statusCode: 404);
        }
        return Product(
          id: products.first.id,
          name: products.first.name,
          image: products.first.image,
          priceInCents: 3500,
          category: ProductCategory.clothing,
          availableSizes: const ['L'],
        );
      };
      final restored = Cart(store: store);
      addTearDown(restored.dispose);
      await restored.restore(repository);
      expect(restored.items, isEmpty);
      expect(restored.notice, contains('2 unavailable'));
      expect(restored.restoreError, isNull);
    },
  );

  test(
    'Transient backend failures and corrupt storage preserve the saved data for retry',
    () async {
      final store = MemoryLocalStore(), repository = FakeProductRepository();
      final cart = Cart(store: store);
      addTearDown(cart.dispose);
      await cart.restore(repository);
      cart.add(products.last);
      await cart.flush();
      final before = store.value;
      repository.onDetail = (_) async => throw const ApiException('Offline');
      final restored = Cart(store: store);
      addTearDown(restored.dispose);
      await restored.restore(repository);
      expect(restored.ready, false);
      expect(store.value, before);
      expect(() => restored.add(products.last), throwsStateError);
      repository.onDetail = null;
      await restored.retryRestore();
      expect(restored.count, 1);
      expect(restored.ready, true);
      await restored.flush();
      store.value = '{corrupt';
      await restored.restore(repository);
      expect(restored.restoreError, isNotNull);
      expect(store.value, '{corrupt');
    },
  );

  test(
    'Pending requests survive restart, remain account scoped, and settle once',
    () async {
      final store = MemoryLocalStore(), repository = FakeProductRepository();
      final cart = Cart(store: store);
      addTearDown(cart.dispose);
      await cart.restore(repository);
      cart.add(products.last);
      cart.add(products.last);
      final body = pendingBody();
      await cart.prepareCheckout('alice', body);
      body['expectedTotalInCents'] = 1;
      expect(cart.pendingCheckout('alice')!['expectedTotalInCents'], 6700);
      expect(cart.pendingCheckout('bob'), isNull);
      final restored = Cart(store: store);
      addTearDown(restored.dispose);
      await restored.restore(repository);
      expect(
        restored.pendingCheckout('alice')!['clientRequestId'],
        pendingBody()['clientRequestId'],
      );
      await restored.completeCheckout(
        'alice',
        'order-one',
        (pendingBody()['items'] as List).cast<Map<String, dynamic>>(),
      );
      expect(restored.count, 1);
      final restarted = Cart(store: store);
      addTearDown(restarted.dispose);
      await restarted.restore(repository);
      expect(restarted.pendingCheckout('alice'), isNull);
      await restarted.completeCheckout(
        'alice',
        'order-one',
        (pendingBody()['items'] as List).cast<Map<String, dynamic>>(),
      );
      expect(restarted.count, 1);
    },
  );

  for (final writeThrough in [false, true]) {
    test(
      'Settlement recovers exactly once when storage acknowledgement fails (write-through=$writeThrough)',
      () async {
        final store = MemoryLocalStore(), repository = FakeProductRepository();
        final cart = Cart(store: store);
        addTearDown(cart.dispose);
        await cart.restore(repository);
        cart.add(products.last);
        cart.add(products.last);
        await cart.prepareCheckout('alice', pendingBody());
        store.failWrite = !writeThrough;
        store.writeThenFail = writeThrough;
        await expectLater(
          cart.completeCheckout(
            'alice',
            'order-one',
            (pendingBody()['items'] as List).cast<Map<String, dynamic>>(),
          ),
          throwsStateError,
        );
        store.failWrite = false;
        store.writeThenFail = false;
        final restarted = Cart(store: store);
        addTearDown(restarted.dispose);
        await restarted.restore(repository);
        await restarted.completeCheckout(
          'alice',
          'order-one',
          (pendingBody()['items'] as List).cast<Map<String, dynamic>>(),
        );
        expect(restarted.count, 1);
      },
    );
  }

  test(
    'Checkout preparation fails closed when secure storage cannot save',
    () async {
      final store = MemoryLocalStore(), repository = FakeProductRepository();
      final persisted = Cart(store: store);
      addTearDown(persisted.dispose);
      await persisted.restore(repository);
      store.failWrite = true;
      await expectLater(
        persisted.prepareCheckout('alice', pendingBody()),
        throwsStateError,
      );
      expect(persisted.pendingCheckout('alice'), isNotNull);
      store.failWrite = false;
      final retry = await persisted.prepareCheckout('alice', {
        ...pendingBody(),
        'clientRequestId': 'different',
      });
      expect(retry['clientRequestId'], pendingBody()['clientRequestId']);
    },
  );
  test(
    'Reviewing updated checkout retains the original key and account ownership',
    () async {
      final cart = Cart();
      addTearDown(cart.dispose);
      await cart.prepareCheckout('alice', pendingBody());
      final revised = await cart.prepareCheckout('alice', {
        ...pendingBody(),
        'clientRequestId': 'new-key',
        'expectedTotalInCents': 7000,
      }, revise: true);
      expect(revised['clientRequestId'], pendingBody()['clientRequestId']);
      expect(revised['expectedTotalInCents'], 7000);
      expect(cart.pendingCheckout('bob'), isNull);
      await expectLater(
        cart.completeCheckout('bob', 'unknown-order', []),
        throwsStateError,
      );
    },
  );
}
