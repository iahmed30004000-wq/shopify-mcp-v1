import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/kids/colouring/domain/flood_fill.dart';

const int _rose = 0xFFE26A89;
const int _teal = 0xFF2FA59C;

/// A white page with helpers to draw black lines.
class _Page {
  _Page(this.w, this.h) : grey = Uint8List(w * h)..fillRange(0, w * h, 255);

  final int w, h;
  final Uint8List grey;

  void set(int x, int y, int v) {
    if (x >= 0 && y >= 0 && x < w && y < h) grey[y * w + x] = v;
  }

  /// A rectangle outline [t] pixels thick.
  void box(int x0, int y0, int x1, int y1, {int t = 1}) {
    for (var k = 0; k < t; k++) {
      for (var x = x0; x <= x1; x++) {
        set(x, y0 + k, 0);
        set(x, y1 - k, 0);
      }
      for (var y = y0; y <= y1; y++) {
        set(x0 + k, y, 0);
        set(x1 - k, y, 0);
      }
    }
  }

  LineArt get art => LineArt(w, h, grey);
}

int _at(ColourCanvas c, int x, int y) => c.colours[y * c.width + x];

void main() {
  group('regions', () {
    test('a tap fills the shape it is in, up to the lines, and nothing outside', () {
      final page = _Page(40, 40)..box(10, 10, 29, 29);
      final c = ColourCanvas(page.art);
      final n = c.fill(20, 20, _rose);
      expect(n, greaterThan(0));
      expect(_at(c, 20, 20), _rose);
      expect(_at(c, 11, 11), _rose, reason: 'right up to the line');
      expect(_at(c, 5, 5), ColourCanvas.paper, reason: 'outside the box');
      expect(_at(c, 10, 10), ColourCanvas.paper, reason: 'the line itself is never painted');
      expect(c.isLine(10, 10), isTrue);
      // the painted pixel count is exactly the 18 x 18 inside
      expect(n, 18 * 18);
    });

    test('two rooms separated by a wall are filled one at a time', () {
      final page = _Page(40, 20)..box(2, 2, 37, 17);
      for (var y = 2; y <= 17; y++) {
        page.set(20, y, 0);
      }
      final c = ColourCanvas(page.art);
      c.fill(5, 10, _rose);
      expect(_at(c, 5, 10), _rose);
      expect(_at(c, 30, 10), ColourCanvas.paper);
      c.fill(30, 10, _teal);
      expect(_at(c, 30, 10), _teal);
      expect(_at(c, 5, 10), _rose, reason: 'the first room keeps its colour');
    });

    test('a region touching the picture edge fills without running off it', () {
      final page = _Page(16, 16);
      final c = ColourCanvas(page.art);
      expect(c.fill(0, 0, _rose), 256);
      expect(c.fill(15, 15, _teal), 256, reason: 'refilling a whole page just recolours it');
      expect(_at(c, 7, 7), _teal);
    });

    test('taps outside the picture do nothing and record nothing', () {
      final c = ColourCanvas(_Page(10, 10).art);
      for (final p in [(-1, 0), (0, -1), (10, 0), (0, 10), (99, 99)]) {
        expect(c.fill(p.$1, p.$2, _rose), 0);
      }
      expect(c.ops, isEmpty);
    });

    test('a tap that lands on a thick line moves to the nearest region instead', () {
      final page = _Page(40, 40)..box(10, 10, 29, 29, t: 4);
      final c = ColourCanvas(page.art);
      expect(c.isLine(13, 20), isTrue);
      final n = c.fill(13, 20, _rose); // on the inner half of the left line (nearest paper is inside)
      expect(n, greaterThan(0));
      expect(_at(c, 20, 20), _rose);
      expect(_at(c, 5, 5), ColourCanvas.paper);
    });

    test('a tap far from any region (inside a solid block) does nothing', () {
      final page = _Page(40, 40);
      for (var y = 5; y < 35; y++) {
        for (var x = 5; x < 35; x++) {
          page.set(x, y, 0);
        }
      }
      final c = ColourCanvas(page.art);
      expect(c.fill(20, 20, _rose), 0);
      expect(c.ops, isEmpty);
    });
  });

  group('tolerance', () {
    // A page whose grey fades from 255 (left) to 156 (right), one step per column.
    LineArt fade() {
      final p = _Page(100, 4);
      for (var x = 0; x < 100; x++) {
        for (var y = 0; y < 4; y++) {
          p.set(x, y, 255 - x);
        }
      }
      return p.art;
    }

    test('a small tolerance fills only the similar part', () {
      final c = ColourCanvas(fade(), tolerance: 10, gapClosing: 0);
      c.fill(0, 1, _rose);
      expect(_at(c, 10, 1), _rose);
      expect(_at(c, 11, 1), ColourCanvas.paper);
      expect(_at(c, 99, 1), ColourCanvas.paper);
    });

    test('a large tolerance fills the whole gradient', () {
      final c = ColourCanvas(fade(), tolerance: 120, gapClosing: 0);
      c.fill(0, 1, _rose);
      expect(_at(c, 99, 1), _rose);
    });

    test('the tolerance is measured from the tapped pixel, so tapping the other end differs', () {
      final c = ColourCanvas(fade(), tolerance: 10, gapClosing: 0);
      c.fill(99, 1, _rose);
      expect(_at(c, 90, 1), _rose);
      expect(_at(c, 0, 1), ColourCanvas.paper);
    });

    test('soft grey edges (above the line threshold) stay part of the picture and are shaded, not whitened', () {
      final p = _Page(30, 10);
      for (var y = 0; y < 10; y++) {
        p.set(15, y, 140); // a faint line, lighter than the threshold 128
      }
      final c = ColourCanvas(p.art, tolerance: 60, gapClosing: 0);
      c.fill(2, 5, _rose);
      final rgba = c.toRgba();
      // the faint line pixel is multiplied: still dark-ish, not pure rose
      final i = (5 * 30 + 15) * 4;
      expect(rgba[i], lessThan(0xE2));
    });
  });

  group('leaks and 1-pixel gaps', () {
    LineArt boxWithGap(int gap) {
      final page = _Page(60, 60)..box(10, 10, 49, 49);
      // open [gap] pixels in the right wall
      for (var k = 0; k < gap; k++) {
        page.set(49, 30 + k, 255);
      }
      return page.art;
    }

    test('a closed box does not leak', () {
      final page = _Page(60, 60)..box(10, 10, 49, 49);
      final c = ColourCanvas(page.art, gapClosing: 0);
      c.fill(30, 30, _rose);
      expect(_at(c, 2, 2), ColourCanvas.paper);
    });

    test('a 1-pixel gap LEAKS when gap closing is off (the problem)', () {
      final c = ColourCanvas(boxWithGap(1), gapClosing: 0);
      c.fill(30, 30, _rose);
      expect(_at(c, 2, 2), _rose);
    });

    test('a 1-pixel gap does NOT leak with the default gap closing', () {
      final c = ColourCanvas(boxWithGap(1));
      c.fill(30, 30, _rose);
      expect(_at(c, 2, 2), ColourCanvas.paper, reason: 'outside stays paper');
      expect(_at(c, 30, 30), _rose);
      expect(_at(c, 11, 11), _rose);
      expect(_at(c, 48, 48), _rose, reason: 'colour reaches the real line (no white halo)');
    });

    test('a 2-pixel gap is sealed by gap closing 1, a 5-pixel gap is not', () {
      final two = ColourCanvas(boxWithGap(2));
      two.fill(30, 30, _rose);
      expect(_at(two, 2, 2), ColourCanvas.paper);
      final five = ColourCanvas(boxWithGap(5));
      five.fill(30, 30, _rose);
      expect(_at(five, 2, 2), _rose, reason: 'a real opening is an opening');
    });

    test('with gap closing, no pixel next to an outline is left white inside a shape', () {
      final page = _Page(40, 40)..box(5, 5, 34, 34);
      final c = ColourCanvas(page.art);
      c.fill(20, 20, _rose);
      for (var y = 6; y <= 33; y++) {
        for (var x = 6; x <= 33; x++) {
          expect(_at(c, x, y), _rose, reason: '($x,$y)');
        }
      }
    });

    test('the colour does not cross a real line through the thickened band', () {
      final page = _Page(40, 20)..box(2, 2, 37, 17);
      for (var y = 2; y <= 17; y++) {
        page.set(20, y, 0);
      }
      final c = ColourCanvas(page.art);
      c.fill(5, 10, _rose);
      expect(_at(c, 19, 10), _rose);
      expect(_at(c, 21, 10), ColourCanvas.paper);
    });
  });

  group('undo, replay, eraser', () {
    test('undo takes back exactly the last fill; replay of the ops rebuilds the picture', () {
      final page = _Page(40, 20)..box(2, 2, 37, 17);
      for (var y = 2; y <= 17; y++) {
        page.set(20, y, 0);
      }
      final c = ColourCanvas(page.art);
      c.fill(5, 10, _rose);
      final afterFirst = Uint32List.fromList(c.colours);
      c.fill(30, 10, _teal);
      expect(c.canUndo, isTrue);
      expect(c.undo(), isTrue);
      expect(c.colours, afterFirst);
      expect(c.ops.length, 1);

      final fresh = ColourCanvas(page.art)..replay(c.ops);
      expect(fresh.colours, c.colours, reason: 'what is saved is what is restored');

      expect(c.undo(), isTrue);
      expect(c.undo(), isFalse);
      expect(c.colours.every((v) => v == ColourCanvas.paper), isTrue);
    });

    test('the eraser (paper) puts a region back and clear starts over', () {
      final page = _Page(20, 20)..box(2, 2, 17, 17);
      final c = ColourCanvas(page.art);
      c.fill(10, 10, _rose);
      c.fill(10, 10, ColourCanvas.paper);
      expect(_at(c, 10, 10), ColourCanvas.paper);
      c.fill(10, 10, _teal);
      c.clear();
      expect(c.ops, isEmpty);
      expect(c.colours.every((v) => v == ColourCanvas.paper), isTrue);
    });

    test('toRgba multiplies colour by the art: lines stay black, paper takes the colour', () {
      final page = _Page(20, 20)..box(2, 2, 17, 17);
      final c = ColourCanvas(page.art);
      c.fill(10, 10, _rose);
      final rgba = c.toRgba();
      int px(int x, int y) => (y * 20 + x) * 4;
      expect(rgba.sublist(px(2, 2), px(2, 2) + 4), [0, 0, 0, 255]);
      expect(rgba.sublist(px(10, 10), px(10, 10) + 4), [0xE2, 0x6A, 0x89, 255]);
      expect(rgba.sublist(px(0, 0), px(0, 0) + 4), [255, 255, 255, 255]);
    });
  });

  group('LineArt', () {
    test('fromRgba: luma, and transparency counts as paper', () {
      final rgba = Uint8List.fromList([
        0, 0, 0, 255, // black
        255, 255, 255, 255, // white
        0, 0, 0, 0, // transparent
        0, 0, 0, 128, // half black
      ]);
      final art = LineArt.fromRgba(rgba, 4, 1);
      expect(art.grey[0], 0);
      expect(art.grey[1], 255);
      expect(art.grey[2], 255);
      expect(art.grey[3], inInclusiveRange(120, 135));
    });

    test('cleaned makes near-white paper pure white and keeps ink', () {
      final art = LineArt(3, 1, Uint8List.fromList([0, 150, 230]));
      expect(art.cleaned().grey, [0, 150, 255]);
    });
  });

  group('performance (explicit stack, no recursion)', () {
    // Budgets are for the debug VM of the test runner on a shared CI machine:
    // generous, but a recursive or quadratic fill would blow through them.
    const budget = Duration(milliseconds: 2500);

    test('a blank 1024 x 1024 page (one region of 1,048,576 pixels) fills within $budget', () {
      final c = ColourCanvas(_Page(1024, 1024).art);
      final sw = Stopwatch()..start();
      final n = c.fill(512, 512, _rose);
      sw.stop();
      // ignore: avoid_print
      print('blank 1024x1024 fill: ${sw.elapsedMilliseconds} ms');
      expect(n, 1024 * 1024);
      expect(sw.elapsed, lessThan(budget), reason: 'took ${sw.elapsedMilliseconds} ms');
    });

    test('a 1024 x 1024 serpentine maze (a single 1-pixel-wide path, the stack stress case) fills within $budget', () {
      final page = _Page(1024, 1024);
      // horizontal walls every 4th row with a hole alternating left/right
      for (var y = 3, k = 0; y < 1020; y += 4, k++) {
        for (var x = 0; x < 1024; x++) {
          page.set(x, y, 0);
        }
        page.set(k.isEven ? 1020 : 3, y, 255);
        page.set(k.isEven ? 1021 : 4, y, 255);
        page.set(k.isEven ? 1022 : 5, y, 255);
        page.set(k.isEven ? 1023 : 6, y, 255);
      }
      final c = ColourCanvas(page.art, gapClosing: 0);
      final sw = Stopwatch()..start();
      final n = c.fill(1, 1, _rose);
      sw.stop();
      // ignore: avoid_print
      print('serpentine 1024x1024 fill: ${sw.elapsedMilliseconds} ms');
      expect(n, greaterThan(500000));
      expect(sw.elapsed, lessThan(budget), reason: 'took ${sw.elapsedMilliseconds} ms');
    });

    test('a 1024 x 1024 page of 16 x 16 cells: fill one cell, then replay 40 fills, within $budget', () {
      final page = _Page(1024, 1024);
      for (var i = 0; i < 1024; i += 64) {
        for (var j = 0; j < 1024; j++) {
          page.set(i, j, 0);
          page.set(j, i, 0);
        }
      }
      final c = ColourCanvas(page.art);
      final sw = Stopwatch()..start();
      for (var k = 0; k < 40; k++) {
        c.fill(10 + 64 * (k % 16), 10 + 64 * (k ~/ 16), k.isEven ? _rose : _teal);
      }
      final fresh = ColourCanvas(page.art)..replay(c.ops);
      sw.stop();
      expect(fresh.colours, c.colours);
      expect(sw.elapsed, lessThan(budget * 2), reason: 'took ${sw.elapsedMilliseconds} ms');
    });
  });
}
