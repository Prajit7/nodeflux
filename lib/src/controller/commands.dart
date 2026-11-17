import 'dart:ui';

import '../model/flow_edge.dart';
import '../model/flow_node.dart';

/// Mutable graph storage owned by a FlowController.
class FlowGraph {
  final Map<String, FlowNode> nodes = {};
  final Map<String, FlowEdge> edges = {};
}

/// A reversible graph mutation. Every user edit goes through one, which is
/// what gives undo/redo (and, later, a collaboration op stream).
abstract class FlowCommand {
  void apply(FlowGraph g);
  void revert(FlowGraph g);
}

class AddNode extends FlowCommand {
  AddNode(this.node);
  final FlowNode node;
  @override
  void apply(FlowGraph g) => g.nodes[node.id] = node;
  @override
  void revert(FlowGraph g) => g.nodes.remove(node.id);
}

/// Removes nodes and every edge touching them.
class RemoveNodes extends FlowCommand {
  RemoveNodes(this.ids);
  final Set<String> ids;
  final List<FlowNode> _nodes = [];
  final List<FlowEdge> _edges = [];

  @override
  void apply(FlowGraph g) {
    _nodes
      ..clear()
      ..addAll(ids.map((id) => g.nodes[id]).whereType<FlowNode>());
    _edges
      ..clear()
      ..addAll(g.edges.values.where((e) => ids.any(e.touches)));
    for (final n in _nodes) {
      g.nodes.remove(n.id);
    }
    for (final e in _edges) {
      g.edges.remove(e.id);
    }
  }

  @override
  void revert(FlowGraph g) {
    for (final n in _nodes) {
      g.nodes[n.id] = n;
    }
    for (final e in _edges) {
      g.edges[e.id] = e;
    }
  }
}

class MoveNodes extends FlowCommand {
  MoveNodes({required this.from, required this.to});
  final Map<String, Offset> from;
  final Map<String, Offset> to;

  void _set(FlowGraph g, Map<String, Offset> pos) {
    pos.forEach((id, p) {
      final n = g.nodes[id];
      if (n != null) g.nodes[id] = n.copyWith(position: p);
    });
  }

  @override
  void apply(FlowGraph g) => _set(g, to);
  @override
  void revert(FlowGraph g) => _set(g, from);
}

class AddEdge extends FlowCommand {
  AddEdge(this.edge);
  final FlowEdge edge;
  @override
  void apply(FlowGraph g) => g.edges[edge.id] = edge;
  @override
  void revert(FlowGraph g) => g.edges.remove(edge.id);
}

class RemoveEdges extends FlowCommand {
  RemoveEdges(this.ids);
  final Set<String> ids;
  final List<FlowEdge> _removed = [];

  @override
  void apply(FlowGraph g) {
    _removed
      ..clear()
      ..addAll(ids.map((id) => g.edges.remove(id)).whereType<FlowEdge>());
  }

  @override
  void revert(FlowGraph g) {
    for (final e in _removed) {
      g.edges[e.id] = e;
    }
  }
}

class UpdateNode extends FlowCommand {
  UpdateNode(this.before, this.after);
  final FlowNode before;
  final FlowNode after;
  @override
  void apply(FlowGraph g) => g.nodes[after.id] = after;
  @override
  void revert(FlowGraph g) => g.nodes[before.id] = before;
}

class UpdateEdge extends FlowCommand {
  UpdateEdge(this.before, this.after);
  final FlowEdge before;
  final FlowEdge after;
  @override
  void apply(FlowGraph g) => g.edges[after.id] = after;
  @override
  void revert(FlowGraph g) => g.edges[before.id] = before;
}

/// Several commands applied and undone as one step.
class BatchCommand extends FlowCommand {
  BatchCommand(this.commands);
  final List<FlowCommand> commands;
  @override
  void apply(FlowGraph g) {
    for (final c in commands) {
      c.apply(g);
    }
  }

  @override
  void revert(FlowGraph g) {
    for (final c in commands.reversed) {
      c.revert(g);
    }
  }
}
