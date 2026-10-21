import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:talegaon_fresh/ai_assistant.dart';

void main() {
  testWidgets('AI assistant screen shows mobile commerce guidance', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AiAssistantPage(token: 'test-token'),
    ));

    expect(find.text('FRESHORA AI'), findsOneWidget);
    expect(
      find.textContaining('I can help with orders, tracking, products, checkout, and cancellations.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Send'), findsOneWidget);
  });
}
