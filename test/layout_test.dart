import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

FlowNode n(String id) =>
    FlowNode(id: id, position: Offset.zero, type: 't', label: id);
FlowEdge e(String a, String b) => FlowEdge(
    id: '$a$b',
    sourceNode: a,
    sourcePort: 'out',
    targetNode: b,
    targetPort: 'in');

void main() {
  test('chain becomes columns', () {
    final p =
        layeredLayout([n('a'), n('b'), n('c')], [e('a', 'b'), e('b', 'c')]);
    expect(p['a']!.dx < p['b']!.dx && p['b']!.dx < p['c']!.dx, isTrue);
    expect(p['b']!.dx - p['a']!.dx, 180 + 80);
    expect(p['a']!.dy, p['c']!.dy);
  });

  test('siblings stacked without overlap', () {
    final nodes = [n('a'), n('b'), n('c'), n('d')];
    final p = layeredLayout(nodes, [e('a', 'b'), e('a', 'c'), e('a', 'd')]);
    final ys = [p['b']!.dy, p['c']!.dy, p['d']!.dy]..sort();
    expect(ys[1] - ys[0], greaterThanOrEqualTo(68 + 40));
    expect(ys[2] - ys[1], greaterThanOrEqualTo(68 + 40));
    expect(p['b']!.dx, p['c']!.dx);
  });

  test('cycle terminates', () {
    final p = layeredLayout(
        [n('a'), n('b'), n('c')], [e('a', 'b'), e('b', 'c'), e('c', 'a')]);
    expect(p.length, 3);
  });

  test('vertical direction', () {
    final p = layeredLayout([n('a'), n('b')], [e('a', 'b')],
        direction: Axis.vertical);
    expect(p['b']!.dy - p['a']!.dy, 68 + 80);
    expect(p['a']!.dx, p['b']!.dx);
  });

  test('autoLayout is one undo step', () {
    final c = FlowController(nodes: [n('a'), n('b')], edges: [e('a', 'b')]);
    c.autoLayout();
    expect(c.node('b')!.position.dx, 260);
    expect(c.historyLength, 1);
    c.undo();
    expect(c.node('b')!.position, Offset.zero);
  });
}
