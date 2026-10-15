import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'board_columns.dart';

/// Which way a card was swiped, physically.
enum SwipeSide { left, right }

/// A card move: to [columnId] at [index] of that column's list.
@immutable
class CardMove {
  const CardMove({required this.cardId, required this.columnId, required this.index});

  final String cardId;
  final String columnId;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is CardMove && other.cardId == cardId && other.columnId == columnId && other.index == index;

  @override
  int get hashCode => Object.hash(cardId, columnId, index);

  @override
  String toString() => 'CardMove($cardId → $columnId#$index)';
}

/// Pure kanban geometry and ordering: where a dragged card lands, how the
/// column orders change, which column a horizontal position or a swipe
/// points at in either reading direction, and edge auto-scroll speed.
abstract final class KanbanMath {
  /// Insertion index in a column for a pointer at [dy], given the vertical
  /// midpoints (top to bottom) of the column's other cards: before the
  /// first card whose middle is below the pointer.
  static int insertionIndex(double dy, List<double> midpoints) {
    for (var i = 0; i < midpoints.length; i++) {
      if (dy < midpoints[i]) return i;
    }
    return midpoints.length;
  }

  /// Column orders (`column id → card ids top to bottom`) after [move]. The
  /// card leaves wherever it was; [CardMove.index] counts positions in the
  /// target list *without* the card and is clamped.
  static Map<String, List<String>> apply(Map<String, List<String>> orders, CardMove move) {
    final out = {for (final e in orders.entries) e.key: [...e.value]};
    for (final list in out.values) {
      list.remove(move.cardId);
    }
    final target = out.putIfAbsent(move.columnId, () => <String>[]);
    target.insert(move.index.clamp(0, target.length), move.cardId);
    return out;
  }

  /// Whether [move] changes anything for a card currently at [fromIndex]
  /// of [fromColumn] (indices without the card, as [apply] counts them).
  static bool isNoop(String fromColumn, int fromIndex, CardMove move) =>
      move.columnId == fromColumn && move.index == fromIndex;

  /// Logical column index (reading order) under a horizontal viewport
  /// position [dx] (measured from the viewport's *left* edge), for columns
  /// of equal [extent] laid out after [leading] padding, scrolled by
  /// [scrollOffset]. In RTL the first column sits at the right edge.
  static int columnAt(
    double dx, {
    required double viewportWidth,
    required double extent,
    required double scrollOffset,
    required int count,
    required bool rtl,
    double leading = 0,
  }) {
    if (count <= 0) return -1;
    // Distance from the reading-direction start edge.
    final fromStart = rtl ? viewportWidth - dx : dx;
    final content = fromStart + scrollOffset - leading;
    final i = (content / extent).floor();
    return i.clamp(0, count - 1);
  }

  /// [logical] items in their on-screen left-to-right order.
  static List<T> visualOrder<T>(List<T> logical, {required bool rtl}) => rtl ? logical.reversed.toList() : logical;

  /// The column a swipe towards [side] moves the card to: towards the next
  /// column in reading order ("forward") when the swipe points where the
  /// next column is drawn – left in RTL, right in LTR – else back.
  static String? swipeTarget(List<BoardColumn> columns, String currentId, SwipeSide side, {required bool rtl}) {
    final forward = rtl ? side == SwipeSide.left : side == SwipeSide.right;
    return forward ? BoardColumns.nextId(columns, currentId) : BoardColumns.previousId(columns, currentId);
  }

  /// Whether a swipe to [side] is "forward" in reading order.
  static bool isForward(SwipeSide side, {required bool rtl}) => rtl ? side == SwipeSide.left : side == SwipeSide.right;

  /// Auto-scroll speed (logical px per second, negative = towards the
  /// start of the axis) while dragging at [position] inside [start]..[end]:
  /// zero in the middle, ramping up to [maxSpeed] inside the [edge] band.
  static double autoScrollSpeed(
    double position, {
    required double start,
    required double end,
    double edge = 56,
    double maxSpeed = 900,
  }) {
    if (end - start <= edge * 2) return 0;
    if (position < start + edge) {
      final f = ((start + edge - position) / edge).clamp(0.0, 1.0);
      return -maxSpeed * f * f;
    }
    if (position > end - edge) {
      final f = ((position - (end - edge)) / edge).clamp(0.0, 1.0);
      return maxSpeed * f * f;
    }
    return 0;
  }

  /// Width of one column on a screen [viewportWidth] wide: most of a phone
  /// screen with the next column peeking, capped on wide screens.
  static double columnExtent(double viewportWidth) => math.min(340.0, math.max(240.0, viewportWidth * 0.8));
}
