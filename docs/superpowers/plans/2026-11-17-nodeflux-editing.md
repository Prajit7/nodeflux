# nodeflux Editing Implementation Plan (Plan 2 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Marquee selection, clipboard, edge reconnect, insert-on-edge, smart guides + grid snap, minimap/controls/stats, JSON save/load and auto-layout.

**Architecture:** All graph changes stay `FlowCommand`s on `FlowController`. Pure logic (guides, layout, serialization, clipboard) lives in plain Dart files with unit tests; `FlowCanvas` only wires gestures to it. Overlay widgets (`FlowMinimap`, `FlowControls`, `FlowStats`) take the controller + a `GlobalKey<FlowCanvasState>`/viewport and are placed by the app in a `Stack`.

**Tech Stack:** Flutter stable, Dart ≥ 3.5, `flutter_test`. No new runtime deps.

**Spec:** `docs/superpowers/specs/2026-11-17-nodeflux-design.md` · Plan 1: `2026-11-17-nodeflux-foundation.md` · Behaviour reference: `../flow_editor_demo.html`

## Global Constraints
- Core depends only on Flutter SDK. No codegen, no state-management library.
- Every user edit is undoable as exactly one step.
- Pointers claimed by `FlowInteractive` are never handled by new gestures.
- Canvas shortcuts act only when the canvas has primary focus.
- Git: the user commits. Checkpoint = full tests + analyze, then suggest a message.

## Review Focus
- Paste twice → second copy offset again, new unique ids, edges between pasted nodes remapped, edges to un-copied nodes dropped (Task 2 test `paste remaps ids and drops external edges`).
- `fromJson` with unknown port type name → falls back to `PortType.any`, doesn't throw (Task 6 test `unknown port type falls back`).
- Auto-layout with a cycle → terminates, every node placed (Task 7 test `cycle terminates`).
- Insert-on-edge with an incompatible node → no change, no history (Task 3 test `incompatible insert is ignored`).
- Guides never snap a node to itself or to other selected nodes (Task 4 test `ignores selected nodes`).

---

### Task 1: Marquee selection
**Files:** Modify `lib/src/widgets/flow_canvas.dart`, `lib/src/render/edge_painter.dart`, `lib/src/controller/flow_controller.dart`; Test `test/marquee_test.dart`
**Produces:** `FlowController.selectNodes(Iterable<String> ids, {bool additive = false})`. `ConnectPreview` unchanged; `EdgePainter` gains `Rect? marquee` (world rect, filled `selection` @8% + 1px stroke).
Behaviour: Shift + drag on empty canvas (mouse) draws marquee; on release selects nodes fully inside (additive). Plain drag still pans.
- [ ] Tests: `shift-drag selects nodes inside`, `partially covered node not selected`, `plain drag still pans`. RED → implement → GREEN → checkpoint `feat: marquee selection`.

### Task 2: Clipboard — copy / paste / duplicate
**Files:** Create `lib/src/controller/clipboard.dart`; Modify controller + canvas keys; Test `test/clipboard_test.dart`
**Produces:** `class FlowClipboard { final List<FlowNode> nodes; final List<FlowEdge> edges; }`; `FlowController.copySelection() → FlowClipboard?` (edges only where both ends selected), `void paste(FlowClipboard clip, {Offset offset = const Offset(30, 30)})` (one `BatchCommand`; new ids `'${old}_${n}'` unique; selects pasted), `void duplicateSelection()` = copy+paste. Controller holds `FlowClipboard? clipboard`; each paste of the same clip increases offset by +30 cumulative.
Keys: ⌘C copy, ⌘V paste, ⌘D duplicate, ⌘X cut (copy + removeSelected).
- [ ] Tests: `paste remaps ids and drops external edges`, `paste twice offsets again`, `paste is one undo step`, `cmd+d duplicates`. RED → GREEN → checkpoint `feat: copy, paste, duplicate`.

### Task 3: Edge reconnect + insert-on-edge
**Files:** Modify canvas, controller; Test `test/edge_edit_test.dart`
**Produces:** `FlowController.reconnectCommand(String edgeId, String dstNode, String dstPort) → FlowCommand?` (remove+add as Batch; validated with `canConnect` ignoring the edge itself); `FlowController.insertOnEdgeCommand(String edgeId, String nodeId) → FlowCommand?` (replaces edge A→B with A→N, N→B using N's first compatible in/out ports; null if either side incompatible).
Behaviour: dragging within 12px of a **selected** edge's target end detaches it (preview like connect); drop on a node → reconnect; drop on empty → delete edge. Dragging a single node and releasing while its centre is over an edge (hitEdge tolerance 16/zoom) and the node has no edges → insert (the move + insert one Batch). Edge under the dragged node is highlighted (hoverEdge).
- [ ] Tests: `drag selected edge end to other node reconnects`, `drop edge end on empty deletes edge`, `drop node on edge inserts it`, `incompatible insert is ignored`. RED → GREEN → checkpoint `feat: reconnect edges and insert node on edge`.

### Task 4: Smart guides + grid snap
**Files:** Create `lib/src/controller/guides.dart`; Modify canvas, painter; Test `test/guides_test.dart`
**Produces:** `class GuideLine { final Axis axis; final double at, from, to; }`; `({Offset delta, List<GuideLine> lines}) computeGuides(Rect moving, Iterable<Rect> others, {required double threshold})` — compares left/centre/right and top/middle/bottom, nearest within threshold per axis. FlowCanvas params `bool snapToGuides = true`, `bool snapToGrid = false` (grid uses `gridSize`; guide wins per axis). Painter draws guides red dashed `#F03E3E`, 1/zoom px. Threshold 6/zoom. Grabbed node is the reference; all selected move by the same adjusted delta.
- [ ] Tests: `snaps left edges within threshold`, `centre alignment`, `nothing beyond threshold`, `ignores selected nodes` (widget), `grid snap rounds position`. RED → GREEN → checkpoint `feat: smart guides and grid snap`.

### Task 5: Minimap, controls, stats
**Files:** Create `lib/src/widgets/flow_minimap.dart`, `flow_controls.dart`, `flow_stats.dart`; Test `test/overlays_test.dart`
**Produces:** `FlowMinimap({required FlowController controller, required FlowViewport viewport, required GlobalKey<FlowCanvasState> canvas, Size size = const Size(200, 130), Color Function(FlowNode)? nodeColor})` — paints nodes + viewport rect; tap/drag recentres viewport on that world point. `FlowControls({required GlobalKey<FlowCanvasState> canvas, required FlowViewport viewport})` — zoom in (×1.2 at centre), zoom out (÷1.2), fit, vertical column of IconButtons with tooltips `'Zoom in'`, `'Zoom out'`, `'Fit view'`. `FlowStats({controller, viewport})` → text `'{n} nodes · {e} edges · {zoom}%'`. FlowCanvasState gains `Size get canvasSize`, `void centerOn(Offset world)`.
- [ ] Tests: `minimap tap recentres viewport`, `zoom in button zooms 1.2x`, `stats text`. RED → GREEN → checkpoint `feat: minimap, controls, stats`.

### Task 6: JSON serialization
**Files:** Create `lib/src/serialization/flow_json.dart`; Test `test/json_test.dart`
**Produces:** `FlowController.toJson({Object? Function(Object? data)? encodeData}) → Map<String, Object?>` and `FlowController.fromJson(Map<String, Object?> json, {required Map<String, PortType> portTypes, Object? Function(Object? raw)? decodeData})` factory. Shape: `{"version":1,"nodes":[{"id","type","label","x","y","w","h","ports":[{"id","side":"left|right","type"}],"data"}],"edges":[{"id","source","sourcePort","target","targetPort","label"}]}`. Run state (status/output) not serialized. Unknown type → `PortType.any`. Default `encodeData` passes through JSON-safe values.
- [ ] Tests: `roundtrip preserves graph`, `unknown port type falls back`, `custom data codec used`, `history empty after load`. RED → GREEN → checkpoint `feat: JSON save and load`.

### Task 7: Auto-layout
**Files:** Create `lib/src/layout/layered_layout.dart`; Test `test/layout_test.dart`
**Produces:** `Map<String, Offset> layeredLayout(Iterable<FlowNode> nodes, Iterable<FlowEdge> edges, {double layerGap = 80, double nodeGap = 40, Axis direction = Axis.horizontal})` — longest-path layering (cycle-safe: cap iterations at node count), order within layer by barycenter of predecessors (one pass), layers centred on y=0. `FlowController.autoLayout({...same params}) ` executes one `MoveNodes`. Canvas `fitView()` afterward is the app's call.
- [ ] Tests: `chain becomes columns`, `siblings stacked without overlap`, `cycle terminates`, `autoLayout is one undo step`. RED → GREEN → checkpoint `feat: auto-layout`.

### Task 8: Example + docs
**Files:** `example/lib/main.dart`, `README.md`, `CHANGELOG.md`; Test `example/test/smoke_test.dart`
Example: Stack overlays — `FlowMinimap` bottom-right, `FlowControls` bottom-left, `FlowStats` above controls; toolbar adds Auto-layout, Save (copies JSON to clipboard + toast), Load (paste JSON dialog), Guides & Grid toggles. README sections for each feature. CHANGELOG 0.0.2.
- [ ] Smoke tests: `auto-layout button rearranges and fits`, `save then load restores node count`. Build web, check in Chrome both themes. Checkpoint `feat: example editing features and docs`.
