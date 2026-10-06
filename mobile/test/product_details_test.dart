import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talegaon_fresh/main.dart';

void main() {
  const product = Product(
    name: 'Tomato',
    unit: '1 kg',
    price: 30,
    icon: Icons.circle,
    mrp: 40,
  );

  testWidgets('quantity changes amount and saves the selected count once',
      (tester) async {
    var savedQuantity = 0;
    var saveCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailsPage(
          product: product,
          onSetQuantity: (_, quantity) {
            savedQuantity = quantity;
            saveCalls++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('₹30'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pump();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('₹60'), findsOneWidget);
    expect(find.text('Add To Basket • ₹60'), findsOneWidget);

    await tester.tap(find.text('Add To Basket • ₹60'));
    await tester.pump();
    expect(savedQuantity, 2);
    expect(saveCalls, 1);
  });

  testWidgets('editing a selected product starts from its cart quantity',
      (tester) async {
    var savedQuantity = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailsPage(
          product: product,
          initialQuantity: 2,
          onSetQuantity: (_, quantity) => savedQuantity = quantity,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('₹60'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    expect(find.text('₹90'), findsOneWidget);

    await tester.tap(find.text('Update Basket • ₹90'));
    await tester.pump();
    expect(savedQuantity, 3);
  });
}
