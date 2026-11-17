import 'package:flutter/widgets.dart';

import 'flow_canvas.dart';

/// Marks an interactive region inside a custom node — a text field,
/// dropdown, slider, button, etc.
///
/// Pointer events that start inside [child] go to [child] only: they don't
/// select, drag, or pan. The rest of the node stays draggable.
///
/// ```dart
/// nodeBuilder: (context, node) => Card(
///   child: Column(children: [
///     Text(node.label),                       // drag the node from here
///     FlowInteractive(child: TextField(...)), // type here
///   ]),
/// ),
/// ```
class FlowInteractive extends StatelessWidget {
  const FlowInteractive({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => context
            .findAncestorStateOfType<FlowCanvasState>()
            ?.claimPointer(e.pointer),
        child: child,
      );
}
