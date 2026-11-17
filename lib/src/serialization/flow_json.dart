import 'dart:ui';

import '../model/flow_edge.dart';
import '../model/flow_node.dart';
import '../model/port.dart';

/// Current JSON schema version written by [encodeFlow].
const flowJsonVersion = 1;

/// Converts a graph to a JSON-safe map. Run state (status, output) is not
/// saved. [encodeData] converts each node's `data`; by default it is written
/// as-is and must already be JSON-safe.
Map<String, Object?> encodeFlow(
        Iterable<FlowNode> nodes, Iterable<FlowEdge> edges,
        {Object? Function(Object? data)? encodeData}) =>
    {
      'version': flowJsonVersion,
      'nodes': [
        for (final n in nodes)
          {
            'id': n.id,
            'type': n.type,
            'label': n.label,
            'x': n.position.dx,
            'y': n.position.dy,
            'w': n.size.width,
            'h': n.size.height,
            'ports': [
              for (final p in n.ports)
                {'id': p.id, 'side': p.side.name, 'type': p.type.name},
            ],
            if (n.data != null || encodeData != null)
              'data': encodeData == null ? n.data : encodeData(n.data),
          },
      ],
      'edges': [
        for (final e in edges)
          {
            'id': e.id,
            'source': e.sourceNode,
            'sourcePort': e.sourcePort,
            'target': e.targetNode,
            'targetPort': e.targetPort,
            if (e.label != null) 'label': e.label,
          },
      ],
    };

/// Reads a map written by [encodeFlow]. Port types are looked up by name in
/// [portTypes]; unknown names become [PortType.any].
(List<FlowNode>, List<FlowEdge>) decodeFlow(Map<String, Object?> json,
    {required Map<String, PortType> portTypes,
    Object? Function(Object? raw)? decodeData}) {
  double d(Object? v, double fallback) => v is num ? v.toDouble() : fallback;
  final nodes = <FlowNode>[
    for (final raw in (json['nodes'] as List? ?? const []).cast<Map>())
      FlowNode(
        id: raw['id'] as String,
        type: raw['type'] as String? ?? '',
        label: raw['label'] as String? ?? '',
        position: Offset(d(raw['x'], 0), d(raw['y'], 0)),
        size: Size(d(raw['w'], FlowNode.defaultSize.width),
            d(raw['h'], FlowNode.defaultSize.height)),
        ports: [
          for (final p in (raw['ports'] as List? ?? const []).cast<Map>())
            Port(
              id: p['id'] as String,
              side: p['side'] == 'left' ? PortSide.left : PortSide.right,
              type: portTypes[p['type']] ?? PortType.any,
            ),
        ],
        data: decodeData == null ? raw['data'] : decodeData(raw['data']),
      ),
  ];
  final edges = <FlowEdge>[
    for (final raw in (json['edges'] as List? ?? const []).cast<Map>())
      FlowEdge(
        id: raw['id'] as String,
        sourceNode: raw['source'] as String,
        sourcePort: raw['sourcePort'] as String,
        targetNode: raw['target'] as String,
        targetPort: raw['targetPort'] as String,
        label: raw['label'] as String?,
      ),
  ];
  return (nodes, edges);
}
