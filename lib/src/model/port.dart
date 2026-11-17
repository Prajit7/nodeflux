import 'dart:ui' show Color;

/// The data type flowing through a port. Two ports connect when their types
/// share a [name], or when either side is [PortType.any].
class PortType {
  const PortType(this.name, this.color);

  final String name;
  final Color color;

  static const any = PortType('any', Color(0xFF868E96));

  /// Whether an input of this type accepts data of type [from].
  bool accepts(PortType? from) {
    if (from == null) return false;
    return name == any.name || from.name == any.name || from.name == name;
  }

  @override
  bool operator ==(Object other) => other is PortType && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

enum PortSide { left, right }

class Port {
  const Port({required this.id, required this.side, required this.type});

  final String id;
  final PortSide side;
  final PortType type;

  bool get isInput => side == PortSide.left;
}
