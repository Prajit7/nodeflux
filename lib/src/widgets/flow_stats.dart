import 'package:flutter/material.dart';

import '../controller/flow_controller.dart';
import '../controller/flow_viewport.dart';
import '../theme/flow_theme.dart';

/// "{n} nodes · {e} edges · {zoom}%" readout.
class FlowStats extends StatelessWidget {
  const FlowStats(
      {super.key, required this.controller, required this.viewport});

  final FlowController controller;
  final FlowViewport viewport;

  @override
  Widget build(BuildContext context) {
    final t = FlowTheme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([controller, viewport]),
      builder: (context, child) => Text(
        '${controller.nodes.length} nodes · ${controller.edges.length} edges · ${(viewport.zoom * 100).round()}%',
        style: TextStyle(fontSize: 12, color: t.mutedText),
      ),
    );
  }
}
