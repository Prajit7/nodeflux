# Device checklist (manual, before 0.1.0)

Run the example: `cd example && flutter run -d <device>`.

## iOS + Android (real phone)
- [ ] Pinch to zoom is smooth; two-finger pan works
- [ ] One-finger drag on empty canvas pans; on a node moves it
- [ ] Long-press an output port (~0.4s) then drag → connection preview; drop on a node connects
- [ ] Tap in the AI Agent prompt field → keyboard opens, typing works, node does not move
- [ ] Model dropdown opens and selects
- [ ] Run → spinners, ✓ badges, dots travel along edges
- [ ] Double-tap empty canvas → add-node menu
- [ ] Group (toolbar) → Open → breadcrumb → Root
- [ ] Stress 1k → panning/zooming stays smooth (note fps from DevTools)

## macOS / Windows / Linux desktop
- [ ] ⌘/Ctrl Z, ⇧Z, A, C, V, D, X, G, ⇧G, K all work
- [ ] Trackpad two-finger pan + pinch zoom (macOS)
- [ ] Right-click empty canvas → add-node menu
- [ ] Shift-drag box selection

## Web (Chrome, Safari)
- [ ] ⌘D duplicates (Chrome may claim it as "bookmark")
- [ ] Right-click doesn't open the browser context menu
