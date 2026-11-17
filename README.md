# nodeflux

A fast, widget-based **node & flow editor for Flutter** — built for workflow, automation and AI-agent builders.

- Infinite canvas: pan, zoom (wheel, trackpad, pinch), animated fit-to-view
- Nodes are **any Flutter widget**; only visible nodes are built
- **Typed ports** — invalid connections are refused with a reason
- Bezier / smoothstep / step / straight edges with **flowing dash animation**
- **Run status** on nodes (running · success · error · skipped) and **data pulses** along edges
- Hover a connection to **preview the data** it carried
- Drop a connection on empty space → **compatible-node picker**; right-click / double-click to add nodes
- **Configurable custom nodes** with real text fields, dropdowns, buttons (`FlowInteractive`)
- Multi-select, delete, **undo / redo** (⌘Z / ⌘⇧Z), keyboard shortcuts
- Light & dark themes, all 6 platforms, **zero dependencies** beyond Flutter

## Hello flow

```dart
const json = PortType('json', Colors.blue);
const ports = [Port(id: 'in', side: PortSide.left, type: json), Port(id: 'out', side: PortSide.right, type: json)];

final flow = FlowController(
  nodes: [
    const FlowNode(id: 'a', position: Offset(0, 0), type: 'step', label: 'Fetch', ports: ports),
    const FlowNode(id: 'b', position: Offset(260, 80), type: 'step', label: 'Transform', ports: ports),
  ],
  edges: [const FlowEdge(id: 'e1', sourceNode: 'a', sourcePort: 'out', targetNode: 'b', targetPort: 'in')],
);

FlowCanvas(
  controller: flow,
  nodeBuilder: (context, node) => DefaultFlowNode(node: node, accent: Colors.blue),
);
```

## Custom, configurable nodes

Any widget can be a node. Wrap interactive parts (text fields, dropdowns,
switches, buttons) in `FlowInteractive` so they receive clicks and typing;
the rest of the node still drags. Store settings in `node.data`:

```dart
nodeBuilder: (context, node) => DefaultFlowNode(
  node: node,
  accent: Colors.teal,
  child: FlowInteractive(
    child: TextFormField(
      initialValue: (node.data as Map)['prompt'],
      onChanged: (v) => flow.updateNode(node.copyWith(data: {'prompt': v}), record: false),
    ),
  ),
),
```

Give such nodes a taller `size` (e.g. `Size(260, 172)`). Canvas shortcuts
(Delete, ⌘Z…) are ignored while a field inside a node has focus.

## Adding nodes

- `flow.addNode(node)` from your own UI (toolbar, sidebar, palette)
- `onCanvasMenu: (context, worldPosition) {…}` — right-click or double-click on empty canvas
- `onConnectEndEmpty` — drop a connection on empty space; return the new node
- `showNodePicker(context, templates: …, from: portType)` — ready-made menu

## Showing run state

Your app runs the flow; nodeflux shows it:

```dart
flow.setStatus('a', NodeStatus.running);
flow.setStatus('a', NodeStatus.success, duration: d, output: {'items': 3});
flow.pulseEdge('e1'); // glowing dot travels along the edge
```

See `example/` for a full workflow editor demo.

## License

MIT
