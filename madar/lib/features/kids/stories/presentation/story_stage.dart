import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:madar/core/design/islamic_geometry/islamic_geometry.dart';

import '../../rewards/presentation/play_kit.dart';
import '../domain/story_script.dart';

/// Draws one beat of a story: the night sky, a hill and a tree, the lantern and
/// the little star with its trail, glow and twinkles.
///
/// Built for 60 fps: it paints inside a RepaintBoundary, repaints only from
/// its two animations, and allocates nothing per frame (the paths are built
/// once per size; the paints and every translucent colour are made up front).
/// With reduced motion it is given stopped animations and shows the end of the
/// beat as one still picture, ghosts and all.
class StoryStagePainter extends CustomPainter {
  StoryStagePainter({required this.beat, required this.move, required this.ambient, this.lowPower = false})
    : super(repaint: Listenable.merge([move, ambient]));

  final StoryBeat beat;

  /// 0..1 through the beat's movement.
  final Animation<double> move;

  /// 0..1, repeating: the twinkle and the lantern's breathing.
  final Animation<double> ambient;

  /// A weak GPU: no ghosts, fewer twinkles, a smaller glow.
  final bool lowPower;

  // ---- built once ----
  static const int _steps = 24;
  static final List<Color> _gold = List.generate(_steps, (i) => KidsColors.sun500.withValues(alpha: i / (_steps - 1)));
  static final List<Color> _cream = List.generate(_steps, (i) => KidsColors.sun100.withValues(alpha: i / (_steps - 1)));
  static final List<Color> _white = List.generate(_steps, (i) => Colors.white.withValues(alpha: i / (_steps - 1)));
  static final Path _unitStar = khatamPath(Offset.zero, 1);
  static final Path _unitStarCore = khatamPath(Offset.zero, 0.42, innerRatio: 0.6);

  static Color _a(List<Color> table, double alpha) => table[(alpha.clamp(0.0, 1.0) * (_steps - 1)).round()];

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  Size? _builtFor;
  late Path _hillFar, _hillNear, _lanternBody;
  late Float32List _spark; // x, y, size per twinkle

  void _build(Size s) {
    _builtFor = s;
    _hillFar = Path()
      ..moveTo(0, s.height * 0.80)
      ..quadraticBezierTo(s.width * 0.30, s.height * 0.70, s.width * 0.62, s.height * 0.80)
      ..quadraticBezierTo(s.width * 0.85, s.height * 0.86, s.width, s.height * 0.78)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    _hillNear = Path()
      ..moveTo(0, s.height * 0.90)
      ..quadraticBezierTo(s.width * 0.4, s.height * 0.84, s.width, s.height * 0.92)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    final w = s.width * 0.05, h = s.height * 0.085;
    _lanternBody = Path()
      ..moveTo(-w * 0.6, -h)
      ..lineTo(w * 0.6, -h)
      ..lineTo(w, 0)
      ..lineTo(w * 0.6, h)
      ..lineTo(-w * 0.6, h)
      ..lineTo(-w, 0)
      ..close();
    _spark = Float32List(StoryScript.maxSparkles * 3);
    final rnd = math.Random(7);
    for (var i = 0; i < StoryScript.maxSparkles; i++) {
      _spark[i * 3] = rnd.nextDouble();
      _spark[i * 3 + 1] = 0.04 + rnd.nextDouble() * 0.62;
      _spark[i * 3 + 2] = 0.006 + rnd.nextDouble() * 0.01;
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// A point on the star's gentle arc from [a] to [b].
  Offset _at(Offset a, Offset b, double u, double h) =>
      Offset(_lerp(a.dx, b.dx, u), _lerp(a.dy, b.dy, u) - math.sin(u * math.pi) * h * 0.04);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_builtFor != size) _build(size);
    final t = Curves.easeInOutCubic.transform(move.value.clamp(0.0, 1.0));
    final amb = ambient.value;
    final w = size.width, h = size.height;

    // Twinkles.
    final n = beat.sparkles.clamp(0, lowPower ? 6 : StoryScript.maxSparkles);
    for (var i = 0; i < n; i++) {
      final tw = 0.55 + 0.45 * math.sin((amb + i * 0.13) * 2 * math.pi);
      canvas.save();
      canvas.translate(_spark[i * 3] * w, _spark[i * 3 + 1] * h);
      canvas.scale(_spark[i * 3 + 2] * w);
      canvas.drawPath(_unitStar, _fill..color = _a(_gold, 0.35 + 0.65 * tw));
      canvas.restore();
    }

    // Hills and the tree.
    canvas.drawPath(_hillFar, _fill..color = const Color(0xFF1E1A55));
    canvas.drawPath(_hillNear, _fill..color = const Color(0xFF110F33));
    final tx = w * 0.17, ty = h * 0.80;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(tx - w * 0.008, ty, w * 0.016, h * 0.085), const Radius.circular(2)),
      _fill..color = const Color(0xFF110F33),
    );
    canvas.drawCircle(Offset(tx, ty - h * 0.01), w * 0.075, _fill..color = KidsColors.teal700);
    canvas.drawCircle(Offset(tx - w * 0.05, ty + h * 0.015), w * 0.055, _fill..color = KidsColors.teal700);

    // The lantern.
    final lx = w * 0.78, ly = h * 0.735;
    final lit = _lerp(beat.lanternFrom, beat.lanternTo, t);
    if (lit > 0.02) {
      final breathe = 1 + 0.06 * math.sin(amb * 2 * math.pi);
      final rings = lowPower ? 2 : 4;
      for (var i = rings; i >= 1; i--) {
        canvas.drawCircle(Offset(lx, ly), w * 0.05 * (1 + i * 0.7) * breathe, _fill..color = _a(_gold, lit * 0.1));
      }
    }
    canvas.save();
    canvas.translate(lx, ly);
    canvas.drawPath(_lanternBody, _fill..color = Color.lerp(const Color(0xFF3B3590), KidsColors.sun500, lit)!);
    canvas.drawPath(
      _lanternBody,
      _line
        ..color = _a(_cream, 0.55 + 0.4 * lit)
        ..strokeWidth = 2,
    );
    canvas.drawLine(Offset(0, -h * 0.085), Offset(0, -h * 0.11), _line..color = _a(_cream, 0.7));
    canvas.restore();

    // The star's path, its ghosts and the star.
    final p0 = Offset(beat.from.x * w, beat.from.y * h);
    final p1 = Offset(beat.to.x * w, beat.to.y * h);
    final r = w * 0.065;
    if (beat.trail && !lowPower) {
      for (var g = 3; g >= 1; g--) {
        final u = (t - g * 0.12).clamp(0.0, 1.0);
        if (u <= 0 || u >= t) continue;
        final gp = _at(p0, p1, u, h);
        canvas.save();
        canvas.translate(gp.dx, gp.dy);
        canvas.scale(r * (1 - g * 0.14));
        canvas.drawPath(_unitStar, _fill..color = _a(_white, 0.26 - g * 0.05));
        canvas.restore();
      }
    }
    final glow = _lerp(beat.from.glow, beat.to.glow, t);
    final sp = _at(p0, p1, t, h);
    final pulse = 1 + 0.05 * math.sin(amb * 2 * math.pi);
    if (glow > 0.02) {
      final rings = lowPower ? 2 : 5;
      for (var i = rings; i >= 1; i--) {
        canvas.drawCircle(sp, r * (1 + i * 0.55) * pulse, _fill..color = _a(_gold, glow * 0.09));
      }
    }
    canvas.save();
    canvas.translate(sp.dx, sp.dy);
    canvas.scale(r * pulse);
    // A star that has lost its light is a dim lavender, not a different shape.
    canvas.drawPath(_unitStar, _fill..color = Color.lerp(const Color(0xFF5A54A8), KidsColors.sun500, glow)!);
    canvas.drawPath(_unitStarCore, _fill..color = Color.lerp(const Color(0xFF2F2A78), Colors.white, glow)!);
    canvas.restore();
  }

  @override
  bool shouldRepaint(StoryStagePainter old) =>
      !identical(old.beat, beat) || old.lowPower != lowPower || old.move != move || old.ambient != ambient;
}

/// The stage: the girih lattice behind, the painted scene in front.
class StoryStage extends StatelessWidget {
  const StoryStage({super.key, required this.beat, required this.move, required this.ambient, this.lowPower = false});

  final StoryBeat beat;
  final Animation<double> move, ambient;
  final bool lowPower;

  static const PatternSpec _lattice = PatternSpec(family: PatternFamily.girih10, lineWidth: 1, repeat: 5);

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF17143F), Color(0xFF2F2A78), Color(0xFF4B3F8F)],
            ),
          ),
        ),
        // A quiet lattice over the sky; cached, so it costs one drawPicture.
        CustomPaint(
          painter: GeometryPatternPainter(spec: _lattice, color: Colors.white, opacity: .07),
        ),
        CustomPaint(
          painter: StoryStagePainter(beat: beat, move: move, ambient: ambient, lowPower: lowPower),
        ),
      ],
    ),
  );
}
