import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

const json = PortType('json', Color(0xFF3B5BDB));

FlowNode n(String id, Offset p) => FlowNode(
      id: id,
      position: p,
      type: 't',
      label: id,
      ports: const [
        Port(id: 'in', side: PortSide.left, type: json),
        Port(id: 'out', side: PortSide.right, type: json),
      ],
    );

Future<(FlowController, FlowViewport)> pumpCanvas(
    WidgetTester t, List<FlowNode> nodes) async {
  final c = FlowController(nodes: nodes);
  final v = FlowViewport();
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: FlowCanvas(
        controller: c,
        viewport: v,
        animateEdges: false,
        nodeBuilder: (_, node) => Center(child: Text(node.label)),
      ),
    ),
  ));
  return (c, v);
}

void main() {
  testWidgets('renders only visible nodes', (t) async {
    await pumpCanvas(t, [
      n('near', const Offset(50, 50)),
      n('far', const Offset(10000, 10000))
    ]);
    expect(find.text('near'), findsOneWidget);
    expect(find.text('far'), findsNothing);
  });

  testWidgets('drag node moves it and creates one history entry', (t) async {
    final (c, _) = await pumpCanvas(t, [n('a', const Offset(100, 100))]);
    await t.dragFrom(const Offset(190, 134), const Offset(60, 30));
    await t.pump();
    expect(c.node('a')!.position, const Offset(160, 130));
    expect(c.historyLength, 1);
    expect(c.selectedNodes, {'a'});
  });

  testWidgets('tap does not create history', (t) async {
    final (c, _) = await pumpCanvas(t, [n('a', const Offset(100, 100))]);
    await t.tapAt(const Offset(190, 134));
    await t.pump();
    expect(c.historyLength, 0);
    expect(c.selectedNodes, {'a'});
  });

  testWidgets('tap empty clears selection', (t) async {
    final (c, _) = await pumpCanvas(t, [n('a', const Offset(100, 100))]);
    c.select('a');
    await t.tapAt(const Offset(600, 500));
    await t.pump();
    expect(c.selectedNodes, isEmpty);
  });

  testWidgets('drag empty pans viewport', (t) async {
    final (_, v) = await pumpCanvas(t, [n('a', const Offset(100, 100))]);
    await t.dragFrom(const Offset(600, 500), const Offset(-100, -40));
    await t.pump();
    expect(v.offset, const Offset(-100, -40));
  });

  testWidgets('delete key removes selected', (t) async {
    final (c, _) = await pumpCanvas(t, [n('a', const Offset(100, 100))]);
    await t.tapAt(const Offset(190, 134));
    await t.sendKeyEvent(LogicalKeyboardKey.delete);
    await t.pump();
    expect(c.nodes, isEmpty);
  });

  testWidgets('cmd+z undoes move', (t) async {
    final (c, _) = await pumpCanvas(t, [n('a', const Offset(100, 100))]);
    await t.dragFrom(const Offset(190, 134), const Offset(60, 30));
    await t.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await t.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await t.pump();
    expect(c.node('a')!.position, const Offset(100, 100));
  });

  testWidgets('scroll zooms around cursor', (t) async {
    final (_, v) = await pumpCanvas(t, [n('a', const Offset(100, 100))]);
    const at = Offset(300, 200);
    final before = v.toWorld(at);
    t.binding.handlePointerEvent(
        const PointerScrollEvent(position: at, scrollDelta: Offset(0, -200)));
    await t.pump();
    expect(v.zoom, greaterThan(1));
    expect((v.toWorld(at) - before).distance, lessThan(1e-6));
  });

  testWidgets('tap edge selects it', (t) async {
    final (c, _) = await pumpCanvas(
        t, [n('a', const Offset(0, 100)), n('b', const Offset(400, 100))]);
    c.connect('a', 'out', 'b', 'in');
    await t.pump();
    await t.tapAt(const Offset(290, 134));
    await t.pump();
    expect(c.selectedEdge, c.edges.first.id);
  });

  testWidgets('fitView animates to show all nodes', (t) async {
    final key = GlobalKey<FlowCanvasState>();
    final c = FlowController(nodes: [
      n('a', const Offset(2000, 2000)),
      n('b', const Offset(2400, 2200))
    ]);
    final v = FlowViewport();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FlowCanvas(
                key: key,
                controller: c,
                viewport: v,
                animateEdges: false,
                nodeBuilder: (_, node) => Text(node.label)))));
    key.currentState!.fitView();
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('double-click and right-click on empty canvas call onCanvasMenu',
      (t) async {
    final c = FlowController(nodes: [n('a', const Offset(100, 100))]);
    final hits = <Offset>[];
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FlowCanvas(
      controller: c,
      animateEdges: false,
      nodeBuilder: (_, node) => Text(node.label),
      onCanvasMenu: (ctx, world) => hits.add(world),
    ))));
    await t.tapAt(const Offset(500, 400), kind: PointerDeviceKind.mouse);
    await t.pump(const Duration(milliseconds: 50));
    await t.tapAt(const Offset(500, 400), kind: PointerDeviceKind.mouse);
    await t.pump();
    expect(hits, [const Offset(500, 400)]);
    await t.tapAt(const Offset(600, 300),
        buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
    await t.pump();
    expect(hits.last, const Offset(600, 300));
    // Double-click on a node does not open the menu.
    await t.tapAt(const Offset(190, 134), kind: PointerDeviceKind.mouse);
    await t.pump(const Duration(milliseconds: 50));
    await t.tapAt(const Offset(190, 134), kind: PointerDeviceKind.mouse);
    await t.pump();
    expect(hits.length, 2);
  });
}
