import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

const json = PortType('json', Color(0xFF3B5BDB));

FlowNode base(
        {NodeStatus status = NodeStatus.idle, Duration? d, String? err}) =>
    FlowNode(
      id: 'a',
      position: Offset.zero,
      type: 'HTTP Request',
      label: 'Fetch orders',
      status: status,
      duration: d,
      error: err,
      ports: const [Port(id: 'out', side: PortSide.right, type: json)],
    );

Future<void> show(WidgetTester t, FlowNode n) => t.pumpWidget(MaterialApp(
      home: Center(
          child: SizedBox(
              width: 180,
              height: 68,
              child: DefaultFlowNode(node: n, accent: Colors.blue))),
    ));

void main() {
  testWidgets('idle shows label and type', (t) async {
    await show(t, base());
    expect(find.text('Fetch orders'), findsOneWidget);
    expect(find.text('HTTP Request'), findsOneWidget);
  });

  testWidgets('running shows spinner', (t) async {
    await show(t, base(status: NodeStatus.running));
    expect(find.text('running…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('success shows duration', (t) async {
    await show(t,
        base(status: NodeStatus.success, d: const Duration(milliseconds: 120)));
    expect(find.text('✓ 120ms'), findsOneWidget);
  });

  testWidgets('error shows message', (t) async {
    await show(t, base(status: NodeStatus.error, err: 'Timeout after 30s'));
    expect(find.text('✕ Timeout after 30s'), findsOneWidget);
  });

  testWidgets('skipped is faded', (t) async {
    await show(t, base(status: NodeStatus.skipped));
    expect(find.text('skipped'), findsOneWidget);
    expect(t.widget<Opacity>(find.byType(Opacity).first).opacity, 0.4);
  });

  testWidgets('edge hover shows output json', (t) async {
    final c = FlowController(nodes: [
      const FlowNode(
          id: 'a',
          position: Offset(0, 100),
          type: 't',
          label: 'A',
          ports: [Port(id: 'out', side: PortSide.right, type: json)]),
      const FlowNode(
          id: 'b',
          position: Offset(400, 100),
          type: 't',
          label: 'B',
          ports: [Port(id: 'in', side: PortSide.left, type: json)]),
    ]);
    c.connect('a', 'out', 'b', 'in');
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FlowCanvas(
                controller: c,
                animateEdges: false,
                nodeBuilder: (_, n) => Text(n.label)))));
    final g = await t.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: const Offset(700, 500));
    await g.moveTo(const Offset(290, 134));
    await t.pump();
    expect(find.text('Run the flow to see data'), findsOneWidget);
    c.setStatus('a', NodeStatus.success, output: {'x': 1});
    await g.moveTo(const Offset(291, 134));
    await t.pump();
    expect(find.textContaining('"x": 1'), findsOneWidget);
    await g.moveTo(const Offset(700, 500));
    await t.pump();
    expect(find.textContaining('"x": 1'), findsNothing);
  });

  testWidgets('child is shown under the header', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Center(
          child: SizedBox(
              width: 240,
              height: 150,
              child: DefaultFlowNode(
                  node: base(),
                  accent: Colors.blue,
                  child: const Text('body')))),
    ));
    expect(find.text('body'), findsOneWidget);
    expect(t.getTopLeft(find.text('body')).dy,
        greaterThan(t.getTopLeft(find.text('HTTP Request')).dy));
  });

  testWidgets('group node shows node count', (t) async {
    final g = base()
        .copyWith(subflow: SubFlow(nodes: [base(), base()], edges: const []));
    await show(t, g);
    expect(find.text('2 nodes'), findsOneWidget);
  });
}
