import 'package:flutter/widgets.dart';

import '../model/flow_edge.dart';
import '../model/flow_node.dart';

/// Arranges nodes in layers following edge direction (left→right by
/// default). Returns new top-left positions keyed by node id.
///
/// Layers come from longest path (cycles are cut off after one pass per
/// node); nodes in a layer are ordered by the average position of their
/// predecessors to reduce crossings, and each layer is centred on 0.
Map<String, Offset> layeredLayout(
  Iterable<FlowNode> nodes,
  Iterable<FlowEdge> edges, {
  double layerGap = 80,
  double nodeGap = 40,
  Axis direction = Axis.horizontal,
}) {
  final list = nodes.toList();
  final ids = {for (final n in list) n.id};
  final es = edges
      .where((e) =>
          ids.contains(e.sourceNode) &&
          ids.contains(e.targetNode) &&
          e.sourceNode != e.targetNode)
      .toList();

  final layer = {for (final n in list) n.id: 0};
  for (var i = 0; i < list.length; i++) {
    var changed = false;
    for (final e in es) {
      if (layer[e.targetNode]! <= layer[e.sourceNode]! &&
          layer[e.sourceNode]! + 1 < list.length) {
        layer[e.targetNode] = layer[e.sourceNode]! + 1;
        changed = true;
      }
    }
    if (!changed) break;
  }

  final count = layer.values.fold(0, (m, v) => v > m ? v : m) + 1;
  final layers = List.generate(count, (_) => <FlowNode>[]);
  for (final n in list) {
    layers[layer[n.id]!].add(n);
  }

  // Order each layer by barycenter of predecessors in the previous layer.
  final index = <String, double>{};
  for (var l = 0; l < count; l++) {
    if (l > 0) {
      final bary = <String, double>{};
      for (final n in layers[l]) {
        final preds = es
            .where(
                (e) => e.targetNode == n.id && index.containsKey(e.sourceNode))
            .map((e) => index[e.sourceNode]!);
        bary[n.id] = preds.isEmpty
            ? double.infinity
            : preds.reduce((a, b) => a + b) / preds.length;
      }
      final orig = {
        for (var i = 0; i < layers[l].length; i++) layers[l][i].id: i
      };
      layers[l].sort((a, b) {
        final c = bary[a.id]!.compareTo(bary[b.id]!);
        return c != 0 ? c : orig[a.id]!.compareTo(orig[b.id]!);
      });
    }
    for (var i = 0; i < layers[l].length; i++) {
      index[layers[l][i].id] = i.toDouble();
    }
  }

  final horizontal = direction == Axis.horizontal;
  double main(Size s) => horizontal ? s.width : s.height;
  double cross(Size s) => horizontal ? s.height : s.width;

  final out = <String, Offset>{};
  var at = 0.0;
  for (final ns in layers) {
    if (ns.isEmpty) continue;
    final total = ns.fold<double>(0, (s, n) => s + cross(n.size)) +
        nodeGap * (ns.length - 1);
    var c = -total / 2;
    for (final n in ns) {
      out[n.id] = horizontal ? Offset(at, c) : Offset(c, at);
      c += cross(n.size) + nodeGap;
    }
    at +=
        ns.map((n) => main(n.size)).reduce((a, b) => a > b ? a : b) + layerGap;
  }
  return out;
}
