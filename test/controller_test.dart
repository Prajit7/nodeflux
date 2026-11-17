import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

const json = PortType('json', Color(0xFF3B5BDB));
const text = PortType('text', Color(0xFFE67700));

FlowNode node(String id, {PortType? inp = json, PortType? out = json}) =>
    FlowNode(
      id: id,
      position: Offset.zero,
      type: 't',
      label: id,
      ports: [
        if (inp != null) Port(id: 'in', side: PortSide.left, type: inp),
        if (out != null) Port(id: 'out', side: PortSide.right, type: out),
      ],
    );

void main() {
  late FlowController c;
  setUp(() => c = FlowController());

  test('undo/redo add node', () {
    c.addNode(node('a'));
    expect(c.nodes.length, 1);
    c.undo();
    expect(c.nodes, isEmpty);
    c.redo();
    expect(c.node('a'), isNotNull);
  });

  test('rejects self and duplicate edges', () {
    c
      ..addNode(node('a'))
      ..addNode(node('b'));
    expect(c.canConnect('a', 'out', 'a', 'in').reason,
        'Cannot connect a node to itself');
    expect(c.connect('a', 'out', 'b', 'in'), isTrue);
    final h = c.historyLength;
    expect(c.connect('a', 'out', 'b', 'in'), isFalse);
    expect(c.canConnect('a', 'out', 'b', 'in').reason, 'Already connected');
    expect(c.historyLength, h);
    expect(c.edges.length, 1);
  });

  test('type mismatch reason', () {
    c
      ..addNode(node('a', out: text))
      ..addNode(node('b'))
      ..addNode(node('t', inp: null));
    final r = c.canConnect('a', 'out', 'b', 'in');
    expect(r.ok, isFalse);
    expect(r.reason, 'text → json not compatible');
    expect(c.canConnect('a', 'out', 't', 'in').reason, 'Target has no input');
  });

  test('remove node cascades and undoes', () {
    c
      ..addNode(node('a'))
      ..addNode(node('b'))
      ..connect('a', 'out', 'b', 'in');
    c.select('a');
    c.removeSelected();
    expect(c.nodes.length, 1);
    expect(c.edges, isEmpty);
    c.undo();
    expect(c.nodes.length, 2);
    expect(c.edges.length, 1);
  });

  test('history capped at 100', () {
    for (var i = 0; i < 150; i++) {
      c.addNode(node('n$i'));
    }
    expect(c.historyLength, 100);
  });

  test('execute clears redo', () {
    c.addNode(node('a'));
    c.undo();
    expect(c.canRedo, isTrue);
    c.addNode(node('b'));
    expect(c.canRedo, isFalse);
  });

  test('setStatus does not touch history', () {
    c.addNode(node('a'));
    final h = c.historyLength;
    c.setStatus('a', NodeStatus.success,
        duration: const Duration(milliseconds: 5), output: {'x': 1});
    expect(c.historyLength, h);
    expect(c.node('a')!.status, NodeStatus.success);
    expect(c.node('a')!.output, {'x': 1});
  });

  test('move nodes undoes', () {
    c.addNode(node('a'));
    c.execute(
        MoveNodes(from: {'a': Offset.zero}, to: {'a': const Offset(10, 20)}));
    expect(c.node('a')!.position, const Offset(10, 20));
    c.undo();
    expect(c.node('a')!.position, Offset.zero);
  });

  test('listeners notified on execute and undo', () {
    var n = 0;
    c.addListener(() => n++);
    c.addNode(node('a'));
    c.undo();
    expect(n, 2);
  });

  test('pulseEdge records time', () {
    c
      ..addNode(node('a'))
      ..addNode(node('b'))
      ..connect('a', 'out', 'b', 'in');
    final id = c.edges.first.id;
    c.pulseEdge(id);
    expect(c.pulses.containsKey(id), isTrue);
  });
}
