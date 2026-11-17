import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

FlowNode n(String id, Offset p) => FlowNode(id: id, position: p, type: 't', label: id);

Future<(FlowController, FlowViewport)> pump(WidgetTester t) async {
  final c = FlowController(nodes: [
    n('a', const Offset(100, 100)),
    n('b', const Offset(100, 250)),
    n('c', const Offset(500, 100)),
  ]);
  final v = FlowViewport();
  await t.pumpWidget(MaterialApp(
      home: Scaffold(
          body: FlowCanvas(controller: c, viewport: v, animateEdges: false, nodeBuilder: (_, n) => Text(n.label)))));
  return (c, v);
}

Future<void> mouseDrag(WidgetTester t, Offset from, Offset to) async {
  final g = await t.startGesture(from, kind: PointerDeviceKind.mouse);
  await g.moveTo((from + to) / 2);
  await t.pump();
  await g.moveTo(to);
  await t.pump();
  await g.up();
  await t.pump();
}

void main() {
  testWidgets('shift-drag selects nodes inside', (t) async {
    final (c, v) = await pump(t);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await mouseDrag(t, const Offset(50, 50), const Offset(320, 360));
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(c.selectedNodes, {'a', 'b'});
    expect(v.offset, Offset.zero);
  });

  testWidgets('partially covered node not selected', (t) async {
    final (c, _) = await pump(t);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await mouseDrag(t, const Offset(50, 50), const Offset(200, 200));
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(c.selectedNodes, isEmpty);
  });

  testWidgets('plain drag still pans', (t) async {
    final (c, v) = await pump(t);
    await mouseDrag(t, const Offset(50, 50), const Offset(320, 360));
    expect(c.selectedNodes, isEmpty);
    expect(v.offset, const Offset(270, 310));
  });

  test('selectNodes additive', () {
    final c = FlowController(nodes: [n('a', Offset.zero), n('b', Offset.zero)]);
    c.select('a');
    c.selectNodes(['b'], additive: true);
    expect(c.selectedNodes, {'a', 'b'});
    c.selectNodes(['b']);
    expect(c.selectedNodes, {'b'});
  });
}
