import 'dart:math' as math;
import 'dart:ui';

import '../core/cinema_shaders.dart';
import '../core/era_skin.dart';
import '../core/rig.dart';
import '../core/shader_uniforms.dart';

/// Minimal procedural rubber-hose character: a bean body with a face,
/// ink-hose arms and legs (quadratic beziers), puffy gloves and big shoes,
/// pie-cut eyes that blink and look around, volume-preserving squash &
/// stretch on a spring, walk/run/jump/hurt/cheer poses and 12 fps line boil.
///
/// Placeholder quality – the rig agent replaces it (and may delete this
/// file). It already shows how a rig uses the contracts: palette roles,
/// [InkStyle], [RigPaintContext.pixelScale] with the halftone material shader
/// through a [ShaderPool], boil seeded by the film clock, paths and paints
/// reset and reused in [paint] (no Path/Paint/shader churn per frame).
class PlaceholderRig implements RigCharacter {
  PlaceholderRig(this.spec);

  @override
  final RigSpec spec;

  RigAction _action = RigAction.idle;
  double _actionTime = 0;
  @override
  RigExpression expression = RigExpression.neutral;
  @override
  double facing = 1;
  @override
  double speed = 0;
  Offset? _look;

  // Squash spring (x = displacement, v = velocity).
  double _sq = 0, _sqV = 0;
  double _cycle = 0;
  double _time = 0;
  double _nextBlink = 2.5;
  double _blink = 0;

  final Path _body = Path();
  final Path _limb = Path();
  final Path _pupil = Path();
  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _shade = Paint();
  final ShaderPool _halftone = ShaderPool(CinemaShader.halftone, maxInstances: 8);
  int _boil = 0;

  @override
  RigAction get action => _action;

  @override
  void act(RigAction action, {bool restart = false}) {
    if (action == _action && !restart) return;
    _action = action;
    _actionTime = 0;
    if (action == RigAction.jump) squash(-0.28);
    if (action == RigAction.land) squash(0.32);
    if (action == RigAction.hurt) squash(0.2);
  }

  @override
  void lookAt(Offset? direction) => _look = direction;

  @override
  void squash(double amount) => _sqV += amount * 14 * spec.bounciness;

  @override
  void update(double dt) {
    _time += dt;
    _actionTime += dt;
    // Critically-under-damped spring back to 0 (rubbery overshoot).
    const k = 260.0, damping = 11.0;
    _sqV += (-k * _sq - damping * _sqV) * dt;
    _sq = (_sq + _sqV * dt).clamp(-0.45, 0.45);
    final cadence = switch (_action) {
      RigAction.run => 13.0,
      RigAction.walk => 8.0,
      _ => 2.2,
    };
    _cycle += dt * cadence;
    _nextBlink -= dt;
    if (_nextBlink <= 0) {
      _blink = 0.14;
      _nextBlink = 2.2 + (math.sin(_time * 7.3) + 1) * 1.6;
    }
    if (_blink > 0) _blink = math.max(0, _blink - dt);
    if (_action == RigAction.land && _actionTime > 0.25) _action = RigAction.idle;
  }

  double _j(int i, double amp) {
    if (amp == 0) return 0;
    var h = (_boil * 374761393 + i * 668265263 + spec.seed * 2246822519) & 0x7fffffff;
    h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff;
    return ((h & 0xffff) / 0xffff - 0.5) * 2 * amp;
  }

  @override
  void paint(Canvas canvas, RigPaintContext ctx) {
    final skin = ctx.skin;
    final pal = skin.palette;
    final ink = skin.ink;
    final h = spec.height;
    final u = h / 100;
    _boil = ctx.clock.boilFrame;
    final boil = ink.boilAmplitude * u;
    final line = ink.lineWidth * u;
    final dir = facing >= 0 ? 1.0 : -1.0;

    // Squash & stretch around the feet, volume preserving.
    final sy = 1 - _sq;
    final sx = 1 / sy.clamp(0.55, 1.6);
    final breathe = _action == RigAction.idle ? math.sin(_time * 2.4) * 0.015 : 0.0;

    final legLen = h * 0.3;
    final bodyH = h * 0.62 * (1 + breathe);
    final bodyW = h * spec.bodyWidth * 0.78;
    final hipY = -legLen;
    final bodyCy = hipY - bodyH * 0.42;
    final lean = (speed / 400).clamp(-0.25, 0.25) * dir;

    canvas
      ..save()
      ..scale(sx, sy);

    // --- legs (behind the body) ---
    _stroke
      ..color = pal.ink
      ..strokeWidth = h * spec.limbWidth;
    final air = _action == RigAction.jump || _action == RigAction.fall;
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      final hip = Offset(side * bodyW * 0.22, hipY);
      Offset foot;
      if (air) {
        foot = Offset(side * h * 0.1 - dir * h * 0.04, -h * 0.07);
      } else if (_action == RigAction.walk || _action == RigAction.run) {
        final ph = _cycle + i * math.pi;
        final stride = _action == RigAction.run ? h * 0.2 : h * 0.13;
        foot = Offset(side * h * 0.06 + math.sin(ph) * stride * dir, -math.max(0.0, math.cos(ph)) * h * 0.1);
      } else {
        foot = Offset(side * h * 0.13, 0);
      }
      final knee = Offset((hip.dx + foot.dx) / 2 + dir * h * 0.07, (hip.dy + foot.dy) / 2);
      _limb
        ..reset()
        ..moveTo(hip.dx + _j(i, boil), hip.dy)
        ..quadraticBezierTo(knee.dx + _j(i + 2, boil), knee.dy + _j(i + 4, boil), foot.dx, foot.dy - h * 0.03);
      canvas.drawPath(_limb, _stroke);
      _shoe(canvas, foot, dir, h, pal, line, boil, i);
    }

    // --- body ---
    canvas
      ..save()
      ..translate(0, hipY)
      ..rotate(lean)
      ..translate(0, -hipY);
    _bean(_body, Offset(0, bodyCy), bodyW, bodyH, boil);
    _fill.color = pal.resolve(spec.fill);
    canvas.drawPath(_body, _fill);
    _shadeBody(canvas, ctx, Offset(0, bodyCy), bodyW, bodyH);
    _stroke
      ..color = pal.ink
      ..strokeWidth = line;
    canvas.drawPath(_body, _stroke);

    // Belt / bow tie accent.
    _fill.color = pal.resolve(spec.accent);
    final tieY = bodyCy + bodyH * 0.3;
    _limb
      ..reset()
      ..moveTo(0, tieY)
      ..lineTo(-h * 0.07, tieY - h * 0.045 + _j(20, boil))
      ..lineTo(-h * 0.07, tieY + h * 0.045)
      ..close()
      ..moveTo(0, tieY)
      ..lineTo(h * 0.07, tieY - h * 0.045)
      ..lineTo(h * 0.07, tieY + h * 0.045 + _j(21, boil))
      ..close();
    canvas
      ..drawPath(_limb, _fill)
      ..drawPath(_limb, _stroke);

    _face(canvas, pal, Offset(dir * bodyW * 0.1, bodyCy - bodyH * 0.2), h, line, boil);

    // --- arms (in front) ---
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      final shoulder = Offset(side * bodyW * 0.44, bodyCy + bodyH * 0.02);
      final armLen = h * spec.limbLength * 0.62;
      Offset hand;
      switch (_action) {
        case RigAction.jump || RigAction.fall:
          hand = shoulder + Offset(side * armLen * 0.55, -armLen * 0.75);
        case RigAction.cheer:
          hand = shoulder + Offset(side * armLen * 0.4, -armLen * (0.8 + 0.15 * math.sin(_time * 12 + i)));
        case RigAction.hurt || RigAction.defeated:
          hand = shoulder + Offset(side * armLen * 0.9, -armLen * 0.2 * math.sin(_time * 20 + i));
        case RigAction.walk || RigAction.run:
          final swing = math.sin(_cycle + i * math.pi + math.pi) * (_action == RigAction.run ? 0.8 : 0.5);
          hand = shoulder + Offset(side * armLen * 0.35 + swing * armLen * 0.6 * dir, armLen * 0.7);
        default:
          hand = shoulder + Offset(side * armLen * 0.45, armLen * (0.72 + 0.05 * math.sin(_time * 2.4 + i)));
      }
      final elbow = Offset((shoulder.dx + hand.dx) / 2 + side * h * 0.08, (shoulder.dy + hand.dy) / 2 + h * 0.03);
      _stroke
        ..color = pal.ink
        ..strokeWidth = h * spec.limbWidth;
      _limb
        ..reset()
        ..moveTo(shoulder.dx, shoulder.dy)
        ..quadraticBezierTo(elbow.dx + _j(30 + i, boil), elbow.dy + _j(32 + i, boil), hand.dx, hand.dy);
      canvas.drawPath(_limb, _stroke);
      if (spec.gloves) _glove(canvas, hand, h, pal, line, boil, i);
    }
    canvas
      ..restore()
      ..restore();
  }

  /// Bean: a slightly pear-shaped blob of 4 cubic segments.
  void _bean(Path p, Offset c, double w, double h, double boil) {
    final rx = w / 2, ry = h / 2;
    const k = 0.5523;
    final top = Offset(c.dx + _j(40, boil), c.dy - ry);
    final right = Offset(c.dx + rx * 1.02 + _j(41, boil), c.dy + ry * 0.12);
    final bottom = Offset(c.dx + _j(42, boil), c.dy + ry);
    final left = Offset(c.dx - rx * 1.02 + _j(43, boil), c.dy + ry * 0.12);
    p
      ..reset()
      ..moveTo(top.dx, top.dy)
      ..cubicTo(top.dx + rx * k * 0.85, top.dy, right.dx, right.dy - ry * k * 1.05, right.dx, right.dy)
      ..cubicTo(right.dx, right.dy + ry * k * 0.9, bottom.dx + rx * k, bottom.dy, bottom.dx, bottom.dy)
      ..cubicTo(bottom.dx - rx * k, bottom.dy, left.dx, left.dy + ry * k * 0.9, left.dx, left.dy)
      ..cubicTo(left.dx, left.dy - ry * k * 1.05, top.dx - rx * k * 0.85, top.dy, top.dx, top.dy)
      ..close();
  }

  void _shadeBody(Canvas canvas, RigPaintContext ctx, Offset c, double w, double h) {
    final skin = ctx.skin;
    if (skin.ink.shading == ShadingMode.flat) return;
    final shader = _halftone.next(ctx.clock);
    canvas
      ..save()
      ..clipPath(_body);
    final from = Offset(c.dx - w * 0.2, c.dy - h * 0.35);
    final to = Offset(c.dx + w * 0.55, c.dy + h * 0.5);
    if (shader != null && skin.ink.shading != ShadingMode.gradient) {
      HalftoneUniforms.write(
        shader,
        from: from,
        to: to,
        ink: skin.palette.shadow,
        style: skin.halftone,
        toneFrom: -0.4,
        toneTo: skin.ink.shadeStrength * 1.3,
        boilFrame: ctx.clock.boilFrame,
        pixelScale: ctx.pixelScale,
      );
      _shade.shader = shader;
    } else {
      _shade.shader = Gradient.linear(from, to, [
        skin.palette.shadow.withValues(alpha: 0),
        skin.palette.shadow.withValues(alpha: skin.ink.shadeStrength),
      ]);
    }
    canvas
      ..drawRect(Rect.fromCenter(center: c, width: w * 1.4, height: h * 1.2), _shade)
      ..restore();
  }

  void _face(Canvas canvas, EraPalette pal, Offset c, double h, double line, double boil) {
    final eyeW = h * 0.085, eyeH = h * 0.14;
    final blink = _blink > 0 ? 0.12 : 1.0;
    final look = _look ?? Offset(facing * 0.4, 0);
    final len = look.distance;
    final lk = len > 1 ? look / len : look;
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      final ec = c + Offset(side * eyeW * 0.62, 0);
      final eye = Rect.fromCenter(center: ec, width: eyeW, height: eyeH * blink);
      _fill.color = pal.highlight;
      canvas.drawOval(eye, _fill);
      _stroke
        ..color = pal.ink
        ..strokeWidth = line * 0.7;
      canvas.drawOval(eye, _stroke);
      if (blink < 1) continue;
      // Pie-cut pupil: an oval with a wedge taken out (the 1930s eye).
      final pc = ec + Offset(lk.dx * eyeW * 0.2, lk.dy * eyeH * 0.2 + eyeH * 0.12);
      final pr = Rect.fromCenter(center: pc, width: eyeW * 0.56, height: eyeH * 0.6);
      final wedge = expression == RigExpression.surprised ? 0.2 : 0.55;
      _pupil
        ..reset()
        ..moveTo(pc.dx, pc.dy)
        ..arcTo(pr, -math.pi / 3 + wedge / 2, math.pi * 2 - wedge, false)
        ..close();
      _fill.color = pal.ink;
      canvas.drawPath(_pupil, _fill);
    }
    // Nose and mouth.
    _fill.color = pal.ink;
    canvas.drawOval(Rect.fromCenter(center: c + Offset(facing * h * 0.02, eyeH * 0.62), width: h * 0.07, height: h * 0.05), _fill);
    final m = c + Offset(facing * h * 0.015, eyeH * 0.95);
    _stroke
      ..color = pal.ink
      ..strokeWidth = line * 0.8;
    final smile = switch (expression) {
      RigExpression.happy || RigExpression.determined => 1.0,
      RigExpression.angry || RigExpression.scared => -0.6,
      RigExpression.surprised => 0.0,
      _ => 0.55,
    };
    _limb
      ..reset()
      ..moveTo(m.dx - h * 0.09, m.dy - smile * h * 0.01)
      ..quadraticBezierTo(m.dx + _j(50, boil), m.dy + smile * h * 0.07, m.dx + h * 0.09, m.dy - smile * h * 0.01);
    canvas.drawPath(_limb, _stroke);
  }

  void _glove(Canvas canvas, Offset hand, double h, EraPalette pal, double line, double boil, int i) {
    final r = h * 0.062;
    final c = hand + Offset(_j(60 + i, boil) * 0.5, r * 0.3);
    _fill.color = pal.resolve(spec.trim);
    _stroke
      ..color = pal.ink
      ..strokeWidth = line * 0.8;
    final palm = Rect.fromCircle(center: c, radius: r);
    canvas
      ..drawOval(palm, _fill)
      ..drawOval(palm, _stroke);
    final cuff = Rect.fromCenter(center: hand - Offset(0, r * 0.55), width: r * 1.5, height: r * 0.7);
    canvas
      ..drawOval(cuff, _fill)
      ..drawOval(cuff, _stroke);
  }

  void _shoe(Canvas canvas, Offset foot, double dir, double h, EraPalette pal, double line, double boil, int i) {
    if (!spec.shoes) return;
    final shoe = Rect.fromLTWH(
      foot.dx - h * 0.07 + dir * h * 0.035 + _j(70 + i, boil) * 0.4,
      foot.dy - h * 0.075,
      h * 0.17,
      h * 0.08,
    );
    _fill.color = pal.ink;
    canvas.drawOval(shoe, _fill);
    _fill.color = pal.highlight;
    canvas.drawOval(
      Rect.fromCenter(center: shoe.center + Offset(dir * h * 0.035, -h * 0.015), width: h * 0.04, height: h * 0.018),
      _fill,
    );
  }

  @override
  Rect get bounds {
    final h = spec.height;
    return Rect.fromLTRB(-h * 0.45, -h * 1.05, h * 0.45, 0);
  }

  @override
  void dispose() => _halftone.dispose();
}
