import 'package:flutter/material.dart';

import '../model/flow_node.dart';
import '../model/node_status.dart';
import '../model/port.dart';
import '../theme/flow_theme.dart';

/// The built-in node look: accent strip, title, status line, typed ports.
class DefaultFlowNode extends StatelessWidget {
  const DefaultFlowNode(
      {super.key,
      required this.node,
      required this.accent,
      this.selected = false,
      this.child});

  final FlowNode node;
  final Color accent;
  final bool selected;

  /// Optional body shown under the header — put your node's inputs here,
  /// wrapped in [FlowInteractive]. Give the node a taller [FlowNode.size].
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = FlowTheme.of(context);
    final s = node.status;
    final border = switch (s) {
      NodeStatus.error => t.errorColor,
      NodeStatus.running => accent,
      _ => selected ? t.selection : t.nodeBorder,
    };
    final thick = selected || s == NodeStatus.running || s == NodeStatus.error;
    final (subtitle, subColor) = switch (s) {
      NodeStatus.idle => (node.type, t.mutedText),
      NodeStatus.running => ('running…', t.mutedText),
      NodeStatus.success => (
          '✓ ${node.duration?.inMilliseconds ?? 0}ms',
          t.successColor
        ),
      NodeStatus.error => ('✕ ${node.error ?? 'failed'}', t.errorColor),
      NodeStatus.skipped => ('skipped', t.mutedText),
    };

    final body = Container(
      decoration: BoxDecoration(
        color: t.nodeColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: thick ? 2.5 : 1),
        boxShadow: selected
            ? [
                BoxShadow(
                    color: t.selection.withValues(alpha: 0.18), blurRadius: 12)
              ]
            : null,
      ),
      child: Row(children: [
        Container(
          width: 6,
          decoration: BoxDecoration(
            color: accent,
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(8)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: _content(Row(children: [
          Expanded(
            child: Opacity(
              opacity: s == NodeStatus.skipped ? 0.4 : 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: t.textColor)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: subColor)),
                ],
              ),
            ),
          ),
          SizedBox(width: 30, child: Center(child: _badge(s, t))),
        ]))),
      ]),
    );

    return Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(child: body),
      for (final p in node.ports) _port(p, t),
    ]);
  }

  Widget _content(Widget header) {
    final c = child;
    if (c == null) return header;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: FlowNode.defaultSize.height - 8, child: header),
      Expanded(
          child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 10), child: c)),
    ]);
  }

  Widget _badge(NodeStatus s, FlowTheme t) => switch (s) {
        NodeStatus.running => SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: accent)),
        NodeStatus.success => _dot(t.successColor, '✓'),
        NodeStatus.error => _dot(t.errorColor, '!'),
        _ => const SizedBox.shrink(),
      };

  Widget _dot(Color c, String ch) => Container(
        width: 16,
        height: 16,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        child: Text(ch,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      );

  Widget _port(Port p, FlowTheme t) {
    final local = node.portPosition(p.id) - node.position;
    return Positioned(
      left: local.dx - 6,
      top: local.dy - 6,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: t.nodeColor,
          shape: BoxShape.circle,
          border: Border.all(color: p.type.color, width: 2.5),
        ),
      ),
    );
  }
}
