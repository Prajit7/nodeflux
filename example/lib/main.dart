import 'package:flutter/material.dart';
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
      onToggleTheme: () => setState(
        () => _mode =
            Theme.of(context).brightness == Brightness.dark ||
                _mode == ThemeMode.dark
            ? ThemeMode.light
            : ThemeMode.dark,
      ),
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
                  IconButton(
                    tooltip: 'Fit view',
                    onPressed: () => canvasKey.currentState?.fitView(),
                    icon: const Icon(Icons.fit_screen),
                  ),
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
            child: FlowCanvas(
              key: canvasKey,
              controller: controller,
              viewport: viewport,
              edgeType: edgeType,
              animateEdges: animate,
              nodeColor: (n) => colorFor(n.type),
              onConnectRejected: (r) => _toast('✕ ${r.reason}'),
              onConnectEndEmpty: _pick,
              onCanvasMenu: _canvasMenu,
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
