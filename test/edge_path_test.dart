import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

void near(Offset a, Offset b) {
  expect(a.dx, closeTo(b.dx, 0.5));
  expect(a.dy, closeTo(b.dy, 0.5));
}

void main() {
  const a = Offset(0, 0), b = Offset(100, 100);
  for (final t in EdgeType.values) {
    test('pointOnEdge u=0 is a, u=1 is b ($t)', () {
      near(pointOnEdge(a, b, t, 0), a);
      near(pointOnEdge(a, b, t, 1), b);
    });
    test('buildEdgePath ends at b ($t)', () {
      final m = buildEdgePath(a, b, t).computeMetrics().first;
      near(m.getTangentForOffset(m.length)!.position, b);
    });
  }

  test('step midpoint on vertical segment', () {
    final p = pointOnEdge(a, b, EdgeType.step, 0.5);
    expect(p.dx, closeTo(50, 0.5));
  });

  test('hitEdge true on straight midpoint, false 20px away', () {
    expect(hitEdge(a, b, EdgeType.straight, const Offset(50, 50)), isTrue);
    expect(hitEdge(a, b, EdgeType.straight, const Offset(50, 70)), isFalse);
  });
}
