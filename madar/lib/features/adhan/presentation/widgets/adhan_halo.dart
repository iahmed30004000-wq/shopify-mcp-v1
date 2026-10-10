import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/painters/painters.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/ambient_motion.dart';
import '../../../../core/motion/motion.dart';

/// The adhan screen's hero: a brass astrolabe of the day assembling itself
/// around a golden glow – a 24-hour limb (noon at the top), a slowly turning
/// girih rete, the day's prayers as small stars on the inner ring and the
/// announced one blazing on the limb. While the adhan sounds, rings of light
/// ripple outward.
class AdhanHalo extends StatefulWidget {
  const AdhanHalo({
    super.key,
    required this.at,
    this.dayTimes = const [],
    this.size = 280,
    this.sounding = false,
    this.dim = false,
  });

  /// The announced moment (wall clock of the location).
  final DateTime at;

  /// The day's other prayer times (wall clock), drawn as small stars.
  final List<DateTime> dayTimes;
  final double size;

  /// Ripples of light while the adhan sounds.
  final bool sounding;

  /// A quieter look (reminders, sunrise).
  final bool dim;

  /// Angle (radians, clockwise from the top) of a time of day on the 24-hour
  /// limb: noon at the top, midnight at the bottom.
  static double angleOf(DateTime t) {
    final fraction = (t.hour * 3600 + t.minute * 60 + t.second) / 86400.0;
    return (fraction - 0.5) * 2 * math.pi;
  }

  @override
  State<AdhanHalo> createState() => _AdhanHaloState();
}

class _AdhanHaloState extends State<AdhanHalo> with TickerProviderStateMixin {
  late final AnimationController _assemble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 36));

  /// Built once: a `CurvedAnimation` registers a status listener on its
  /// parent until disposed, so one per build would leak.
  late final CurvedAnimation _assembleCurve = CurvedAnimation(parent: _assemble, curve: MadarMotion.decelerate);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = context.reducedMotion;
    if (!_started) {
      _started = true;
      if (reduced) {
        _assemble.value = 1;
      } else {
        _assemble.forward();
      }
    }
    final ambient = AmbientMotion.enabled && AmbientMotionScope.enabledOf(context) && !reduced;
    if (ambient && !_ambient.isAnimating) {
      _ambient.repeat();
    } else if (!ambient && _ambient.isAnimating) {
      _ambient.stop();
    }
  }

  @override
  void dispose() {
    _assembleCurve.dispose();
    _assemble.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: _HaloPainter(
              tokens: t,
              assemble: _assembleCurve,
              ambient: _ambient,
              at: widget.at,
              dayTimes: widget.dayTimes,
              sounding: widget.sounding,
              dim: widget.dim,
            ),
          ),
        ),
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({
    required this.tokens,
    required this.assemble,
    required this.ambient,
    required this.at,
    required this.dayTimes,
    required this.sounding,
    required this.dim,
  }) : super(repaint: Listenable.merge([assemble, ambient]));

  final MadarTokens tokens;
  final Animation<double> assemble;
  final Animation<double> ambient;
  final DateTime at;
  final List<DateTime> dayTimes;
  final bool sounding;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tokens;
    final a = assemble.value.clamp(0.0, 1.0);
    final phase = ambient.value; // 0..1 over 36 s
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final light = !t.isDark;
    final metal = light ? t.brass : t.gold;
    final breathe = 0.5 + 0.5 * math.sin(phase * 2 * math.pi * 9); // 4 s breath

    // Glow: a warm bloom reaching past the instrument ----------------------
    final glowStrength = (dim ? 0.5 : 0.9) * a * (0.82 + 0.18 * breathe);
    final bloomR = r * 1.45;
    canvas.drawCircle(
      c,
      bloomR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            t.accentGlow.withValues(alpha: 0.5 * glowStrength),
            t.gold.withValues(alpha: 0.16 * glowStrength),
            t.gold.withValues(alpha: 0.05 * glowStrength),
            t.gold.withValues(alpha: 0),
          ],
          stops: const [0, 0.32, 0.62, 1],
        ).createShader(Rect.fromCircle(center: c, radius: bloomR)),
    );

    // Ripples of light leaving the limb while the adhan sounds -------------
    if (sounding && a > 0.6) {
      for (var i = 0; i < 3; i++) {
        final p = (phase * 12 + i / 3) % 1.0; // one ring a second, 3 s life
        final rr = r * (0.9 + 0.5 * p);
        final fade = (1 - p) * (1 - p) * ((a - 0.6) / 0.4);
        canvas.drawCircle(
          c,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 + 2.2 * (1 - p)
            ..color = metal.withValues(alpha: 0.42 * fade),
        );
      }
    }

    // Outer limb: a 24-hour scale (a tick every 20 min, hours, 6-hour marks).
    final limbR = r * 0.86 * (0.92 + 0.08 * a);
    final limbTurn = (1 - a) * -0.7;
    canvas.save();
    AstrolabeTicksPainter.paintScale(
      canvas,
      center: c,
      radius: limbR,
      color: metal.withValues(alpha: 0.55 * a),
      majorColor: metal.withValues(alpha: 0.95 * a),
      minorStep: 5,
      midStep: 15,
      majorStep: 90,
      showNumerals: false,
      rotation: limbTurn,
      ringWidth: math.max(1.2, r * 0.012),
    );
    canvas.restore();

    // Inner ring (the plate) and its hour marks.
    final plateR = limbR * 0.74;
    final plate = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, r * 0.006)
      ..color = metal.withValues(alpha: 0.45 * a);
    canvas.drawCircle(c, plateR, plate);
    canvas.drawCircle(c, plateR * 1.04, plate..color = metal.withValues(alpha: 0.22 * a));

    // Rete: a girih rosette turning slowly the other way.
    final reteA = ((a - 0.15) / 0.85).clamp(0.0, 1.0);
    if (reteA > 0) {
      final reteSize = plateR * 1.62;
      canvas.save();
      canvas.translate(c.dx - reteSize / 2, c.dy - reteSize / 2);
      GirihRosettePainter(
        folds: 12,
        strandColor: metal.withValues(alpha: 0.5 * reteA),
        strandInnerColor: t.starTint.withValues(alpha: (light ? 0.35 : 0.22) * reteA),
        ringColor: metal.withValues(alpha: 0.3 * reteA),
        rotation: (1 - reteA) * 1.1 + phase * 2 * math.pi,
      ).paint(canvas, Size.square(reteSize));
      canvas.restore();
    }

    // The day's prayers on the plate.
    for (final d in dayTimes) {
      final ang = AdhanHalo.angleOf(d) + limbTurn;
      final p = c + Offset(math.sin(ang), -math.cos(ang)) * plateR;
      final lit = d.hour == at.hour && d.minute == at.minute;
      if (lit) continue;
      canvas.save();
      canvas.translate(p.dx - 6, p.dy - 6);
      IslamicStarPainter(
        fillColor: metal.withValues(alpha: 0.7 * reteA),
        strokeColor: null,
        rotation: ang,
      ).paint(canvas, const Size.square(12));
      canvas.restore();
    }

    // The announced moment: a pointer from the centre and a blazing star on
    // the limb.
    final markerA = ((a - 0.45) / 0.55).clamp(0.0, 1.0);
    if (markerA > 0) {
      final ang = AdhanHalo.angleOf(at) + limbTurn;
      final dir = Offset(math.sin(ang), -math.cos(ang));
      final tip = c + dir * limbR * 0.98;
      canvas.drawLine(
        c + dir * plateR * 0.18,
        tip,
        Paint()
          ..shader = LinearGradient(
            colors: [
              metal.withValues(alpha: 0),
              metal.withValues(alpha: 0.9 * markerA),
            ],
          ).createShader(Rect.fromPoints(c, tip))
          ..strokeWidth = math.max(1.4, r * 0.012)
          ..strokeCap = StrokeCap.round,
      );
      final starR = r * (0.085 + 0.012 * breathe) * (0.6 + 0.4 * markerA);
      canvas.drawCircle(
        tip,
        starR * 2.6,
        Paint()
          ..shader = RadialGradient(
            colors: [
              t.accentGlow.withValues(alpha: 0.9 * markerA),
              t.accentGlow.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: tip, radius: starR * 2.6)),
      );
      canvas.save();
      canvas.translate(tip.dx - starR, tip.dy - starR);
      IslamicStarPainter(
        fillGradient: [t.starTint, t.gold],
        strokeColor: light ? t.brassDark : t.brass,
        strokeWidth: 1,
        rotation: ang,
        glowColor: t.accentGlow.withValues(alpha: 0.8 * markerA),
        glowSigma: 8,
        centerDotColor: light ? t.brassDark : t.space1,
      ).paint(canvas, Size.square(starR * 2));
      canvas.restore();
    }

    // Hub.
    canvas.drawCircle(c, r * 0.05 * a, Paint()..color = metal.withValues(alpha: 0.9 * a));
    canvas.drawCircle(c, r * 0.022 * a, Paint()..color = light ? t.space0 : t.space1);
  }

  @override
  bool shouldRepaint(_HaloPainter old) =>
      old.tokens != tokens ||
      old.at != at ||
      old.sounding != sounding ||
      old.dim != dim ||
      !_sameTimes(old.dayTimes, dayTimes);

  static bool _sameTimes(List<DateTime> a, List<DateTime> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
