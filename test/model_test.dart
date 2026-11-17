import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

const json = PortType('json', Color(0xFF3B5BDB));
const text = PortType('text', Color(0xFFE67700));

void main() {
  test('compatibility matrix', () {
    expect(json.accepts(json), isTrue);
    expect(text.accepts(json), isFalse);
    expect(PortType.any.accepts(text), isTrue);
    expect(json.accepts(PortType.any), isTrue);
    expect(json.accepts(null), isFalse);
  });

  test('portPosition', () {
    const n = FlowNode(
      id: 'a',
      position: Offset(100, 50),
      type: 'x',
      label: 'A',
      ports: [
        Port(id: 'in', side: PortSide.left, type: json),
        Port(id: 'out', side: PortSide.right, type: json),
      ],
    );
    expect(n.portPosition('out'), const Offset(280, 84));
    expect(n.portPosition('in'), const Offset(100, 84));
    expect(n.rect, const Rect.fromLTWH(100, 50, 180, 68));
  });

  test('copyWith keeps id', () {
    const n = FlowNode(id: 'a', position: Offset.zero, type: 'x', label: 'A');
    final m =
        n.copyWith(position: const Offset(5, 5), status: NodeStatus.running);
    expect(m.id, 'a');
    expect(m.position, const Offset(5, 5));
    expect(m.status, NodeStatus.running);
    expect(m.label, 'A');
  });
}
