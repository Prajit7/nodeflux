import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nodeflux/nodeflux.dart';

void main() {
  test('toWorld/toScreen roundtrip', () {
    final v = FlowViewport(offset: const Offset(40, -20), zoom: 1.5);
    const p = Offset(123, 456);
    final r = v.toScreen(v.toWorld(p));
    expect(r.dx, closeTo(p.dx, 1e-9));
    expect(r.dy, closeTo(p.dy, 1e-9));
  });

  test('zoomAt keeps focal point fixed', () {
    final v = FlowViewport(offset: const Offset(10, 10));
    const f = Offset(300, 200);
    final before = v.toWorld(f);
    v.zoomAt(f, 2);
    final after = v.toWorld(f);
    expect(after.dx, closeTo(before.dx, 1e-9));
    expect(after.dy, closeTo(before.dy, 1e-9));
    expect(v.zoom, 2);
  });

  test('zoom clamped', () {
    final v = FlowViewport();
    v.zoomAt(Offset.zero, 1000);
    expect(v.zoom, FlowViewport.maxZoom);
    v.zoomAt(Offset.zero, 1e-9);
    expect(v.zoom, FlowViewport.minZoom);
  });

  test('fitTarget centres content', () {
    final v = FlowViewport();
    final t =
        v.fitTarget(const Rect.fromLTWH(0, 0, 200, 100), const Size(800, 600));
    expect(t.zoom, 1.4);
    final centre = (const Offset(100, 50) * t.zoom) + t.offset;
    expect(centre.dx, closeTo(400, 1e-9));
    expect(centre.dy, closeTo(300, 1e-9));
  });

  test('visibleWorldRect', () {
    final v = FlowViewport(offset: const Offset(-100, -50), zoom: 2);
    expect(v.visibleWorldRect(const Size(400, 200)),
        const Rect.fromLTWH(50, 25, 200, 100));
  });
}
