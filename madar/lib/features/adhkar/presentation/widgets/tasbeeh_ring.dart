import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../domain/tasbeeh.dart';

/// Colours of the bead ring (from the theme tokens): dim brass beads that
/// light up in the theme accent in the dark themes; ivory pearls that turn
/// gold in Pearl.
@immutable
class TasbeehRingPalette {
  const TasbeehRingPalette({
    required this.unlit,
    required this.unlitEdge,
    required this.lit,
    required this.litEdge,
    required this.litGlow,
    required this.gold,
    required this.brassDark,
    required this.string,
    required this.highlight,
  });

  factory TasbeehRingPalette.of(MadarTokens t) {
    final lit = t.isDark ? t.accent : Color.lerp(t.accentGlow.withValues(alpha: 1), t.accent, 0.3)!;
    return TasbeehRingPalette(
      unlit: t.isDark ? Color.lerp(t.brassDark, t.brass, 0.55)! : Color.lerp(t.space1, t.space3, 0.45)!,
      unlitEdge: t.isDark ? Color.lerp(t.brassDark, t.space0, 0.35)! : Color.lerp(t.space3, t.brass, 0.5)!,
      lit: lit,
      litEdge: Color.lerp(lit, t.brassDark, 0.5)!,
      litGlow: t.accentGlow,
      gold: t.gold,
      brassDark: t.brassDark,
      string: t.brass.withValues(alpha: t.isDark ? 0.55 : 0.6),
      highlight: t.isDark ? t.glassHighlight.withValues(alpha: 1) : const Color(0xFFFFFFFF),
    );
  }

  final Color unlit, unlitEdge, lit, litEdge, litGlow, gold, brassDark, string, highlight;

  @override
  bool operator ==(Object other) =>
      other is TasbeehRingPalette &&
      other.unlit == unlit &&
      other.unlitEdge == unlitEdge &&
      other.lit == lit &&
      other.litEdge == litEdge &&
      other.litGlow == litGlow &&
      other.gold == gold &&
      other.string == string &&
      other.highlight == highlight;

  @override
  int get hashCode => Object.hash(unlit, unlitEdge, lit, litEdge, litGlow, gold, string, highlight);
}

/// Geometry of the ring (pure, for the painter and tests).
abstract final class TasbeehRingGeometry {
  /// Bead radius for [beads] beads on a ring of radius [ringRadius].
  static double beadRadius(int beads, double ringRadius) =>
      math.min(12.5, math.pi * ringRadius / beads * 0.74).clamp(1.8, 12.5);

  /// Angle of bead [i] when the ring has advanced [position] beads (the
  /// bead at [position] sits at the top). Beads flow toward the reading
  /// start: counter-clockwise in LTR, clockwise in RTL.
  static double angleOf(int i, double position, int beads, TextDirection dir) {
    final step = 2 * math.pi / beads;
    final sign = dir == TextDirection.rtl ? -1.0 : 1.0;
    return -math.pi / 2 + sign * (i - position) * step;
  }

  /// Separator beads (a third and two thirds of the way round), as on a
  /// 33- or 99-bead misbaha.
  static Set<int> separators(int beads) => beads >= 30 && beads % 3 == 0 ? {beads ~/ 3, 2 * beads ~/ 3} : const {};
}

/// The cinematic tasbeeh ring: [TasbeehCounter.beads] beads on a brass
/// string; each tap springs the ring one bead on (the counted bead lights
/// up as it passes the gold marker at the top); a completed round sends a
/// pulse around the ring. Under reduced motion the ring snaps.
class TasbeehBeadRing extends StatefulWidget {
  const TasbeehBeadRing({super.key, required this.counter, required this.size, this.child});

  final TasbeehCounter counter;
  final double size;

  /// Shown in the middle (count, phrase …).
  final Widget? child;

  @override
  State<TasbeehBeadRing> createState() => _TasbeehBeadRingState();
}

class _TasbeehBeadRingState extends State<TasbeehBeadRing> with TickerProviderStateMixin {
  late final SpringValue _position = SpringValue(
    vsync: this,
    value: _target(widget.counter),
    spring: SpringDescription.withDampingRatio(mass: 1, stiffness: 340, ratio: 0.72),
    tolerance: MadarSprings.unit,
  );
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
  final _BeadsRecording _recording = _BeadsRecording();

  static double _target(TasbeehCounter c) => c.count * c.beads / c.target;

  @override
  void didUpdateWidget(TasbeehBeadRing old) {
    super.didUpdateWidget(old);
    final c = widget.counter;
    final reduced = context.reducedMotion;
    if (c.target != old.counter.target || c.count < old.counter.count || reduced) {
      _position.jumpTo(_target(c));
    } else if (c.count != old.counter.count) {
      _position.animateTo(_target(c));
    }
    if (c.count > old.counter.count && c.roundJustCompleted && c.target == old.counter.target && !reduced) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _pulse.dispose();
    _recording.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _BeadRingPainter(
            position: _position,
            pulse: _pulse,
            counter: widget.counter,
            palette: TasbeehRingPalette.of(t),
            direction: Directionality.of(context),
            recording: _recording,
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

/// The beads as recorded for one count (see [_BeadRingPainter]).
class _BeadsRecording {
  ui.Picture? picture;
  Object? key;

  /// The ring position the beads were recorded at.
  double at = 0;

  void replace(ui.Picture next, Object nextKey, double nextAt) {
    picture?.dispose();
    picture = next;
    key = nextKey;
    at = nextAt;
  }

  void dispose() {
    picture?.dispose();
    picture = null;
    key = null;
  }
}

class _BeadRingPainter extends CustomPainter {
  _BeadRingPainter({
    required this.position,
    required this.pulse,
    required this.counter,
    required this.palette,
    required this.direction,
    required this.recording,
  }) : super(repaint: Listenable.merge([position, pulse]));

  final Animation<double> position;
  final Animation<double> pulse;
  final TasbeehCounter counter;
  final TasbeehRingPalette palette;
  final TextDirection direction;

  /// Between two taps the ring only turns: the beads (spheres, halos,
  /// separators – a few hundred draw calls) are recorded once per count at
  /// the position the spring is heading to, and every frame of the spring
  /// draws that recording rotated by how far the spring still has to go.
  /// At rest the drawing is exactly the per-bead one.
  final _BeadsRecording recording;

  @override
  void paint(Canvas canvas, Size size) {
    final beads = counter.beads;
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final ringR = outer * 0.8;
    final beadR = TasbeehRingGeometry.beadRadius(beads, ringR);
    final p = position.value;
    final key = (counter.count, counter.target, palette, size, direction);
    if (recording.key != key || recording.picture == null) {
      final at = counter.count * beads / counter.target;
      final recorder = ui.PictureRecorder();
      _paintBeads(Canvas(recorder), c, ringR, beadR, at);
      recording.replace(recorder.endRecording(), key, at);
    }
    final sign = direction == TextDirection.rtl ? -1.0 : 1.0;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-sign * (p - recording.at) * 2 * math.pi / beads);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawPicture(recording.picture!);
    canvas.restore();

    // The marker at the top: a gold drop (the misbaha's "imam") with a
    // short tassel line toward the centre.
    final top = c + Offset(0, -ringR);
    final markerY = top.dy - beadR - 7;
    final drop = Path()
      ..moveTo(c.dx, markerY + 8)
      ..quadraticBezierTo(c.dx + 7, markerY - 2, c.dx, markerY - 11)
      ..quadraticBezierTo(c.dx - 7, markerY - 2, c.dx, markerY + 8)
      ..close();
    canvas.drawPath(
      drop,
      Paint()
        ..color = palette.litGlow.withValues(alpha: palette.litGlow.a * 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      drop,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(palette.gold, palette.highlight, 0.4)!, palette.gold, palette.brassDark],
        ).createShader(drop.getBounds()),
    );
    canvas.drawLine(
      Offset(c.dx, top.dy + beadR + 5),
      Offset(c.dx, top.dy + beadR + 14),
      Paint()
        ..color = palette.gold.withValues(alpha: 0.7)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    // A completed round: a pulse of light travelling outwards.
    final pv = pulse.value;
    if (pv > 0 && pv < 1) {
      final e = Curves.easeOutCubic.transform(pv);
      canvas.drawCircle(
        c,
        ringR + e * outer * 0.22,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = beadR * (1.6 - e)
          ..color = palette.litGlow.withValues(alpha: (1 - pv) * 0.8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + 6 * e),
      );
    }
  }

  /// The string and the beads with the ring at position [p].
  void _paintBeads(Canvas canvas, Offset c, double ringR, double beadR, double p) {
    final beads = counter.beads;
    final paints = _BeadPaints(palette, beadR);

    // The string: a thin brass circle with a faint inner engraving.
    canvas.drawCircle(c, ringR, paints.string);
    canvas.drawCircle(c, ringR - beadR * 2.4, paints.engraving);

    // Which beads are lit: the ones counted in this round, just behind the
    // marker.
    // From the counter, not the spring: the counted bead lights at once and
    // glides past the marker lit.
    final head = (counter.count * beads / counter.target).floor();
    final lit = counter.litBeads;
    final seps = TasbeehRingGeometry.separators(beads);
    for (var k = 0; k < beads; k++) {
      final angle = TasbeehRingGeometry.angleOf(k, p, beads, direction);
      final behind = ((head - k) % beads + beads) % beads; // 1 = just passed
      final isLit = lit > 0 && behind >= 1 && behind <= lit || (lit == beads && counter.count > 0);
      final isSep = seps.contains(k);
      canvas.save();
      canvas.translate(c.dx + math.cos(angle) * ringR, c.dy + math.sin(angle) * ringR);
      if (isLit) {
        canvas.drawCircle(Offset.zero, (isSep ? beadR * 0.8 : beadR) * 1.9, isSep ? paints.sepHalo : paints.halo);
      }
      if (isSep) {
        // An elongated separator bead along the string.
        canvas.rotate(angle + math.pi / 2);
        canvas.drawRRect(paints.sepShape, isLit ? paints.sepLit : paints.sepUnlit);
      } else {
        canvas.drawCircle(Offset.zero, beadR, isLit ? paints.beadLit : paints.beadUnlit);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BeadRingPainter old) =>
      old.counter != counter || old.palette != palette || old.direction != direction;
}

/// The bead paints of one palette and bead size (see [_BeadRingPainter]).
class _BeadPaints {
  _BeadPaints(TasbeehRingPalette palette, this.beadR)
    : string = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = palette.string,
      engraving = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = palette.string.withValues(alpha: palette.string.a * 0.35),
      halo = _halo(palette, beadR),
      sepHalo = _halo(palette, beadR * 0.8),
      beadLit = _sphere(palette.lit, palette.litEdge, palette.highlight, beadR, 0.6),
      beadUnlit = _sphere(palette.unlit, palette.unlitEdge, palette.highlight, beadR, 0.45),
      sepShape = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: beadR * 0.8 * 3.2, height: beadR * 0.8 * 1.7),
        Radius.circular(beadR * 0.8),
      ),
      sepLit = _separator(palette.lit, palette.litEdge, palette.highlight, beadR * 0.8),
      sepUnlit = _separator(palette.unlit, palette.unlitEdge, palette.highlight, beadR * 0.8);

  final double beadR;
  final Paint string, engraving, halo, sepHalo, beadLit, beadUnlit, sepLit, sepUnlit;
  final RRect sepShape;

  static Paint _halo(TasbeehRingPalette palette, double r) => Paint()
    ..color = palette.litGlow.withValues(alpha: palette.litGlow.a * 0.55)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.9);

  /// A lit-from-the-top-left sphere centred on the origin.
  static Paint _sphere(Color base, Color edge, Color highlight, double r, double shine) => Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.35, -0.4),
      radius: 1.1,
      colors: [Color.lerp(base, highlight, shine)!, base, edge],
      stops: const [0, 0.45, 1],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));

  static Paint _separator(Color base, Color edge, Color highlight, double r) {
    final rect = Rect.fromCenter(center: Offset.zero, width: r * 3.2, height: r * 1.7);
    return Paint()
      ..shader = RadialGradient(
        colors: [Color.lerp(base, highlight, 0.5)!, base, edge],
        stops: const [0, 0.5, 1],
      ).createShader(rect);
  }
}
