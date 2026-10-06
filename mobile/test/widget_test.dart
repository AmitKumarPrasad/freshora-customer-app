import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talegaon_fresh/main.dart';
import 'package:talegaon_fresh/landing_page.dart';
import 'package:talegaon_fresh/product_api.dart';

class FakeProductRepository implements ProductRepository {
  @override
  Future<List<ApiProduct>> fetchProducts() async => const [
        ApiProduct(
            id: 1,
            name: 'Tomato',
            unit: '1 kg',
            price: 30,
            inStock: true,
            category: 'Vegetables'),
        ApiProduct(
            id: 2,
            name: 'Potato',
            unit: '1 kg',
            price: 25,
            inStock: true,
            category: 'Vegetables'),
      ];
}

class ExpandedProductRepository implements ProductRepository {
  @override
  Future<List<ApiProduct>> fetchProducts() async => const [
        ApiProduct(
            id: 1,
            name: 'Tomato',
            unit: '1 kg',
            price: 30,
            inStock: true,
            category: 'Vegetables'),
        ApiProduct(
            id: 21,
            name: 'Amul Taaza Milk',
            unit: '1 L',
            price: 59,
            inStock: true,
            category: 'Dairy'),
        ApiProduct(
            id: 26,
            name: "Lay's Cream & Onion Chips",
            unit: '58 g',
            price: 20,
            inStock: true,
            category: 'Snacks'),
        ApiProduct(
            id: 31,
            name: 'Aashirvaad Whole Wheat Atta',
            unit: '5 kg',
            price: 264,
            inStock: true,
            category: 'Grocery'),
      ];
}

void main() {
  testWidgets('market welcome fits a phone and opens account creation',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      home: TalegaonLandingPage(
        onCreateAccount: () => opened = true,
        onSignIn: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Explore the market'));
    expect(opened, isTrue);
  });

  testWidgets('FRESHORA starts with customer authentication', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TalegaonFreshApp());
    await tester.pump(const Duration(milliseconds: 1700));
    expect(find.text('FRESHORA'), findsWidgets);
    final landingSignIn = find.widgetWithText(OutlinedButton, 'Sign in');
    expect(landingSignIn, findsOneWidget);
    await tester.ensureVisible(landingSignIn);
    await tester.pumpAndSettle();
    await tester.tap(landingSignIn);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back. Sign in securely.'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, '9876543210');
    await tester.enterText(find.byType(TextField).last, '123456');
    final signInButton = find.widgetWithText(FilledButton, 'Sign in');
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    await tester.pumpAndSettle();
    expect(find.text('FRESHORA'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);

    // AppShell asks for location permission on first launch. Dismiss it so the
    // modal does not block the navigation tap below in the widget test.
    final notNowLocation = find.text('Not now');
    if (notNowLocation.evaluate().isNotEmpty) {
      await tester.tap(notNowLocation);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
  });

  testWidgets('customer can manage saved addresses', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          repository: FakeProductRepository(),
          session: const CustomerSession(
            phone: '9876543210',
            name: 'Talegaon Customer',
            token: 'test-token',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final myAddresses = find.text('Delivery Address');
    await tester.ensureVisible(myAddresses);
    await tester.pumpAndSettle();
    await tester.tap(myAddresses);
    await tester.pumpAndSettle();

    expect(find.text('No saved addresses yet.'), findsOneWidget);
    expect(find.text('Add Address'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.data?.contains('Talegaon Dabhade') == true,
      ),
      findsNothing,
    );

    await tester.tap(find.text('Add Address'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Work');
    await tester.enterText(fields.at(1), 'Office Road');
    await tester.enterText(fields.at(2), 'Talegaon');
    await tester.enterText(fields.at(3), '410507');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);
    expect(find.textContaining('Office Road'), findsOneWidget);
  });

  testWidgets('FRESHORA loads products from repository', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          repository: FakeProductRepository(),
          session: const CustomerSession(
            phone: '9876543210',
            name: 'Talegaon Customer',
            token: 'test-token',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('FRESHORA'), findsOneWidget);
    expect(find.text("Today's Products"), findsOneWidget);
    expect(find.text('Tomato'), findsWidgets);
    expect(find.text('₹30'), findsWidgets);
    expect(find.text('1 kg'), findsWidgets);
  });

  testWidgets('Home search filters products and opens notifications',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          repository: FakeProductRepository(),
          session: const CustomerSession(
            phone: '9876543210',
            name: 'Talegaon Customer',
            token: 'test-token',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'tomato');
    await tester.pump();
    expect(find.text('Tomato'), findsWidgets);
    expect(find.text('Potato'), findsNothing);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('product catalog filters expanded backend categories',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          repository: ExpandedProductRepository(),
          session: const CustomerSession(
            phone: '9876543210',
            name: 'Talegaon Customer',
            token: 'test-token',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    final dairyFilter = find.widgetWithText(ChoiceChip, 'Dairy');
    expect(dairyFilter, findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Snacks'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Grocery'), findsOneWidget);

    await tester.tap(dairyFilter);
    await tester.pumpAndSettle();

    expect(find.text('Amul Taaza Milk'), findsOneWidget);
    expect(find.text('Tomato'), findsNothing);
    expect(find.text("Lay's Cream & Onion Chips"), findsNothing);
  });

  testWidgets('customer cart persists across app sessions', (tester) async {
    SharedPreferences.setMockInitialValues({});

    Widget buildShell() => MaterialApp(
          home: AppShell(
            repository: FakeProductRepository(),
            session: const CustomerSession(
              phone: '9876543210',
              name: 'Talegaon Customer',
              token: 'test-token',
            ),
          ),
        );

    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    final addButton = find.byTooltip('Add to cart').first;
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Tomato'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();

    expect(find.text('Tomato'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
