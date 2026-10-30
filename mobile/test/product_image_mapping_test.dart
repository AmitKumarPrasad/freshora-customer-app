import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talegaon_fresh/main.dart';

void main() {
  testWidgets('produce names use the matching bundled image', (tester) async {
    for (final entry in {
      'Carrot': 'assets/images/products/green_chilies.png',
      'Ladyfinger': 'assets/images/products/carrots.png',
      'Green Chilli': 'assets/images/products/green_chilies_2.png',
      'Ginger': 'assets/images/products/garlic.png',
    }.entries) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProductImage(
            product: Product(
              name: entry.key,
              unit: '500 g',
              price: 50,
              icon: Icons.shopping_basket,
            ),
          ),
        ),
      ));
      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image;
      expect(provider, isA<ResizeImage>());
      expect((provider as ResizeImage).imageProvider, isA<AssetImage>());
      expect((provider.imageProvider as AssetImage).assetName, entry.value);
    }
  });

  testWidgets('packaged onion product does not use a vegetable asset',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ProductImage(
          product: Product(
            name: "Lay's Cream & Onion Chips",
            unit: '1 pack',
            price: 20,
            icon: Icons.shopping_basket,
          ),
        ),
      ),
    ));
    expect(find.byType(Image), findsNothing);
  });
}
