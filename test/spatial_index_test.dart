import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

void main() {
  test('query returns overlapping items only', () {
    final i = SpatialIndex<String>()
      ..insert('a', const Rect.fromLTWH(0, 0, 100, 100))
      ..insert('b', const Rect.fromLTWH(1000, 1000, 100, 100));
    expect(i.query(const Rect.fromLTWH(50, 50, 10, 10)).toList(), ['a']);
    expect(i.at(const Offset(1050, 1050)).toList(), ['b']);
    expect(i.at(const Offset(500, 500)), isEmpty);
  });

  test('item spanning cells returned once', () {
    final i = SpatialIndex<String>(cell: 50)
      ..insert('big', const Rect.fromLTWH(0, 0, 400, 400));
    expect(i.query(const Rect.fromLTWH(0, 0, 400, 400)).toList(), ['big']);
  });

  test('negative coordinates', () {
    final i = SpatialIndex<String>()
      ..insert('n', const Rect.fromLTWH(-500, -500, 50, 50));
    expect(i.at(const Offset(-480, -480)).toList(), ['n']);
  });

  test('index follows moves and undo', () {
    final c = FlowController(nodes: const [
      FlowNode(id: 'a', position: Offset.zero, type: 't', label: 'a')
    ]);
    expect(
        c.nodesIn(const Rect.fromLTWH(10, 10, 1, 1)).map((n) => n.id), ['a']);
    c.execute(
        MoveNodes(from: {'a': Offset.zero}, to: {'a': const Offset(2000, 0)}));
    expect(c.nodesIn(const Rect.fromLTWH(10, 10, 1, 1)), isEmpty);
    expect(
        c.nodesIn(const Rect.fromLTWH(2010, 10, 1, 1)).map((n) => n.id), ['a']);
    c.undo();
    expect(
        c.nodesIn(const Rect.fromLTWH(10, 10, 1, 1)).map((n) => n.id), ['a']);
    c.moveLive({'a': const Offset(5000, 5000)});
    expect(c.nodesIn(const Rect.fromLTWH(5010, 5010, 1, 1)).map((n) => n.id),
        ['a']);
  });

  test('edgesNear finds edges by endpoint bounds', () {
    final c = FlowController(nodes: const [
      FlowNode(
          id: 'a',
          position: Offset.zero,
          type: 't',
          label: 'a',
          ports: [Port(id: 'out', side: PortSide.right, type: PortType.any)]),
      FlowNode(
          id: 'b',
          position: Offset(400, 0),
          type: 't',
          label: 'b',
          ports: [Port(id: 'in', side: PortSide.left, type: PortType.any)]),
    ]);
    c.connect('a', 'out', 'b', 'in');
    expect(c.edgesNear(const Rect.fromLTWH(290, 30, 1, 1)).length, 1);
    expect(c.edgesNear(const Rect.fromLTWH(3000, 3000, 1, 1)), isEmpty);
  });

  test('backwards edge bulge is indexed', () {
    final c = FlowController(nodes: const [
      FlowNode(
          id: 'a',
          position: Offset(2000, 0),
          type: 't',
          label: 'a',
          ports: [Port(id: 'out', side: PortSide.right, type: PortType.any)]),
      FlowNode(
          id: 'b',
          position: Offset(0, 300),
          type: 't',
          label: 'b',
          ports: [Port(id: 'in', side: PortSide.left, type: PortType.any)]),
    ]);
    c.connect('a', 'out', 'b', 'in');
    final e = c.edges.single;
    final a = c.node('a')!.portPosition('out'),
        b = c.node('b')!.portPosition('in');
    for (var u = 0.0; u <= 1; u += 0.05) {
      final p = pointOnEdge(a, b, EdgeType.bezier, u);
      expect(c.edgesNear(Rect.fromCenter(center: p, width: 1, height: 1)),
          contains(e),
          reason: 'u=$u');
    }
  });
}
