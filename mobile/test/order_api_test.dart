import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talegaon_fresh/main.dart';
import 'package:talegaon_fresh/order_api.dart';

void main() {
  const address = CustomerAddress(
    label: 'Home',
    fullAddress: 'Talegaon Dabhade',
    city: 'Pune',
    pincode: '410507',
  );
  const line = OrderLine(
    name: 'Tomato',
    unit: 'kg',
    price: 40,
    quantity: 2,
  );

  test('order API creates order with bearer token', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://example.test/customers/me/orders');
      expect(request.headers['authorization'], 'Bearer jwt-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['total'], 80);
      expect((body['items'] as List).single['name'], 'Tomato');
      return http.Response(jsonEncode({
        'order': {
          'id': 'TF1001',
          'total': 80,
          'payment': 'COD',
          'address': address.displayAddress,
          'createdAt': '2026-09-29T10:00:00Z',
          'items': [line.toJson()],
        },
      }), 201);
    });

    final repo = HttpOrderRepository(
      client: client,
      baseUrl: 'https://example.test',
      token: 'jwt-token',
    );
    final result = await repo.createOrder(
      const CreateOrderRequest(
        items: [line],
        total: 80,
        payment: 'COD',
        address: address,
      ),
    );

    expect(result.id, 'TF1001');
    expect(result.items.single.quantity, 2);
  });

  test('order API fetches customer orders', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.headers['authorization'], 'Bearer jwt-token');
      return http.Response(jsonEncode({
        'orders': [{
          'id': 'TF1002',
          'total': 40,
          'payment': 'UPI',
          'address': address.displayAddress,
          'createdAt': '2026-09-29T11:00:00Z',
          'items': [line.toJson()],
        }],
      }), 200);
    });

    final repo = HttpOrderRepository(
      client: client,
      baseUrl: 'https://example.test',
      token: 'jwt-token',
    );
    final result = await repo.fetchOrders();

    expect(result.single.id, 'TF1002');
    expect(result.single.payment, 'UPI');
  });

  test('order API maps unauthorized response', () async {
    final client = MockClient((request) async => http.Response('', 401));
    final repo = HttpOrderRepository(
      client: client,
      baseUrl: 'https://example.test',
      token: 'expired',
    );

    expect(repo.fetchOrders, throwsA(isA<OrderApiException>()));
  });

  test('checkout reports the backend stock rejection', () async {
    final repo = HttpOrderRepository(
      client: MockClient((_) async => http.Response(
        jsonEncode({'detail': 'Insufficient stock: Tomato'}), 409,
      )),
      baseUrl: 'https://example.test',
    );

    await expectLater(
      repo.createOrder(const CreateOrderRequest(
        items: [line], total: 80, payment: 'COD', address: address,
      )),
      throwsA(isA<OrderApiException>().having(
        (error) => error.message, 'message', 'Insufficient stock: Tomato',
      )),
    );
  });
}
