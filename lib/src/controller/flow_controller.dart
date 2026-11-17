import 'package:flutter/foundation.dart';
import 'dart:ui' show Offset;

import '../model/flow_edge.dart';
import '../model/flow_node.dart';
import '../model/node_status.dart';
import 'commands.dart';

class ConnectResult {
  const ConnectResult.ok()
      : ok = true,
        reason = null;
  const ConnectResult.fail(String this.reason) : ok = false;
  final bool ok;
  final String? reason;
}

/// Holds the graph, selection, run state and undo history.
class FlowController extends ChangeNotifier {
  FlowController(
      {Iterable<FlowNode> nodes = const [],
      Iterable<FlowEdge> edges = const []}) {
    for (final n in nodes) {
      _g.nodes[n.id] = n;
    }
    for (final e in edges) {
      _g.edges[e.id] = e;
    }
  }

  static const historyLimit = 100;

  final FlowGraph _g = FlowGraph();
  final List<FlowCommand> _undo = [];
  final List<FlowCommand> _redo = [];
  final Set<String> _selected = {};
  String? _selectedEdge;
  int _edgeSeq = 0;

  /// Edge id → time a data pulse started travelling along it.
  final Map<String, DateTime> pulses = {};

  Iterable<FlowNode> get nodes => _g.nodes.values;
  Iterable<FlowEdge> get edges => _g.edges.values;
  FlowNode? node(String id) => _g.nodes[id];
  FlowEdge? edge(String id) => _g.edges[id];

  Set<String> get selectedNodes => Set.unmodifiable(_selected);
  String? get selectedEdge => _selectedEdge;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get historyLength => _undo.length;

  void execute(FlowCommand c) {
    c.apply(_g);
    _undo.add(c);
    if (_undo.length > historyLimit) _undo.removeAt(0);
    _redo.clear();
    _pruneSelection();
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    final c = _undo.removeLast()..revert(_g);
    _redo.add(c);
    _pruneSelection();
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    final c = _redo.removeLast()..apply(_g);
    _undo.add(c);
    _pruneSelection();
    notifyListeners();
  }

  void addNode(FlowNode n) => execute(AddNode(n));

  void removeSelected() {
    if (_selected.isEmpty && _selectedEdge == null) return;
    execute(BatchCommand([
      if (_selectedEdge != null) RemoveEdges({_selectedEdge!}),
      if (_selected.isNotEmpty) RemoveNodes({..._selected}),
    ]));
    _selected.clear();
    _selectedEdge = null;
    notifyListeners();
  }

  ConnectResult canConnect(
      String srcNode, String srcPort, String dstNode, String dstPort) {
    if (srcNode == dstNode) {
      return const ConnectResult.fail('Cannot connect a node to itself');
    }
    final a = _g.nodes[srcNode], b = _g.nodes[dstNode];
    if (a == null || b == null) return const ConnectResult.fail('Unknown node');
    final out = a.port(srcPort);
    final inp = b.port(dstPort);
    if (inp == null || !inp.isInput) {
      return const ConnectResult.fail('Target has no input');
    }
    if (out == null) return const ConnectResult.fail('Source has no output');
    if (_g.edges.values.any((e) =>
        e.sourceNode == srcNode &&
        e.sourcePort == srcPort &&
        e.targetNode == dstNode &&
        e.targetPort == dstPort)) {
      return const ConnectResult.fail('Already connected');
    }
    if (!inp.type.accepts(out.type)) {
      return ConnectResult.fail(
          '${out.type.name} → ${inp.type.name} not compatible');
    }
    return const ConnectResult.ok();
  }

  /// Builds the edge command for a valid connection, or null.
  AddEdge? connectCommand(
      String srcNode, String srcPort, String dstNode, String dstPort) {
    if (!canConnect(srcNode, srcPort, dstNode, dstPort).ok) return null;
    String id;
    do {
      id = 'e${++_edgeSeq}';
    } while (_g.edges.containsKey(id));
    return AddEdge(FlowEdge(
        id: id,
        sourceNode: srcNode,
        sourcePort: srcPort,
        targetNode: dstNode,
        targetPort: dstPort));
  }

  bool connect(String srcNode, String srcPort, String dstNode, String dstPort) {
    final c = connectCommand(srcNode, srcPort, dstNode, dstPort);
    if (c == null) return false;
    execute(c);
    return true;
  }

  void select(String id, {bool additive = false}) {
    if (!additive) _selected.clear();
    _selected.add(id);
    _selectedEdge = null;
    notifyListeners();
  }

  void toggleSelect(String id) {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    _selectedEdge = null;
    notifyListeners();
  }

  void selectEdge(String id) {
    _selected.clear();
    _selectedEdge = id;
    notifyListeners();
  }

  void selectAll() {
    _selected.addAll(_g.nodes.keys);
    _selectedEdge = null;
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty && _selectedEdge == null) return;
    _selected.clear();
    _selectedEdge = null;
    notifyListeners();
  }

  /// Replaces a node (matched by id), e.g. to store edited settings in
  /// [FlowNode.data]. With [record] false the change skips undo history —
  /// use that for per-keystroke edits.
  void updateNode(FlowNode node, {bool record = true}) {
    final before = _g.nodes[node.id];
    if (before == null) return;
    if (record) {
      execute(UpdateNode(before, node));
    } else {
      _g.nodes[node.id] = node;
      notifyListeners();
    }
  }

  /// Moves nodes without recording history (live drag). Commit the final
  /// positions with a [MoveNodes] command.
  void moveLive(Map<String, Offset> positions) {
    positions.forEach((id, p) {
      final n = _g.nodes[id];
      if (n != null) _g.nodes[id] = n.copyWith(position: p);
    });
    notifyListeners();
  }

  /// Updates run state. Not recorded in undo history.
  void setStatus(String id, NodeStatus status,
      {Duration? duration, String? error, Object? output}) {
    final n = _g.nodes[id];
    if (n == null) return;
    _g.nodes[id] = n.copyWith(
        status: status, duration: duration, error: error, output: output);
    notifyListeners();
  }

  void resetStatus() {
    for (final id in _g.nodes.keys.toList()) {
      _g.nodes[id] = _g.nodes[id]!.copyWith(
          status: NodeStatus.idle, duration: null, error: null, output: null);
    }
    notifyListeners();
  }

  /// Starts a data-flow pulse animation along an edge.
  void pulseEdge(String edgeId) {
    pulses[edgeId] = DateTime.now();
    notifyListeners();
  }

  void _pruneSelection() {
    _selected.removeWhere((id) => !_g.nodes.containsKey(id));
    if (_selectedEdge != null && !_g.edges.containsKey(_selectedEdge)) {
      _selectedEdge = null;
    }
  }
}
