import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

List<FlowNode> grid(int count, {int cols = 10}) => [
      for (var i = 0; i < count; i++)
        FlowNode(
            id: 'n$i',
            position: Offset((i % cols) * 200.0, (i ~/ cols) * 90.0),
            type: 't',
            label: 'n$i'),
    ];

void main() {
  testWidgets('dragging one node rebuilds only that node', (t) async {
    final c = FlowController(nodes: grid(40));
    var builds = 0;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FlowCanvas(
                controller: c,
                animateEdges: false,
                nodeBuilder: (_, n) {
                  builds++;
                  return Text(n.label);
                }))));
    builds = 0;
    final g = await t.startGesture(const Offset(90, 34),
        kind: PointerDeviceKind.mouse);
    for (var i = 1; i <= 5; i++) {
      await g.moveTo(Offset(90 + i * 7.0, 34 + i * 3.0));
      await t.pump();
    }
    await g.up();
    await t.pump();
    // One rebuild of the dragged node per frame (+ selection change + drop).
    expect(builds, lessThanOrEqualTo(8));
  });

  testWidgets('semantics label present', (t) async {
    final h = t.ensureSemantics();
    final c = FlowController(nodes: grid(1));
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FlowCanvas(
                controller: c,
                animateEdges: false,
                nodeBuilder: (_, n) => const SizedBox()))));
    expect(find.bySemanticsLabel('n0'), findsOneWidget);
    h.dispose();
  });

  test('1000 nodes: nodesIn point query is fast', () {
    final c = FlowController(nodes: grid(1000, cols: 40));
    c.nodesIn(Rect.zero); // build index
    final sw = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      c
          .nodesIn(Rect.fromCenter(
              center: Offset((i % 40) * 200.0 + 50, (i ~/ 40) * 90.0 + 30),
              width: 1,
              height: 1))
          .toList();
    }
    sw.stop();
    expect(sw.elapsedMicroseconds / 1000, lessThan(1000));
  });
}
