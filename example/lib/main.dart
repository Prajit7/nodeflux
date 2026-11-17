import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nodeflux/nodeflux.dart';

import 'agent_node.dart';
import 'demo_flow.dart';
import 'run_simulator.dart';

void main() => runApp(const NodefluxDemo());

class NodefluxDemo extends StatefulWidget {
  const NodefluxDemo({
    super.key,
    this.stepDelay = const Duration(milliseconds: 300),
  });
  final Duration stepDelay;

  @override
  State<NodefluxDemo> createState() => _NodefluxDemoState();
}

class _NodefluxDemoState extends State<NodefluxDemo> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'nodeflux demo',
    debugShowCheckedModeBanner: false,
    themeMode: _mode,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF3B5BDB),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorSchemeSeed: const Color(0xFF3B5BDB),
      brightness: Brightness.dark,
      useMaterial3: true,
    ),
    home: EditorPage(
      stepDelay: widget.stepDelay,
      onToggleTheme: () => setState(() {
        // In system mode the effective brightness is the platform's.
        final dark = _mode == ThemeMode.dark ||
            (_mode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        _mode = dark ? ThemeMode.light : ThemeMode.dark;
      }),
    ),
  );
}

class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    required this.stepDelay,
    required this.onToggleTheme,
  });
  final Duration stepDelay;
  final VoidCallback onToggleTheme;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final controller = buildDemoFlow();
  final viewport = FlowViewport();
  final canvasKey = GlobalKey<FlowCanvasState>();
  late final sim = RunSimulator(controller, stepDelay: widget.stepDelay);
  EdgeType edgeType = EdgeType.bezier;
  bool animate = true, injectErrors = false, running = false;
  bool guides = true, grid = false;
  int _ids = 100;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => canvasKey.currentState?.fitView(),
    );
  }

  Future<void> _run() async {
    setState(() => running = true);
    final errors = await sim.run(injectErrors: injectErrors);
    if (!mounted) return;
    setState(() => running = false);
    _toast(
      errors == 0
          ? '✓ Run succeeded · hover a connection to see its data'
          : 'Run finished with $errors error(s)',
    );
  }

  void _autoLayout() {
    controller.autoLayout();
    canvasKey.currentState?.fitView();
  }

  Future<void> _save() async {
    final text = const JsonEncoder.withIndent('  ')
        .convert(controller.toJson());
    await Clipboard.setData(ClipboardData(text: text));
    _toast('Flow JSON copied to clipboard (${controller.nodes.length} nodes)');
  }

  Future<void> _load() async {
    final field = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load flow JSON'),
        content: SizedBox(
          width: 480,
          child: TextField(
            key: const Key('load-json'),
            controller: field,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'Paste JSON saved with Save',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, field.text),
            child: const Text('Load'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      controller.loadJson(
        jsonDecode(text) as Map<String, Object?>,
        portTypes: portTypes,
      );
      canvasKey.currentState?.fitView();
      _toast('Loaded ${controller.nodes.length} nodes');
    } catch (e) {
      _toast('✕ Not valid flow JSON');
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        width: 420,
      ),
    );

  Future<FlowNode?> _pick(
    BuildContext ctx, {
    required FlowNode source,
    required Port port,
    required Offset worldPosition,
  }) async {
    final box = canvasKey.currentContext!.findRenderObject() as RenderBox;
    final at = box.localToGlobal(viewport.toScreen(worldPosition));
    final t = await showNodePicker(
      ctx,
      templates: templates,
      from: port.type,
      screenPosition: at,
    );
    return t?.create(
      'n${_ids++}',
      worldPosition - Offset(0, FlowNode.defaultSize.height / 2),
    );
  }

  /// Adds a node of [t] at [world] (top-left), selects it.
  void _add(NodeTemplate t, Offset world) {
    final node = t.create('n${_ids++}', world);
    controller.addNode(node);
    controller.select(node.id);
  }

  Offset get _viewCentre {
    final size =
        (canvasKey.currentContext!.findRenderObject() as RenderBox).size;
    return viewport.toWorld(size.center(Offset.zero)) -
        Offset(FlowNode.defaultSize.width / 2, FlowNode.defaultSize.height / 2);
  }

  Future<void> _canvasMenu(BuildContext ctx, Offset world) async {
    final box = canvasKey.currentContext!.findRenderObject() as RenderBox;
    final t = await showNodePicker(
      ctx,
      templates: templates,
      screenPosition: box.localToGlobal(viewport.toScreen(world)),
    );
    if (t != null) _add(t, world);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: cs.surface,
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'nodeflux',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: running ? null : _run,
                    icon: Icon(
                      running ? Icons.hourglass_top : Icons.play_arrow,
                    ),
                    label: Text(running ? 'Running…' : 'Run'),
                  ),
                  PopupMenuButton<NodeTemplate>(
                    tooltip: 'Add node',
                    onSelected: (t) => _add(t, _viewCentre),
                    itemBuilder: (_) => [
                      for (final t in templates)
                        PopupMenuItem(
                          value: t,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: t.color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(t.label),
                            ],
                          ),
                        ),
                    ],
                    child: const Chip(
                      avatar: Icon(Icons.add, size: 18),
                      label: Text('Add node'),
                    ),
                  ),
                  _check(
                    'Inject errors',
                    injectErrors,
                    (v) => setState(() => injectErrors = v),
                  ),
                  const SizedBox(width: 4),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (_, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Undo (⌘Z)',
                          onPressed: controller.canUndo
                              ? controller.undo
                              : null,
                          icon: const Icon(Icons.undo),
                        ),
                        IconButton(
                          tooltip: 'Redo (⌘⇧Z)',
                          onPressed: controller.canRedo
                              ? controller.redo
                              : null,
                          icon: const Icon(Icons.redo),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _autoLayout,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Auto-layout'),
                  ),
                  TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('Load'),
                  ),
                  _check('Guides', guides, (v) => setState(() => guides = v)),
                  _check('Grid', grid, (v) => setState(() => grid = v)),
                  DropdownButton<EdgeType>(
                    value: edgeType,
                    underline: const SizedBox(),
                    items: [
                      for (final t in EdgeType.values)
                        DropdownMenuItem(value: t, child: Text(t.name)),
                    ],
                    onChanged: (v) => setState(() => edgeType = v!),
                  ),
                  _check(
                    'Animate edges',
                    animate,
                    (v) => setState(() => animate = v),
                  ),
                  IconButton(
                    tooltip: 'Toggle theme',
                    onPressed: widget.onToggleTheme,
                    icon: const Icon(Icons.contrast),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlowCanvas(
                  key: canvasKey,
                  controller: controller,
                  viewport: viewport,
                  edgeType: edgeType,
                  animateEdges: animate,
                  nodeColor: (n) => colorFor(n.type),
                  onConnectRejected: (r) => _toast('✕ ${r.reason}'),
                  onConnectEndEmpty: _pick,
                  onCanvasMenu: _canvasMenu,
                  snapToGuides: guides,
                  snapToGrid: grid,
                  nodeBuilder: (_, n) => n.type == 'AI Agent'
                      ? AgentNode(
                          node: n,
                          controller: controller,
                          accent: colorFor(n.type),
                        )
                      : DefaultFlowNode(
                          node: n,
                          accent: colorFor(n.type),
                          selected: controller.selectedNodes.contains(n.id),
                        ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FlowMinimap(
                    controller: controller,
                    viewport: viewport,
                    canvas: canvasKey,
                    nodeColor: (n) => colorFor(n.type),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: FlowControls(canvas: canvasKey, viewport: viewport),
                ),
                Positioned(
                  left: 16,
                  top: 12,
                  child: FlowStats(controller: controller, viewport: viewport),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _check(String label, bool v, ValueChanged<bool> on) => InkWell(
    onTap: () => on(!v),
    borderRadius: BorderRadius.circular(6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(value: v, onChanged: (x) => on(x!)),
        Text(label),
        const SizedBox(width: 6),
      ],
    ),
  );
}
