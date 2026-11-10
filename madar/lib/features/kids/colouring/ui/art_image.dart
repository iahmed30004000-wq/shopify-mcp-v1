// Turning grey pages and coloured layers into pictures the screen can paint.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../domain/flood_fill.dart';

/// An opaque picture from straight RGBA bytes. The caller disposes it.
Future<ui.Image> imageFromRgba(Uint8List rgba, int width, int height) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

/// A grey page as a picture, at most [maxSide] pixels on its longest side
/// (thumbnails are small, the preview a little bigger).
Future<ui.Image> imageFromArt(LineArt art, {int maxSide = 1024}) {
  final step = ([art.width, art.height].reduce((a, b) => a > b ? a : b) / maxSide).ceil().clamp(1, 64);
  final w = (art.width / step).ceil(), h = (art.height / step).ceil();
  final rgba = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // Darkest pixel of the block, so thin lines survive a thumbnail.
      var v = 255;
      for (var dy = 0; dy < step; dy++) {
        final sy = y * step + dy;
        if (sy >= art.height) break;
        for (var dx = 0; dx < step; dx++) {
          final sx = x * step + dx;
          if (sx >= art.width) break;
          final g = art.grey[sy * art.width + sx];
          if (g < v) v = g;
        }
      }
      final o = (y * w + x) * 4;
      rgba[o] = v;
      rgba[o + 1] = v;
      rgba[o + 2] = v;
      rgba[o + 3] = 255;
    }
  }
  return imageFromRgba(rgba, w, h);
}
