import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

void main() {
  late FlowController c;
  late FlowViewport v;
  final key = GlobalKey<FlowCanvasState>();

  Future<void> pump(WidgetTester t) async {
    c = FlowController(nodes: const [
      FlowNode(id: 'a', position: Offset(0, 0), type: 't', label: 'a'),
      FlowNode(id: 'b', position: Offset(1000, 600), type: 't', label: 'b'),
    ]);
    v = FlowViewport();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          FlowCanvas(
              key: key,
              controller: c,
              viewport: v,
              animateEdges: false,
              nodeBuilder: (_, n) => Text(n.label)),
          Positioned(
              right: 10,
              bottom: 10,
              child: FlowMinimap(
                  key: const Key('mini'),
                  controller: c,
                  viewport: v,
                  canvas: key)),
          Positioned(
              left: 10,
              bottom: 10,
              child: FlowControls(canvas: key, viewport: v)),
          Positioned(
              left: 10, top: 10, child: FlowStats(controller: c, viewport: v)),
        ]),
      ),
    ));
  }

  testWidgets('stats text', (t) async {
    await pump(t);
    expect(find.text('2 nodes · 0 edges · 100%'), findsOneWidget);
  });

  testWidgets('zoom in button zooms 1.2x', (t) async {
    await pump(t);
    await t.tap(find.byTooltip('Zoom in'));
    await t.pump(const Duration(milliseconds: 500));
    expect(v.zoom, closeTo(1.2, 1e-9));
    await t.tap(find.byTooltip('Zoom out'));
    await t.pump(const Duration(milliseconds: 500));
    expect(v.zoom, closeTo(1.0, 1e-9));
  });

  testWidgets('minimap tap recentres viewport', (t) async {
    await pump(t);
    final mini = find.byKey(const Key('mini'));
    // Bottom-right of the minimap is near node b.
    final br = t.getBottomRight(mini) - const Offset(30, 30);
    await t.tapAt(br);
    await t.pump();
    final centre = v.toWorld(const Offset(400, 300));
    expect(centre.dx, greaterThan(600));
    expect(centre.dy, greaterThan(300));
  });

  testWidgets('centerOn puts world point at view centre', (t) async {
    await pump(t);
    key.currentState!.centerOn(const Offset(500, 500));
    final c0 = v.toWorld(const Offset(400, 300));
    expect(c0.dx, closeTo(500, 1e-6));
    expect(c0.dy, closeTo(500, 1e-6));
  });
}
