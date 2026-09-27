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

  // ---------------------------------------------------------------- static set
  Object? _staticKey;
  double rb = 0;
  AstrolabeLod lod = AstrolabeLod.full;

  /// Limb annulus (evenOdd) and hub geometry at [rb].
  late Path limbPath;
  ui.Picture? limbInk;
  ui.Picture? plateInk;
  ui.Picture? reteInk;

  late Paint platePaint;
  late Paint plateSheenPaint;
  late Paint limbShadowPaint;
  late Paint haloPaint;
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
  late Paint fallbackBrassPaint;
  late Paint fallbackStarPaint;
  late Paint fallbackFirePaint;
  late Path sunRays;

  // Rete at [rb].
  late Path reteRings;
  late Path reteEcliptic;
  late Path reteStraps;
  late Path reteOvers;
  late Path reteFlames;

  // ---------------------------------------------------------------- almucantars
  Object? _almuKey;
  ui.Picture? almucantars;

  // ---------------------------------------------------------------- prayers
  Object? _prayerKey;
  ui.Picture? labels;
  final Map<Prayer, Path> pointerPaths = {};
  final Map<Prayer, Offset> pointerCenters = {};
  final Map<Prayer, Offset> pointerTips = {};
  Map<Prayer, double> labelAngles = const {};

  /// Centres of the engraved names (px at [rb], origin-centred).
  final Map<Prayer, Offset> labelCenters = {};

  // ---------------------------------------------------------------- hub text
  Object? _countdownKey;
  ui.Image? countdownImage;
  double countdownScale = 1;
  Object? _markKey;
  ui.Image? markImage;
  double markScale = 1;

  /// Font size (px at [rb]) of the hub ring text; the band is 1.5× that.
  double hubFont = 10;
  double get hubBand => hubFont * 1.5;
  double get hubOuter => AstrolabeRadii.hubOuter * rb;
  double get hubInner => hubOuter - hubBand;

  bool get isDisposed => _disposed;

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
    rb = bucket;
    this.lod = lod;
    limbInk?.dispose();
    plateInk?.dispose();
    reteInk?.dispose();
    final r = bucket;
    hubFont = math.max(9.0, r * 0.058);

    limbPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r))
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * AstrolabeRadii.limbInner));

    platePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        r * AstrolabeRadii.limbInner,
        [palette.enamelCenter, palette.enamelMid, palette.enamelEdge],
        const [0.0, 0.58, 1.0],
      );
    plateSheenPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(-0.32 * r, -0.42 * r),
        r * 0.75,
        [palette.enamelSheen.withValues(alpha: 0.32), palette.enamelSheen.withValues(alpha: 0)],
      );
    limbShadowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        r * AstrolabeRadii.limbInner,
        [palette.shadow.withValues(alpha: 0), palette.shadow.withValues(alpha: 0), palette.shadow.withValues(alpha: 0.55)],
        const [0.0, 0.9, 1.0],
      );
    final haloR = r * AstrolabeRadii.halo;
    haloPaint = palette.light
        ? (Paint()
            ..shader = ui.Gradient.radial(
              Offset(0, r * 0.03),
              haloR,
              [palette.shadow, palette.shadow, palette.shadow.withValues(alpha: 0)],
              const [0.0, 0.88, 1.0],
            ))
        : (Paint()
            ..shader = ui.Gradient.radial(
              Offset.zero,
              haloR,
              [palette.halo.withValues(alpha: 0.3), palette.halo.withValues(alpha: 0.22), palette.halo.withValues(alpha: 0)],
              [0.0, 1 / AstrolabeRadii.halo, 1.0],
            ));
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
        r * (AstrolabeRadii.hubOuter + 0.05),
        [palette.shadow.withValues(alpha: 0.6), palette.shadow.withValues(alpha: 0.45), palette.shadow.withValues(alpha: 0)],
        [0.0, AstrolabeRadii.hubOuter / (AstrolabeRadii.hubOuter + 0.05), 1.0],
      );
    hubWindowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        hubInner,
        [palette.enamelMid, palette.enamelEdge],
      );
    final sunR = r * 0.034;
    sunRays = AstrolabePaths.sunRays(sunR);
    sunGlowPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        Offset.zero,
        sunR * 3.6,
        [palette.sunGlow.withValues(alpha: 0.55), palette.sunGlow.withValues(alpha: 0.16), palette.sunGlow.withValues(alpha: 0)],
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
        r * 0.075,
        [palette.litHead.withValues(alpha: 0.95), palette.litArc.withValues(alpha: 0.3), palette.litArc.withValues(alpha: 0)],
        const [0.0, 0.3, 1.0],
      );
    pointerGlowPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        Offset.zero,
        r * 0.1,
        [palette.litHead.withValues(alpha: 0.7), palette.litArc.withValues(alpha: 0.22), palette.litArc.withValues(alpha: 0)],
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
        [palette.starCorona.withValues(alpha: 0.2), palette.starCorona.withValues(alpha: 0.07), palette.starCorona.withValues(alpha: 0)],
        const [0.0, 0.45, 1.0],
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
        [palette.fireInner, palette.starCore, palette.starCorona.withValues(alpha: 0.35), palette.starCorona.withValues(alpha: 0)],
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
    reteRings = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r * AstrolabeRadii.capricorn));
    reteEcliptic = Path()..addOval(Rect.fromCircle(center: rete.eclipticCenter * r, radius: rete.eclipticRadius * r));
    reteStraps = rete.straps.transform(scale);
    reteOvers = rete.overs.transform(scale);
    reteFlames = rete.flames.transform(scale);

    limbInk = _recordLimb(palette, labels);
    plateInk = _recordPlate(palette);
    reteInk = _recordRete(palette, labels, rete);
    // Everything keyed on the static layer is stale now.
    _prayerKey = null;
    _almuKey = null;
    _countdownKey = null;
    _markKey = null;
    return true;
  }

  // -------------------------------------------------------------- limb engraving

  ui.Picture _recordLimb(AstrolabePalette palette, AstrolabeLabels labels) {
    final r = rb;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final px = math.max(0.6, r / 260); // engraving line unit
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

    // Numerals (kept upright), noon at the top, 24 at the bottom.
    if (lod >= AstrolabeLod.medium) {
      final font = r * (lod >= AstrolabeLod.full ? 0.05 : 0.056);
      final every = lod >= AstrolabeLod.full ? 1 : 2;
      final rr = r * AstrolabeRadii.numerals;
      for (var h = every; h <= 24; h += every) {
        final a = AstrolabeGeometry.angleForFraction(h / 24);
        final text = labels.numeral(h);
        final tpInk = _text(text, font, palette.ink.withValues(alpha: 0.92), weight: FontWeight.w700, labels: labels);
        final tpHi = _text(text, font, palette.engraveHi.withValues(alpha: 0.5), weight: FontWeight.w700, labels: labels);
        c
          ..save()
          ..translate(math.cos(a) * rr, math.sin(a) * rr)
          ..rotate(AstrolabeGeometry.uprightRotation(a));
        final o = Offset(-tpInk.width / 2, -tpInk.height / 2);
        final rot = AstrolabeGeometry.uprightRotation(a);
        // keep the engraving's lit edge toward the bottom-right of the screen
        final litLocal = _rotate(lit, -rot);
        tpHi.paint(c, o + litLocal);
        tpInk.paint(c, o);
        c.restore();
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
    final px = math.max(0.6, r / 260);
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
          palette.plateLine.withValues(alpha: 0.13),
          palette.plateLine.withValues(alpha: 0.2),
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
      c.drawPath(marks, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = px * 0.8
        ..color = palette.plateLine.withValues(alpha: 0.42));
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
    final px = math.max(0.6, r / 260);
    final cap = r * AstrolabeRadii.capricorn;
    c.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: cap)));

    Rect circleOf(double alt) {
      final a = AstrolabeProjection.almucantar(alt, latitude);
      return Rect.fromCircle(center: a.center * r, radius: a.radius * r);
    }

    final horizon = circleOf(0);
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
          ..shader = ui.Gradient.radial(
            Offset(0, -cap * 0.6),
            cap * 1.3,
            [palette.daySky.withValues(alpha: 0.2), palette.daySky.withValues(alpha: 0.07)],
          ),
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
      final star = Path();
      final s = r * 0.012;
      star
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
      ..drawOval(horizon.shift(Offset(px * 0.4, px * 0.6)), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = px * 1.4
        ..color = palette.shadow.withValues(alpha: 0.5))
      ..drawOval(horizon, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = px * 1.1
        ..color = palette.plateLine.withValues(alpha: 0.62));
    return almucantars = rec.endRecording();
  }

  // -------------------------------------------------------------- rete engraving

  ui.Picture _recordRete(AstrolabePalette palette, AstrolabeLabels labels, ReteModel rete) {
    final r = rb;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final px = math.max(0.6, r / 260);
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
      final every = lod >= AstrolabeLod.ultra ? 2 : (lod >= AstrolabeLod.full ? 10 : 30);
      for (var l = 0; l < 360; l += every) {
        final p = AstrolabeProjection.eclipticPoint(l.toDouble()) * r;
        final d = p - ec;
        final u = d / d.distance;
        final len = l % 30 == 0 ? 0.9 : (l % 10 == 0 ? 0.5 : 0.28);
        final outer = ec + u * (er + ew * 0.5 - px);
        ticks
          ..moveTo(outer.dx, outer.dy)
          ..lineTo(outer.dx - u.dx * ew * len, outer.dy - u.dy * ew * len);
      }
      c.drawPath(ticks, ink..strokeWidth = px * 0.75);
    }
    // Capricorn ring rail.
    c.drawCircle(Offset.zero, r * AstrolabeRadii.capricorn, ink..strokeWidth = px * 0.7);

    // Rivet eyes on the pointer bosses.
    final eyes = Path();
    for (final s in rete.stars) {
      eyes.addOval(Rect.fromCircle(center: s.base * r, radius: r * 0.0048));
    }
    c.drawPath(eyes, Paint()..color = palette.ink.withValues(alpha: 0.8));

    // Star names along their pointers (large dials only).
    if (lod >= AstrolabeLod.ultra) {
      final font = r * 0.023;
      for (final s in rete.stars) {
        final name = labels.arabic ? s.nameAr : s.nameEn;
        final mid = (s.base * 0.45 + s.tip * 0.55) * r;
        var a = math.atan2(s.tip.dy - s.base.dy, s.tip.dx - s.base.dx);
        // keep names readable (never upside down)
        if (math.cos(a) < 0) a += math.pi;
        final tp = _text(name, font, palette.plateLine.withValues(alpha: 0.85), weight: FontWeight.w600, labels: labels);
        final shade = _text(name, font, palette.enamelEdge.withValues(alpha: 0.85), weight: FontWeight.w600, labels: labels, outline: font * 0.18);
        c
          ..save()
          ..translate(mid.dx, mid.dy)
          ..rotate(a)
          ..translate(0, r * 0.03 * (math.cos(math.atan2(s.tip.dy - s.base.dy, s.tip.dx - s.base.dx)) < 0 ? s.bend : -s.bend));
        shade.paint(c, Offset(-tp.width / 2, -tp.height / 2));
        tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
        c.restore();
      }
    }
    return rec.endRecording();
  }

  // -------------------------------------------------------------- prayers

  /// Pointer paths and the names (a picture) for the current prayer times,
  /// statuses and language.
  void ensurePrayers({
    required AstrolabeState state,
    required AstrolabePalette palette,
  }) {
    final r = rb;
    final statuses = [for (final p in AstrolabeGeometry.prayers) state.statusOf(p)];
    final minutes = [for (final p in AstrolabeGeometry.prayers) (state.fractionOf(p) * 1440).round()];
    final key = (_staticKey, statuses.join(), minutes.join(','), state.labels);
    if (key == _prayerKey) return;
    _prayerKey = key;
    labels?.dispose();
    labels = null;
    pointerPaths.clear();
    pointerCenters.clear();
    pointerTips.clear();
    final fractions = state.fractions;
    for (final e in fractions.entries) {
      final center = AstrolabeGeometry.pointerCenter(Offset.zero, r, e.value);
      final tip = AstrolabeGeometry.pointerTip(Offset.zero, r, e.value);
      final a = AstrolabeGeometry.angleForFraction(e.value);
      pointerCenters[e.key] = center;
      pointerTips[e.key] = tip;
      pointerPaths[e.key] = AstrolabePaths.pointerStar(
        center: center,
        radius: r * AstrolabeRadii.pointerStar,
        angle: a,
        tipLength: r * (AstrolabeRadii.limbInner - AstrolabeRadii.channel),
      );
    }
    if (lod < AstrolabeLod.medium) {
      labelAngles = const {};
      return;
    }
    final font = math.max(8.5, r * (lod >= AstrolabeLod.full ? 0.05 : 0.06));
    final painters = <Prayer, (TextPainter, TextPainter?, TextPainter?)>{};
    final timeShades = <Prayer, TextPainter?>{};
    var maxW = 0.0;
    var maxH = 0.0;
    for (final p in AstrolabeGeometry.prayers) {
      final status = state.statusOf(p);
      final color = switch (status) {
        AstrolabePrayerStatus.prayed => palette.labelPrayed,
        AstrolabePrayerStatus.due => palette.labelDue,
        AstrolabePrayerStatus.upcoming => palette.labelUpcoming,
        AstrolabePrayerStatus.missed => palette.labelMissed,
      };
      final name = _text(state.labels.prayerName(p), font, color, weight: FontWeight.w700, labels: state.labels, display: true);
      final shade = _text(state.labels.prayerName(p), font, palette.enamelEdge.withValues(alpha: 0.9), weight: FontWeight.w700, labels: state.labels, display: true, outline: font * 0.2);
      TextPainter? time;
      TextPainter? timeShade;
      if (lod >= AstrolabeLod.ultra) {
        final t = state.labels.time(state.timeOf(p));
        time = _text(t, font * 0.66, Color.lerp(color, palette.plateLine, 0.35)!, weight: FontWeight.w600, labels: state.labels);
        timeShade = _text(t, font * 0.66, palette.enamelEdge.withValues(alpha: 0.9), weight: FontWeight.w600, labels: state.labels, outline: font * 0.16);
      }
      painters[p] = (name, shade, time);
      timeShades[p] = timeShade;
      maxW = math.max(maxW, math.max(name.width, time?.width ?? 0));
      maxH = math.max(maxH, name.height * 0.8 + (time == null ? 0 : time.height * 0.8));
    }
    final radius = r * (AstrolabeRadii.labelsOuter - 0.06);
    labelAngles = AstrolabeGeometry.labelAngles(
      fractions,
      gapFor: (a) {
        final s = math.sin(a).abs(), co = math.cos(a).abs();
        final need = math.min(s < 1e-3 ? double.infinity : (maxW + font * 0.4) / s, co < 1e-3 ? double.infinity : (maxH + font * 0.15) / co);
        return need / radius;
      },
    );
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final px = math.max(0.6, r / 260);
    labelCenters.clear();
    for (final p in AstrolabeGeometry.prayers) {
      final (name, shade, time) = painters[p]!;
      final a = labelAngles[p]!;
      final dir = Offset(math.cos(a), math.sin(a));
      final boxW = math.max(name.width, time?.width ?? 0);
      final total = name.height * 0.82 + (time == null ? 0 : time.height * 0.8);
      // Sit each name just inside the rete's rim, whatever its width.
      final extent = boxW / 2 * dir.dx.abs() + total / 2 * dir.dy.abs();
      final center = dir * (r * AstrolabeRadii.labelsOuter - extent);
      labelCenters[p] = center;
      final top = center.dy - total / 2 - name.height * 0.09;
      final o = Offset(center.dx - name.width / 2, top);
      // dark outline (legible over the rete), a lit edge, then the gold inlay
      shade!.paint(c, o + Offset(px * 0.3, px * 0.5));
      name.paint(c, o);
      if (time != null) {
        final to = Offset(center.dx - time.width / 2, top + name.height * 0.82);
        timeShades[p]?.paint(c, to);
        time.paint(c, to);
      }
    }
    labels = rec.endRecording();
  }

  // -------------------------------------------------------------- hub text

  /// The countdown as a white-on-transparent image [countdownScale]× the
  /// size it is shown at (re-rendered only when the text changes).
  ui.Image ensureCountdown(String text, AstrolabeLabels labels, double devicePixelRatio) {
    final scale = (devicePixelRatio * 1.35).clamp(1.0, 6.0);
    final key = (text, hubFont, scale, labels.arabic);
    final existing = countdownImage;
    if (key == _countdownKey && existing != null) return existing;
    _countdownKey = key;
    existing?.dispose();
    countdownScale = scale;
    return countdownImage = _ringTextImage(text, hubFont, scale, labels, flip: false);
  }

  /// The maker's mark for the lower half of the hub (drawn upside down in
  /// the image so it reads upright along the bottom of the ring).
  ui.Image ensureMark(String text, AstrolabeLabels labels, double devicePixelRatio) {
    final scale = (devicePixelRatio * 1.35).clamp(1.0, 6.0);
    final key = (text, hubFont, scale, labels.arabic);
    final existing = markImage;
    if (key == _markKey && existing != null) return existing;
    _markKey = key;
    existing?.dispose();
    markScale = scale;
    return markImage = _ringTextImage(text, hubFont * 0.9, scale, labels, flip: true, band: hubBand);
  }

  ui.Image _ringTextImage(
    String text,
    double font,
    double scale,
    AstrolabeLabels labels, {
    required bool flip,
    double? band,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: MadarTypography.uiFamily,
          fontSize: font * scale,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFFFFF),
          height: 1.0,
          letterSpacing: labels.arabic ? 0 : font * scale * 0.06,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
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
          fontFamily: MadarTypography.uiFamily,
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
    countdownImage?.dispose();
    markImage?.dispose();
    limbInk = plateInk = reteInk = almucantars = labels = null;
    countdownImage = markImage = null;
  }
}
