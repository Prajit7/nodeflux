import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

void main() {
  const other = Rect.fromLTWH(100, 100, 180, 68);

  test('snaps left edges within threshold', () {
    final r = computeGuides(const Rect.fromLTWH(104, 300, 180, 68), [other],
        threshold: 6);
    expect(r.delta, const Offset(-4, 0));
    expect(r.lines.single.axis, Axis.vertical);
    expect(r.lines.single.at, 100);
  });

  test('centre alignment', () {
    // centre y of other = 134; moving height 40 at y=112 → centre 132.
    final r = computeGuides(const Rect.fromLTWH(500, 112, 100, 40), [other],
        threshold: 6);
    expect(r.delta, const Offset(0, 2));
    expect(r.lines.single.axis, Axis.horizontal);
    expect(r.lines.single.at, 134);
  });

  test('nothing beyond threshold', () {
    final r = computeGuides(const Rect.fromLTWH(120, 300, 50, 50), [other],
        threshold: 6);
    expect(r.delta, Offset.zero);
    expect(r.lines, isEmpty);
  });

  test('picks nearest candidate', () {
    final r = computeGuides(const Rect.fromLTWH(103, 300, 180, 68),
        [other, const Rect.fromLTWH(101, 600, 10, 10)],
        threshold: 6);
    expect(r.delta.dx, -2);
  });

  Future<FlowController> pump(WidgetTester t,
      {bool guides = true, bool grid = false}) async {
    final c = FlowController(nodes: [
      const FlowNode(
          id: 'a', position: Offset(100, 100), type: 't', label: 'a'),
      const FlowNode(
          id: 'b', position: Offset(400, 300), type: 't', label: 'b'),
      const FlowNode(
          id: 'c', position: Offset(103, 500), type: 't', label: 'c'),
    ]);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FlowCanvas(
                controller: c,
                animateEdges: false,
                snapToGuides: guides,
                snapToGrid: grid,
                nodeBuilder: (_, n) => Text(n.label)))));
    return c;
  }

  Future<void> mouseDrag(WidgetTester t, Offset from, Offset to) async {
    final g = await t.startGesture(from, kind: PointerDeviceKind.mouse);
    await g.moveTo(to);
    await t.pump();
    await g.up();
    await t.pump();
  }

  testWidgets('dragging snaps to guide', (t) async {
    final c = await pump(t);
    await mouseDrag(
        t, const Offset(490, 334), const Offset(193, 334)); // b to x=103
    expect(c.node('b')!.position.dx, anyOf(100, 103));
  });

  testWidgets('ignores selected nodes', (t) async {
    final c = await pump(t);
    // select a and b; drag b so its left lands 2px from a's left: a moves too,
    // so a must not be a guide target — but c (x=103) is.
    await t.tapAt(const Offset(190, 134));
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.tapAt(const Offset(490, 334));
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await mouseDrag(
        t, const Offset(490, 334), const Offset(192, 334)); // b.x → 102
    expect(c.node('b')!.position.dx, 103);
  });

  testWidgets('grid snap rounds position', (t) async {
    final c = await pump(t, guides: false, grid: true);
    await mouseDrag(t, const Offset(490, 334), const Offset(497, 341));
    expect(c.node('b')!.position, const Offset(400, 300));
    await mouseDrag(t, const Offset(490, 334), const Offset(503, 346));
    expect(c.node('b')!.position, const Offset(420, 320));
  });
}
