import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';
import 'package:nodeflux_example/main.dart';

void main() {
  testWidgets('demo runs the flow to success', (t) async {
    t.view.physicalSize = const Size(2400, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      const NodefluxDemo(stepDelay: Duration(milliseconds: 10)),
    );
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Fetch orders'), findsOneWidget);
    expect(find.text('Send to Slack'), findsOneWidget);
    await t.tap(find.text('Run'));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining(RegExp(r'^✓ \d+ms$')), findsNWidgets(7));
  });

  testWidgets('Add node button adds a node at view centre', (t) async {
    t.view.physicalSize = const Size(2400, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const NodefluxDemo());
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.text('Add node'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.tap(
      find.descendant(
        of: find.byType(PopupMenuItem<NodeTemplate>),
        matching: find.text('AI Agent'),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.text('AI Agent'),
      findsNWidgets(3),
    ); // seeded node's subtitle + new node title & subtitle
  });
}
