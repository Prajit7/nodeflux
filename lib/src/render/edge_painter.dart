import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../controller/flow_controller.dart';
import '../controller/flow_viewport.dart';
import '../model/flow_edge.dart';
import '../model/flow_node.dart';
import '../model/node_status.dart';
import '../theme/flow_theme.dart';
import 'edge_path.dart';

/// Live connection being dragged, in world coordinates.
class ConnectPreview {
  const ConnectPreview(this.from, this.to, {this.bad = false});
  final Offset from, to;
  final bool bad;
}

const pulseDuration = Duration(milliseconds: 600);

/// Paints edges (with flowing dashes and data pulses), the connection
/// preview, and LOD node boxes, in world space.
class EdgePainter extends CustomPainter {
  EdgePainter({
    required this.controller,
    required this.viewport,
    required this.theme,
    required this.edgeType,
    required this.animate,
    required this.lod,
    required this.nodeColor,
    required Listenable repaint,
    this.preview,
    this.hoverEdge,
  }) : super(repaint: repaint);

  final FlowController controller;
  final FlowViewport viewport;
  final FlowTheme theme;
  final EdgeType edgeType;
  final bool animate, lod;
  final Color Function(FlowNode) nodeColor;
  final ConnectPreview? preview;
  final String? hoverEdge;

  static (Offset, Offset)? endpoints(FlowController c, FlowEdge e) {
    final a = c.node(e.sourceNode), b = c.node(e.targetNode);
    if (a == null ||
        b == null ||
        a.port(e.sourcePort) == null ||
        b.port(e.targetPort) == null) {
      return null;
    }
    return (a.portPosition(e.sourcePort), b.portPosition(e.targetPort));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final visible = viewport.visibleWorldRect(size).inflate(60);
    canvas
      ..save()
      ..translate(viewport.offset.dx, viewport.offset.dy)
      ..scale(viewport.zoom);
    final phase = (now.millisecondsSinceEpoch / 40) % 12;

    for (final e in controller.edges) {
      final ends = endpoints(controller, e);
      if (ends == null) continue;
      final (a, b) = ends;
      if (!visible.overlaps(Rect.fromPoints(a, b))) continue;
      final src = controller.node(e.sourceNode)!;
      final selected = controller.selectedEdge == e.id || hoverEdge == e.id;
      final base = src.port(e.sourcePort)!.type.color;
      final color = selected
          ? theme.selection
          : base.withValues(alpha: src.status == NodeStatus.success ? 1 : 0.55);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3 : 2;
      final path = buildEdgePath(a, b, edgeType);
      canvas.drawPath(animate && !lod ? _dash(path, phase) : path, paint);
      if (!lod) {
        final tip = b - const Offset(6, 0);
        canvas.drawPath(
            Path()
              ..moveTo(tip.dx, tip.dy)
              ..lineTo(tip.dx - 8, tip.dy - 5)
              ..lineTo(tip.dx - 8, tip.dy + 5)
              ..close(),
            Paint()..color = color);
      }
      final started = controller.pulses[e.id];
      if (started != null) {
        final u = now.difference(started).inMicroseconds /
            pulseDuration.inMicroseconds;
        if (u >= 0 && u < 1) {
          final p = pointOnEdge(a, b, edgeType, u);
          canvas
            ..drawCircle(p, 10, Paint()..color = base.withValues(alpha: 0.25))
            ..drawCircle(p, 6, Paint()..color = base);
        }
      }
    }

    if (lod) {
      for (final n in controller.nodes) {
        if (!visible.overlaps(n.rect)) continue;
        final r = RRect.fromRectAndRadius(n.rect, const Radius.circular(10));
        canvas
          ..drawRRect(r, Paint()..color = theme.nodeColor)
          ..drawRRect(
              r,
              Paint()
                ..style = PaintingStyle.stroke
                ..color = controller.selectedNodes.contains(n.id)
                    ? theme.selection
                    : theme.nodeBorder
                ..strokeWidth = 2)
          ..drawRect(Rect.fromLTWH(n.rect.left, n.rect.top, 6, n.rect.height),
              Paint()..color = nodeColor(n));
      }
    }

    final pv = preview;
    if (pv != null) {
      canvas.drawPath(
          _dash(buildEdgePath(pv.from, pv.to, edgeType), 0, on: 5, off: 5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = pv.bad ? theme.errorColor : theme.selection);
    }
    canvas.restore();
  }

  Path _dash(Path src, double phase, {double on = 6, double off = 6}) {
    final out = Path();
    final period = on + off;
    for (final m in src.computeMetrics()) {
      var d = -(period - phase % period);
      while (d < m.length) {
        final s = math.max(0.0, d), e = math.min(m.length, d + on);
        if (e > s) out.addPath(m.extractPath(s, e), Offset.zero);
        d += period;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(EdgePainter old) => true;
}
