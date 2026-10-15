import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../core/design/painters/islamic_star_painter.dart' show IslamicGeometry;
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/i18n/formatters.dart' show Digits;
import '../../orbit/render/astrolabe/astrolabe_geometry.dart' show AstrolabeRadii;
import '../../orbit/render/astrolabe/astrolabe_palette.dart';
import '../../orbit/render/astrolabe/astrolabe_paths.dart';
import 'assembly.dart';

/// Everything that changes from frame to frame on the lock dial.
@immutable
class LockDialFrame {
  const LockDialFrame({
    this.progress = 0,
    this.ignite = 0,
    this.scan = 0,
    this.time = 0,
    this.drift = 0,
    this.error = 0,
    this.ruleAngle = -math.pi / 2,
  });

  /// Assembly progress p (see [AssemblyTimeline]).
  final double progress;

  /// 0 → 1 once the dial is complete: the core star flares and settles.
  final double ignite;

  /// Intensity of the "reading" sweep around the limb (fingerprint prompt).
  final double scan;

  /// Seconds of ambient time (drift, glints, the sweep).
  final double time;

  /// Amplitude of the idle float of unassembled parts (0 when still).
  final double drift;

  /// A red pulse after a wrong PIN / failed read.
  final double error;

  /// Where the rule points once it locks (canvas radians).
  final double ruleAngle;

  @override
  bool operator ==(Object other) =>
      other is LockDialFrame &&
      other.progress == progress &&
      other.ignite == ignite &&
      other.scan == scan &&
      other.time == time &&
      other.drift == drift &&
      other.error == error &&
      other.ruleAngle == ruleAngle;

  @override
  int get hashCode => Object.hash(progress, ignite, scan, time, drift, error, ruleAngle);
}

/// The lock dial's colours: the orbit astrolabe's palette plus a few theme
/// tokens for glows.
@immutable
class LockDialLook {
  const LockDialLook({required this.palette, required this.glow, required this.gold, required this.danger});

  factory LockDialLook.of(MadarTokens t) =>
      LockDialLook(palette: AstrolabePalette.fromTokens(t), glow: t.accentGlow, gold: t.gold, danger: t.danger);

  final AstrolabePalette palette;
  final Color glow, gold, danger;

  @override
  bool operator ==(Object other) =>
      other is LockDialLook &&
      other.palette == palette &&
      other.glow == glow &&
      other.gold == gold &&
      other.danger == danger;

  @override
  int get hashCode => Object.hash(palette, glow, gold, danger);
}

/// Vector geometry, paints and the numeral sprites of the lock dial,
/// recorded once at a reference radius and replayed at any size (the dial
/// shrinks and grows between the hold and PIN layouts without re-recording).
class LockDialCache {
  static const double refR = 160;

  Object? _key;
  bool _disposed = false;

  late Path limb, ticks, beads, plateClip, girih, almucantars, hourLines;
  late Path reteStraps, reteOvers, reteOverEdges, reteLines, reteFlames, reteBosses, reteRibs, reteRings;
  late Offset eclipticCenter;
  late double eclipticRadius;
  late List<Offset> starTips;
  late Path rule, ruleEdge, hubRing, hubStar;

  late Paint platePaint, sheenPaint, girihPaint, almuPaint, hourPaint, channelPaint, rimShadowPaint;
  late Paint inkPaint, tickPaint, beadPaint, bevelOuter, bevelInner, fallbackBrass;
  late Paint shadowFill, shadowStroke, outline, groove, eyePaint;
  late Paint jewelGlow, jewelCore, haloPaint;

  /// Numeral sprites (hour h at index h − 1).
  final List<ui.Image> numerals = [];
  double _numeralScale = 0;

  /// Sweep gradients start at the light's direction (upper left); Skia only
  /// sweeps within [0, 2π], so the turn is a matrix.
  static final Float64List _lightTurn = Matrix4.rotationZ(-math.pi * 0.75).storage;

  /// Rebuilds for a new [look] / numeral style / pixel density.
  void ensure(LockDialLook look, {required bool arabicIndic, required double pixelScale}) {
    final key = (look, arabicIndic);
    final scale = (pixelScale * 4).ceilToDouble() / 4;
    if (key == _key && scale <= _numeralScale) return;
    if (key != _key) {
      _key = key;
      _build(look);
    }
    _buildNumerals(look.palette, arabicIndic, math.max(scale, 1));
  }

  bool get isReady => _key != null;

  void _build(LockDialLook look) {
    final p = look.palette;
    const r = refR;
    Path circle(double radius, [Offset c = Offset.zero]) => Path()..addOval(Rect.fromCircle(center: c, radius: radius));

    limb = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r))
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * AstrolabeRadii.limbInner));

    // 24-hour scale: hour, half and quarter ticks in the scale band.
    ticks = Path();
    for (var i = 0; i < 96; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 96;
      final len = i % 4 == 0 ? 1.0 : (i % 2 == 0 ? 0.62 : 0.38);
      const outer = AstrolabeRadii.scaleOuter;
      const band = AstrolabeRadii.scaleOuter - AstrolabeRadii.scaleInner;
      final d = Offset(math.cos(a), math.sin(a));
      ticks
        ..moveTo(d.dx * r * outer, d.dy * r * outer)
        ..lineTo(d.dx * r * (outer - band * len), d.dy * r * (outer - band * len));
    }
    beads = Path();
    const beadR = (AstrolabeRadii.beadOuter + AstrolabeRadii.beadInner) / 2;
    for (var i = 0; i < 72; i++) {
      final a = i * 2 * math.pi / 72;
      beads.addOval(Rect.fromCircle(center: Offset(math.cos(a), math.sin(a)) * (r * beadR), radius: r * 0.0085));
    }

    const plateR = r * AstrolabeRadii.limbInner;
    plateClip = circle(plateR);
    girih = AstrolabePaths.girih(scale: plateR, spacing: 0.21);
    // Almucantars: circles of equal altitude crowding towards the zenith
    // (a stereographic plate's signature), and the horizon below them.
    almucantars = Path();
    for (var k = 0; k < 9; k++) {
      final f = k / 8;
      final cy = -plateR * (0.1 + 0.3 * f * f);
      final rad = plateR * (0.78 - 0.66 * math.pow(f, 0.8));
      almucantars.addOval(Rect.fromCircle(center: Offset(0, cy), radius: rad));
    }
    hourLines = Path();
    for (var i = 0; i < 24; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 24;
      final d = Offset(math.cos(a), math.sin(a));
      hourLines
        ..moveTo(d.dx * r * 0.3, d.dy * r * 0.3)
        ..lineTo(d.dx * r * AstrolabeRadii.channelInner, d.dy * r * AstrolabeRadii.channelInner);
    }

    // The rete, from the orbit astrolabe's model (unit coordinates).
    final model = AstrolabePaths.rete();
    final m = Matrix4.diagonal3Values(r, r, 1).storage;
    reteStraps = model.straps.transform(m);
    reteOvers = model.overs.transform(m);
    reteOverEdges = model.overEdges.transform(m);
    reteLines = model.strapLines.transform(m);
    reteFlames = model.flames.transform(m);
    reteBosses = model.bosses.transform(m);
    reteRibs = model.ribs.transform(m);
    reteRings = model.rings.transform(m);
    eclipticCenter = model.eclipticCenter * r;
    eclipticRadius = model.eclipticRadius * r;
    starTips = [for (final s in model.stars) s.tip * r];

    // The rule: a slender blade across the dial with needle tips and a
    // fiducial groove.
    const len = r * 0.8, half = r * 0.018, tip = r * 0.09;
    rule = Path()
      ..moveTo(-len, 0)
      ..lineTo(-len + tip, -half)
      ..lineTo(len - tip, -half)
      ..lineTo(len, 0)
      ..lineTo(len - tip, half)
      ..lineTo(-len + tip, half)
      ..close()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * 0.05));
    ruleEdge = Path()
      ..moveTo(-len + tip * 0.6, 0)
      ..lineTo(len - tip * 0.6, 0);

    hubRing = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * 0.135))
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * 0.092));
    hubStar = IslamicGeometry.starPath(center: Offset.zero, radius: r * 0.078, points: 8, rotation: math.pi / 8);

    // ------------------------------------------------------------ paints
    platePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        plateR,
        [p.enamelCenter, p.enamelMid, p.enamelEdge],
        const [0, 0.6, 1],
      );
    sheenPaint = Paint()
      ..shader = ui.Gradient.radial(const Offset(-plateR * 0.35, -plateR * 0.45), plateR * 0.9, [
        p.enamelSheen.withValues(alpha: 0.38),
        p.enamelSheen.withValues(alpha: 0),
      ]);
    girihPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55
      ..color = p.plateLine.withValues(alpha: 0.17);
    almuPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = p.plateLine.withValues(alpha: 0.34);
    hourPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = p.plateLine.withValues(alpha: 0.22);
    channelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = p.plateLine.withValues(alpha: 0.55);
    rimShadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = plateR * 0.08
      ..shader = ui.Gradient.radial(
        Offset.zero,
        plateR,
        [p.shadow.withValues(alpha: 0), p.shadow.withValues(alpha: 0), p.shadow.withValues(alpha: 0.55)],
        const [0, 0.9, 1],
      );
    inkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = p.ink.withValues(alpha: 0.8);
    tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = p.ink.withValues(alpha: 0.85);
    beadPaint = Paint()..color = p.brassHi.withValues(alpha: 0.55);
    // Chamfers lit from the upper left.
    Paint bevel(double width, bool outer) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = ui.Gradient.sweep(
        Offset.zero,
        [
          p.bevelLight.withValues(alpha: outer ? 0.95 : 0.2),
          p.bevelLight.withValues(alpha: 0),
          p.bevelDark.withValues(alpha: outer ? 0.6 : 0.9),
          p.bevelLight.withValues(alpha: 0),
          p.bevelLight.withValues(alpha: outer ? 0.95 : 0.2),
        ],
        const [0, 0.28, 0.5, 0.72, 1],
        TileMode.clamp,
        0,
        2 * math.pi,
        _lightTurn,
      );
    bevelOuter = bevel(r * 0.012, true);
    bevelInner = bevel(r * 0.01, false);
    // Without the brass shader: an anisotropic sweep, brightest along the
    // light's axis (upper left / lower right).
    final brassHi = p.light ? Color.lerp(p.brassHi, p.brass, 0.15)! : p.brassHi;
    fallbackBrass = Paint()
      ..shader = ui.Gradient.sweep(
        Offset.zero,
        [brassHi, p.brass, p.brassLow, p.brass, brassHi, p.brass, p.brassLow, p.brass, brassHi],
        const [0, 0.13, 0.25, 0.37, 0.5, 0.63, 0.75, 0.87, 1],
        TileMode.clamp,
        0,
        2 * math.pi,
        _lightTurn,
      );
    shadowFill = Paint()..color = p.shadow.withValues(alpha: p.light ? 0.4 : 0.6);
    shadowStroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = p.shadow.withValues(alpha: p.light ? 0.4 : 0.6);
    outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..color = p.ink.withValues(alpha: 0.9);
    groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.8
      ..color = p.ink.withValues(alpha: 0.5);
    eyePaint = Paint()..color = p.ink.withValues(alpha: 0.85);
    jewelGlow = Paint()
      ..blendMode = p.light ? BlendMode.srcOver : BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2);
    jewelCore = Paint();
    haloPaint = Paint();
  }

  void _buildNumerals(AstrolabePalette p, bool arabicIndic, double pixelScale) {
    for (final img in numerals) {
      img.dispose();
    }
    numerals.clear();
    _numeralScale = pixelScale;
    const font = refR * 0.074;
    for (var h = 1; h <= 24; h++) {
      final label = arabicIndic ? Digits.toArabicIndic('$h') : '$h';
      TextPainter layout(Color c) => TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: MadarTypography.uiFamily,
            fontSize: font,
            fontWeight: FontWeight.w700,
            height: 1,
            color: c,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final ink = layout(p.ink.withValues(alpha: 0.95));
      final lit = layout(p.engraveHi.withValues(alpha: 0.55));
      final w = ink.width + 4, hgt = ink.height + 4;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(pixelScale);
      // Engraved: the incision's lit lower lip, then the dark cut.
      lit.paint(c, const Offset(2, 2.7));
      ink.paint(c, const Offset(2, 2));
      final pic = rec.endRecording();
      numerals.add(pic.toImageSync((w * pixelScale).ceil(), (hgt * pixelScale).ceil()));
      pic.dispose();
      ink.dispose();
      lit.dispose();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final img in numerals) {
      img.dispose();
    }
    numerals.clear();
  }
}

/// Paints the lock screen's astrolabe mid-assembly: every part in its own
/// 3D pose (see [AssemblyTimeline]) – limb, plate, numerals, rete with its
/// star jewels, rule and hub – plus the reading sweep, the ignition flare
/// and the error pulse. Colours come from [look] (theme tokens through the
/// orbit astrolabe's palette); metal uses the orbit's brass shader when
/// [brass] is given, a sweep gradient otherwise.
class LockAstrolabePainter extends CustomPainter {
  LockAstrolabePainter({
    required this.frame,
    required this.look,
    required this.cache,
    required this.arabicIndic,
    this.devicePixelRatio = 2,
    this.brass,
  });

  /// The painted dial's radius is `size.shortestSide / 2 / boxFactor` (the
  /// rest of the box is room for parts flying in).
  static const double boxFactor = 1.24;

  final LockDialFrame frame;
  final LockDialLook look;
  final LockDialCache cache;
  final bool arabicIndic;
  final double devicePixelRatio;
  final ui.FragmentShader? brass;

  static const double _ref = LockDialCache.refR;
  final Paint _layer = Paint();
  final Paint _brassPaint = Paint();
  final Paint _fx = Paint();
  final Paint _metalStroke = Paint()..style = PaintingStyle.stroke;

  AstrolabePalette get _p => look.palette;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2 / boxFactor;
    if (radius < 8) return;
    final k = radius / _ref;
    cache.ensure(look, arabicIndic: arabicIndic, pixelScale: devicePixelRatio * k * 1.9);
    final c = size.center(Offset.zero);
    final p = frame.progress;
    final bounds = (Offset.zero & size).inflate(radius * 0.6);
    final metal = _metal(k);

    _halo(canvas, c, radius, p);
    _part(canvas, c, radius, k, bounds, AstrolabePart.plate, 0, _plate);
    _part(canvas, c, radius, k, bounds, AstrolabePart.limb, 1, (cv) => _limb(cv, metal));
    _numerals(canvas, c, radius, k, p);
    _part(canvas, c, radius, k, bounds, AstrolabePart.rete, 2, (cv) => _rete(cv, metal, p));
    _part(
      canvas,
      c,
      radius,
      k,
      bounds,
      AstrolabePart.rule,
      3,
      (cv) => _rule(cv, metal),
      extraRotation: frame.ruleAngle,
    );
    _part(canvas, c, radius, k, bounds, AstrolabePart.hub, 4, (cv) => _hub(cv, metal));
    _scan(canvas, c, radius);
    _ignite(canvas, c, radius);
    _error(canvas, c, radius);
  }

  // ------------------------------------------------------------------ poses

  /// Paints one part under its pose: opacity / depth blur as a layer, then
  /// position, perspective tilt, turn and scale around the dial's centre.
  void _part(
    Canvas canvas,
    Offset c,
    double radius,
    double k,
    Rect bounds,
    AstrolabePart part,
    int seed,
    void Function(Canvas) paint, {
    double extraRotation = 0,
  }) {
    final pose = AssemblyTimeline.pose(part, frame.progress);
    if (pose.opacity <= 0.004) return;
    final d = AssemblyTimeline.displacement(AssemblyTimeline.local(part, frame.progress)).clamp(0.0, 1.0);
    final drift = frame.drift * d;
    var offset = pose.offset;
    var rotation = pose.rotation + extraRotation;
    if (drift > 0) {
      final t = frame.time;
      offset += Offset(math.sin(t * 0.47 + seed * 1.9), math.cos(t * 0.39 + seed * 2.7)) * (0.035 * drift);
      rotation += math.sin(t * 0.23 + seed) * 0.12 * drift;
    }
    final layered = pose.opacity < 0.995 || pose.blur > 0.3;
    if (layered) {
      _layer
        ..color = Color.fromRGBO(0, 0, 0, pose.opacity.clamp(0.0, 1.0))
        ..imageFilter = pose.blur > 0.3 ? ui.ImageFilter.blur(sigmaX: pose.blur, sigmaY: pose.blur) : null;
      canvas.saveLayer(bounds, _layer);
    }
    canvas
      ..save()
      ..translate(c.dx + offset.dx * radius, c.dy + offset.dy * radius);
    if (pose.tiltX.abs() > 1e-4 || pose.tiltY.abs() > 1e-4) {
      canvas.transform(
        (Matrix4.identity()
              ..setEntry(3, 2, 1 / (radius * 4.2))
              ..rotateX(pose.tiltX)
              ..rotateY(pose.tiltY))
            .storage,
      );
    }
    canvas
      ..rotate(rotation)
      ..scale(pose.scale * k);
    paint(canvas);
    canvas.restore();
    if (layered) canvas.restore();
  }

  // ------------------------------------------------------------------ metal

  Paint _metal(double k) {
    final s = brass;
    if (s == null) return cache.fallbackBrass;
    // brass.frag: uSize, uCenter, uScale, uLight, uTime, uWear, uBase, uHi,
    // uLow – local coordinates around each part's centre.
    var i = 0;
    void f(double v) => s.setFloat(i++, v);
    void col(Color c) {
      f(c.r);
      f(c.g);
      f(c.b);
      f(c.a);
    }

    f(0);
    f(0);
    f(0);
    f(0);
    f(_ref);
    f(-0.55);
    f(-0.83);
    f(frame.time % 7200);
    f(0);
    col(_p.brass);
    col(_p.brassHi);
    col(_p.brassLow);
    return _brassPaint..shader = s;
  }

  // ------------------------------------------------------------------ parts

  void _halo(Canvas canvas, Offset c, double radius, double p) {
    final u = AssemblyTimeline.local(AstrolabePart.limb, p);
    final a =
        (0.25 + 0.75 * AssemblyTimeline.opacity(u)) * (0.55 + 0.45 * AssemblyTimeline.local(AstrolabePart.hub, p));
    if (_p.light) {
      // A cast shadow belongs to a dial that is there: it grows with the
      // limb (no grey smudge under the scattered parts on Pearl).
      final shade = a * AssemblyTimeline.opacity(u) * (1 - AssemblyTimeline.displacement(u)).clamp(0.0, 1.0);
      if (shade <= 0.005) return;
      _fx
        ..shader = null
        ..blendMode = BlendMode.srcOver
        ..color = _p.shadow.withValues(alpha: 0.5 * shade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.06);
      canvas.drawCircle(c + Offset(0, radius * 0.04), radius * 0.99 * (0.6 + 0.4 * u), _fx);
      _fx.maskFilter = null;
      return;
    }
    _fx
      ..maskFilter = null
      ..color = const Color(0xFF000000)
      ..blendMode = BlendMode.srcOver
      ..shader = ui.Gradient.radial(
        c,
        radius * 1.32,
        [_p.halo.withValues(alpha: 0.32 * a), _p.halo.withValues(alpha: 0.12 * a), _p.halo.withValues(alpha: 0)],
        const [0.55, 0.78, 1],
      );
    canvas.drawCircle(c, radius * 1.32, _fx);
    _fx.shader = null;
  }

  void _plate(Canvas cv) {
    const plateR = _ref * AstrolabeRadii.limbInner;
    cv.drawCircle(Offset.zero, plateR, cache.platePaint);
    cv
      ..save()
      ..clipPath(cache.plateClip)
      ..drawPath(cache.girih, cache.girihPaint)
      ..drawPath(cache.almucantars, cache.almuPaint)
      ..drawPath(cache.hourLines, cache.hourPaint)
      ..restore();
    cv
      ..drawCircle(Offset.zero, _ref * AstrolabeRadii.channelOuter, cache.channelPaint)
      ..drawCircle(Offset.zero, _ref * AstrolabeRadii.channelInner, cache.channelPaint)
      ..drawCircle(Offset.zero, _ref * AstrolabeRadii.capricorn, cache.almuPaint)
      ..drawCircle(Offset.zero, plateR, cache.sheenPaint)
      ..drawCircle(Offset.zero, plateR * 0.96, cache.rimShadowPaint);
  }

  void _limb(Canvas cv, Paint metal) {
    cv
      ..drawPath(cache.limb, metal)
      ..drawCircle(Offset.zero, _ref * AstrolabeRadii.scaleOuter, cache.inkPaint)
      ..drawCircle(Offset.zero, _ref * AstrolabeRadii.scaleInner, cache.inkPaint)
      ..drawCircle(Offset.zero, _ref * AstrolabeRadii.numeralsInner - 1, cache.inkPaint)
      ..drawPath(cache.ticks, cache.tickPaint)
      ..drawPath(cache.beads, cache.beadPaint)
      ..drawCircle(Offset.zero, _ref * 0.994, cache.bevelOuter)
      ..drawCircle(Offset.zero, _ref * (AstrolabeRadii.limbInner + 0.005), cache.bevelInner);
  }

  void _numerals(Canvas canvas, Offset c, double radius, double k, double p) {
    final images = cache.numerals;
    if (images.length != 24) return;
    // Dark ink on a light theme reads much stronger: a fainter ghost there.
    final ghost = AssemblyTimeline.scattered[AstrolabePart.numerals]!.opacity * (_p.light ? 0.6 : 1);
    final limb = AssemblyTimeline.pose(AstrolabePart.limb, p);
    const ringR = _ref * (AstrolabeRadii.numerals + AstrolabeRadii.numeralsInner) / 2;
    for (var i = 0; i < 24; i++) {
      // Noon at the top, then clockwise round the day.
      final h = (12 + i - 1) % 24 + 1;
      final u = AssemblyTimeline.staggered(AstrolabePart.numerals, i, 24, p, span: 0.42);
      final d = AssemblyTimeline.displacement(u);
      final alpha = ghost + (1 - ghost) * AssemblyTimeline.opacity(u);
      if (alpha <= 0.01) continue;
      final dc = d.clamp(0.0, 1.0);
      // Scattered as a wider, slowly swirling ring (one direction, so no two
      // numerals cross), each at its own depth.
      var a = -math.pi / 2 + i * 2 * math.pi / 24 + 0.55 * d;
      var rr = ringR * (1 + 0.5 * d + 0.12 * dc * math.sin(i * 2.39));
      if (frame.drift > 0 && dc > 0) {
        a += math.sin(frame.time * 0.31 + i) * 0.05 * dc * frame.drift;
        rr += math.cos(frame.time * 0.27 + i * 1.3) * 6 * dc * frame.drift;
      }
      // Numerals ride with the limb once it has arrived.
      final spin = limb.rotation * (1 - dc);
      final pos = Offset(math.cos(a + spin), math.sin(a + spin)) * rr * k * limb.scale;
      final img = images[h - 1];
      final s = (1 + 0.35 * d) / cache._numeralScale * k;
      final w = img.width * s, hh = img.height * s;
      canvas
        ..save()
        ..translate(
          c.dx + pos.dx + limb.offset.dx * radius * (1 - dc),
          c.dy + pos.dy + limb.offset.dy * radius * (1 - dc),
        )
        ..rotate(_upright(a + spin + math.pi / 2));
      _fx
        ..shader = null
        ..maskFilter = null
        ..blendMode = BlendMode.srcOver
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
      canvas
        ..drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromCenter(center: Offset.zero, width: w, height: hh),
          _fx,
        )
        ..restore();
    }
  }

  /// Keeps a tangential numeral readable: the lower half of the ring is
  /// turned the other way round (tops towards the centre).
  static double _upright(double a) {
    final n = math.atan2(math.sin(a), math.cos(a));
    return n.abs() > math.pi / 2 ? n + math.pi : n;
  }

  void _rete(Canvas cv, Paint metal, double p) {
    const shadow = Offset(_ref * 0.012, _ref * 0.018);
    final ringW = _ref * ReteModel.ringWidth;
    final eclW = _ref * ReteModel.eclipticWidth;
    // Cast shadow on the plate.
    cv
      ..save()
      ..translate(shadow.dx, shadow.dy)
      ..drawPath(cache.reteRings, cache.shadowStroke..strokeWidth = ringW)
      ..drawCircle(cache.eclipticCenter, cache.eclipticRadius, cache.shadowStroke..strokeWidth = eclW)
      ..drawPath(cache.reteStraps, cache.shadowFill)
      ..drawPath(cache.reteFlames, cache.shadowFill)
      ..restore();
    // Dark outlines.
    cv
      ..drawPath(cache.reteRings, cache.outline..strokeWidth = ringW + 1.6)
      ..drawCircle(cache.eclipticCenter, cache.eclipticRadius, cache.outline..strokeWidth = eclW + 1.6)
      ..drawPath(cache.reteStraps, cache.outline..strokeWidth = 1.5)
      ..drawPath(cache.reteFlames, cache.outline..strokeWidth = 1.5);
    // Metal.
    final stroke = _metalStroke
      ..shader = metal.shader
      ..color = metal.color;
    cv
      ..drawPath(cache.reteRings, stroke..strokeWidth = ringW)
      ..drawCircle(cache.eclipticCenter, cache.eclipticRadius, stroke..strokeWidth = eclW)
      ..drawPath(cache.reteStraps, metal)
      ..drawPath(cache.reteLines, cache.groove)
      ..drawPath(cache.reteOverEdges, cache.outline..strokeWidth = 1.3)
      ..drawPath(cache.reteOvers, metal)
      ..drawPath(cache.reteFlames, metal)
      ..drawPath(cache.reteRibs, cache.groove)
      ..drawPath(cache.reteBosses, metal)
      ..drawPath(cache.reteBosses, cache.outline..strokeWidth = 1)
      // Ecliptic ring rails.
      ..drawCircle(cache.eclipticCenter, cache.eclipticRadius + eclW * 0.5 - 1.2, cache.inkPaint)
      ..drawCircle(cache.eclipticCenter, cache.eclipticRadius - eclW * 0.5 + 1.2, cache.inkPaint);
    // Star jewels at the pointer tips: ghosts while scattered, igniting one
    // after another as the stars lock in.
    final ghost = AssemblyTimeline.scattered[AstrolabePart.stars]!.opacity;
    final tips = cache.starTips;
    for (var i = 0; i < tips.length; i++) {
      final u = AssemblyTimeline.staggered(AstrolabePart.stars, i, tips.length, p, span: 0.5);
      final twinkle = 0.8 + 0.2 * math.sin(frame.time * 1.7 + i * 2.1);
      final lit = ghost + (1 - ghost) * AssemblyTimeline.opacity(u);
      // A brief flash as each star locks.
      final flash = u > 0.35 && u < 1 ? math.sin((u - 0.35) / 0.65 * math.pi) : 0.0;
      final a = (lit * twinkle).clamp(0.0, 1.0);
      cache.jewelGlow.color = _p.starCore.withValues(alpha: (0.55 * a + 0.45 * flash).clamp(0.0, 1.0));
      cv.drawCircle(tips[i], _ref * (0.02 + 0.02 * flash), cache.jewelGlow);
      cache.jewelCore.color = Color.lerp(_p.starCore, _p.starCorona, 0.6)!.withValues(alpha: a);
      cv.drawCircle(tips[i], _ref * 0.0085, cache.jewelCore);
    }
  }

  void _rule(Canvas cv, Paint metal) {
    cv
      ..save()
      ..translate(_ref * 0.008, _ref * 0.014)
      ..drawPath(cache.rule, cache.shadowFill)
      ..restore()
      ..drawPath(cache.rule, cache.outline..strokeWidth = 1.4)
      ..drawPath(cache.rule, metal)
      ..drawPath(cache.ruleEdge, cache.groove);
  }

  void _hub(Canvas cv, Paint metal) {
    final ig = frame.ignite;
    // The star's corona.
    _fx
      ..maskFilter = null
      ..blendMode = _p.light ? BlendMode.srcOver : BlendMode.plus
      ..color = const Color(0xFF000000)
      ..shader = ui.Gradient.radial(
        Offset.zero,
        _ref * 0.3,
        [
          _p.starCore.withValues(alpha: 0.5 + 0.3 * ig),
          _p.starCorona.withValues(alpha: 0.12),
          _p.starCorona.withValues(alpha: 0),
        ],
        const [0, 0.45, 1],
      );
    cv.drawCircle(Offset.zero, _ref * 0.3, _fx);
    _fx
      ..shader = null
      ..blendMode = BlendMode.srcOver;
    cv
      ..drawPath(cache.hubRing, cache.outline..strokeWidth = 1.4)
      ..drawPath(cache.hubRing, metal)
      ..drawCircle(Offset.zero, _ref * 0.113, cache.inkPaint);
    _fx.shader = ui.Gradient.radial(
      const Offset(-_ref * 0.02, -_ref * 0.03),
      _ref * 0.1,
      [
        Color.lerp(_p.starCore, const Color(0xFFFFFFFF), 0.35 + 0.3 * ig)!,
        _p.starCore,
        Color.lerp(_p.starCore, _p.brass, 0.5)!,
      ],
      const [0, 0.5, 1],
    );
    cv.drawPath(cache.hubStar, _fx);
    _fx.shader = null;
    cv.drawPath(cache.hubStar, cache.outline..strokeWidth = 0.9);
  }

  // ---------------------------------------------------------------- effects

  void _scan(Canvas canvas, Offset c, double radius) {
    final s = frame.scan;
    if (s <= 0.01) return;
    // A comet of light running round the dark channel between the limb and
    // the plate while the fingerprint is read, over a faint breathing ring.
    final a0 = frame.time * 2.8;
    final rr = radius * 0.818;
    final rect = Rect.fromCircle(center: c, radius: rr);
    final breathe = 0.5 + 0.5 * math.sin(frame.time * 3.2);
    _fx
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = _p.light ? BlendMode.srcOver : BlendMode.plus
      ..strokeWidth = radius * 0.03
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.02)
      ..color = _p.litHead.withValues(alpha: (0.14 + 0.12 * breathe) * s);
    canvas.drawCircle(c, rr, _fx);
    final turn =
        (Matrix4.translationValues(c.dx, c.dy, 0)
              ..rotateZ(a0)
              ..translateByDouble(-c.dx, -c.dy, 0, 1))
            .storage;
    for (final (width, blur, alpha) in [(0.11, 0.035, 0.45), (0.035, 0.006, 1.0)]) {
      _fx
        ..strokeWidth = radius * width
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * blur)
        ..color = const Color(0xFF000000)
        ..shader = ui.Gradient.sweep(
          c,
          [
            _p.litHead.withValues(alpha: 0),
            _p.litHead.withValues(alpha: alpha * s),
            _p.starCorona.withValues(alpha: alpha * s),
          ],
          const [0, 0.9, 1],
          TileMode.clamp,
          0,
          math.pi * 0.7,
          turn,
        );
      canvas.drawArc(rect, a0, math.pi * 0.7, false, _fx);
    }
    _fx
      ..maskFilter = null
      ..style = PaintingStyle.fill
      ..shader = null
      ..blendMode = BlendMode.srcOver;
  }

  void _ignite(Canvas canvas, Offset c, double radius) {
    final ig = frame.ignite;
    if (ig <= 0.001 || ig >= 0.999) return;
    final bloom = Curves.easeOutCubic.transform(ig);
    final fade = 1 - Curves.easeIn.transform(ig);
    _fx
      ..maskFilter = null
      ..blendMode = _p.light ? BlendMode.srcOver : BlendMode.plus
      ..color = const Color(0xFF000000)
      ..shader = ui.Gradient.radial(
        c,
        radius * (0.3 + 1.1 * bloom),
        [
          _p.starCore.withValues(alpha: 0.85 * fade),
          look.glow.withValues(alpha: 0.35 * fade),
          look.glow.withValues(alpha: 0),
        ],
        const [0, 0.35, 1],
      );
    canvas.drawCircle(c, radius * (0.3 + 1.1 * bloom), _fx);
    // Eight long rays of light turning a little as they fade.
    _fx.shader = null;
    final rays = Path();
    final len = radius * (0.35 + 1.25 * bloom);
    final w = radius * 0.03 * fade;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + math.pi / 8 + 0.25 * bloom;
      final d = Offset(math.cos(a), math.sin(a));
      final n = Offset(-d.dy, d.dx);
      rays
        ..moveTo(c.dx + n.dx * w, c.dy + n.dy * w)
        ..lineTo(c.dx + d.dx * len, c.dy + d.dy * len)
        ..lineTo(c.dx - n.dx * w, c.dy - n.dy * w)
        ..close();
    }
    _fx
      ..color = _p.starCorona.withValues(alpha: 0.7 * fade)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.01);
    canvas.drawPath(rays, _fx);
    _fx
      ..maskFilter = null
      ..blendMode = BlendMode.srcOver;
  }

  void _error(Canvas canvas, Offset c, double radius) {
    final e = frame.error;
    if (e <= 0.01) return;
    _fx
      ..shader = null
      ..blendMode = BlendMode.srcOver
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.12
      ..color = look.danger.withValues(alpha: 0.42 * e)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.05);
    canvas.drawCircle(c, radius * 0.97, _fx);
    _fx
      ..style = PaintingStyle.fill
      ..maskFilter = null;
  }

  @override
  bool shouldRepaint(LockAstrolabePainter old) =>
      old.frame != frame ||
      old.look != look ||
      old.arabicIndic != arabicIndic ||
      old.brass != brass ||
      old.devicePixelRatio != devicePixelRatio ||
      old.cache != cache;
}
