import 'dart:math' as math;
import 'dart:ui';

import '../fx/line_boil.dart';

/// Hand-inked ornaments of the Madar Cinema house style, drawn in code:
/// the orbit emblem (Madar's own mark: a tilted ring round a planet with a
/// moon), sunbursts, rosettes, stars, laurels, neon tubes, bulbs.
///
/// These run when a stage picture, a poster or a plaque is (re)built – not
/// every frame – so they may allocate paths. Pass a [BoilPen] to wobble the
/// outlines on the 12 fps line boil.
abstract final class Ornaments {
  static final Paint _fill = Paint()..isAntiAlias = true;
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Fills [path] (optionally with [shader]) and inks its outline.
  static void inked(Canvas canvas, Path path, Color fill, Color ink, double lineWidth, {Shader? shader}) {
    if (lineWidth > 0) {
      _stroke
        ..shader = null
        ..color = ink
        ..strokeWidth = lineWidth * 2;
      canvas.drawPath(path, _stroke);
    }
    _fill
      ..shader = shader
      ..color = fill;
    canvas.drawPath(path, _fill);
    _fill.shader = null;
  }

  /// Strokes [path] with [color] at [width].
  static void line(Canvas canvas, Path path, Color color, double width, {Shader? shader, StrokeCap cap = StrokeCap.round}) {
    _stroke
      ..shader = shader
      ..color = color
      ..strokeWidth = width
      ..strokeCap = cap;
    canvas.drawPath(path, _stroke);
    _stroke
      ..shader = null
      ..strokeCap = StrokeCap.round;
  }

  /// A glowing neon tube along [path]: three widening halos under a hot
  /// white-ish core (no blur filters – cheap to replay every frame).
  static void neon(Canvas canvas, Path path, Color color, double width, {double intensity = 1}) {
    final k = intensity.clamp(0.0, 1.5);
    for (final (w, a) in const [(6.0, 0.10), (3.4, 0.18), (1.9, 0.45)]) {
      _stroke
        ..shader = null
        ..color = color.withValues(alpha: (a * k).clamp(0.0, 1.0))
        ..strokeWidth = width * w;
      canvas.drawPath(path, _stroke);
    }
    _stroke
      ..color = Color.lerp(color, const Color(0xFFFFFFFF), 0.55)!.withValues(alpha: (0.95 * k).clamp(0.0, 1.0))
      ..strokeWidth = width * 0.8;
    canvas.drawPath(path, _stroke);
  }

  /// Madar's orbit emblem: a planet inside a tilted ring with a moon riding
  /// it. [r] = ring radius.
  static void orbitEmblem(
    Canvas canvas,
    Offset c,
    double r, {
    required Color ring,
    required Color planet,
    required Color ink,
    Color? light,
    double lineWidth = 2,
    BoilPen? pen,
    int frame = 0,
    bool neon = false,
    double tilt = -0.42,
  }) {
    final pr = r * 0.42;
    final ringPath = Path();
    final planetPath = Path();
    final moonPath = Path();
    final moonAngle = -2.2;
    final moon = c + Offset(math.cos(moonAngle) * r, math.sin(moonAngle) * r * 0.36).rotate(tilt);
    if (pen != null) {
      pen.begin(planetPath, frame);
      pen.circle(c, pr);
      pen.begin(moonPath, frame);
      pen.circle(moon, r * 0.13);
    } else {
      planetPath.addOval(Rect.fromCircle(center: c, radius: pr));
      moonPath.addOval(Rect.fromCircle(center: moon, radius: r * 0.13));
    }
    // The ring as a thin ellipse band (drawn as two strokes: behind and in
    // front of the planet).
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(tilt);
    ringPath.addOval(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 0.72));
    final back = Path()..addArc(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 0.72), math.pi, math.pi);
    final front = Path()..addArc(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 0.72), 0, math.pi);
    if (neon) {
      Ornaments.neon(canvas, back, ring, lineWidth * 1.2);
    } else {
      line(canvas, back, ink, lineWidth * 3.2);
      line(canvas, back, ring, lineWidth * 1.4);
    }
    canvas.restore();
    if (neon) {
      Ornaments.neon(canvas, planetPath, planet, lineWidth * 1.1);
    } else {
      inked(canvas, planetPath, planet, ink, lineWidth);
      if (light != null) {
        final shine = Path()..addOval(Rect.fromCircle(center: c + Offset(-pr * 0.38, -pr * 0.4), radius: pr * 0.22));
        inked(canvas, shine, light, ink, 0);
      }
    }
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(tilt);
    if (neon) {
      Ornaments.neon(canvas, front, ring, lineWidth * 1.2);
    } else {
      line(canvas, front, ink, lineWidth * 3.2);
      line(canvas, front, ring, lineWidth * 1.4);
    }
    canvas.restore();
    if (neon) {
      Ornaments.neon(canvas, moonPath, ring, lineWidth);
    } else {
      inked(canvas, moonPath, light ?? ring, ink, lineWidth * 0.8);
    }
  }

  /// A fan of alternating rays between radii [r0] and [r1] over [sweep]
  /// radians starting at [start] (art-deco sunburst).
  static void sunburst(
    Canvas canvas,
    Offset c,
    double r0,
    double r1,
    int rays,
    double start,
    double sweep, {
    required Color a,
    required Color b,
    required Color ink,
    double lineWidth = 1.2,
  }) {
    final step = sweep / rays;
    for (var i = 0; i < rays; i++) {
      final a0 = start + step * i, a1 = a0 + step;
      final p = Path()
        ..moveTo(c.dx + math.cos(a0) * r0, c.dy + math.sin(a0) * r0)
        ..lineTo(c.dx + math.cos(a0) * r1, c.dy + math.sin(a0) * r1)
        ..lineTo(c.dx + math.cos(a1) * r1, c.dy + math.sin(a1) * r1)
        ..lineTo(c.dx + math.cos(a1) * r0, c.dy + math.sin(a1) * r0)
        ..close();
      inked(canvas, p, i.isEven ? a : b, ink, lineWidth * 0.5);
    }
  }

  /// A star with [points] spikes (outer radius [r], inner [ri]).
  static Path starPath(Offset c, double r, double ri, int points, {double rotation = -math.pi / 2, BoilPen? pen, int frame = 0}) {
    final path = Path();
    if (pen != null) pen.begin(path, frame);
    for (var i = 0; i < points * 2; i++) {
      final rr = i.isEven ? r : ri;
      final a = rotation + math.pi * i / points;
      final x = c.dx + math.cos(a) * rr, y = c.dy + math.sin(a) * rr;
      if (pen != null) {
        i == 0 ? pen.moveTo(x, y) : pen.lineTo(x, y);
      } else {
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  /// A plaster rosette: [petals] round petals around a boss.
  static void rosette(Canvas canvas, Offset c, double r, int petals, {required Color fill, required Color ink, required Color boss, double lineWidth = 1}) {
    final p = Path();
    for (var i = 0; i < petals; i++) {
      final a = math.pi * 2 * i / petals;
      p.addOval(Rect.fromCircle(center: c + Offset(math.cos(a), math.sin(a)) * r * 0.58, radius: r * 0.42));
    }
    inked(canvas, p, fill, ink, lineWidth);
    inked(canvas, Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.36)), boss, ink, lineWidth);
  }

  /// A laurel sprig from [a] to [b] bowing by [bend] (× length), with
  /// [leaves] pairs of leaves.
  static void laurel(Canvas canvas, Offset a, Offset b, double bend, int leaves, {required Color fill, required Color ink, double lineWidth = 1}) {
    final d = b - a;
    final n = Offset(-d.dy, d.dx);
    final ctrl = Offset.lerp(a, b, 0.5)! + n * bend;
    Offset at(double t) => a * ((1 - t) * (1 - t)) + ctrl * (2 * (1 - t) * t) + b * (t * t);
    final stem = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
    line(canvas, stem, ink, lineWidth * 1.4);
    final len = d.distance;
    for (var i = 0; i < leaves; i++) {
      final t = 0.12 + 0.82 * i / math.max(1, leaves - 1);
      final p = at(t);
      final q = at(math.min(1, t + 0.02));
      final dir = math.atan2(q.dy - p.dy, q.dx - p.dx);
      final size = len * 0.13 * (1 - t * 0.45);
      for (final side in const [-1.0, 1.0]) {
        canvas
          ..save()
          ..translate(p.dx, p.dy)
          ..rotate(dir + side * 0.75);
        final leaf = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(size * 0.5, -size * 0.34, size, 0)
          ..quadraticBezierTo(size * 0.5, size * 0.34, 0, 0)
          ..close();
        inked(canvas, leaf, fill, ink, lineWidth * 0.6);
        canvas.restore();
      }
    }
  }

  /// A volute (scroll) of radius [r] turning [dir] (±1).
  static Path volute(Offset c, double r, double dir) {
    final p = Path();
    const turns = 1.6;
    const steps = 22;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final a = dir * t * turns * math.pi * 2;
      final rr = r * (1 - 0.72 * t);
      final x = c.dx + math.cos(a) * rr, y = c.dy + math.sin(a) * rr;
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p;
  }
}

extension on Offset {
  Offset rotate(double a) {
    final c = math.cos(a), s = math.sin(a);
    return Offset(dx * c - dy * s, dx * s + dy * c);
  }
}
