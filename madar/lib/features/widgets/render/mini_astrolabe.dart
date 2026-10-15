import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../core/design/themes.dart';
import '../../orbit/render/astrolabe/astrolabe_geometry.dart';
import '../../orbit/render/astrolabe/astrolabe_palette.dart';
import '../domain/widget_build.dart';

export '../domain/widget_build.dart' show MiniAstrolabeSpec;

/// Paints the mini astrolabe in the orbit's visual language – brass limb
/// with engraved hours, lapis enamel plate with the day arc and twilight,
/// the lit window as molten amber, star pointers for the five prayers and
/// the rete's eight-point star with an alidade aimed at the next prayer –
/// simplified to read at 60–100 dp on a home screen.
class MiniAstrolabePainter {
  MiniAstrolabePainter(this.spec, this.palette);

  final MiniAstrolabeSpec spec;
  final AstrolabePalette palette;

  /// The palette for a light (Pearl) or dark (Lapis) home screen.
  static AstrolabePalette paletteFor({required bool dark}) =>
      AstrolabePalette.fromTokens(MadarPalettes.tokensFor(dark ? MadarThemeId.lapis : MadarThemeId.pearl));

  void paint(Canvas canvas, Size size) {
    final p = palette;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * 0.9;
    final limbIn = r * 0.8;

    // Halo (dark) / soft shadow (light) around the limb.
    canvas.drawCircle(
      c + (p.light ? Offset(0, r * 0.03) : Offset.zero),
      r * (p.light ? 0.99 : 1.02),
      Paint()
        ..color = (p.light ? p.shadow : p.halo).withValues(alpha: p.light ? 0.35 : 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.07),
    );

    // Brass limb: a three-stop metal ramp swept around the ring.
    final limb = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: c, radius: r))
      ..addOval(Rect.fromCircle(center: c, radius: limbIn));
    canvas.drawPath(
      limb,
      Paint()
        ..shader = ui.Gradient.sweep(
          c,
          [p.brassHi, p.brass, p.brassLow, p.brass, p.brassHi, p.brass, p.brassLow, p.brass, p.brassHi],
          [0, 0.12, 0.25, 0.37, 0.5, 0.62, 0.75, 0.87, 1],
        ),
    );
    // Bevels: lit outer edge, shaded inner edge.
    canvas.drawCircle(
      c,
      r - r * 0.012,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.024
        ..color = p.bevelLight,
    );
    canvas.drawCircle(
      c,
      limbIn + r * 0.01,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.02
        ..color = p.bevelDark,
    );

    // Engraved hours: 24 ticks, the quarters of the day longer.
    final tick = Paint()
      ..color = p.ink
      ..strokeCap = StrokeCap.round;
    for (var h = 0; h < 24; h++) {
      final major = h % 6 == 0;
      final dir = AstrolabeGeometry.directionOf(h / 24);
      final outer = r * 0.95;
      final inner = major ? r * 0.83 : r * 0.885;
      tick.strokeWidth = r * (major ? 0.028 : 0.016);
      canvas.drawLine(c + dir * inner, c + dir * outer, tick);
    }

    // Enamel plate.
    canvas.drawCircle(
      c,
      limbIn,
      Paint()
        ..shader = ui.Gradient.radial(c, limbIn, [p.enamelCenter, p.enamelMid, p.enamelEdge], [0, 0.6, 1]),
    );
    // The sky above the horizon (sunrise → Maghrib) and the twilights.
    _sector(canvas, c, limbIn * 0.98, spec.sunrise, spec.maghrib, p.daySky.withValues(alpha: 0.42));
    _sector(canvas, c, limbIn * 0.98, spec.fajr, spec.sunrise, p.twilight.withValues(alpha: 0.3));
    _sector(canvas, c, limbIn * 0.98, spec.maghrib, spec.isha, p.twilight.withValues(alpha: 0.3));
    // Sheen and the engraved almucantars.
    canvas.drawCircle(
      c.translate(-limbIn * 0.25, -limbIn * 0.3),
      limbIn * 0.6,
      Paint()
        ..shader = ui.Gradient.radial(
          c.translate(-limbIn * 0.25, -limbIn * 0.3),
          limbIn * 0.6,
          [p.enamelSheen.withValues(alpha: 0.35), p.enamelSheen.withValues(alpha: 0)],
        ),
    );
    final plate = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.012
      ..color = p.plateLine.withValues(alpha: 0.35);
    for (final k in const [0.36, 0.58]) {
      canvas.drawCircle(c, limbIn * k, plate);
    }
    // Horizon line through the sunrise and Maghrib points.
    canvas.drawLine(
      AstrolabeGeometry.pointAt(c, limbIn * 0.98, spec.sunrise),
      AstrolabeGeometry.pointAt(c, limbIn * 0.98, spec.maghrib),
      plate..color = p.plateLine.withValues(alpha: 0.5),
    );

    // The lit window leading to the next prayer.
    final (from, to) = spec.window;
    final channel = limbIn * 0.84;
    final start = AstrolabeGeometry.angleForFraction(from);
    var sweep = (to - from) * AstrolabeGeometry.tau;
    if (sweep <= 0) sweep += AstrolabeGeometry.tau;
    // Drawn rotated so the arc starts at angle 0: the sweep gradient then
    // runs from its tail to its head without wrapping past 2π.
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(start);
    final arcRect = Rect.fromCircle(center: Offset.zero, radius: channel);
    canvas.drawArc(
      arcRect,
      0,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.11
        ..strokeCap = StrokeCap.round
        ..color = p.litArc.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04),
    );
    canvas.drawArc(
      arcRect,
      0,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.055
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.sweep(
          Offset.zero,
          [p.litArc.withValues(alpha: 0.35), p.litArc, p.litHead],
          [0, 0.7, 1],
          TileMode.clamp,
          0,
          sweep,
        ),
    );
    canvas.restore();

    // Alidade: from the centre to the next prayer.
    final nextF = spec.prayers[spec.next.clamp(0, 4)];
    final tip = AstrolabeGeometry.pointAt(c, channel * 0.93, nextF);
    final tail = AstrolabeGeometry.pointAt(c, limbIn * 0.3, nextF + 0.5);
    canvas.drawLine(
      tail,
      tip,
      Paint()
        ..strokeWidth = r * 0.04
        ..strokeCap = StrokeCap.round
        ..color = p.brassLow,
    );
    canvas.drawLine(
      tail,
      tip,
      Paint()
        ..strokeWidth = r * 0.022
        ..strokeCap = StrokeCap.round
        ..color = p.brassHi,
    );

    // Prayer pointers: small stars, the next one large and burning.
    for (var i = 0; i < 5; i++) {
      final f = spec.prayers[i];
      final at = AstrolabeGeometry.pointAt(c, channel, f);
      if (i == spec.next) {
        canvas.drawCircle(
          at,
          r * 0.17,
          Paint()
            ..shader = ui.Gradient.radial(at, r * 0.17, [
              p.fireInner.withValues(alpha: 0.9),
              p.fireOuter.withValues(alpha: 0.35),
              p.fireOuter.withValues(alpha: 0),
            ], [0, 0.45, 1]),
        );
        _star(canvas, at, r * 0.1, p.brassHi, p.brassLow, stroke: r * 0.012);
        canvas.drawCircle(at, r * 0.032, Paint()..color = p.starCore);
      } else {
        _star(canvas, at, r * 0.055, p.labelUpcoming, p.brassLow, stroke: r * 0.008);
      }
    }

    // The rete's star at the pivot.
    _star(canvas, c, r * 0.16, p.brass, p.brassLow, stroke: r * 0.014);
    canvas.drawCircle(
      c,
      r * 0.06,
      Paint()..shader = ui.Gradient.radial(c, r * 0.06, [p.starCore, p.starCorona.withValues(alpha: 0.8)]),
    );
    canvas.drawCircle(
      c,
      r * 0.06,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.012
        ..color = p.brassLow,
    );
  }

  /// A filled pie slice of the plate from dial fraction [from] clockwise to
  /// [to].
  static void _sector(Canvas canvas, Offset c, double radius, double from, double to, Color color) {
    var sweep = (to - from) * AstrolabeGeometry.tau;
    if (sweep <= 0) sweep += AstrolabeGeometry.tau;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      AstrolabeGeometry.angleForFraction(from),
      sweep,
      true,
      Paint()..color = color,
    );
  }

  /// The eight-point star (Rub el Hizb): two squares, 45° apart.
  static void _star(Canvas canvas, Offset at, double radius, Color fill, Color edge, {required double stroke}) {
    final path = Path();
    for (var k = 0; k < 16; k++) {
      final a = k * math.pi / 8 - math.pi / 2;
      final rr = k.isEven ? radius : radius * 0.62;
      final pt = at + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (k == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..color = edge,
    );
  }
}

/// Renders mini astrolabes to PNG (Flutter's [ui.PictureRecorder]; no
/// widget tree), for the Android provider to show as a bitmap.
abstract final class MiniAstrolabeRenderer {
  /// Pixel size of the published PNGs: sharp at 96 dp on a 3× screen.
  static const int sizePx = 288;

  static Future<ui.Image> render(MiniAstrolabeSpec spec, {required bool dark, int size = sizePx}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final s = Size.square(size.toDouble());
    MiniAstrolabePainter(spec, MiniAstrolabePainter.paletteFor(dark: dark)).paint(canvas, s);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(size, size);
    } finally {
      picture.dispose();
    }
  }

  /// [spec] as PNG bytes.
  static Future<Uint8List> png(MiniAstrolabeSpec spec, {required bool dark, int size = sizePx}) async {
    final image = await render(spec, dark: dark, size: size);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('PNG encoding failed');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }
}
