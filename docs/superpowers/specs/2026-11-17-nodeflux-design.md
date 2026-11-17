# nodeflux — design

**Date:** 2026-11-17 · **Status:** draft, awaiting approval
**Name:** `nodeflux` (free on pub.dev as of 2026-11-17). Says "node editor" + "data in motion", short, searchable.

## Intent
A React Flow–class node/flow editor for Flutter that beats `vyuh_node_flow` (0.32.0). Primary audience: teams building **workflow / automation / AI-agent builders** in Flutter; general enough for diagrams. The interactive HTML spike (`../flow_editor_demo.html`) is the reference for behaviour and feel.

## Goals (v1)
- Infinite canvas: pan, zoom (wheel/trackpad/pinch), animated fit-view, dot/line/none backgrounds.
- Nodes are **any Flutter widget**; built-in default node look matching the spike.
- Ports/handles with **types**; connection validation with a reason shown while dragging; refused drops give feedback.
- Edge types: bezier, smoothstep, step, straight + custom painter; arrow markers; labels; **animated flowing dashes** (toggle); selection & delete.
- **Run-state API:** per-node status (idle/running/success/error/skipped, duration, error text) rendered by default nodes; **flow pulse** on edges (`controller.pulseEdge(id)`); per-edge data preview on hover.
- Drop connection on empty space → callback to show a **compatible-node picker** (default picker provided).
- Selection: click, shift-click, marquee, select-all; move group; delete.
- **Undo/redo** via command history (every mutation is a command).
- **Smart alignment guides** + optional grid snap.
- **Sub-flows:** group selection into a node, enter/exit with breadcrumb.
- **Command palette** (⌘K) widget with built-in + user actions.
- Minimap, controls, stats overlay; viewport culling + LOD; 1k nodes smooth on desktop/web, target 5k.
- Simple layered **auto-layout**.
- JSON serialization.
- Keyboard: ⌘Z/⌘⇧Z/⌘A/⌘G/⌘K/Del/Esc.
- All 6 platforms, light & dark themes.

## Non-goals (v1)
Actually executing flows (the app does that; we only display state), real-time collaboration, orthogonal edge routing, PNG/SVG export, advanced layouts. (All post-v1.)

## Anti-goals
- Forcing a state-management library on users (no MobX/Riverpod/Bloc dependency).
- A generic-heavy API that's hard to start with — a "hello flow" must fit in ~15 lines.
- Dropping below 60fps on a 200-node flow on a mid-range phone.

## Constraints
- Core depends only on Flutter SDK (+ `collection`/`vector_math` if needed). No `http`, no codegen.
- Dart ≥ 3.5, Flutter stable. MIT license.
- Mobile/touch is first-class: long-press to start connections, pinch zoom.

## Approaches considered
1. **Widget-per-node in a custom `RenderObject` canvas + `CustomPainter` for edges/background (chosen).** Nodes stay real widgets (users' custom UI, text fields, hit-testing), we cull off-screen ones, edges painted in one layer with cached paths. Best balance of flexibility and speed.
2. **Pure `CustomPainter` for everything.** Fastest, but nodes can't be arbitrary widgets — kills the main selling point.
3. **`InteractiveViewer` + `Stack` of `Positioned`.** Quickest to write, but no culling, poor at scale, gesture conflicts. This is roughly what weaker packages do.

Picked in conversation: user chose to prototype in HTML first, then build the real package; approach 1 is my call.

## Design (decided)
- **Model:** immutable `FlowNode<T>` (id, position, size, type, data, ports, status), `FlowEdge` (id, source/target node+port, type, label, data), `Port` (id, side, dataType). `T` is optional user data — default API is non-generic-friendly.
- **Controller:** `FlowController extends ChangeNotifier`. All mutations go through `FlowCommand`s → undo/redo stack and an `onChange` op stream (future collaboration hook).
- **Widgets:** `FlowCanvas(controller, nodeBuilder, edgeStyle, ...)`, `FlowMinimap`, `FlowControls`, `FlowCommandPalette`, `FlowBreadcrumb`, `DefaultFlowNode`.
- **Rendering:** custom `RenderBox` lays out only visible nodes (spatial grid index); edges/background/guides in `CustomPainter`s driven by a single ticker for animation.
- **Theme:** `FlowTheme` (ThemeExtension) with light/dark defaults matching the spike.
- **Repo layout:** single package `nodeflux/` with `lib/src/{model,controller,render,widgets,layout,serialization}`, `example/` (Flutter web demo mirroring the spike), `test/`, `benchmark/`.

## Left to the builder
Exact class/method names beyond the above, spatial index choice, test structure, milestone ordering inside the plan.

## Post-v1 ideas
Edge routing around nodes, insert-node-on-edge, sticky notes/frames, PNG/SVG export, read-only viewer, collaboration adapter, flow diffing, radial touch menu.
