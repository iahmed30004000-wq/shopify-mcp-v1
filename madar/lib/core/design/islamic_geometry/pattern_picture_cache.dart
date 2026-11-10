import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'pattern_geometry.dart';

/// Recorded-picture cache shared by every painter in this folder.
///
/// A painter builds a `config` once (a Dart record: structural `==`, no
/// per-frame allocation) and on each paint calls [find]; only the first
/// paint at a given size records the [ui.Picture]. Lookups scan a short list
/// comparing fields, so a repeat paint allocates nothing.
abstract final class PatternPictureCache {
  static const int _capacity = 48;
  static final List<_Entry> _entries = <_Entry>[];

  /// Pictures recorded so far / lookups answered from the cache (tests).
  static int builds = 0;
  static int hits = 0;

  static ui.Picture? find(Object config, Size size) {
    final w = size.width, h = size.height;
    for (var i = _entries.length - 1; i >= 0; i--) {
      final e = _entries[i];
      if (e.w == w && e.h == h && (identical(e.config, config) || e.config == config)) {
        hits++;
        return e.picture;
      }
    }
    return null;
  }

  /// Records [paint] into a picture, stores and returns it.
  static ui.Picture record(Object config, Size size, void Function(Canvas canvas) paint) {
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder, Offset.zero & size));
    final picture = recorder.endRecording();
    builds++;
    if (_entries.length >= _capacity) _entries.removeAt(0);
    _entries.add(_Entry(config, size.width, size.height, picture));
    return picture;
  }

  @visibleForTesting
  static void debugReset() {
    _entries.clear();
    builds = 0;
    hits = 0;
  }
}

class _Entry {
  _Entry(this.config, this.w, this.h, this.picture);
  final Object config;
  final double w, h;
  final ui.Picture picture;
}

/// Translations of the lattice that put a copy of [g] anywhere inside
/// [area] (culled by the cell's bounding box), as one [ui.Path] in pixels.
///
/// [cell] is the pixel length of the first translation vector; [origin] the
/// pixel position of lattice point (0, 0).
///
/// Copies whose box lies wholly inside [hole] are skipped (a frame never
/// draws them).
ui.Path buildTiledPath(
  PatternGeometry g, {
  required Rect area,
  required double cell,
  required Offset origin,
  Rect? hole,
}) {
  final one = ui.Path();
  for (final line in g.lines) {
    final pts = line.points;
    one.moveTo(pts.first.x * cell, pts.first.y * cell);
    for (var i = 1; i < pts.length; i++) {
      one.lineTo(pts[i].x * cell, pts[i].y * cell);
    }
    one.close();
  }

  final t1 = g.translation1, t2 = g.translation2;
  final det = t1.cross(t2);
  final all = ui.Path();
  if (det.abs() < 1e-9 || cell <= 0 || area.isEmpty) return all;

  // Lattice coordinates of the area corners (inverse of [t1 t2]).
  double iOf(double x, double y) => (x * t2.y - y * t2.x) / det;
  double jOf(double x, double y) => (-x * t1.y + y * t1.x) / det;
  final cs = [area.topLeft, area.topRight, area.bottomLeft, area.bottomRight];
  var iMin = double.infinity, iMax = -double.infinity, jMin = double.infinity, jMax = -double.infinity;
  for (final c in cs) {
    final x = (c.dx - origin.dx) / cell, y = (c.dy - origin.dy) / cell;
    iMin = math.min(iMin, iOf(x, y));
    iMax = math.max(iMax, iOf(x, y));
    jMin = math.min(jMin, jOf(x, y));
    jMax = math.max(jMax, jOf(x, y));
  }
  // The geometry overhangs its lattice point by up to ~one cell.
  final pad = 2;
  final i0 = iMin.floor() - pad, i1 = iMax.ceil() + pad;
  final j0 = jMin.floor() - pad, j1 = jMax.ceil() + pad;
  final bbox = Rect.fromLTRB(g.minX * cell, g.minY * cell, g.maxX * cell, g.maxY * cell);
  for (var i = i0; i <= i1; i++) {
    for (var j = j0; j <= j1; j++) {
      final dx = origin.dx + (t1.x * i + t2.x * j) * cell;
      final dy = origin.dy + (t1.y * i + t2.y * j) * cell;
      final box = bbox.shift(Offset(dx, dy));
      if (!box.overlaps(area)) continue;
      if (hole != null && box.left >= hole.left && box.right <= hole.right && box.top >= hole.top && box.bottom <= hole.bottom) {
        continue;
      }
      all.addPath(one, Offset(dx, dy));
    }
  }
  return all;
}

/// Cell length in px so a tile of [spec] fills [width] with
/// `repeat` cells, but never more than [maxCells] cells in [area].
double effectiveCellPx(PatternGeometry g, double width, double height, int repeat, {int maxCells = 5000}) {
  final base = width / repeat;
  final cellsAtBase = (width * height) / (base * base * g.cellArea);
  if (cellsAtBase <= maxCells) return base;
  return math.sqrt(width * height / (maxCells * g.cellArea));
}
