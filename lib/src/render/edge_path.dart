import 'dart:math' as math;
import 'dart:ui';

enum EdgeType { bezier, smoothstep, step, straight }

/// Path from output port [a] to input port [b]. Geometry matches the HTML
/// reference spike.
Path buildEdgePath(Offset a, Offset b, EdgeType type) {
  final p = Path()..moveTo(a.dx, a.dy);
  final mid = (a.dx + b.dx) / 2;
  switch (type) {
    case EdgeType.bezier:
      final d = math.max(40.0, (b.dx - a.dx).abs() / 2);
      p.cubicTo(a.dx + d, a.dy, b.dx - d, b.dy, b.dx, b.dy);
    case EdgeType.straight:
      p.lineTo(b.dx, b.dy);
    case EdgeType.step:
      p
        ..lineTo(mid, a.dy)
        ..lineTo(mid, b.dy)
        ..lineTo(b.dx, b.dy);
    case EdgeType.smoothstep:
      final r =
          [12.0, (b.dy - a.dy).abs() / 2, (mid - a.dx).abs()].reduce(math.min);
      final s = (b.dy - a.dy).sign == 0 ? 1.0 : (b.dy - a.dy).sign;
      final h = (b.dx - a.dx).sign == 0 ? 1.0 : (b.dx - a.dx).sign;
      p
        ..lineTo(mid - r * h, a.dy)
        ..quadraticBezierTo(mid, a.dy, mid, a.dy + r * s)
        ..lineTo(mid, b.dy - r * s)
        ..quadraticBezierTo(mid, b.dy, mid + r * h, b.dy)
        ..lineTo(b.dx, b.dy);
  }
  return p;
}

/// Point at fraction [u] (0..1) of the edge's arc length.
Offset pointOnEdge(Offset a, Offset b, EdgeType type, double u) {
  final metrics = buildEdgePath(a, b, type).computeMetrics().toList();
  final total = metrics.fold<double>(0, (s, m) => s + m.length);
  if (total == 0) return a;
  var d = u.clamp(0.0, 1.0) * total;
  for (final m in metrics) {
    if (d <= m.length) return m.getTangentForOffset(d)!.position;
    d -= m.length;
  }
  return b;
}

/// Whether [p] lies within [tolerance] of the edge.
bool hitEdge(Offset a, Offset b, EdgeType type, Offset p,
    {double tolerance = 8}) {
  final bounds = Rect.fromPoints(a, b).inflate(tolerance + 50);
  if (!bounds.contains(p)) return false;
  for (final m in buildEdgePath(a, b, type).computeMetrics()) {
    for (double d = 0; d <= m.length; d += 4) {
      if ((m.getTangentForOffset(d)!.position - p).distance <= tolerance) {
        return true;
      }
    }
    if ((m.getTangentForOffset(m.length)!.position - p).distance <= tolerance) {
      return true;
    }
  }
  return false;
}
