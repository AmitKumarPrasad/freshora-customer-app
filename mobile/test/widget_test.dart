import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talegaon_fresh/customer_api.dart';
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
    expect(find.textContaining('1 kg'), findsWidgets);
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
    final snacks = find.widgetWithText(ChoiceChip, 'Snacks');
    await tester.ensureVisible(snacks);
    await tester.tap(snacks);
    await tester.pumpAndSettle();
    expect(find.text('Amul Taaza Milk'), findsOneWidget);
    expect(find.text("Lay's Cream & Onion Chips"), findsOneWidget);
    await tester.ensureVisible(dairyFilter);
    await tester.tap(dairyFilter);
    await tester.pumpAndSettle();
    expect(find.text('Amul Taaza Milk'), findsNothing);
    await tester.ensureVisible(snacks);
    await tester.tap(snacks);
    await tester.pumpAndSettle();
    expect(find.text('Tomato'), findsWidgets);
    expect(find.text('Amul Taaza Milk'), findsOneWidget);
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
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Tomato'), findsOneWidget);
    expect(find.descendant(of: find.byType(CartPage), matching: find.text('1')), findsOneWidget);

    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();

    expect(find.text('Tomato'), findsOneWidget);
    expect(find.descendant(of: find.byType(CartPage), matching: find.text('1')), findsOneWidget);
  });

  testWidgets('My Details shows customer information, not photo options',
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
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    final details = find.text('My Details');
    await tester.ensureVisible(details);
    await tester.pumpAndSettle();
    await tester.tap(details);
    await tester.pumpAndSettle();

    expect(find.text('My Details'), findsOneWidget);
    expect(find.text('Talegaon Customer'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsNothing);
  });

  testWidgets('online cart validates promo and shows authoritative totals',
      (tester) async {
    final product = Product(
      name: 'Tomato',
      unit: '1 kg',
      price: 100,
      icon: Icons.circle,
    );
    final api = HttpCustomerRepository(
      token: 'test-token',
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/customers/me/promos/validate');
        expect(jsonDecode(request.body)['promo_code'], 'FRESH10');
        return http.Response(jsonEncode({
          'promo_code': 'FRESH10',
          'subtotal': 100,
          'delivery_fee': 20,
          'discount_amount': 10,
          'total': 110,
        }), 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CartPage(
            cart: [CartItem(product, 1)],
            onIncrement: (_) {},
            onDecrement: (_) {},
            onRemove: (_) {},
            addresses: const [],
            onOrderPlaced: (_, __, ___, ____) async => OrderRecord(
              id: '1',
              total: 100,
              payment: 'COD',
              address: 'Talegaon',
              createdAt: DateTime(2026),
            ),
            onContinueShopping: () {},
            api: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'FRESH10');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Discount (FRESH10)'), findsOneWidget);
    expect(find.text('₹110'), findsOneWidget);
    final remove = find.text('Remove promo code');
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('Discount (FRESH10)'), findsNothing);
    expect(find.text('₹120'), findsOneWidget);
    expect(find.textContaining('Add ₹99 for free delivery'), findsOneWidget);
  });
  testWidgets('registration requires matching PIN and accepts valid account', (tester) async {
    CustomerSession? session;
    await tester.pumpWidget(MaterialApp(home: LoginPage(
      initialRegisterMode: true,
      onAuthenticated: (value) => session = value,
    )));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Amit Prasad');
    await tester.enterText(fields.at(1), '9876543210');
    await tester.enterText(fields.at(2), '123456');
    await tester.enterText(fields.at(3), '654321');
    final submit = find.widgetWithText(FilledButton, 'Create secure account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(session, isNull);
    expect(find.textContaining('PINs do not match'), findsOneWidget);
    await tester.enterText(fields.at(3), '123456');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(session?.phone, '9876543210');
  });

  testWidgets('address rejects empty fields and invalid PIN before saving', (tester) async {
    final addresses = <CustomerAddress>[];
    await tester.pumpWidget(MaterialApp(home: AddressBookPage(
      addresses: addresses, onChanged: () {},
    )));
    await tester.tap(find.text('Add Address'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(addresses, isEmpty);
    expect(find.text('Label is required'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Home');
    await tester.enterText(fields.at(1), 'Flat 2, Main Road');
    await tester.enterText(fields.at(2), 'Talegaon');
    await tester.enterText(fields.at(3), '000000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(addresses, isEmpty);
    expect(find.text('Enter a valid 6-digit PIN code'), findsOneWidget);
    await tester.enterText(fields.at(3), '410507');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(addresses.single.pincode, '410507');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Account ignores valid base64 containing invalid image bytes', (tester) async {
    SharedPreferences.setMockInitialValues({
      'freshora_profile_photo_9876543210': base64Encode([1, 2, 3]),
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProfilePage(
      session: const CustomerSession(phone: '9876543210', name: 'Amit', token: 'test'),
      addresses: const [], onManageAddresses: () {}, onManageFavorites: () {},
      onViewOrders: () {},
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Amit'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('freshora_profile_photo_9876543210'), isNull);
  });

}

