import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

const json = PortType('json', Color(0xFF3B5BDB));
const io = [Port(id: 'in', side: PortSide.left, type: json), Port(id: 'out', side: PortSide.right, type: json)];
FlowNode n(String id, Offset p) => FlowNode(id: id, position: p, type: 't', label: id, ports: io);

FlowController graph() {
  final c = FlowController(nodes: [n('a', Offset.zero), n('b', const Offset(300, 0)), n('c', const Offset(600, 0))]);
  c.connect('a', 'out', 'b', 'in');
  c.connect('b', 'out', 'c', 'in');
  return c;
}

void main() {
  test('paste remaps ids and drops external edges', () {
    final c = graph();
    c.selectNodes(['a', 'b']);
    final clip = c.copySelection()!;
    expect(clip.nodes.length, 2);
    expect(clip.edges.length, 1);
    c.paste(clip);
    expect(c.nodes.length, 5);
    expect(c.edges.length, 3);
    final pasted = c.selectedNodes;
    expect(pasted.length, 2);
    expect(pasted.intersection({'a', 'b', 'c'}), isEmpty);
    final e = c.edges.firstWhere((e) => pasted.contains(e.sourceNode));
    expect(pasted.contains(e.targetNode), isTrue);
    final copyA = c.node(pasted.firstWhere((id) => c.node(id)!.label == 'a'))!;
    expect(copyA.position, const Offset(30, 30));
  });

  test('paste twice offsets again', () {
    final c = graph();
    c.selectNodes(['a']);
    final clip = c.copySelection()!;
    c.paste(clip);
    c.paste(clip);
    final copies = c.nodes.where((x) => x.label == 'a' && x.id != 'a').map((x) => x.position).toSet();
    expect(copies, {const Offset(30, 30), const Offset(60, 60)});
    expect(c.nodes.map((x) => x.id).toSet().length, c.nodes.length);
  });

  test('paste is one undo step', () {
    final c = graph();
    c.selectNodes(['a', 'b']);
    c.paste(c.copySelection()!);
    c.undo();
    expect(c.nodes.length, 3);
    expect(c.edges.length, 2);
  });

  test('copy with nothing selected returns null', () {
    expect(graph().copySelection(), isNull);
  });

  testWidgets('cmd+d duplicates, cmd+c/cmd+v pastes', (t) async {
    final c = graph();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: FlowCanvas(controller: c, animateEdges: false, nodeBuilder: (_, n) => Text(n.label)))));
    await t.tapAt(const Offset(90, 34));
    Future<void> cmd(LogicalKeyboardKey k) async {
      await t.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await t.sendKeyEvent(k);
      await t.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await t.pump();
    }
    await cmd(LogicalKeyboardKey.keyD);
    expect(c.nodes.length, 4);
    await cmd(LogicalKeyboardKey.keyC);
    await cmd(LogicalKeyboardKey.keyV);
    expect(c.nodes.length, 5);
    await cmd(LogicalKeyboardKey.keyX);
    expect(c.nodes.length, 4);
  });
}
