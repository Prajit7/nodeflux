import 'package:flutter/material.dart';

import '../model/flow_node.dart';
import '../model/port.dart';

/// A node kind users can add from a picker or palette.
class NodeTemplate {
  const NodeTemplate(
      {required this.type,
      required this.label,
      required this.color,
      this.ports = const [],
      this.size = FlowNode.defaultSize,
      this.data});

  final String type;
  final String label;
  final Color color;
  final List<Port> ports;

  /// Size of nodes created from this template.
  final Size size;

  /// Initial [FlowNode.data] (e.g. default settings for a custom node).
  final Object? data;

  /// Whether this template has an input that accepts [from].
  bool accepts(PortType from) =>
      ports.any((p) => p.isInput && p.type.accepts(from));

  FlowNode create(String id, Offset position) => FlowNode(
      id: id,
      position: position,
      type: type,
      label: label,
      ports: ports,
      size: size,
      data: data);
}

/// Shows a popup listing [templates]. When [from] is given, only templates
/// that can accept that data type are listed. Returns the chosen template,
/// or null if dismissed.
Future<NodeTemplate?> showNodePicker(
  BuildContext context, {
  required List<NodeTemplate> templates,
  PortType? from,
  required Offset screenPosition,
}) {
  final ok = from == null
      ? templates
      : templates.where((t) => t.accepts(from)).toList();
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final pos = RelativeRect.fromRect(
      screenPosition & const Size(1, 1), Offset.zero & overlay.size);
  return showMenu<NodeTemplate>(
    context: context,
    position: pos,
    items: [
      PopupMenuItem<NodeTemplate>(
        enabled: false,
        height: 28,
        child: Text(
            from == null ? 'Add node' : 'Add node accepting ${from.name}',
            style: const TextStyle(fontSize: 11)),
      ),
      for (final t in ok)
        PopupMenuItem<NodeTemplate>(
          value: t,
          height: 36,
          child: Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: t.color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Text(t.label),
          ]),
        ),
    ],
  );
}
