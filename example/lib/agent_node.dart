import 'package:flutter/material.dart';
import 'package:nodeflux/nodeflux.dart';

/// A custom node with real inputs: shows how to build configurable nodes.
/// Everything wrapped in [FlowInteractive] receives clicks and typing; the
/// header still drags the node.
class AgentNode extends StatelessWidget {
  const AgentNode({
    super.key,
    required this.node,
    required this.controller,
    required this.accent,
  });

  final FlowNode node;
  final FlowController controller;
  final Color accent;

  static const models = [
    'claude-opus-5-5',
    'claude-sonnet-5-5',
    'claude-haiku-5-5',
  ];

  Map<String, Object?> get _cfg =>
      Map<String, Object?>.from(node.data as Map? ?? const {});

  void _set(String key, Object? value, {bool record = true}) => controller
      .updateNode(node.copyWith(data: {..._cfg, key: value}), record: record);

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedNodes.contains(node.id);
    final t = FlowTheme.of(context);
    final model = _cfg['model'] as String? ?? models[1];
    return DefaultFlowNode(
      node: node,
      accent: accent,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FlowInteractive(
              child: DropdownButton<String>(
                value: models.contains(model) ? model : models[1],
                isDense: true,
                isExpanded: true,
                style: TextStyle(fontSize: 12, color: t.textColor),
                underline: const SizedBox(),
                items: [
                  for (final m in models)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (v) => _set('model', v),
              ),
            ),
            const SizedBox(height: 6),
            FlowInteractive(
              child: TextFormField(
                initialValue: _cfg['prompt'] as String? ?? '',
                maxLines: 2,
                style: TextStyle(fontSize: 12, color: t.textColor),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Prompt…',
                  filled: true,
                  fillColor: t.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(8),
                ),
                onChanged: (v) => _set('prompt', v, record: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
