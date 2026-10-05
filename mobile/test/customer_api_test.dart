import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:talegaon_fresh/customer_api.dart';
import 'package:talegaon_fresh/main.dart';

void main() {
  test('cart writes finish in order before checkout clears the cart', () async {
    final firstWrite = Completer<void>();
    final firstStarted = Completer<void>();
    final requests = <String>[];
    final quantities = <int>[];
    var savedQuantity = 0;
    final repository = HttpCustomerRepository(
      token: 'jwt-token',
      client: MockClient((request) async {
        requests.add(request.method);
        if (request.method == 'DELETE') {
          savedQuantity = 0;
        } else {
          final items = (jsonDecode(request.body) as Map)['items'] as List;
          if (!firstStarted.isCompleted) {
            firstStarted.complete();
            await firstWrite.future;
          }
          savedQuantity = (items.single as Map)['quantity'] as int;
          quantities.add(savedQuantity);
        }
        return http.Response('{}', 200);
      }),
      baseUrl: 'https://example.test',
    );
    const product = Product(
      name: 'Tomato', unit: 'kg', price: 40, icon: Icons.local_grocery_store,
    );
    final cart = [CartItem(product, 1)];
    final first = repository.replaceCart(cart);
    await firstStarted.future;
    cart.single.quantity = 2;
    final second = repository.replaceCart(cart);
    cart.single.quantity = 3;
    final clear = repository.clearCart();
    await Future<void>.delayed(Duration.zero);
    final requestsWhilePending = List<String>.from(requests);
    firstWrite.complete();
    await Future.wait([first, second, clear]);

    expect(requestsWhilePending, ['PUT']);
    expect(requests, ['PUT', 'PUT', 'DELETE']);
    expect(quantities, [1, 2]);
    expect(savedQuantity, 0);
  });

  test('a failed cart write does not prevent the next write', () async {
    var calls = 0;
    final repository = HttpCustomerRepository(
      token: 'jwt-token',
      client: MockClient((_) async => ++calls == 1
          ? http.Response('{"detail":"Try again"}', 503)
          : http.Response('{}', 200)),
      baseUrl: 'https://example.test',
    );
    await expectLater(repository.replaceCart([]),
        throwsA(isA<CustomerApiException>()));
    await repository.clearCart();
    expect(calls, 2);
  });

  const address = CustomerAddress(
    id: 42,
    label: 'Home',
    fullAddress: 'Main Road',
    city: 'Talegaon',
    pincode: '410507',
    landmark: 'Near Station',
    isDefault: true,
  );

  test('customer API updateAddress preserves server id and default flag', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.toString(), 'https://example.test/customers/me/addresses/42');
      expect(request.headers['authorization'], 'Bearer jwt-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['label'], 'Home');
      expect(body['address'], 'Main Road, Near Station');
      expect(body['city'], 'Talegaon');
      expect(body['pincode'], '410507');
      expect(body['is_default'], true);
      return http.Response(
        jsonEncode({'address': {
          'id': 42, 'label': 'Home', 'address': 'Main Road, Near Station',
          'city': 'Talegaon', 'pincode': '410507', 'is_default': true,
        }}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final repository = HttpCustomerRepository(
      token: 'jwt-token', client: client, baseUrl: 'https://example.test',
    );
    final saved = await repository.updateAddress(address);
    expect(saved.id, 42);
    expect(saved.isDefault, true);
    expect(saved.fullAddress, 'Main Road, Near Station');
  });

  test('customer API updateAddress rejects an address without server id', () async {
    final repository = HttpCustomerRepository(
      token: 'jwt-token',
      client: MockClient((_) async => http.Response('{}', 200)),
      baseUrl: 'https://example.test',
    );
    const withoutId = CustomerAddress(
      label: 'Home', fullAddress: 'Main Road', city: 'Talegaon', pincode: '410507',
    );
    expect(
      () => repository.updateAddress(withoutId),
      throwsA(isA<CustomerApiException>().having(
        (e) => e.message, 'message', 'Address ID is required.',
      )),
    );
  });

  test('customer API maps cart rows to products and quantities', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'https://example.test/customers/me/cart');
      return http.Response(
        jsonEncode({'items': [
          {'name': 'Tomato', 'unit': 'kg', 'price': 40, 'quantity': 3},
        ]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final repository = HttpCustomerRepository(
      token: 'jwt-token', client: client, baseUrl: 'https://example.test',
    );
    const product = Product(
      name: 'Tomato', unit: 'kg', price: 40, icon: Icons.local_grocery_store,
    );
    final cart = await repository.getCart([product]);
    expect(cart, hasLength(1));
    expect(cart.single.product.name, 'Tomato');
    expect(cart.single.quantity, 3);
  });


  test('order persistence preserves payment status and payment link', () {
    final original = OrderRecord(
      id: '1001',
      total: 120,
      payment: 'UPI',
      address: 'Main Road, Talegaon, 410507',
      createdAt: DateTime.parse('2026-09-29T10:00:00Z'),
      status: 'PAYMENT_PENDING',
      paymentLinkUrl: 'https://rzp.io/i/test-link',
      items: const [
        OrderLine(name: 'Tomato', unit: 'kg', price: 40, quantity: 3),
      ],
    );

    final restored = OrderRecord.fromJson(jsonDecode(jsonEncode(original.toJson())));
    expect(restored, isNotNull);
    expect(restored!.status, 'PAYMENT_PENDING');
    expect(restored.paymentLinkUrl, 'https://rzp.io/i/test-link');
    expect(restored.items.single.name, 'Tomato');
  });

  test('customer API sends authenticated order creation payload', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://example.test/customers/me/orders');
      expect(request.headers['authorization'], 'Bearer jwt-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['address_id'], 42);
      expect(body['payment_method'], 'COD');
      expect(body['items'], hasLength(1));
      return http.Response(
        jsonEncode({
          'order_id': 1001, 'total': 120,
          'address': 'Main Road, Talegaon, 410507',
          'payment_method': 'COD', 'status': 'CONFIRMED',
          'items': [
            {'name': 'Tomato', 'unit': 'kg', 'unit_price': 40, 'quantity': 3},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final repository = HttpCustomerRepository(
      token: 'jwt-token', client: client, baseUrl: 'https://example.test',
    );
    const product = Product(
      name: 'Tomato', unit: 'kg', price: 40, icon: Icons.local_grocery_store,
    );
    final order = await repository.createOrder(
      [CartItem(product, 3)], address, 'COD',
    );
    expect(order.id, '1001');
    expect(order.status, 'CONFIRMED');
    expect(order.total, 120);
  });
}
