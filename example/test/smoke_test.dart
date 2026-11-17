import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('auto-layout button rearranges and save/load restores', (
    t,
  ) async {
    t.view.physicalSize = const Size(2400, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await t.pumpWidget(const NodefluxDemo());
    await t.pump(const Duration(milliseconds: 600));
    expect(
      find.text('7 nodes · 6 edges · ', findRichText: false),
      findsNothing,
    );
    expect(find.textContaining('7 nodes · 6 edges'), findsOneWidget);
    final before = t.getTopLeft(find.text('Fetch orders'));
    await t.tap(find.text('Auto-layout'));
    await t.pump(const Duration(milliseconds: 600));
    expect(t.getTopLeft(find.text('Fetch orders')), isNot(before));

    await t.tap(find.text('Save'));
    await t.pump();
    expect(copied, contains('"version": 1'));

    await t.tap(find.text('Load'));
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byKey(const Key('load-json')), copied!);
    await t.tap(find.widgetWithText(FilledButton, 'Load'));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('7 nodes · 6 edges'), findsOneWidget);
    expect(find.text('Send to Slack'), findsOneWidget);
  });
}
