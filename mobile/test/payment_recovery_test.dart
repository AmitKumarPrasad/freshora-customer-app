import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talegaon_fresh/customer_api.dart';
import 'package:talegaon_fresh/main.dart';

OrderRecord pendingOrder() => OrderRecord(
  id: '42', total: 80, payment: 'UPI', address: 'Talegaon',
  createdAt: DateTime(2026, 10, 2), status: 'PAYMENT_PENDING',
);

void main() {
  testWidgets('unpaid order can retry payment setup from order details', (tester) async {
    var linkRequests = 0;
    var status = 'PAYMENT_PENDING';
    final api = HttpCustomerRepository(token: 'test', client: MockClient((request) async {
      if (request.method == 'POST') {
        expect(request.url.path, '/customers/me/orders/42/payment-link');
        linkRequests++;
        return http.Response('{"detail":"Payment provider unavailable. Retry shortly."}', 503);
      }
      return http.Response(jsonEncode({
        'order_id': 42, 'total': 80, 'payment_method': 'UPI', 'status': status,
        'address': 'Talegaon', 'created_at': '2026-10-02T00:00:00Z',
      }), 200);
    }));
    await tester.pumpWidget(MaterialApp(home: OrderDetailsPage(order: pendingOrder(), api: api)));
    final pay = find.text('Pay with UPI');
    await tester.ensureVisible(pay);
    await tester.tap(pay);
    await tester.pumpAndSettle();
    expect(linkRequests, 1);
    expect(find.text('Payment provider unavailable. Retry shortly.'), findsOneWidget);
    await tester.ensureVisible(pay);
    await tester.tap(pay);
    await tester.pumpAndSettle();
    expect(linkRequests, 2);
    // Payment is confirmed elsewhere: refresh removes the payment button.
    status = 'CONFIRMED';
    final refresh = find.text('Refresh payment status');
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(pay, findsNothing);
    expect(linkRequests, 2);
  });

  testWidgets('checkout prevents duplicate taps while order is being created', (tester) async {
    final result = Completer<OrderRecord>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: CheckoutPage(
      total: 80,
      addresses: [CustomerAddress(label: 'Home', fullAddress: 'Main Road', city: 'Talegaon', pincode: '410507')],
      onContinueShopping: () {},
      onOrderPlaced: (_, __, ___, ____) { calls++; return result.future; },
    )));
    final place = find.widgetWithText(FilledButton, 'Place Order');
    await tester.ensureVisible(place);
    await tester.tap(place);
    await tester.pump();
    final busy = find.widgetWithText(FilledButton, 'Placing order…');
    expect(tester.widget<FilledButton>(busy).onPressed, isNull);
    expect(calls, 1);
    result.complete(pendingOrder());
    await tester.pumpAndSettle();
    expect(find.text('Order Created — Payment Pending'), findsOneWidget);
  });

  testWidgets('rapid duplicate checkout callback submits only once', (tester) async {
    final result = Completer<OrderRecord>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: CheckoutPage(
      total: 80,
      addresses: [CustomerAddress(label: 'Home', fullAddress: 'Main Road', city: 'Talegaon', pincode: '410507')],
      onContinueShopping: () {},
      onOrderPlaced: (_, __, ___, ____) {
        calls++;
        return result.future;
      },
    )));
    final place = find.widgetWithText(FilledButton, 'Place Order');
    await tester.ensureVisible(place);
    final callback = tester.widget<FilledButton>(place).onPressed!;

    // Simulate two events before Flutter rebuilds the disabled button.
    callback();
    callback();
    await tester.pump();

    expect(calls, 1);
    expect(find.text('Placing order…'), findsOneWidget);

    result.complete(pendingOrder());
    await tester.pumpAndSettle();
    expect(find.text('Order Created — Payment Pending'), findsOneWidget);
  });

}
