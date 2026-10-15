import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../../core/design/typography.dart';
import '../../domain/scene_math.dart';
import 'sky_colors.dart';
import 'sky_controller.dart';
import 'sky_flare.dart';
import 'sky_model.dart';
import 'sky_shaders.dart';
import 'sky_view.dart';
import 'star_field.dart';

/// Sequential float-uniform cursor (one per shader; no per-frame closures).
class _Uniforms {
  _Uniforms(this.shader);

  final ui.FragmentShader shader;
  int _i = 0;

  _Uniforms reset() {
    _i = 0;
    return this;
  }

  void f(double v) => shader.setFloat(_i++, v);

  void v3(V3 v) {
    f(v.x);
    f(v.y);
    f(v.z);
  }

  void rgba(double r, double g, double b, double a) {
    f(r);
    f(g);
    f(b);
    f(a);
  }
}

/// GPU resources and caches owned by one sky layer (dispose with it).
class SkyRenderCache {
  SkyShaderSet? _shaders;
  _Uniforms? _skyU, _moonU;

  /// Binds the loaded programs (once).
  void attach(SkyPrograms programs) {
    if (_shaders != null) return;
    final set = _shaders = SkyShaderSet(programs);
    _skyU = _Uniforms(set.sky);
    _moonU = _Uniforms(set.moon);
  }

  SkyShaderSet? get shaders => _shaders;

  // Still capture of the backdrop.
  ui.Image? _still;
  SkyCamera? _stillCamera;
  int _stillState = -1;
  int _stillEpoch = -1;
  Size _stillSize = Size.zero;
  double _stillDpr = 0;
  bool _stillLabels = false;

  bool get hasStill => _still != null;

  void _dropStill() {
    _still?.dispose();
    _still = null;
    _stillCamera = null;
  }

  // Encoded palette (per state version).
  int _paletteState = -1;
  final Float64List _palette = Float64List(16);

  // Reusable paints.
  final Paint skyPaint = Paint();

  /// The moon's light adds to the sky in front of it (a crescent's dark
  /// side shows the sky, faintly lifted by earthshine – never a black disc).
  /// Screen = additive on a dark sky, while on a bright (Pearl, twilight)
  /// sky the faint earthshine sinks into it and only the lit limb shows.
  final Paint moonPaint = Paint()..blendMode = BlendMode.screen;
  final Paint glowPaint = Paint()..blendMode = BlendMode.plus;
  final Paint fallbackPaint = Paint();
  final Paint groundPaint = Paint();
  Shader? _groundShader;
  int _groundKey = 0;
  final Paint ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.7;
  final Paint labelLayer = Paint();
  final Paint stillPaint = Paint()..filterQuality = FilterQuality.none;
  Shader? _glowShader;
  SkyTone? _glowTone;
  Shader? _fallbackShader;
  int _fallbackKey = 0;

  // Star-name text (face + engraving shadow), per language and tone.
  List<TextPainter>? _faces, _shadows;
  bool? _labelsArabic;
  SkyTone? _labelsTone;

  List<TextPainter> _labelFaces(StarNames names, bool arabic, SkyTone tone) {
    if (_faces == null || _labelsArabic != arabic || _labelsTone != tone) {
      _disposeLabels();
      _labelsArabic = arabic;
      _labelsTone = tone;
      TextPainter make(StarName n, Color color) {
        final style = TextStyle(
          fontFamily: arabic ? MadarTypography.naskhFamily : MadarTypography.uiFamily,
          fontSize: arabic ? 12.5 : 10,
          fontWeight: arabic ? FontWeight.w400 : FontWeight.w500,
          letterSpacing: arabic ? 0 : 0.9,
          height: 1.1,
          color: color,
        );
        return TextPainter(
          text: TextSpan(text: arabic ? n.ar : n.en.toUpperCase(), style: style),
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          maxLines: 1,
        )..layout();
      }

      _faces = [for (final n in names.all) make(n, tone.engrave)];
      _shadows = [for (final n in names.all) make(n, tone.engraveShadow.withValues(alpha: 0.85))];
    }
    return _faces!;
  }

  void _disposeLabels() {
    for (final t in _faces ?? const <TextPainter>[]) {
      t.dispose();
    }
    for (final t in _shadows ?? const <TextPainter>[]) {
      t.dispose();
    }
    _faces = null;
    _shadows = null;
  }

  void dispose() {
    _dropStill();
    _shaders?.dispose();
    _shaders = null;
    _disposeLabels();
    _glowShader?.dispose();
    _fallbackShader?.dispose();
    _groundShader?.dispose();
  }
}

/// Paints the sky backdrop: the full-screen sky.frag pass (gradient, sun
/// glow and disc, Milky Way, haze), the moon with its glow, and the
/// engraved star names. Once the view has been steady for a moment (or at
/// once when the sky is [SkyController.still]) the result is captured into
/// an image at device resolution, so steady frames cost one texture draw
/// instead of the sky shader.
class SkyBackdropPainter extends CustomPainter {
  SkyBackdropPainter({required this.controller, required this.cache, required this.devicePixelRatio})
    : super(repaint: controller.backdrop);

  final SkyController controller;
  final SkyRenderCache cache;
  final double devicePixelRatio;

  /// How far (px) the backdrop is painted past every edge of the screen:
  /// the fly-in's depth of field blurs it and its camera shifts, and a
  /// blur sampling beyond the edge must find sky there, not the dark space
  /// behind it (≈ 8 % – the largest parallax plus three blur sigmas).
  static double overscanFor(Size size) => (size.shortestSide * 0.08).roundToDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final frame = controller.frameFor(size);
    final state = controller.state;
    if (frame == null || state == null) return;
    final labels = _labelOpacity(state) > 0.01;
    final c = cache;
    final canCapture = c.shaders != null;
    final wantStill = canCapture && (controller.still || controller.captureEpoch != c._stillEpoch);
    final stillValid =
        c._still != null &&
        c._stillState == controller.stateVersion &&
        c._stillSize == size &&
        c._stillDpr == devicePixelRatio &&
        c._stillLabels == labels &&
        !frame.camera.differsFrom(c._stillCamera, degrees: StarField.reprojectDegrees);
    if (stillValid) {
      _drawStill(canvas, size);
      controller.notePaintedBackdrop(frame);
      return;
    }
    if (wantStill) {
      final o = overscanFor(size);
      final w = ((size.width + 2 * o) * devicePixelRatio).ceil(), h = ((size.height + 2 * o) * devicePixelRatio).ceil();
      final recorder = ui.PictureRecorder();
      final rc = Canvas(recorder)
        ..scale(devicePixelRatio)
        ..translate(o, o);
      paintSky(rc, size, frame, state);
      final picture = recorder.endRecording();
      final image = picture.toImageSync(w, h);
      picture.dispose();
      c._dropStill();
      c
        .._still = image
        .._stillCamera = frame.camera
        .._stillState = controller.stateVersion
        .._stillEpoch = controller.captureEpoch
        .._stillSize = size
        .._stillDpr = devicePixelRatio
        .._stillLabels = labels;
      _drawStill(canvas, size);
    } else {
      c._dropStill();
      paintSky(canvas, size, frame, state);
    }
    controller.notePaintedBackdrop(frame);
  }

  void _drawStill(Canvas canvas, Size size) {
    final img = cache._still!;
    final o = overscanFor(size);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Offset(-o, -o) & Size(img.width / devicePixelRatio, img.height / devicePixelRatio),
      cache.stillPaint,
    );
  }

  /// The whole backdrop (live) into [canvas] in logical coordinates.
  void paintSky(Canvas canvas, Size size, SkyFrame frame, SkyState state) {
    final shaders = cache.shaders;
    if (shaders != null) {
      _paintSkyPass(canvas, size, frame, state);
    } else {
      _paintFallback(canvas, size, frame, state);
    }
    _paintGround(canvas, size, frame, state);
    _paintMoon(canvas, frame, state);
    _paintNames(canvas, size, frame, state);
  }

  void _encodePalette(SkyState s) {
    final c = cache;
    if (c._paletteState == controller.stateVersion) return;
    c._paletteState = controller.stateVersion;
    final p = s.palette;
    final out = c._palette;
    void put(int o, Color col) {
      out[o] = SkyColors.encodeChannel(col.r);
      out[o + 1] = SkyColors.encodeChannel(col.g);
      out[o + 2] = SkyColors.encodeChannel(col.b);
    }

    put(0, p.zenith);
    put(4, p.horizon);
    out[8] = p.glow.r;
    out[9] = p.glow.g;
    out[10] = p.glow.b;
    out[11] = p.glowIntensity;
    out[12] = p.nebula.r;
    out[13] = p.nebula.g;
    out[14] = p.nebula.b;
  }

  void _paintSkyPass(Canvas canvas, Size size, SkyFrame frame, SkyState s) {
    _encodePalette(s);
    final cam = frame.camera;
    final u = cache._skyU!.reset();
    final p = cache._palette;
    u
      ..f(size.width)
      ..f(size.height)
      ..f(cam.principal.dx)
      ..f(cam.principal.dy)
      ..f(cam.focal)
      ..v3(cam.right)
      ..v3(cam.up)
      ..v3(cam.forward)
      ..v3(s.sunDir)
      ..v3(s.galacticPole)
      ..v3(s.galacticCenter)
      ..f(controller.seconds)
      ..f(s.milkyWay)
      ..rgba(p[0], p[1], p[2], 1)
      ..rgba(p[4], p[5], p[6], 1)
      ..rgba(p[8], p[9], p[10], p[11])
      ..rgba(p[12], p[13], p[14], 1);
    cache.skyPaint.shader = cache.shaders!.sky;
    canvas.drawRect((Offset.zero & size).inflate(overscanFor(size)), cache.skyPaint);
  }

  /// Gradient stand-in until the shaders load (or where they cannot).
  void _paintFallback(Canvas canvas, Size size, SkyFrame frame, SkyState s) {
    final cam = frame.camera;
    final yaw = cam.aim.yaw * math.pi / 180;
    final horizon = cam.project(V3(math.sin(yaw), math.cos(yaw), 0))?.dy ?? size.height;
    final key = Object.hash(controller.stateVersion, size, horizon.round());
    if (cache._fallbackShader == null || cache._fallbackKey != key) {
      cache._fallbackShader?.dispose();
      cache._fallbackKey = key;
      final h = horizon.clamp(1.0, size.height * 2);
      cache._fallbackShader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, h),
        [s.palette.zenith, SkyColors.lerp(s.palette.zenith, s.palette.horizon, 0.45), s.palette.horizon],
        const [0.0, 0.7, 1.0],
      );
    }
    cache.fallbackPaint.shader = cache._fallbackShader;
    canvas.drawRect((Offset.zero & size).inflate(overscanFor(size)), cache.fallbackPaint);
  }

  /// The horizon line on screen: a point on it and its direction (a level
  /// or rolled pinhole camera maps the horizon to a straight line).
  static (Offset, Offset)? horizonLine(SkyFrame frame) {
    final cam = frame.camera;
    final yaw = cam.aim.yaw * math.pi / 180;
    V3 dir(double d) => V3(math.sin(yaw + d), math.cos(yaw + d), 0);
    final a = cam.project(dir(-0.35)), b = cam.project(dir(0.35));
    if (a == null || b == null) return null;
    final d = b - a;
    final l = d.distance;
    if (l < 1e-6) return null;
    return (a, d / l);
  }

  /// A designed ground below the horizon: the horizon's own haze carried
  /// down, deepening only gently toward [SkyPalette.ground] (replaces the
  /// shader's plain darkening) – when a fly-in lowers the horizon into view
  /// it reads as atmosphere, never as a dark slab.
  void _paintGround(Canvas canvas, Size size, SkyFrame frame, SkyState s) {
    final line = horizonLine(frame);
    if (line == null) return;
    final (p, d) = line;
    final h = size.height;
    final key = Object.hash(controller.stateVersion, h.round());
    if (cache._groundShader == null || cache._groundKey != key) {
      cache._groundShader?.dispose();
      cache._groundKey = key;
      final hor = s.palette.horizon, ground = s.palette.ground;
      final haze = SkyColors.lerp(hor, ground, 0.14);
      final deep = SkyColors.lerp(hor, ground, 0.34);
      cache._groundShader = ui.Gradient.linear(
        Offset(0, -0.012 * h),
        Offset(0, 0.4 * h),
        [hor.withValues(alpha: 0), hor.withValues(alpha: 0.55), haze, deep, deep],
        const [0.0, 0.03, 0.18, 0.7, 1.0],
      );
    }
    final diag = size.longestSide * 2;
    canvas
      ..save()
      ..translate(p.dx, p.dy)
      ..rotate(math.atan2(d.dy, d.dx));
    cache.groundPaint.shader = cache._groundShader;
    canvas
      ..drawRect(Rect.fromLTRB(-diag, -0.012 * h, diag, diag), cache.groundPaint)
      ..restore();
  }

  void _paintMoon(Canvas canvas, SkyFrame frame, SkyState s) {
    final center = frame.moonCenter;
    if (center == null || frame.moonVisibility <= 0) return;
    final r = frame.moonRadius;
    final tone = controller.tone;
    // Broad scattered moonlight around the disc (additive).
    final glow =
        math.pow(s.moonIllumination, 1.3) *
        frame.moonVisibility *
        (1 - 0.8 * s.daylight) *
        ((tone?.dark ?? true) ? 0.5 : 0.28);
    if (glow > 0.004) {
      if (cache._glowShader == null || cache._glowTone != tone) {
        cache._glowShader?.dispose();
        cache._glowTone = tone;
        final base = SkyColors.lerp(const Color(0xFFDCE6FF), tone?.starTint ?? const Color(0xFFFFFFFF), 0.25);
        // A tight halo (≤ 1.5× the disc for most of its light) and a faint
        // wide scatter – not a heavy bloom around a white coin.
        cache._glowShader = ui.Gradient.radial(
          Offset.zero,
          1,
          [
            base.withValues(alpha: 0.4),
            base.withValues(alpha: 0.12),
            base.withValues(alpha: 0.025),
            base.withValues(alpha: 0),
          ],
          const [0.0, 0.36, 0.62, 1.0],
        );
      }
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..scale(r * 3.2);
      cache.glowPaint
        ..shader = cache._glowShader
        ..color = Color.fromRGBO(255, 255, 255, glow.clamp(0.0, 1.0).toDouble());
      canvas
        ..drawCircle(Offset.zero, 1, cache.glowPaint)
        ..restore();
    }
    final shaders = cache.shaders;
    if (shaders == null) {
      cache.moonPaint
        ..shader = null
        ..color = const Color(0xFFE9ECF2).withValues(alpha: frame.moonVisibility * s.moonIllumination);
      canvas.drawCircle(center, r, cache.moonPaint);
      return;
    }
    final l = frame.moonLight;
    cache._moonU!.reset()
      ..f(frame.size.width)
      ..f(frame.size.height)
      ..f(center.dx)
      ..f(center.dy)
      ..f(r)
      ..v3(l)
      ..f(controller.seconds)
      ..f(s.daylight);
    cache.moonPaint
      ..shader = shaders.moon
      ..color = Color.fromRGBO(0, 0, 0, frame.moonVisibility);
    canvas.drawRect(Rect.fromCircle(center: center, radius: r * 2.6), cache.moonPaint);
  }

  double _labelOpacity(SkyState s) {
    if (!controller.showStarNames) return 0;
    final night = SkyModel.smoothstep(-10, -16, s.sun.altitude);
    final zoom = 1 - SkyModel.smoothstep(0.02, 0.3, controller.zoom);
    return night * zoom * (1 - 0.3 * s.moonlight) * (s.dark ? 0.9 : 0.8);
  }

  void _paintNames(Canvas canvas, Size size, SkyFrame frame, SkyState s) {
    final opacity = _labelOpacity(s);
    final tone = controller.tone;
    if (opacity <= 0.01 || tone == null) return;
    final names = controller.names;
    final arabic = controller.arabicNames;
    final faces = cache._labelFaces(names, arabic, tone);
    names.layout(
      frame.camera,
      lstDeg: s.localSiderealDeg,
      latitudeDeg: s.observer.latitude,
      labelSize: (i) => faces[i].size,
      rtl: arabic,
      limitMagnitude: math.min(1.9, s.starLimit - 1.2),
      keepOut: controller.labelKeepOut,
    );
    if (names.count == 0) return;
    var bounds = names.placed[0].rect;
    for (var i = 0; i < names.count; i++) {
      bounds = bounds
          .expandToInclude(names.placed[i].rect)
          .expandToInclude(Rect.fromCircle(center: names.placed[i].star, radius: 6));
    }
    final layered = opacity < 0.99;
    if (layered) {
      cache.labelLayer.color = Color.fromRGBO(0, 0, 0, opacity);
      canvas.saveLayer(bounds.inflate(2), cache.labelLayer);
    }
    cache.ringPaint.color = tone.engrave.withValues(alpha: 0.42);
    final shadows = cache._shadows!;
    for (var i = 0; i < names.count; i++) {
      final slot = names.placed[i];
      canvas.drawCircle(slot.star, 4.2, cache.ringPaint);
      final at = slot.rect.topLeft;
      shadows[slot.name].paint(canvas, at + const Offset(0, 0.9));
      faces[slot.name].paint(canvas, at);
    }
    if (layered) canvas.restore();
  }

  @override
  bool shouldRepaint(SkyBackdropPainter old) =>
      old.controller != controller || old.cache != cache || old.devicePixelRatio != devicePixelRatio;
}

/// Paints the star field: the catalogue through `drawRawAtlas` with the
/// procedural sprite, additive, magnitude-limited by darkness, twinkling.
class SkyStarsPainter extends CustomPainter {
  SkyStarsPainter({required this.controller, required this.programs, this.starScale = 1}) : super(repaint: controller);

  final SkyController controller;
  final SkyPrograms? programs;

  /// Multiplies sprite sizes (logical px).
  final double starScale;

  static final Paint _paint = Paint()..blendMode = BlendMode.plus;

  @override
  void paint(Canvas canvas, Size size) {
    final sprite = programs?.starSprite;
    final frame = controller.frameFor(size);
    final s = controller.state;
    if (sprite == null || frame == null || s == null) return;
    final field = controller.stars;
    field.project(
      frame.camera,
      lstDeg: s.localSiderealDeg,
      latitudeDeg: s.observer.latitude,
      limitMagnitude: s.starLimit,
      gain: s.starGain,
      scale: starScale,
      occluder: frame.moonCenter,
      occluderRadius: frame.moonRadius * 1.12,
    );
    if (field.count == 0) return;
    field.colorize(controller.seconds, twinkle: controller.twinkling);
    canvas.drawRawAtlas(
      sprite,
      field.transformsView,
      field.rectsView,
      field.colorsView,
      BlendMode.modulate,
      null,
      _paint,
    );
  }

  @override
  bool shouldRepaint(SkyStarsPainter old) =>
      old.controller != controller || old.programs != programs || old.starScale != starScale;
}

/// Paints the lens flares over the whole scene (additive): the core star's
/// restrained cinematic flare and, by day, the sun's when it is in view.
class SkyFlarePainter extends CustomPainter {
  SkyFlarePainter({required this.controller, required this.shaders}) : super(repaint: controller);

  final SkyController controller;
  final FlareShaderSet? shaders;

  static final Paint _core = Paint()..blendMode = BlendMode.plus;
  static final Paint _sun = Paint()..blendMode = BlendMode.plus;

  static void _write(ui.FragmentShader sh, Size size, Offset src, double intensity, Color tint) {
    sh
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, src.dx)
      ..setFloat(3, src.dy)
      ..setFloat(4, intensity)
      ..setFloat(5, tint.r)
      ..setFloat(6, tint.g)
      ..setFloat(7, tint.b)
      ..setFloat(8, 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sh = shaders;
    final s = controller.state;
    final tone = controller.tone;
    if (sh == null || s == null || tone == null) return;
    final core = controller.coreStar;
    if (core != null) {
      final i = controller.coreFlareIntensity;
      if (i > 0.003 && SkyFlares.withinReach(core, size)) {
        _write(sh.core, size, core, i, controller.coreFlareTint);
        _core.shader = sh.core;
        canvas.drawRect(Offset.zero & size, _core);
      }
    }
    if (s.sun.altitude > -1) {
      final frame = controller.peekFrame(size);
      final sun = frame?.sunScreen;
      final i = SkyFlares.sunIntensity(
        sunAltitude: s.sun.altitude,
        sunScreen: sun,
        viewport: size,
        dark: s.dark,
        zoom: controller.zoom,
      );
      if (sun != null && i > 0.003) {
        _write(sh.sun, size, sun, i, controller.sunFlareTint);
        _sun.shader = sh.sun;
        canvas.drawRect(Offset.zero & size, _sun);
      }
    }
  }

  @override
  bool shouldRepaint(SkyFlarePainter old) => old.controller != controller || old.shaders != shaders;
}
