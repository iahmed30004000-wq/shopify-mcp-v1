import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe_geometry.dart';
import 'package:madar/features/widgets/widgets.dart';

/// Decoded RGBA pixels of a PNG.
class _Pixels {
  _Pixels(this.width, this.height, this.rgba);

  final int width, height;
  final ByteData rgba;

  Color at(double x, double y) {
    final i = (y.round().clamp(0, height - 1) * width + x.round().clamp(0, width - 1)) * 4;
    return Color.fromARGB(rgba.getUint8(i + 3), rgba.getUint8(i), rgba.getUint8(i + 1), rgba.getUint8(i + 2));
  }

  static Future<_Pixels> decode(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final data = (await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final p = _Pixels(frame.image.width, frame.image.height, data);
    frame.image.dispose();
    codec.dispose();
    return p;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Amman, late September: Fajr 4:52, sunrise 6:18, Dhuhr 12:37, Asr 15:59,
  // Maghrib 18:49, Isha 20:08 (dial fractions of the day).
  double f(int h, int m) => (h * 60 + m) / 1440;
  MiniAstrolabeSpec spec(int next) => MiniAstrolabeSpec(
    fajr: f(4, 52),
    sunrise: f(6, 18),
    dhuhr: f(12, 37),
    asr: f(15, 59),
    maghrib: f(18, 49),
    isha: f(20, 8),
    next: next,
  );

  const size = MiniAstrolabeRenderer.sizePx;
  const c = Offset(size / 2, size / 2);
  const r = size / 2 * 0.9;
  const channel = r * 0.8 * 0.84;
  Offset onDial(double fraction, double radius) => AstrolabeGeometry.pointAt(c, radius, fraction);
  bool amber(Color x) => x.a > 0.9 && x.r > 0.6 && x.r > x.b + 0.25;

  test('renders a square PNG: transparent corners, opaque dial', () async {
    final png = await MiniAstrolabeRenderer.png(spec(2), dark: true);
    expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final px = await _Pixels.decode(png);
    expect((px.width, px.height), (size, size));
    for (final corner in [const Offset(1, 1), const Offset(size - 2, 1), const Offset(1, size - 2)]) {
      expect(px.at(corner.dx, corner.dy).a, 0, reason: '$corner');
    }
    expect(px.at(c.dx, c.dy).a, greaterThan(0.99), reason: 'the rete star at the pivot');
    // The limb is brass: warm, red over blue.
    final limb = px.at(c.dx, c.dy - r * 0.9);
    expect(limb.a, greaterThan(0.99));
    expect(limb.r, greaterThan(limb.b));
  });

  test('the window to the next prayer burns amber; the rest of the channel does not', () async {
    final px = await _Pixels.decode(await MiniAstrolabeRenderer.png(spec(2), dark: true));
    // Halfway between Dhuhr and Asr (the lit window when Asr is next).
    final lit = px.at(onDial((f(12, 37) + f(15, 59)) / 2, channel).dx, onDial((f(12, 37) + f(15, 59)) / 2, channel).dy);
    expect(amber(lit), isTrue, reason: '$lit');
    // Halfway between Isha and Fajr (unlit night).
    final nightF = (f(20, 8) + 1 + f(4, 52)) / 2 % 1;
    final night = px.at(onDial(nightF, channel).dx, onDial(nightF, channel).dy);
    expect(amber(night), isFalse, reason: '$night');
  });

  test('each prayer lights its own window; light and dark differ', () async {
    final asr = await MiniAstrolabeRenderer.png(spec(2), dark: true);
    final maghrib = await MiniAstrolabeRenderer.png(spec(3), dark: true);
    final asrLight = await MiniAstrolabeRenderer.png(spec(2), dark: false);
    expect(maghrib, isNot(asr));
    expect(asrLight, isNot(asr));
    final px = await _Pixels.decode(maghrib);
    final mid = (f(15, 59) + f(18, 49)) / 2;
    final p = onDial(mid, channel);
    expect(amber(px.at(p.dx, p.dy)), isTrue);
    // The fajr window wraps past midnight and still draws (Isha → Fajr).
    final fajr = await _Pixels.decode(await MiniAstrolabeRenderer.png(spec(0), dark: false));
    final wrap = onDial(0, channel);
    expect(fajr.at(wrap.dx, wrap.dy).a, greaterThan(0.9));
  });

  test('is deterministic (the bridge compares signatures, Android the bytes it gets)', () async {
    expect(await MiniAstrolabeRenderer.png(spec(1), dark: true), await MiniAstrolabeRenderer.png(spec(1), dark: true));
    expect(spec(1).signature, spec(1).signature);
    expect(spec(1).signature, isNot(spec(2).signature));
    expect(spec(1), spec(1));
    // Sub-minute differences do not change the drawing's identity.
    final nudged = MiniAstrolabeSpec(
      fajr: f(4, 52) + 1 / 1440 / 10,
      sunrise: f(6, 18),
      dhuhr: f(12, 37),
      asr: f(15, 59),
      maghrib: f(18, 49),
      isha: f(20, 8),
      next: 1,
    );
    expect(nudged.signature, spec(1).signature);
    expect(math.pi, greaterThan(3));
  });
}
