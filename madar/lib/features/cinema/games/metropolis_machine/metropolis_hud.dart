import 'dart:math' as math;
import 'dart:ui';

import '../../engine/cinema_engine.dart';
import '../../engine/stage/stage_kit.dart' show HudPlaque;

// On-screen control hints in the house HUD style: a brass run pad with two
// arrows (the lit side is the one held), a round jump button and a wrench
// button for the strike. They only paint – the game reads the touch zones
// itself – so they never swallow a tap.

/// What the hints read each frame.
abstract interface class MetroControlState {
  /// Held run direction −1 / 0 / 1.
  double get moveHeld;
  bool get jumpHeld;
  bool get strikeLit;
  bool get dashLit;
}

class RunPadHint extends HudItem {
  RunPadHint(this.state);

  final MetroControlState state;
  final HudPlaque _plaque = HudPlaque();
  final Paint _fill = Paint();
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Path _path = Path();
  double _lit = 0;

  @override
  Size layoutSize(HudContext ctx) => Size(132 * ctx.scale, 54 * ctx.scale);

  @override
  void update(double dt, HudContext ctx) {
    final target = state.moveHeld.abs() > 0 ? 1.0 : 0.0;
    _lit += (target - _lit) * math.min(1, dt * 18);
  }

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    final pal = ctx.skin.palette;
    final s = ctx.scale;
    _plaque.paint(canvas, rect, ctx, round: true);
    final held = state.moveHeld;
    for (final side in const [-1.0, 1.0]) {
      final cx = rect.center.dx + side * rect.width * 0.24;
      final cy = rect.center.dy;
      final on = held.sign == side && held != 0;
      final r = 12 * s;
      _path
        ..reset()
        ..moveTo(cx + side * r, cy)
        ..lineTo(cx - side * r * 0.6, cy - r * 0.9)
        ..lineTo(cx - side * r * 0.25, cy)
        ..lineTo(cx - side * r * 0.6, cy + r * 0.9)
        ..close();
      _fill.color = on ? pal.ink : pal.ink.withValues(alpha: 0.35);
      canvas.drawPath(_path, _fill);
      if (on) {
        _line
          ..color = pal.highlight.withValues(alpha: 0.9)
          ..strokeWidth = 2 * s;
        canvas.drawCircle(Offset(cx, cy), r * 1.5, _line);
      }
    }
    // A divider rivet.
    _fill.color = pal.ink.withValues(alpha: 0.6);
    canvas.drawCircle(rect.center, 3 * s, _fill);
  }
}

class JumpButtonHint extends HudItem {
  JumpButtonHint(this.state);

  final MetroControlState state;
  final HudPlaque _plaque = HudPlaque();
  final Paint _fill = Paint();
  final Path _path = Path();

  @override
  Size layoutSize(HudContext ctx) => Size.square(56 * ctx.scale);

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    final pal = ctx.skin.palette;
    final s = ctx.scale;
    final pressed = state.jumpHeld;
    final r = pressed ? rect.deflate(3 * s) : rect;
    _plaque.paint(canvas, r, ctx, round: true, flash: pressed ? 0.6 : 0);
    final c = r.center, k = 11 * s;
    _path
      ..reset()
      ..moveTo(c.dx, c.dy - k)
      ..lineTo(c.dx + k * 0.9, c.dy + k * 0.1)
      ..lineTo(c.dx + k * 0.35, c.dy + k * 0.1)
      ..lineTo(c.dx + k * 0.35, c.dy + k)
      ..lineTo(c.dx - k * 0.35, c.dy + k)
      ..lineTo(c.dx - k * 0.35, c.dy + k * 0.1)
      ..lineTo(c.dx - k * 0.9, c.dy + k * 0.1)
      ..close();
    _fill.color = pal.ink.withValues(alpha: pressed ? 1 : 0.75);
    canvas.drawPath(_path, _fill);
  }
}

class WrenchButtonHint extends HudItem {
  WrenchButtonHint(this.state);

  final MetroControlState state;
  final HudPlaque _plaque = HudPlaque();
  final Paint _fill = Paint();
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Path _path = Path();

  @override
  Size layoutSize(HudContext ctx) => Size.square(56 * ctx.scale);

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    final pal = ctx.skin.palette;
    final s = ctx.scale;
    final lit = state.strikeLit;
    final r = lit ? rect.deflate(3 * s) : rect;
    _plaque.paint(canvas, r, ctx, round: true, flash: lit ? 0.6 : 0);
    final c = r.center, k = 12 * s;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(-0.75);
    _line
      ..color = pal.ink.withValues(alpha: lit ? 1 : 0.8)
      ..strokeWidth = 4.5 * s;
    canvas.drawLine(Offset(-k * 0.8, 0), Offset(k * 0.45, 0), _line);
    _path
      ..reset()
      ..moveTo(k * 0.3, -k * 0.55)
      ..lineTo(k * 0.95, -k * 0.6)
      ..lineTo(k * 1.1, -k * 0.2)
      ..lineTo(k * 0.8, -k * 0.1)
      ..lineTo(k * 0.8, k * 0.1)
      ..lineTo(k * 1.1, k * 0.2)
      ..lineTo(k * 0.95, k * 0.6)
      ..lineTo(k * 0.3, k * 0.55)
      ..close();
    _fill.color = pal.ink.withValues(alpha: lit ? 1 : 0.8);
    canvas.drawPath(_path, _fill);
    canvas.drawCircle(Offset(-k * 0.85, 0), k * 0.28, _fill);
    canvas.restore();
    if (state.dashLit) {
      _line
        ..color = pal.highlight.withValues(alpha: 0.9)
        ..strokeWidth = 2 * s;
      canvas.drawCircle(c, r.width * 0.5, _line);
    }
  }
}
