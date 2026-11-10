import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../../core/design/typography.dart';
import '../../../../core/domain/enums.dart';
import 'astrolabe_geometry.dart';
import 'astrolabe_palette.dart';
import 'astrolabe_paths.dart';
import 'astrolabe_state.dart';

/// Everything the astrolabe painter can prepare once and replay every frame:
/// engraving pictures (vector, so they stay sharp under any scale or tilt),
/// scaled paths, gradients and the text images warped onto the hub ring.
///
/// Pictures are recorded at a quantised radius ([bucketFor]) centred on the
/// origin and replayed with a small scale, so pinch-zooming re-records only
/// when the radius crosses a bucket (≈ every 18 %). Owned by the layer's
/// State; [dispose] frees the GPU resources.
class AstrolabeRenderCache {
  AstrolabeRenderCache();

  static const double bucketStep = 1.18;

  /// Quantised radius the caches are recorded at.
  static double bucketFor(double radius) {
    if (radius <= 1) return 1;
    final n = (math.log(radius) / math.log(bucketStep)).roundToDouble();
    return math.pow(bucketStep, n).toDouble();
  }

  bool _disposed = false;
  bool get isDisposed => _disposed;

  /// How often the static layer was (re)built – for tests.
  int get staticBuilds => _staticBuilds;
  int _staticBuilds = 0;

  /// How often the countdown image was rendered – for tests.
  int get countdownRenders => _countdownRenders;
  int _countdownRenders = 0;

  // ---------------------------------------------------------------- static set
  Object? _staticKey;

  /// Identity of the static layer and of the almucantars (keys of the baked
  /// layers).
  Object? get staticKey => _staticKey;
  Object? get almuKey => _almuKey;

  /// Radius (logical px) everything below is recorded at.
  double rb = 0;
  AstrolabeLod lod = AstrolabeLod.full;

  /// Engraving line unit at [rb].
  double px = 1;

  /// Limb annulus (evenOdd) and hub ring annulus at [rb].
  late Path limbPath;
  late Path hubPath;
  ui.Picture? limbInk;
  ui.Picture? plateInk;
  ui.Picture? reteInk;

  late Paint platePaint;
  late Paint plateSheenPaint;
  late Paint limbShadowPaint;
  late Paint haloPaint;

  /// Centre and radius of the halo ring's stroke.
  Offset haloCenter = Offset.zero;
  double haloRing = 0;
  late Paint bevelPaint;
  late Paint hubShadowPaint;
  late Paint hubWindowPaint;
  late Paint sunGlowPaint;
  late Paint sunDiscPaint;
  late Paint sunRayPaint;
  late Paint headGlowPaint;
  late Paint pointerGlowPaint;
  late Paint starJewelPaint;
  late Paint starLightPaint;
  late Paint hubRimLightPaint;
  late Paint windowFanPaint;
  late Paint fallbackBrassPaint;
  late Paint fallbackStarPaint;
  late Paint fallbackFirePaint;
  late Path sunRays;

  // Rete at [rb].
  late Path reteRings;
  late Path reteEcliptic;

  /// The strapwork as filled ribbons, the over pieces of the weave with
  /// their long edges, and the straps' centre lines (the engraved groove).
  late Path reteStraps;
  late Path reteOvers;
  late Path reteOverEdges;
  late Path reteLines;
  late Path reteOverLines;
  late Path reteFlames;
  late Path reteBosses;
  late List<Offset> reteStarTips;

  /// Names engraved on the rete (large dials only): star names beside their
  /// pointers and the zodiac signs on the ecliptic ring. Drawn per frame so
  /// each can be kept upright as the rete turns.
  final List<ReteLabel> reteLabels = [];

  // ---------------------------------------------------------------- almucantars
  Object? _almuKey;
  ui.Picture? almucantars;

  /// The horizon circle on the plate (plate-local, px at [rb]).
  Offset horizonCenter = Offset.zero;
  double horizonRadius = 0;

  // ---------------------------------------------------------------- prayers
  Object? _prayerKey;
  AstrolabeState? _prayerState;
  Object? _prayerStatic;
  ui.Picture? labels;

  /// Half-size of a prayer pointer's star (px at [rb]): never under 6 px so
  /// lit and unlit pointers read apart on the home-size dial.
  double get pointerRadius => math.max(rb * AstrolabeRadii.pointerStar, 6.0);
  final Map<Prayer, Path> pointerPaths = {};
  final Map<Prayer, Offset> pointerCenters = {};
  final Map<Prayer, Offset> pointerTips = {};

  /// Canvas angle of each pointer.
  final Map<Prayer, double> pointerAngles = {};

  /// Status of each prayer when the pointers were last built.
  final Map<Prayer, AstrolabePrayerStatus> statuses = {};
  Map<Prayer, double> labelAngles = const {};

  /// Centres of the engraved names (px at [rb], origin-centred).
  final Map<Prayer, Offset> labelCenters = {};

  /// [labelCenters] as a list, and the largest half-extent of a name.
  final List<Offset> labelCenterList = [];
  double labelExtent = 0;

  // ---------------------------------------------------------------- lit arc
  Object? _windowKey;

  /// The current window on the dial: start angle, sweep, elapsed sweep.
  double arcStart = 0, arcSweep = 0, arcDone = 0;
  ui.Shader? _litShader;
  double _litShaderSweep = -1;
  ui.Shader? _poolShader;
  double _poolShaderSweep = -1;

  // ---------------------------------------------------------------- hub text
  Object? _countdownKey;
  ui.Image? countdownImage;
  double countdownScale = 1;
  Object? _markKey;
  ui.Image? markImage;
  double markScale = 1;

  /// Font size (px at [rb]) of the hub ring text; the band is 1.5× that.
  /// Never under 15 px on the home-size dial: the countdown must read at a
  /// glance (the hub grows to carry it, see [hubOuter]).
  double hubFont = 10;
  double get hubBand => hubFont * 1.5;

  /// Outer edge of the hub ring: 0.285 R on large dials; on smaller ones
  /// wide enough for the 15-px countdown band around the star's window.
  double hubOuter = 0;
  double get hubInner => hubOuter - hubBand;

  /// Smallest countdown type on the home-size dial (logical px).
  static const double minHubFont = 15;

  // ============================================================== static layer

  /// (Re)builds the pieces that depend only on size, detail level, palette
  /// and language. Returns true when anything was rebuilt.
  bool ensureStatic({
    required double bucket,
    required AstrolabeLod lod,
    required AstrolabePalette palette,
    required AstrolabeLabels labels,
  }) {
    final key = (bucket, lod, palette, labels);
    if (key == _staticKey) return false;
    _staticKey = key;
    _staticBuilds++;
    rb = bucket;
    this.lod = lod;
    limbInk?.dispose();
    plateInk?.dispose();
    reteInk?.dispose();
    final r = bucket;
    px = math.max(0.6, r / 260);
    if (lod >= AstrolabeLod.full) {
      hubFont = math.max(9.0, r * 0.058);
      hubOuter = AstrolabeRadii.hubOuter * r;
    } else {
      hubFont = math.max(minHubFont, r * 0.1);
      // the band plus a window 1.7× the core star's radius
      hubOuter = math.min(0.5 * r, math.max(0.36 * r, hubFont * 1.5 + r * AstrolabeRadii.coreStar * 1.7));
    }

    limbPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r))
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * AstrolabeRadii.limbInner));
    hubPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: hubOuter))
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: hubInner));

    final plateR = r * AstrolabeRadii.limbInner;
    platePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        plateR,
        [palette.enamelCenter, palette.enamelMid, palette.enamelEdge],
        const [0.0, 0.58, 1.0],
      );
    plateSheenPaint = Paint()
      ..shader = ui.Gradient.radial(Offset(-0.32 * r, -0.42 * r), r * 0.75, [
        palette.enamelSheen.withValues(alpha: 0.3),
        palette.enamelSheen.withValues(alpha: 0),
      ]);
    // (drawn as a ring over the plate's outer rim only)
    limbShadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = plateR * 0.075
      ..shader = ui.Gradient.radial(
        Offset.zero,
        plateR,
        [
          palette.shadow.withValues(alpha: 0),
          palette.shadow.withValues(alpha: 0),
          palette.shadow.withValues(alpha: 0.5),
        ],
        const [0.0, 0.93, 1.0],
      );
    // The halo / drop shadow is drawn as a ring around the limb (nothing of
    // it shows through the disc), see [haloRing].
    final haloR = r * AstrolabeRadii.halo;
    haloPaint = palette.light
        ? (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = haloR - r * 0.93
            ..shader = ui.Gradient.radial(
              Offset(0, r * 0.03),
              haloR,
              [palette.shadow, palette.shadow, palette.shadow.withValues(alpha: 0)],
              const [0.0, 0.88, 1.0],
            ))
        : (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = haloR - r * 0.93
            ..shader = ui.Gradient.radial(
              Offset.zero,
              haloR,
              [
                palette.halo.withValues(alpha: 0.3),
                palette.halo.withValues(alpha: 0.22),
                palette.halo.withValues(alpha: 0),
              ],
              [0.0, 1 / AstrolabeRadii.halo, 1.0],
            ));
    haloCenter = palette.light ? Offset(0, r * 0.03) : Offset.zero;
    haloRing = (haloR + r * 0.93) / 2;
    // Rim bevel: bright where it faces the light (drawn rotated to the light).
    bevelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..shader = ui.Gradient.sweep(
        Offset.zero,
        [
          palette.brassHi.withValues(alpha: 0.95),
          palette.brassHi.withValues(alpha: 0.0),
          palette.ink.withValues(alpha: 0.55),
          palette.brassHi.withValues(alpha: 0.0),
          palette.brassHi.withValues(alpha: 0.95),
        ],
        const [0.0, 0.3, 0.5, 0.7, 1.0],
      );
    hubShadowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        hubOuter + r * 0.05,
        [
          palette.shadow.withValues(alpha: 0.6),
          palette.shadow.withValues(alpha: 0.45),
          palette.shadow.withValues(alpha: 0),
        ],
        [0.0, hubOuter / (hubOuter + r * 0.05), 1.0],
      );
    hubWindowPaint = Paint()
      ..shader = ui.Gradient.radial(Offset.zero, hubInner, [palette.enamelMid, palette.enamelEdge]);
    final sunR = r * AstrolabeRadii.sun;
    sunRays = AstrolabePaths.sunRays(sunR);
    sunGlowPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        Offset.zero,
        sunR * 3.6,
        [
          palette.sunGlow.withValues(alpha: 0.55),
          palette.sunGlow.withValues(alpha: 0.16),
          palette.sunGlow.withValues(alpha: 0),
        ],
        const [0.0, 0.35, 1.0],
      );
    sunDiscPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(-sunR * 0.3, -sunR * 0.35),
        sunR * 1.1,
        [palette.fireInner, palette.sun, palette.brassLow],
        const [0.0, 0.6, 1.0],
      );
    sunRayPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        sunR * 2.1,
        [palette.fireInner, palette.sun, palette.brass],
        const [0.0, 0.55, 1.0],
      );
    headGlowPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        Offset.zero,
        r * 0.085,
        [
          palette.litHead.withValues(alpha: 0.95),
          palette.litArc.withValues(alpha: 0.32),
          palette.litArc.withValues(alpha: 0),
        ],
        const [0.0, 0.28, 1.0],
      );
    pointerGlowPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        Offset.zero,
        r * 0.1,
        [
          palette.litHead.withValues(alpha: 0.7),
          palette.litArc.withValues(alpha: 0.22),
          palette.litArc.withValues(alpha: 0),
        ],
        const [0.0, 0.35, 1.0],
      );
    starJewelPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1,
        [palette.litHead, palette.litHead.withValues(alpha: 0.35), palette.litHead.withValues(alpha: 0)],
        const [0.0, 0.3, 1.0],
      );
    starLightPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        Offset.zero,
        r * 0.66,
        [
          palette.starCorona.withValues(alpha: 0.2),
          palette.starCorona.withValues(alpha: 0.07),
          palette.starCorona.withValues(alpha: 0),
        ],
        const [0.0, 0.45, 1.0],
      );
    // Warm light on the hub's inner rim: strongest on the far side from the
    // viewer's light, where the star alone lights the metal.
    hubRimLightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        Offset.zero,
        hubInner + r * 0.012,
        [
          palette.starCore.withValues(alpha: 0),
          palette.starCore.withValues(alpha: 0),
          palette.litHead.withValues(alpha: 0.85),
          palette.starCore.withValues(alpha: 0),
        ],
        [0.0, (hubInner - r * 0.004) / (hubInner + r * 0.012), (hubInner + r * 0.004) / (hubInner + r * 0.012), 1.0],
      );
    windowFanPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        Offset.zero,
        r * AstrolabeRadii.channelInner,
        [
          palette.litArc.withValues(alpha: 0),
          palette.litArc.withValues(alpha: 0.05),
          palette.litArc.withValues(alpha: 0.14),
          palette.litArc.withValues(alpha: 0.26),
        ],
        [windowFanInner / AstrolabeRadii.channelInner, 0.75, 0.93, 1.0],
      );
    fallbackBrassPaint = Paint()
      ..shader = ui.Gradient.sweep(
        Offset.zero,
        [palette.brassHi, palette.brass, palette.brassLow, palette.brass, palette.brassHi],
        const [0.0, 0.25, 0.5, 0.75, 1.0],
        TileMode.clamp,
        -math.pi * 0.75,
        math.pi * 1.25,
      );
    fallbackStarPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        r * AstrolabeRadii.coreStar * 3,
        [
          palette.fireInner,
          palette.starCore,
          palette.starCorona.withValues(alpha: 0.35),
          palette.starCorona.withValues(alpha: 0),
        ],
        const [0.0, 0.3, 0.45, 1.0],
      );
    fallbackFirePaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1,
        [palette.fireInner, palette.fireOuter.withValues(alpha: 0.6), palette.fireOuter.withValues(alpha: 0)],
        const [0.0, 0.4, 1.0],
      );

    final rete = AstrolabePaths.rete();
    final scale = Matrix4.diagonal3Values(r, r, 1).storage;
    reteRings = rete.rings.transform(scale);
    reteEcliptic = Path()..addOval(Rect.fromCircle(center: rete.eclipticCenter * r, radius: rete.eclipticRadius * r));
    reteStraps = rete.straps.transform(scale);
    reteOvers = rete.overs.transform(scale);
    reteOverEdges = rete.overEdges.transform(scale);
    reteLines = rete.strapLines.transform(scale);
    reteOverLines = rete.overLines.transform(scale);
    reteFlames = rete.flames.transform(scale);
    reteBosses = rete.bosses.transform(scale);
    reteStarTips = [for (final s in rete.stars) s.tip * r];

    limbInk = _recordLimb(palette, labels);
    plateInk = _recordPlate(palette);
    reteInk = _recordRete(palette, labels, rete);
    _disposeReteLabels();
    if (lod >= AstrolabeLod.full) _buildReteLabels(palette, labels, rete);
    _dropBaked();
    // Everything keyed on the static layer is stale now.
    _prayerKey = null;
    _almuKey = null;
    _windowKey = null;
    arcStart = arcSweep = 0;
    _litShaderSweep = -1;
    _poolShaderSweep = -1;
    _bezelShaderSweep = -1;
    _countdownKey = null;
    _markKey = null;
    return true;
  }

  // -------------------------------------------------------------- limb engraving

  ui.Picture _recordLimb(AstrolabePalette palette, AstrolabeLabels labels) {
    final r = rb;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..color = palette.ink.withValues(alpha: 0.85)
      ..strokeCap = StrokeCap.round;
    final hi = Paint()
      ..style = PaintingStyle.stroke
      ..color = palette.engraveHi.withValues(alpha: 0.45)
      ..strokeCap = StrokeCap.round;
    final lit = Offset(px * 0.55, px * 0.7);

    void engrave(Path p, double width) {
      c
        ..save()
        ..translate(lit.dx, lit.dy)
        ..drawPath(p, hi..strokeWidth = width * 0.9)
        ..restore()
        ..drawPath(p, ink..strokeWidth = width);
    }

    Path circle(double f) => Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r * f));

    // Outer edge definition + rails.
    c.drawPath(circle(0.998), ink..strokeWidth = px * 1.1);
    final rails = Path()
      ..addPath(circle(AstrolabeRadii.scaleOuter), Offset.zero)
      ..addPath(circle(AstrolabeRadii.scaleInner), Offset.zero);
    if (lod >= AstrolabeLod.medium) rails.addPath(circle(AstrolabeRadii.numeralsInner), Offset.zero);
    engrave(rails, px * 0.9);

    // Beads (bead-and-reel border).
    if (lod >= AstrolabeLod.full) {
      final n = lod >= AstrolabeLod.ultra ? 192 : 144;
      final beadR = r * (AstrolabeRadii.beadOuter + AstrolabeRadii.beadInner) / 2;
      final size = r * (AstrolabeRadii.beadOuter - AstrolabeRadii.beadInner) * 0.36;
      final beads = Path();
      final shine = Path();
      for (var i = 0; i < n; i++) {
        final a = i / n * AstrolabeGeometry.tau;
        final p = Offset(math.cos(a), math.sin(a)) * beadR;
        beads.addOval(Rect.fromCircle(center: p, radius: size));
        shine.addOval(Rect.fromCircle(center: p + Offset(-size * 0.3, -size * 0.35), radius: size * 0.42));
      }
      c
        ..drawPath(beads.shift(Offset(px * 0.4, px * 0.6)), Paint()..color = palette.ink.withValues(alpha: 0.55))
        ..drawPath(beads, Paint()..color = palette.brass.withValues(alpha: 0.35))
        ..drawPath(shine, Paint()..color = palette.brassHi.withValues(alpha: 0.55));
      engrave(circle(AstrolabeRadii.beadInner), px * 0.8);
    }

    // 96 ticks: hours cross the band, halves 62 %, quarters 38 %.
    final hour = Path(), half = Path(), quarter = Path();
    final tickCount = lod >= AstrolabeLod.medium ? 96 : 24;
    final step = 96 ~/ tickCount;
    for (var i = 0; i < 96; i += step) {
      final a = AstrolabeGeometry.angleForFraction(i / 96);
      final d = Offset(math.cos(a), math.sin(a));
      final outer = r * AstrolabeRadii.scaleOuter;
      final band = r * (AstrolabeRadii.scaleOuter - AstrolabeRadii.scaleInner);
      final (Path path, double len) = i % 4 == 0 ? (hour, 1.0) : (i % 2 == 0 ? (half, 0.62) : (quarter, 0.38));
      path
        ..moveTo(d.dx * outer, d.dy * outer)
        ..lineTo(d.dx * (outer - band * len), d.dy * (outer - band * len));
    }
    engrave(hour, px * 1.5);
    engrave(half, px * 1.05);
    engrave(quarter, px * 0.8);

    // Minute dots between the ticks on large dials.
    if (lod >= AstrolabeLod.ultra) {
      final dots = Path();
      final rr = r * (AstrolabeRadii.scaleOuter - 0.006);
      for (var i = 0; i < 288; i++) {
        if (i % 3 == 0) continue;
        final a = AstrolabeGeometry.angleForFraction(i / 288);
        dots.addOval(Rect.fromCircle(center: Offset(math.cos(a), math.sin(a)) * rr, radius: px * 0.55));
      }
      c.drawPath(dots, Paint()..color = palette.ink.withValues(alpha: 0.6));
    }

    // Numerals (kept upright), noon at the top, 24 at the bottom; the
    // home-size dial carries only the four cardinal hours, larger.
    if (lod >= AstrolabeLod.medium) {
      final font = r * (lod >= AstrolabeLod.full ? 0.05 : 0.074);
      final every = lod >= AstrolabeLod.full ? 1 : 6;
      final rr = r * AstrolabeRadii.numerals;
      for (var h = every; h <= 24; h += every) {
        final a = AstrolabeGeometry.angleForFraction(h / 24);
        final text = labels.numeral(h);
        final tpInk = _text(text, font, palette.ink.withValues(alpha: 0.92), weight: FontWeight.w700, labels: labels);
        final tpHi = _text(
          text,
          font,
          palette.engraveHi.withValues(alpha: 0.5),
          weight: FontWeight.w700,
          labels: labels,
        );
        final rot = AstrolabeGeometry.uprightRotation(a);
        c
          ..save()
          ..translate(math.cos(a) * rr, math.sin(a) * rr)
          ..rotate(rot);
        final o = Offset(-tpInk.width / 2, -tpInk.height / 2);
        // keep the engraving's lit edge toward the bottom-right of the screen
        tpHi.paint(c, o + _rotate(lit, -rot));
        tpInk.paint(c, o);
        c.restore();
        tpInk.dispose();
        tpHi.dispose();
      }
      // Tiny diamonds at the half hours between numerals.
      if (lod >= AstrolabeLod.full) {
        final gems = Path();
        final s = r * 0.0065;
        for (var h = 0; h < 24; h++) {
          final a = AstrolabeGeometry.angleForFraction((h + 0.5) / 24);
          final p = Offset(math.cos(a), math.sin(a)) * rr;
          final d = Offset(math.cos(a), math.sin(a));
          final t = Offset(-d.dy, d.dx);
          gems
            ..moveTo(p.dx + d.dx * s * 1.6, p.dy + d.dy * s * 1.6)
            ..lineTo(p.dx + t.dx * s, p.dy + t.dy * s)
            ..lineTo(p.dx - d.dx * s * 1.6, p.dy - d.dy * s * 1.6)
            ..lineTo(p.dx - t.dx * s, p.dy - t.dy * s)
            ..close();
        }
        c
          ..drawPath(gems.shift(lit), Paint()..color = palette.engraveHi.withValues(alpha: 0.4))
          ..drawPath(gems, Paint()..color = palette.ink.withValues(alpha: 0.7));
      }
    }

    // Inner edge of the limb: a sharp dark step down to the plate.
    c.drawPath(circle(AstrolabeRadii.limbInner + 0.002), ink..strokeWidth = px * 1.2);
    return rec.endRecording();
  }

  // -------------------------------------------------------------- plate engraving

  ui.Picture _recordPlate(AstrolabePalette palette) {
    final r = rb;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final plateR = r * AstrolabeRadii.limbInner;
    c.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: plateR)));

    // Girih star lattice, strongest toward the rim, fading into the centre.
    if (lod >= AstrolabeLod.medium) {
      final spacing = lod >= AstrolabeLod.full ? 0.15 : 0.22;
      final girih = AstrolabePaths.girih(scale: r, radius: AstrolabeRadii.limbInner, spacing: spacing);
      final shader = ui.Gradient.radial(
        Offset.zero,
        plateR,
        [
          palette.plateLine.withValues(alpha: 0),
          palette.plateLine.withValues(alpha: 0.05),
          palette.plateLine.withValues(alpha: 0.12),
          palette.plateLine.withValues(alpha: 0.18),
        ],
        const [0.0, 0.4, 0.75, 1.0],
      );
      final shadowShader = ui.Gradient.radial(
        Offset.zero,
        plateR,
        [palette.shadow.withValues(alpha: 0), palette.shadow.withValues(alpha: 0.35)],
        const [0.3, 1.0],
      );
      c
        ..drawPath(
          girih.shift(Offset(px * 0.5, px * 0.6)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = px * 0.9
            ..shader = shadowShader,
        )
        ..drawPath(
          girih,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = px * 0.7
            ..shader = shader,
        );
    }

    // Lapis lazuli: pyrite flecks glinting in the deep blue enamel.
    if (lod >= AstrolabeLod.full) {
      final rnd = math.Random(0x1A915);
      final specks = Path();
      final bright = Path();
      final n = lod >= AstrolabeLod.ultra ? 900 : 520;
      for (var i = 0; i < n; i++) {
        final rr = plateR * math.sqrt(rnd.nextDouble());
        final a = rnd.nextDouble() * AstrolabeGeometry.tau;
        final p = Offset(math.cos(a), math.sin(a)) * rr;
        final size = px * (0.25 + 0.65 * math.pow(rnd.nextDouble(), 3));
        (rnd.nextDouble() < 0.12 ? bright : specks).addOval(Rect.fromCircle(center: p, radius: size));
      }
      c
        ..drawPath(specks, Paint()..color = palette.plateLine.withValues(alpha: 0.22))
        ..drawPath(bright, Paint()..color = palette.engraveHi.withValues(alpha: 0.55));
    }

    // The channel: a double gold rail the prayer pointers and the lit arc run in.
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = px * 0.8
      ..color = palette.plateLine.withValues(alpha: 0.5);
    final dark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = px * 1.2
      ..color = palette.shadow.withValues(alpha: 0.5);
    for (final f in const [AstrolabeRadii.channelOuter, AstrolabeRadii.channelInner]) {
      final rect = Rect.fromCircle(center: Offset.zero, radius: r * f);
      c
        ..drawOval(rect.shift(Offset(px * 0.4, px * 0.6)), dark)
        ..drawOval(rect, gold);
    }
    // Hour marks along the channel.
    if (lod >= AstrolabeLod.medium) {
      final marks = Path();
      for (var h = 0; h < 24; h++) {
        final a = AstrolabeGeometry.angleForFraction(h / 24);
        final d = Offset(math.cos(a), math.sin(a));
        marks
          ..moveTo(d.dx * r * AstrolabeRadii.channelOuter, d.dy * r * AstrolabeRadii.channelOuter)
          ..lineTo(d.dx * r * (AstrolabeRadii.channelOuter - 0.012), d.dy * r * (AstrolabeRadii.channelOuter - 0.012));
      }
      c.drawPath(
        marks,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = px * 0.8
          ..color = palette.plateLine.withValues(alpha: 0.42),
      );
    }
    return rec.endRecording();
  }

  /// Horizon, twilight line and almucantars for [latitude] (drawn rotated by
  /// the plate rotation). Rebuilt only when the latitude changes.
  ui.Picture ensureAlmucantars(AstrolabePalette palette, double latitude) {
    final key = (_staticKey, latitude.toStringAsFixed(2));
    final existing = almucantars;
    if (key == _almuKey && existing != null) return existing;
    _almuKey = key;
    existing?.dispose();
    final r = rb;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final cap = r * AstrolabeRadii.capricorn;
    c.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: cap)));

    Rect circleOf(double alt) {
      final a = AstrolabeProjection.almucantar(alt, latitude);
      return Rect.fromCircle(center: a.center * r, radius: a.radius * r);
    }

    final horizon = circleOf(0);
    horizonCenter = horizon.center;
    horizonRadius = horizon.width / 2;
    final twilight = circleOf(-18);
    // Sky above the horizon, and the twilight band down to −18°.
    c
      ..drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(twilight)
          ..addOval(horizon),
        Paint()
          ..shader = ui.Gradient.radial(
            twilight.center,
            twilight.width / 2,
            [palette.twilight.withValues(alpha: 0.0), palette.twilight.withValues(alpha: 0.13)],
            const [0.82, 1.0],
          ),
      )
      ..drawOval(
        horizon,
        Paint()
          ..shader = ui.Gradient.radial(Offset(0, -cap * 0.6), cap * 1.3, [
            palette.daySky.withValues(alpha: 0.2),
            palette.daySky.withValues(alpha: 0.07),
          ]),
      );

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = palette.plateLine.withValues(alpha: 0.22)
      ..strokeWidth = px * 0.6;
    if (lod >= AstrolabeLod.medium) {
      final step = lod >= AstrolabeLod.full ? 10 : 30;
      for (var alt = step; alt < 90; alt += step) {
        c.drawOval(circleOf(alt.toDouble()), line);
      }
      // meridian through the zenith
      final z = AstrolabeProjection.zenith(latitude) * r;
      c.drawLine(Offset(0, -cap), Offset(0, cap * 0.2), line);
      final s = r * 0.012;
      final star = Path()
        ..moveTo(z.dx, z.dy - s * 1.8)
        ..lineTo(z.dx + s * 0.35, z.dy - s * 0.35)
        ..lineTo(z.dx + s * 1.8, z.dy)
        ..lineTo(z.dx + s * 0.35, z.dy + s * 0.35)
        ..lineTo(z.dx, z.dy + s * 1.8)
        ..lineTo(z.dx - s * 0.35, z.dy + s * 0.35)
        ..lineTo(z.dx - s * 1.8, z.dy)
        ..lineTo(z.dx - s * 0.35, z.dy - s * 0.35)
        ..close();
      c.drawPath(star, Paint()..color = palette.plateLine.withValues(alpha: 0.55));
    }
    // Twilight line (Fajr / Isha, sun 18° below the horizon): dashed.
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..color = palette.twilight.withValues(alpha: 0.55)
      ..strokeWidth = px * 0.9;
    final twilightPath = Path()..addOval(twilight);
    for (final m in twilightPath.computeMetrics()) {
      final seg = r * 0.022;
      for (var d = 0.0; d < m.length; d += seg * 1.9) {
        c.drawPath(m.extractPath(d, d + seg), dash);
      }
    }
    // Horizon: the brightest line on the plate.
    c
      ..drawOval(
        horizon.shift(Offset(px * 0.4, px * 0.6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = px * 1.4
          ..color = palette.shadow.withValues(alpha: 0.5),
      )
      ..drawOval(
        horizon,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = px * 1.1
          ..color = palette.plateLine.withValues(alpha: 0.62),
      );
    return almucantars = rec.endRecording();
  }

  // -------------------------------------------------------------- rete engraving

  ui.Picture _recordRete(AstrolabePalette palette, AstrolabeLabels labels, ReteModel rete) {
    final r = rb;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..color = palette.ink.withValues(alpha: 0.75)
      ..strokeWidth = px * 0.8;

    // Ecliptic ring: engraved rails and zodiac graduations.
    final ec = rete.eclipticCenter * r;
    final er = rete.eclipticRadius * r;
    final ew = ReteModel.eclipticWidth * r;
    c
      ..drawCircle(ec, er + ew * 0.5 - px * 0.9, ink)
      ..drawCircle(ec, er - ew * 0.5 + px * 0.9, ink);
    if (lod >= AstrolabeLod.medium) {
      final ticks = Path();
      final every = lod >= AstrolabeLod.ultra ? 2 : (lod >= AstrolabeLod.full ? 5 : 30);
      for (var l = 0; l < 360; l += every) {
        final p = AstrolabeProjection.eclipticPoint(l.toDouble()) * r;
        final d = p - ec;
        final u = d / d.distance;
        final len = l % 30 == 0 ? 1.0 : (l % 10 == 0 ? 0.42 : (l % 5 == 0 ? 0.3 : 0.2));
        final outer = ec + u * (er + ew * 0.5 - px);
        ticks
          ..moveTo(outer.dx, outer.dy)
          ..lineTo(outer.dx - u.dx * (ew - 2 * px) * len, outer.dy - u.dy * (ew - 2 * px) * len);
      }
      c.drawPath(ticks, ink..strokeWidth = px * 0.75);
      // the inner rail of the graduated band
      if (lod >= AstrolabeLod.full) {
        c.drawCircle(ec, er + ew * 0.5 - (ew - 2 * px) * 0.44, ink..strokeWidth = px * 0.6);
      }
    }
    // Capricorn ring rail.
    c.drawCircle(Offset.zero, r * AstrolabeRadii.capricorn, ink..strokeWidth = px * 0.7);

    // Engraved mid-ribs of the flames, and the rivet eyes on their bosses.
    if (lod >= AstrolabeLod.medium) {
      c.drawPath(
        rete.ribs.transform(Matrix4.diagonal3Values(r, r, 1).storage),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = px * 0.7
          ..color = palette.ink.withValues(alpha: 0.55),
      );
    }
    final eyes = Path();
    for (final s in rete.stars) {
      eyes.addOval(Rect.fromCircle(center: s.base * r, radius: r * ReteModel.bossRadius * 0.42));
    }
    c.drawPath(eyes, Paint()..color = palette.ink.withValues(alpha: 0.8));

    return rec.endRecording();
  }

  void _buildReteLabels(AstrolabePalette palette, AstrolabeLabels labels, ReteModel rete) {
    final r = rb;
    // Zodiac signs in the inner part of the ecliptic band (largest dials).
    final ec = rete.eclipticCenter * r;
    final er = rete.eclipticRadius * r;
    final ew = ReteModel.eclipticWidth * r;
    final zFont = ew * 0.36;
    final bandMid = er + ew * 0.5 - (ew - 2 * px) * 0.44 - (ew * 0.56 - px) / 2;
    for (var k = 0; k < (lod >= AstrolabeLod.ultra ? 12 : 0); k++) {
      final p = AstrolabeProjection.eclipticPoint(k * 30.0 + 15) * r;
      final u = (p - ec) / (p - ec).distance;
      final name = labels.zodiacName(k);
      reteLabels.add(
        ReteLabel(
          center: ec + u * bandMid,
          angle: math.atan2(u.dy, u.dx) + math.pi / 2,
          ink: _text(name, zFont, palette.ink.withValues(alpha: 0.85), weight: FontWeight.w700, labels: labels),
          shade: _text(name, zFont, palette.engraveHi.withValues(alpha: 0.4), weight: FontWeight.w700, labels: labels),
          shadeOffset: Offset(px * 0.45, px * 0.6),
        ),
      );
    }
    // Tiny Kufic star names beside their pointers, skipping any that would
    // collide with a name already placed.
    final font = math.max(6.0, r * 0.024);
    final placed = <(Offset, Offset, double)>[];
    for (final s in rete.stars) {
      final name = labels.starName(s.id);
      final tp = _text(
        name,
        font,
        palette.plateLine.withValues(alpha: 0.92),
        weight: FontWeight.w500,
        labels: labels,
        display: true,
      );
      final dir = s.tip - s.base;
      final a = math.atan2(dir.dy, dir.dx);
      final along = Offset(math.cos(a), math.sin(a));
      final normal = Offset(-along.dy, along.dx);
      // on the side the flame does not curl toward
      final mid = (s.base * 0.5 + s.tip * 0.5) * r - normal * (s.bend * (font * 1.05 + r * ReteModel.flameWidth * 0.4));
      final half = along * (tp.width / 2);
      final seg = (mid - half, mid + half, font * 1.1);
      final collides =
          placed.any((p) => _segmentDistance(p.$1, p.$2, seg.$1, seg.$2) < (p.$3 + seg.$3) / 2) ||
          mid.distance - tp.width / 2 < hubOuter + font ||
          mid.distance + tp.width / 2 > r * AstrolabeRadii.capricorn;
      if (collides) {
        tp.dispose();
        continue;
      }
      placed.add(seg);
      reteLabels.add(
        ReteLabel(
          center: mid,
          angle: a,
          ink: tp,
          shade: _text(
            name,
            font,
            palette.enamelEdge.withValues(alpha: 0.9),
            weight: FontWeight.w500,
            labels: labels,
            outline: font * 0.22,
            display: true,
          ),
          shadeOffset: Offset.zero,
          shadeBelow: true,
        ),
      );
    }
  }

  void _disposeReteLabels() {
    for (final l in reteLabels) {
      l.ink.dispose();
      l.shade.dispose();
    }
    reteLabels.clear();
  }

  static double _segmentDistance(Offset a, Offset b, Offset c, Offset d) {
    double pointSeg(Offset p, Offset s0, Offset s1) {
      final v = s1 - s0;
      final l2 = v.dx * v.dx + v.dy * v.dy;
      final t = l2 == 0 ? 0.0 : (((p - s0).dx * v.dx + (p - s0).dy * v.dy) / l2).clamp(0.0, 1.0);
      return (p - (s0 + v * t)).distance;
    }

    return math.min(math.min(pointSeg(a, c, d), pointSeg(b, c, d)), math.min(pointSeg(c, a, b), pointSeg(d, a, b)));
  }

  // -------------------------------------------------------------- prayers

  /// Pointer paths and the names (a picture) for the current prayer times,
  /// statuses and language.
  void ensurePrayers({required AstrolabeState state, required AstrolabePalette palette}) {
    // Same state object, same static layer: nothing can have changed (the
    // painter calls this every frame – no work, no allocation).
    if (identical(state, _prayerState) && identical(_staticKey, _prayerStatic)) return;
    _prayerState = state;
    _prayerStatic = _staticKey;
    final r = rb;
    var statusKey = 0, minutesKey = 0;
    for (final p in AstrolabeGeometry.prayers) {
      statusKey = statusKey * 4 + state.statusOf(p).index;
      minutesKey = minutesKey * 1441 + (state.fractionOf(p) * 1440).round();
    }
    final key = (_staticKey, statusKey, minutesKey, state.labels, state.window.nextPrayer);
    if (key == _prayerKey) return;
    _prayerKey = key;
    labels?.dispose();
    labels = null;
    pointerPaths.clear();
    pointerCenters.clear();
    pointerTips.clear();
    pointerAngles.clear();
    statuses.clear();
    final fractions = state.fractions;
    for (var i = 0; i < AstrolabeGeometry.prayers.length; i++) {
      final p = AstrolabeGeometry.prayers[i];
      final f = fractions[p]!;
      final center = AstrolabeGeometry.pointerCenter(Offset.zero, r, f);
      final a = AstrolabeGeometry.angleForFraction(f);
      statuses[p] = state.statusOf(p);
      pointerCenters[p] = center;
      pointerTips[p] = AstrolabeGeometry.pointerTip(Offset.zero, r, f);
      pointerAngles[p] = a;
      pointerPaths[p] = AstrolabePaths.pointerStar(
        center: center,
        radius: pointerRadius,
        angle: a,
        tipLength: r * (AstrolabeRadii.limbInner - AstrolabeRadii.channel),
      );
    }
    labelCenterList.clear();
    labelExtent = 0;
    if (lod < AstrolabeLod.medium) {
      labelAngles = const {};
      labelCenters.clear();
      return;
    }
    // The names are engraved into the plate beside their star-points (Reem
    // Kufi, gold inlay in a dark cavity with a lit lower lip – no boxes). On
    // the home-size dial only the due (or next) prayer is named; from the
    // full level of detail every prayer is, with its time engraved under it.
    final full = lod >= AstrolabeLod.full;
    final font = full ? math.max(8.5, r * 0.052) : math.max(10.0, r * 0.11);
    final timeFont = math.max(7.0, font * 0.7);
    final due = AstrolabeGeometry.prayers.where((p) => statuses[p] == AstrolabePrayerStatus.due).firstOrNull;
    final named = full ? AstrolabeGeometry.prayers : [due ?? state.window.nextPrayer];
    final pad = font * 0.18;
    final painters = <Prayer, _Engraving>{};
    var maxW = 0.0;
    var maxH = 0.0;
    for (final p in AstrolabeGeometry.prayers) {
      if (!named.contains(p)) continue;
      final inlay = switch (statuses[p]!) {
        AstrolabePrayerStatus.prayed => palette.labelPrayed,
        AstrolabePrayerStatus.due => palette.labelDue,
        AstrolabePrayerStatus.upcoming => palette.labelUpcoming,
        AstrolabePrayerStatus.missed => palette.labelMissed,
      };
      final e = _Engraving.of(
        state.labels.prayerName(p),
        full ? state.labels.time(state.timeOf(p)) : null,
        font: font,
        timeFont: timeFont,
        inlay: inlay,
        palette: palette,
        labels: state.labels,
      );
      painters[p] = e;
      maxW = math.max(maxW, e.width + 2 * pad);
      maxH = math.max(maxH, e.height + 2 * pad);
    }
    final radius = r * (AstrolabeRadii.labelsOuter - 0.08);
    labelAngles = full
        ? AstrolabeGeometry.labelAngles(
            fractions,
            gapFor: (a) {
              final s = math.sin(a).abs(), co = math.cos(a).abs();
              final need = math.min(
                s < 1e-3 ? double.infinity : (maxW + font * 0.5) / s,
                co < 1e-3 ? double.infinity : (maxH + font * 0.35) / co,
              );
              return need / radius;
            },
          )
        : {for (final p in named) p: AstrolabeGeometry.angleForFraction(fractions[p]!)};
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    labelCenters.clear();
    final lit = Offset(px * 0.45, px * 0.6);
    for (final p in AstrolabeGeometry.prayers) {
      final e = painters[p];
      final a = labelAngles[p];
      if (e == null || a == null) continue;
      final dir = Offset(math.cos(a), math.sin(a));
      final boxW = e.width + 2 * pad, boxH = e.height + 2 * pad;
      // Just inside the channel, whatever its size; a long name lying along
      // the radius (Maghrib at 3 o'clock) is engraved a little smaller
      // rather than touch the hub.
      final along = boxW / 2 * dir.dx.abs() + boxH / 2 * dir.dy.abs();
      final room = r * AstrolabeRadii.labelsOuter - (hubOuter + font * 0.45);
      final k = 2 * along > room ? math.max(0.72, room / (2 * along)) : 1.0;
      final extent = along * k;
      final center = dir * (r * AstrolabeRadii.labelsOuter - extent);
      labelCenters[p] = center;
      labelCenterList.add(center);
      labelExtent = math.max(labelExtent, math.max(boxW, boxH) / 2 * k);
      c
        ..save()
        ..translate(center.dx, center.dy)
        ..scale(k);
      e.paint(c, lit: lit, cavity: px * 0.9);
      c.restore();
      e.dispose();
    }
    for (final e in painters.values) {
      e.dispose();
    }
    labels = rec.endRecording();
  }

  // -------------------------------------------------------------- lit arc

  /// The current window's arc on the dial (rebuilt when the window or the
  /// elapsed part changes).
  void ensureWindow(AstrolabeState state) {
    final w = state.window;
    final key = (w.start, w.end, state.now);
    if (key == _windowKey) return;
    _windowKey = key;
    final arc = AstrolabeGeometry.arc(w.start, w.end);
    arcDone = arc.sweep * AstrolabeGeometry.arcProgress(w.start, w.end, state.now);
    if (arc.start == arcStart && arc.sweep == arcSweep) return;
    arcStart = arc.start;
    arcSweep = arc.sweep;
    // The window's sector of the plate (inside the channel), lit from the
    // rim inward: the current window reads at a glance on a small dial.
    final r = rb;
    final outer = Rect.fromCircle(center: Offset.zero, radius: r * AstrolabeRadii.channelInner);
    final inner = Rect.fromCircle(center: Offset.zero, radius: r * windowFanInner);
    windowFan = Path()
      ..arcTo(outer, arc.start, arc.sweep, true)
      ..arcTo(inner, arc.start + arc.sweep, -arc.sweep, false)
      ..close();
  }

  /// Inner edge of the lit window's sector (× R).
  static const double windowFanInner = 0.46;

  /// The current window's sector (see [ensureWindow]); empty before.
  Path windowFan = Path();

  /// Angular lead-in (radians) before the elapsed arc, so its round start
  /// cap falls where [litShader] is still transparent.
  static const litLead = 0.05;

  /// Sweep gradient for the elapsed part of the lit arc, in a frame rotated
  /// so the window starts at angle [litLead]: transparent at the window's
  /// start, hottest at "now" and beyond it (the round head cap). Rebuilt
  /// when [arcDone] moves.
  ui.Shader litShader(AstrolabePalette palette) {
    final existing = _litShader;
    if (existing != null && (arcDone - _litShaderSweep).abs() < 1e-3) return existing;
    existing?.dispose();
    _litShaderSweep = arcDone;
    final done = math.max(arcDone, 1e-3);
    final total = done + 2 * litLead;
    double at(double a) => a / total;
    return _litShader = ui.Gradient.sweep(
      Offset.zero,
      [
        palette.litArc.withValues(alpha: 0),
        palette.litArc.withValues(alpha: 0),
        palette.litArc.withValues(alpha: 0.35),
        palette.litArc.withValues(alpha: 0.75),
        palette.litHead,
        palette.litHead,
      ],
      [0.0, at(litLead), at(litLead + math.min(0.035, done * 0.4)), at(litLead + done * 0.62), at(litLead + done), 1.0],
      TileMode.clamp,
      0,
      total,
    );
  }

  /// Sweep gradient for the whole window (fading in and out at its ends),
  /// in the same rotated frame as [litShader].
  ui.Shader poolShader(AstrolabePalette palette) {
    final existing = _poolShader;
    if (existing != null && (arcSweep - _poolShaderSweep).abs() < 1e-4) return existing;
    existing?.dispose();
    _poolShaderSweep = arcSweep;
    return _poolShader = _windowSweep(palette.litArc);
  }

  ui.Shader? _bezelShader;
  double _bezelShaderSweep = -1;

  /// Like [poolShader] in the lit head's hotter colour: the window's stretch
  /// of the hour scale glows (the limb sector reads as lit at a glance).
  ui.Shader bezelShader(AstrolabePalette palette) {
    final existing = _bezelShader;
    if (existing != null && (arcSweep - _bezelShaderSweep).abs() < 1e-4) return existing;
    existing?.dispose();
    _bezelShaderSweep = arcSweep;
    return _bezelShader = _windowSweep(palette.litHead);
  }

  ui.Shader _windowSweep(Color color) {
    final end = math.max(arcSweep, 1e-3);
    final e = math.min(0.25, 0.05 / end);
    return ui.Gradient.sweep(
      Offset.zero,
      [color.withValues(alpha: 0), color, color, color.withValues(alpha: 0)],
      [0.0, e, 1 - e, 1.0],
      TileMode.clamp,
      0,
      end,
    );
  }

  // -------------------------------------------------------------- hub text

  /// The widest arc (radians) text may take on the hub ring: 150°, centred
  /// on 12 (or 6) o'clock, so it never wraps round the star.
  static const double maxRingSweep = 150 * math.pi / 180;

  /// Oversampling of the ring-text images. Fixed per size bucket (the canvas
  /// scale does the rest), so a pinch or a fly-in never re-renders them.
  static double ringTextScale(double devicePixelRatio) => (devicePixelRatio * bucketStep * 1.35).clamp(1.0, 7.0);

  /// The countdown (top of the hub ring) as a white-on-transparent image
  /// [countdownScale]× the size it is shown at, engraved at [font] (defaults
  /// to [hubFont]); re-rendered only when the text or the font changes.
  ui.Image ensureCountdown(String text, AstrolabeLabels labels, double scale, {double? font}) {
    final f = font ?? hubFont;
    final key = (text, f, scale, labels.arabic);
    final existing = countdownImage;
    if (key == _countdownKey && existing != null) return existing;
    _countdownKey = key;
    _countdownRenders++;
    existing?.dispose();
    countdownScale = scale;
    return countdownImage = _ringTextImage(text, f, scale, labels, flip: false, band: hubBand);
  }

  /// Text for the lower half of the hub (the maker's mark on large dials,
  /// the countdown's prayer on small ones), drawn upside down in the image
  /// so it reads upright along the bottom of the ring.
  ui.Image ensureMark(String text, AstrolabeLabels labels, double scale, {double? font}) {
    final f = font ?? hubFont * 0.9;
    final key = (text, f, scale, labels.arabic);
    final existing = markImage;
    if (key == _markKey && existing != null) return existing;
    _markKey = key;
    existing?.dispose();
    markScale = scale;
    return markImage = _ringTextImage(text, f, scale, labels, flip: true, band: hubBand);
  }

  final Map<(String, double, bool), double> _widths = {};

  /// Width (px at [rb], padding included) of [text] engraved on the hub ring
  /// at [font] – the same box [ensureCountdown] renders (cached per text).
  double ringTextWidth(String text, double font, AstrolabeLabels labels) {
    final key = (text, font, labels.arabic);
    final hit = _widths[key];
    if (hit != null) return hit;
    if (_widths.length > 24) _widths.clear();
    final tp = TextPainter(
      text: TextSpan(text: text, style: _ringStyle(font, labels)),
      textDirection: labels.textDirection,
    )..layout();
    final w = tp.width + 2 * font * 0.35;
    tp.dispose();
    return _widths[key] = w;
  }

  /// The largest font ≤ [font] (in quarter-pixel steps, so a ticking clock
  /// never changes it) at which [text] fits [maxRingSweep] on a ring of
  /// radius [mid]; null when even [minScale] × [font] does not fit.
  double? fitRingFont(String text, double font, double mid, AstrolabeLabels labels, {double minScale = 0.72}) {
    final w = ringTextWidth(text, font, labels);
    final need = w / math.max(mid, 1);
    if (need <= maxRingSweep) return font;
    final scaled = font * maxRingSweep / need;
    if (scaled < font * minScale) return null;
    return (scaled * 4).floorToDouble() / 4;
  }

  static TextStyle _ringStyle(double size, AstrolabeLabels labels) => TextStyle(
    fontFamily: MadarTypography.uiFamily,
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: const Color(0xFFFFFFFF),
    height: 1.0,
    letterSpacing: labels.arabic ? 0 : size * 0.06,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  ui.Image _ringTextImage(
    String text,
    double font,
    double scale,
    AstrolabeLabels labels, {
    required bool flip,
    double? band,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: _ringStyle(font * scale, labels)),
      textDirection: labels.textDirection,
    )..layout();
    final h = ((band ?? font * 1.5) * scale).ceil();
    final pad = (font * scale * 0.35).ceil();
    final w = math.min(8192, tp.width.ceil() + pad * 2);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    if (flip) {
      c
        ..translate(w.toDouble(), h.toDouble())
        ..rotate(math.pi);
    }
    tp.paint(c, Offset(pad.toDouble(), (h - tp.height) / 2 + (labels.arabic ? font * scale * 0.04 : 0)));
    tp.dispose();
    final picture = rec.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    return image;
  }

  // -------------------------------------------------------------- baked layers

  /// The dial's two heavy vector layers, rasterised once and replayed as
  /// textures (Impeller re-tessellates vector pictures on every frame): the
  /// base (halo, plate, almucantars, limb with its engraving) and the rete
  /// (in its own frame; the painter turns it). Re-baked only when their key
  /// changes – the size bucket, the palette, the tarnish, the light
  /// direction (quantised), the plate's slow turn.
  ui.Image? baseImage, reteImage;
  Object? _baseKey, _reteKey;

  /// Half-size (px at [rb]) each baked image covers around the centre.
  double baseExtent = 0, reteExtent = 0;

  /// How often each layer was baked – for tests.
  int get baseBakes => _baseBakes;
  int get reteBakes => _reteBakes;
  int _baseBakes = 0, _reteBakes = 0;

  /// The base layer for [key], painted by [paint] (origin-centred, px at
  /// [rb]) at [scale] device pixels per px when stale.
  ui.Image bakeBase(Object key, {required double extent, required double scale, required void Function(Canvas) paint}) {
    final existing = baseImage;
    if (key == _baseKey && existing != null) return existing;
    _baseKey = key;
    _baseBakes++;
    existing?.dispose();
    baseExtent = extent;
    return baseImage = _bake(extent, scale, paint);
  }

  /// The rete layer (see [bakeBase]), in the rete's own frame.
  ui.Image bakeRete(Object key, {required double extent, required double scale, required void Function(Canvas) paint}) {
    final existing = reteImage;
    if (key == _reteKey && existing != null) return existing;
    _reteKey = key;
    _reteBakes++;
    existing?.dispose();
    reteExtent = extent;
    return reteImage = _bake(extent, scale, paint);
  }

  static ui.Image _bake(double extent, double scale, void Function(Canvas) paint) {
    final side = math.max(1, (2 * extent * scale).ceil());
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)
      ..scale(scale)
      ..translate(extent, extent);
    paint(c);
    final picture = rec.endRecording();
    final image = picture.toImageSync(side, side);
    picture.dispose();
    return image;
  }

  void _dropBaked() {
    baseImage?.dispose();
    reteImage?.dispose();
    baseImage = reteImage = null;
    _baseKey = _reteKey = null;
  }

  // -------------------------------------------------------------- helpers

  static TextPainter _text(
    String text,
    double size,
    Color color, {
    required FontWeight weight,
    required AstrolabeLabels labels,
    bool display = false,
    double outline = 0,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: display ? MadarTypography.displayFamily : MadarTypography.uiFamily,
          fontSize: size,
          fontWeight: weight,
          color: outline > 0 ? null : color,
          foreground: outline > 0
              ? (Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = outline
                  ..strokeJoin = StrokeJoin.round
                  ..color = color)
              : null,
          height: 1.15,
          letterSpacing: labels.arabic || !display ? 0 : size * 0.04,
        ),
      ),
      textDirection: labels.textDirection,
      textAlign: TextAlign.center,
    )..layout();
  }

  static Offset _rotate(Offset v, double a) {
    final c = math.cos(a), s = math.sin(a);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    limbInk?.dispose();
    plateInk?.dispose();
    reteInk?.dispose();
    almucantars?.dispose();
    labels?.dispose();
    _disposeReteLabels();
    countdownImage?.dispose();
    markImage?.dispose();
    _dropBaked();
    limbInk = plateInk = reteInk = almucantars = labels = null;
    countdownImage = markImage = null;
    _litShader?.dispose();
    _poolShader?.dispose();
    _bezelShader?.dispose();
    _litShader = null;
    _poolShader = null;
    _bezelShader = null;
  }
}

/// A name engraved on the rete, laid out once and drawn each frame at
/// [center] (rete-local px) along [angle], turned half a turn whenever it
/// would read upside down on screen.
class ReteLabel {
  ReteLabel({
    required this.center,
    required this.angle,
    required this.ink,
    required this.shade,
    required this.shadeOffset,
    this.shadeBelow = false,
  });

  final Offset center;
  final double angle;
  final TextPainter ink;

  /// Lit edge (engraving) or dark outline ([shadeBelow]).
  final TextPainter shade;
  final Offset shadeOffset;
  final bool shadeBelow;

  /// Paints the label in the rete's frame, the rete being turned by
  /// [reteRotation] on screen.
  void paint(Canvas canvas, double reteRotation) {
    final screen = angle + reteRotation;
    final flip = math.cos(screen) < 0;
    final rot = flip ? angle + math.pi : angle;
    final o = Offset(-ink.width / 2, -ink.height / 2);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(rot);
    if (shadeBelow) {
      shade.paint(canvas, o);
    } else {
      // keep the engraving's lit edge toward the bottom-right of the screen
      final a = -(rot + reteRotation);
      final c = math.cos(a), s = math.sin(a);
      shade.paint(canvas, o + Offset(shadeOffset.dx * c - shadeOffset.dy * s, shadeOffset.dx * s + shadeOffset.dy * c));
    }
    ink.paint(canvas, o);
    canvas.restore();
  }
}

/// A prayer's name (and its time) engraved into the plate: a soft dark
/// cavity behind it (legible over the rete's straps), a 1-px dark cavity
/// wall above, a lit lower lip, and the gold inlay on top.
final class _Engraving {
  _Engraving._(this._layers, this._time, this.width, this.height, this._nameHeight);

  static _Engraving of(
    String name,
    String? time, {
    required double font,
    required double timeFont,
    required Color inlay,
    required AstrolabePalette palette,
    required AstrolabeLabels labels,
  }) {
    TextPainter text(String s, double size, Paint paint, {required bool display}) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: display ? MadarTypography.displayFamily : MadarTypography.uiFamily,
          fontSize: size,
          fontWeight: display ? FontWeight.w500 : FontWeight.w600,
          fontVariations: display ? const [FontVariation.weight(500)] : null,
          foreground: paint,
          height: 1.1,
          letterSpacing: labels.arabic || !display ? 0 : size * 0.04,
          fontFeatures: display ? null : const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: labels.textDirection,
      textAlign: TextAlign.center,
    )..layout();

    List<TextPainter> layers(String s, double size, Color color, {required bool display}) => [
      text(
        s,
        size,
        Paint()
          ..color = palette.shadow.withValues(alpha: palette.light ? 0.4 : 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.16),
        display: display,
      ),
      text(s, size, Paint()..color = palette.ink.withValues(alpha: 0.95), display: display),
      text(s, size, Paint()..color = palette.engraveHi.withValues(alpha: 0.55), display: display),
      text(s, size, Paint()..color = color, display: display),
    ];

    final names = layers(name, font, inlay, display: true);
    final times = time == null
        ? null
        : layers(time, timeFont, Color.lerp(inlay, palette.plateLine, 0.35)!.withValues(alpha: 0.92), display: false);
    final nameH = names.last.height * 0.9;
    final w = math.max(names.last.width, times?.last.width ?? 0);
    final h = nameH + (times == null ? 0 : times.last.height * 0.9);
    return _Engraving._(names, times, w, h, nameH);
  }

  final List<TextPainter> _layers;
  final List<TextPainter>? _time;
  final double width, height, _nameHeight;

  /// Paints centred on the origin; [lit] is the lower lip's offset and
  /// [cavity] how far the dark wall sits above the inlay.
  void paint(Canvas c, {required Offset lit, required double cavity}) {
    void block(List<TextPainter> l, double top) {
      final w = l.last.width;
      final o = Offset(-w / 2, top);
      l[0].paint(c, o);
      l[1].paint(c, o - Offset(cavity * 0.55, cavity));
      l[2].paint(c, o + lit);
      l[3].paint(c, o);
    }

    final top = -height / 2 - _layers.last.height * 0.05;
    block(_layers, top);
    final t = _time;
    if (t != null) block(t, top + _nameHeight);
  }

  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final l in [..._layers, ...?_time]) {
      l.dispose();
    }
  }
}
