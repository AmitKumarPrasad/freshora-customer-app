import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talegaon_fresh/main.dart';

const products = [
  Product(name: 'Test Apple', unit: '1 kg', price: 50,
      icon: Icons.circle, category: 'Fruits'),
  Product(name: 'Test Milk', unit: '1 L', price: 60,
      icon: Icons.circle, category: 'Dairy'),
];

Widget catalog({List<Product> items = products, VoidCallback? retry}) =>
    MaterialApp(home: Scaffold(body: ProductsPage(
      products: items, loading: false, onRetry: retry ?? () {},
      onAdd: (_) {}, onOpenProduct: (_) {}, favorites: const {},
      onToggleFavorite: (_) {}, quantityFor: (_) => 0,
      onIncrementProduct: (_) {}, onDecrementProduct: (_) {},
    )));

void main() {
  testWidgets('clearing search preserves selected categories', (tester) async {
    await tester.pumpWidget(catalog());
    await tester.tap(find.widgetWithText(ChoiceChip, 'Fruits'));
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.text('Test Apple'), findsOneWidget);
    expect(find.text('Test Milk'), findsNothing);
    expect(find.byTooltip('Clear search'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty search recovery clears both search and categories',
      (tester) async {
    await tester.pumpWidget(catalog());
    await tester.tap(find.widgetWithText(ChoiceChip, 'Fruits'));
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    await tester.tap(find.text('Clear search and filters'));
    await tester.pump();
    expect(find.text('Test Apple'), findsOneWidget);
    expect(find.text('Test Milk'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty inventory offers retry instead of search advice',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(catalog(items: const [], retry: () => retries++));
    expect(find.text('No products available right now. Please try again.'),
        findsOneWidget);
    await tester.tap(find.text('Refresh products'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
