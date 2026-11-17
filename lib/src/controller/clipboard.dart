import 'dart:ui' show Offset;

import '../model/flow_edge.dart';
import '../model/flow_node.dart';

/// A copied set of nodes and the edges between them.
class FlowClipboard {
  FlowClipboard(this.nodes, this.edges);

  final List<FlowNode> nodes;
  final List<FlowEdge> edges;

  /// How many times this clip has been pasted; each paste is offset further.
  int pasteCount = 0;
}

FlowNode cloneNode(FlowNode n, String id, Offset delta) => FlowNode(
      id: id,
      position: n.position + delta,
      size: n.size,
      type: n.type,
      label: n.label,
      ports: n.ports,
      data: n.data,
      subflow: n.subflow,
    );
