import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

const json = PortType('json', Color(0xFF3B5BDB));
const text = PortType('text', Color(0xFFE67700));

FlowNode n(String id, Offset p, {PortType inp = json, PortType out = json}) =>
    FlowNode(
      id: id,
      position: p,
      type: 't',
      label: id,
      ports: [
        Port(id: 'in', side: PortSide.left, type: inp),
        Port(id: 'out', side: PortSide.right, type: out),
      ],
    );

ConnectResult? rejected;

Future<FlowController> pump(WidgetTester t, List<FlowNode> nodes,
    {Future<FlowNode?> Function(BuildContext,
            {required FlowNode source,
            required Port port,
            required Offset worldPosition})?
        onEmpty}) async {
  rejected = null;
  final c = FlowController(nodes: nodes);
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: FlowCanvas(
        controller: c,
        animateEdges: false,
        nodeBuilder: (_, node) => Text(node.label),
        onConnectRejected: (r) => rejected = r,
        onConnectEndEmpty: onEmpty,
      ),
    ),
  ));
  return c;
}

// a's output port is at (180, 134); b's body centre at (490, 134).
const aOut = Offset(180, 134), bBody = Offset(490, 134);

Future<void> mouseDrag(WidgetTester t, Offset from, Offset to) async {
  final g = await t.startGesture(from, kind: PointerDeviceKind.mouse);
  await g.moveTo((from + to) / 2);
  await t.pump();
  await g.moveTo(to);
  await t.pump();
  await g.up();
  await t.pump();
}

void main() {
  testWidgets('drag output to compatible input creates edge', (t) async {
    final c = await pump(
        t, [n('a', const Offset(0, 100)), n('b', const Offset(400, 100))]);
    await mouseDrag(t, aOut, bBody);
    expect(c.edges.length, 1);
    expect(c.edges.first.sourceNode, 'a');
    expect(c.edges.first.targetNode, 'b');
    expect(c.node('a')!.position, const Offset(0, 100)); // not moved
  });

  testWidgets('shows type tooltip while hovering a target', (t) async {
    await pump(t, [
      n('a', const Offset(0, 100), out: text),
      n('b', const Offset(400, 100))
    ]);
    final g = await t.startGesture(aOut, kind: PointerDeviceKind.mouse);
    await g.moveTo(bBody);
    await t.pump();
    expect(find.text('text → json not compatible'), findsOneWidget);
    await g.up();
    await t.pump();
    expect(find.text('text → json not compatible'), findsNothing);
  });

  testWidgets('incompatible drop calls onConnectRejected with reason',
      (t) async {
    final c = await pump(t, [
      n('a', const Offset(0, 100), out: text),
      n('b', const Offset(400, 100))
    ]);
    await mouseDrag(t, aOut, bBody);
    expect(c.edges, isEmpty);
    expect(rejected?.reason, 'text → json not compatible');
  });

  testWidgets(
      'drop on empty calls onConnectEndEmpty and adds node+edge, single undo removes both',
      (t) async {
    Offset? at;
    final c = await pump(t, [n('a', const Offset(0, 100))], onEmpty: (ctx,
        {required source, required port, required worldPosition}) async {
      at = worldPosition;
      return n('new', worldPosition);
    });
    await mouseDrag(t, aOut, const Offset(500, 400));
    await t.pump();
    expect(at, const Offset(500, 400));
    expect(c.nodes.length, 2);
    expect(c.edges.single.targetNode, 'new');
    c.undo();
    expect(c.nodes.length, 1);
    expect(c.edges, isEmpty);
  });

  testWidgets('long-press starts connection on touch', (t) async {
    final c = await pump(
        t, [n('a', const Offset(0, 100)), n('b', const Offset(400, 100))]);
    final g = await t.startGesture(aOut);
    await t.pump(const Duration(milliseconds: 500));
    await g.moveTo(bBody);
    await t.pump();
    await g.up();
    await t.pump();
    expect(c.edges.length, 1);
  });

  testWidgets('NodePicker lists only compatible templates', (t) async {
    const templates = [
      NodeTemplate(
          type: 'A',
          label: 'Takes json',
          color: Colors.blue,
          ports: [Port(id: 'in', side: PortSide.left, type: json)]),
      NodeTemplate(
          type: 'B',
          label: 'Takes text',
          color: Colors.orange,
          ports: [Port(id: 'in', side: PortSide.left, type: text)]),
    ];
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (ctx) {
      return TextButton(
          onPressed: () => showNodePicker(ctx,
              templates: templates,
              from: json,
              screenPosition: const Offset(100, 100)),
          child: const Text('open'));
    }))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Takes json'), findsOneWidget);
    expect(find.text('Takes text'), findsNothing);
  });

  testWidgets('NodePicker without a type lists all templates', (t) async {
    const templates = [
      NodeTemplate(type: 'A', label: 'Starter', color: Colors.blue),
      NodeTemplate(
          type: 'B',
          label: 'Takes text',
          color: Colors.orange,
          ports: [Port(id: 'in', side: PortSide.left, type: text)]),
    ];
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (ctx) {
      return TextButton(
          onPressed: () => showNodePicker(ctx,
              templates: templates, screenPosition: const Offset(100, 100)),
          child: const Text('open'));
    }))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Starter'), findsOneWidget);
    expect(find.text('Takes text'), findsOneWidget);
  });
}
