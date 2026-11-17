import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class FlowViewportState {
  const FlowViewportState(this.offset, this.zoom);
  final Offset offset;
  final double zoom;
}

/// Pan/zoom transform: screen = world * zoom + offset.
class FlowViewport extends ChangeNotifier {
  FlowViewport({Offset offset = Offset.zero, double zoom = 1})
      : _offset = offset,
        _zoom = zoom.clamp(minZoom, maxZoom);

  static const minZoom = 0.05;
  static const maxZoom = 3.0;

  Offset _offset;
  double _zoom;

  Offset get offset => _offset;
  double get zoom => _zoom;

  set offset(Offset v) {
    _offset = v;
    notifyListeners();
  }

  void set(Offset offset, double zoom) {
    _offset = offset;
    _zoom = zoom.clamp(minZoom, maxZoom);
    notifyListeners();
  }

  Offset toWorld(Offset screen) => (screen - _offset) / _zoom;
  Offset toScreen(Offset world) => world * _zoom + _offset;

  void panBy(Offset d) => offset = _offset + d;

  void zoomAt(Offset focalScreen, double factor) {
    final k = (_zoom * factor).clamp(minZoom, maxZoom);
    final world = toWorld(focalScreen);
    _zoom = k;
    _offset = focalScreen - world * k;
    notifyListeners();
  }

  Rect visibleWorldRect(Size viewport) => Rect.fromPoints(
      toWorld(Offset.zero), toWorld(Offset(viewport.width, viewport.height)));

  FlowViewportState fitTarget(Rect content, Size viewport,
      {EdgeInsets padding = const EdgeInsets.all(60), double maxZoom = 1.4}) {
    final avail = padding.deflateSize(viewport);
    final k = math
        .min(avail.width / math.max(content.width, 1),
            avail.height / math.max(content.height, 1))
        .clamp(minZoom, maxZoom);
    final centre = padding.topLeft + Offset(avail.width / 2, avail.height / 2);
    return FlowViewportState(centre - content.center * k, k);
  }

  Matrix4 get matrix => Matrix4.identity()
    ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
    ..scaleByDouble(_zoom, _zoom, 1, 1);
}
