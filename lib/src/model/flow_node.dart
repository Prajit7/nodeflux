import 'dart:ui';

import 'node_status.dart';
import 'port.dart';

const _unset = Object();

class FlowNode {
  const FlowNode({
    required this.id,
    required this.position,
    required this.type,
    required this.label,
    this.size = defaultSize,
    this.ports = const [],
    this.status = NodeStatus.idle,
    this.duration,
    this.error,
    this.data,
    this.output,
  });

  static const defaultSize = Size(180, 68);

  final String id;
  final Offset position;
  final Size size;
  final String type;
  final String label;
  final List<Port> ports;
  final NodeStatus status;
  final Duration? duration;
  final String? error;

  /// Arbitrary user data attached to the node.
  final Object? data;

  /// Last output produced by a run; shown in data previews.
  final Object? output;

  Rect get rect => position & size;

  Iterable<Port> get inputs => ports.where((p) => p.side == PortSide.left);
  Iterable<Port> get outputs => ports.where((p) => p.side == PortSide.right);

  Port? port(String id) {
    for (final p in ports) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// World-space centre of port [portId]. Ports on one side are spread
  /// evenly along the node's height.
  Offset portPosition(String portId) {
    final p = port(portId);
    if (p == null) throw ArgumentError('Unknown port $portId on node $id');
    final side = ports.where((x) => x.side == p.side).toList();
    final i = side.indexOf(p);
    final y = position.dy + size.height * (i + 1) / (side.length + 1);
    final x = p.side == PortSide.left ? position.dx : position.dx + size.width;
    return Offset(x, y);
  }

  FlowNode copyWith({
    Offset? position,
    Size? size,
    String? label,
    List<Port>? ports,
    NodeStatus? status,
    Object? duration = _unset,
    Object? error = _unset,
    Object? data = _unset,
    Object? output = _unset,
  }) {
    return FlowNode(
      id: id,
      type: type,
      position: position ?? this.position,
      size: size ?? this.size,
      label: label ?? this.label,
      ports: ports ?? this.ports,
      status: status ?? this.status,
      duration:
          identical(duration, _unset) ? this.duration : duration as Duration?,
      error: identical(error, _unset) ? this.error : error as String?,
      data: identical(data, _unset) ? this.data : data,
      output: identical(output, _unset) ? this.output : output,
    );
  }
}
