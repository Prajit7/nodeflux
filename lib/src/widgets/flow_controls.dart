import 'package:flutter/material.dart';

import '../controller/flow_viewport.dart';
import '../theme/flow_theme.dart';
import 'flow_canvas.dart';

/// Zoom in / zoom out / fit buttons.
class FlowControls extends StatelessWidget {
  const FlowControls(
      {super.key,
      required this.canvas,
      required this.viewport,
      this.step = 1.2});

  final GlobalKey<FlowCanvasState> canvas;
  final FlowViewport viewport;
  final double step;

  @override
  Widget build(BuildContext context) {
    final t = FlowTheme.of(context);
    return Material(
      color: t.nodeColor,
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            tooltip: 'Zoom in',
            icon: const Icon(Icons.add),
            onPressed: () => canvas.currentState?.zoomBy(step)),
        IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.remove),
            onPressed: () => canvas.currentState?.zoomBy(1 / step)),
        IconButton(
            tooltip: 'Fit view',
            icon: const Icon(Icons.fit_screen),
            onPressed: () => canvas.currentState?.fitView()),
      ]),
    );
  }
}
