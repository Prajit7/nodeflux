import 'dart:convert';

import 'package:flutter/material.dart';

import '../model/flow_edge.dart';
import '../model/flow_node.dart';
import '../theme/flow_theme.dart';

/// Hover card for an edge: source → target, data type, and the source
/// node's last output.
class EdgeTooltip extends StatelessWidget {
  const EdgeTooltip(
      {super.key,
      required this.edge,
      required this.source,
      required this.target});

  final FlowEdge edge;
  final FlowNode source, target;

  static String format(Object? v) {
    if (v is String) return v;
    try {
      return const JsonEncoder.withIndent('  ').convert(v);
    } catch (_) {
      return v.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = FlowTheme.of(context);
    final type = source.port(edge.sourcePort)?.type;
    return Material(
      color: t.nodeColor,
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text('${source.label} → ${target.label}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: t.textColor)),
                  ),
                  if (type != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                          color: type.color,
                          borderRadius: BorderRadius.circular(99)),
                      child: Text(type.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ]),
                const SizedBox(height: 6),
                if (source.output == null)
                  Text('Run the flow to see data',
                      style: TextStyle(fontSize: 12, color: t.mutedText))
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: t.background,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(format(source.output),
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: t.textColor)),
                  ),
              ]),
        ),
      ),
    );
  }
}
