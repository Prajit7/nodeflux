# nodeflux Foundation Implementation Plan (Plan 1 of 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A working `nodeflux` Flutter package with canvas (pan/zoom), widget nodes, typed ports + validated connections, four animated edge styles, run-status display, selection and undo/redo, plus an example app reproducing the HTML spike's sample flow.

**Architecture:** Immutable model (`FlowNode`, `FlowEdge`, `Port`) held by a `FlowController extends ChangeNotifier`; every mutation is a `FlowCommand` on an undo stack. `FlowCanvas` stacks a background/edge `CustomPainter` (driven by one ticker) under positioned node widgets culled to the viewport, inside a transform from `FlowViewport`.

**Tech Stack:** Flutter stable, Dart ≥ 3.5, `flutter_test`. No other runtime deps.

**Spec:** `docs/superpowers/specs/2026-11-17-nodeflux-design.md`
**Behaviour reference:** `../flow_editor_demo.html`

## Global Constraints
- Core depends only on Flutter SDK (+ `collection`/`vector_math` if needed). No `http`, no codegen, no state-management library.
- Dart ≥ 3.5, Flutter stable. MIT license.
- Mobile/touch first-class: long-press to start connections, pinch zoom.
- A "hello flow" must fit in ~15 lines.
- Light & dark themes.
- Git: the user commits. "Checkpoint" steps = run full tests + analyze, then suggest a commit message; do not run git.

## Review Focus
- Connecting a node to itself or creating a duplicate edge → refused, no command pushed (Task 2 test `rejects self and duplicate edges`).
- Deleting a node → its edges are removed too, and undo brings both back (Task 2 test `remove node cascades and undoes`).
- Zoom clamped to [0.05, 3]; zoom keeps the point under the cursor fixed (Task 3 tests).
- Port type `any` on either side is compatible; null input (Trigger-like) refuses all (Task 1 test `compatibility matrix`).
- A drag that doesn't move a node must not push an undo entry (Task 5 test `tap does not create history`).

---

### Task 1: Scaffold + model

**Files:**
- Create: package via `flutter create --template=package nodeflux` in `/Users/prajit/Documents/development/nodeflux` (keep existing `docs/`), `example/` via `flutter create --platforms=web,macos,android,ios example`
- Create: `lib/nodeflux.dart` (exports), `lib/src/model/port.dart`, `lib/src/model/flow_node.dart`, `lib/src/model/flow_edge.dart`, `lib/src/model/node_status.dart`
- Test: `test/model_test.dart`

**Interfaces — Produces:**
- `class PortType { final String name; final Color color; const PortType(this.name, this.color); static const any; bool accepts(PortType? from); }` — `accepts` true if either is `any` or names equal; false if `from` null.
- `enum PortSide { left, right }`; `class Port { final String id; final PortSide side; final PortType type; }`
- `enum NodeStatus { idle, running, success, error, skipped }`
- `class FlowNode { final String id; final Offset position; final Size size; final String type; final String label; final List<Port> ports; final NodeStatus status; final Duration? duration; final String? error; final Object? data; final Object? output; FlowNode copyWith(...); Rect get rect; Port? port(String id); Offset portPosition(String portId); }` — default size `Size(180, 68)`; left ports at `x`, right at `x+width`, vertically centred (spread evenly if several).
- `class FlowEdge { final String id; final String sourceNode, sourcePort, targetNode, targetPort; final String? label; FlowEdge copyWith(...); }`

- [ ] **Step 1:** Scaffold package + example; set `pubspec.yaml` description, `sdk: ^3.5.0`, MIT `LICENSE`; example depends on `nodeflux: {path: ../}`.
- [ ] **Step 2: failing tests** — `compatibility matrix`: `json.accepts(json)` true, `text.accepts(json)` false, `PortType.any.accepts(text)` true, `json.accepts(PortType.any)` true, `json.accepts(null)` false. `portPosition`: node at (100,50) size 180×68 → right port at (280,84), left at (100,84). `copyWith` keeps id.
- [ ] **Step 3:** Run `flutter test test/model_test.dart` → FAIL (undefined).
- [ ] **Step 4:** Implement model files; export from `lib/nodeflux.dart`.
- [ ] **Step 5:** Run → PASS; `flutter analyze` clean.
- [ ] **Step 6: Checkpoint** — suggest `feat: scaffold nodeflux package and core model`.

### Task 2: FlowController + commands + undo/redo

**Files:** Create `lib/src/controller/flow_controller.dart`, `lib/src/controller/commands.dart`; Test `test/controller_test.dart`

**Interfaces — Consumes:** Task 1 model. **Produces:**
- `abstract class FlowCommand { void apply(FlowGraph g); void revert(FlowGraph g); }` with `AddNode`, `RemoveNodes` (cascades edges), `MoveNodes(Map<String,Offset> from, to)`, `AddEdge`, `RemoveEdges`, `UpdateNode(before, after)`.
- `class FlowGraph { Map<String,FlowNode> nodes; Map<String,FlowEdge> edges; }` (mutable internals, read via controller getters).
- `class FlowController extends ChangeNotifier` with: `Iterable<FlowNode> get nodes`, `Iterable<FlowEdge> get edges`, `FlowNode? node(String id)`, `Set<String> selectedNodes`, `String? selectedEdge`, `void execute(FlowCommand c)`, `bool get canUndo/canRedo`, `void undo()`, `void redo()` (history cap 100; execute clears redo), `void addNode(FlowNode)`, `void removeSelected()`, `ConnectResult canConnect(String srcNode, String srcPort, String dstNode, String dstPort)`, `bool connect(...)` (pushes `AddEdge` only if `canConnect.ok`), `void select(String id, {bool additive=false})`, `void selectAll()`, `void clearSelection()`, `void setStatus(String id, NodeStatus s, {Duration? duration, String? error, Object? output})` (**not** on undo stack), `Stream<double>`-free `pulseEdge(String edgeId)` storing `Map<String,DateTime> pulses`.
- `class ConnectResult { final bool ok; final String? reason; }` — reasons exactly: `'Cannot connect a node to itself'`, `'Already connected'`, `'Target has no input'`, `'<from> → <to> not compatible'` (type names).

- [ ] **Step 1: failing tests** — `undo/redo add node`; `rejects self and duplicate edges` (history length unchanged); `type mismatch reason` equals `'text → json not compatible'`; `remove node cascades and undoes`; `history capped at 100`; `setStatus does not touch history`; `listeners notified on execute and undo`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5: Checkpoint** — `feat: controller with command history and typed connection validation`.

### Task 3: Viewport

**Files:** Create `lib/src/controller/flow_viewport.dart`; Test `test/viewport_test.dart`

**Produces:** `class FlowViewport extends ChangeNotifier { Offset offset; double zoom; static const minZoom=0.05, maxZoom=3.0; Offset toWorld(Offset screen); Offset toScreen(Offset world); void panBy(Offset d); void zoomAt(Offset focalScreen, double factor); Rect visibleWorldRect(Size viewport); FlowViewportState fitTarget(Rect content, Size viewport, {EdgeInsets padding = const EdgeInsets.all(60), double maxZoom = 1.4}); Matrix4 get matrix; }` — `FlowViewportState(offset, zoom)`; animation of fit done in Task 5 widget.

- [ ] **Step 1: failing tests** — `toWorld/toScreen roundtrip`; `zoomAt keeps focal point fixed` (world point under (300,200) identical before/after `zoomAt(..,2)`); `zoom clamped` (`zoomAt(…, 1000)` → 3.0, `1e-6` → 0.05); `fitTarget centres content`.
- [ ] **Step 2–4:** fail → implement → pass.
- [ ] **Step 5: Checkpoint** — `feat: viewport math`.

### Task 4: Edge geometry

**Files:** Create `lib/src/render/edge_path.dart`; Test `test/edge_path_test.dart`

**Produces:** `enum EdgeType { bezier, smoothstep, step, straight }`; `Path buildEdgePath(Offset a, Offset b, EdgeType t)`; `Offset pointOnEdge(Offset a, Offset b, EdgeType t, double u)`; `bool hitEdge(Offset a, Offset b, EdgeType t, Offset p, {double tolerance = 8})`.
Geometry must match the spike (`path2`/`pointAt` in `flow_editor_demo.html`): bezier control offset `max(40, |dx|/2)`; step/smoothstep via mid-x; smoothstep corner radius `min(12, |dy|/2, |mid-x − a.x|)`. `hitEdge` uses `Path.computeMetrics` sampling every 4px.

- [ ] **Step 1: failing tests** — `pointOnEdge u=0 is a, u=1 is b` for all 4 types; `step midpoint on vertical segment` (a=(0,0), b=(100,100) → u=0.5 gives x=50); `hitEdge true on straight midpoint, false 20px away`.
- [ ] **Step 2–4:** fail → implement → pass.
- [ ] **Step 5: Checkpoint** — `feat: edge path geometry`.

### Task 5: FlowCanvas — background, nodes, edges, gestures, selection

**Files:** Create `lib/src/widgets/flow_canvas.dart`, `lib/src/render/edge_painter.dart`, `lib/src/render/background_painter.dart`, `lib/src/theme/flow_theme.dart`; Test `test/flow_canvas_test.dart`

**Consumes:** Tasks 2–4. **Produces:**
- `class FlowTheme extends ThemeExtension<FlowTheme>` fields: `background, dotColor, nodeColor, nodeBorder, selection, textColor, mutedText, edgeColor, errorColor, successColor`; `FlowTheme.light()`, `FlowTheme.dark()` with the spike's CSS values (`#f6f7f9/#cfd3da/#fff/#dfe2e8/#3b5bdb…`, dark `#111318/#2b2f38/#1c1f26/#2f343e/#7c94ff…`); `FlowTheme.of(context)` falls back by brightness.
- `enum BackgroundType { dots, lines, none }`
- `class FlowCanvas extends StatefulWidget { FlowCanvas({required FlowController controller, FlowViewport? viewport, required Widget Function(BuildContext, FlowNode) nodeBuilder, EdgeType edgeType = EdgeType.bezier, bool animateEdges = true, BackgroundType background = BackgroundType.dots, double gridSize = 20}) }`
- Behaviour: drag empty = pan; scroll/trackpad = zoomAt cursor (factor `exp(-dy*0.0015)`); pinch = zoom; tap node = select (shift additive); drag node = move all selected, one `MoveNodes` on drag end only if moved; tap edge = select edge; tap empty = clear; Delete/Backspace = `removeSelected`; ⌘/Ctrl+Z undo, ⇧ redo; ⌘A select all. Only nodes intersecting `visibleWorldRect` are built. Edges: stroke colour = source port type colour, alpha 0.55 unless source `success` or selected; arrow at target; when `animateEdges` and zoom ≥ 0.45, dash [6,6] with offset `-t/40ms`; pulses draw a glowing dot travelling over 600ms using `pointOnEdge`. Below zoom 0.45 (LOD) nodes render as coloured rectangles in the painter instead of widgets.
- [ ] **Step 1: failing widget tests** — `renders only visible nodes` (node at (10000,10000) not found); `drag node moves it and creates one history entry`; `tap does not create history`; `tap empty clears selection`; `delete key removes selected`; `cmd+z undoes move`; `scroll zooms around cursor`.
- [ ] **Step 2–4:** fail → implement → pass.
- [ ] **Step 5: Checkpoint** — `feat: FlowCanvas with gestures, culling, animated edges`.

### Task 6: Interactive connections + empty-drop picker hook

**Files:** Modify `lib/src/widgets/flow_canvas.dart`; Create `lib/src/widgets/port_widget.dart`, `lib/src/widgets/node_picker.dart`; Test `test/connect_test.dart`

**Produces:** `FlowCanvas` params `void Function(ConnectResult)? onConnectRejected`, `Future<FlowNode?> Function(BuildContext, {required FlowNode source, required Port port, required Offset worldPosition})? onConnectEndEmpty`; `class NodePicker` default popup listing `List<NodeTemplate>` filtered by `accepts`; `class NodeTemplate { String type; String label; Color color; List<Port> ports; }`.
Behaviour: drag from output port (mouse) or long-press then drag (touch) → dashed preview line; hovering a node shows tooltip with `ConnectResult.reason` or `'json → json ✓'`, red preview when bad; drop on node → `connect`, on failure call `onConnectRejected`; drop on empty → `onConnectEndEmpty`, if it returns a node, add node + edge as one undo step (add a `BatchCommand(List<FlowCommand>)` in `commands.dart`).

- [ ] **Step 1: failing tests** — `drag output to compatible input creates edge`; `incompatible drop calls onConnectRejected with reason`; `drop on empty calls onConnectEndEmpty and adds node+edge, single undo removes both`; `long-press starts connection on touch`.
- [ ] **Step 2–4:** fail → implement → pass.
- [ ] **Step 5: Checkpoint** — `feat: typed interactive connections and node picker`.

### Task 7: DefaultFlowNode + data preview

**Files:** Create `lib/src/widgets/default_flow_node.dart`, `lib/src/widgets/edge_tooltip.dart`; Test `test/default_node_test.dart`

**Produces:** `DefaultFlowNode({required FlowNode node, required Color accent, bool selected})` matching spike: 6px accent strip, title (ellipsized), subtitle per status (`idle` → type, `running` → `'running…'` + spinner, `success` → `'✓ {ms}ms'` green badge, `error` → `'✕ {error}'` red border, `skipped` → 40% opacity), ports coloured by type. `FlowCanvas` param `bool showEdgeData = true`: hovering an edge shows `EdgeTooltip` with source→target labels, type pill and `JsonEncoder.withIndent('  ')` of source `output`, or `'Run the flow to see data'`.

- [ ] **Step 1: failing tests** — one per status asserting text/semantics; `edge hover shows output json`.
- [ ] **Step 2–4:** fail → implement → pass.
- [ ] **Step 5: Checkpoint** — `feat: default node with run status and edge data preview`.

### Task 8: Example app (hello flow + spike flow)

**Files:** `example/lib/main.dart`, `example/lib/demo_flow.dart`, `example/lib/run_simulator.dart`; `README.md`; Test `example/test/smoke_test.dart`

Example mirrors spike: 7-node flow (Trigger → Fetch orders → Transform → Condition → To Text → Summarize (Claude) → Send to Slack), types event/json/text with spike colours `#2f9e44/#3b5bdb/#e67700/#868e96`; toolbar: Run, Inject errors, Undo, Redo, edge type dropdown, Animate edges, theme toggle. `RunSimulator` walks layers by depth, sets status via `setStatus`, `pulseEdge` on success, 30% error when injected with spike error strings, downstream `skipped`. README "hello flow" snippet ≤ 15 lines.

- [ ] **Step 1: failing smoke test** — app pumps, 7 nodes visible, tapping Run eventually shows 7 `✓`.
- [ ] **Step 2–4:** fail → implement → pass.
- [ ] **Step 5:** `cd example && flutter run -d chrome`; screenshot light + dark; compare against spike.
- [ ] **Step 6: Checkpoint** — `feat: example app and README`.

---
**Plan 2 (next):** smart guides + grid snap, sub-flows + breadcrumb, command palette, minimap/controls/stats, auto-layout, JSON serialization, spatial index + 1k/5k benchmarks, pub.dev polish.
