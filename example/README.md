# nodeflux example — workflow editor

A full workflow editor built with [nodeflux](https://pub.dev/packages/nodeflux).
**[Open the live demo](https://nodeflux-demo.vercel.app)**.

What it shows:

- A 7-step flow (Trigger → Fetch orders → Transform → Condition → To Text → AI Agent → Slack) with typed `event` / `json` / `text` ports
- **Run** with live node status, data pulses along edges, and *Inject errors* to see failures
- Hover a connection to preview its data
- A custom **AI Agent** node with a real model dropdown and prompt field (`FlowInteractive`)
- Add nodes from the toolbar, right-click / double-click, ⌘K, or by dropping a connection on empty space
- Group into sub-flows, open them, breadcrumb back
- Auto-layout, Save / Load JSON, guides and grid snap, minimap, light / dark theme
- **Stress 1k** — 1,000 nodes

## Run it

```bash
flutter run -d chrome   # or macos, ios, android, windows, linux
```

## Where to look

| File | What's in it |
|---|---|
| [`lib/main.dart`](https://github.com/Prajit7/nodeflux/blob/main/example/lib/main.dart) | The editor page: canvas, toolbar, overlays, add-node menu, save / load |
| [`lib/demo_flow.dart`](https://github.com/Prajit7/nodeflux/blob/main/example/lib/demo_flow.dart) | Port types, node templates, the sample flow |
| [`lib/agent_node.dart`](https://github.com/Prajit7/nodeflux/blob/main/example/lib/agent_node.dart) | A configurable custom node with inputs |
| [`lib/run_simulator.dart`](https://github.com/Prajit7/nodeflux/blob/main/example/lib/run_simulator.dart) | Fake engine driving `setStatus` / `pulseEdge` |
