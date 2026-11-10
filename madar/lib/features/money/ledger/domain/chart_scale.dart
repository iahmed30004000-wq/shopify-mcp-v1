/// "Nice" axis scales for the ledger's charts (pure Dart, display only).
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

@immutable
class ChartScale {
  const ChartScale(this.min, this.max, this.interval);

  /// A scale covering [lo]..[hi] with about [ticks] round steps (1, 2, 2.5,
  /// 5 × 10ⁿ); zero is always included.
  factory ChartScale.of(double lo, double hi, {int ticks = 4}) {
    var a = math.min(0.0, math.min(lo, hi));
    var b = math.max(0.0, math.max(lo, hi));
    if (b - a <= 0) b = a + 1;
    final rough = (b - a) / ticks;
    final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final residual = rough / mag;
    final nice = residual <= 1
        ? 1.0
        : residual <= 2
        ? 2.0
        : residual <= 2.5
        ? 2.5
        : residual <= 5
        ? 5.0
        : 10.0;
    final interval = nice * mag;
    a = (a / interval).floorToDouble() * interval;
    b = (b / interval).ceilToDouble() * interval;
    if (b <= a) b = a + interval;
    return ChartScale(a, b, interval);
  }

  final double min;
  final double max;
  final double interval;

  @override
  bool operator ==(Object other) =>
      other is ChartScale && other.min == min && other.max == max && other.interval == interval;

  @override
  int get hashCode => Object.hash(min, max, interval);

  @override
  String toString() => 'ChartScale($min..$max step $interval)';
}
