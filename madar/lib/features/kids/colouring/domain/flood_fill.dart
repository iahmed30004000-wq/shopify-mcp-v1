// The colouring engine for pictures: grey line art in, flat colour out.
//
// Pure Dart (no Flutter, no dart:ui) so it is easy to test and to run off the
// UI isolate. The idea:
//  * the picture is a grey image ([LineArt]); dark pixels are LINES, they are
//    never painted over, so the outline stays crisp;
//  * a tap fills the connected region around it with a flat colour, using an
//    explicit stack of scan-line spans (never recursion, so a 1024 x 1024
//    blank page cannot overflow the stack);
//  * what is shown is the colour layer MULTIPLIED by the grey art, so the
//    anti-aliased edge of every line is kept and no white halo appears;
//  * "gap closing" thickens the lines for the fill only, so a hole one or two
//    pixels wide in a line does not let the colour leak out of its shape.
//
// Undo is a replay: the colour layer is the result of a list of fills
// ([FillOp]s), which is also exactly what is saved on the device.
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;

/// A grey picture: 0 is black ink, 255 is paper.
class LineArt {
  LineArt(this.width, this.height, this.grey) : assert(width > 0 && height > 0), assert(grey.length == width * height);

  final int width, height;
  final Uint8List grey;

  /// Grey values from straight RGBA bytes (alpha composited over white, so a
  /// transparent PNG with black lines becomes black lines on paper).
  factory LineArt.fromRgba(Uint8List rgba, int width, int height) {
    assert(rgba.length >= width * height * 4);
    final g = Uint8List(width * height);
    for (var i = 0, p = 0; i < g.length; i++, p += 4) {
      final a = rgba[p + 3];
      // Rec. 601 luma in integer maths.
      final lum = (rgba[p] * 299 + rgba[p + 1] * 587 + rgba[p + 2] * 114) ~/ 1000;
      g[i] = a == 255 ? lum : (lum * a + 255 * (255 - a)) ~/ 255;
    }
    return LineArt(width, height, g);
  }

  /// A fresh copy where every pixel lighter than [whiten] becomes pure paper:
  /// scanner noise and a slightly grey page stop being "regions".
  LineArt cleaned({int whiten = 200}) {
    final g = Uint8List.fromList(grey);
    for (var i = 0; i < g.length; i++) {
      if (g[i] >= whiten) g[i] = 255;
    }
    return LineArt(width, height, g);
  }
}

/// One fill: tap at ([x], [y]) with [argb] (0xFFFFFFFF = paper, the eraser).
@immutable
class FillOp {
  const FillOp(this.x, this.y, this.argb);

  final int x, y, argb;

  List<int> toJson() => [x, y, argb];

  static FillOp? fromJson(Object? j) {
    if (j is List && j.length == 3 && j.every((e) => e is int)) {
      return FillOp(j[0] as int, j[1] as int, j[2] as int);
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is FillOp && other.x == x && other.y == y && other.argb == argb;

  @override
  int get hashCode => Object.hash(x, y, argb);
}

/// What a tap on a picture can do.
class ColourCanvas {
  ColourCanvas(this.art, {this.lineThreshold = 128, this.tolerance = 90, this.gapClosing = 1, this.snapRadius = 6})
    : assert(gapClosing >= 0 && gapClosing <= 3),
      _line = Uint8List(art.width * art.height),
      _wall = Uint8List(art.width * art.height),
      _stamp = Uint32List(art.width * art.height),
      colours = Uint32List(art.width * art.height)..fillRange(0, art.width * art.height, paper) {
    final g = art.grey;
    for (var i = 0; i < g.length; i++) {
      if (g[i] < lineThreshold) _line[i] = 1;
    }
    _wall.setAll(0, _line);
    for (var k = 0; k < gapClosing; k++) {
      _dilate(_wall, art.width, art.height);
    }
    // Thickened but not really ink: the band the fill reaches into at the end.
    final band = <int>[];
    for (var i = 0; i < _wall.length; i++) {
      if (_wall[i] == 1 && _line[i] == 0) band.add(i);
    }
    _band = Int32List.fromList(band);
  }

  /// Unpainted: opaque white.
  static const int paper = 0xFFFFFFFF;

  final LineArt art;

  /// Grey below this is a line (never painted).
  final int lineThreshold;

  /// How far (0-255 grey levels) a pixel may differ from the tapped one and
  /// still count as the same region. High for clean line art, low for a
  /// picture with soft shading.
  final int tolerance;

  /// Lines are thickened by this many pixels for the fill only, so gaps up to
  /// 2 x [gapClosing] pixels wide do not leak.
  final int gapClosing;

  /// A tap that lands on a line is moved to the nearest region within this
  /// many pixels (small fingers, thick lines).
  final int snapRadius;

  /// The colour layer, ARGB per pixel, [paper] where nothing is painted.
  final Uint32List colours;

  late final Int32List _band;
  final Uint8List _line;
  final Uint8List _wall;
  final Uint32List _stamp;
  int _gen = 0;
  final List<FillOp> _ops = [];

  int get width => art.width;
  int get height => art.height;

  /// The fills that make up the current picture, oldest first.
  List<FillOp> get ops => List.unmodifiable(_ops);

  bool get canUndo => _ops.isNotEmpty;

  bool isLine(int x, int y) => _line[y * width + x] == 1;

  /// One step of 4-neighbour growth of the 1s in [m].
  static void _dilate(Uint8List m, int w, int h) {
    final src = Uint8List.fromList(m);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (src[i] == 1) continue;
        if ((x > 0 && src[i - 1] == 1) ||
            (x < w - 1 && src[i + 1] == 1) ||
            (y > 0 && src[i - w] == 1) ||
            (y < h - 1 && src[i + w] == 1)) {
          m[i] = 1;
        }
      }
    }
  }

  /// Fills the region at ([x], [y]) with [argb]. Returns the number of pixels
  /// painted; 0 means there was nothing to fill there (outside the picture or
  /// no region within [snapRadius]) and no operation is recorded.
  int fill(int x, int y, int argb) {
    final n = _fillAt(x, y, argb);
    if (n > 0) _ops.add(FillOp(x, y, argb));
    return n;
  }

  /// Takes the last fill back. False when there is nothing to undo.
  bool undo() {
    if (_ops.isEmpty) return false;
    final keep = _ops.sublist(0, _ops.length - 1);
    replay(keep);
    return true;
  }

  /// Starts again from paper.
  void clear() {
    colours.fillRange(0, colours.length, paper);
    _ops.clear();
  }

  /// Rebuilds the colour layer from [ops] (loading a saved picture, undo).
  void replay(List<FillOp> ops) {
    colours.fillRange(0, colours.length, paper);
    _ops.clear();
    for (final op in ops) {
      if (_fillAt(op.x, op.y, op.argb) > 0) _ops.add(op);
    }
  }

  /// The picture to show: colour layer x grey art, as straight RGBA bytes.
  Uint8List toRgba() {
    final out = Uint8List(width * height * 4);
    final g = art.grey;
    for (var i = 0, p = 0; i < g.length; i++, p += 4) {
      final c = colours[i];
      final k = g[i];
      out[p] = (((c >> 16) & 0xFF) * k) ~/ 255;
      out[p + 1] = (((c >> 8) & 0xFF) * k) ~/ 255;
      out[p + 2] = ((c & 0xFF) * k) ~/ 255;
      out[p + 3] = 255;
    }
    return out;
  }

  // ---- the fill itself ------------------------------------------------------

  int _seedIndex(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return -1;
    if (_wall[y * width + x] == 0) return y * width + x;
    // On a line (or its fill-only thickening): look for the closest paper.
    var best = -1;
    var bestD = 1 << 30;
    for (var r = 1; r <= snapRadius; r++) {
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          if (dx.abs() != r && dy.abs() != r) continue; // the ring only
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final i = ny * width + nx;
          if (_wall[i] == 1) continue;
          final d = dx * dx + dy * dy;
          if (d < bestD) {
            bestD = d;
            best = i;
          }
        }
      }
      if (best >= 0) return best;
    }
    return -1;
  }

  int _fillAt(int x, int y, int argb) {
    final seed = _seedIndex(x, y);
    if (seed < 0) return 0;
    final w = width, h = height;
    final grey = art.grey;
    final seedGrey = grey[seed];
    final tol = tolerance;
    final gen = ++_gen;
    final stamp = _stamp, wall = _wall, colours = this.colours;

    bool ok(int i) {
      if (stamp[i] == gen || wall[i] == 1) return false;
      final d = grey[i] - seedGrey;
      return (d < 0 ? -d : d) <= tol;
    }

    var count = 0;
    final stack = _IntStack()..push2(seed % w, seed ~/ w);
    while (stack.isNotEmpty) {
      final py = stack.pop();
      final px = stack.pop();
      final row = py * w;
      if (!ok(row + px)) continue;
      var l = px;
      while (l > 0 && ok(row + l - 1)) {
        l--;
      }
      var r = px;
      while (r < w - 1 && ok(row + r + 1)) {
        r++;
      }
      for (var i = l; i <= r; i++) {
        stamp[row + i] = gen;
        colours[row + i] = argb;
      }
      count += r - l + 1;
      for (final ny in [py - 1, py + 1]) {
        if (ny < 0 || ny >= h) continue;
        var inSpan = false;
        final nrow = ny * w;
        for (var i = l; i <= r; i++) {
          if (ok(nrow + i)) {
            if (!inSpan) {
              stack.push2(i, ny);
              inSpan = true;
            }
          } else {
            inSpan = false;
          }
        }
      }
    }

    // The thickened lines kept the colour 1 px short of the real line; reach
    // into that band (never across a real line, never beyond the band) so the
    // shape is fully coloured right up to its outline.
    // A corner pixel is two steps (not one) from the painted area, hence 2 x.
    final band = _band;
    for (var k = 0; k < gapClosing * 2; k++) {
      for (var b = 0; b < band.length; b++) {
        final j = band[b];
        if (stamp[j] == gen) continue;
        final px = j % w, py = j ~/ w;
        if ((px > 0 && stamp[j - 1] == gen) ||
            (px < w - 1 && stamp[j + 1] == gen) ||
            (py > 0 && stamp[j - w] == gen) ||
            (py < h - 1 && stamp[j + w] == gen)) {
          stamp[j] = gen;
          colours[j] = argb;
          count++;
        }
      }
    }
    return count;
  }
}

/// A growable stack of ints (two per entry): no recursion anywhere.
class _IntStack {
  Int32List _data = Int32List(1024);
  int _n = 0;

  bool get isNotEmpty => _n > 0;

  void push2(int a, int b) {
    if (_n + 2 > _data.length) {
      final bigger = Int32List(_data.length * 2)..setAll(0, _data);
      _data = bigger;
    }
    _data[_n++] = a;
    _data[_n++] = b;
  }

  int pop() => _data[--_n];
}
