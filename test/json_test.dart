import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

const json = PortType('json', Color(0xFF3B5BDB));
const io = [
  Port(id: 'in', side: PortSide.left, type: json),
  Port(id: 'out', side: PortSide.right, type: json)
];

FlowController graph() {
  final c = FlowController(nodes: [
    const FlowNode(
        id: 'a',
        position: Offset(10, 20),
        type: 'http',
        label: 'A',
        ports: io,
        data: {'url': 'x'}),
    const FlowNode(
        id: 'b',
        position: Offset(300, 40),
        size: Size(240, 150),
        type: 'ai',
        label: 'B',
        ports: io),
  ]);
  c.connect('a', 'out', 'b', 'in');
  c.setStatus('a', NodeStatus.success, output: {'secret': 1});
  return c;
}

void main() {
  test('roundtrip preserves graph', () {
    final src = graph();
    final text = jsonEncode(src.toJson());
    final c = FlowController.fromJson(jsonDecode(text) as Map<String, Object?>,
        portTypes: {'json': json});
    expect(c.nodes.length, 2);
    final b = c.node('b')!;
    expect(b.position, const Offset(300, 40));
    expect(b.size, const Size(240, 150));
    expect(b.type, 'ai');
    expect(b.port('in')!.type, json);
    expect(c.node('a')!.data, {'url': 'x'});
    expect(c.node('a')!.status, NodeStatus.idle);
    expect(c.node('a')!.output, isNull);
    expect(c.edges.single.sourceNode, 'a');
    expect(c.edges.single.targetPort, 'in');
    expect(text.contains('secret'), isFalse);
  });

  test('unknown port type falls back', () {
    final m = graph().toJson();
    final c = FlowController.fromJson(m, portTypes: const {});
    expect(c.node('a')!.port('out')!.type, PortType.any);
  });

  test('custom data codec used', () {
    final m = graph().toJson(encodeData: (d) => d == null ? null : 'ENC');
    expect((m['nodes'] as List).first['data'], 'ENC');
    final c = FlowController.fromJson(m,
        portTypes: {'json': json},
        decodeData: (raw) => raw == 'ENC' ? 'DEC' : raw);
    expect(c.node('a')!.data, 'DEC');
  });

  test('history empty after load', () {
    final c =
        FlowController.fromJson(graph().toJson(), portTypes: {'json': json});
    expect(c.canUndo, isFalse);
  });

  test('version field present', () {
    expect(graph().toJson()['version'], 1);
  });

  test('loadJson replaces graph in place and clears history', () {
    final c = FlowController(nodes: [
      const FlowNode(id: 'z', position: Offset.zero, type: 't', label: 'Z')
    ]);
    c.addNode(
        const FlowNode(id: 'y', position: Offset.zero, type: 't', label: 'Y'));
    c.select('z');
    var notified = 0;
    c.addListener(() => notified++);
    c.loadJson(graph().toJson(), portTypes: {'json': json});
    expect(c.nodes.map((n) => n.id).toSet(), {'a', 'b'});
    expect(c.canUndo, isFalse);
    expect(c.selectedNodes, isEmpty);
    expect(notified, 1);
  });
}
