import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

const json = PortType('json', Color(0xFF3B5BDB));

void main() {
  late FlowController c;

  Future<void> pump(WidgetTester t) async {
    c = FlowController(nodes: [
      const FlowNode(
          id: 'a',
          position: Offset(100, 100),
          size: Size(240, 120),
          type: 'form',
          label: 'Form',
          data: {'prompt': ''}),
    ]);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FlowCanvas(
          controller: c,
          animateEdges: false,
          nodeBuilder: (_, n) => Material(
            child: Column(children: [
              const Text('drag here'),
              FlowInteractive(
                child: TextField(
                  key: const Key('prompt'),
                  onChanged: (v) => c.updateNode(
                      n.copyWith(data: {'prompt': v}),
                      record: false),
                ),
              ),
            ]),
          ),
        ),
      ),
    ));
  }

  testWidgets('text field inside a node accepts typing', (t) async {
    await pump(t);
    await t.tap(find.byKey(const Key('prompt')));
    await t.enterText(find.byKey(const Key('prompt')), 'hello');
    await t.pump();
    expect(find.text('hello'), findsOneWidget);
    expect(c.node('a')!.data, {'prompt': 'hello'});
    expect(c.historyLength, 0);
  });

  testWidgets('dragging inside FlowInteractive does not move the node',
      (t) async {
    await pump(t);
    await t.drag(find.byKey(const Key('prompt')), const Offset(80, 40));
    await t.pump();
    expect(c.node('a')!.position, const Offset(100, 100));
  });

  testWidgets('dragging the rest of the node still moves it', (t) async {
    await pump(t);
    await t.drag(find.text('drag here'), const Offset(80, 40));
    await t.pump();
    expect(c.node('a')!.position, const Offset(180, 140));
  });

  testWidgets('backspace while typing does not delete the node', (t) async {
    await pump(t);
    await t.tap(find.text('drag here')); // selects node
    await t.tap(find.byKey(const Key('prompt')));
    await t.enterText(find.byKey(const Key('prompt')), 'hi');
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    await t.pump();
    expect(c.node('a'), isNotNull);
  });

  test('updateNode records undo when asked', () {
    final c = FlowController(nodes: [
      const FlowNode(
          id: 'a', position: Offset.zero, type: 't', label: 'A', data: 1)
    ]);
    c.updateNode(c.node('a')!.copyWith(data: 2));
    expect(c.node('a')!.data, 2);
    c.undo();
    expect(c.node('a')!.data, 1);
  });
}
