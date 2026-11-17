import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

const json = PortType('json', Color(0xFF3B5BDB));
const io = [
  Port(id: 'in', side: PortSide.left, type: json),
  Port(id: 'out', side: PortSide.right, type: json)
];
FlowNode n(String id, double x) =>
    FlowNode(id: id, position: Offset(x, 100), type: 't', label: id, ports: io);

/// a → b → c → d ; group {b, c}
FlowController chain() {
  final c =
      FlowController(nodes: [n('a', 0), n('b', 250), n('c', 500), n('d', 750)]);
  c.connect('a', 'out', 'b', 'in');
  c.connect('b', 'out', 'c', 'in');
  c.connect('c', 'out', 'd', 'in');
  c.selectNodes(['b', 'c']);
  return c;
}

void main() {
  test('group rewires crossing edges', () {
    final c = chain()..groupSelection();
    expect(c.nodes.map((x) => x.id).toSet().containsAll({'a', 'd'}), isTrue);
    expect(c.nodes.length, 3);
    final g = c.nodes.firstWhere((x) => x.subflow != null);
    expect(g.position, const Offset(250, 100));
    expect(g.subflow!.nodes.map((x) => x.id).toSet(), {'b', 'c'});
    expect(g.subflow!.edges.length, 1);
    expect(c.edges.length, 2);
    expect(c.edges.any((e) => e.sourceNode == 'a' && e.targetNode == g.id),
        isTrue);
    expect(c.edges.any((e) => e.sourceNode == g.id && e.targetNode == 'd'),
        isTrue);
    expect(g.inputs.single.type, json);
    expect(g.outputs.single.type, json);
    expect(c.selectedNodes, {g.id});
  });

  test('group is one undo step', () {
    final c = chain();
    final h = c.historyLength;
    c.groupSelection();
    expect(c.historyLength, h + 1);
    c.undo();
    expect(c.nodes.length, 4);
    expect(c.edges.length, 3);
  });

  test('ungroup restores nodes and edges', () {
    final c = chain()..groupSelection();
    final g = c.nodes.firstWhere((x) => x.subflow != null).id;
    c.ungroup(g);
    expect(c.nodes.map((x) => x.id).toSet(), {'a', 'b', 'c', 'd'});
    expect(c.edges.length, 3);
    expect(
        c.edges.any((e) => e.sourceNode == 'a' && e.targetNode == 'b'), isTrue);
    expect(
        c.edges.any((e) => e.sourceNode == 'c' && e.targetNode == 'd'), isTrue);
    expect(c.node('b')!.position, const Offset(250, 100));
  });

  test('enter shows inner nodes; exit persists edits', () {
    final c = chain()..groupSelection();
    final g = c.nodes.firstWhere((x) => x.subflow != null).id;
    c.enter(g);
    expect(c.depth, 1);
    expect(c.path.single.id, g);
    expect(c.nodes.map((x) => x.id).toSet(), {'b', 'c'});
    c.addNode(n('x', 900));
    c.exit();
    expect(c.depth, 0);
    expect(c.node(g)!.subflow!.nodes.map((x) => x.id), contains('x'));
  });

  test('history is per level', () {
    final c = chain()..groupSelection();
    final g = c.nodes.firstWhere((x) => x.subflow != null).id;
    c.enter(g);
    expect(c.canUndo, isFalse);
    c.addNode(n('x', 900));
    c.exit();
    c.undo(); // undoes the group, not the inner add
    expect(c.nodes.length, 4);
  });

  test('json roundtrip keeps subflow', () {
    final c = chain()..groupSelection();
    final text = jsonEncode(c.toJson());
    final r = FlowController.fromJson(jsonDecode(text) as Map<String, Object?>,
        portTypes: {'json': json});
    final g = r.nodes.firstWhere((x) => x.subflow != null);
    expect(g.subflow!.nodes.length, 2);
    r.ungroup(g.id);
    expect(r.edges.length, 3);
  });

  Future<FlowController> pumpGrouped(WidgetTester t) async {
    final c = chain()..groupSelection();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      FlowBreadcrumb(controller: c),
      Expanded(
          child: FlowCanvas(
              controller: c,
              animateEdges: false,
              nodeBuilder: (_, n) => Text(n.label))),
    ]))));
    return c;
  }

  testWidgets('double-click enters', (t) async {
    final c = await pumpGrouped(t);
    final at = t.getCenter(find.text('Sub-flow'));
    await t.tapAt(at, kind: PointerDeviceKind.mouse);
    await t.pump(const Duration(milliseconds: 50));
    await t.tapAt(at, kind: PointerDeviceKind.mouse);
    await t.pump(const Duration(milliseconds: 500));
    expect(c.depth, 1);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('breadcrumb exits, Esc exits', (t) async {
    final c = await pumpGrouped(t);
    c.enter(c.nodes.firstWhere((x) => x.subflow != null).id);
    await t.pump();
    expect(find.text('Root'), findsOneWidget);
    await t.tap(find.text('Root'));
    await t.pump();
    expect(c.depth, 0);
    c.enter(c.nodes.firstWhere((x) => x.subflow != null).id);
    await t.pump();
    await t.tapAt(const Offset(700, 500));
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(c.depth, 0);
  });
}
