import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/flow_controller.dart';
import '../theme/flow_theme.dart';
import 'flow_canvas.dart';

/// An entry in the command palette.
class FlowAction {
  const FlowAction(
      {required this.label, required this.run, this.color, this.shortcut});

  final String label;
  final VoidCallback run;

  /// Optional colour swatch (e.g. a node type's accent).
  final Color? color;

  /// Optional shortcut hint shown on the right, e.g. '⌘Z'.
  final String? shortcut;
}

/// Built-in actions for a canvas: undo, redo, select all, duplicate,
/// group/ungroup, auto-layout, fit view.
List<FlowAction> defaultFlowActions(
        FlowController c, FlowCanvasState? canvas) =>
    [
      FlowAction(label: 'Undo', shortcut: '⌘Z', run: c.undo),
      FlowAction(label: 'Redo', shortcut: '⌘⇧Z', run: c.redo),
      FlowAction(label: 'Select all', shortcut: '⌘A', run: c.selectAll),
      FlowAction(label: 'Duplicate', shortcut: '⌘D', run: c.duplicateSelection),
      FlowAction(
          label: 'Group into sub-flow', shortcut: '⌘G', run: c.groupSelection),
      FlowAction(
        label: 'Ungroup',
        shortcut: '⌘⇧G',
        run: () {
          if (c.selectedNodes.length == 1) c.ungroup(c.selectedNodes.single);
        },
      ),
      FlowAction(
        label: 'Auto-layout',
        run: () {
          c.autoLayout();
          canvas?.fitView();
        },
      ),
      FlowAction(label: 'Fit view', run: () => canvas?.fitView()),
    ];

/// Shows a searchable list of [actions]. Type to filter, ↑/↓ to move,
/// Enter or click to run, Esc to close.
Future<void> showFlowCommandPalette(BuildContext context,
    {required List<FlowAction> actions}) async {
  final chosen = await showDialog<FlowAction>(
    context: context,
    barrierColor: Colors.black26,
    builder: (_) => _Palette(actions: actions),
  );
  chosen?.run();
}

class _Palette extends StatefulWidget {
  const _Palette({required this.actions});
  final List<FlowAction> actions;

  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  String _q = '';
  int _i = 0;

  List<FlowAction> get _items {
    final q = _q.toLowerCase();
    return widget.actions
        .where((a) => a.label.toLowerCase().contains(q))
        .toList();
  }

  void _run() {
    final items = _items;
    if (items.isEmpty) return;
    Navigator.of(context).pop(items[_i.clamp(0, items.length - 1)]);
  }

  void _moveBy(int d) {
    final n = _items.length;
    if (n == 0) return;
    setState(() => _i = (_i + d).clamp(0, n - 1));
  }

  @override
  Widget build(BuildContext context) {
    final t = FlowTheme.of(context);
    final items = _items;
    return Align(
      alignment: const Alignment(0, -0.5),
      child: Material(
        color: t.nodeColor,
        elevation: 12,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 520,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _moveBy(1),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _moveBy(-1),
              const SingleActivator(LogicalKeyboardKey.enter): _run,
            },
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                autofocus: true,
                style: TextStyle(fontSize: 16, color: t.textColor),
                decoration: InputDecoration(
                  hintText: 'Type a command…',
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                  hintStyle: TextStyle(color: t.mutedText),
                ),
                onChanged: (v) => setState(() {
                  _q = v;
                  _i = 0;
                }),
                onSubmitted: (_) => _run(),
              ),
              Divider(height: 1, color: t.nodeBorder),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No matches',
                            style: TextStyle(color: t.mutedText)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(6),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final a = items[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => Navigator.of(context).pop(a),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              decoration: BoxDecoration(
                                color: i == _i ? t.background : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(children: [
                                if (a.color != null) ...[
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color: a.color,
                                        borderRadius: BorderRadius.circular(3)),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                    child: Text(a.label,
                                        style: TextStyle(color: t.textColor))),
                                if (a.shortcut != null)
                                  Text(a.shortcut!,
                                      style: TextStyle(
                                          fontSize: 12, color: t.mutedText)),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
