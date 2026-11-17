import 'dart:math';

import 'package:nodeflux/nodeflux.dart';

import 'demo_flow.dart';

/// Fakes executing the flow so the editor's run-state UI can be shown.
/// Real apps run their own engine and call `setStatus` / `pulseEdge`.
class RunSimulator {
  RunSimulator(
    this.c, {
    this.stepDelay = const Duration(milliseconds: 300),
    Random? random,
  }) : _rng = random ?? Random();

  final FlowController c;
  final Duration stepDelay;
  final Random _rng;
  bool running = false;

  static const errors = [
    'Timeout after 30s',
    '401 Unauthorized',
    'Rate limited',
    'Invalid JSON',
  ];

  Map<String, int> _depths() {
    final d = {for (final n in c.nodes) n.id: 0};
    for (var i = 0; i < d.length; i++) {
      var changed = false;
      for (final e in c.edges) {
        if (d[e.targetNode]! <= d[e.sourceNode]!) {
          d[e.targetNode] = d[e.sourceNode]! + 1;
          changed = true;
        }
      }
      if (!changed) break;
    }
    return d;
  }

  Future<int> run({bool injectErrors = false}) async {
    if (running) return 0;
    running = true;
    c.resetStatus();
    final depth = _depths();
    final layers = <int, List<FlowNode>>{};
    for (final n in c.nodes) {
      layers.putIfAbsent(depth[n.id]!, () => []).add(n);
    }
    for (final l in layers.keys.toList()..sort()) {
      await Future.wait(layers[l]!.map((n) => _runNode(n.id, injectErrors)));
      await Future<void>.delayed(stepDelay ~/ 2);
    }
    running = false;
    return c.nodes.where((n) => n.status == NodeStatus.error).length;
  }

  Future<void> _runNode(String id, bool injectErrors) async {
    final ups = c.edges
        .where((e) => e.targetNode == id)
        .map((e) => c.node(e.sourceNode)!);
    if (ups.any((u) => u.status != NodeStatus.success)) {
      c.setStatus(id, NodeStatus.skipped);
      return;
    }
    c.setStatus(id, NodeStatus.running);
    final n = c.node(id)!;
    final factor = n.type == 'AI Agent' ? 3.0 : 1.0 + _rng.nextDouble();
    final d = stepDelay * factor;
    await Future<void>.delayed(d);
    if (injectErrors && n.type != 'Trigger' && _rng.nextDouble() < 0.3) {
      c.setStatus(
        id,
        NodeStatus.error,
        duration: d,
        error: errors[_rng.nextInt(errors.length)],
      );
      return;
    }
    c.setStatus(id, NodeStatus.success, duration: d, output: payloadFor(n));
    for (final e in c.edges.where((e) => e.sourceNode == id)) {
      c.pulseEdge(e.id);
    }
  }
}
