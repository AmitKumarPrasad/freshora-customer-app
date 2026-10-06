import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talegaon_fresh/main.dart';

void main() {
  testWidgets('narrow product card keeps quantity buttons usable and total updated',
      (tester) async {
    const product = Product(
      name: 'Tomato',
      unit: '1 kg',
      price: 30,
      icon: Icons.local_grocery_store,
    );
    var quantity = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 134,
            height: 225,
            child: StatefulBuilder(builder: (context, setState) {
              return ProductCard(
                product: product,
                quantity: quantity,
                isFavorite: false,
                onOpen: (_) {},
                onToggleFavorite: (_) {},
                onAdd: (_) => setState(() => quantity++),
                onIncrement: () => setState(() => quantity++),
                onDecrement: () => setState(() => quantity--),
              );
            }),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Add to cart'));
    await tester.pump();
    expect(find.text('₹30'), findsOneWidget);
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(find.text('₹60'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
