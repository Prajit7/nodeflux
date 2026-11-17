import 'flow_edge.dart';
import 'flow_node.dart';

/// Where a group node's port leads inside the sub-flow.
class BoundaryTarget {
  const BoundaryTarget(this.node, this.port);
  final String node;
  final String port;
}

/// The nested graph inside a group node (see `FlowController.groupSelection`).
class SubFlow {
  const SubFlow(
      {required this.nodes, required this.edges, this.boundary = const {}});

  final List<FlowNode> nodes;
  final List<FlowEdge> edges;

  /// Group port id → the inner node/port it stands for.
  final Map<String, BoundaryTarget> boundary;
}
