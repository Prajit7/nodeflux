import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Axis, Offset, Rect, Size;

import '../model/flow_edge.dart';
import '../model/flow_node.dart';
import '../model/node_status.dart';
import '../layout/layered_layout.dart';
import '../model/port.dart';
import '../model/subflow.dart';
import '../serialization/flow_json.dart';
import 'clipboard.dart';
import 'commands.dart';
import 'spatial_index.dart';

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

  /// Loads a graph saved with [toJson]. See [decodeFlow].
  factory FlowController.fromJson(Map<String, Object?> json,
      {required Map<String, PortType> portTypes,
      Object? Function(Object? raw)? decodeData}) {
    final (nodes, edges) =
        decodeFlow(json, portTypes: portTypes, decodeData: decodeData);
    return FlowController(nodes: nodes, edges: edges);
  }

  /// Saves the graph (not run state or history). See [encodeFlow].
  Map<String, Object?> toJson({Object? Function(Object? data)? encodeData}) =>
      encodeFlow(nodes, edges, encodeData: encodeData);

  /// Replaces the whole graph with one saved by [toJson]; clears
  /// selection, run state and undo history.
  void loadJson(Map<String, Object?> json,
      {required Map<String, PortType> portTypes,
      Object? Function(Object? raw)? decodeData}) {
    final (nodes, edges) =
        decodeFlow(json, portTypes: portTypes, decodeData: decodeData);
    _g.nodes
      ..clear()
      ..addEntries(nodes.map((n) => MapEntry(n.id, n)));
    _g.edges
      ..clear()
      ..addEntries(edges.map((e) => MapEntry(e.id, e)));
    _levels.clear();
    _undo.clear();
    _redo.clear();
    _selected.clear();
    _selectedEdge = null;
    pulses.clear();
    notifyListeners();
  }

  static const historyLimit = 100;

  FlowGraph _g = FlowGraph();
  List<FlowCommand> _undo = [];
  List<FlowCommand> _redo = [];

  /// Parent levels while inside sub-flows: (graph, undo, redo, group id).
  final List<(FlowGraph, List<FlowCommand>, List<FlowCommand>, String)>
      _levels = [];
  final Set<String> _selected = {};
  String? _selectedEdge;
  int _edgeSeq = 0;

  /// Edge id → time a data pulse started travelling along it.
  final Map<String, DateTime> pulses = {};

  final SpatialIndex<String> _nodeIndex = SpatialIndex();
  final SpatialIndex<String> _edgeIndex = SpatialIndex();
  bool _indexDirty = true;
  final Map<String, int> _z = {};

  /// Paint order of a node (higher = on top).
  int zOf(String id) {
    _reindex();
    return _z[id] ?? -1;
  }

  @override
  void notifyListeners() {
    _indexDirty = true;
    super.notifyListeners();
  }

  void _reindex() {
    if (!_indexDirty) return;
    _indexDirty = false;
    _nodeIndex.clear();
    _edgeIndex.clear();
    _z.clear();
    var z = 0;
    for (final n in _g.nodes.values) {
      _z[n.id] = z++;
      // Inflate so ports sitting on the node border are found too.
      _nodeIndex.insert(n.id, n.rect.inflate(12));
    }
    for (final e in _g.edges.values) {
      final a = _g.nodes[e.sourceNode], b = _g.nodes[e.targetNode];
      if (a == null || b == null) continue;
      // Bezier/step curves bulge sideways by up to ~40% of the horizontal
      // distance (backwards edges), so pad generously.
      final pad = a.size.width / 2 +
          60 +
          (b.rect.center.dx - a.rect.center.dx).abs() * 0.4;
      _edgeIndex.insert(
          e.id, Rect.fromPoints(a.rect.center, b.rect.center).inflate(pad));
    }
  }

  /// Nodes whose bounds (plus a 12px port margin) overlap [r].
  Iterable<FlowNode> nodesIn(Rect r) {
    _reindex();
    return _nodeIndex.query(r).map((id) => _g.nodes[id]).whereType<FlowNode>();
  }

  /// Edges whose endpoint bounds overlap [r]; candidates for hit-testing.
  Iterable<FlowEdge> edgesNear(Rect r) {
    _reindex();
    return _edgeIndex.query(r).map((id) => _g.edges[id]).whereType<FlowEdge>();
  }

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

  String _freshEdgeId() {
    String id;
    do {
      id = 'e${++_edgeSeq}';
    } while (_g.edges.containsKey(id));
    return id;
  }

  /// Moves the target end of [edgeId] to [dstNode]/[dstPort]; null if the
  /// new connection is invalid.
  FlowCommand? reconnectCommand(String edgeId, String dstNode, String dstPort) {
    final e = _g.edges.remove(edgeId);
    if (e == null) return null;
    final ok = canConnect(e.sourceNode, e.sourcePort, dstNode, dstPort).ok;
    _g.edges[edgeId] = e;
    if (!ok) return null;
    return BatchCommand([
      RemoveEdges({edgeId}),
      AddEdge(FlowEdge(
          id: edgeId,
          sourceNode: e.sourceNode,
          sourcePort: e.sourcePort,
          targetNode: dstNode,
          targetPort: dstPort,
          label: e.label)),
    ]);
  }

  /// Splices node [nodeId] into [edgeId] (A→B becomes A→N→B) using N's
  /// first compatible input and output; null if N can't sit there.
  FlowCommand? insertOnEdgeCommand(String edgeId, String nodeId) {
    final e = _g.edges[edgeId];
    final n = _g.nodes[nodeId];
    if (e == null || n == null || e.touches(nodeId)) return null;
    final srcType = _g.nodes[e.sourceNode]?.port(e.sourcePort)?.type;
    final dstType = _g.nodes[e.targetNode]?.port(e.targetPort)?.type;
    if (srcType == null || dstType == null) return null;
    final input = n.inputs.where((p) => p.type.accepts(srcType)).firstOrNull;
    final output = n.outputs.where((p) => dstType.accepts(p.type)).firstOrNull;
    if (input == null || output == null) return null;
    return BatchCommand([
      RemoveEdges({edgeId}),
      AddEdge(FlowEdge(
          id: _freshEdgeId(),
          sourceNode: e.sourceNode,
          sourcePort: e.sourcePort,
          targetNode: nodeId,
          targetPort: input.id)),
      AddEdge(FlowEdge(
          id: _freshEdgeId(),
          sourceNode: nodeId,
          sourcePort: output.id,
          targetNode: e.targetNode,
          targetPort: e.targetPort)),
    ]);
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

  void selectNodes(Iterable<String> ids, {bool additive = false}) {
    if (!additive) _selected.clear();
    _selected.addAll(ids.where(_g.nodes.containsKey));
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

  /// Last clip copied with [copySelection] (used by ⌘V).
  FlowClipboard? clipboard;
  int _pasteSeq = 0;

  /// Copies selected nodes and the edges between them.
  FlowClipboard? copySelection() {
    if (_selected.isEmpty) return null;
    final nodes = [for (final id in _selected) _g.nodes[id]!];
    final edges = _g.edges.values
        .where((e) =>
            _selected.contains(e.sourceNode) &&
            _selected.contains(e.targetNode))
        .toList();
    return clipboard = FlowClipboard(nodes, edges);
  }

  /// Adds copies of [clip] with fresh ids, offset by [offset] × paste count,
  /// as one undo step, and selects them.
  void paste(FlowClipboard clip, {Offset offset = const Offset(30, 30)}) {
    if (clip.nodes.isEmpty) return;
    clip.pasteCount++;
    final delta = offset * clip.pasteCount.toDouble();
    String fresh(String old) {
      String id;
      do {
        id = '${old}_${++_pasteSeq}';
      } while (_g.nodes.containsKey(id) || _g.edges.containsKey(id));
      return id;
    }

    final ids = {for (final n in clip.nodes) n.id: fresh(n.id)};
    execute(BatchCommand([
      for (final n in clip.nodes) AddNode(cloneNode(n, ids[n.id]!, delta)),
      for (final e in clip.edges)
        AddEdge(FlowEdge(
          id: fresh(e.id),
          sourceNode: ids[e.sourceNode]!,
          sourcePort: e.sourcePort,
          targetNode: ids[e.targetNode]!,
          targetPort: e.targetPort,
          label: e.label,
        )),
    ]));
    selectNodes(ids.values);
  }

  void duplicateSelection() {
    final c = copySelection();
    if (c != null) paste(c);
  }

  void cutSelection() {
    if (copySelection() != null) removeSelected();
  }

  /// Sets or clears the label drawn at an edge's midpoint (undoable).
  void setEdgeLabel(String id, String? label) {
    final e = _g.edges[id];
    if (e == null || e.label == label) return;
    execute(UpdateEdge(e, e.copyWith(label: label)));
  }

  // ------------------------------------------------------------- sub-flows

  /// How many sub-flows deep the editor currently is (0 = root).
  int get depth => _levels.length;

  /// Group nodes from the root down to the current level.
  List<FlowNode> get path => [
        for (final (g, _, _, id) in _levels) g.nodes[id]!,
      ];

  String _freshId(String base, bool Function(String) taken) {
    if (!taken(base)) return base;
    var i = 2;
    while (taken('${base}_$i')) {
      i++;
    }
    return '${base}_$i';
  }

  /// Collapses the selected nodes into one group node (one undo step).
  /// Edges crossing the selection become ports on the group.
  void groupSelection({String label = 'Sub-flow'}) {
    final sel = {..._selected};
    if (sel.isEmpty) return;
    final inner = [for (final id in sel) _g.nodes[id]!];
    final innerEdges = _g.edges.values
        .where((e) => sel.contains(e.sourceNode) && sel.contains(e.targetNode))
        .toList();
    final id = _freshId('group', (x) => _g.nodes.containsKey(x));
    final ports = <Port>[];
    final boundary = <String, BoundaryTarget>{};
    final portFor = <String, String>{}; // "node/port" → group port id
    final rewired = <FlowEdge>[];
    for (final e in _g.edges.values) {
      final inS = sel.contains(e.sourceNode), inT = sel.contains(e.targetNode);
      if (inS == inT) continue;
      final (node, port) =
          inT ? (e.targetNode, e.targetPort) : (e.sourceNode, e.sourcePort);
      final pid = portFor.putIfAbsent('$node/$port', () {
        final pid = '${inT ? 'in' : 'out'}_${ports.length + 1}';
        ports.add(Port(
            id: pid,
            side: inT ? PortSide.left : PortSide.right,
            type: _g.nodes[node]!.port(port)!.type));
        boundary[pid] = BoundaryTarget(node, port);
        return pid;
      });
      rewired.add(inT
          ? FlowEdge(
              id: e.id,
              sourceNode: e.sourceNode,
              sourcePort: e.sourcePort,
              targetNode: id,
              targetPort: pid,
              label: e.label)
          : FlowEdge(
              id: e.id,
              sourceNode: id,
              sourcePort: pid,
              targetNode: e.targetNode,
              targetPort: e.targetPort,
              label: e.label));
    }
    var tl = inner.first.position;
    for (final x in inner) {
      tl = Offset(tl.dx < x.position.dx ? tl.dx : x.position.dx,
          tl.dy < x.position.dy ? tl.dy : x.position.dy);
    }
    final side = ports.where((p) => p.isInput).length >
            ports.where((p) => !p.isInput).length
        ? ports.where((p) => p.isInput).length
        : ports.where((p) => !p.isInput).length;
    final group = FlowNode(
      id: id,
      position: tl,
      size: Size(200, side * 28.0 + 20 > 68 ? side * 28.0 + 20 : 68),
      type: 'subflow',
      label: label,
      ports: ports,
      subflow: SubFlow(nodes: inner, edges: innerEdges, boundary: boundary),
    );
    execute(BatchCommand([
      RemoveNodes(sel),
      AddNode(group),
      for (final e in rewired) AddEdge(e),
    ]));
    select(id);
  }

  /// Expands group node [id] back into its nodes (one undo step).
  void ungroup(String id) {
    final g = _g.nodes[id];
    final sub = g?.subflow;
    if (g == null || sub == null) return;
    var tl = sub.nodes.isEmpty ? g.position : sub.nodes.first.position;
    for (final x in sub.nodes) {
      tl = Offset(tl.dx < x.position.dx ? tl.dx : x.position.dx,
          tl.dy < x.position.dy ? tl.dy : x.position.dy);
    }
    final shift = g.position - tl;
    final taken = {..._g.nodes.keys}..remove(id);
    final nodeIds = <String, String>{};
    for (final x in sub.nodes) {
      final nid = _freshId(x.id, taken.contains);
      taken.add(nid);
      nodeIds[x.id] = nid;
    }
    final edgeTaken = {..._g.edges.keys};
    String eid(String base) {
      final e = _freshId(base, edgeTaken.contains);
      edgeTaken.add(e);
      return e;
    }

    final outside = _g.edges.values.where((e) => e.touches(id)).toList();
    for (final e in outside) {
      edgeTaken.remove(e.id);
    }
    execute(BatchCommand([
      RemoveNodes({id}),
      for (final x in sub.nodes) AddNode(cloneNode(x, nodeIds[x.id]!, shift)),
      for (final e in sub.edges)
        AddEdge(FlowEdge(
            id: eid(e.id),
            sourceNode: nodeIds[e.sourceNode]!,
            sourcePort: e.sourcePort,
            targetNode: nodeIds[e.targetNode]!,
            targetPort: e.targetPort,
            label: e.label)),
      for (final e in outside)
        if (sub.boundary[e.targetNode == id ? e.targetPort : e.sourcePort]
            case final b?)
          AddEdge(e.targetNode == id
              ? FlowEdge(
                  id: eid(e.id),
                  sourceNode: e.sourceNode,
                  sourcePort: e.sourcePort,
                  targetNode: nodeIds[b.node]!,
                  targetPort: b.port,
                  label: e.label)
              : FlowEdge(
                  id: eid(e.id),
                  sourceNode: nodeIds[b.node]!,
                  sourcePort: b.port,
                  targetNode: e.targetNode,
                  targetPort: e.targetPort,
                  label: e.label)),
    ]));
    selectNodes(nodeIds.values);
  }

  /// Opens group node [id] for editing; [nodes]/[edges] become its contents.
  void enter(String id) {
    final sub = _g.nodes[id]?.subflow;
    if (sub == null) return;
    _levels.add((_g, _undo, _redo, id));
    _g = FlowGraph();
    for (final x in sub.nodes) {
      _g.nodes[x.id] = x;
    }
    for (final e in sub.edges) {
      _g.edges[e.id] = e;
    }
    _undo = [];
    _redo = [];
    _selected.clear();
    _selectedEdge = null;
    notifyListeners();
  }

  /// Leaves the current sub-flow, saving its contents into the group node.
  void exit() {
    if (_levels.isEmpty) return;
    final (parent, undo, redo, id) = _levels.removeLast();
    final group = parent.nodes[id]!;
    parent.nodes[id] = group.copyWith(
      subflow: SubFlow(
        nodes: _g.nodes.values.toList(),
        edges: _g.edges.values.toList(),
        boundary: group.subflow!.boundary,
      ),
    );
    _g = parent;
    _undo = undo;
    _redo = redo;
    _selected
      ..clear()
      ..add(id);
    _selectedEdge = null;
    notifyListeners();
  }

  /// Exits until [depth] equals [level].
  void exitTo(int level) {
    while (_levels.length > level) {
      exit();
    }
  }

  /// Arranges all nodes with [layeredLayout] as one undo step. Call
  /// `FlowCanvasState.fitView()` afterwards to bring them into view.
  void autoLayout(
      {double layerGap = 80,
      double nodeGap = 40,
      Axis direction = Axis.horizontal}) {
    if (_g.nodes.isEmpty) return;
    final to = layeredLayout(nodes, edges,
        layerGap: layerGap, nodeGap: nodeGap, direction: direction);
    execute(MoveNodes(from: {for (final n in nodes) n.id: n.position}, to: to));
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
