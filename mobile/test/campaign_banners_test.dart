import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talegaon_fresh/campaign_banners.dart';

void main() {
  testWidgets('active banner loads and opens shopping', (tester) async {
    var browsed = false;
    final client = MockClient((request) async {
      expect(request.url.path, '/campaigns');
      return http.Response(jsonEncode({'banners': [
        {'title': 'First order offer', 'description': '₹50 off ₹499', 'promo_code': 'WELCOME50'}
      ]}), 200);
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: CampaignBanners(client: client, baseUrl: 'https://example.test', onBrowse: () => browsed = true),
    )));
    await tester.pumpAndSettle();
    expect(find.text('First order offer'), findsOneWidget);
    expect(find.text('Copy WELCOME50'), findsOneWidget);
    await tester.tap(find.text('Shop now'));
    expect(browsed, isTrue);
    client.close();
  });

  testWidgets('failed campaign request keeps home usable', (tester) async {
    final client = MockClient((_) async => http.Response('', 503));
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: CampaignBanners(client: client, baseUrl: 'https://example.test', onBrowse: () {}),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsNothing);
    expect(tester.takeException(), isNull);
    client.close();
  });
}
