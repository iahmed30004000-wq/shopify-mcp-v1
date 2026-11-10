import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../orbit/render/astrolabe/astrolabe_palette.dart';
import '../../../orbit/render/astrolabe/astrolabe_paths.dart';
import '../../../orbit/render/astrolabe/astrolabe_shaders.dart';

/// Radii of the qibla astrolabe in units of the limb radius R.
abstract final class QiblaDialGeometry {
  static const double limbInner = 0.865;
  static const double reteInner = 0.765;
  static const double reteOuter = 0.795;
  static const double letters = 0.665;
  static const double pointerCenter = 0.78;
  static const double pointerRadius = 0.088;
  static const double pointerTip = 0.975;
  static const double needleTip = 0.70;
  static const double needleTail = 0.25;
  static const double hub = 0.078;
  static const double sun = 0.60;

  /// The limb radius for a dial laid out in [size] (room is left above for
  /// the kursi – the astrolabe's throne – and around for the glow).
  static double radiusFor(Size size) => math.min(size.width / 2 * 0.88, size.height / 2.34);

  /// The dial centre (pushed down to make room for the kursi).
  static Offset centerFor(Size size) {
    final r = radiusFor(size);
    return Offset(size.width / 2, size.height / 2 + r * 0.1);
  }
}

/// What the dial shows around the needle.
enum QiblaDialKind {
  /// Live compass: the dial turns with the phone.
  compass,

  /// Waiting for the compass: north up, the needle dimmed.
  waiting,

  /// Sun compass: the sun is drawn on the dial.
  sun,

  /// Static diagram: north up, a protractor arc from north to the qibla.
  diagram,
}

/// Colours and labels of the dial (all derived from the theme tokens).
@immutable
class QiblaDialStyle {
  const QiblaDialStyle({
    required this.palette,
    required this.gold,
    required this.accent,
    required this.accentGlow,
    required this.kaabaBody,
    required this.cardinals,
    required this.arabicDigits,
    required this.letterFamily,
    required this.numeralFamily,
    required this.degreeLabel,
    this.compact = false,
  });

  factory QiblaDialStyle.of(
    MadarTokens t, {
    required List<String> cardinals,
    required bool arabicDigits,
    required String Function(double degrees) degreeLabel,
    bool compact = false,
  }) {
    final palette = AstrolabePalette.fromTokens(t);
    return QiblaDialStyle(
      palette: palette,
      gold: t.metalGold,
      accent: t.isDark ? t.accent : Color.lerp(t.metalGold, t.accent, 0.35)!,
      accentGlow: t.isDark ? Color.lerp(t.metalGold, t.accentGlow, 0.35)! : t.metalGold,
      kaabaBody: Color.lerp(t.brassDark, const Color(0xFF000000), 0.72)!,
      cardinals: cardinals,
      arabicDigits: arabicDigits,
      letterFamily: MadarTypography.displayFamily,
      numeralFamily: MadarTypography.uiFamily,
      degreeLabel: degreeLabel,
      compact: compact,
    );
  }

  final AstrolabePalette palette;
  final Color gold;
  final Color accent;
  final Color accentGlow;

  /// The Kaaba's black kiswah (a near-black of the theme's dark brass).
  final Color kaabaBody;

  /// N, E, S, W labels (localised: ش ق ج غ in Arabic).
  final List<String> cardinals;
  final bool arabicDigits;
  final String letterFamily;
  final String numeralFamily;

  /// Formats a bearing for the diagram's protractor label.
  final String Function(double degrees) degreeLabel;

  /// A small dial (cards): no numerals, fewer ticks, bolder letters.
  final bool compact;

  /// Identity of everything baked into the engraving raster.
  Object get engravingKey => Object.hash(
    palette.brass,
    palette.ink,
    palette.enamelCenter,
    palette.plateLine,
    accent,
    Object.hashAll(cardinals),
    arabicDigits,
    letterFamily,
    compact,
  );
}

/// The brushed-brass shader of the Orbit's astrolabe (shaders/orbit/
/// brass.frag, reused read-only), or null → gradient fallback.
class QiblaBrass {
  QiblaBrass(AstrolabePrograms programs) : shader = programs.brass.fragmentShader() {
    shader.setImageSampler(0, programs.noise, filterQuality: ui.FilterQuality.low);
  }

  final ui.FragmentShader shader;

  void dispose() => shader.dispose();
}

/// The static engraving of the dial – plate, girih, compass rose, cardinal
/// letters, the limb's degree scale – rasterised once per size and style
/// and drawn rotated every frame.
class QiblaDialEngraving {
  ui.Image? _image;
  Object? _key;

  /// Number of rasterisations so far (tests assert it stays at one).
  int renders = 0;

  ui.Image imageFor(double r, double dpr, QiblaDialStyle style) {
    final key = Object.hash(r.roundToDouble(), dpr, style.engravingKey);
    final existing = _image;
    if (existing != null && key == _key) return existing;
    existing?.dispose();
    final px = (r * 2 * dpr).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(dpr)
      ..translate(r, r);
    _paintEngraving(canvas, r, style);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(px, px);
    picture.dispose();
    renders++;
    _key = key;
    return _image = image;
  }

  List<TextPainter>? _letters;
  Object? _lettersKey;

  /// The four cardinal letters, laid out once per size and style (drawn
  /// upright on screen every frame).
  List<TextPainter> lettersFor(double r, QiblaDialStyle s) {
    final key = Object.hash(r.roundToDouble(), s.engravingKey);
    final existing = _letters;
    if (existing != null && key == _lettersKey) return existing;
    if (existing != null) {
      for (final tp in existing) {
        tp.dispose();
      }
    }
    final p = s.palette;
    _lettersKey = key;
    return _letters = [
      for (var i = 0; i < 4; i++)
        TextPainter(
          text: TextSpan(
            text: s.cardinals[i],
            style: TextStyle(
              fontFamily: s.letterFamily,
              fontSize: r * (s.compact ? (i == 0 ? 0.25 : 0.21) : (i == 0 ? 0.14 : 0.115)),
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: i == 0 ? s.accent : p.brassHi,
              shadows: [Shadow(color: p.enamelEdge, blurRadius: r * 0.02)],
            ),
          ),
          textDirection: TextDirection.rtl,
        )..layout(),
    ];
  }

  QiblaDialPaths? _paths;

  /// The needle, kursi and ring outlines for radius [r] (built once per
  /// size – path boolean operations are too costly for every frame).
  QiblaDialPaths pathsFor(double r) {
    final existing = _paths;
    if (existing != null && existing.r == r) return existing;
    return _paths = QiblaDialPaths(r);
  }

  List<(int, TextPainter)>? _numerals;
  Object? _numeralsKey;

  /// The limb's numerals (every 30°, cardinals excepted), laid out once and
  /// drawn live so they can turn upright in the lower half.
  List<(int, TextPainter)> numeralsFor(double r, QiblaDialStyle s) {
    final key = Object.hash(r.roundToDouble(), s.engravingKey);
    final existing = _numerals;
    if (existing != null && key == _numeralsKey) return existing;
    if (existing != null) {
      for (final (_, tp) in existing) {
        tp.dispose();
      }
    }
    final p = s.palette;
    _numeralsKey = key;
    return _numerals = [
      for (var d = 30; d < 360 && !s.compact; d += 30)
        if (d % 90 != 0)
          (
            d,
            TextPainter(
              text: TextSpan(
                text: s.arabicDigits ? _arabicIndic('$d') : '$d',
                style: TextStyle(
                  fontFamily: s.numeralFamily,
                  fontSize: r * 0.066,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: p.ink,
                  shadows: [
                    Shadow(color: p.engraveHi.withValues(alpha: 0.5), offset: Offset(0, math.max(0.5, r * 0.004))),
                  ],
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(),
          ),
    ];
  }

  void dispose() {
    _image?.dispose();
    _image = null;
    final numerals = _numerals;
    if (numerals != null) {
      for (final (_, tp) in numerals) {
        tp.dispose();
      }
    }
    _numerals = null;
    final letters = _letters;
    if (letters != null) {
      for (final tp in letters) {
        tp.dispose();
      }
    }
    _letters = null;
  }

  static void _paintEngraving(Canvas canvas, double r, QiblaDialStyle s) {
    final p = s.palette;
    const g = QiblaDialGeometry.limbInner;

    // ---- enamel plate
    canvas.drawCircle(
      Offset.zero,
      r * g,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(-r * 0.18, -r * 0.22),
          r * 1.05,
          [p.enamelCenter, p.enamelMid, p.enamelEdge],
          const [0, 0.55, 1],
        ),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r * (g - 0.012))));
    canvas.drawPath(
      AstrolabePaths.girih(scale: r * g, spacing: 0.22),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.5, r * 0.0035)
        ..color = p.plateLine.withValues(alpha: 0.16),
    );
    // A soft sheen across the enamel.
    canvas.drawCircle(
      Offset.zero,
      r * g,
      Paint()
        ..shader = ui.Gradient.linear(Offset(-r, -r), Offset(r * 0.6, r * 0.6), [
          p.enamelSheen.withValues(alpha: 0.28),
          p.enamelSheen.withValues(alpha: 0),
        ]),
    );
    canvas.restore();

    final hair = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.005)
      ..color = p.plateLine.withValues(alpha: 0.5);
    canvas
      ..drawCircle(Offset.zero, r * 0.30, hair)
      ..drawCircle(Offset.zero, r * 0.54, hair)
      ..drawCircle(Offset.zero, r * (g - 0.02), hair..color = p.plateLine.withValues(alpha: 0.35));

    // ---- wind rose: 16 rays, each split into a lit and a shaded facet.
    for (var i = 0; i < 16; i++) {
      final a = (i * 22.5 - 90) * math.pi / 180;
      final len = i % 4 == 0 ? 0.56 : (i % 2 == 0 ? 0.40 : 0.24);
      final half = i % 4 == 0 ? 0.075 : (i % 2 == 0 ? 0.06 : 0.04);
      final d = Offset(math.cos(a), math.sin(a));
      final n = Offset(-d.dy, d.dx);
      final tip = d * (r * len);
      final left = (d * (r * 0.06) + n * (r * half));
      final right = (d * (r * 0.06) - n * (r * half));
      final major = i % 4 == 0;
      canvas
        ..drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(left.dx, left.dy)
            ..lineTo(tip.dx, tip.dy)
            ..close(),
          Paint()..color = p.plateLine.withValues(alpha: major ? 0.34 : 0.2),
        )
        ..drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(right.dx, right.dy)
            ..lineTo(tip.dx, tip.dy)
            ..close(),
          Paint()..color = p.enamelSheen.withValues(alpha: major ? 0.5 : 0.3),
        )
        ..drawPath(
          Path()
            ..moveTo(left.dx, left.dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(right.dx, right.dy),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.miter
            ..strokeWidth = math.max(0.5, r * 0.004)
            ..color = p.plateLine.withValues(alpha: major ? 0.7 : 0.45),
        );
    }

    // ---- intercardinal pips (the letters are drawn live, upright)
    for (var i = 0; i < 4; i++) {
      final a = (45 + i * 90 - 90) * math.pi / 180;
      final c = Offset(math.cos(a), math.sin(a)) * (r * QiblaDialGeometry.letters);
      canvas.drawPath(_diamond(c, r * 0.022, a), Paint()..color = p.plateLine.withValues(alpha: 0.75));
    }

    // ---- limb engraving (drawn over the live brass): rules, ticks, numerals
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..color = p.ink.withValues(alpha: 0.9)
      ..strokeWidth = math.max(0.7, r * 0.006);
    final lit = Paint()
      ..style = PaintingStyle.stroke
      ..color = p.engraveHi.withValues(alpha: 0.45)
      ..strokeWidth = math.max(0.5, r * 0.004);
    final hi = Offset(0, math.max(0.5, r * 0.004));
    canvas
      ..drawCircle(hi, r * 0.992, lit)
      ..drawCircle(Offset.zero, r * 0.992, ink)
      ..drawCircle(hi, r * (g + 0.002), lit)
      ..drawCircle(Offset.zero, r * (g + 0.002), ink);
    for (var d = 0; d < 360; d += s.compact ? 10 : 2) {
      final a = (d - 90) * math.pi / 180;
      final dir = Offset(math.cos(a), math.sin(a));
      final (len, w) = d % 30 == 0
          ? (0.068, 0.009)
          : d % 10 == 0
          ? (0.05, 0.0065)
          : (0.028, 0.0045);
      final p0 = dir * (r * 0.985);
      final p1 = dir * (r * (0.985 - len));
      canvas
        ..drawLine(p0 + hi, p1 + hi, lit..strokeWidth = math.max(0.4, r * w * 0.8))
        ..drawLine(
          p0,
          p1,
          ink
            ..strokeWidth = math.max(0.5, r * w)
            ..strokeCap = StrokeCap.round,
        );
    }
    // Cardinal stars on the limb (north in the accent).
    for (var i = 0; i < 4; i++) {
      final a = (i * 90 - 90) * math.pi / 180;
      final c = Offset(math.cos(a), math.sin(a)) * (r * 0.892);
      final star = _star(c, r * (i == 0 ? 0.042 : 0.032), 8, 0.45, a);
      canvas
        ..drawPath(star.shift(hi), Paint()..color = p.engraveHi.withValues(alpha: 0.5))
        ..drawPath(star, Paint()..color = i == 0 ? s.accent : p.ink);
    }
  }

  static String _arabicIndic(String s) {
    const digits = '٠١٢٣٤٥٦٧٨٩';
    return s.replaceAllMapped(RegExp('[0-9]'), (m) => digits[int.parse(m[0]!)]);
  }
}

/// Every outline of the dial at one radius (dial centre at the origin; the
/// needle along −y).
class QiblaDialPaths {
  QiblaDialPaths(this.r) {
    Path annulus(double inner, double outer) => Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * outer))
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * inner));
    limb = annulus(QiblaDialGeometry.limbInner - 0.004, 1.0);
    rete = annulus(QiblaDialGeometry.reteInner, QiblaDialGeometry.reteOuter);

    // The needle: a faceted lozenge (lit and shaded halves) and a crescent.
    final tipY = -r * QiblaDialGeometry.needleTip;
    final tailY = r * QiblaDialGeometry.needleTail;
    final w = r * 0.052;
    needleLit = Path()
      ..moveTo(0, tipY)
      ..lineTo(-w, -r * 0.1)
      ..lineTo(-w * 0.62, tailY * 0.72)
      ..lineTo(0, tailY)
      ..close();
    needleShade = Path()
      ..moveTo(0, tipY)
      ..lineTo(w, -r * 0.1)
      ..lineTo(w * 0.62, tailY * 0.72)
      ..lineTo(0, tailY)
      ..close();
    needleWhole = Path.combine(PathOperation.union, needleLit, needleShade);
    crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: Offset(0, tailY + r * 0.045), radius: r * 0.058)),
      Path()..addOval(Rect.fromCircle(center: Offset(0, tailY + r * 0.07), radius: r * 0.05)),
    );
    needleShadow = Path.combine(PathOperation.union, needleWhole, crescent).shift(Offset(r * 0.012, r * 0.022));

    // The kursi: an ogee throne on the limb with its shackle ring and a
    // pierced eight-point star.
    final base = -r * 0.975;
    final top = -r * 1.17;
    final kw = r * 0.2;
    final throne = Path()
      ..moveTo(-kw, base)
      ..cubicTo(-kw * 0.95, base - r * 0.07, -kw * 0.45, base - r * 0.05, -kw * 0.42, top + r * 0.06)
      ..cubicTo(-kw * 0.4, top + r * 0.02, -kw * 0.12, top + r * 0.02, 0, top)
      ..cubicTo(kw * 0.12, top + r * 0.02, kw * 0.4, top + r * 0.02, kw * 0.42, top + r * 0.06)
      ..cubicTo(kw * 0.45, base - r * 0.05, kw * 0.95, base - r * 0.07, kw, base)
      ..arcToPoint(Offset(-kw, base), radius: Radius.circular(r * 0.975), clockwise: false)
      ..close();
    final ringC = Offset(0, top - r * 0.035);
    final ring = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: ringC, radius: r * 0.05)),
      Path()..addOval(Rect.fromCircle(center: ringC, radius: r * 0.03)),
    );
    kursiCut = _star(Offset(0, base - r * 0.085), r * 0.042, 8, 0.5, -math.pi / 2);
    kursiBody = Path.combine(PathOperation.difference, Path.combine(PathOperation.union, throne, ring), kursiCut);
    index = Path()
      ..moveTo(-r * 0.022, -r * 1.0)
      ..lineTo(r * 0.022, -r * 1.0)
      ..lineTo(0, -r * 0.89)
      ..close();
  }

  final double r;
  late final Path limb, rete;
  late final Path needleLit, needleShade, needleWhole, needleShadow, crescent;
  late final Path kursiBody, kursiCut, index;
}

/// A diamond pip centred at [c] oriented along [angle].
Path _diamond(Offset c, double size, double angle) {
  final d = Offset(math.cos(angle), math.sin(angle)) * size;
  final n = Offset(-d.dy, d.dx) * 0.6;
  return Path()
    ..moveTo(c.dx + d.dx, c.dy + d.dy)
    ..lineTo(c.dx + n.dx, c.dy + n.dy)
    ..lineTo(c.dx - d.dx, c.dy - d.dy)
    ..lineTo(c.dx - n.dx, c.dy - n.dy)
    ..close();
}

/// An n-point star centred at [c] with one point along [angle].
Path _star(Offset c, double radius, int points, double innerRatio, double angle) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final a = angle + i * math.pi / points;
    final rr = i.isEven ? radius : radius * innerRatio;
    final p = c + Offset(math.cos(a), math.sin(a)) * rr;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// Paints the Kaaba (a black cube with its golden band) centred at the
/// origin, [size] wide, its top toward −y.
void paintKaabaGlyph(Canvas canvas, double size, {required Color body, required Color band, Color? edge}) {
  final h = size / 2;
  final cube = RRect.fromRectAndRadius(Rect.fromLTRB(-h, -h * 0.92, h, h), Radius.circular(size * 0.08));
  canvas.drawRRect(cube, Paint()..color = body);
  // The golden hizam across the upper third.
  canvas.drawRect(Rect.fromLTRB(-h, -h * 0.42, h, -h * 0.2), Paint()..color = band);
  // The door (bottom right of the east face, simplified).
  canvas.drawRect(Rect.fromLTRB(h * 0.2, h * 0.18, h * 0.62, h), Paint()..color = band.withValues(alpha: 0.85));
  if (edge != null) {
    canvas.drawRRect(
      cube,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.5, size * 0.06)
        ..color = edge,
    );
  }
}

/// The qibla astrolabe: a brass limb with a degree scale, an enamel plate
/// with a wind rose, the Kaaba star-pointer on the rete, a golden needle on
/// a jewelled hub and the kursi (throne) marking "ahead".
///
/// [dial] turns the dial (degrees, clockwise), [needle] is the needle's
/// screen angle (degrees from straight up, clockwise – equal to the turn
/// still needed), [glow] (0…1) lights the needle and the kursi when aligned
/// and [tilt] (−1…1 per axis) shifts the layers for parallax.
class QiblaDialPainter extends CustomPainter {
  QiblaDialPainter({
    required this.dial,
    required this.needle,
    required this.glow,
    required this.tilt,
    required this.style,
    required this.engraving,
    required this.kind,
    required this.qiblaBearing,
    required this.devicePixelRatio,
    this.brass,
    this.sunAzimuth,
    this.showArrow = true,
    this.needleOpacity = 1,
    this.detail = true,
  }) : super(repaint: Listenable.merge([dial, needle, glow, tilt]));

  final ValueListenable<double> dial;
  final ValueListenable<double> needle;
  final ValueListenable<double> glow;
  final ValueListenable<Offset> tilt;
  final QiblaDialStyle style;
  final QiblaDialEngraving engraving;
  final QiblaDialKind kind;
  final double qiblaBearing;
  final double devicePixelRatio;
  final QiblaBrass? brass;
  final double? sunAzimuth;
  final bool showArrow;
  final double needleOpacity;

  /// Small renders (the card) skip the arrow and the parallax.
  final bool detail;

  static const _screenLight = Offset(-0.45, -0.89);

  AstrolabePalette get _p => style.palette;

  @override
  void paint(Canvas canvas, Size size) {
    final r = QiblaDialGeometry.radiusFor(size);
    if (r <= 4) return;
    final c = QiblaDialGeometry.centerFor(size);
    final t = detail ? tilt.value : Offset.zero;
    final dialOff = t * (r * 0.012);
    final needleOff = t * (r * 0.038);
    final dialRad = dial.value * math.pi / 180;
    final g = glow.value.clamp(0.0, 1.0);

    _halo(canvas, c + dialOff, r);

    // ---- the turning dial
    canvas
      ..save()
      ..translate(c.dx + dialOff.dx, c.dy + dialOff.dy)
      ..rotate(dialRad);
    // The light stays put on screen while the brass turns under it.
    final light = _rotate(_screenLight, -dialRad);
    canvas.drawPath(engraving.pathsFor(r).limb, _brass(r, light, 0.08));
    final image = engraving.imageFor(r, devicePixelRatio, style);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCircle(center: Offset.zero, radius: r),
      Paint()..filterQuality = FilterQuality.medium,
    );
    _bevel(canvas, r, light);
    canvas.drawPath(engraving.pathsFor(r).rete, _brass(r, light, 0.05));
    _reteEdges(canvas, r);
    if (kind == QiblaDialKind.sun && sunAzimuth != null) _sun(canvas, r, sunAzimuth!);
    if (kind == QiblaDialKind.diagram || kind == QiblaDialKind.waiting) {
      _protractor(canvas, r, kind == QiblaDialKind.waiting ? 0.35 : 1);
    }
    _kaabaPointer(canvas, r, g);
    canvas.restore();
    _numerals(canvas, c + dialOff, r, dialRad);
    _letters(canvas, c + dialOff, r, dialRad);

    // ---- the golden needle
    final nc = c + needleOff;
    canvas
      ..save()
      ..translate(nc.dx, nc.dy)
      ..rotate(needle.value * math.pi / 180);
    _needle(canvas, r, g);
    canvas.restore();
    _hub(canvas, nc, r);

    // ---- the kursi (fixed: "ahead")
    canvas
      ..save()
      ..translate(c.dx + dialOff.dx, c.dy + dialOff.dy);
    _kursi(canvas, r, g);
    canvas.restore();

    if (detail && showArrow && kind == QiblaDialKind.compass) _arrow(canvas, c, r, needle.value);
  }

  // ------------------------------------------------------------ materials

  Paint _brass(double r, Offset light, double wear) {
    final b = brass;
    if (b == null) {
      return Paint()
        ..shader = ui.Gradient.sweep(
          Offset.zero,
          [_p.brassHi, _p.brass, _p.brassLow, _p.brass, _p.brassHi],
          const [0.0, 0.25, 0.5, 0.75, 1.0],
          TileMode.clamp,
          -math.pi * 0.75,
          math.pi * 1.25,
        );
    }
    final s = b.shader;
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
    f(r);
    f(light.dx);
    f(light.dy);
    f(0);
    f(wear);
    col(_p.brass);
    col(_p.brassHi);
    col(_p.brassLow);
    return Paint()..shader = s;
  }

  static Offset _rotate(Offset v, double a) =>
      Offset(v.dx * math.cos(a) - v.dy * math.sin(a), v.dx * math.sin(a) + v.dy * math.cos(a));

  void _halo(Canvas canvas, Offset c, double r) {
    if (_p.light) {
      canvas.drawCircle(
        c + Offset(0, r * 0.03),
        r * 0.99,
        Paint()
          ..color = _p.shadow.withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05),
      );
    } else {
      canvas.drawCircle(
        c,
        r * 1.01,
        Paint()
          ..color = _p.halo.withValues(alpha: 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.09),
      );
      canvas.drawCircle(
        c + Offset(0, r * 0.02),
        r * 0.99,
        Paint()
          ..color = _p.shadow.withValues(alpha: 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.03),
      );
    }
  }

  /// Chamfered edges of the limb: lit toward the light, dark away from it.
  void _bevel(Canvas canvas, double r, Offset light) {
    final rect = Rect.fromCircle(center: Offset.zero, radius: r * 0.997);
    final a = math.atan2(light.dy, light.dx);
    final w = math.max(0.8, r * 0.012);
    canvas
      ..drawArc(
        rect,
        a - math.pi * 0.45,
        math.pi * 0.9,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = _p.bevelLight,
      )
      ..drawArc(
        rect,
        a + math.pi * 0.55,
        math.pi * 0.9,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = _p.bevelDark,
      );
  }

  void _reteEdges(Canvas canvas, double r) {
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, r * 0.004)
      ..color = _p.ink.withValues(alpha: 0.7);
    canvas
      ..drawCircle(Offset.zero, r * QiblaDialGeometry.reteInner, edge)
      ..drawCircle(Offset.zero, r * QiblaDialGeometry.reteOuter, edge);
  }

  /// The limb's numerals, engraved along the scale with their tops toward
  /// the rim – and turned the other way in the lower half so they never
  /// read upside down.
  void _numerals(Canvas canvas, Offset c, double r, double dialRad) {
    for (final (d, tp) in engraving.numeralsFor(r, style)) {
      final theta = d * math.pi / 180 + dialRad;
      final at = c + Offset(math.sin(theta), -math.cos(theta)) * (r * 0.885);
      final upper = math.cos(theta) >= 0;
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(upper ? theta : theta + math.pi);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  /// N / E / S / W on the plate, carried round by the dial but kept upright
  /// on screen so they always read.
  void _letters(Canvas canvas, Offset c, double r, double dialRad) {
    final letters = engraving.lettersFor(r, style);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 - math.pi / 2 + dialRad;
      final at = c + Offset(math.cos(a), math.sin(a)) * (r * QiblaDialGeometry.letters);
      final tp = letters[i];
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  // --------------------------------------------------------------- pointer

  /// The Kaaba star-pointer riveted to the rete at the qibla bearing: an
  /// eight-point star whose outward point runs into the degree scale.
  void _kaabaPointer(Canvas canvas, double r, double g) {
    final a = (qiblaBearing - 90) * math.pi / 180;
    final dir = Offset(math.cos(a), math.sin(a));
    final center = dir * (r * QiblaDialGeometry.pointerCenter);
    final star = AstrolabePaths.pointerStar(
      center: center,
      radius: r * QiblaDialGeometry.pointerRadius,
      angle: a,
      tipLength: r * (QiblaDialGeometry.pointerTip - QiblaDialGeometry.pointerCenter),
      innerRatio: 0.5,
    );
    if (g > 0) {
      canvas.drawPath(
        star,
        Paint()
          ..color = style.accentGlow.withValues(alpha: 0.75 * g)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05),
      );
    }
    canvas
      ..drawPath(
        star.shift(Offset(r * 0.006, r * 0.01)),
        Paint()
          ..color = _p.shadow.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.008),
      )
      ..drawPath(
        star,
        Paint()
          ..shader = ui.Gradient.linear(
            center - dir * (r * 0.07),
            center + dir * (r * 0.19),
            [Color.lerp(style.gold, _p.brassHi, 0.5)!, style.gold, _p.brass],
            const [0, 0.45, 1],
          ),
      )
      ..drawPath(
        star,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, r * 0.005)
          ..color = _p.ink.withValues(alpha: 0.85),
      );
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(a + math.pi / 2);
    canvas
      ..drawCircle(Offset.zero, r * 0.05, Paint()..color = Color.lerp(style.gold, _p.brassHi, 0.35)!)
      ..drawCircle(
        Offset.zero,
        r * 0.05,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, r * 0.005)
          ..color = _p.ink.withValues(alpha: 0.8),
      );
    paintKaabaGlyph(canvas, r * 0.056, body: style.kaabaBody, band: style.gold);
    canvas.restore();
  }

  void _sun(Canvas canvas, double r, double azimuth) {
    final a = (azimuth - 90) * math.pi / 180;
    final dir = Offset(math.cos(a), math.sin(a));
    final c = dir * (r * QiblaDialGeometry.sun);
    canvas.drawLine(
      dir * (r * 0.1),
      c - dir * (r * 0.07),
      Paint()
        ..strokeWidth = math.max(0.6, r * 0.006)
        ..color = _p.sun.withValues(alpha: 0.6),
    );
    canvas.drawCircle(
      c,
      r * 0.09,
      Paint()
        ..color = _p.sunGlow.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05),
    );
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(a + math.pi / 2);
    canvas.drawPath(AstrolabePaths.sunRays(r * 0.032), Paint()..color = _p.sun);
    canvas.drawCircle(Offset.zero, r * 0.032, Paint()..color = Color.lerp(_p.sun, style.gold, 0.4)!);
    canvas.restore();
  }

  /// North → qibla protractor (diagram mode): an arc with an arrowhead and
  /// the bearing engraved beside it.
  void _protractor(Canvas canvas, double r, double opacity) {
    final rr = r * 0.44;
    final sweep = qiblaBearing * math.pi / 180;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, r * 0.014)
      ..strokeCap = StrokeCap.round
      ..color = style.accent.withValues(alpha: 0.9 * opacity);
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: rr), -math.pi / 2, sweep, false, paint);
    final end = qiblaBearing * math.pi / 180 - math.pi / 2;
    final tip = Offset(math.cos(end), math.sin(end)) * rr;
    final tangent = Offset(-math.sin(end), math.cos(end));
    final normal = Offset(math.cos(end), math.sin(end));
    final head = r * 0.045;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx + tangent.dx * head, tip.dy + tangent.dy * head)
        ..lineTo(
          tip.dx - tangent.dx * head * 0.4 + normal.dx * head * 0.7,
          tip.dy - tangent.dy * head * 0.4 + normal.dy * head * 0.7,
        )
        ..lineTo(
          tip.dx - tangent.dx * head * 0.4 - normal.dx * head * 0.7,
          tip.dy - tangent.dy * head * 0.4 - normal.dy * head * 0.7,
        )
        ..close(),
      Paint()..color = style.accent.withValues(alpha: 0.9 * opacity),
    );
    if (opacity < 0.5 || !detail) return;
    final mid = (qiblaBearing / 2 - 90) * math.pi / 180;
    final at = Offset(math.cos(mid), math.sin(mid)) * (r * 0.32);
    final tp = TextPainter(
      text: TextSpan(
        text: style.degreeLabel(qiblaBearing),
        style: TextStyle(
          fontFamily: style.numeralFamily,
          fontSize: r * 0.075,
          fontWeight: FontWeight.w700,
          color: style.accent,
          shadows: [Shadow(color: _p.enamelEdge, blurRadius: r * 0.03)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  // ---------------------------------------------------------------- needle

  /// The golden needle along −y: a faceted lozenge to the qibla, a short
  /// tail ending in a crescent.
  void _needle(Canvas canvas, double r, double g) {
    final tipY = -r * QiblaDialGeometry.needleTip;
    final tailY = r * QiblaDialGeometry.needleTail;
    final paths = engraving.pathsFor(r);
    final lit = paths.needleLit;
    final shade = paths.needleShade;
    final whole = paths.needleWhole;
    final crescent = paths.crescent;
    final o = needleOpacity.clamp(0.0, 1.0);

    // Shadow cast on the plate.
    canvas.drawPath(
      paths.needleShadow,
      Paint()
        ..color = _p.shadow.withValues(alpha: 0.55 * o)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.014),
    );
    if (g > 0) {
      canvas.drawPath(
        whole,
        Paint()
          ..color = style.accentGlow.withValues(alpha: 0.8 * g * o)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.045),
      );
    }
    final goldHi = Color.lerp(style.gold, _p.brassHi, 0.55)!;
    canvas
      ..drawPath(
        lit,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, tipY),
            Offset(0, tailY),
            [
              Color.lerp(goldHi, style.accentGlow, 0.25 * g)!.withValues(alpha: o),
              style.gold.withValues(alpha: o),
              _p.brass.withValues(alpha: o),
            ],
            const [0, 0.5, 1],
          ),
      )
      ..drawPath(
        shade,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, tipY),
            Offset(0, tailY),
            [style.gold.withValues(alpha: o), _p.brass.withValues(alpha: o), _p.brassLow.withValues(alpha: o)],
            const [0, 0.5, 1],
          ),
      )
      ..drawPath(crescent, Paint()..color = style.gold.withValues(alpha: o))
      ..drawPath(
        whole,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.miter
          ..strokeWidth = math.max(0.6, r * 0.005)
          ..color = _p.ink.withValues(alpha: 0.75 * o),
      )
      ..drawLine(
        Offset(0, tipY + r * 0.02),
        Offset(0, tailY - r * 0.02),
        Paint()
          ..strokeWidth = math.max(0.5, r * 0.003)
          ..color = _p.engraveHi.withValues(alpha: 0.6 * o),
      );
  }

  void _hub(Canvas canvas, Offset c, double r) {
    final hr = r * QiblaDialGeometry.hub;
    canvas
      ..drawCircle(
        c + Offset(r * 0.008, r * 0.014),
        hr,
        Paint()
          ..color = _p.shadow.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.012),
      )
      ..save()
      ..translate(c.dx, c.dy)
      ..drawCircle(Offset.zero, hr, _brass(r, _screenLight, 0))
      ..drawCircle(
        Offset.zero,
        hr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, r * 0.005)
          ..color = _p.ink.withValues(alpha: 0.8),
      )
      // The jewel.
      ..drawCircle(
        Offset.zero,
        hr * 0.46,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(-hr * 0.15, -hr * 0.15),
            hr * 0.6,
            [
              Color.lerp(style.accent, Colors.white, 0.35)!,
              style.accent,
              Color.lerp(style.accent, _p.enamelEdge, 0.6)!,
            ],
            const [0, 0.5, 1],
          ),
      )
      ..drawCircle(Offset(-hr * 0.14, -hr * 0.16), hr * 0.1, Paint()..color = Colors.white.withValues(alpha: 0.7))
      ..restore();
  }

  // ----------------------------------------------------------------- kursi

  /// The throne above the limb with its shackle ring, and the index that
  /// marks the direction the phone points.
  void _kursi(Canvas canvas, double r, double g) {
    final paths = engraving.pathsFor(r);
    final body = paths.kursiBody;
    final cut = paths.kursiCut;

    if (g > 0) {
      // A soft bloom over the top of the limb: the qibla is ahead.
      final bloomC = Offset(0, -r * 0.93);
      canvas
        ..drawCircle(
          bloomC,
          r * 0.5,
          Paint()
            ..shader = ui.Gradient.radial(
              bloomC,
              r * 0.5,
              [
                style.accentGlow.withValues(alpha: 0.42 * g),
                style.accentGlow.withValues(alpha: 0.12 * g),
                style.accentGlow.withValues(alpha: 0),
              ],
              const [0, 0.45, 1],
            ),
        )
        ..drawPath(
          body,
          Paint()
            ..color = style.accentGlow.withValues(alpha: 0.7 * g)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06),
        );
    }
    canvas
      ..drawPath(
        body.shift(Offset(0, r * 0.012)),
        Paint()
          ..color = _p.shadow.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.01),
      )
      ..drawPath(body, _brass(r, _screenLight, 0.05))
      ..drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, r * 0.005)
          ..color = _p.ink.withValues(alpha: 0.8),
      )
      // Enamel behind the pierced star; lit gold when aligned.
      ..drawPath(cut, Paint()..color = Color.lerp(_p.enamelMid, style.accentGlow, g)!);

    // The index: a gold wedge over the scale at 12 o'clock.
    final idx = paths.index;
    if (g > 0) {
      canvas.drawPath(
        idx,
        Paint()
          ..color = style.accentGlow.withValues(alpha: 0.9 * g)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.03),
      );
    }
    canvas
      ..drawPath(idx, Paint()..color = Color.lerp(style.gold, style.accentGlow, g)!)
      ..drawPath(
        idx,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, r * 0.005)
          ..color = _p.ink.withValues(alpha: 0.8),
      );
  }

  // ----------------------------------------------------------------- arrow

  /// Far off: a curved arrow around the rim from "ahead" toward the qibla
  /// (physical right / left – never mirrored for RTL).
  void _arrow(Canvas canvas, Offset c, double r, double needleDeg) {
    final turn = ((needleDeg % 360) + 360) % 360;
    final signed = turn > 180 ? turn - 360 : turn;
    final strength = ((signed.abs() - 15) / 10).clamp(0.0, 1.0);
    if (strength <= 0) return;
    final dirSign = signed.sign;
    final span = math.min(signed.abs(), 70.0) * math.pi / 180;
    final start = -math.pi / 2 + dirSign * 16 * math.pi / 180;
    final sweep = dirSign * (span - 12 * math.pi / 180).clamp(8 * math.pi / 180, math.pi);
    final rr = r * 1.09;
    final rect = Rect.fromCircle(center: c, radius: rr);
    final color = style.accent.withValues(alpha: 0.9 * strength);
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, r * 0.022)
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.sweep(
          c,
          [color.withValues(alpha: 0), color],
          null,
          TileMode.clamp,
          math.min(start, start + sweep),
          math.max(start, start + sweep),
        ),
    );
    final end = start + sweep;
    final tip = c + Offset(math.cos(end), math.sin(end)) * rr;
    final tangent = Offset(-math.sin(end), math.cos(end)) * dirSign;
    final normal = Offset(math.cos(end), math.sin(end));
    final head = r * 0.06;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx + tangent.dx * head, tip.dy + tangent.dy * head)
        ..lineTo(tip.dx + normal.dx * head * 0.62, tip.dy + normal.dy * head * 0.62)
        ..lineTo(tip.dx - normal.dx * head * 0.62, tip.dy - normal.dy * head * 0.62)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(QiblaDialPainter old) =>
      old.style != style ||
      old.kind != kind ||
      old.qiblaBearing != qiblaBearing ||
      old.sunAzimuth != sunAzimuth ||
      old.brass != brass ||
      old.devicePixelRatio != devicePixelRatio ||
      old.showArrow != showArrow ||
      old.needleOpacity != needleOpacity ||
      old.dial != dial ||
      old.needle != needle ||
      old.glow != glow ||
      old.tilt != tilt;
}
