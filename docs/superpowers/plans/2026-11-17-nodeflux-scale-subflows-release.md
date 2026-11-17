# nodeflux Scale, Sub-flows & Release Plan (Plan 3 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Meet the spec's performance targets, add sub-flows and the command palette, close known gaps (edge labels, reconnect ghost, semantics), and make the package publish-ready.

**Architecture:** A uniform-grid `SpatialIndex` (cell 256 world units) rebuilt lazily when the graph changes answers point and rect queries for nodes and edge bounds. Node widgets are cached per immutable `FlowNode` instance + selected flag so unchanged nodes skip rebuilds. Sub-flows store a nested `SubFlow(nodes, edges)` on `FlowNode.subflow`; the controller keeps a stack of levels (graph + history) and exposes the current level only.

**Spec:** `docs/superpowers/specs/2026-11-17-nodeflux-design.md` · Plans 1–2 in this folder.

## Global Constraints
- Core depends only on Flutter SDK; Dart ≥ 3.5 (no wildcard `_` duplicates).
- 1k nodes smooth on desktop/web, target 5k; 200 nodes 60fps mid-range phone.
- Every user edit is one undo step; run state never in history.
- Git: user commits. Never run `pub publish` — dry-run only.

## Review Focus
- Index stale after move/undo/load → hit-tests wrong (Task 1 test `index follows moves and undo`).
- Entering a sub-flow, editing, exiting → edits persist in parent node and survive JSON roundtrip (Task 3 tests).
- Undo inside a sub-flow never undoes parent-level edits (Task 3 test `history is per level`).
- Grouping nodes with crossing edges keeps outside connections (Task 3 test `group rewires crossing edges`).
- Node builder not called for unchanged nodes while dragging another (Task 2 test).

---

### Task 1: Spatial index
**Files:** Create `lib/src/controller/spatial_index.dart`; Modify `flow_controller.dart`, `flow_canvas.dart`; Test `test/spatial_index_test.dart`
**Produces:** `class SpatialIndex<T> { SpatialIndex({double cell = 256}); void clear(); void insert(T item, Rect r); Iterable<T> query(Rect r); Iterable<T> at(Offset p); }`. `FlowController.nodesIn(Rect r) → Iterable<FlowNode>`, `edgesNear(Rect r) → Iterable<FlowEdge>` (edge bounds = rect of endpoints inflated 60), rebuilt lazily on a `_dirty` flag set in every mutation path (`execute/undo/redo/moveLive/loadJson/...`). Canvas uses them for culling, `nodeAt`, `edgeAt`, `outputPortAt`, insert target, marquee, guides.
- [ ] Tests: `query returns overlapping items only`, `item spanning cells returned once`, `index follows moves and undo`. RED → GREEN → full suite.

### Task 2: Rebuild minimisation + semantics + stress
**Files:** Modify `flow_canvas.dart`; Test `test/perf_test.dart`; example stress button
**Produces:** canvas caches `Widget` per node id keyed on `(FlowNode identity, selected)`; reuses when identical. Each node wrapped in `Semantics(label: node.label, selected:, button: true)`. Example toolbar "Stress 1k" builds 1000 nodes in a 40-column grid with chain edges.
- [ ] Tests: `dragging one node rebuilds only that node` (100 nodes visible, count builder calls during 5 move frames ≤ 5 + 5), `semantics label present`, `1000 nodes: nodeAt under 1ms avg over 1000 calls`. RED → GREEN.

### Task 3: Sub-flows
**Files:** Create `lib/src/model/subflow.dart`, `lib/src/widgets/flow_breadcrumb.dart`; Modify model, controller, json, canvas; Test `test/subflow_test.dart`
**Produces:** `class SubFlow { final List<FlowNode> nodes; final List<FlowEdge> edges; }`; `FlowNode.subflow` (+ copyWith). Controller: `void groupSelection({String label = 'Sub-flow'})` (one undo step; group node at selection bbox top-left, type `'subflow'`; for each crossing edge a port on the group: inbound → `Port('in_k', left, targetPortType)`, outbound → `Port('out_k', right, sourcePortType)`; edges rewired to those ports; size `Size(200, max(68, 28*ports+20))`), `void ungroup(String id)` (one undo step; restores inner nodes offset so their bbox starts at the group position; crossing edges re-pointed to the original inner endpoints stored in group port metadata — store mapping in `SubFlow.boundary: Map<String portId, (String node, String port)>`), `void enter(String id)`, `void exit()`, `List<FlowNode> get path` (groups from root), `int get depth`. History is per level (stack). JSON encodes `subflow` recursively (`"subflow": {nodes, edges, boundary}`). Canvas: double-click a node with subflow → `enter` + `fitView`; Esc when depth>0 and nothing selected → `exit`. `FlowBreadcrumb(controller)` shows `Root › Group…`, tapping a crumb exits to that depth. ⌘G groups, ⌘⇧G ungroups. `DefaultFlowNode` draws a stacked-card shadow and `'{n} nodes'` subtitle for sub-flow nodes.
- [ ] Tests: `group rewires crossing edges`, `group is one undo step`, `ungroup restores nodes and edges`, `enter shows inner nodes; exit persists edits`, `history is per level`, `json roundtrip keeps subflow`, `double-click enters`, `breadcrumb exits`. RED → GREEN.

### Task 4: Edge labels + reconnect ghost
**Files:** Modify `edge_painter.dart`, `flow_canvas.dart`; Test `test/edge_label_test.dart`
**Produces:** labels painted at `pointOnEdge(u=0.5)` in a rounded pill (nodeColor bg, mutedText 11px), hidden in LOD. `FlowController.setEdgeLabel(String id, String? label)` (undoable via `UpdateEdge(before, after)` command). Edge being reconnected isn't painted (`EdgePainter.hiddenEdge`).
- [ ] Tests: `setEdgeLabel undoable`, `label painted` (golden-free: painter reports label count via `debugLastLabelCount`), `reconnecting edge hidden`. RED → GREEN.

### Task 5: Command palette
**Files:** Create `lib/src/widgets/flow_command_palette.dart`; Test `test/palette_test.dart`
**Produces:** `class FlowAction { final String label; final VoidCallback run; final Color? color; final String? shortcut; }`; `Future<void> showFlowCommandPalette(BuildContext, {required List<FlowAction> actions})` — dialog with search field (autofocus), filtered list (case-insensitive contains), ↑/↓ moves highlight, Enter runs, Esc closes, click runs. `List<FlowAction> defaultFlowActions(FlowController c, GlobalKey<FlowCanvasState> canvas)` → Undo, Redo, Select all, Duplicate, Group into sub-flow, Auto-layout, Fit view. Canvas param `List<FlowAction> Function()? paletteActions`; ⌘K opens palette with `defaultFlowActions + paletteActions()`.
- [ ] Tests: `filters by text`, `enter runs highlighted`, `arrow keys move`, `cmd+k opens`. RED → GREEN.

### Task 6: Release prep
**Files:** `.github/workflows/ci.yml`, `analysis_options.yaml`, dartdoc on all public API, `README.md`, `CHANGELOG.md` (0.1.0), `pubspec.yaml` (0.1.0, `screenshots:`), `doc/screenshot.png`, `docs/device-checklist.md`
- [ ] Enable `public_member_api_docs`; fix all. `flutter pub publish --dry-run` → 0 warnings. CI: analyze + test on push for package and example. Screenshot from Chrome saved to `doc/`. Device checklist for the user (iOS/Android touch: pinch, long-press connect, text field in node; desktop builds).

### Task 7: Example + verify
Example: ⌘K palette with "Add: <type>" actions, breadcrumb overlay, Group/Ungroup toolbar buttons, Stress 1k. Smoke tests: `group then enter shows inner nodes`, `palette adds node`. Build web, verify in Chrome both themes.
