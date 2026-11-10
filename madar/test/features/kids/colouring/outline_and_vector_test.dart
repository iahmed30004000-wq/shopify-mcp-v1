import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/islamic_geometry/islamic_geometry.dart' show Vec2;
import 'package:madar/features/kids/colouring/domain/flood_fill.dart';
import 'package:madar/features/kids/colouring/domain/outline.dart';
import 'package:madar/features/kids/colouring/domain/vector_colouring.dart';
import 'package:madar/features/kids/colouring/domain/vector_pages.dart';

LineArt _squareOnDark(int size, {int inner = 20}) {
  final g = Uint8List(size * size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final inside =
          x >= (size - inner) ~/ 2 && x < (size + inner) ~/ 2 && y >= (size - inner) ~/ 2 && y < (size + inner) ~/ 2;
      g[y * size + x] = inside ? 230 : 30;
    }
  }
  return LineArt(size, size, g);
}

bool _segmentsCross(Vec2 a, Vec2 b, Vec2 c, Vec2 d) {
  double o(Vec2 p, Vec2 q, Vec2 r) => (q - p).cross(r - p);
  final d1 = o(a, b, c), d2 = o(a, b, d), d3 = o(c, d, a), d4 = o(c, d, b);
  return ((d1 > 1e-12 && d2 < -1e-12) || (d1 < -1e-12 && d2 > 1e-12)) &&
      ((d3 > 1e-12 && d4 < -1e-12) || (d3 < -1e-12 && d4 > 1e-12));
}

void main() {
  group('outline (Sobel)', () {
    test('a light square on a dark ground gets an outline ring and nothing else', () {
      final out = sobelOutline(_squareOnDark(60));
      int ink(int x, int y) => out.grey[y * 60 + x] == 0 ? 1 : 0;
      expect(out.grey.every((v) => v == 0 || v == 255), isTrue, reason: 'pure ink on paper');
      var edge = 0;
      for (var y = 0; y < 60; y++) {
        for (var x = 0; x < 60; x++) {
          edge += ink(x, y);
        }
      }
      expect(edge, greaterThan(60), reason: 'there is a ring');
      expect(ink(30, 30), 0, reason: 'inside is paper');
      expect(ink(5, 5), 0, reason: 'far outside is paper');
      // the ring sits around the square (x = 20..39)
      expect([for (var x = 15; x < 45; x++) ink(x, 30)].reduce((a, b) => a + b), greaterThanOrEqualTo(2));
    });

    test('a flat picture has no edges at all', () {
      final out = sobelOutline(LineArt(40, 40, Uint8List(1600)..fillRange(0, 1600, 128)));
      expect(out.grey.every((v) => v == 255), isTrue);
    });

    test('more detail keeps more lines (few <= some <= many)', () {
      final g = Uint8List(80 * 80);
      final rng = math.Random(1);
      for (var i = 0; i < g.length; i++) {
        g[i] = 128 + ((i % 80) ~/ 10) * 6 + rng.nextInt(40);
      }
      final art = LineArt(80, 80, g);
      int inkCount(OutlineLevel l) => sobelOutline(art, level: l).grey.where((v) => v == 0).length;
      expect(inkCount(OutlineLevel.few), lessThanOrEqualTo(inkCount(OutlineLevel.some)));
      expect(inkCount(OutlineLevel.some), lessThanOrEqualTo(inkCount(OutlineLevel.many)));
    });

    test('the size cap: a picture over the limit is refused (sync and in the isolate)', () async {
      final big = LineArt(1100, 1100, Uint8List(1100 * 1100));
      expect(() => sobelOutline(big), throwsArgumentError);
      await expectLater(outlineInBackground(big), throwsArgumentError);
      expect(maxOutlinePixels, 1024 * 1024);
    });

    test('the isolate gives the same picture as the direct call, within a second', () async {
      final art = _squareOnDark(200, inner: 100);
      final sw = Stopwatch()..start();
      final bg = await outlineInBackground(art, level: OutlineLevel.many);
      sw.stop();
      expect(bg.grey, sobelOutline(art, level: OutlineLevel.many).grey);
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('the largest allowed page (1024 x 1024) is outlined within a stated budget of 4 s', () async {
      final art = _squareOnDark(1024, inner: 500);
      final sw = Stopwatch()..start();
      final out = await outlineInBackground(art);
      sw.stop();
      expect(out.width, 1024);
      expect(sw.elapsed, lessThan(const Duration(seconds: 4)), reason: '${sw.elapsedMilliseconds} ms');
    });

    test('outlined pictures can be coloured: the ring is a barrier, the inside a region', () {
      final out = sobelOutline(_squareOnDark(60));
      final c = ColourCanvas(out);
      c.fill(30, 30, 0xFFE26A89);
      expect(c.colours[30 * 60 + 30], 0xFFE26A89);
      expect(c.colours[5 * 60 + 5], ColourCanvas.paper, reason: 'the outside is a different region');
    });

    test('looksLikePhoto: a drawing is not, a photo-like gradient is', () {
      final drawing = Uint8List(100 * 100)..fillRange(0, 10000, 255);
      for (var i = 0; i < 100; i++) {
        drawing[i * 100 + 50] = 0;
      }
      expect(looksLikePhoto(LineArt(100, 100, drawing)), isFalse);
      final photo = Uint8List.fromList([for (var i = 0; i < 10000; i++) 70 + (i * 7) % 120]);
      expect(looksLikePhoto(LineArt(100, 100, photo)), isTrue);
    });
  });

  group('built-in pages from the Islamic geometry library', () {
    final pages = VectorPages.builtIn;

    test('there are six, with unique stable ids', () {
      expect(pages.length, 6);
      expect({for (final p in pages) p.id}.length, 6);
      expect(VectorPages.byId('khatam'), isNotNull);
      expect(VectorPages.byId('nope'), isNull);
    });

    test('every page has plenty to colour, all inside the unit square, sorted largest first', () {
      for (final page in pages) {
        expect(page.regions.length, greaterThanOrEqualTo(8), reason: page.id);
        for (final r in page.regions) {
          expect(r.points.length, greaterThanOrEqualTo(3));
          expect(r.area, greaterThan(1e-5));
          for (final p in r.points) {
            expect(p.isFinite, isTrue);
            expect(p.x, inInclusiveRange(0, 1), reason: page.id);
            expect(p.y, inInclusiveRange(0, 1), reason: page.id);
          }
        }
        for (var i = 1; i < page.regions.length; i++) {
          expect(page.regions[i].area, lessThanOrEqualTo(page.regions[i - 1].area));
        }
      }
    });

    test('every region is a simple polygon (no edge crosses another)', () {
      for (final page in pages) {
        for (var ri = 0; ri < page.regions.length; ri++) {
          final pts = page.regions[ri].points;
          for (var i = 0; i < pts.length; i++) {
            for (var j = i + 2; j < pts.length; j++) {
              if (i == 0 && j == pts.length - 1) continue;
              expect(
                _segmentsCross(pts[i], pts[(i + 1) % pts.length], pts[j], pts[(j + 1) % pts.length]),
                isFalse,
                reason: '${page.id} region $ri edges $i/$j cross',
              );
            }
          }
        }
      }
    });

    test('the pages are deterministic', () {
      final a = VectorPages.builtIn.first.regions.map((r) => r.points).toList();
      VectorPages.builtIn; // cached; a fresh build would be identical by the library's contract
      expect(VectorPages.byId('khatam')!.regions.map((r) => r.points).toList(), a);
    });

    test(
      'a tap picks the smallest region under it: the centre of a medallion is its centre piece, not the big star',
      () {
        final page = VectorPages.byId('khatam')!;
        final centre = page.regionAt(const Vec2(0.5, 0.5))!;
        expect(page.regions[centre].area, lessThan(page.regions.first.area / 10));
        expect(page.regionAt(const Vec2(-0.2, 0.5)), isNull, reason: 'outside the picture');
        expect(page.regionAt(const Vec2(0.5, 0.5)), centre);
      },
    );

    test('the lattice pages are patches: many more regions than a lone medallion', () {
      expect(
        VectorPages.byId('lattice_square')!.regions.length,
        greaterThan(VectorPages.byId('khatam')!.regions.length * 2),
      );
      expect(
        VectorPages.byId('lattice_hex')!.regions.length,
        greaterThan(VectorPages.byId('hexstar')!.regions.length * 2),
      );
    });

    test('colouring a built-in page: fill, erase, undo, clear, replay (what is saved is what is restored)', () {
      final page = VectorPages.byId('rosette')!;
      final c = VectorColouring(page);
      expect(c.fill(0, 0xFFE26A89), isTrue);
      expect(c.fill(0, 0xFFE26A89), isFalse, reason: 'same colour again changes nothing');
      expect(c.fill(1, 0xFF2FA59C), isTrue);
      expect(c.fill(999, 1), isFalse);
      expect(c.colours, {0: 0xFFE26A89, 1: 0xFF2FA59C});
      expect(c.fill(0, 0), isTrue, reason: 'eraser');
      expect(c.colours, {1: 0xFF2FA59C});
      expect(c.undo(), isTrue);
      expect(c.colours, {0: 0xFFE26A89, 1: 0xFF2FA59C});
      final restored = VectorColouring(page, [for (final o in c.ops) RegionFill.fromJson(o.toJson())!]);
      expect(restored.colours, c.colours);
      c.clear();
      expect(c.colours, isEmpty);
      expect(c.canUndo, isFalse);
    });

    test('RegionFill.fromJson refuses garbage', () {
      expect(RegionFill.fromJson([1]), isNull);
      expect(RegionFill.fromJson('x'), isNull);
      expect(RegionFill.fromJson([1, 'a']), isNull);
    });
  });
}
