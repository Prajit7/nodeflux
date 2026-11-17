import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

const io = [Port(id: 'in', side: PortSide.left, type: PortType.any), Port(id: 'out', side: PortSide.right, type: PortType.any)];

FlowController two() {
  final c = FlowController(nodes: const [
    FlowNode(id: 'a', position: Offset(0, 100), type: 't', label: 'a', ports: io),
    FlowNode(id: 'b', position: Offset(400, 100), type: 't', label: 'b', ports: io),
    FlowNode(id: 'c', position: Offset(400, 300), type: 't', label: 'c', ports: io),
  ]);
  c.connect('a', 'out', 'b', 'in');
  return c;
}

void main() {
  test('setEdgeLabel undoable', () {
    final c = two();
    final id = c.edges.single.id;
    c.setEdgeLabel(id, 'yes');
    expect(c.edge(id)!.label, 'yes');
    c.undo();
    expect(c.edge(id)!.label, isNull);
  });

  testWidgets('label painted', (t) async {
    final c = two()..setEdgeLabel('e1', 'on success');
    await t.pumpWidget(MaterialApp(home: Scaffold(body: FlowCanvas(controller: c, animateEdges: false, nodeBuilder: (_, n) => Text(n.label)))));
    await t.pump();
    expect(EdgePainter.debugLastLabelCount, 1);
  });

  testWidgets('reconnecting edge hidden', (t) async {
    final c = two();
    c.selectEdge(c.edges.single.id);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: FlowCanvas(controller: c, animateEdges: false, nodeBuilder: (_, n) => Text(n.label)))));
    await t.pump();
    expect(EdgePainter.debugLastEdgeCount, 1);
    final g = await t.startGesture(const Offset(400, 134), kind: PointerDeviceKind.mouse);
    await g.moveTo(const Offset(450, 250));
    await t.pump();
    expect(EdgePainter.debugLastEdgeCount, 0);
    await g.up();
    await t.pump();
  });
}
