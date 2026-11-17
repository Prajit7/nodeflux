import 'package:flutter/material.dart';
import 'package:nodeflux/nodeflux.dart';

const event = PortType('event', Color(0xFF2F9E44));
const json = PortType('json', Color(0xFF3B5BDB));
const text = PortType('text', Color(0xFFE67700));

List<Port> io(PortType? i, PortType? o) => [
  if (i != null) Port(id: 'in', side: PortSide.left, type: i),
  if (o != null) Port(id: 'out', side: PortSide.right, type: o),
];

final templates = <NodeTemplate>[
  NodeTemplate(
    type: 'Trigger',
    label: 'Trigger',
    color: const Color(0xFF2F9E44),
    ports: io(null, event),
  ),
  NodeTemplate(
    type: 'HTTP Request',
    label: 'HTTP Request',
    color: const Color(0xFF3B5BDB),
    ports: io(event, json),
  ),
  NodeTemplate(
    type: 'Transform',
    label: 'Transform',
    color: const Color(0xFF1C7ED6),
    ports: io(json, json),
  ),
  NodeTemplate(
    type: 'Condition',
    label: 'Condition',
    color: const Color(0xFFAE3EC9),
    ports: io(json, json),
  ),
  NodeTemplate(
    type: 'To Text',
    label: 'To Text',
    color: const Color(0xFFF08C00),
    ports: io(json, text),
  ),
  NodeTemplate(
    type: 'AI Agent',
    label: 'AI Agent',
    color: const Color(0xFF0C8599),
    ports: io(text, text),
    size: const Size(260, 172),
    data: const {
      'model': 'claude-sonnet-5-5',
      'prompt': 'Summarize today\'s sales in one line.',
    },
  ),
  NodeTemplate(
    type: 'Output',
    label: 'Output',
    color: const Color(0xFFC92A2A),
    ports: io(PortType.any, null),
  ),
];

Color colorFor(String type) => templates
    .firstWhere((t) => t.type == type, orElse: () => templates.first)
    .color;

FlowController buildDemoFlow() {
  const labels = [
    'Trigger',
    'Fetch orders',
    'Transform',
    'Condition',
    'To Text',
    'Summarize (Claude)',
    'Send to Slack',
  ];
  final nodes = [
    for (var i = 0; i < templates.length; i++)
      FlowNode(
        id: 'n${i + 1}',
        position: Offset(i * 260.0 + (i > 5 ? 80 : 0), i.isOdd ? 120 : 0),
        size: templates[i].size,
        data: templates[i].data,
        type: templates[i].type,
        label: labels[i],
        ports: templates[i].ports,
      ),
  ];
  return FlowController(
    nodes: nodes,
    edges: [
      for (var i = 1; i < nodes.length; i++)
        FlowEdge(
          id: 'e$i',
          sourceNode: 'n$i',
          sourcePort: 'out',
          targetNode: 'n${i + 1}',
          targetPort: 'in',
        ),
    ],
  );
}

Object? payloadFor(FlowNode n) => switch (n.type) {
  'Trigger' => {
    'event': 'webhook',
    'at': DateTime.now().toIso8601String().substring(11, 19),
  },
  'HTTP Request' => {
    'status': 200,
    'orders': [
      {'id': 'A12', 'amt': 1820},
      {'id': 'B07', 'amt': 2100},
      {'id': 'C33', 'amt': 900},
    ],
  },
  'Transform' => {'count': 3, 'total': 4820, 'currency': 'INR'},
  'Condition' => {'passed': true, 'rule': 'total > 1000'},
  'To Text' => '3 orders today, total ₹4,820',
  'AI Agent' =>
    'Sales are healthy: 3 orders worth ₹4,820, led by B07 (₹2,100).',
  'Output' => {'delivered': true, 'channel': '#sales'},
  _ => {'ok': true},
};
