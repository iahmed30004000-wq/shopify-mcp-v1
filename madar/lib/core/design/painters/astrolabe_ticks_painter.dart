import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum AstrolabeTickKind { minor, mid, major }

@immutable
class AstrolabeTick {
  const AstrolabeTick(this.degrees, this.kind);

  /// 0° at the top, increasing clockwise (the limb scale of an astrolabe).
  final int degrees;
  final AstrolabeTickKind kind;

  @override
  bool operator ==(Object other) => other is AstrolabeTick && other.degrees == degrees && other.kind == kind;

  @override
  int get hashCode => Object.hash(degrees, kind);

  @override
  String toString() => 'AstrolabeTick($degrees°, ${kind.name})';
}

/// Pure layout of the degree scale and numeral formatting (unit-tested).
abstract final class AstrolabeScale {
  static const _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';

  /// Every tick of a full 360° ring. Steps must nest: [majorStep] is a
  /// multiple of [midStep], which is a multiple of [minorStep], and 360 is a
  /// multiple of [minorStep].
  static List<AstrolabeTick> ticks({int minorStep = 2, int midStep = 10, int majorStep = 30}) {
    assert(minorStep > 0 && 360 % minorStep == 0, 'minorStep must divide 360');
    assert(midStep % minorStep == 0 && majorStep % midStep == 0, 'steps must nest');
    return [
      for (var d = 0; d < 360; d += minorStep)
        AstrolabeTick(
          d,
          d % majorStep == 0
              ? AstrolabeTickKind.major
              : d % midStep == 0
                  ? AstrolabeTickKind.mid
                  : AstrolabeTickKind.minor,
        ),
    ];
  }

  /// Replaces ASCII digits with Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩).
  static String toArabicIndic(String input) {
    final out = StringBuffer();
    for (final unit in input.codeUnits) {
      if (unit >= 0x30 && unit <= 0x39) {
        out.write(_arabicIndicDigits[unit - 0x30]);
      } else {
        out.writeCharCode(unit);
      }
    }
    return out.toString();
  }

  /// Formats a scale numeral.
  static String numeral(int value, {bool arabicIndic = true}) =>
      arabicIndic ? toArabicIndic('$value') : '$value';

  /// Angle in radians (canvas space, 0 = +x) for a scale reading.
  static double radiansFor(num degrees, {double rotation = 0}) =>
      (degrees - 90) * math.pi / 180 + rotation;
}

/// A brass astrolabe degree ring: outer ring, major/mid/minor ticks and
/// optional (Arabic-Indic) numerals engraved tangentially. Vector only.
class AstrolabeTicksPainter extends CustomPainter {
  const AstrolabeTicksPainter({
    required this.color,
    this.majorColor,
    this.numeralColor,
    this.minorStep = 2,
    this.midStep = 10,
    this.majorStep = 30,
    this.showNumerals = true,
    this.arabicIndic = true,
    this.fontFamily,
    this.rotation = 0,
    this.ringWidth,
    this.innerRing = true,
  });

  final Color color;
  final Color? majorColor;
  final Color? numeralColor;
  final int minorStep;
  final int midStep;
  final int majorStep;
  final bool showNumerals;
  final bool arabicIndic;
  final String? fontFamily;

  /// Clockwise rotation of the whole ring in radians.
  final double rotation;
  final double? ringWidth;
  final bool innerRing;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    paintScale(
      canvas,
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2,
      color: color,
      majorColor: majorColor,
      numeralColor: numeralColor,
      minorStep: minorStep,
      midStep: midStep,
      majorStep: majorStep,
      showNumerals: showNumerals,
      arabicIndic: arabicIndic,
      fontFamily: fontFamily,
      rotation: rotation,
      ringWidth: ringWidth,
      innerRing: innerRing,
    );
  }

  /// Paints the scale; shared with the astrolabe empty-state illustration.
  static void paintScale(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    Color? majorColor,
    Color? numeralColor,
    int minorStep = 2,
    int midStep = 10,
    int majorStep = 30,
    bool showNumerals = true,
    bool arabicIndic = true,
    String? fontFamily,
    double rotation = 0,
    double? ringWidth,
    bool innerRing = true,
  }) {
    final rw = ringWidth ?? math.max(0.8, radius * 0.018);
    final outerR = radius - rw / 2;
    final ring = Paint()
      ..color = majorColor ?? color
      ..style = PaintingStyle.stroke
      ..strokeWidth = rw;
    canvas.drawCircle(center, outerR, ring);

    final minorLen = radius * 0.045;
    final midLen = radius * 0.075;
    final majorLen = radius * 0.12;
    final tickStart = outerR - rw / 2 - radius * 0.012;
    final minorPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.75)
      ..strokeWidth = math.max(0.5, radius * 0.008)
      ..strokeCap = StrokeCap.round;
    final midPaint = Paint()
      ..color = color
      ..strokeWidth = math.max(0.7, radius * 0.012)
      ..strokeCap = StrokeCap.round;
    final majorPaint = Paint()
      ..color = majorColor ?? color
      ..strokeWidth = math.max(0.9, radius * 0.018)
      ..strokeCap = StrokeCap.round;

    for (final tick in AstrolabeScale.ticks(minorStep: minorStep, midStep: midStep, majorStep: majorStep)) {
      final a = AstrolabeScale.radiansFor(tick.degrees, rotation: rotation);
      final dir = Offset(math.cos(a), math.sin(a));
      final (len, paint) = switch (tick.kind) {
        AstrolabeTickKind.minor => (minorLen, minorPaint),
        AstrolabeTickKind.mid => (midLen, midPaint),
        AstrolabeTickKind.major => (majorLen, majorPaint),
      };
      canvas.drawLine(center + dir * tickStart, center + dir * (tickStart - len), paint);
    }

    final innerR = tickStart - majorLen - radius * 0.02;
    if (innerRing) {
      canvas.drawCircle(
        center,
        innerR,
        Paint()
          ..color = color.withValues(alpha: color.a * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.5, rw * 0.5),
      );
    }

    if (!showNumerals) return;
    final fontSize = (radius * 0.085).clamp(6.0, 15.0);
    final labelR = innerR - fontSize * 0.95;
    if (labelR <= fontSize) return;
    for (var d = 0; d < 360; d += majorStep) {
      final painter = TextPainter(
        text: TextSpan(
          text: AstrolabeScale.numeral(d, arabicIndic: arabicIndic),
          style: TextStyle(
            color: numeralColor ?? majorColor ?? color,
            fontSize: fontSize,
            fontFamily: fontFamily,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final a = AstrolabeScale.radiansFor(d, rotation: rotation);
      canvas.save();
      canvas.translate(center.dx + math.cos(a) * labelR, center.dy + math.sin(a) * labelR);
      // Engraved tangentially: the glyph tops face outward.
      canvas.rotate(a + math.pi / 2);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(AstrolabeTicksPainter old) =>
      old.color != color ||
      old.majorColor != majorColor ||
      old.numeralColor != numeralColor ||
      old.minorStep != minorStep ||
      old.midStep != midStep ||
      old.majorStep != majorStep ||
      old.showNumerals != showNumerals ||
      old.arabicIndic != arabicIndic ||
      old.fontFamily != fontFamily ||
      old.rotation != rotation ||
      old.ringWidth != ringWidth ||
      old.innerRing != innerRing;
}
