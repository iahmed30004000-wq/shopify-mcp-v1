// «اكتب الحرف بإصبعك»: a big faint letter and a finger that paints over it.
//
// Forgiving on purpose: nothing is measured against the glyph, nothing is
// "wrong". After the child has drawn a little the screen simply says
// something kind. Strokes are kept as [Path]s that grow as the finger moves,
// so a frame never builds a path from scratch.
import 'package:flutter/material.dart';

import '../ui/kids_tokens.dart';

class TraceCanvas extends StatefulWidget {
  const TraceCanvas({super.key, required this.glyph, this.onEnough, this.enoughLength = 420});

  final String glyph;

  /// Called once per drawing, when the child has drawn [enoughLength] logical
  /// pixels of line (a kind message appears, never a score).
  final VoidCallback? onEnough;
  final double enoughLength;

  @override
  State<TraceCanvas> createState() => TraceCanvasState();
}

class TraceCanvasState extends State<TraceCanvas> {
  final _tick = ValueNotifier<int>(0);
  final List<Path> _strokes = [];
  Offset? _last;
  double _length = 0;
  bool _reported = false;

  /// How many logical pixels of line have been drawn (tests, semantics).
  double get drawnLength => _length;

  void clear() {
    _strokes.clear();
    _last = null;
    _length = 0;
    _reported = false;
    _tick.value++;
  }

  @override
  void didUpdateWidget(TraceCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.glyph != widget.glyph) clear();
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    _last = e.localPosition;
    _strokes.add(Path()..moveTo(e.localPosition.dx, e.localPosition.dy));
    // A tap leaves a dot, so touching is never "nothing".
    _strokes.last.lineTo(e.localPosition.dx + 0.1, e.localPosition.dy);
    _tick.value++;
  }

  void _move(PointerMoveEvent e) {
    final last = _last;
    if (last == null || _strokes.isEmpty) return;
    _strokes.last.lineTo(e.localPosition.dx, e.localPosition.dy);
    _length += (e.localPosition - last).distance;
    _last = e.localPosition;
    _tick.value++;
    if (!_reported && _length >= widget.enoughLength) {
      _reported = true;
      widget.onEnough?.call();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final side = box.biggest.shortestSide;
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: (_) => _last = null,
          onPointerCancel: (_) => _last = null,
          child: Container(
            width: side,
            height: side,
            color: KidsColors.sun100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The glyph is shaped by the text engine, like everywhere else.
                Center(
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: EdgeInsets.all(side * 0.08),
                      child: FittedBox(
                        child: Text(
                          widget.glyph,
                          textDirection: TextDirection.rtl,
                          style: KidsType.letterStyle(260, color: KidsColors.sun300),
                        ),
                      ),
                    ),
                  ),
                ),
                RepaintBoundary(
                  child: CustomPaint(painter: _StrokePainter(_strokes, _tick)),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.strokes, Listenable repaint) : super(repaint: repaint);

  final List<Path> strokes;
  final Paint _paint = Paint()
    ..color = KidsColors.rose500
    ..style = PaintingStyle.stroke
    ..strokeWidth = 18
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      canvas.drawPath(s, _paint);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter old) => true;
}
