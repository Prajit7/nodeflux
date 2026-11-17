import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/commands.dart';
import '../controller/flow_controller.dart';
import '../controller/flow_viewport.dart';
import '../model/flow_edge.dart';
import '../model/flow_node.dart';
import '../model/port.dart';
import '../render/background_painter.dart';
import '../render/edge_painter.dart';
import '../render/edge_path.dart';
import '../theme/flow_theme.dart';
import 'edge_tooltip.dart';

typedef FlowNodeBuilder = Widget Function(BuildContext context, FlowNode node);

/// An infinite, pannable, zoomable canvas showing a [FlowController]'s graph.
///
/// Nodes are ordinary widgets from [nodeBuilder]; only those inside the
/// viewport are built. Edges, background and previews are painted.
class FlowCanvas extends StatefulWidget {
  const FlowCanvas({
    super.key,
    required this.controller,
    required this.nodeBuilder,
    this.viewport,
    this.edgeType = EdgeType.bezier,
    this.animateEdges = true,
    this.background = BackgroundType.dots,
    this.gridSize = 20,
    this.lodZoom = 0.45,
    this.nodeColor,
    this.onConnectRejected,
    this.onConnectEndEmpty,
    this.longPressDelay = const Duration(milliseconds: 400),
    this.showEdgeData = true,
    this.onCanvasMenu,
  });

  final FlowController controller;
  final FlowNodeBuilder nodeBuilder;
  final FlowViewport? viewport;
  final EdgeType edgeType;

  /// Flowing dashes along edges.
  final bool animateEdges;
  final BackgroundType background;
  final double gridSize;

  /// Below this zoom, nodes are painted as simple boxes instead of widgets.
  final double lodZoom;

  /// Accent colour for a node in LOD mode. Defaults to the theme selection.
  final Color Function(FlowNode node)? nodeColor;

  /// Called when a dragged connection is dropped on a node it can't connect to.
  final void Function(ConnectResult result)? onConnectRejected;

  /// Called when a connection is dropped on empty canvas. Return a node to
  /// add it and connect to it in a single undo step (see [showNodePicker]).
  final Future<FlowNode?> Function(BuildContext context,
      {required FlowNode source,
      required Port port,
      required Offset worldPosition})? onConnectEndEmpty;

  /// Touch hold time on an output port before a connection drag starts.
  final Duration longPressDelay;

  /// Show an [EdgeTooltip] with the carried data when hovering an edge.
  final bool showEdgeData;

  /// Called on right-click or double-click/double-tap on empty canvas —
  /// typically used to show an "add node" menu at [worldPosition].
  final void Function(BuildContext context, Offset worldPosition)? onCanvasMenu;

  @override
  State<FlowCanvas> createState() => FlowCanvasState();
}

sealed class _Drag {}

class _Pan extends _Drag {}

class _Move extends _Drag {
  _Move(this.origin, this.start);
  final Offset origin;
  final Map<String, Offset> start;
  bool moved = false;
}

class _Connect extends _Drag {
  _Connect(this.node, this.port, this.to);
  final String node, port;
  Offset to;
  Offset screen = Offset.zero;
  String? targetNode, targetPort;
  ConnectResult? result;
}

/// Touch is down on an output port, waiting for the long-press delay.
class _PendingConnect extends _Drag {
  _PendingConnect(this.node, this.port, this.down, this.timer);
  final String node, port;
  final Offset down;
  final Timer timer;
}

class FlowCanvasState extends State<FlowCanvas> with TickerProviderStateMixin {
  late FlowViewport _vp = widget.viewport ?? FlowViewport();
  late final AnimationController _ticker =
      AnimationController(vsync: this, duration: const Duration(seconds: 1));
  final FocusNode _focus = FocusNode(debugLabel: 'FlowCanvas');
  final Map<int, Offset> _pointers = {};
  _Drag? _drag;
  double? _pinchDist;
  double _lastPanZoomScale = 1;
  Size _size = Size.zero;
  String? _hoverEdge;
  DateTime? _lastEmptyTap;
  final Set<int> _claimed = {};

  /// Hands pointer [pointer] to a widget inside a node (see FlowInteractive);
  /// the canvas ignores it until it is released.
  void claimPointer(int pointer) => _claimed.add(pointer);
  Offset _lastEmptyTapAt = Offset.zero;
  Offset _hoverAt = Offset.zero;

  FlowViewport get viewport => _vp;
  FlowController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onGraph);
    _syncTicker();
  }

  @override
  void didUpdateWidget(FlowCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onGraph);
      widget.controller.addListener(_onGraph);
    }
    if (widget.viewport != null && widget.viewport != _vp) {
      _vp = widget.viewport!;
    }
    _syncTicker();
  }

  @override
  void dispose() {
    _c.removeListener(_onGraph);
    _ticker.dispose();
    _fit?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onGraph() {
    _syncTicker();
    setState(() {});
  }

  bool get _pulsing {
    final now = DateTime.now();
    return _c.pulses.values.any((t) => now.difference(t) < pulseDuration);
  }

  void _syncTicker() {
    final want = (widget.animateEdges && _c.edges.isNotEmpty) || _pulsing;
    if (want && !_ticker.isAnimating) {
      _ticker.repeat();
    } else if (!want && _ticker.isAnimating) {
      _ticker.stop();
    }
  }

  AnimationController? _fit;

  /// Bounding box of all nodes, or null if empty.
  Rect? get contentBounds {
    Rect? r;
    for (final n in _c.nodes) {
      r = r == null ? n.rect : r.expandToInclude(n.rect);
    }
    return r;
  }

  /// Animates the viewport so every node is visible.
  void fitView(
      {Duration duration = const Duration(milliseconds: 400),
      EdgeInsets padding = const EdgeInsets.all(60)}) {
    final b = contentBounds;
    if (b == null || _size.isEmpty) return;
    final target = _vp.fitTarget(b, _size, padding: padding);
    final o0 = _vp.offset, z0 = _vp.zoom;
    _fit?.dispose();
    final a = _fit = AnimationController(vsync: this, duration: duration);
    final curve = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
    a.addListener(() {
      final k = curve.value;
      _vp.set(Offset.lerp(o0, target.offset, k)!, z0 + (target.zoom - z0) * k);
    });
    a.forward();
  }

  // ---------------------------------------------------------------- hit tests

  FlowNode? nodeAt(Offset world) {
    for (final n in _c.nodes.toList().reversed) {
      if (n.rect.contains(world)) return n;
    }
    return null;
  }

  /// Output port near [world], as (node, port).
  (FlowNode, Port)? outputPortAt(Offset world) {
    final tol = math.max(10.0, 10 / _vp.zoom);
    for (final n in _c.nodes.toList().reversed) {
      for (final p in n.outputs) {
        if ((n.portPosition(p.id) - world).distance <= tol) return (n, p);
      }
    }
    return null;
  }

  String? edgeAt(Offset world) {
    for (final e in _c.edges) {
      final ends = EdgePainter.endpoints(_c, e);
      if (ends == null) continue;
      if (hitEdge(ends.$1, ends.$2, widget.edgeType, world,
          tolerance: 8 / _vp.zoom)) {
        return e.id;
      }
    }
    return null;
  }

  // ------------------------------------------------------------------ pointer

  void _down(PointerDownEvent e) {
    if (_claimed.contains(e.pointer)) return;
    _focus.requestFocus();
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2) {
      _cancelDrag();
      final p = _pointers.values.toList();
      _pinchDist = (p[0] - p[1]).distance;
      return;
    }
    if (_pointers.length > 2) return;
    final w = _vp.toWorld(e.localPosition);
    final port = outputPortAt(w);
    if (port != null) {
      final (pn, pp) = port;
      if (e.kind == PointerDeviceKind.touch) {
        _drag = _PendingConnect(
            pn.id,
            pp.id,
            e.localPosition,
            Timer(widget.longPressDelay, () {
              if (_drag is _PendingConnect && mounted) {
                HapticFeedback.selectionClick();
                setState(() =>
                    _drag = _Connect(pn.id, pp.id, pn.portPosition(pp.id))
                      ..screen = e.localPosition);
              }
            }));
      } else {
        _drag = _Connect(pn.id, pp.id, w)..screen = e.localPosition;
      }
      return;
    }
    final node = nodeAt(w);
    if (node != null) {
      final shift = HardwareKeyboard.instance.isShiftPressed;
      if (shift) {
        _c.toggleSelect(node.id);
      } else if (!_c.selectedNodes.contains(node.id)) {
        _c.select(node.id);
      }
      _drag = _Move(w, {
        for (final id in _c.selectedNodes) id: _c.node(id)!.position,
      });
      return;
    }
    final edge = edgeAt(w);
    if (edge != null) {
      _c.selectEdge(edge);
      _drag = null;
      return;
    }
    if (e.buttons & kSecondaryMouseButton != 0) {
      _drag = null;
      widget.onCanvasMenu?.call(context, w);
      return;
    }
    final now = DateTime.now();
    final last = _lastEmptyTap;
    if (last != null &&
        now.difference(last) < kDoubleTapTimeout &&
        (e.localPosition - _lastEmptyTapAt).distance < kDoubleTapSlop) {
      _lastEmptyTap = null;
      _drag = null;
      widget.onCanvasMenu?.call(context, w);
      return;
    }
    _lastEmptyTap = now;
    _lastEmptyTapAt = e.localPosition;
    _c.clearSelection();
    _drag = _Pan();
  }

  void _move(PointerMoveEvent e) {
    final prev = _pointers[e.pointer];
    if (prev == null) return;
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2 && _pinchDist != null) {
      final p = _pointers.values.toList();
      final d = (p[0] - p[1]).distance;
      final mid = (p[0] + p[1]) / 2;
      _vp.zoomAt(mid, d / math.max(_pinchDist!, 1));
      _vp.panBy(e.delta / 2);
      _pinchDist = d;
      return;
    }
    final w = _vp.toWorld(e.localPosition);
    switch (_drag) {
      case final _PendingConnect p:
        if ((e.localPosition - p.down).distance > kTouchSlop) {
          p.timer.cancel();
          _drag = _Pan();
          _vp.panBy(e.localPosition - p.down);
        }
      case final _Connect cn:
        setState(() => _updateConnect(cn, w, e.localPosition));
      case _Pan():
        _vp.panBy(e.delta);
      case final _Move m:
        final d = w - m.origin;
        if (d == Offset.zero) return;
        m.moved = true;
        _c.moveLive({for (final en in m.start.entries) en.key: en.value + d});
      case null:
        break;
    }
  }

  void _up(PointerEvent e) {
    if (_claimed.remove(e.pointer)) return;
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchDist = null;
    final d = _drag;
    if (d is _PendingConnect) {
      d.timer.cancel();
      _drag = null;
      return;
    }
    if (d is _Connect) {
      _drag = null;
      setState(() {});
      if (e is PointerUpEvent) _dropConnect(d, _vp.toWorld(e.localPosition));
      return;
    }
    _finishDrag();
  }

  void _finishDrag() {
    final d = _drag;
    if (d is _Move && d.moved) {
      _c.execute(MoveNodes(
        from: d.start,
        to: {for (final id in d.start.keys) id: _c.node(id)!.position},
      ));
    }
    _drag = null;
  }

  void _cancelDrag() {
    final d = _drag;
    if (d is _PendingConnect) d.timer.cancel();
    if (d is _Connect) {
      _drag = null;
      setState(() {});
      return;
    }
    _finishDrag();
  }

  void _updateConnect(_Connect cn, Offset w, Offset screen) {
    cn
      ..to = w
      ..screen = screen
      ..targetNode = null
      ..targetPort = null
      ..result = null;
    final target = nodeAt(w);
    if (target == null || target.id == cn.node) return;
    final src = _c.node(cn.node)!.port(cn.port)!;
    final inputs = target.inputs.toList();
    final pick = inputs.firstWhere((p) => p.type.accepts(src.type),
        orElse: () => inputs.isEmpty ? src : inputs.first);
    cn
      ..targetNode = target.id
      ..targetPort = inputs.isEmpty ? '' : pick.id
      ..result = _c.canConnect(
          cn.node, cn.port, target.id, inputs.isEmpty ? '' : pick.id);
  }

  Future<void> _dropConnect(_Connect cn, Offset w) async {
    _updateConnect(cn, w, cn.screen);
    if (cn.targetNode != null) {
      final cmd =
          _c.connectCommand(cn.node, cn.port, cn.targetNode!, cn.targetPort!);
      if (cmd != null) {
        _c.execute(cmd);
      } else {
        widget.onConnectRejected?.call(cn.result!);
      }
      return;
    }
    final cb = widget.onConnectEndEmpty;
    if (cb == null) return;
    final source = _c.node(cn.node)!;
    final port = source.port(cn.port)!;
    final created =
        await cb(context, source: source, port: port, worldPosition: w);
    if (created == null || !mounted) return;
    final input =
        created.inputs.where((p) => p.type.accepts(port.type)).firstOrNull;
    final add = AddNode(created);
    _c.execute(BatchCommand([
      add,
      if (input != null)
        AddEdge(FlowEdge(
          id: 'e_${source.id}_${created.id}_${DateTime.now().microsecondsSinceEpoch}',
          sourceNode: source.id,
          sourcePort: port.id,
          targetNode: created.id,
          targetPort: input.id,
        )),
    ]));
  }

  void _hover(PointerHoverEvent e) {
    final id = edgeAt(_vp.toWorld(e.localPosition));
    if (id != _hoverEdge || (id != null && widget.showEdgeData)) {
      setState(() {
        _hoverEdge = id;
        _hoverAt = e.localPosition;
      });
    }
  }

  void _signal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      _vp.zoomAt(e.localPosition, math.exp(-e.scrollDelta.dy * 0.0015));
    }
  }

  void _panZoomStart(PointerPanZoomStartEvent e) => _lastPanZoomScale = 1;

  void _panZoomUpdate(PointerPanZoomUpdateEvent e) {
    _vp.panBy(e.panDelta);
    if (e.scale != _lastPanZoomScale) {
      _vp.zoomAt(e.localPosition, e.scale / _lastPanZoomScale);
      _lastPanZoomScale = e.scale;
    }
  }

  // ----------------------------------------------------------------- keyboard

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Keys typed into a text field (or other widget) inside a node bubble up
    // here; only act when the canvas itself is focused.
    if (!_focus.hasPrimaryFocus) return KeyEventResult.ignored;
    final kb = HardwareKeyboard.instance;
    final mod = kb.isMetaPressed || kb.isControlPressed;
    final k = e.logicalKey;
    if (mod && k == LogicalKeyboardKey.keyZ) {
      kb.isShiftPressed ? _c.redo() : _c.undo();
    } else if (mod && k == LogicalKeyboardKey.keyY) {
      _c.redo();
    } else if (mod && k == LogicalKeyboardKey.keyA) {
      _c.selectAll();
    } else if (k == LogicalKeyboardKey.delete ||
        k == LogicalKeyboardKey.backspace) {
      _c.removeSelected();
    } else if (k == LogicalKeyboardKey.escape) {
      _c.clearSelection();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ------------------------------------------------------------------- build

  ConnectPreview? get _preview {
    final d = _drag;
    if (d is! _Connect) return null;
    final n = _c.node(d.node);
    if (n == null) return null;
    return ConnectPreview(n.portPosition(d.port), d.to,
        bad: d.result != null && !d.result!.ok);
  }

  List<Widget> _overlays(FlowTheme theme) {
    final d = _drag;
    if (d == null && widget.showEdgeData && _hoverEdge != null) {
      final e = _c.edge(_hoverEdge!);
      final a = e == null ? null : _c.node(e.sourceNode),
          b = e == null ? null : _c.node(e.targetNode);
      if (e == null || a == null || b == null) return const [];
      return [
        Positioned(
          left: math.min(_hoverAt.dx + 14, math.max(0.0, _size.width - 330)),
          top: _hoverAt.dy + 14,
          child:
              IgnorePointer(child: EdgeTooltip(edge: e, source: a, target: b)),
        ),
      ];
    }
    if (d is! _Connect || d.result == null) return const [];
    final r = d.result!;
    final src = _c.node(d.node)!.port(d.port)!.type;
    final label = r.ok
        ? '${src.name} → ${_c.node(d.targetNode!)!.port(d.targetPort!)!.type.name} ✓'
        : r.reason!;
    return [
      Positioned(
        left: d.screen.dx + 14,
        top: d.screen.dy + 14,
        child: IgnorePointer(
          child: Material(
            color: theme.nodeColor,
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: r.ok ? theme.textColor : theme.errorColor)),
            ),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlowTheme.of(context);
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      return Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _key,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          onPointerSignal: _signal,
          onPointerHover: _hover,
          onPointerPanZoomStart: _panZoomStart,
          onPointerPanZoomUpdate: _panZoomUpdate,
          child: ClipRect(
            child: ListenableBuilder(
              listenable: _vp,
              builder: (context, _) {
                final lod = _vp.zoom < widget.lodZoom;
                final visible = _vp.visibleWorldRect(_size).inflate(20);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: BackgroundPainter(
                          viewport: _vp,
                          type: widget.background,
                          color: theme.dotColor,
                          background: theme.background,
                          gridSize: widget.gridSize,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: EdgePainter(
                            controller: _c,
                            viewport: _vp,
                            theme: theme,
                            edgeType: widget.edgeType,
                            animate: widget.animateEdges,
                            lod: lod,
                            nodeColor:
                                widget.nodeColor ?? (_) => theme.selection,
                            preview: _preview,
                            hoverEdge: _hoverEdge,
                            repaint: Listenable.merge([_ticker, _vp, _c]),
                          ),
                        ),
                      ),
                    ),
                    if (!lod)
                      Positioned.fill(
                        child: Transform(
                          transform: _vp.matrix,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              for (final n in _c.nodes)
                                if (visible.overlaps(n.rect))
                                  Positioned(
                                    key: ValueKey(n.id),
                                    left: n.position.dx,
                                    top: n.position.dy,
                                    width: n.size.width,
                                    height: n.size.height,
                                    child: widget.nodeBuilder(context, n),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ..._overlays(theme),
                  ],
                );
              },
            ),
          ),
        ),
      );
    });
  }
}
