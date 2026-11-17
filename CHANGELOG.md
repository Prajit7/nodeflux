## 0.1.0

- Sub-flows: `groupSelection`, `ungroup`, `enter`, `exit`, `FlowBreadcrumb`; saved in JSON; per-level undo.
- ⌘K command palette: `showFlowCommandPalette`, `FlowAction`, `defaultFlowActions`, `FlowCanvas.paletteActions`.
- Edge labels (`setEdgeLabel`), hidden old edge while reconnecting.
- Performance: spatial index for culling and hit-testing; node widgets cached per node.
- Nodes expose semantics labels for screen readers.
- CI workflow.

## 0.0.2

- Box selection (Shift-drag), copy / cut / paste / duplicate.
- Reconnect edges by dragging their end; drop a node on an edge to insert it.
- Smart alignment guides and grid snap.
- FlowMinimap, FlowControls, FlowStats overlays.
- JSON save / load (`toJson`, `fromJson`, `loadJson`).
- Layered auto-layout (`autoLayout`, `layeredLayout`).
- Add-node menu (`onCanvasMenu`), interactive custom nodes (`FlowInteractive`), `updateNode`.

## 0.0.1

- Initial foundation: canvas, typed ports, animated edges, run status, data previews, undo/redo.
