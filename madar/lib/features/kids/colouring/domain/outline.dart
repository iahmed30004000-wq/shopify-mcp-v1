// Turning a photograph into something a child can colour: an outline.
//
// Deliberately simple and bounded: a 3 x 3 blur, a Sobel edge filter, a
// threshold, a speck filter and one pixel of thickening. It runs in a
// separate isolate (see [outlineInBackground]) and refuses pictures bigger
// than [maxOutlinePixels], so a huge file can never freeze the phone.
import 'dart:isolate';
import 'dart:typed_data';

import 'flood_fill.dart';

/// How many lines the outline keeps.
enum OutlineLevel {
  few(90),
  some(55),
  many(32);

  const OutlineLevel(this.threshold);

  /// Edge strength (0-255) above which a pixel becomes ink.
  final int threshold;
}

/// The longest side a picture is brought down to before it becomes a page.
const int kMaxPictureSide = 1024;

/// The most pixels the edge filter will touch (a page is at most 1024 x 1024).
const int maxOutlinePixels = kMaxPictureSide * kMaxPictureSide;

/// True when [art] looks like a photograph or a shaded picture rather than a
/// line drawing: a drawing is almost only ink and paper, a photo is mostly
/// middle greys.
bool looksLikePhoto(LineArt art) {
  final g = art.grey;
  var mid = 0;
  for (var i = 0; i < g.length; i++) {
    if (g[i] > 60 && g[i] < 200) mid++;
  }
  return mid / g.length > 0.30;
}

/// The Sobel outline of [src]: black ink on white paper.
LineArt sobelOutline(LineArt src, {OutlineLevel level = OutlineLevel.some}) {
  final w = src.width, h = src.height;
  if (w * h > maxOutlinePixels) {
    throw ArgumentError('picture too big for the outline filter: ${w}x$h');
  }
  final blur = _boxBlur(src.grey, w, h);
  final ink = Uint8List(w * h);
  final t = level.threshold;
  for (var y = 1; y < h - 1; y++) {
    final r0 = (y - 1) * w, r1 = y * w, r2 = (y + 1) * w;
    for (var x = 1; x < w - 1; x++) {
      final a = blur[r0 + x - 1], b = blur[r0 + x], c = blur[r0 + x + 1];
      final d = blur[r1 + x - 1], f = blur[r1 + x + 1];
      final g = blur[r2 + x - 1], hh = blur[r2 + x], i = blur[r2 + x + 1];
      final gx = (c + 2 * f + i) - (a + 2 * d + g);
      final gy = (g + 2 * hh + i) - (a + 2 * b + c);
      // |gx| + |gy| is at most 2040 for 8-bit input; scale to 0..255.
      final mag = ((gx < 0 ? -gx : gx) + (gy < 0 ? -gy : gy)) >> 2;
      if (mag >= t) ink[r1 + x] = 1;
    }
  }
  _removeSpecks(ink, w, h);
  final thick = _thicken(ink, w, h);
  final out = Uint8List(w * h);
  for (var i = 0; i < out.length; i++) {
    out[i] = thick[i] == 1 ? 0 : 255;
  }
  return LineArt(w, h, out);
}

/// [sobelOutline] on a background isolate.
Future<LineArt> outlineInBackground(LineArt src, {OutlineLevel level = OutlineLevel.some}) {
  if (src.width * src.height > maxOutlinePixels) {
    return Future.error(ArgumentError('picture too big for the outline filter'));
  }
  final w = src.width, h = src.height;
  final grey = TransferableTypedData.fromList([src.grey]);
  return Isolate.run(() {
    final bytes = grey.materialize().asUint8List();
    return sobelOutline(LineArt(w, h, bytes), level: level).grey;
  }).then((g) => LineArt(w, h, g));
}

Uint8List _boxBlur(Uint8List g, int w, int h) {
  final out = Uint8List.fromList(g);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      var s = 0;
      for (var dy = -1; dy <= 1; dy++) {
        final row = (y + dy) * w + x;
        s += g[row - 1] + g[row] + g[row + 1];
      }
      out[y * w + x] = s ~/ 9;
    }
  }
  return out;
}

/// Ink pixels with no ink neighbour at all are noise, not drawing.
void _removeSpecks(Uint8List ink, int w, int h) {
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      if (ink[i] == 0) continue;
      var n = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if ((dx != 0 || dy != 0) && ink[i + dy * w + dx] == 1) n++;
        }
      }
      if (n == 0) ink[i] = 0;
    }
  }
}

Uint8List _thicken(Uint8List ink, int w, int h) {
  final out = Uint8List.fromList(ink);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (ink[i] == 1) continue;
      if ((x > 0 && ink[i - 1] == 1) ||
          (x < w - 1 && ink[i + 1] == 1) ||
          (y > 0 && ink[i - w] == 1) ||
          (y < h - 1 && ink[i + w] == 1)) {
        out[i] = 1;
      }
    }
  }
  return out;
}
