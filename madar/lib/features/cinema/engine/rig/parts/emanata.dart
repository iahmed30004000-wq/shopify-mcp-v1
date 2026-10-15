import 'dart:math' as math;

import '../ink/ink_build.dart';

/// The little marks cartoonists draw AROUND a character to show what it
/// feels: dizzy stars, sweat drops, shock lines, speed lines, dust puffs,
/// the impact burst, steam, sparkles and music notes. All in the pen's
/// design space, all boiling with the drawing.
abstract final class Emanata {
  /// Stars circling over a head at ([cx], [cy]) on an orbit [rx] wide.
  static void dizzyStars(InkBuild b, double cx, double cy, double rx, double time, {int count = 3}) {
    final pen = b.pen;
    for (var i = 0; i < count; i++) {
      final a = time * 4.2 + i * math.pi * 2 / count;
      final depth = math.sin(a);
      final x = cx + math.cos(a) * rx, y = cy + depth * rx * 0.28;
      final s = rx * (0.2 + 0.06 * depth);
      b.layer();
      b.shape(b.colors.puff, ink: 0.7);
      pen.star(x, y, 5, s, s * 0.45, rot: -math.pi / 2 + time * 3 + i, round: 0.25);
      b.endLayer();
    }
  }

  /// Sweat drops flying off a head; [phase] 0..1 loops.
  static void sweat(InkBuild b, double x, double y, double size, double side, double phase) {
    final pen = b.pen;
    for (var i = 0; i < 2; i++) {
      final p = (phase + i * 0.5) % 1;
      final dx = x + side * (size * 0.5 + p * size * 1.4) + i * side * size * 0.2;
      final dy = y - size * (0.6 + i * 0.5) + p * p * size * 1.6 - p * size * 0.6;
      final s = size * (0.36 - p * 0.14);
      b.layer();
      b.shape(b.colors.puff, ink: 0.7);
      pen
        ..save()
        ..translate(dx, dy)
        ..rotate(side * (0.5 + p))
        ..moveTo(0, -s * 1.5)
        ..cubicTo(s * 0.35, -s * 0.7, s, -s * 0.2, s, s * 0.3)
        ..cubicTo(s, s * 0.9, -s, s * 0.9, -s, s * 0.3)
        ..cubicTo(-s, -s * 0.2, -s * 0.35, -s * 0.7, 0, -s * 1.5)
        ..close()
        ..restore();
      b.endLayer();
    }
  }

  /// Radiating shock lines around a head ([amount] 0..1 grows them).
  static void shock(InkBuild b, double cx, double cy, double r, double amount, {int count = 7}) {
    if (amount <= 0.01) return;
    b.layer();
    for (var i = 0; i < count; i++) {
      final a = -math.pi * 0.95 + i * math.pi * 0.9 / (count - 1) + b.j(90 + i) * 0.05;
      final r0 = r * (1.18 + 0.05 * b.j(100 + i));
      final r1 = r0 + r * (0.28 + 0.16 * (i.isEven ? 1 : 0)) * amount;
      final ca = math.cos(a), sa = math.sin(a);
      b.brushQuad(
        2,
        cx + ca * r0,
        cy + sa * r0,
        cx + ca * (r0 + r1) / 2,
        cy + sa * (r0 + r1) / 2,
        cx + ca * r1,
        cy + sa * r1,
        b.lw * 1.2,
        taperIn: 0.1,
        taperOut: 0.8,
      );
    }
    b.endLayer();
  }

  /// Horizontal speed lines trailing behind ([dir] = direction of travel).
  static void speedLines(InkBuild b, double x, double top, double bottom, double dir, double intensity) {
    if (intensity <= 0.05) return;
    b.layer();
    for (var i = 0; i < 4; i++) {
      final y = top + (bottom - top) * (0.15 + i * 0.24) + b.ja(110 + i, 1.5);
      final len = (bottom - top) * (0.35 + 0.25 * (b.j(120 + i) + 1) / 2) * intensity;
      final x0 = x - dir * (bottom - top) * (0.05 + 0.08 * (i.isOdd ? 1 : 0));
      b.brushQuad(
        2,
        x0,
        y,
        x0 - dir * len * 0.5,
        y + b.ja(130 + i),
        x0 - dir * len,
        y,
        b.lw * 0.9,
        taperIn: 0.05,
        taperOut: 0.9,
      );
    }
    b.endLayer();
  }

  /// A dust puff at ([x], [y]); [age] 0..1 (grows, then shrinks away).
  static void dust(InkBuild b, double x, double y, double size, double age) {
    if (age <= 0 || age >= 1) return;
    final pen = b.pen;
    final grow = math.sin(age * math.pi);
    b.layer();
    for (var i = 0; i < 3; i++) {
      final a = math.pi + i * 0.7 - 0.2;
      final d = size * (0.3 + age * 0.9);
      b.shape(b.colors.puff, ink: 0.65);
      pen.circle(
        x + math.cos(a) * d * (i - 1).abs() + (i - 1) * d,
        y - size * 0.25 - age * size * 0.5 - (i == 1 ? size * 0.2 : 0),
        size * (0.28 + 0.14 * (i == 1 ? 1 : 0)) * grow,
      );
    }
    b.endLayer();
  }

  /// The spiky "POW" burst behind an impact.
  static void impact(InkBuild b, double x, double y, double size, {double rot = 0}) {
    final pen = b.pen;
    b.layer();
    b.shape(b.colors.puff, ink: 0.9);
    pen
      ..save()
      ..translate(x, y)
      ..rotate(rot + b.j(140) * 0.1);
    const n = 9;
    for (var i = 0; i <= n * 2; i++) {
      final k = i % (n * 2);
      final a = k * math.pi / n;
      final r = k.isEven ? size * (1 + 0.18 * b.j(150 + k)) : size * 0.5;
      if (i == 0) {
        pen.moveTo(math.cos(a) * r, math.sin(a) * r);
      } else {
        pen.lineTo(math.cos(a) * r, math.sin(a) * r);
      }
    }
    pen
      ..close()
      ..restore();
    b.endLayer();
  }

  /// A puff of steam rising from ([x], [y]); [phase] 0..1 loops.
  static void steam(InkBuild b, double x, double y, double size, double phase, {double drift = 0.3}) {
    final pen = b.pen;
    b.layer();
    for (var i = 0; i < 3; i++) {
      final p = (phase + i / 3) % 1;
      final s = size * (0.35 + p * 0.65) * math.sin(math.min(1.0, p * 1.2) * math.pi * 0.95 + 0.1);
      if (s <= 0.01) continue;
      b.shape(b.colors.puff, ink: 0.7);
      pen.circle(x + drift * p * size * 2 + math.sin(p * 7 + i) * size * 0.15, y - p * size * 2.6, s);
    }
    b.endLayer();
  }

  /// Four-point twinkles (cheer, shine) around ([cx], [cy]).
  static void sparkles(InkBuild b, double cx, double cy, double r, double time, {int count = 3}) {
    final pen = b.pen;
    for (var i = 0; i < count; i++) {
      final p = (time * 1.3 + i / count) % 1;
      final a = i * 2.1 + 0.6;
      final x = cx + math.cos(a) * r * (0.9 + 0.2 * i), y = cy + math.sin(a) * r * 0.8;
      final s = r * 0.16 * math.sin(p * math.pi);
      if (s < 0.3) continue;
      b.layer();
      b.shape(b.colors.puff, ink: 0.6);
      pen.star(x, y, 4, s, s * 0.28, rot: 0, round: 0.1);
      b.endLayer();
    }
  }

  /// A quaver floating up (whistling, taunts); [phase] 0..1.
  static void note(InkBuild b, double x, double y, double size, double phase) {
    final pen = b.pen;
    final p = phase % 1;
    final px = x + math.sin(p * math.pi * 2) * size * 0.4, py = y - p * size * 2.2;
    final s = size * (0.6 + 0.4 * math.sin(p * math.pi));
    b.layer();
    b.inkFill();
    pen.ellipse(px, py, s * 0.36, s * 0.26, -0.4);
    b.inkLine(b.lw * 0.8);
    pen
      ..moveTo(px + s * 0.3, py - s * 0.1)
      ..lineTo(px + s * 0.3, py - s * 1.1)
      ..quadTo(px + s * 0.75, py - s * 0.85, px + s * 0.7, py - s * 0.5);
    b.endLayer();
  }
}
