import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

const json = PortType('json', Color(0xFF3B5BDB));
const text = PortType('text', Color(0xFFE67700));
List<Port> io(PortType t) => [
      Port(id: 'in', side: PortSide.left, type: t),
      Port(id: 'out', side: PortSide.right, type: t)
    ];
FlowNode n(String id, Offset p, [PortType t = json]) =>
    FlowNode(id: id, position: p, type: 't', label: id, ports: io(t));

Future<FlowController> pump(WidgetTester t, List<FlowNode> nodes) async {
  final c = FlowController(nodes: nodes);
  await t.pumpWidget(MaterialApp(
      home: Scaffold(
          body: FlowCanvas(
              controller: c,
              animateEdges: false,
              nodeBuilder: (_, n) => Text(n.label)))));
  return c;
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
  testWidgets('drag selected edge end to other node reconnects', (t) async {
    final c = await pump(t, [
      n('a', const Offset(0, 100)),
      n('b', const Offset(400, 100)),
      n('c', const Offset(400, 300))
    ]);
    c.connect('a', 'out', 'b', 'in');
    c.selectEdge(c.edges.first.id);
    await t.pump();
    await mouseDrag(t, const Offset(400, 134), const Offset(490, 334));
    expect(c.edges.length, 1);
    expect(c.edges.first.sourceNode, 'a');
    expect(c.edges.first.targetNode, 'c');
    c.undo();
    expect(c.edges.single.targetNode, 'b');
  });

  testWidgets('drop edge end on empty deletes edge', (t) async {
    final c = await pump(
        t, [n('a', const Offset(0, 100)), n('b', const Offset(400, 100))]);
    c.connect('a', 'out', 'b', 'in');
    c.selectEdge(c.edges.first.id);
    await t.pump();
    await mouseDrag(t, const Offset(400, 134), const Offset(500, 500));
    expect(c.edges, isEmpty);
  });

  testWidgets('drop node on edge inserts it', (t) async {
    final c = await pump(t, [
      n('a', const Offset(0, 100)),
      n('b', const Offset(600, 100)),
      n('m', const Offset(300, 400))
    ]);
    c.connect('a', 'out', 'b', 'in');
    await t.pump();
    final h = c.historyLength;
    await mouseDrag(t, const Offset(390, 434), const Offset(390, 134));
    expect(c.edges.length, 2);
    expect(
        c.edges.any((e) => e.sourceNode == 'a' && e.targetNode == 'm'), isTrue);
    expect(
        c.edges.any((e) => e.sourceNode == 'm' && e.targetNode == 'b'), isTrue);
    expect(c.historyLength, h + 1);
    c.undo();
    expect(c.edges.single.targetNode, 'b');
    expect(c.node('m')!.position, const Offset(300, 400));
  });

  testWidgets('incompatible insert is ignored', (t) async {
    final c = await pump(t, [
      n('a', const Offset(0, 100)),
      n('b', const Offset(600, 100)),
      n('m', const Offset(300, 400), text)
    ]);
    c.connect('a', 'out', 'b', 'in');
    await t.pump();
    await mouseDrag(t, const Offset(390, 434), const Offset(390, 134));
    expect(c.edges.single.targetNode, 'b');
    expect(c.historyLength, 2); // connect + move only
  });

  test('reconnectCommand validates types', () {
    final c = FlowController(nodes: [
      n('a', Offset.zero),
      n('b', Offset.zero),
      n('t', Offset.zero, text)
    ]);
    c.connect('a', 'out', 'b', 'in');
    expect(c.reconnectCommand(c.edges.first.id, 't', 'in'), isNull);
  });
}
