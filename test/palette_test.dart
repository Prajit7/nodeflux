import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

void main() {
  final ran = <String>[];
  List<FlowAction> actions() => [
        FlowAction(label: 'Add: Trigger', run: () => ran.add('trigger')),
        FlowAction(label: 'Add: HTTP Request', run: () => ran.add('http')),
        FlowAction(label: 'Auto-layout', run: () => ran.add('layout'), shortcut: '⌘L'),
      ];

  Future<void> open(WidgetTester t) async {
    ran.clear();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (ctx) {
      return TextButton(onPressed: () => showFlowCommandPalette(ctx, actions: actions()), child: const Text('open'));
    }))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  testWidgets('filters by text', (t) async {
    await open(t);
    expect(find.text('Auto-layout'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'add');
    await t.pump();
    expect(find.text('Add: Trigger'), findsOneWidget);
    expect(find.text('Auto-layout'), findsNothing);
  });

  testWidgets('enter runs highlighted', (t) async {
    await open(t);
    await t.enterText(find.byType(TextField), 'http');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(ran, ['http']);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('arrow keys move', (t) async {
    await open(t);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(ran, ['layout']);
  });

  testWidgets('click runs', (t) async {
    await open(t);
    await t.tap(find.text('Add: Trigger'));
    await t.pumpAndSettle();
    expect(ran, ['trigger']);
  });

  testWidgets('cmd+k opens with defaults and extras', (t) async {
    final c = FlowController(nodes: const [FlowNode(id: 'a', position: Offset(100, 100), type: 't', label: 'a')]);
    var extra = false;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FlowCanvas(
                controller: c,
                animateEdges: false,
                paletteActions: () => [FlowAction(label: 'My action', run: () => extra = true)],
                nodeBuilder: (_, n) => Text(n.label)))));
    await t.tapAt(const Offset(600, 500));
    await t.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await t.sendKeyEvent(LogicalKeyboardKey.keyK);
    await t.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Auto-layout'), findsOneWidget);
    await t.tap(find.text('My action'));
    await t.pump(const Duration(milliseconds: 300));
    expect(extra, isTrue);
  });
}
