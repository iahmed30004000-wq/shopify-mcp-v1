import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../../core/domain/enums.dart';
import 'astrolabe_cache.dart';
import 'astrolabe_controller.dart';
import 'astrolabe_geometry.dart';
import 'astrolabe_palette.dart';
import 'astrolabe_paths.dart';
import 'astrolabe_shaders.dart';
import 'astrolabe_state.dart';

/// Paints the astrolabe centrepiece: halo, enamel plate with girih and the
/// stereographic horizon, the brass limb with its 24-hour scale, the five
/// prayer pointers (engraved / breathing / ignited / dimmed), the rotating
/// rete with its star pointers and the sun marker, the current window's lit
/// arc, the hub ring with the engraved countdown, the core star and the
/// prayer fires.
///
/// Driven entirely by [controller] (and [repaint]): the widget never rebuilds
/// per frame. Everything static is replayed from [cache]; per frame it only
/// sets shader uniforms on the reused [shaders] and draws cached paths.
class AstrolabePainter extends CustomPainter {
  AstrolabePainter({
    required this.controller,
    required this.palette,
    required this.cache,
    this.shaders,
    this.devicePixelRatio = 1,
    this.makersMark,
    Listenable? repaint,
  }) : super(repaint: repaint == null ? controller : Listenable.merge([controller, repaint]));

  final AstrolabeController controller;
  final AstrolabePalette palette;
  final AstrolabeRenderCache cache;

  /// Reused shader instances; null → gradient fallbacks (shaders unavailable).
  final AstrolabeShaderSet? shaders;
  final double devicePixelRatio;

  /// Engraved on the lower half of the hub ring (large dials).
  final String? makersMark;

  // Reused per-frame objects.
  final Paint _brassPaint = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _fill = Paint();
  final Paint _glow = Paint()..blendMode = BlendMode.plus;
  final Paint _shaderPaint = Paint();
  final Paint _arc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  Path? _hubPath;
  double _hubKey = -1;
  AstrolabeTilt? _tiltKey;
  double _tiltRadius = -1;
  Float64List? _tiltStorage;
  AstrolabeState? _textState;
  String _countdown = '';

  static const _prayers = AstrolabeGeometry.prayers;

  @override
  void paint(Canvas canvas, Size size) {
    final state = controller.state;
    if (state == null || cache.isDisposed) return;
    final radius = AstrolabeGeometry.radiusFor(size);
    if (radius < 6) return;
    final bucket = AstrolabeRenderCache.bucketFor(radius);
    final lod = AstrolabeGeometry.lodFor(bucket);
    cache
      ..ensureStatic(bucket: bucket, lod: lod, palette: palette, labels: state.labels)
      ..ensurePrayers(state: state, palette: palette);
    final r = bucket;
    final k = radius / bucket;
    final px = math.max(0.6, r / 260);

    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2);
    final tilt = controller.tilt;
    if (!tilt.isFlat) canvas.transform(_tiltFor(tilt, radius));
    canvas.scale(k);

    _halo(canvas, r);
    _plate(canvas, state, r, px);
    _limb(canvas, r, px);
    _pointers(canvas, state, r, px);
    _rete(canvas, state, r, px);
    _labels(canvas);
    _litArc(canvas, state, r);
    _hub(canvas, state, r, px, k);
    _coreStar(canvas, state, r);
    _fires(canvas, state, r, k);
    canvas.restore();
  }

  Float64List _tiltFor(AstrolabeTilt tilt, double radius) {
    final cached = _tiltStorage;
    if (cached != null && tilt == _tiltKey && radius == _tiltRadius) return cached;
    _tiltKey = tilt;
    _tiltRadius = radius;
    return _tiltStorage = AstrolabeGeometry.tiltMatrix(Offset.zero, radius, tilt).storage;
  }

  // ------------------------------------------------------------------ brass

  /// Loads the brass uniforms (light in the current canvas frame) into the
  /// shared brass paint, or the gradient fallback.
  Paint _brass(double r, Offset light, double wear) {
    final set = shaders;
    if (set == null) return cache.fallbackBrassPaint;
    final s = set.brass;
    var i = 0;
    void f(double v) => s.setFloat(i++, v);
    f(0);
    f(0);
    f(0);
    f(0);
    f(r);
    f(light.dx);
    f(light.dy);
    f(controller.time);
    f(wear);
    for (final c in [palette.brass, palette.brassHi, palette.brassLow]) {
      f(c.r);
      f(c.g);
      f(c.b);
      f(1);
    }
    return _brassPaint..shader = s;
  }

  double _wear(AstrolabeState state) => (((0.74 - state.balance) / 0.56).clamp(0.0, 1.0)) * 0.85;

  static Offset _rot(Offset v, double a) {
    final c = math.cos(a), s = math.sin(a);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  // ------------------------------------------------------------------ layers

  void _halo(Canvas canvas, double r) {
    canvas.drawCircle(Offset.zero, r * AstrolabeRadii.halo, cache.haloPaint);
  }

  void _plate(Canvas canvas, AstrolabeState state, double r, double px) {
    final plateR = r * AstrolabeRadii.limbInner;
    canvas
      ..drawCircle(Offset.zero, plateR, cache.platePaint)
      ..drawCircle(Offset.zero, plateR, cache.plateSheenPaint);
    final plate = cache.plateInk;
    if (plate != null) canvas.drawPicture(plate);
    final almu = cache.ensureAlmucantars(palette, state.sky.latitude);
    canvas
      ..save()
      ..rotate(state.sky.plateRotation)
      ..drawPicture(almu)
      ..restore()
      // the raised limb shades the plate's rim
      ..drawCircle(Offset.zero, plateR, cache.limbShadowPaint);
  }

  void _limb(Canvas canvas, double r, double px) {
    final state = controller.state!;
    final light = controller.light;
    canvas.drawPath(cache.limbPath, _brass(r, light, _wear(state)));
    final ink = cache.limbInk;
    if (ink != null) canvas.drawPicture(ink);
    _bevel(canvas, r * 0.994, r * 0.011, light, outer: true);
    _bevel(canvas, r * (AstrolabeRadii.limbInner + 0.006), r * 0.01, light, outer: false);
    _bevel(canvas, r * (AstrolabeRadii.scaleInner - 0.004), r * 0.005, light, outer: false, strength: 0.45);
  }

  /// A chamfer highlight around a circle: bright where it faces [light].
  void _bevel(Canvas canvas, double radius, double width, Offset light, {required bool outer, double strength = 1}) {
    final a = math.atan2(light.dy, light.dx) + (outer ? 0 : math.pi);
    cache.bevelPaint
      ..strokeWidth = width
      ..color = Color.fromRGBO(0, 0, 0, strength);
    canvas
      ..save()
      ..rotate(a)
      ..drawCircle(Offset.zero, radius, cache.bevelPaint)
      ..restore();
  }

  void _pointers(Canvas canvas, AstrolabeState state, double r, double px) {
    final t = controller.time;
    final light = controller.light;
    for (var i = 0; i < _prayers.length; i++) {
      final p = _prayers[i];
      final path = cache.pointerPaths[p];
      final center = cache.pointerCenters[p];
      if (path == null || center == null) continue;
      final ign = controller.ignition(p);
      final status = state.statusOf(p);
      // soft shadow under the raised star
      canvas.drawPath(path.shift(Offset(px * 0.8, px * 1.2)), _fill..color = palette.shadow.withValues(alpha: 0.55));
      switch (status) {
        case AstrolabePrayerStatus.prayed:
          final g = ign.clamp(0.0, 1.0);
          _glowAt(canvas, center, g * 0.9, r * 0.1 / (r * 0.1));
          canvas.drawPath(path, _brass(r, light, 0));
          canvas.drawPath(path, _glow..color = palette.litHead.withValues(alpha: 0.5 * g));
          canvas.drawPath(path, _stroke
            ..strokeWidth = px * 0.9
            ..color = Color.lerp(palette.ink, palette.brassHi, g)!.withValues(alpha: 0.9));
        case AstrolabePrayerStatus.due:
          final b = controller.reducedMotion ? 0.8 : 0.55 + 0.45 * math.sin(t * 2.3 + i);
          _glowAt(canvas, center, 0.28 + 0.3 * b, 1);
          canvas.drawPath(path, _fill..color = palette.brass.withValues(alpha: 0.45));
          canvas.drawPath(path, _stroke
            ..strokeWidth = px * 1.2
            ..color = palette.labelDue.withValues(alpha: 0.65 + 0.35 * b));
        case AstrolabePrayerStatus.upcoming:
          canvas.drawPath(path, _fill..color = palette.enamelMid.withValues(alpha: 0.9));
          canvas.drawPath(path, _stroke
            ..strokeWidth = px * 1.05
            ..color = palette.plateLine.withValues(alpha: 0.85));
        case AstrolabePrayerStatus.missed:
          canvas.drawPath(path, _fill..color = palette.enamelEdge.withValues(alpha: 0.9));
          canvas.drawPath(path, _stroke
            ..strokeWidth = px * 0.9
            ..color = palette.labelMissed.withValues(alpha: 0.55));
      }
      // engraved centre ring
      canvas.drawCircle(center, r * AstrolabeRadii.pointerStar * 0.28, _stroke
        ..strokeWidth = px * 0.7
        ..color = (status == AstrolabePrayerStatus.prayed ? palette.ink : palette.plateLine).withValues(alpha: 0.6));
    }
  }

  void _glowAt(Canvas canvas, Offset at, double alpha, double scale) {
    if (alpha <= 0.002) return;
    cache.pointerGlowPaint.color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(scale)
      ..drawCircle(Offset.zero, cache.rb * 0.1, cache.pointerGlowPaint)
      ..restore();
  }

  void _rete(Canvas canvas, AstrolabeState state, double r, double px) {
    final theta = state.sky.reteRotation;
    final light = controller.light;
    final shadowOffset = _rot(Offset(-light.dx, -light.dy) * (r * 0.011), -theta);
    final ringW = r * ReteModel.ringWidth;
    final eclW = r * ReteModel.eclipticWidth;
    final strapW = r * ReteModel.strapWidth;
    canvas
      ..save()
      ..rotate(theta);

    // Cast shadow on the plate (the rete floats above it).
    final shadow = palette.shadow.withValues(alpha: palette.light ? 0.5 : 0.62);
    canvas
      ..save()
      ..translate(shadowOffset.dx, shadowOffset.dy);
    _stroke.color = shadow;
    canvas
      ..drawPath(cache.reteRings, _stroke..strokeWidth = ringW)
      ..drawPath(cache.reteEcliptic, _stroke..strokeWidth = eclW)
      ..drawPath(cache.reteStraps, _stroke..strokeWidth = strapW)
      ..drawPath(cache.reteFlames, _fill..color = shadow)
      ..restore();

    // Dark outline, then the brass itself.
    final outline = palette.ink.withValues(alpha: 0.9);
    _stroke.color = outline;
    canvas
      ..drawPath(cache.reteRings, _stroke..strokeWidth = ringW + px * 1.6)
      ..drawPath(cache.reteEcliptic, _stroke..strokeWidth = eclW + px * 1.6)
      ..drawPath(cache.reteStraps, _stroke..strokeWidth = strapW + px * 1.6)
      ..drawPath(cache.reteFlames, _stroke..strokeWidth = px * 1.6);
    final brass = _brass(r, _rot(light, -theta), _wear(state) * 0.8);
    brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringW;
    canvas.drawPath(cache.reteRings, brass);
    brass.strokeWidth = eclW;
    canvas.drawPath(cache.reteEcliptic, brass);
    brass.strokeWidth = strapW;
    canvas.drawPath(cache.reteStraps, brass);
    // weave: the over strand crosses on top with its own dark edges
    brass.strokeCap = StrokeCap.butt;
    canvas
      ..drawPath(cache.reteOvers, _stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = strapW + px * 3.2
        ..color = outline)
      ..drawPath(cache.reteOvers, brass);
    // engraved groove down the middle of every strap
    _stroke
      ..strokeWidth = strapW * 0.22
      ..color = palette.ink.withValues(alpha: 0.55);
    canvas
      ..drawPath(cache.reteStraps, _stroke)
      ..drawPath(cache.reteOvers, _stroke);
    brass.style = PaintingStyle.fill;
    canvas.drawPath(cache.reteFlames, brass);
    final ink = cache.reteInk;
    if (ink != null) canvas.drawPicture(ink);

    // The stars themselves: tiny jewels at the pointer tips.
    if (cache.lod >= AstrolabeLod.medium) {
      final stars = AstrolabePaths.rete().stars;
      final tw = controller.reducedMotion ? 0.0 : controller.time;
      for (var i = 0; i < stars.length; i++) {
        final a = 0.7 + 0.3 * math.sin(tw * 1.3 + i * 2.1);
        cache.starJewelPaint.color = Color.fromRGBO(0, 0, 0, a);
        final tip = stars[i].tip * r;
        canvas
          ..save()
          ..translate(tip.dx, tip.dy)
          ..scale(r * 0.02)
          ..drawCircle(Offset.zero, 1, cache.starJewelPaint)
          ..restore();
      }
    }
    canvas.restore();

    // Sun marker (upright glyph at the rete's sun position).
    final sun = _rot(state.sky.sunReteLocal * r, theta);
    final almu = AstrolabeProjection.almucantar(0, state.sky.latitude);
    final hc = _rot(almu.center * r, state.sky.plateRotation);
    final above = (sun - hc).distance < almu.radius * r;
    final sunR = r * 0.034;
    cache.sunGlowPaint.color = Color.fromRGBO(0, 0, 0, above ? 1 : 0.45);
    canvas
      ..save()
      ..translate(sun.dx, sun.dy)
      ..drawCircle(Offset.zero, sunR * 3.6, cache.sunGlowPaint)
      ..drawPath(cache.sunRays.shift(Offset(px * 0.7, px * 1.0)), _fill..color = palette.shadow.withValues(alpha: 0.5))
      ..rotate(controller.reducedMotion ? 0 : controller.time * 0.06)
      ..drawPath(cache.sunRays, cache.sunRayPaint)
      ..drawPath(cache.sunRays, _stroke
        ..strokeWidth = px * 0.6
        ..color = palette.ink.withValues(alpha: 0.55))
      ..drawCircle(Offset.zero, sunR, cache.sunDiscPaint)
      ..drawCircle(Offset.zero, sunR, _stroke
        ..strokeWidth = px * 0.8
        ..color = palette.ink.withValues(alpha: 0.6))
      ..drawCircle(Offset.zero, sunR * 0.55, _stroke
        ..strokeWidth = px * 0.6
        ..color = palette.brassLow.withValues(alpha: 0.45))
      ..restore();
  }

  void _labels(Canvas canvas) {
    final labels = cache.labels;
    if (labels != null) canvas.drawPicture(labels);
  }

  void _litArc(Canvas canvas, AstrolabeState state, double r) {
    final w = state.window;
    final arc = AstrolabeGeometry.arc(w.start, w.end);
    if (arc.sweep <= 0) return;
    final progress = AstrolabeGeometry.arcProgress(w.start, w.end, state.now);
    final rect = Rect.fromCircle(center: Offset.zero, radius: r * AstrolabeRadii.channel);
    final done = arc.sweep * progress;
    const layers = <(double, double)>[(0.07, 0.07), (0.04, 0.14), (0.02, 0.4), (0.009, 0.75), (0.0038, 1.0)];
    for (var i = 0; i < layers.length; i++) {
      final (width, alpha) = layers[i];
      final core = i == layers.length - 1;
      final color = core ? palette.litHead : palette.litArc;
      if (arc.sweep - done > 1e-4) {
        _arc
          ..strokeWidth = r * width * 0.8
          ..color = color.withValues(alpha: alpha * 0.38);
        canvas.drawArc(rect, arc.start + done, arc.sweep - done, false, _arc);
      }
      if (done > 1e-4) {
        _arc
          ..strokeWidth = r * width
          ..color = color.withValues(alpha: alpha);
        canvas.drawArc(rect, arc.start, done, false, _arc);
      }
    }
    // Luminous head at "now".
    final a = arc.start + done;
    final head = Offset(math.cos(a), math.sin(a)) * (r * AstrolabeRadii.channel);
    final breathe = controller.reducedMotion ? 1.0 : 0.9 + 0.1 * math.sin(controller.time * 2.1);
    cache.headGlowPaint.color = const Color(0xFF000000);
    canvas
      ..save()
      ..translate(head.dx, head.dy)
      ..scale(breathe)
      ..drawCircle(Offset.zero, r * 0.075, cache.headGlowPaint)
      ..restore()
      ..drawCircle(head, r * 0.0085, _glow..color = palette.litHead);
  }

  void _hub(Canvas canvas, AstrolabeState state, double r, double px, double k) {
    final outer = cache.hubOuter;
    final inner = cache.hubInner;
    if (_hubKey != inner || _hubPath == null) {
      _hubKey = inner;
      _hubPath = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: outer))
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: inner));
    }
    final light = controller.light;
    // the core star's warm light spilling over the rete
    cache.starLightPaint.color = Color.fromRGBO(0, 0, 0, 0.35 + 0.65 * state.balance.clamp(0.0, 1.0));
    canvas.drawCircle(Offset.zero, r * 0.66, cache.starLightPaint);
    canvas
      ..drawCircle(Offset.zero, outer + r * 0.05, cache.hubShadowPaint)
      ..drawCircle(Offset.zero, inner, cache.hubWindowPaint)
      ..drawPath(_hubPath!, _brass(r, light, _wear(state)));
    _stroke
      ..strokeWidth = px * 0.8
      ..color = palette.ink.withValues(alpha: 0.7);
    canvas
      ..drawCircle(Offset.zero, outer - px * 0.6, _stroke)
      ..drawCircle(Offset.zero, inner + px * 0.5, _stroke);
    _bevel(canvas, outer - r * 0.004, r * 0.007, light, outer: true, strength: 0.8);
    _bevel(canvas, inner + r * 0.003, r * 0.005, light, outer: false, strength: 0.7);

    if (cache.lod < AstrolabeLod.medium) return;
    if (!identical(state, _textState)) {
      _textState = state;
      _countdown = state.countdown;
    }
    final remaining = state.window.nextPrayerAt.difference(state.now);
    final urgency = remaining.inSeconds <= 0 ? 1.0 : (1 - remaining.inSeconds / 900).clamp(0.0, 1.0);
    final image = cache.ensureCountdown(_countdown, state.labels, devicePixelRatio * k);
    _ringText(canvas, shaders?.countdown, image, cache.countdownScale, inner, outer, top: true,
        ink: palette.ink, glow: palette.engraveHi, glowAmount: 0.08 + 0.5 * urgency, state: state);
    final mark = makersMark;
    if (mark != null && mark.isNotEmpty && cache.lod >= AstrolabeLod.full) {
      final img = cache.ensureMark(mark, state.labels, devicePixelRatio * k);
      _ringText(canvas, shaders?.mark, img, cache.markScale, inner, outer, top: false,
          ink: Color.lerp(palette.ink, palette.brass, 0.3)!, glow: palette.engraveHi, glowAmount: 0, state: state);
    }
  }

  void _ringText(
    Canvas canvas,
    ui.FragmentShader? s,
    ui.Image image,
    double scale,
    double inner,
    double outer, {
    required bool top,
    required Color ink,
    required Color glow,
    required double glowAmount,
    required AstrolabeState state,
  }) {
    final wLogical = image.width / scale;
    final mid = (inner + outer) / 2;
    final sweep = math.min(wLogical / mid, math.pi * 1.3);
    if (s == null) {
      // Fallback: the text image drawn flat across the top/bottom of the ring.
      final h = image.height / scale;
      final dst = Rect.fromCenter(center: Offset(0, top ? -mid : mid), width: wLogical, height: h);
      canvas.drawImageRect(image, Offset.zero & Size(image.width.toDouble(), image.height.toDouble()), dst,
          _fill..colorFilter = ColorFilter.mode(ink, BlendMode.srcIn));
      _fill.colorFilter = null;
      return;
    }
    var i = 0;
    void f(double v) => s.setFloat(i++, v);
    f(0);
    f(0);
    f(0);
    f(0);
    f(inner);
    f(outer);
    f(top ? math.pi / 2 + sweep / 2 : -math.pi / 2 + sweep / 2);
    f(sweep);
    f(image.width.toDouble());
    f(image.height.toDouble());
    for (final c in [ink, glow]) {
      f(c.r);
      f(c.g);
      f(c.b);
      f(1);
    }
    f(glowAmount);
    s.setImageSampler(0, image, filterQuality: FilterQuality.medium);
    canvas.drawCircle(Offset.zero, outer + 2, _shaderPaint..shader = s);
  }

  void _coreStar(Canvas canvas, AstrolabeState state, double r) {
    final rs = r * AstrolabeRadii.coreStar;
    final set = shaders;
    if (set == null) {
      canvas.drawCircle(Offset.zero, rs * 3, cache.fallbackStarPaint);
      return;
    }
    final s = set.star;
    var i = 0;
    void f(double v) => s.setFloat(i++, v);
    f(0);
    f(0);
    f(0);
    f(0);
    f(rs);
    f(controller.time);
    f(state.balance.clamp(0.0, 1.0));
    f(controller.pulse);
    for (final c in [palette.starCore, palette.starCorona]) {
      f(c.r);
      f(c.g);
      f(c.b);
      f(1);
    }
    canvas.drawRect(Rect.fromCircle(center: Offset.zero, radius: rs * 4), _shaderPaint..shader = s);
  }

  void _fires(Canvas canvas, AstrolabeState state, double r, double k) {
    final set = shaders;
    for (var i = 0; i < _prayers.length; i++) {
      final p = _prayers[i];
      final ign = controller.ignition(p);
      if (ign <= 0.001) continue;
      final tip = cache.pointerTips[p];
      if (tip == null) continue;
      final a = AstrolabeGeometry.angleForFraction(state.fractionOf(p));
      final height = math.max(r * 0.15, 20 / k);
      // Flames rise, leaning a little outward with the pointer.
      final angle = -math.pi / 2 + math.cos(a) * 0.22;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final root = tip - Offset(math.cos(a), math.sin(a)) * (r * 0.012);
      if (set == null) {
        _fallbackFlame(canvas, root, dir, height, ign);
        continue;
      }
      final s = set.fire;
      var j = 0;
      void f(double v) => s.setFloat(j++, v);
      f(0);
      f(0);
      f(root.dx);
      f(root.dy);
      f(angle);
      f(height);
      f(controller.time + i * 1.37);
      f(ign);
      for (final c in [palette.fireOuter, palette.fireInner]) {
        f(c.r);
        f(c.g);
        f(c.b);
        f(1);
      }
      canvas.drawRect(Rect.fromCircle(center: root + dir * (height * 0.4), radius: height * 0.95), _shaderPaint..shader = s);
    }
  }

  void _fallbackFlame(Canvas canvas, Offset root, Offset dir, double height, double ign) {
    cache.fallbackFirePaint.color = Color.fromRGBO(0, 0, 0, ign.clamp(0.0, 1.0));
    final c = root + dir * (height * 0.35);
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..scale(height * 0.28, height * 0.45)
      ..drawCircle(Offset.zero, 1, cache.fallbackFirePaint)
      ..restore();
  }

  @override
  bool shouldRepaint(AstrolabePainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.palette != palette ||
      oldDelegate.cache != cache ||
      oldDelegate.shaders != shaders ||
      oldDelegate.devicePixelRatio != devicePixelRatio ||
      oldDelegate.makersMark != makersMark;

  /// Prayer under a position of the paint box (see
  /// [AstrolabeGeometry.hitTestPrayer]).
  Prayer? prayerAt(Offset local, Size size) {
    final state = controller.state;
    if (state == null) return null;
    final k = AstrolabeGeometry.radiusFor(size) / (cache.rb == 0 ? 1 : cache.rb);
    return AstrolabeGeometry.hitTestPrayer(
      local,
      size: size,
      fractions: state.fractions,
      labelAngles: cache.labelAngles.map((p, a) => MapEntry(p, a)),
      tilt: controller.tilt,
      minTouchRadius: 22 / (k == 0 ? 1 : 1),
    );
  }
}
