import 'dart:ui';

/// Uniform-grid spatial hash for fast rect / point queries.
class SpatialIndex<T> {
  SpatialIndex({this.cell = 256});

  final double cell;
  final Map<(int, int), List<T>> _cells = {};
  final Map<T, Rect> _rects = {};

  int get length => _rects.length;

  void clear() {
    _cells.clear();
    _rects.clear();
  }

  (int, int, int, int) _span(Rect r) => (
        (r.left / cell).floor(),
        (r.top / cell).floor(),
        (r.right / cell).floor(),
        (r.bottom / cell).floor(),
      );

  void insert(T item, Rect r) {
    _rects[item] = r;
    final (x0, y0, x1, y1) = _span(r);
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        (_cells[(x, y)] ??= []).add(item);
      }
    }
  }

  /// Items whose rect overlaps [r]; each item at most once.
  Iterable<T> query(Rect r) {
    final (x0, y0, x1, y1) = _span(r);
    final seen = <T>{};
    final out = <T>[];
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        for (final item in _cells[(x, y)] ?? const []) {
          if (seen.add(item) && _rects[item]!.overlaps(r)) out.add(item);
        }
      }
    }
    return out;
  }

  /// Items whose rect contains [p].
  Iterable<T> at(Offset p) {
    final key = ((p.dx / cell).floor(), (p.dy / cell).floor());
    return (_cells[key] ?? const []).where((i) => _rects[i]!.contains(p));
  }
}
