import 'package:flutter/widgets.dart';

import '../controller/flow_viewport.dart';

enum BackgroundType { dots, lines, none }

class BackgroundPainter extends CustomPainter {
  BackgroundPainter(
      {required this.viewport,
      required this.type,
      required this.color,
      required this.background,
      required this.gridSize})
      : super(repaint: viewport);

  final FlowViewport viewport;
  final BackgroundType type;
  final Color color, background;
  final double gridSize;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final g = gridSize * viewport.zoom;
    if (type == BackgroundType.none || g < 6) return;
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    final ox = viewport.offset.dx % g, oy = viewport.offset.dy % g;
    if (type == BackgroundType.dots) {
      for (var x = ox; x < size.width; x += g) {
        for (var y = oy; y < size.height; y += g) {
          canvas.drawRect(Rect.fromLTWH(x, y, 1.5, 1.5), p);
        }
      }
    } else {
      for (var x = ox; x < size.width; x += g) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      }
      for (var y = oy; y < size.height; y += g) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
    }
  }

  @override
  bool shouldRepaint(BackgroundPainter old) =>
      old.type != type ||
      old.color != color ||
      old.background != background ||
      old.gridSize != gridSize;
}
