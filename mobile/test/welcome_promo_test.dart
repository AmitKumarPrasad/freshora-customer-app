import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talegaon_fresh/customer_api.dart';
import 'package:talegaon_fresh/main.dart';

Widget cart(double price, {HttpCustomerRepository? api}) => MaterialApp(
  home: Scaffold(body: CartPage(
    cart: [CartItem(Product(name: 'Test basket', unit: '1 pack',
      price: price, icon: Icons.circle), 1)],
    onIncrement: (_) {}, onDecrement: (_) {}, onRemove: (_) {},
    addresses: const [], onContinueShopping: () {},
    onOrderPlaced: (_, __, ___, ____) async => OrderRecord(
      id: '1', total: price, payment: 'COD', address: 'Talegaon',
      createdAt: DateTime(2026)),
    api: api,
  )),
);

Future<void> applyWelcome(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'welcome50');
  await tester.pump();
  final apply = find.text('Apply');
  await tester.ensureVisible(apply);
  await tester.tap(apply);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty cart shows Start shopping without errors', (tester) async {
    var continued = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CartPage(
      cart: const [], onIncrement: (_) {}, onDecrement: (_) {}, onRemove: (_) {},
      addresses: const [], onContinueShopping: () => continued = true,
      onOrderPlaced: (_, __, ___, ____) async => OrderRecord(id: '1', total: 0, payment: 'COD', address: 'Talegaon', createdAt: DateTime(2026)),
    ))));
    await tester.tap(find.text('Start shopping'));
    expect(continued, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SHOP200 applies at 200 and shows remaining subtotal below it', (tester) async {
    await tester.pumpWidget(shop200Cart(200));
    await tester.enterText(find.byType(TextField), 'SHOP200');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Discount (SHOP200)'), findsOneWidget);
    expect(find.text('₹180'), findsOneWidget);
    await tester.pumpWidget(shop200Cart(199));
    await tester.enterText(find.byType(TextField), 'SHOP200');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Add ₹1 more to use this code'), findsOneWidget);
  });

  testWidgets('local welcome promo requires product subtotal 500', (tester) async {
    await tester.pumpWidget(cart(499));
    await applyWelcome(tester);
    expect(find.text('Add ₹1 more to use this code'), findsOneWidget);
    expect(find.text('Discount (WELCOME50)'), findsNothing);
  });

  testWidgets('local welcome promo cannot assume first-order eligibility',
      (tester) async {
    await tester.pumpWidget(cart(500));
    await applyWelcome(tester);
    expect(find.text('Sign in to verify first-order eligibility for this code.'),
      findsOneWidget);
    expect(find.text('Discount (WELCOME50)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('welcome promo displays server eligibility rejection',
      (tester) async {
    final api = HttpCustomerRepository(token: 'test', baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/customers/me/promos/validate');
        expect(jsonDecode(request.body)['promo_code'], 'WELCOME50');
        return http.Response(jsonEncode({
          'detail': 'WELCOME50 is only valid on your first order.',
        }), 400);
      }));
    await tester.pumpWidget(cart(500, api: api));
    await applyWelcome(tester);
    expect(find.text('WELCOME50 is only valid on your first order.'), findsOneWidget);
    expect(find.text('Discount (WELCOME50)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('welcome promo uses authoritative 50 discount at 500',
      (tester) async {
    final api = HttpCustomerRepository(token: 'test', baseUrl: 'https://example.test',
      client: MockClient((request) async => http.Response(jsonEncode({
        'promo_code': 'WELCOME50', 'subtotal': 500, 'delivery_fee': 0,
        'discount_amount': 50, 'total': 450,
      }), 200)));
    await tester.pumpWidget(cart(499, api: api));
    await applyWelcome(tester);
    expect(find.text('Discount (WELCOME50)'), findsOneWidget);
    expect(find.text('₹450'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}


Widget shop200Cart(double price) => MaterialApp(
  home: Scaffold(body: CartPage(
    cart: [CartItem(Product(name: 'Test basket', unit: '1 pack', price: price, icon: Icons.circle), 1)],
    onIncrement: (_) {}, onDecrement: (_) {}, onRemove: (_) {},
    addresses: const [], onContinueShopping: () {},
    onOrderPlaced: (_, __, ___, ____) async => OrderRecord(
      id: '1', total: price, payment: 'COD', address: 'Talegaon', createdAt: DateTime(2026)),
  )),
);
