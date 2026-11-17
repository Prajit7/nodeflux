import 'package:flutter/material.dart';

import '../controller/flow_controller.dart';
import '../theme/flow_theme.dart';

/// "Root › Group › …" trail shown while inside sub-flows. Tapping a crumb
/// leaves to that level. Renders nothing at the root.
class FlowBreadcrumb extends StatelessWidget {
  const FlowBreadcrumb(
      {super.key,
      required this.controller,
      this.rootLabel = 'Root',
      this.onNavigate});

  final FlowController controller;
  final String rootLabel;

  /// Called after navigating (e.g. to fit the view).
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final t = FlowTheme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        if (controller.depth == 0) return const SizedBox.shrink();
        final path = controller.path;
        final crumbs = <Widget>[];
        for (var i = 0; i <= path.length; i++) {
          final last = i == path.length;
          final label = i == 0 ? rootLabel : path[i - 1].label;
          if (i > 0) {
            crumbs.add(Text('  ›  ', style: TextStyle(color: t.mutedText)));
          }
          crumbs.add(last
              ? Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: t.textColor))
              : InkWell(
                  onTap: () {
                    controller.exitTo(i);
                    onNavigate?.call();
                  },
                  child: Text(label, style: TextStyle(color: t.selection)),
                ));
        }
        return Material(
          color: t.nodeColor,
          elevation: 2,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: crumbs),
          ),
        );
      },
    );
  }
}
