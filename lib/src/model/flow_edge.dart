const _unset = Object();

class FlowEdge {
  const FlowEdge({
    required this.id,
    required this.sourceNode,
    required this.sourcePort,
    required this.targetNode,
    required this.targetPort,
    this.label,
  });

  final String id;
  final String sourceNode;
  final String sourcePort;
  final String targetNode;
  final String targetPort;
  final String? label;

  bool touches(String nodeId) => sourceNode == nodeId || targetNode == nodeId;

  FlowEdge copyWith({Object? label = _unset}) => FlowEdge(
        id: id,
        sourceNode: sourceNode,
        sourcePort: sourcePort,
        targetNode: targetNode,
        targetPort: targetPort,
        label: identical(label, _unset) ? this.label : label as String?,
      );
}
