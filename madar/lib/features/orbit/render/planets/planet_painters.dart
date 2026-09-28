import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import 'label_layout.dart';
import 'planet_frame.dart';
import 'planet_renderer.dart';
import 'planet_scene_controller.dart';
import 'planet_style.dart';
import 'planet_uniforms.dart';

/// Which worlds a bodies view draws, relative to the core star – so the
/// scene can sandwich the astrolabe: `behindCore` below it, `frontOfCore`
/// above it.
enum PlanetPass { all, behindCore, frontOfCore }

/// Which worlds a bodies view draws during a fly-in – so the scene can blur
/// the rest (depth of field) while the focused world stays sharp.
enum PlanetFocusFilter { any, focusedOnly, unfocusedOnly }

/// Colours and type of the planet layer's chrome (guides, labels), from the
/// theme's tokens.
@immutable
class PlanetLayerStyle {
  const PlanetLayerStyle({
    required this.silver,
    required this.groove,
    required this.labelText,
    required this.labelHalo,
    required this.moonLabelText,
    required this.dark,
    this.textScale = 1,
    this.night,
  });

  /// [textScale]: the user's text size (labels grow with it, up to 1.3×).
  factory PlanetLayerStyle.fromTokens(MadarTokens t, {double textScale = 1}) => PlanetLayerStyle(
    // Engraved silver on dark skies; a warm grey on Pearl's pale sky.
    silver: t.isDark ? Color.lerp(t.textSecondary, t.starTint, 0.55)! : Color.lerp(t.textSecondary, t.brassDark, 0.3)!,
    groove: t.isDark ? t.space0 : t.glassHighlight,
    labelText: t.textPrimary.withValues(alpha: 0.8),
    // A soft shadow that lifts the text off any sky (deep space on dark
    // themes, a pearl glow on Pearl).
    labelHalo: t.isDark ? t.space0 : Color.lerp(t.glassHighlight, t.space0, 0.15)!,
    moonLabelText: t.textPrimary.withValues(alpha: 0.78),
    dark: t.isDark,
    textScale: textScale.clamp(1.0, 1.3),
    // Pearl's night sky is a deep indigo-slate: pearl ink on it, lifted by
    // a shadow of the theme's own ink.
    night: t.isDark
        ? null
        : PlanetLayerStyle(
            silver: Color.lerp(t.space2, t.gold, 0.2)!,
            groove: t.textPrimary,
            labelText: t.space0.withValues(alpha: 0.9),
            labelHalo: t.textPrimary,
            moonLabelText: t.space0.withValues(alpha: 0.82),
            dark: true,
            textScale: textScale.clamp(1.0, 1.3),
          ),
  );

  /// The look on a dark sky (Pearl's night); null: this one serves every
  /// sky.
  final PlanetLayerStyle? night;

  /// This style, or its [night] variant on a dark sky.
  PlanetLayerStyle forSky({required bool darkSky}) => darkSky ? (night ?? this) : this;

  /// Engraved-silver hairline of the orbit guides.
  final Color silver;

  /// The groove under the hairline (a shadow on dark themes, a highlight
  /// on Pearl) – the "engraved" relief.
  final Color groove;

  /// Label text (≈ 80 % opacity) and its soft shadow.
  final Color labelText, labelHalo;
  final Color moonLabelText;
  final bool dark;

  /// Multiplies the label type size (the user's text scale, clamped).
  final double textScale;

  List<Shadow> get _shadows => [
    Shadow(color: labelHalo.withValues(alpha: dark ? 0.9 : 0.85), blurRadius: 7),
    Shadow(color: labelHalo.withValues(alpha: dark ? 0.7 : 0.6), blurRadius: 2.5),
  ];

  /// A world's name: IBM Plex Sans Arabic SemiBold 13 – text only, no pill.
  TextStyle get planetLabel => TextStyle(
    fontFamily: MadarTypography.uiFamily,
    fontSize: 13 * textScale,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: labelText,
    shadows: _shadows,
  );

  TextStyle get moonLabel => TextStyle(
    fontFamily: MadarTypography.uiFamily,
    fontSize: 10.5 * textScale,
    height: 1.2,
    fontWeight: FontWeight.w500,
    color: moonLabelText,
    shadows: _shadows,
  );

  @override
  bool operator ==(Object other) =>
      other is PlanetLayerStyle &&
      other.silver == silver &&
      other.groove == groove &&
      other.labelText == labelText &&
      other.labelHalo == labelHalo &&
      other.moonLabelText == moonLabelText &&
      other.dark == dark &&
      other.textScale == textScale &&
      other.night == night;

  @override
  int get hashCode => Object.hash(silver, groove, labelText, labelHalo, moonLabelText, dark, textScale, night);
}

// -------------------------------------------------------------- orbit guides --

/// Reusable objects of the guides painter (owned by the view's state).
class OrbitGuideCache {
  static const samples = 160;

  static final Float64List _cos = Float64List.fromList([
    for (var k = 0; k <= samples; k++) math.cos(2 * math.pi * k / samples),
  ]);
  static final Float64List _sin = Float64List.fromList([
    for (var k = 0; k <= samples; k++) math.sin(2 * math.pi * k / samples),
  ]);

  final List<Path> _paths = [];
  final ScreenProjector projector = ScreenProjector();
  final Paint groove = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint glow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  final Paint tick = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  Path pathAt(int i) {
    while (_paths.length <= i) {
      _paths.add(Path());
    }
    return _paths[i]..reset();
  }
}

/// Faint engraved-silver orbit ellipses, one per world: a quiet hairline
/// (12–18 % on the near side, fading with depth toward the far side) that
/// brightens to ~40 % only along the 25° its world has just travelled – a
/// wake behind each planet, not eight vinyl grooves – and fades out
/// entirely during a fly-in to another world. The selected world's orbit is
/// traced in its own glow colour.
///
/// Repaints on [PlanetSceneController.guides] (camera, lanes, selection,
/// focus, the worlds moving).
class OrbitGuidesPainter extends CustomPainter {
  OrbitGuidesPainter({required this.controller, required this.style, required this.cache})
    : super(repaint: controller.guides);

  final PlanetSceneController controller;
  final PlanetLayerStyle style;

  /// [style] for the sky behind (Pearl's dark night takes light ink).
  PlanetLayerStyle get _sky => style.forSky(darkSky: controller.skyDark);
  final OrbitGuideCache cache;

  /// Arc of the bright wake behind each world (radians).
  static const double wake = 25 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final f = controller.frameFor(size);
    if (f.bodies.isEmpty) return;
    final pr = cache.projector..configure(controller.camera, size);
    final selected = controller.selectedKey;
    final star = controller.star;
    final dark = _sky.dark;
    for (var i = 0; i < f.bodies.length; i++) {
      final b = f.bodies[i];
      final opacity = b.guideOpacity;
      if (opacity <= 0.01) continue;
      final path = cache.pathAt(2 * i);
      final ci = math.cos(b.inclination), si = math.sin(b.inclination);
      final cn = math.cos(b.node), sn = math.sin(b.node);
      var nearD = double.infinity, farD = -double.infinity;
      var nearX = 0.0, nearY = 0.0, farX = 0.0, farY = 0.0;
      var pen = false;
      for (var k = 0; k <= OrbitGuideCache.samples; k++) {
        // orbitPoint(b.lane, angle_k, inclination, node) without allocating.
        final x0 = b.lane * OrbitGuideCache._cos[k];
        final z0 = b.lane * OrbitGuideCache._sin[k];
        final y1 = -z0 * si;
        final z1 = z0 * ci;
        final x2 = x0 * cn + z1 * sn;
        final z2 = -x0 * sn + z1 * cn;
        if (!pr.project(star.x + x2, star.y + y1, star.z + z2)) {
          pen = false;
          continue;
        }
        if (pen) {
          path.lineTo(pr.x, pr.y);
        } else {
          path.moveTo(pr.x, pr.y);
          pen = true;
        }
        if (pr.depth < nearD) {
          nearD = pr.depth;
          nearX = pr.x;
          nearY = pr.y;
        }
        if (pr.depth > farD) {
          farD = pr.depth;
          farX = pr.x;
          farY = pr.y;
        }
      }
      if (nearD == double.infinity) continue;
      final isSelected = b.key == selected;
      final near = Offset(nearX, nearY), far = Offset(farX, farY);
      final degenerate = (near - far).distanceSquared < 1;
      final farEnd = degenerate ? near + const Offset(0, -1) : far;

      if (isSelected) {
        final glowColor = b.body.palette.glow;
        cache.glow
          ..strokeWidth = 4.5
          ..shader = ui.Gradient.linear(farEnd, near, [
            glowColor.withValues(alpha: 0.05 * opacity),
            glowColor.withValues(alpha: 0.18 * opacity),
          ]);
        canvas.drawPath(path, cache.glow);
        cache.line
          ..strokeWidth = 1.1
          ..shader = ui.Gradient.linear(farEnd, near, [
            glowColor.withValues(alpha: 0.28 * opacity),
            glowColor.withValues(alpha: 0.7 * opacity),
          ]);
        canvas.drawPath(path, cache.line);
        continue;
      }
      // A soft relief under the near side only (Pearl: a highlight).
      cache.groove
        ..strokeWidth = 1.6
        ..shader = ui.Gradient.linear(farEnd, near, [
          _sky.groove.withValues(alpha: 0),
          _sky.groove.withValues(alpha: (dark ? 0.12 : 0.3) * opacity),
        ]);
      canvas.save();
      canvas.translate(0, 0.5);
      canvas.drawPath(path, cache.groove);
      canvas.restore();
      cache.line
        ..strokeWidth = 0.8
        ..shader = ui.Gradient.linear(farEnd, near, [
          _sky.silver.withValues(alpha: (dark ? 0.06 : 0.12) * opacity),
          _sky.silver.withValues(alpha: (dark ? 0.17 : 0.3) * opacity),
        ]);
      canvas.drawPath(path, cache.line);
      _wake(canvas, pr, b, cache.pathAt(2 * i + 1), ci, si, cn, sn, opacity);
    }
  }

  /// The brighter stretch of orbit the world [b] has just travelled.
  void _wake(
    Canvas canvas,
    ScreenProjector pr,
    BodyFrame b,
    Path path,
    double ci,
    double si,
    double cn,
    double sn,
    double opacity,
  ) {
    if (!b.visible) return;
    final star = controller.star;
    const steps = 14;
    double sx = 0, sy = 0;
    var pen = false;
    for (var k = 0; k <= steps; k++) {
      final a = b.angle - wake + wake * k / steps;
      final x0 = b.lane * math.cos(a), z0 = b.lane * math.sin(a);
      final y1 = -z0 * si, z1 = z0 * ci;
      final x2 = x0 * cn + z1 * sn, z2 = -x0 * sn + z1 * cn;
      if (!pr.project(star.x + x2, star.y + y1, star.z + z2)) {
        pen = false;
        continue;
      }
      if (!pen) {
        path.moveTo(pr.x, pr.y);
        sx = pr.x;
        sy = pr.y;
        pen = true;
      } else {
        path.lineTo(pr.x, pr.y);
      }
    }
    if (!pen) return;
    final tail = Offset(sx, sy), head = b.center;
    if ((head - tail).distanceSquared < 1) return;
    final color = Color.lerp(_sky.silver, b.body.palette.glow, 0.35)!;
    cache.tick
      ..strokeWidth = 1.1
      ..shader = ui.Gradient.linear(tail, head, [color.withValues(alpha: 0), color.withValues(alpha: 0.4 * opacity)]);
    canvas.drawPath(path, cache.tick);
  }

  /// Never claims a pointer (taps go to [PlanetHitRegion] / the scene).
  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(OrbitGuidesPainter old) =>
      old.controller != controller || old.style != style || old.cache != cache;
}

// -------------------------------------------------------------------- bodies --

/// Draws the worlds and their moons, farthest first; each world's moons
/// behind it go before it, those in front after it. Culled bodies (behind
/// the camera, off screen, sub-pixel) are skipped. Repaints on every
/// controller tick.
///
/// Without a [renderer] (shaders not loaded yet / unavailable) the worlds
/// are drawn as softly shaded palette spheres.
class PlanetBodiesPainter extends CustomPainter {
  PlanetBodiesPainter({
    required this.controller,
    required this.renderer,
    this.pass = PlanetPass.all,
    this.filter = PlanetFocusFilter.any,
    this.retain = true,
    this.ghostRim,
    this.ghostShade,
  }) : super(repaint: controller);

  final PlanetSceneController controller;
  final PlanetRenderer? renderer;
  final PlanetPass pass;
  final PlanetFocusFilter filter;

  /// The front pass (over the astrolabe) also draws the worlds mostly
  /// hidden behind the dial as ghosts: the dial dimmed by [ghostShade]
  /// where the world is, the world itself faint over it, and a hairline
  /// [ghostRim] (gold) around it. Null: no ghosts.
  final Color? ghostRim, ghostShade;

  /// Release shaders of bodies that left the scene (one view per renderer
  /// should do it).
  final bool retain;

  static final Expando<int> _retainedVersion = Expando('retainedVersion');
  final List<MoonFrame> _scratch = [];
  final Paint _sky = Paint()..blendMode = BlendMode.screen;
  final Paint _shade = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  final Paint _rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1;

  static int _farFirst(MoonFrame a, MoonFrame b) => b.depth.compareTo(a.depth);

  bool _accepts(BodyFrame b) {
    final passOk = switch (pass) {
      PlanetPass.all => true,
      PlanetPass.behindCore => b.behindCore,
      PlanetPass.frontOfCore => !b.behindCore,
    };
    if (!passOk) return false;
    final focus = controller.focusKey;
    return switch (filter) {
      PlanetFocusFilter.any => true,
      PlanetFocusFilter.focusedOnly => b.key == focus,
      PlanetFocusFilter.unfocusedOnly => b.key != focus,
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final f = controller.frameFor(size);
    final r = renderer;
    if (r != null && retain && _retainedVersion[r] != controller.bodiesVersion) {
      final ids = controller.liveIds;
      r.retain(planetKeys: ids.planets, moonIds: ids.moons);
      _retainedVersion[r] = controller.bodiesVersion;
    }
    final t = controller.time;
    if (pass == PlanetPass.frontOfCore && ghostRim != null) _ghosts(canvas, size, f, r, t);
    for (final b in f.drawOrder) {
      if (!_accepts(b) || b.opacity <= 0.004) continue;
      _moons(canvas, size, b, front: false, t: t);
      if (b.visible) {
        if (r != null && r.canDraw(b.body)) {
          r.paintPlanet(canvas, size, b, t);
        } else {
          fallbackSphere(canvas, b.center, b.radius, b.body.shaderPalette.surface, b.body.shaderPalette.deep, b);
        }
        _skyLight(canvas, b);
      }
      _moons(canvas, size, b, front: true, t: t);
    }
  }

  /// Worlds more than half hidden behind the dial, drawn over it (clipped to
  /// the dial) as faint gold-rimmed ghosts – farthest first, before the
  /// worlds in front of the dial.
  void _ghosts(Canvas canvas, Size size, PlanetFrame f, PlanetRenderer? r, double t) {
    final core = controller.coreOpacity;
    if (core <= 0.01 || f.coreRadius <= 0) return;
    var clipped = false;
    for (final b in f.drawOrder) {
      if (!b.ghosted || !_acceptsFocus(b)) continue;
      final a =
          PlanetViewMath.smoothstep(PlanetViewGhost.threshold, PlanetViewGhost.threshold + 0.12, b.coreOcclusion) *
          core *
          b.opacity;
      if (a <= 0.01) continue;
      if (!clipped) {
        clipped = true;
        canvas.save();
        final cr = f.coreRadius * 0.996;
        canvas.clipRRect(
          RRect.fromRectAndRadius(Rect.fromCircle(center: f.coreCenter, radius: cr), Radius.circular(cr)),
        );
      }
      // A window into the sky: the brass dims where the world passes.
      _shade.color = (ghostShade ?? const Color(0xFF000000)).withValues(alpha: 0.5 * a);
      canvas.drawCircle(b.center, b.radius * 1.04, _shade);
      final opacity = b.opacity;
      b.opacity = opacity * 0.62 * a;
      if (r != null && r.canDraw(b.body)) {
        r.paintPlanet(canvas, size, b, t);
      }
      b.opacity = opacity;
      _rim.color = ghostRim!.withValues(alpha: 0.85 * a);
      canvas.drawCircle(b.center, b.radius, _rim);
    }
    if (clipped) canvas.restore();
  }

  bool _acceptsFocus(BodyFrame b) {
    final focus = controller.focusKey;
    return switch (filter) {
      PlanetFocusFilter.any => true,
      PlanetFocusFilter.focusedOnly => b.key == focus,
      PlanetFocusFilter.unfocusedOnly => b.key != focus,
    };
  }

  void _moons(Canvas canvas, Size size, BodyFrame b, {required bool front, required double t}) {
    if (b.moons.isEmpty) return;
    _scratch.clear();
    for (final m in b.moons) {
      if (m.visible && m.front == front) _scratch.add(m);
    }
    if (_scratch.isEmpty) return;
    _scratch.sort(_farFirst);
    final r = renderer;
    for (final m in _scratch) {
      if (r != null && r.canDrawMoons) {
        r.paintMoon(canvas, size, m, t);
      } else {
        fallbackSphere(canvas, m.center, m.radius, m.moon.color, const Color(0xFF05070F), null);
      }
    }
  }

  ui.Shader? _skyShader;
  Color? _skyShaderColor;

  /// Sky light on the disc (screen blend, so it only ever lifts): a
  /// sky-dome ambient over the whole disc – the night side is never pure
  /// black against a daylit sky – and a Fresnel rim in the sky's colour
  /// (every world sits in the time of day: blue at noon, amber at Maghrib),
  /// stronger on far worlds (aerial perspective).
  void _skyLight(Canvas canvas, BodyFrame b) {
    final sky = controller.skyAmbient;
    if (sky == null || b.radius < 1) return;
    final bright = sky.computeLuminance() > 0.45;
    final a = (0.75 + 0.5 * b.haze) * b.opacity * (bright ? 0.8 : 1);
    if (a <= 0.004) return;
    if (_skyShaderColor != sky) {
      _skyShader?.dispose();
      _skyShaderColor = sky;
      _skyShader = ui.Gradient.radial(
        Offset.zero,
        1,
        [
          sky.withValues(alpha: 0.12),
          sky.withValues(alpha: 0.13),
          sky.withValues(alpha: 0.24),
          sky.withValues(alpha: 0.5),
          sky.withValues(alpha: 0.62),
        ],
        const [0.0, 0.55, 0.8, 0.95, 1.0],
      );
    }
    _sky
      ..shader = _skyShader
      ..color = Color.fromRGBO(0, 0, 0, a.clamp(0.0, 1.0));
    canvas
      ..save()
      ..translate(b.center.dx, b.center.dy)
      ..scale(b.radius)
      ..drawCircle(Offset.zero, 0.996, _sky)
      ..restore();
  }

  /// A plain lit sphere without shaders (first frames, no shader support,
  /// or a program that did not compile).
  static void fallbackSphere(Canvas canvas, Offset c, double r, Color surface, Color deep, BodyFrame? b) {
    if (r <= 0) return;
    final lx = b?.lightX ?? -0.6, ly = b?.lightY ?? 0.4;
    final hi = c + Offset(lx, -ly) * r * 0.45;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          hi,
          r * 1.35,
          [Color.lerp(surface, const Color(0xFFFFFFFF), 0.18)!, surface, deep],
          const [0, 0.45, 1],
        ),
    );
  }

  /// Never claims a pointer (taps go to [PlanetHitRegion] / the scene).
  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(PlanetBodiesPainter old) =>
      old.controller != controller ||
      old.renderer != renderer ||
      old.pass != pass ||
      old.filter != filter ||
      old.ghostRim != ghostRim ||
      old.ghostShade != ghostShade;
}

// -------------------------------------------------------------------- labels --

/// Laid-out label text, kept between frames (owned by the view's state).
class PlanetLabelCache {
  final Map<String, TextPainter> _text = {};
  final Map<String, Rect> lastRect = {};

  /// The candidate slot each label used last frame (hysteresis).
  final Map<String, int> slots = {};

  /// Displayed offset of each label's centre from its body's centre (it
  /// glides to a new spot instead of jumping).
  final Map<String, Offset> shown = {};

  /// Controller time of the last paint (for the glide).
  double lastTime = double.nan;
  final Set<String> _used = {};
  PlanetLayerStyle? _style;
  TextDirection? _direction;

  final List<LabelObstacle> obstacles = [];
  final List<Rect> taken = [];
  final List<BodyFrame> order = [];
  final Paint dot = Paint();
  final Paint dotGlow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
  final Paint layer = Paint();

  /// The laid-out [text] (ellipsised to [maxWidth]).
  TextPainter painter(String text, TextStyle style, TextDirection direction, double maxWidth, {required String kind}) {
    final key = '$kind|$text|${maxWidth.round()}';
    _used.add(key);
    return _text[key] ??= TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }

  /// Starts a paint pass; drops everything when the look changed.
  void begin(PlanetLayerStyle style, TextDirection direction) {
    if (style != _style || direction != _direction) {
      clear();
      _style = style;
      _direction = direction;
    }
    _used.clear();
    obstacles.clear();
    taken.clear();
  }

  /// Disposes text not used in the last pass (every so often).
  void sweep() {
    if (_text.length < 48) return;
    _text.removeWhere((k, tp) {
      if (_used.contains(k)) return false;
      tp.dispose();
      return true;
    });
  }

  void clear() {
    for (final tp in _text.values) {
      tp.dispose();
    }
    _text.clear();
    lastRect.clear();
    slots.clear();
    shown.clear();
  }
}

/// Planet name labels – calm, text-only (IBM Plex Sans Arabic SemiBold at
/// ~80 % with a soft shadow and the world's colour as a small glowing dot on
/// the reading-start side) – and, when zoomed in far enough, the moons'
/// names. A label sits beside its own world ([LabelPlacer]: below first),
/// keeps its spot while it stays (nearly) clear – no hopping as the system
/// drifts – and never covers a disc (worlds, moons, the astrolabe) or
/// another label. Where no clean spot exists, or its world is hidden
/// (behind the dial, behind a nearer world, off screen), the label fades
/// out instead of wandering off on a leader line.
class PlanetLabelsPainter extends CustomPainter {
  PlanetLabelsPainter({
    required this.controller,
    required this.style,
    required this.cache,
    required this.textDirection,
    this.snap = false,
  }) : super(repaint: controller);

  final PlanetSceneController controller;
  final PlanetLayerStyle style;

  /// [style] for the sky behind (Pearl's dark night takes light ink).
  PlanetLayerStyle get _sky => style.forSky(darkSky: controller.skyDark);
  final PlanetLabelCache cache;
  final TextDirection textDirection;

  /// Show labels at their target opacity at once (stills, reduced motion).
  final bool snap;

  /// Hysteresis of a label's spot (fraction of its area it may overlap
  /// before it moves).
  static const double stickiness = 0.14;

  static int _priority(BodyFrame a, BodyFrame b) => b.radius.compareTo(a.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final f = controller.frameFor(size);
    cache.begin(_sky, textDirection);
    final snapNow = snap || controller.reducedMotion;
    final t = controller.time;
    final dt = cache.lastTime.isNaN ? 0.0 : (t - cache.lastTime).clamp(0.0, 0.1);
    cache.lastTime = t;
    _glide = snapNow ? 1.0 : 1 - math.exp(-dt / 0.14);
    final obstacles = cache.obstacles;
    // During a fly-in the other worlds are background (the scene blurs
    // them): only the focused world and its moons are obstacles.
    final focusKey = controller.focus >= 0.5 ? controller.focusKey : null;
    for (final b in f.drawOrder) {
      if (focusKey != null && b.key != focusKey) continue;
      if (b.visible) obstacles.add((center: b.center, radius: b.radius * PlanetStyle.clearanceOf(b.body.archetype)));
      for (final m in b.moons) {
        if (m.visible && m.radius > 1.5) obstacles.add((center: m.center, radius: m.radius * 1.15));
      }
    }
    // The dial is always an obstacle while it shows (labels never sit on
    // the brass), wherever the world is.
    if (_dialShown(f)) obstacles.add((center: f.coreCenter, radius: f.coreRadius * 1.04));
    final order = cache.order
      ..clear()
      ..addAll(f.drawOrder);
    final selected = controller.selectedKey;
    order.sort(_priority);
    if (selected != null) {
      final i = order.indexWhere((b) => b.key == selected);
      if (i > 0) order.insert(0, order.removeAt(i));
    }

    // Moon labels first (they sit closest to their bodies), then planets.
    for (final b in order) {
      for (final m in b.moons) {
        _moonLabel(canvas, size, f, b, m, snapNow);
      }
    }
    for (final b in order) {
      _planetLabel(canvas, size, f, b, snapNow);
    }
    // Worlds that left the draw order fade out where they were.
    for (final b in f.bodies) {
      if (!f.drawOrder.contains(b)) controller.planetLabels.target(b.key, 0, snap: snapNow);
    }
    cache.sweep();
  }

  double _glide = 1;

  bool _dialShown(PlanetFrame f) => f.coreRadius > 0 && controller.coreOpacity > 0.5 && controller.focus < 0.5;

  /// A world hidden behind the dial (bar a sliver), or behind a nearer
  /// world: its label stays down (it would name nothing visible).
  bool _hidden(PlanetFrame f, BodyFrame b) {
    if (b.behindCore && _dialShown(f) && b.coreOcclusion > 0.85) return true;
    for (final n in f.drawOrder) {
      if (identical(n, b) || !n.visible || n.depth >= b.depth || n.opacity < 0.5) continue;
      if ((n.center - b.center).distance + b.radius * 0.35 < n.radius) return true;
    }
    return false;
  }

  /// A body whose centre is off screen gets no label (it would float free
  /// of anything visible).
  static bool _onScreen(Offset c, Size size) => c.dx >= 0 && c.dy >= 0 && c.dx <= size.width && c.dy <= size.height;

  /// Where the label [key] of a body at [center] goes this frame: its spot
  /// (gliding toward a new one) or null when no clean spot exists.
  Rect? _place(
    String key, {
    required Offset center,
    required double clearance,
    required Size pill,
    required Size size,
    required double gap,
    Offset? ignoreAlso,
  }) {
    final spot = LabelPlacer.placeBest(
      center: center,
      clearance: clearance,
      size: pill,
      direction: textDirection,
      viewport: size,
      area: controller.labelArea,
      obstacles: cache.obstacles,
      keepOut: controller.labelKeepOut,
      taken: cache.taken,
      ignore: center,
      ignoreAlso: ignoreAlso,
      gap: gap,
      previousSlot: cache.slots[key],
      leaders: false,
      stickiness: stickiness,
    );
    if (!spot.clean) return null;
    cache.slots[key] = spot.slot;
    cache.taken.add(spot.rect);
    final target = spot.rect.center - center;
    final shown = cache.shown[key];
    final now = shown == null || _glide >= 1 ? target : Offset.lerp(shown, target, _glide)!;
    cache.shown[key] = now;
    return Rect.fromCenter(center: center + now, width: pill.width, height: pill.height);
  }

  /// The rect a fading label keeps (where it last was, following its body).
  Rect? _fading(String key, Offset center, Size pill) {
    final shown = cache.shown[key];
    return shown == null ? null : Rect.fromCenter(center: center + shown, width: pill.width, height: pill.height);
  }

  void _planetLabel(Canvas canvas, Size size, PlanetFrame f, BodyFrame b, bool snapNow) {
    final key = b.key;
    var target = b.labelTarget;
    if (target > 0 && (_hidden(f, b) || !_onScreen(b.center, size))) target = 0;
    if (b.radius <= 0) {
      controller.planetLabels.target(key, 0, snap: snapNow);
      return;
    }
    final selected = key == controller.selectedKey;
    final ts = selected ? _sky.planetLabel.copyWith(fontSize: 14 * _sky.textScale) : _sky.planetLabel;
    final tp = cache.painter(
      b.body.name.trim(),
      ts,
      textDirection,
      LabelPlacer.maxWidthFor(b.radius, size),
      kind: selected ? 'ps' : 'p',
    );
    final pill = Size(tp.width + _dotSpace, tp.height);
    final clearance = b.radius * PlanetStyle.clearanceOf(b.body.archetype);
    Rect? rect;
    if (target > 0) {
      rect = _place(
        key,
        center: b.center,
        clearance: clearance,
        pill: pill,
        size: size,
        gap: 3 + math.min(5, b.radius * 0.1),
      );
      if (rect == null) target = 0;
    }
    controller.planetLabels.target(key, target, snap: snapNow);
    final opacity = controller.planetLabels.of(key);
    rect ??= _fading(key, b.center, pill);
    if (opacity <= 0.01 || rect == null) return;
    cache.lastRect[key] = rect;
    _drawLabel(canvas, rect, tp, b.body.palette.glow, opacity);
  }

  /// Width the dot and its gap add to a planet label.
  static const _dotSpace = 11.0;

  void _drawLabel(Canvas canvas, Rect rect, TextPainter tp, Color dotColor, double opacity) {
    final layered = opacity < 0.995;
    if (layered) {
      cache.layer.color = Color.fromRGBO(0, 0, 0, opacity);
      canvas.saveLayer(rect.inflate(10), cache.layer);
    }
    // The world's colour as a small glowing dot on the reading-start side.
    final rtl = textDirection == TextDirection.rtl;
    final dotCenter = Offset(rtl ? rect.right - 3 : rect.left + 3, rect.center.dy + 0.5);
    cache.dotGlow.color = dotColor.withValues(alpha: 0.7);
    canvas.drawCircle(dotCenter, 3.2, cache.dotGlow);
    cache.dot.color = dotColor;
    canvas.drawCircle(dotCenter, 2.1, cache.dot);
    final textLeft = rtl ? rect.right - _dotSpace - tp.width : rect.left + _dotSpace;
    tp.paint(canvas, Offset(textLeft, rect.top));
    if (layered) canvas.restore();
  }

  void _moonLabel(Canvas canvas, Size size, PlanetFrame f, BodyFrame b, MoonFrame m, bool snapNow) {
    final id = m.id;
    var target = m.labelTarget;
    // A moon behind its own world (or behind the dial with it) names
    // nothing visible.
    if (target > 0 && !m.front && (m.center - b.center).distance < b.radius * 1.02) target = 0;
    if (target > 0 && !_onScreen(m.center, size)) target = 0;
    if (target > 0 && b.behindCore && _dialShown(f) && (m.center - f.coreCenter).distance < f.coreRadius) target = 0;
    if (m.radius <= 0) {
      controller.moonLabels.target(id, 0, snap: snapNow);
      return;
    }
    final tp = cache.painter(
      m.moon.label.trim(),
      _sky.moonLabel,
      textDirection,
      math.min(120, size.width * 0.3),
      kind: 'm',
    );
    final pill = Size(tp.width, tp.height);
    Rect? rect;
    if (target > 0) {
      rect = _place(
        'm:$id',
        center: m.center,
        clearance: m.radius * 1.2,
        pill: pill,
        size: size,
        gap: 2.5,
        ignoreAlso: m.front ? b.center : null,
      );
      if (rect == null) target = 0;
    }
    controller.moonLabels.target(id, target, snap: snapNow);
    final opacity = controller.moonLabels.of(id);
    rect ??= _fading('m:$id', m.center, pill);
    if (opacity <= 0.01 || rect == null) return;
    cache.lastRect['m:$id'] = rect;
    final layered = opacity < 0.995;
    if (layered) {
      cache.layer.color = Color.fromRGBO(0, 0, 0, opacity);
      canvas.saveLayer(rect.inflate(8), cache.layer);
    }
    tp.paint(canvas, rect.topLeft);
    if (layered) canvas.restore();
  }

  /// Never claims a pointer (taps go to [PlanetHitRegion] / the scene).
  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(PlanetLabelsPainter old) =>
      old.controller != controller ||
      old.style != style ||
      old.cache != cache ||
      old.textDirection != textDirection ||
      old.snap != snap;
}
