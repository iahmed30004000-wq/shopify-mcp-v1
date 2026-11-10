import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart';

/// A [Curve] that follows a damped spring from 0 to 1, so route transitions
/// driven by a plain [AnimationController] still move physically (with the
/// spring's overshoot). Use [settleDuration] as the controller duration so the
/// curve has come to rest by `t = 1`.
class InteractionSpringCurve extends Curve {
  /// [timeline] is the length of the animation the curve is applied to; it
  /// defaults to the spring's own [settleDuration]. A longer timeline makes
  /// the spring come to rest before `t = 1`.
  InteractionSpringCurve(this.spring, {Duration? timeline})
    : _seconds = timeline == null ? settleSeconds(spring) : timeline.inMicroseconds / Duration.microsecondsPerSecond;

  final SpringDescription spring;
  final double _seconds;

  /// Seconds until the spring's envelope decays below [tolerance].
  static double settleSeconds(SpringDescription spring, {double tolerance = 0.002}) {
    final omega = math.sqrt(spring.stiffness / spring.mass);
    final zeta = spring.damping / (2 * math.sqrt(spring.stiffness * spring.mass));
    final decay = math.max(0.5, zeta.clamp(0.0, 1.0) * omega);
    // Critically / over-damped springs converge slower than the envelope.
    final factor = zeta >= 0.999 ? 1.6 : 1.0;
    return (math.log(1 / tolerance) / decay * factor).clamp(0.12, 2.0);
  }

  /// Controller duration matching [spring].
  static Duration settleDuration(SpringDescription spring) =>
      Duration(microseconds: (settleSeconds(spring) * Duration.microsecondsPerSecond).round());

  @override
  double transformInternal(double t) {
    final sim = SpringSimulation(spring, 0, 1, 0);
    return sim.x(t * _seconds);
  }
}

/// Swipe physics for [ActionableItem] rows (pure; physical pixels, positive =
/// finger moved right regardless of text direction).
abstract final class SwipeMath {
  /// iOS-style rubber band: maps an [overshoot] beyond a limit to a displayed
  /// distance that approaches [dimension] asymptotically.
  static double rubberBand(double overshoot, double dimension, [double coefficient = 0.55]) {
    if (overshoot <= 0 || dimension <= 0) return 0;
    return (1 - 1 / (overshoot * coefficient / dimension + 1)) * dimension;
  }

  /// Displayed offset for a raw drag distance [raw].
  ///
  /// * Right (complete): free until [threshold], rubber band beyond it.
  /// * Left (quick actions): free until [trayWidth], rubber band beyond it.
  /// * A side without an action barely moves (heavy resistance).
  static double displayOffset({
    required double raw,
    required double threshold,
    required double trayWidth,
    required bool canComplete,
    required bool hasTray,
    required double width,
  }) {
    if (raw >= 0) {
      if (!canComplete) return rubberBand(raw, 28);
      if (raw <= threshold) return raw;
      return threshold + rubberBand(raw - threshold, width * 0.35);
    }
    final left = -raw;
    if (!hasTray) return -rubberBand(left, 28);
    if (left <= trayWidth) return raw;
    return -(trayWidth + rubberBand(left - trayWidth, width * 0.25));
  }

  /// Inverse of [displayOffset] for the free (non-rubber) zone, used when a
  /// drag starts from an already-open tray.
  static double rawFromDisplay(double display) => display;

  /// Progress towards the complete threshold (0..1+, may exceed 1 while
  /// rubber-banding).
  static double completeProgress(double display, double threshold) =>
      threshold <= 0 ? 0 : math.max(0, display) / threshold;

  /// Threshold (in px) for a row of [width]: a third of the row, clamped to a
  /// comfortable thumb distance.
  static double completeThreshold(double width) => (width * 0.34).clamp(72.0, 140.0);

  /// Where a released drag should settle.
  static SwipeSettle settle({
    required double display,
    required double velocity,
    required double threshold,
    required double trayWidth,
    required bool canComplete,
    required bool hasTray,
  }) {
    if (display > 0) {
      if (canComplete && display >= threshold) return SwipeSettle.complete;
      return SwipeSettle.closed;
    }
    if (!hasTray || display == 0) return SwipeSettle.closed;
    final open = -display;
    if (velocity < -350) return SwipeSettle.openTray;
    if (velocity > 350) return SwipeSettle.closed;
    return open >= trayWidth * 0.5 ? SwipeSettle.openTray : SwipeSettle.closed;
  }
}

enum SwipeSettle { closed, openTray, complete }

/// Placement of the long-press context menu relative to its item.
@immutable
class ContextMenuPlacement {
  const ContextMenuPlacement({required this.menuOffset, required this.itemOffset, required this.below});

  /// Top-left of the menu in overlay coordinates.
  final Offset menuOffset;

  /// Top-left where the (lifted) item snapshot is drawn; differs from the
  /// item's own position only when the item had to shift to make room.
  final Offset itemOffset;

  /// Whether the menu sits below the item.
  final bool below;
}

/// Keeps the context menu on screen (pure, unit-tested).
abstract final class ContextMenuLayout {
  static ContextMenuPlacement compute({
    required Rect item,
    required Size menu,
    required Size screen,
    required EdgeInsets safe,
    required TextDirection direction,
    double gap = 10,
    double margin = 12,
  }) {
    final top = safe.top + margin;
    final bottom = screen.height - safe.bottom - margin;
    final left = safe.left + margin;
    final right = screen.width - safe.right - margin;

    // Horizontal: align to the item's start edge, clamped into the safe area.
    double x = direction == TextDirection.rtl ? item.right - menu.width : item.left;
    x = x.clamp(left, math.max(left, right - menu.width));

    final spaceBelow = bottom - item.bottom - gap;
    final spaceAbove = item.top - gap - top;
    var itemTop = item.top;
    double y;
    bool below;
    if (menu.height <= spaceBelow) {
      below = true;
      y = item.bottom + gap;
    } else if (menu.height <= spaceAbove) {
      below = false;
      y = item.top - gap - menu.height;
    } else {
      // Not enough room either side: pin the menu to the bottom and lift the
      // item above it as far as the top safe edge allows.
      below = true;
      y = math.max(top, bottom - menu.height);
      final desiredItemTop = y - gap - item.height;
      itemTop = math.max(top, math.min(item.top, desiredItemTop));
    }
    return ContextMenuPlacement(menuOffset: Offset(x, y), itemOffset: Offset(item.left, itemTop), below: below);
  }
}

/// Moves the element at [oldIndex] to [newIndex] (indexes as reported by
/// `ReorderableListView.onReorderItem`, i.e. already adjusted for the
/// removal) and returns a new list.
List<T> reorderItems<T>(List<T> items, int oldIndex, int newIndex) {
  final out = List<T>.of(items);
  if (oldIndex < 0 || oldIndex >= out.length) return out;
  final item = out.removeAt(oldIndex);
  out.insert(newIndex.clamp(0, out.length), item);
  return out;
}
