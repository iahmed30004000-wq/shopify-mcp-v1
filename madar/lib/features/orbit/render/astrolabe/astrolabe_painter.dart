import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show SemanticsProperties;
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
/// sets shader uniforms on the reused [shaders] and draws cached paths with
/// reused paints (no paths, paints, shaders or lists are created per frame).
class AstrolabePainter extends CustomPainter {
  AstrolabePainter({
    required this.controller,
    required this.palette,
    required this.cache,
    this.shaders,
    this.devicePixelRatio = 1,
    this.makersMark,
    this.semanticsState,
    this.onPrayerTap,
    Listenable? repaint,
  }) : _ink = _Inks(palette),
       super(repaint: repaint == null ? controller : Listenable.merge([controller, repaint]));

  final AstrolabeController controller;
  final AstrolabePalette palette;
  final AstrolabeRenderCache cache;

  /// Reused shader instances; null → gradient fallbacks (shaders unavailable).
  final AstrolabeShaderSet? shaders;
  final double devicePixelRatio;

  /// Engraved on the lower half of the hub ring (large dials).
  final String? makersMark;

  /// The state the prayer pointers' semantics nodes describe (null: no
  /// per-prayer nodes).
  final AstrolabeState? semanticsState;

  /// Tapping a prayer pointer or its name (also the semantics tap action).
  /// Without it the painter lets every pointer event through.
  final ValueChanged<Prayer>? onPrayerTap;

  final _Inks _ink;
  Size _size = Size.zero;

  // Reused per-frame objects.
  final _Uniforms _u = _Uniforms();
  final Paint _brassPaint = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _fill = Paint();
  final Paint _glow = Paint()..blendMode = BlendMode.plus;
  final Paint _shaderPaint = Paint();
  final Paint _textPaint = Paint();
  final Paint _arc = Paint()
    ..style = PaintingStyle.stroke
    ..blendMode = BlendMode.plus;
  AstrolabeTilt? _tiltKey;
  double _tiltRadius = -1;
  Float64List? _tiltStorage;
  AstrolabeState? _textState;
  _HubText? _hubText;
  ui.Image? _boundCountdown;
  ui.Image? _boundMark;

  static const _prayers = AstrolabeGeometry.prayers;

  /// Shader clocks wrap (in double precision) before they become float32
  /// uniforms: hours-long sessions keep smooth flames and glints.
  static const double _timeWrap = 7200;

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    final state = controller.state;
    if (state == null || cache.isDisposed) return;
    final radius = AstrolabeGeometry.radiusFor(size);
    if (radius < 6) return;
    final bucket = AstrolabeRenderCache.bucketFor(radius);
    final lod = AstrolabeGeometry.lodFor(bucket);
    cache
      ..ensureStatic(bucket: bucket, lod: lod, palette: palette, labels: state.labels)
      ..ensurePrayers(state: state, palette: palette)
      ..ensureWindow(state);
    final r = bucket;
    final k = radius / bucket;
    final px = cache.px;

    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2);
    final tilt = controller.tilt;
    if (!tilt.isFlat) {
      _thickness(canvas, tilt, radius);
      canvas.transform(_tiltFor(tilt, radius));
    }
    canvas.scale(k);

    _drawBase(canvas, state, r, px, k);
    _litArc(canvas, r, px, k);
    _litBezel(canvas, r);
    _pointers(canvas, r, px, k);
    _drawRete(canvas, state, r, px, k);
    // The current window's sector glows over the plate and the rete.
    canvas.drawPath(cache.windowFan, cache.windowFanPaint);
    final labels = cache.labels;
    if (labels != null) canvas.drawPicture(labels);
    _litHead(canvas, r, px, k);
    _hub(canvas, state, r, px);
    _fires(canvas, r, k);
    canvas.restore();
  }

  Float64List _tiltFor(AstrolabeTilt tilt, double radius) {
    final cached = _tiltStorage;
    if (cached != null && tilt == _tiltKey && radius == _tiltRadius) return cached;
    _tiltKey = tilt;
    _tiltRadius = radius;
    final m = AstrolabeGeometry.tiltMatrix(Offset.zero, radius, tilt);
    for (var i = 0; i < _depths.length; i++) {
      _depthStorage[i] = (m.clone()..translateByDouble(0, 0, -radius * _depths[i], 1)).storage;
    }
    return _tiltStorage = m.storage;
  }

  /// Depths (× radius) behind the face at which the disc's side wall is
  /// drawn when it is tilted.
  static const _depths = <double>[0.045, 0.03, 0.015];
  final List<Float64List?> _depthStorage = List.filled(_depths.length, null);

  /// The brass disc's thickness: its edge at a few depths behind the face,
  /// visible as a side wall while the disc is tilted.
  void _thickness(Canvas canvas, AstrolabeTilt tilt, double radius) {
    _tiltFor(tilt, radius);
    _fill.color = _ink.sideWall;
    for (var i = 0; i < _depths.length; i++) {
      final m = _depthStorage[i];
      if (m == null) continue;
      canvas
        ..save()
        ..transform(m)
        ..drawCircle(Offset.zero, radius, _fill)
        ..restore();
    }
    _stroke
      ..strokeWidth = math.max(0.6, radius / 260)
      ..color = _ink.outline;
    canvas
      ..save()
      ..transform(_depthStorage.first!)
      ..drawCircle(Offset.zero, radius, _stroke)
      ..restore();
  }

  // ------------------------------------------------------------------ brass

  /// Loads the brass uniforms (light in the current canvas frame) into the
  /// shared brass paint, or returns the gradient fallback. [time] overrides
  /// the clock (baked layers use a fixed one).
  Paint _brass(double r, double lightX, double lightY, double wear, {double? time}) {
    final set = shaders;
    if (set == null) return cache.fallbackBrassPaint;
    _u
      ..begin(set.brass)
      ..v4(0, 0, 0, 0)
      ..f(r)
      ..f(lightX)
      ..f(lightY)
      ..f(time ?? controller.time % _timeWrap)
      ..f(wear)
      ..color(palette.brass)
      ..color(palette.brassHi)
      ..color(palette.brassLow);
    return _brassPaint..shader = set.brass;
  }

  /// Tarnish from the overall balance: polished when thriving, patina when low.
  static double wearFor(double balance) => ((0.74 - balance) / 0.56).clamp(0.0, 1.0) * 0.85;

  // ------------------------------------------------------------------ layers

  // ------------------------------------------------------------ baked layers

  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  /// Baked layers carry this many device pixels per canvas pixel (the dial
  /// is drawn at up to ~1.09× its size bucket).
  double get _bakeScale => devicePixelRatio * AstrolabeRenderCache.bucketStep * 0.95;

  /// Light directions are quantised to this step (radians) for the baked
  /// layers: the gyro glint re-bakes them only every few degrees.
  static const double _lightStep = math.pi / 18;

  static Offset _quantLight(Offset l) {
    final len = l.distance;
    if (len < 1e-6) return l;
    final a = (math.atan2(l.dy, l.dx) / _lightStep).roundToDouble() * _lightStep;
    return Offset(math.cos(a), math.sin(a)) * len;
  }

  void _drawBaked(Canvas canvas, ui.Image image, double extent) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCircle(center: Offset.zero, radius: extent),
      _imagePaint,
    );
  }

  /// Halo, plate, almucantars and the limb with its engraving – baked.
  void _drawBase(Canvas canvas, AstrolabeState state, double r, double px, double k) {
    final light = _quantLight(controller.light);
    final wear = (wearFor(state.balance) * 20).roundToDouble() / 20;
    final plateRot = (state.sky.plateRotation / 0.004).roundToDouble() * 0.004;
    final almu = cache.ensureAlmucantars(palette, state.sky.latitude);
    final extent = r * AstrolabeRadii.halo;
    final image = cache.bakeBase(
      (cache.staticKey, cache.almuKey, light, wear, plateRot, _bakeScale),
      extent: extent,
      scale: _bakeScale,
      paint: (c) {
        c.drawCircle(cache.haloCenter, cache.haloRing, cache.haloPaint);
        _plate(c, almu, plateRot, r);
        _limb(c, wear, light, r, px);
      },
    );
    _drawBaked(canvas, image, extent);
  }

  void _plate(Canvas canvas, ui.Picture almu, double plateRotation, double r) {
    final plateR = r * AstrolabeRadii.limbInner;
    canvas
      ..drawCircle(Offset.zero, plateR, cache.platePaint)
      ..drawCircle(Offset.zero, plateR, cache.plateSheenPaint);
    final plate = cache.plateInk;
    if (plate != null) canvas.drawPicture(plate);
    canvas
      ..save()
      ..rotate(plateRotation)
      ..drawPicture(almu)
      ..restore()
      // the raised limb shades the plate's rim
      ..drawCircle(Offset.zero, plateR * 0.9625, cache.limbShadowPaint);
  }

  void _limb(Canvas canvas, double wear, Offset light, double r, double px) {
    canvas.drawPath(cache.limbPath, _brass(r, light.dx, light.dy, wear, time: 0));
    final ink = cache.limbInk;
    if (ink != null) canvas.drawPicture(ink);
    _bevel(canvas, r * 0.994, r * 0.011, light, outer: true);
    _bevel(canvas, r * (AstrolabeRadii.limbInner + 0.006), r * 0.01, light, outer: false);
    _bevel(
      canvas,
      r * (AstrolabeRadii.scaleInner - 0.004),
      r * 0.005,
      light,
      outer: false,
      opacity: const Color(0x73000000),
    );
  }

  /// A chamfer highlight around a circle: bright where it faces [light]
  /// ([opacity]'s alpha scales it).
  void _bevel(
    Canvas canvas,
    double radius,
    double width,
    Offset light, {
    required bool outer,
    Color opacity = const Color(0xFF000000),
  }) {
    final a = math.atan2(light.dy, light.dx) + (outer ? 0 : math.pi);
    cache.bevelPaint
      ..strokeWidth = width
      ..color = opacity;
    canvas
      ..save()
      ..rotate(a)
      ..drawCircle(Offset.zero, radius, cache.bevelPaint)
      ..restore();
  }

  void _pointers(Canvas canvas, double r, double px, double k) {
    final t = controller.time;
    final light = controller.light;
    final starR = cache.pointerRadius;
    // A lit pointer's glow: 1.6× the star and never under 11 logical px.
    final glowR = math.max(starR * 2.6, 11 / k);
    for (var i = 0; i < _prayers.length; i++) {
      final p = _prayers[i];
      final path = cache.pointerPaths[p];
      final center = cache.pointerCenters[p];
      final status = cache.statuses[p];
      if (path == null || center == null || status == null) continue;
      // soft shadow under the raised star
      canvas
        ..save()
        ..translate(px * 0.8, px * 1.2)
        ..drawPath(path, _fill..color = _ink.pointerShadow)
        ..restore();
      switch (status) {
        case AstrolabePrayerStatus.prayed:
          final g = controller.ignition(p).clamp(0.0, 1.0);
          _glowAt(canvas, center, g, glowR);
          canvas
            ..drawPath(path, _brass(r, light.dx, light.dy, 0))
            ..drawPath(path, _glow..color = palette.litHead.withValues(alpha: 0.5 * g))
            ..drawPath(
              path,
              _stroke
                ..strokeWidth = px * 0.9
                ..color = Color.lerp(_ink.outline, palette.brassHi, g)!,
            );
        case AstrolabePrayerStatus.due:
          final b = controller.reducedMotion ? 0.8 : 0.55 + 0.45 * math.sin(t * 2.3 + i);
          _glowAt(canvas, center, 0.22 + 0.26 * b, glowR * 0.8);
          canvas
            ..drawPath(path, _fill..color = _ink.dueFill)
            ..drawPath(
              path,
              _stroke
                ..strokeWidth = px * 1.2
                ..color = palette.labelDue.withValues(alpha: 0.65 + 0.35 * b),
            );
        case AstrolabePrayerStatus.upcoming:
          canvas
            ..drawPath(path, _fill..color = _ink.upcomingFill)
            ..drawPath(
              path,
              _stroke
                ..strokeWidth = px * 1.05
                ..color = _ink.upcomingStroke,
            );
        case AstrolabePrayerStatus.missed:
          canvas
            ..drawPath(path, _fill..color = _ink.missedFill)
            ..drawPath(
              path,
              _stroke
                ..strokeWidth = px * 0.9
                ..color = _ink.missedStroke,
            );
      }
      // engraved centre ring
      canvas.drawCircle(
        center,
        starR * 0.28,
        _stroke
          ..strokeWidth = px * 0.7
          ..color = status == AstrolabePrayerStatus.prayed ? _ink.centreRingLit : _ink.centreRing,
      );
    }
  }

  void _glowAt(Canvas canvas, Offset at, double alpha, double radius) {
    if (alpha <= 0.002) return;
    cache.pointerGlowPaint.color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
    final s = radius / (cache.rb * 0.1);
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(s)
      ..drawCircle(Offset.zero, cache.rb * 0.1, cache.pointerGlowPaint)
      ..restore();
  }

  /// The rete: baked in its own frame (re-baked when the light, turned into
  /// that frame, moves a step, when the tarnish changes or a star name has
  /// to flip upright), turned to the sky each frame; its star jewels twinkle
  /// live on top.
  void _drawRete(Canvas canvas, AstrolabeState state, double r, double px, double k) {
    final theta = state.sky.reteRotation;
    final light = controller.light;
    // the light in the rete's own (rotated) frame
    final c = math.cos(-theta), s = math.sin(-theta);
    final local = _quantLight(Offset(light.dx * c - light.dy * s, light.dx * s + light.dy * c));
    final wear = (wearFor(state.balance) * 0.8 * 20).roundToDouble() / 20;
    var flips = 0;
    final names = cache.reteLabels;
    for (var i = 0; i < names.length && i < 60; i++) {
      if (math.cos(names[i].angle + theta) < 0) flips |= 1 << i;
    }
    final extent = r * (AstrolabeRadii.capricorn + 0.05);
    final image = cache.bakeRete(
      (cache.staticKey, local, wear, flips, _bakeScale),
      extent: extent,
      scale: _bakeScale,
      paint: (canvas) => _paintRete(canvas, theta, local.dx, local.dy, wear, r, px),
    );
    canvas
      ..save()
      ..rotate(theta);
    _drawBaked(canvas, image, extent);
    // The stars themselves: tiny jewels at the pointer tips.
    if (cache.lod >= AstrolabeLod.medium) {
      final tips = cache.reteStarTips;
      final tw = controller.reducedMotion ? 0.0 : controller.time;
      final jewel = r * 0.02;
      for (var i = 0; i < tips.length; i++) {
        final a = 0.7 + 0.3 * math.sin(tw * 1.3 + i * 2.1);
        cache.starJewelPaint.color = Color.fromRGBO(0, 0, 0, a);
        final tip = tips[i];
        canvas
          ..save()
          ..translate(tip.dx, tip.dy)
          ..scale(jewel)
          ..drawCircle(Offset.zero, 1, cache.starJewelPaint)
          ..restore();
      }
    }
    canvas.restore();
    _sun(canvas, state, r, px);
  }

  /// The rete's metal in its own frame, lit from (lx, ly): cast shadow,
  /// dark outlines, the woven strapwork (bevel-shaded ribbons, the over
  /// strand crossing on top, a groove down every strap), the rings, the
  /// flame pointers with their bosses and engraving, and the star names.
  void _paintRete(Canvas canvas, double theta, double lx, double ly, double wear, double r, double px) {
    final ringW = r * ReteModel.ringWidth;
    final eclW = r * ReteModel.eclipticWidth;
    final shadowD = r * 0.013;

    // Cast shadow on the plate (the rete floats above it).
    _stroke
      ..strokeCap = StrokeCap.round
      ..color = _ink.reteShadow;
    _fill.color = _ink.reteShadow;
    canvas
      ..save()
      ..translate(-lx * shadowD, -ly * shadowD)
      ..drawPath(cache.reteRings, _stroke..strokeWidth = ringW)
      ..drawPath(cache.reteEcliptic, _stroke..strokeWidth = eclW)
      ..drawPath(cache.reteStraps, _fill)
      ..drawPath(cache.reteFlames, _fill)
      ..drawPath(cache.reteBosses, _fill)
      ..restore();

    // Dark outline of every piece of metal.
    _stroke.color = _ink.outline;
    canvas
      ..drawPath(cache.reteRings, _stroke..strokeWidth = ringW + px * 1.6)
      ..drawPath(cache.reteEcliptic, _stroke..strokeWidth = eclW + px * 1.6)
      ..drawPath(cache.reteStraps, _stroke..strokeWidth = px * 1.6)
      ..drawPath(cache.reteFlames, _stroke..strokeWidth = px * 1.6)
      ..drawPath(cache.reteBosses, _stroke);

    // The strapwork: brass ribbons, bevelled toward the light.
    final brass = _brass(r, lx, ly, wear, time: 0)..style = PaintingStyle.fill;
    canvas.drawPath(cache.reteStraps, brass);
    _bevelFill(canvas, cache.reteStraps, lx, ly, px);
    // engraved groove down the middle of every strap
    _stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(px * 0.6, r * ReteModel.strapWidth * 0.16)
      ..color = _ink.groove;
    canvas.drawPath(cache.reteLines, _stroke);
    // weave: the over strand crosses on top with its own dark edges
    _stroke
      ..strokeWidth = px * 1.5
      ..color = _ink.outline;
    canvas
      ..drawPath(cache.reteOverEdges, _stroke)
      ..drawPath(cache.reteOvers, brass);
    _bevelFill(canvas, cache.reteOvers, lx, ly, px);
    _stroke
      ..strokeWidth = math.max(px * 0.6, r * ReteModel.strapWidth * 0.16)
      ..color = _ink.groove;
    canvas.drawPath(cache.reteOverLines, _stroke);

    // Rings on top.
    brass
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = ringW;
    canvas.drawPath(cache.reteRings, brass);
    brass.strokeWidth = eclW;
    canvas.drawPath(cache.reteEcliptic, brass);
    _bevelPath(canvas, cache.reteRings, ringW, lx, ly, StrokeCap.round);
    _bevelPath(canvas, cache.reteEcliptic, eclW, lx, ly, StrokeCap.round);

    // Flame pointers and their bosses.
    brass.style = PaintingStyle.fill;
    canvas
      ..drawPath(cache.reteFlames, brass)
      ..drawPath(cache.reteBosses, brass);
    _bevelFill(canvas, cache.reteFlames, lx, ly, px);
    final ink = cache.reteInk;
    if (ink != null) canvas.drawPicture(ink);
    final names = cache.reteLabels;
    if (names.isNotEmpty) {
      // names passing under a prayer label step aside until it has gone by
      final avoid = cache.labelCenterList;
      final ct = math.cos(theta), st = math.sin(theta);
      for (var i = 0; i < names.length; i++) {
        final n = names[i];
        final x = n.center.dx * ct - n.center.dy * st;
        final y = n.center.dx * st + n.center.dy * ct;
        final reach = cache.labelExtent + n.ink.width * 0.5;
        var hidden = false;
        for (var j = 0; j < avoid.length && !hidden; j++) {
          final dx = x - avoid[j].dx, dy = y - avoid[j].dy;
          hidden = dx * dx + dy * dy < reach * reach;
        }
        if (!hidden) n.paint(canvas, theta);
      }
    }
  }

  /// Chamfered edges of a stroked piece of rete metal: a lit edge on the
  /// side facing the light (lx, ly) and a dark one opposite.
  void _bevelPath(Canvas canvas, Path path, double width, double lx, double ly, StrokeCap cap) {
    final o = width * 0.3;
    _stroke
      ..strokeCap = cap
      ..strokeWidth = width * 0.24
      ..color = _ink.bevelLight;
    canvas
      ..save()
      ..translate(lx * o, ly * o)
      ..drawPath(path, _stroke)
      ..restore();
    _stroke.color = _ink.bevelDark;
    canvas
      ..save()
      ..translate(-lx * o, -ly * o)
      ..drawPath(path, _stroke)
      ..restore();
  }

  /// Bevel shading inside a filled piece of metal: a lit edge just inside
  /// its side facing the light (lx, ly), a dark one inside the far side.
  void _bevelFill(Canvas canvas, Path path, double lx, double ly, double px) {
    final o = px * 1.1;
    canvas
      ..save()
      ..clipPath(path);
    _stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = px * 1.6
      ..color = _ink.bevelLight;
    canvas
      ..save()
      ..translate(-lx * o, -ly * o)
      ..drawPath(path, _stroke)
      ..restore();
    _stroke.color = _ink.bevelDark;
    canvas
      ..save()
      ..translate(lx * o, ly * o)
      ..drawPath(path, _stroke)
      ..restore()
      ..restore();
  }

  /// The sun marker: an upright radiant sun glyph at the sun's place on the
  /// rete (never under 10 logical px across), glowing brighter while the
  /// sun is above the plate's horizon, on an engraved alidade – a rule from
  /// the hub through the sun out to the hour scale, so the time reads.
  void _sun(Canvas canvas, AstrolabeState state, double r, double px) {
    final theta = state.sky.reteRotation;
    final local = state.sky.sunReteLocal;
    final c = math.cos(theta), s = math.sin(theta);
    final sx = (local.dx * c - local.dy * s) * r;
    final sy = (local.dx * s + local.dy * c) * r;
    // horizon circle, rotated with the plate
    final pr = state.sky.plateRotation;
    final pc = math.cos(pr), ps = math.sin(pr);
    final hc = cache.horizonCenter;
    final hx = hc.dx * pc - hc.dy * ps;
    final hy = hc.dx * ps + hc.dy * pc;
    final dx = sx - hx, dy = sy - hy;
    final above = dx * dx + dy * dy < cache.horizonRadius * cache.horizonRadius;
    final k = _size.isEmpty ? 1.0 : AstrolabeGeometry.radiusFor(_size) / r;
    final sunR = math.max(r * AstrolabeRadii.sun, 5 / k);
    final g = sunR / (r * AstrolabeRadii.sun);

    // The alidade: hub edge → through the sun → the hour scale.
    final len = math.sqrt(sx * sx + sy * sy);
    if (len > 1e-6) {
      final ux = sx / len, uy = sy / len;
      final from = cache.hubOuter + px * 2, to = r * (AstrolabeRadii.scaleInner - 0.004);
      final a = Offset(ux * from, uy * from), b = Offset(ux * to, uy * to);
      _stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(px * 1.3, 1.1 / k)
        ..color = _ink.alidade;
      canvas.drawLine(a, b, _stroke);
      _stroke
        ..strokeWidth = math.max(px * 0.6, 0.5 / k)
        ..color = _ink.alidadeLip;
      canvas.drawLine(a + Offset(px * 0.5, px * 0.7), b + Offset(px * 0.5, px * 0.7), _stroke);
      // a fine gold tick where it meets the scale
      _stroke
        ..strokeWidth = math.max(px * 1.4, 1.2 / k)
        ..color = palette.litHead;
      final t0 = r * (AstrolabeRadii.scaleInner - 0.03);
      canvas.drawLine(Offset(ux * t0, uy * t0), b, _stroke);
    }

    cache.sunGlowPaint.color = Color.fromRGBO(0, 0, 0, above ? 1 : 0.45);
    canvas
      ..save()
      ..translate(sx, sy)
      ..scale(g)
      ..drawCircle(Offset.zero, r * AstrolabeRadii.sun * 3.6, cache.sunGlowPaint)
      ..save()
      ..translate(px * 0.7 / g, px / g)
      ..drawPath(cache.sunRays, _fill..color = _ink.sunShadow)
      ..restore()
      ..rotate(controller.reducedMotion ? 0 : controller.time * 0.06)
      ..drawPath(cache.sunRays, cache.sunRayPaint)
      ..drawPath(
        cache.sunRays,
        _stroke
          ..strokeWidth = px * 0.6 / g
          ..color = _ink.sunInk,
      )
      ..drawCircle(Offset.zero, r * AstrolabeRadii.sun, cache.sunDiscPaint)
      ..drawCircle(
        Offset.zero,
        r * AstrolabeRadii.sun,
        _stroke
          ..strokeWidth = px * 0.8 / g
          ..color = _ink.sunRim,
      )
      ..drawCircle(
        Offset.zero,
        r * AstrolabeRadii.sun * 0.55,
        _stroke
          ..strokeWidth = px * 0.6 / g
          ..color = _ink.sunInner,
      )
      ..restore();
  }

  /// The current window's arc: a molten-gold groove in the engraved
  /// channel (0.778–0.838 R), from the window's start pointer to the next
  /// one. Additive amber layers stacked into a Gaussian cross-section – all
  /// inside the channel, nothing spills past the rim – and the part already
  /// elapsed burns hotter toward "now".
  void _litArc(Canvas canvas, double r, double px, double k) {
    final sweep = cache.arcSweep;
    if (sweep <= 0) return;
    final done = cache.arcDone;
    final rect = Rect.fromCircle(center: Offset.zero, radius: r * AstrolabeRadii.channel);
    final channel = r * (AstrolabeRadii.channelOuter - AstrolabeRadii.channelInner);
    canvas
      ..save()
      ..rotate(cache.arcStart);
    _arc
      ..shader = cache.poolShader(palette)
      ..strokeCap = StrokeCap.butt;
    for (var i = 0; i < _poolLayers.length; i++) {
      final (width, opacity) = _poolLayers[i];
      _arc
        ..strokeWidth = channel * width
        ..color = opacity;
      canvas.drawArc(rect, 0, sweep, false, _arc);
    }
    _arc.shader = null;
    // Already elapsed: hotter toward "now" (drawn in a frame turned back by
    // the gradient's lead-in, so the round start cap is still transparent).
    if (done > 1e-4) {
      const lead = AstrolabeRenderCache.litLead;
      canvas.rotate(-lead);
      _arc
        ..shader = cache.litShader(palette)
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < _litLayers.length; i++) {
        final (width, opacity) = _litLayers[i];
        _arc
          ..strokeWidth = math.max(px * 0.9, channel * width)
          ..color = opacity;
        canvas.drawArc(rect, lead, done, false, _arc);
      }
      _arc.shader = null;
    }
    canvas.restore();
  }

  /// The window's stretch of the hour scale warmed from within (additive,
  /// inside the limb's scale band – never past the rim).
  void _litBezel(Canvas canvas, double r) {
    final sweep = cache.arcSweep;
    if (sweep <= 0) return;
    final mid = r * (AstrolabeRadii.numeralsInner + AstrolabeRadii.scaleOuter) / 2;
    canvas
      ..save()
      ..rotate(cache.arcStart);
    _arc
      ..shader = cache.bezelShader(palette)
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = r * (AstrolabeRadii.scaleOuter - AstrolabeRadii.numeralsInner)
      ..color = _ink.litBezel;
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: mid), 0, sweep, false, _arc);
    _arc.shader = null;
    canvas.restore();
  }

  /// (width as a fraction of the channel, opacity) of the whole window's
  /// additive layers – a Gaussian cross-section, widest first.
  static const _poolLayers = <(double, Color)>[
    (0.96, Color(0x2E000000)),
    (0.66, Color(0x38000000)),
    (0.4, Color(0x4D000000)),
    (0.2, Color(0x66000000)),
  ];

  /// (width as a fraction of the channel, opacity) of the elapsed arc's
  /// layers, widest first (all inside the channel).
  static const _litLayers = <(double, Color)>[
    (0.9, Color(0x40000000)),
    (0.6, Color(0x5C000000)),
    (0.36, Color(0x85000000)),
    (0.18, Color(0xC2000000)),
    (0.07, Color(0xFF000000)),
  ];

  /// The luminous head of the lit arc at "now" (drawn over the rete): at
  /// least 10 logical px of glow round a bright bead, breathing gently.
  void _litHead(Canvas canvas, double r, double px, double k) {
    if (cache.arcSweep <= 0) return;
    final a = cache.arcStart + cache.arcDone;
    final rr = r * AstrolabeRadii.channel;
    final hx = math.cos(a) * rr, hy = math.sin(a) * rr;
    final breathe = controller.reducedMotion ? 1.0 : 0.9 + 0.1 * math.sin(controller.time * 2.1);
    final glow = math.max(0.7, (7 / k) / (r * 0.085));
    canvas
      ..save()
      ..translate(hx, hy)
      ..scale(breathe * glow)
      ..drawCircle(Offset.zero, r * 0.085, cache.headGlowPaint)
      ..restore()
      ..drawCircle(Offset(hx, hy), math.max(1.8 / k, r * 0.013), _glow..color = palette.litHead);
  }

  void _hub(Canvas canvas, AstrolabeState state, double r, double px) {
    final outer = cache.hubOuter;
    final inner = cache.hubInner;
    final light = controller.light;
    // the core star's warm light spilling over the rete
    cache.starLightPaint.color = Color.fromRGBO(0, 0, 0, 0.35 + 0.65 * state.balance.clamp(0.0, 1.0));
    canvas
      ..drawCircle(Offset.zero, r * 0.66, cache.starLightPaint)
      ..drawCircle(Offset.zero, outer + r * 0.05, cache.hubShadowPaint)
      ..drawCircle(Offset.zero, inner, cache.hubWindowPaint);
    // The star burns inside the hub's window: the brass ring drawn over it
    // keeps its glow off the engraved countdown.
    _coreStar(canvas, state, r);
    // A polished band (less tarnish than the limb) the countdown is cut into.
    canvas.drawPath(cache.hubPath, _brass(r, light.dx, light.dy, wearFor(state.balance) * 0.35));
    _stroke
      ..strokeWidth = px * 0.8
      ..color = _ink.hubRim;
    canvas
      ..drawCircle(Offset.zero, outer - px * 0.6, _stroke)
      ..drawCircle(Offset.zero, inner + px * 0.5, _stroke);
    _bevel(canvas, outer - r * 0.004, r * 0.007, light, outer: true, opacity: const Color(0xCC000000));
    _bevel(canvas, inner + r * 0.003, r * 0.005, light, outer: false, opacity: const Color(0xB3000000));
    // The core star lights the hub's inner edge from within.
    cache.hubRimLightPaint
      ..strokeWidth = math.max(px * 1.2, r * 0.008)
      ..color = Color.fromRGBO(0, 0, 0, 0.25 + 0.55 * state.balance.clamp(0.0, 1.0) + 0.2 * controller.pulse);
    canvas.drawCircle(Offset.zero, inner + r * 0.005, cache.hubRimLightPaint);

    if (cache.lod < AstrolabeLod.medium) return;
    final text = _hubTextFor(state);
    final remaining = state.window.nextPrayerAt.difference(state.now).inSeconds;
    final urgency = remaining <= 0 ? 1.0 : (1 - remaining / 900).clamp(0.0, 1.0);
    final scale = AstrolabeRenderCache.ringTextScale(devicePixelRatio);
    final image = cache.ensureCountdown(text.top, state.labels, scale, font: text.topFont);
    final set = shaders;
    if (set != null && !identical(image, _boundCountdown)) {
      set.countdown.setImageSampler(0, image, filterQuality: FilterQuality.medium);
      _boundCountdown = image;
    }
    _ringText(
      canvas,
      set?.countdown,
      image,
      cache.countdownScale,
      inner,
      outer,
      top: true,
      ink: palette.ink,
      glow: palette.engraveHi,
      glowAmount: 0.03 + 0.4 * urgency,
    );
    final bottom = text.bottom;
    if (bottom == null || bottom.isEmpty) return;
    final img = cache.ensureMark(bottom, state.labels, scale, font: text.bottomFont);
    if (set != null && !identical(img, _boundMark)) {
      set.mark.setImageSampler(0, img, filterQuality: FilterQuality.medium);
      _boundMark = img;
    }
    _ringText(
      canvas,
      set?.mark,
      img,
      cache.markScale,
      inner,
      outer,
      top: false,
      ink: text.bottomIsMark ? _ink.mark : palette.ink,
      glow: palette.engraveHi,
      glowAmount: text.bottomIsMark ? 0 : 0.08,
    );
  }

  /// What the hub ring carries for [state] (decided once per state): the
  /// whole countdown across the top when it fits 150° there (the maker's
  /// mark below on large dials), otherwise the clock on top and the prayer
  /// it runs to across the bottom.
  _HubText _hubTextFor(AstrolabeState state) {
    final cached = _hubText;
    if (cached != null && identical(state, _textState) && cached.rb == cache.rb) return cached;
    _textState = state;
    final labels = state.labels;
    final font = cache.hubFont;
    final mid = (cache.hubInner + cache.hubOuter) / 2;
    final mark = makersMark;
    final large = cache.lod >= AstrolabeLod.full;
    final full = state.countdown;
    final wholeFont = large ? cache.fitRingFont(full, font, mid, labels, minScale: 0.8) : null;
    _HubText out;
    if (wholeFont != null) {
      out = _HubText(
        rb: cache.rb,
        top: full,
        topFont: wholeFont,
        bottom: mark != null && mark.isNotEmpty ? mark : null,
        bottomFont: font * 0.9,
        bottomIsMark: true,
      );
    } else {
      final bands = state.countdownBands;
      out = _HubText(
        rb: cache.rb,
        top: bands.top,
        topFont: cache.fitRingFont(bands.top, font, mid, labels, minScale: 0) ?? font,
        bottom: bands.bottom,
        bottomFont: cache.fitRingFont(bands.bottom, font * 0.9, mid, labels, minScale: 0) ?? font * 0.9,
        bottomIsMark: false,
      );
    }
    return _hubText = out;
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
  }) {
    final wLogical = image.width / scale;
    final mid = (inner + outer) / 2;
    final sweep = math.min(wLogical / mid, AstrolabeRenderCache.maxRingSweep * 1.02);
    if (s == null) {
      // Fallback: the text image drawn flat across the top/bottom of the ring.
      final h = image.height / scale;
      final dst = Rect.fromCenter(center: Offset(0, top ? -mid : mid), width: wLogical, height: h);
      _textPaint.colorFilter = ColorFilter.mode(ink, BlendMode.srcIn);
      canvas.drawImageRect(image, Offset.zero & Size(image.width.toDouble(), image.height.toDouble()), dst, _textPaint);
      return;
    }
    _u
      ..begin(s)
      ..v4(0, 0, 0, 0)
      ..f(inner)
      ..f(outer)
      ..f(top ? math.pi / 2 + sweep / 2 : -math.pi / 2 + sweep / 2)
      ..f(sweep)
      ..f(image.width.toDouble())
      ..f(image.height.toDouble())
      ..color(ink)
      ..color(glow)
      ..f(glowAmount);
    // Only the text's stretch of the band runs the shader.
    final margin = 4 / mid;
    _shaderPaint
      ..shader = s
      ..style = PaintingStyle.stroke
      ..strokeWidth = outer - inner + 4;
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: mid),
      (top ? -math.pi / 2 : math.pi / 2) - sweep / 2 - margin,
      sweep + 2 * margin,
      false,
      _shaderPaint,
    );
    _shaderPaint.style = PaintingStyle.fill;
  }

  void _coreStar(Canvas canvas, AstrolabeState state, double r) {
    final rs = r * AstrolabeRadii.coreStar;
    final set = shaders;
    if (set == null) {
      canvas.drawCircle(Offset.zero, rs * 3, cache.fallbackStarPaint);
      return;
    }
    _u
      ..begin(set.star)
      ..v4(0, 0, 0, 0)
      ..f(rs)
      ..f(controller.time % _timeWrap)
      ..f(state.balance.clamp(0.0, 1.0))
      ..f(controller.pulse)
      ..color(palette.starCore)
      ..color(palette.starCorona);
    canvas.drawRect(Rect.fromCircle(center: Offset.zero, radius: rs * 4), _shaderPaint..shader = set.star);
  }

  /// Prayed pointers burn with a crown of golden fire (prayer_fire.frag):
  /// thin filaments round the star-point, sized by the detail level so a
  /// small dial is never swamped by flames.
  void _fires(Canvas canvas, double r, double k) {
    final set = shaders;
    final crown = cache.pointerRadius * (cache.lod >= AstrolabeLod.full ? 2.7 : 2.2);
    for (var i = 0; i < _prayers.length; i++) {
      final p = _prayers[i];
      final ign = controller.ignition(p);
      if (ign <= 0.001) continue;
      final center = cache.pointerCenters[p];
      final a = cache.pointerAngles[p];
      if (center == null || a == null) continue;
      // The fire rises, leaning a little outward with the pointer.
      final angle = -math.pi / 2 + math.cos(a) * 0.3;
      if (set == null) {
        cache.fallbackFirePaint.color = Color.fromRGBO(0, 0, 0, ign.clamp(0.0, 1.0));
        canvas
          ..save()
          ..translate(center.dx, center.dy)
          ..scale(crown * 0.6)
          ..drawCircle(Offset.zero, 1, cache.fallbackFirePaint)
          ..restore();
        continue;
      }
      _u
        ..begin(set.fire)
        ..f(0)
        ..f(0)
        ..f(center.dx)
        ..f(center.dy)
        ..f(angle)
        ..f(crown)
        ..f(controller.time % _timeWrap + i * 1.37)
        ..f(ign)
        ..color(palette.fireOuter)
        ..color(palette.fireInner);
      canvas.drawRect(Rect.fromCircle(center: center, radius: crown), _shaderPaint..shader = set.fire);
    }
  }

  /// Only the prayer pointers and their names are hit (when tappable), so
  /// gestures anywhere else reach the scene around and behind the astrolabe.
  @override
  bool hitTest(Offset position) => onPrayerTap != null && !_size.isEmpty && prayerAt(position, _size) != null;

  @override
  SemanticsBuilderCallback? get semanticsBuilder => semanticsState == null ? null : _semantics;

  List<CustomPainterSemantics> _semantics(Size size) {
    final state = semanticsState;
    if (state == null || size.isEmpty) return const [];
    final center = size.center(Offset.zero);
    final radius = AstrolabeGeometry.radiusFor(size);
    final tilt = controller.tilt;
    final m = tilt.isFlat ? null : AstrolabeGeometry.tiltMatrix(center, radius, tilt);
    final labels = state.labels;
    final l10n = labels.l10n;
    final touch = math.max(radius * 0.075, 22.0);
    final tap = onPrayerTap;
    return [
      for (final p in _prayers)
        () {
          var at = AstrolabeGeometry.pointerCenter(center, radius, state.fractionOf(p));
          if (m != null) at = AstrolabeGeometry.project(m, at);
          final name = labels.prayerName(p);
          return CustomPainterSemantics(
            key: ValueKey<Prayer>(p),
            rect: Rect.fromCircle(center: at, radius: touch),
            properties: SemanticsProperties(
              label: switch (state.statusOf(p)) {
                AstrolabePrayerStatus.prayed => l10n.astrolabePrayerPrayed(name),
                AstrolabePrayerStatus.due => l10n.astrolabePrayerDue(name),
                AstrolabePrayerStatus.upcoming => l10n.astrolabePrayerUpcoming(name, labels.time(state.timeOf(p))),
                AstrolabePrayerStatus.missed => l10n.astrolabePrayerMissed(name),
              },
              textDirection: labels.textDirection,
              button: tap != null,
              onTap: tap == null ? null : () => tap(p),
            ),
          );
        }(),
    ];
  }

  @override
  bool shouldRebuildSemantics(AstrolabePainter oldDelegate) =>
      !identical(oldDelegate.semanticsState, semanticsState) ||
      (oldDelegate.onPrayerTap == null) != (onPrayerTap == null);

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
    final rb = cache.rb;
    return AstrolabeGeometry.hitTestPrayer(
      local,
      size: size,
      fractions: state.fractions,
      labelCenters: rb <= 0 ? const {} : {for (final e in cache.labelCenters.entries) e.key: e.value / rb},
      tilt: controller.tilt,
    );
  }
}

/// Sequential float-uniform writer reused across draws (no closures or
/// allocations per frame).
final class _Uniforms {
  ui.FragmentShader? _s;
  int _i = 0;

  void begin(ui.FragmentShader s) {
    _s = s;
    _i = 0;
  }

  void f(double v) => _s!.setFloat(_i++, v);

  void v4(double x, double y, double z, double w) {
    f(x);
    f(y);
    f(z);
    f(w);
  }

  /// Straight (non-premultiplied) sRGB rgba.
  void color(Color c) => v4(c.r, c.g, c.b, c.a);
}

/// Fixed colours of the painter, derived once from the palette.
final class _Inks {
  _Inks(AstrolabePalette p)
    : pointerShadow = p.shadow.withValues(alpha: 0.55),
      reteShadow = p.shadow.withValues(alpha: p.light ? 0.45 : 0.62),
      outline = p.ink.withValues(alpha: 0.9),
      groove = p.ink.withValues(alpha: 0.5),
      bevelLight = p.bevelLight,
      bevelDark = p.bevelDark,
      dueFill = p.brass.withValues(alpha: 0.45),
      upcomingFill = Color.lerp(p.enamelEdge, p.ink, 0.35)!.withValues(alpha: 0.96),
      upcomingStroke = p.plateLine.withValues(alpha: 0.42),
      missedFill = p.enamelEdge.withValues(alpha: 0.9),
      missedStroke = p.labelMissed.withValues(alpha: 0.55),
      centreRing = p.plateLine.withValues(alpha: 0.6),
      centreRingLit = p.ink.withValues(alpha: 0.6),
      sunShadow = p.shadow.withValues(alpha: 0.5),
      sunInk = p.ink.withValues(alpha: 0.55),
      sunRim = p.ink.withValues(alpha: 0.6),
      sunInner = p.brassLow.withValues(alpha: 0.45),
      hubRim = p.ink.withValues(alpha: 0.7),
      alidade = p.ink.withValues(alpha: 0.85),
      alidadeLip = p.engraveHi.withValues(alpha: 0.45),
      mark = Color.lerp(p.ink, p.brass, 0.3)!,
      litBezel = Color.fromRGBO(0, 0, 0, p.light ? 0.14 : 0.2),
      sideWall = Color.lerp(p.brassLow, p.brass, 0.45)!;

  final Color pointerShadow, reteShadow, outline, groove, bevelLight, bevelDark;
  final Color dueFill, upcomingFill, upcomingStroke, missedFill, missedStroke, centreRing, centreRingLit;
  final Color sunShadow, sunInk, sunRim, sunInner, hubRim, mark, alidade, alidadeLip;
  final Color litBezel, sideWall;
}

/// The hub ring's engraved text for one state (see
/// [AstrolabePainter._hubTextFor]).
final class _HubText {
  const _HubText({
    required this.rb,
    required this.top,
    required this.topFont,
    required this.bottom,
    required this.bottomFont,
    required this.bottomIsMark,
  });

  /// The cache bucket it was laid out for.
  final double rb;
  final String top;
  final double topFont;
  final String? bottom;
  final double bottomFont;

  /// The lower band is the maker's mark (quiet ink) rather than the countdown.
  final bool bottomIsMark;
}
