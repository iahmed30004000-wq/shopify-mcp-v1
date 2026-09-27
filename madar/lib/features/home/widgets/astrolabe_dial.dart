import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/painters/painters.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/motion/motion.dart';
import '../domain/prayer_day.dart';

/// Pure geometry of the 24-hour astrolabe dial: noon at the top, midnight at
/// the bottom, time running clockwise (like the rete of an astrolabe
/// following the sun).
abstract final class DialGeometry {
  /// Canvas angle (radians, 0 = +x, clockwise positive) of a time of day.
  static double angleOf(Duration sinceMidnight) =>
      2 * math.pi * PrayerDayTimes.dialFraction(sinceMidnight) - 1.5 * math.pi;

  /// Pushes sorted [angles] apart so neighbours are at least the matching
  /// [minGaps] apart (radians; `minGaps[i]` is the gap needed between
  /// label i and i+1), keeping the group centred where it was. Used to keep
  /// close prayer labels (Maghrib / Isha) from overlapping.
  static List<double> spread(List<double> angles, List<double> minGaps, {int iterations = 24}) {
    final a = List<double>.of(angles);
    for (var it = 0; it < iterations; it++) {
      var moved = false;
      for (var i = 0; i + 1 < a.length; i++) {
        final need = minGaps[i];
        final gap = a[i + 1] - a[i];
        if (gap < need) {
          final push = (need - gap) / 2;
          a[i] -= push;
          a[i + 1] += push;
          moved = true;
        }
      }
      if (!moved) break;
    }
    return a;
  }
}

/// A label on the dial (a prayer or sunrise).
@immutable
class DialMark {
  const DialMark({required this.at, required this.label, this.isPrayer = true});

  /// Offset from midnight.
  final Duration at;
  final String label;

  /// Prayers get an eight-point star; sunrise a small open circle.
  final bool isPrayer;

  @override
  bool operator ==(Object other) =>
      other is DialMark && other.at == at && other.label == label && other.isPrayer == isPrayer;

  @override
  int get hashCode => Object.hash(at, label, isPrayer);
}

/// The home screen's 2D astrolabe (Phase 0 stand-in for the living orbit):
/// a brass 24-hour ring, the six prayer windows as engraved arcs (the one
/// in focus glowing in the accent), prayer stars, a sun marker with the
/// rete's pointer at "now", and a slowly turning girih rete behind the
/// centre. Only the rete moves continuously (ambient; off under reduced
/// motion, battery saver and when TickerMode is off); the dial itself
/// repaints once a minute.
class AstrolabeDial extends StatefulWidget {
  const AstrolabeDial({
    super.key,
    required this.times,
    required this.now,
    required this.focused,
    required this.marks,
    this.animate = true,
    this.center,
    this.size = 300,
  });

  final PrayerDayTimes times;
  final DateTime now;
  final PrayerWindow focused;
  final List<DialMark> marks;
  final bool animate;
  final Widget? center;
  final double size;

  @override
  State<AstrolabeDial> createState() => _AstrolabeDialState();
}

class _AstrolabeDialState extends State<AstrolabeDial> with SingleTickerProviderStateMixin {
  late final AnimationController _rete = AnimationController(vsync: this, duration: const Duration(seconds: 180));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(AstrolabeDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncLoop();
  }

  void _syncLoop() {
    final run = widget.animate && AmbientMotion.enabled && !context.reducedMotion;
    if (run && !_rete.isAnimating) {
      _rete.repeat();
    } else if (!run && _rete.isAnimating) {
      _rete.stop();
    }
  }

  @override
  void dispose() {
    _rete.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = widget.size;
    final nowOffset = PrayerDayTimes.sinceMidnight(widget.now);
    return SizedBox.square(
      dimension: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Turning girih rete (cached raster, only its transform changes).
          RotationTransition(
            turns: _rete,
            child: RepaintBoundary(
              child: Opacity(
                opacity: t.isDark ? 0.1 : 0.14,
                child: GirihRosette(size: s * 0.56, folds: 12),
              ),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              size: Size.square(s),
              painter: AstrolabeDialPainter(
                times: widget.times,
                now: nowOffset,
                focused: widget.focused,
                marks: widget.marks,
                brass: t.brass,
                gold: t.gold,
                accent: t.accent,
                accentGlow: t.accentGlow,
                ink: t.textSecondary,
                faint: t.textTertiary,
                sun: t.starTint,
                night: t.space0,
                textDirection: Directionality.of(context),
              ),
            ),
          ),
          if (widget.center != null)
            SizedBox.square(
              dimension: s * 0.5,
              child: Center(child: widget.center),
            ),
        ],
      ),
    );
  }
}

/// Paints the static part of [AstrolabeDial].
class AstrolabeDialPainter extends CustomPainter {
  const AstrolabeDialPainter({
    required this.times,
    required this.now,
    required this.focused,
    required this.marks,
    required this.brass,
    required this.gold,
    required this.accent,
    required this.accentGlow,
    required this.ink,
    required this.faint,
    required this.sun,
    required this.night,
    required this.textDirection,
  });

  final PrayerDayTimes times;
  final Duration now;
  final PrayerWindow focused;
  final List<DialMark> marks;
  final Color brass, gold, accent, accentGlow, ink, faint, sun, night;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // Brass hour ring: a tick every 20 min, every hour, every 3 hours.
    AstrolabeTicksPainter.paintScale(
      canvas,
      center: c,
      radius: r,
      color: brass,
      majorColor: gold,
      minorStep: 5,
      midStep: 15,
      majorStep: 45,
      showNumerals: false,
    );
    final track = r * 0.6;
    final band = r * 0.05;

    // Daylight band (sunrise → maghrib) and night band.
    final dayStart = DialGeometry.angleOf(times.sunrise);
    final dayEnd = DialGeometry.angleOf(times.maghrib);
    final bandRect = Rect.fromCircle(center: c, radius: track);
    canvas.drawArc(
      bandRect,
      dayStart,
      _sweep(dayStart, dayEnd),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = band * 3.2
        ..color = gold.withValues(alpha: 0.07),
    );
    canvas.drawArc(
      bandRect,
      dayEnd,
      _sweep(dayEnd, dayStart),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = band * 3.2
        ..color = night.withValues(alpha: 0.28),
    );

    // Window arcs.
    const gap = 0.022;
    for (final w in PrayerDayTimes.windows) {
      final a0 = DialGeometry.angleOf(times.startOf(w)) + gap;
      final a1 = DialGeometry.angleOf(times.endOf(w)) - gap;
      final sweep = _sweep(a0, a1);
      final isFocused = w == focused;
      if (isFocused) {
        canvas.drawArc(
          bandRect,
          a0,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = band * 2.2
            ..color = accentGlow.withValues(alpha: accentGlow.a * 0.55)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, band * 1.4),
        );
      }
      canvas.drawArc(
        bandRect,
        a0,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = isFocused ? band : band * 0.55
          ..color = isFocused ? accent : brass.withValues(alpha: 0.55),
      );
    }

    // Prayer stars / sunrise circle on the track, labels inside it.
    // Labels ride outside the track, inside the brass hour ring.
    final labelR = track + band * 2.2 + r * 0.075;
    final sorted = [...marks]..sort((a, b) => a.at.compareTo(b.at));
    final painters = [
      for (final m in sorted)
        TextPainter(
          text: TextSpan(
            text: m.label,
            style: TextStyle(
              fontFamily: MadarTypography.uiFamily,
              fontSize: (r * 0.072).clamp(9.0, 12.5),
              fontWeight: FontWeight.w500,
              color: m.isPrayer ? ink : faint,
              height: 1,
            ),
          ),
          textDirection: textDirection,
        )..layout(),
    ];
    final angles = [for (final m in sorted) DialGeometry.angleOf(m.at)];
    final gaps = [
      for (var i = 0; i + 1 < painters.length; i++)
        _angularGap(painters[i], painters[i + 1], angles[i], angles[i + 1], labelR),
    ];
    final spread = DialGeometry.spread(angles, gaps);
    for (var i = 0; i < sorted.length; i++) {
      final m = sorted[i];
      final a = angles[i];
      final p = c + Offset(math.cos(a), math.sin(a)) * track;
      if (m.isPrayer) {
        final star = IslamicGeometry.starPath(center: p, radius: band * 1.35);
        canvas.drawPath(
          star,
          Paint()
            ..color = gold.withValues(alpha: 0.6)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, band * 0.8),
        );
        canvas.drawPath(star, Paint()..color = gold);
      } else {
        canvas.drawCircle(
          p,
          band * 0.8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = gold.withValues(alpha: 0.8),
        );
      }
      final la = spread[i];
      final lp = c + Offset(math.cos(la), math.sin(la)) * labelR;
      final tp = painters[i];
      tp.paint(canvas, lp - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }

    // The rete's pointer (an alidade arm outside the centre text) and the
    // sun at "now".
    final na = DialGeometry.angleOf(now);
    final dir = Offset(math.cos(na), math.sin(na));
    final normal = Offset(-dir.dy, dir.dx);
    final base = c + dir * (r * 0.47);
    final tip = c + dir * (track - band * 1.9);
    final w = r * 0.016;
    final pointer = Path()
      ..moveTo((base + normal * w).dx, (base + normal * w).dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo((base - normal * w).dx, (base - normal * w).dy)
      ..close();
    canvas.drawPath(pointer, Paint()..color = brass.withValues(alpha: 0.9));
    canvas.drawPath(
      pointer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = gold.withValues(alpha: 0.9),
    );
    canvas.drawCircle(base, w * 1.4, Paint()..color = gold);

    final sunP = c + dir * track;
    canvas.drawCircle(
      sunP,
      band * 2.6,
      Paint()
        ..color = accentGlow.withValues(alpha: accentGlow.a * 0.8)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, band * 1.8),
    );
    canvas.drawCircle(sunP, band * 1.05, Paint()..color = sun);
    canvas.drawCircle(
      sunP,
      band * 1.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent,
    );
  }

  static double _sweep(double a0, double a1) {
    var s = a1 - a0;
    while (s <= 0) {
      s += 2 * math.pi;
    }
    return s;
  }

  /// Angle two labels need between their centres so their boxes clear.
  static double _angularGap(TextPainter a, TextPainter b, double angleA, double angleB, double radius) {
    final mid = (angleA + angleB) / 2;
    // Tangential extent of each box at this angle.
    double extent(TextPainter p) => (p.width / 2) * math.sin(mid).abs() + (p.height / 2) * math.cos(mid).abs();
    return (extent(a) + extent(b) + 6) / radius;
  }

  @override
  bool shouldRepaint(AstrolabeDialPainter old) =>
      old.times != times ||
      old.now.inMinutes != now.inMinutes ||
      old.focused != focused ||
      !_listEquals(old.marks, marks) ||
      old.brass != brass ||
      old.gold != gold ||
      old.accent != accent ||
      old.accentGlow != accentGlow ||
      old.ink != ink ||
      old.faint != faint ||
      old.sun != sun ||
      old.night != night ||
      old.textDirection != textDirection;

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
