import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size, TextDirection;

/// A disc on screen that a label must not cover.
typedef LabelObstacle = ({Offset center, double radius});

/// Where [LabelPlacer.placeBest] put a label: its [rect], the candidate
/// [slot] it came from (kept next frame while it stays valid – hysteresis),
/// whether it sits out on a [leader] line, and whether it is [clean] (clear
/// of every obstacle and label; false only when nothing clean existed and
/// the least-bad spot was taken instead of dropping the label).
typedef LabelSpot = ({Rect rect, int slot, bool leader, bool clean});

/// Places name labels next to their body (pure).
///
/// Candidates ("slots"), in order: centred **below** the body, centred
/// **above** it, beside it – first on the reading-end side (right in LTR,
/// left in RTL, so the text runs away from the world), then the other side –
/// and then the four **diagonals** (below-end, below-start, above-end,
/// above-start). [placeBest] adds the same eight directions again further
/// out, joined to the body by a leader line, and finally falls back to the
/// least-bad spot, so a label is never dropped.
///
/// A candidate must stay inside the [area] (default: the viewport minus
/// [margin]; above/below may slide sideways to fit), must not touch the
/// body's own disc (guaranteed by construction: it starts [gap] beyond
/// [clearance]) nor any obstacle disc, keep-out rect or label already
/// placed. Obstacles centred on [ignore] (the body's own disc) or
/// [ignoreAlso] (a front moon's world, which the moon already covers) are
/// skipped.
abstract final class LabelPlacer {
  /// Candidate slots per ring (below, above, end, start, four diagonals).
  static const int slotsPerRing = 8;

  /// First slot of the leader-line ring.
  static const int leaderSlot = slotsPerRing;

  /// How much farther out (× clearance, plus px) the leader ring sits.
  static const double leaderReach = 0.9, leaderExtra = 14;

  /// The first clean candidate of the inner ring, or null (strict: no
  /// leader lines, no fallback).
  static Rect? place({
    required Offset center,
    required double clearance,
    required Size size,
    required TextDirection direction,
    required Size viewport,
    Iterable<LabelObstacle> obstacles = const [],
    Iterable<Rect> taken = const [],
    Iterable<Rect> keepOut = const [],
    Rect? area,
    Offset? ignore,
    Offset? ignoreAlso,
    double gap = 5,
    double margin = 4,
  }) {
    final bounds = _bounds(area, viewport, margin);
    if (size.width > bounds.width || size.height > bounds.height) return null;
    for (var i = 0; i < slotsPerRing; i++) {
      final r = candidate(
        i,
        center: center,
        clearance: clearance,
        size: size,
        direction: direction,
        gap: gap,
        bounds: bounds,
      );
      if (_valid(r, bounds, obstacles, keepOut, taken, ignore, ignoreAlso)) return r;
    }
    return null;
  }

  /// Like [place], but never gives up: keeps an inner [previousSlot] while
  /// it is still clean (a label does not hop between spots as the camera
  /// drifts), then tries the inner ring, then keeps a clean leader-ring
  /// [previousSlot], then tries the leader ring, and finally takes the spot
  /// that overlaps the least.
  ///
  /// [stickiness] (0..1) is the hysteresis of the previous slot: it is kept
  /// (and reported clean) while what it overlaps stays under that fraction
  /// of the label's own area – a world brushing a label's corner for a
  /// moment does not send it hopping to the other side and back.
  static LabelSpot placeBest({
    required Offset center,
    required double clearance,
    required Size size,
    required TextDirection direction,
    required Size viewport,
    Iterable<LabelObstacle> obstacles = const [],
    Iterable<Rect> taken = const [],
    Iterable<Rect> keepOut = const [],
    Rect? area,
    Offset? ignore,
    Offset? ignoreAlso,
    double gap = 5,
    double margin = 4,
    int? previousSlot,
    bool leaders = true,
    double stickiness = 0,
  }) {
    final bounds = _bounds(area, viewport, margin);
    final slots = leaders ? 2 * slotsPerRing : slotsPerRing;
    Rect at(int i) =>
        candidate(i, center: center, clearance: clearance, size: size, direction: direction, gap: gap, bounds: bounds);
    bool valid(Rect r) => _valid(r, bounds, obstacles, keepOut, taken, ignore, ignoreAlso);
    final prev = previousSlot != null && previousSlot >= 0 && previousSlot < slots ? previousSlot : null;
    final prevRect = prev == null ? null : at(prev);
    final prevValid =
        prevRect != null &&
        (valid(prevRect) ||
            (stickiness > 0 &&
                _inside(prevRect, bounds) &&
                !_hitsRects(prevRect, keepOut, 0) &&
                !_hitsRects(prevRect, taken, 0) &&
                _cost(prevRect, bounds, obstacles, keepOut, taken, ignore, ignoreAlso) <=
                    stickiness * prevRect.width * prevRect.height));
    // Hysteresis within a ring: an inner spot is kept while clean; a label
    // out on a leader line comes back in as soon as an inner spot frees up.
    if (prevValid && prev! < leaderSlot) return (rect: prevRect, slot: prev, leader: false, clean: true);
    for (var i = 0; i < slotsPerRing; i++) {
      final r = at(i);
      if (valid(r)) return (rect: r, slot: i, leader: false, clean: true);
    }
    if (prevValid) return (rect: prevRect, slot: prev!, leader: true, clean: true);
    for (var i = slotsPerRing; i < slots; i++) {
      final r = at(i);
      if (valid(r)) return (rect: r, slot: i, leader: true, clean: true);
    }
    // Nothing clean: the least-bad spot (overlap area, off-area area), the
    // inner ring winning ties.
    var best = at(0);
    var bestSlot = 0;
    var bestCost = double.infinity;
    for (var i = 0; i < slots; i++) {
      final r = at(i);
      final cost = _cost(r, bounds, obstacles, keepOut, taken, ignore, ignoreAlso) * (i >= leaderSlot ? 1.15 : 1);
      if (cost < bestCost - 1e-6) {
        bestCost = cost;
        best = r;
        bestSlot = i;
      }
    }
    return (rect: best, slot: bestSlot, leader: bestSlot >= leaderSlot, clean: false);
  }

  /// Candidate [slot] (see the class docs) for a label of [size] beside a
  /// body at [center] with [clearance]. Above / below slide sideways to stay
  /// inside [bounds].
  static Rect candidate(
    int slot, {
    required Offset center,
    required double clearance,
    required Size size,
    required TextDirection direction,
    required double gap,
    required Rect bounds,
  }) {
    final w = size.width, h = size.height;
    final leader = slot >= slotsPerRing;
    final i = slot % slotsPerRing;
    final c = leader ? clearance * (1 + leaderReach) + leaderExtra : clearance;
    final endIsRight = direction == TextDirection.ltr;
    Rect r;
    switch (i) {
      case 0:
        r = Rect.fromLTWH(center.dx - w / 2, center.dy + c + gap, w, h);
      case 1:
        r = Rect.fromLTWH(center.dx - w / 2, center.dy - c - gap - h, w, h);
      case 2 || 3:
        final right = (i == 2) == endIsRight;
        r = right
            ? Rect.fromLTWH(center.dx + c + gap, center.dy - h / 2, w, h)
            : Rect.fromLTWH(center.dx - c - gap - w, center.dy - h / 2, w, h);
      default:
        // Diagonals: the label's near corner touches the circle of radius
        // c + gap at 45°.
        final below = i == 4 || i == 5;
        final end = i == 4 || i == 6;
        final right = end == endIsRight;
        final d = (c + gap) * math.sqrt1_2;
        final x = right ? center.dx + d : center.dx - d - w;
        final y = below ? center.dy + d : center.dy - d - h;
        r = Rect.fromLTWH(x, y, w, h);
    }
    if (i < 2) r = _slideInside(r, bounds);
    return r;
  }

  /// Whether rect [r] intersects the disc ([c], [radius]).
  static bool rectHitsDisc(Rect r, Offset c, double radius) {
    final nx = c.dx.clamp(r.left, r.right);
    final ny = c.dy.clamp(r.top, r.bottom);
    final dx = c.dx - nx, dy = c.dy - ny;
    return dx * dx + dy * dy < radius * radius;
  }

  /// Where a leader line from a label [rect] to a body at [center] with
  /// [clearance] starts and ends (the rect's nearest point → the body's rim).
  static (Offset, Offset) leaderLine(Rect rect, Offset center, double clearance) {
    final from = Offset(center.dx.clamp(rect.left, rect.right), center.dy.clamp(rect.top, rect.bottom));
    final v = from - center;
    final l = v.distance;
    final to = l < 1e-6 ? center : center + v / l * clearance;
    return (from, to);
  }

  static Rect _bounds(Rect? area, Size viewport, double margin) {
    final view = Rect.fromLTWH(margin, margin, viewport.width - 2 * margin, viewport.height - 2 * margin);
    final a = area;
    if (a == null) return view;
    final i = a.intersect(view);
    return i.width <= 0 || i.height <= 0 ? view : i;
  }

  static Rect _slideInside(Rect r, Rect b) {
    var dx = 0.0;
    if (r.left < b.left) dx = b.left - r.left;
    if (r.right > b.right) dx = b.right - r.right;
    return dx == 0 ? r : r.shift(Offset(dx, 0));
  }

  static bool _inside(Rect r, Rect b) =>
      r.left >= b.left - 0.01 && r.top >= b.top - 0.01 && r.right <= b.right + 0.01 && r.bottom <= b.bottom + 0.01;

  static bool _valid(
    Rect r,
    Rect bounds,
    Iterable<LabelObstacle> obstacles,
    Iterable<Rect> keepOut,
    Iterable<Rect> taken,
    Offset? ignore,
    Offset? ignoreAlso,
  ) =>
      _inside(r, bounds) &&
      !_hitsObstacle(r, obstacles, ignore, ignoreAlso) &&
      !_hitsRects(r, keepOut, 0) &&
      !_hitsRects(r, taken, 2);

  static bool _hitsObstacle(Rect r, Iterable<LabelObstacle> obstacles, Offset? ignore, Offset? ignoreAlso) {
    for (final o in obstacles) {
      if (o.center == ignore || o.center == ignoreAlso) continue;
      if (o.radius > 0 && rectHitsDisc(r, o.center, o.radius)) return true;
    }
    return false;
  }

  static bool _hitsRects(Rect r, Iterable<Rect> rects, double grow) {
    final grown = r.inflate(grow);
    for (final t in rects) {
      if (grown.overlaps(t)) return true;
    }
    return false;
  }

  /// Overlap "cost" of a candidate: area over discs (approximated by the
  /// disc's bounding square), keep-outs, labels and outside the area.
  static double _cost(
    Rect r,
    Rect bounds,
    Iterable<LabelObstacle> obstacles,
    Iterable<Rect> keepOut,
    Iterable<Rect> taken,
    Offset? ignore,
    Offset? ignoreAlso,
  ) {
    double overlap(Rect a, Rect b) {
      final i = a.intersect(b);
      return i.width <= 0 || i.height <= 0 ? 0 : i.width * i.height;
    }

    final area = r.width * r.height;
    var cost = (area - overlap(r, bounds)) * 3;
    for (final o in obstacles) {
      if (o.center == ignore || o.center == ignoreAlso || o.radius <= 0) continue;
      if (rectHitsDisc(r, o.center, o.radius)) {
        cost += overlap(r, Rect.fromCircle(center: o.center, radius: o.radius * 0.8));
      }
    }
    for (final k in keepOut) {
      cost += overlap(r, k) * 2;
    }
    for (final t in taken) {
      cost += overlap(r, t.inflate(2)) * 2;
    }
    return cost;
  }

  /// Largest label width worth trying for a body of [radius] px (long names
  /// are ellipsised to it). Quantised to 24-px steps so a zoom does not lay
  /// the text out again every frame.
  static double maxWidthFor(double radius, Size viewport) {
    final w = math.min(viewport.width * 0.42, math.max(96.0, radius * 4));
    return math.max(48.0, (w / 24).floorToDouble() * 24);
  }
}
