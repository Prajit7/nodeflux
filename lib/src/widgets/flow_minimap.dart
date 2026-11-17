import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controller/flow_controller.dart';
import '../controller/flow_viewport.dart';
import '../model/flow_node.dart';
import '../theme/flow_theme.dart';
import 'flow_canvas.dart';

/// Overview of the whole flow with the visible area outlined. Tap or drag
/// to move the view.
class FlowMinimap extends StatelessWidget {
  const FlowMinimap({
    super.key,
    required this.controller,
    required this.viewport,
    required this.canvas,
    this.size = const Size(200, 130),
    this.nodeColor,
  });

  final FlowController controller;
  final FlowViewport viewport;
  final GlobalKey<FlowCanvasState> canvas;
  final Size size;
  final Color Function(FlowNode node)? nodeColor;

  /// World rect shown by the minimap and its scale.
  (Rect, double) _frame() {
    final state = canvas.currentState;
    Rect r = state == null || state.canvasSize.isEmpty
        ? Rect.zero
        : viewport.visibleWorldRect(state.canvasSize);
    for (final n in controller.nodes) {
      r = r.isEmpty ? n.rect : r.expandToInclude(n.rect);
    }
    r = r.inflate(100);
    final k = math.min(size.width / r.width, size.height / r.height);
    // Centre the content in the box.
    final w = size.width / k, h = size.height / k;
    return (Rect.fromCenter(center: r.center, width: w, height: h), k);
  }

  void _jump(Offset local) {
    final (r, k) = _frame();
    canvas.currentState?.centerOn(r.topLeft + local / k);
  }

  @override
  Widget build(BuildContext context) {
    final t = FlowTheme.of(context);
    return Material(
      color: t.nodeColor,
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTapDown: (d) => _jump(d.localPosition),
        onPanUpdate: (d) => _jump(d.localPosition),
        child: SizedBox.fromSize(
          size: size,
          child: ListenableBuilder(
            listenable: Listenable.merge([controller, viewport]),
            builder: (context, _) {
              final (r, k) = _frame();
              final state = canvas.currentState;
              return CustomPaint(
                painter: _MinimapPainter(
                  nodes: controller.nodes.toList(),
                  frame: r,
                  scale: k,
                  view: state == null
                      ? null
                      : viewport.visibleWorldRect(state.canvasSize),
                  color: nodeColor ?? (_) => t.mutedText,
                  viewColor: t.selection,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({
    required this.nodes,
    required this.frame,
    required this.scale,
    required this.view,
    required this.color,
    required this.viewColor,
  });

  final List<FlowNode> nodes;
  final Rect frame;
  final double scale;
  final Rect? view;
  final Color Function(FlowNode) color;
  final Color viewColor;

  Rect _map(Rect r) => Rect.fromLTWH((r.left - frame.left) * scale,
      (r.top - frame.top) * scale, r.width * scale, r.height * scale);

  @override
  void paint(Canvas canvas, Size size) {
    for (final n in nodes) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(_map(n.rect), const Radius.circular(2)),
          Paint()..color = color(n));
    }
    final v = view;
    if (v != null) {
      final r = _map(v);
      canvas
        ..drawRect(r, Paint()..color = viewColor.withValues(alpha: 0.08))
        ..drawRect(
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = viewColor);
    }
  }

  @override
  bool shouldRepaint(_MinimapPainter old) => true;
}
