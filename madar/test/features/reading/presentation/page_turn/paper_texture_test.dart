import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/reading/presentation/page_turn/paper_texture.dart';

void main() {
  test('same seed, same paper; another seed, another paper', () {
    final a = PaperTexture.pixels(seed: 3, strength: 0.6);
    final b = PaperTexture.pixels(seed: 3, strength: 0.6);
    final c = PaperTexture.pixels(seed: 4, strength: 0.6);
    expect(a, orderedEquals(b));
    expect(a, isNot(orderedEquals(c)));
    expect(a.length, PaperTexture.tileSize * PaperTexture.tileSize * 4);
  });

  test('strength 0 is fully transparent; the grain stays faint even at full strength', () {
    expect(PaperTexture.pixels(seed: 1, strength: 0).every((v) => v == 0), isTrue);
    final px = PaperTexture.pixels(seed: 1, strength: 1);
    var maxAlpha = 0, touched = 0;
    for (var i = 3; i < px.length; i += 4) {
      if (px[i] > maxAlpha) maxAlpha = px[i];
      if (px[i] > 0) touched++;
    }
    expect(maxAlpha, lessThanOrEqualTo((255 * 0.12).ceil()));
    expect(touched, greaterThan(px.length ~/ 4 ~/ 4)); // plenty of fine grain
    // Premultiplied: no channel may exceed alpha.
    for (var i = 0; i < px.length; i += 4) {
      expect(px[i], lessThanOrEqualTo(px[i + 3]));
      expect(px[i + 1], lessThanOrEqualTo(px[i + 3]));
      expect(px[i + 2], lessThanOrEqualTo(px[i + 3]));
    }
  });

  test('stronger paper has more visible grain', () {
    int sum(Uint8List p) {
      var s = 0;
      for (var i = 3; i < p.length; i += 4) {
        s += p[i];
      }
      return s;
    }

    expect(sum(PaperTexture.pixels(seed: 2, strength: 1)), greaterThan(sum(PaperTexture.pixels(seed: 2, strength: 0.3))));
  });

  testWidgets('the tile is generated once into a shared image', (tester) async {
    // The decode callback needs the real event loop, so everything runs in
    // runAsync (a future created in the fake-async zone would never complete).
    await tester.runAsync(() async {
      PaperTexture.debugClearCache();
      final first = PaperTexture.load(seed: 9, strength: 0.5);
      final again = PaperTexture.load(seed: 9, strength: 0.5);
      expect(identical(first, again), isTrue);
      final img = await first.timeout(const Duration(seconds: 20));
      expect(img.width, PaperTexture.tileSize);
      expect(img.height, PaperTexture.tileSize);
    });
  });

  test('options compare by value', () {
    expect(const PaperOptions(), const PaperOptions());
    expect(const PaperOptions(seed: 1), isNot(const PaperOptions(seed: 2)));
    expect(const PaperOptions(tint: Color(0xFF000000)).hashCode, const PaperOptions(tint: Color(0xFF000000)).hashCode);
  });
}
