/// Where a coach-tour bubble goes. Pure geometry (no widgets), so the corner
/// cases – targets in the four corners, RTL, under the keyboard – are plain
/// unit tests.
///
/// All rectangles are physical (left / top), in the overlay's coordinates.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show EdgeInsets;

enum BubbleSide { above, below, center }

@immutable
class BubblePlacement {
  const BubblePlacement({required this.rect, required this.side, required this.spotlight, required this.overlapsTarget});

  /// Where the bubble sits; its height may be less than asked when the room
  /// is short (the bubble scrolls inside).
  final Rect rect;
  final BubbleSide side;

  /// The part of the target that is on screen (null: no target, or it is
  /// hidden behind the keyboard / off screen – the bubble is centred).
  final Rect? spotlight;

  /// True only when no side had room (a target filling the screen): the
  /// bubble then overlaps it rather than leaving the screen.
  final bool overlapsTarget;

  @override
  String toString() => 'BubblePlacement($rect, ${side.name}, spotlight: $spotlight, overlaps: $overlapsTarget)';
}

abstract final class BubbleGeometry {
  /// Never squeeze a bubble below this height.
  static const double minHeight = 96;

  static Rect _area(Size screen, EdgeInsets safe, double keyboard, double margin) => Rect.fromLTRB(
    safe.left + margin,
    safe.top + margin,
    math.max(safe.left + margin, screen.width - safe.right - margin),
    math.max(safe.top + margin, screen.height - math.max(safe.bottom, keyboard) - margin),
  );

  /// The target as the person can see it: clipped to the screen above the
  /// keyboard; null when none of it shows.
  static Rect? visibleTarget(Rect? target, Size screen, double keyboard) {
    if (target == null) return null;
    final visible = Rect.fromLTRB(0, 0, screen.width, math.max(0, screen.height - keyboard));
    if (!target.overlaps(visible)) return null;
    final clipped = target.intersect(visible);
    return clipped.isEmpty ? null : clipped;
  }

  /// The tallest bubble that fits beside [target] (use it as the bubble's
  /// max height so it never has to cover the target).
  static double maxBubbleHeight({
    required Rect? target,
    required Size screen,
    EdgeInsets safe = EdgeInsets.zero,
    double keyboard = 0,
    double gap = 12,
    double margin = 16,
  }) {
    final area = _area(screen, safe, keyboard, margin);
    final spot = visibleTarget(target, screen, keyboard);
    if (spot == null) return area.height;
    final room = math.max(area.bottom - (spot.bottom + gap), (spot.top - gap) - area.top);
    return room.clamp(math.min(minHeight, area.height), area.height);
  }

  static BubblePlacement place({
    required Rect? target,
    required Size screen,
    required Size bubble,
    required TextDirection direction,
    EdgeInsets safe = EdgeInsets.zero,
    double keyboard = 0,
    double gap = 12,
    double margin = 16,
  }) {
    final area = _area(screen, safe, keyboard, margin);
    final width = math.min(bubble.width, area.width);
    final spot = visibleTarget(target, screen, keyboard);

    if (spot == null) {
      final h = math.min(bubble.height, area.height);
      final r = Rect.fromLTWH(area.left + (area.width - width) / 2, area.top + (area.height - h) / 2, width, h);
      return BubblePlacement(rect: r, side: BubbleSide.center, spotlight: null, overlapsTarget: false);
    }

    final below = area.bottom - (spot.bottom + gap);
    final above = (spot.top - gap) - area.top;
    final BubbleSide side;
    double height = bubble.height;
    var overlaps = false;
    if (height <= below) {
      side = BubbleSide.below;
    } else if (height <= above) {
      side = BubbleSide.above;
    } else {
      // Neither side holds the whole bubble: take the roomier one and let the
      // bubble scroll inside; only a target that fills the screen overlaps.
      side = below >= above ? BubbleSide.below : BubbleSide.above;
      final room = math.max(below, above);
      if (room < math.min(minHeight, area.height)) {
        overlaps = true;
        height = math.min(bubble.height, area.height);
      } else {
        height = room;
      }
    }

    // A narrow target: centre on it. A target wider than the bubble: line up
    // with its start edge (right in RTL, left in LTR) so the bubble reads
    // from where the eye starts.
    double x;
    if (spot.width <= width) {
      x = spot.center.dx - width / 2;
    } else {
      x = direction == TextDirection.rtl ? spot.right - width : spot.left;
    }
    x = x.clamp(area.left, math.max(area.left, area.right - width));

    final double y;
    if (overlaps) {
      y = side == BubbleSide.below ? area.bottom - height : area.top;
    } else {
      y = side == BubbleSide.below ? spot.bottom + gap : spot.top - gap - height;
    }
    return BubblePlacement(rect: Rect.fromLTWH(x, y, width, height), side: side, spotlight: spot, overlapsTarget: overlaps);
  }
}
