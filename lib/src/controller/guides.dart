import 'package:flutter/widgets.dart';

/// An alignment line drawn while dragging. [axis] vertical = a line at
/// x = [at] spanning y [from]..[to]; horizontal = a line at y = [at].
class GuideLine {
  const GuideLine(this.axis, this.at, this.from, this.to);
  final Axis axis;
  final double at, from, to;
}

/// Finds the nearest edge/centre alignment between [moving] and [others]
/// within [threshold] on each axis. Returns the correction to apply to the
/// moving rect and the guide lines to draw.
({Offset delta, List<GuideLine> lines}) computeGuides(
    Rect moving, Iterable<Rect> others,
    {required double threshold}) {
  double? bestDx, bestDy;
  Rect? withX, withY;
  double atX = 0, atY = 0;
  for (final o in others) {
    for (final a in [moving.left, moving.center.dx, moving.right]) {
      for (final b in [o.left, o.center.dx, o.right]) {
        final d = b - a;
        if (d.abs() <= threshold &&
            (bestDx == null || d.abs() < bestDx.abs())) {
          bestDx = d;
          withX = o;
          atX = b;
        }
      }
    }
    for (final a in [moving.top, moving.center.dy, moving.bottom]) {
      for (final b in [o.top, o.center.dy, o.bottom]) {
        final d = b - a;
        if (d.abs() <= threshold &&
            (bestDy == null || d.abs() < bestDy.abs())) {
          bestDy = d;
          withY = o;
          atY = b;
        }
      }
    }
  }
  final delta = Offset(bestDx ?? 0, bestDy ?? 0);
  final m = moving.shift(delta);
  return (
    delta: delta,
    lines: [
      if (withX != null)
        GuideLine(
            Axis.vertical,
            atX,
            (m.top < withX.top ? m.top : withX.top) - 20,
            (m.bottom > withX.bottom ? m.bottom : withX.bottom) + 20),
      if (withY != null)
        GuideLine(
            Axis.horizontal,
            atY,
            (m.left < withY.left ? m.left : withY.left) - 20,
            (m.right > withY.right ? m.right : withY.right) + 20),
    ],
  );
}
