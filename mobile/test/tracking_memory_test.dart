import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talegaon_fresh/customer_api.dart';
import 'package:talegaon_fresh/main.dart';

final sampleOrder = OrderRecord(id: '1', total: 100, payment: 'COD', address: 'Talegaon', createdAt: DateTime(2026));
class TrackingApi extends HttpCustomerRepository {
  TrackingApi() : super(token: 'test');
  int polls = 0;
  @override
  Future<OrderRecord> getOrder(int id) async => sampleOrder;
  @override
  Future<OrderTracking> getTracking(int id) async {
    polls++;
    return const OrderTracking(status: 'CONFIRMED');
  }
  @override
  Future<List<OrderChatMessage>> getMessages(int id) async => [];
}

void main() {
  testWidgets('tracking pauses in background and resumes polling', (tester) async {
    final api = TrackingApi();
    await tester.pumpWidget(MaterialApp(home: TrackingPage(order: sampleOrder, api: api)));
    await tester.pump();
    await tester.pump();
    final initial = api.polls;
    expect(initial, greaterThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 24));
    expect(api.polls, initial);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(api.polls, greaterThan(initial));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('product image decoding is bounded', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SizedBox(width: 100, height: 100,
      child: ProductImage(product: Product(name: 'Tomato', unit: 'kg', price: 30, icon: Icons.circle)))));
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(images, isNotEmpty);
    expect(images.first.image, isA<ResizeImage>());
    final provider = images.first.image as ResizeImage;
    expect(provider.width, inInclusiveRange(1, 1024));
    await tester.pumpWidget(const SizedBox());
  });
}
