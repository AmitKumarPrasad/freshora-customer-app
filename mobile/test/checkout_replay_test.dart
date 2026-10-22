import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talegaon_fresh/customer_api.dart';
import 'package:talegaon_fresh/main.dart';

void main() {
  test('failed checkout reuses its key and successful checkout clears it', () async {
    final keys = <String>[];
    final api = HttpCustomerRepository(token: 'test', baseUrl: 'https://example.test',
      client: MockClient((request) async {
        keys.add(jsonDecode(request.body)['idempotency_key'] as String);
        if (keys.length == 1) return http.Response('{"detail":"Temporary failure"}', 503);
        return http.Response('{"order_id":1,"total":120,"payment_method":"COD","address":"Talegaon","status":"CONFIRMED"}', 200);
      }));
    final cart = [CartItem(Product(name: 'Apple', unit: 'kg', price: 100, icon: Icons.circle), 1)];
    const address = CustomerAddress(id: 1, label: 'Home', fullAddress: 'Street', city: 'Talegaon', pincode: '410507');
    await expectLater(api.createOrder(cart, address, 'COD'), throwsA(isA<CustomerApiException>()));
    await api.createOrder(cart, address, 'COD');
    await api.createOrder(cart, address, 'COD');
    expect(keys[0], keys[1]);
    expect(keys[1], isNot(keys[2]));
  });
}


  test('retry after repository restart reuses pending checkout key', () async {
    SharedPreferences.setMockInitialValues({});
    final keys = <String>[];
    final cart = [
      CartItem(
        Product(name: 'Apple', unit: 'kg', price: 100, icon: Icons.circle),
        1,
      ),
    ];
    const address = CustomerAddress(
      id: 1,
      label: 'Home',
      fullAddress: 'Street',
      city: 'Talegaon',
      pincode: '410507',
    );

    final firstAttempt = HttpCustomerRepository(
      token: 'test',
      checkoutScope: '9000000001',
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        keys.add(jsonDecode(request.body)['idempotency_key'] as String);
        // Simulate a lost/uncertain response after the server might have committed.
        return http.Response('{"detail":"Connection interrupted"}', 503);
      }),
    );
    await expectLater(
      firstAttempt.createOrder(cart, address, 'COD'),
      throwsA(isA<CustomerApiException>()),
    );

    final retry = HttpCustomerRepository(
      token: 'test',
      checkoutScope: '9000000001',
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        keys.add(jsonDecode(request.body)['idempotency_key'] as String);
        return http.Response(
          '{"order_id":1,"total":120,"payment_method":"COD","address":"Talegaon","status":"CONFIRMED"}',
          200,
        );
      }),
    );
    await retry.createOrder(cart, address, 'COD');
    expect(keys[0], keys[1]);

    final laterOrder = HttpCustomerRepository(
      token: 'test',
      checkoutScope: '9000000001',
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        keys.add(jsonDecode(request.body)['idempotency_key'] as String);
        return http.Response(
          '{"order_id":2,"total":120,"payment_method":"COD","address":"Talegaon","status":"CONFIRMED"}',
          200,
        );
      }),
    );
    await laterOrder.createOrder(cart, address, 'COD');
    expect(keys[2], isNot(keys[1]));
  });
