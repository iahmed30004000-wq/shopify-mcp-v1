/// Lab flags: where a reading sits against the user's *own* reference range.
///
/// These are neutral labels (low / borderline / within range / high) – never
/// an interpretation. Pure Dart.
///
/// **Borderline rule.** A reading inside the range is *borderline* when it is
/// within a margin of a bound. The margin is a fraction (default 5 %,
/// user-adjustable 0–25 %) of the range width `high − low`:
///
/// * `low ≤ v < low + m` → borderline low; `high − m < v ≤ high` → borderline
///   high (a value exactly on a bound is still within the range, so it is
///   borderline).
/// * With only one bound (`< 200`, `> 40`) there is no width, so the margin
///   is that fraction of the bound's magnitude (5 % of 200 = 10).
/// * When a reading is near both bounds (a very narrow range) the nearer one
///   wins.
library;

enum LabFlag {
  /// Below the user's low bound.
  low,

  /// Within range, close to the low bound.
  borderlineLow,

  /// Within range and not near a bound.
  inRange,

  /// Within range, close to the high bound.
  borderlineHigh,

  /// Above the user's high bound.
  high,

  /// A number, but the test has no reference range.
  noRange,

  /// A qualitative result ("negative", "trace") – never flagged.
  qualitative,
}

extension LabFlagFacts on LabFlag {
  bool get isOutOfRange => this == LabFlag.low || this == LabFlag.high;
  bool get isBorderline => this == LabFlag.borderlineLow || this == LabFlag.borderlineHigh;

  /// Out of range or borderline – worth a chip on the hub.
  bool get isFlagged => isOutOfRange || isBorderline;

  /// −1 towards/below the low bound, +1 towards/above the high bound, 0
  /// otherwise (for ↓ / ↑ markers).
  int get side => switch (this) {
    LabFlag.low || LabFlag.borderlineLow => -1,
    LabFlag.high || LabFlag.borderlineHigh => 1,
    _ => 0,
  };

  /// Sort weight: out of range first, then borderline, then the rest.
  int get attention => switch (this) {
    LabFlag.low || LabFlag.high => 2,
    LabFlag.borderlineLow || LabFlag.borderlineHigh => 1,
    _ => 0,
  };
}

/// A test's reference range (either bound may be missing).
class LabRange {
  const LabRange({this.low, this.high});

  final double? low;
  final double? high;

  bool get isEmpty => low == null && high == null;
  bool get isBounded => low != null && high != null;

  /// Bounds in order (a range typed backwards still works).
  (double?, double?) get ordered {
    final lo = low, hi = high;
    if (lo != null && hi != null && lo > hi) return (hi, lo);
    return (lo, hi);
  }

  @override
  bool operator ==(Object other) => other is LabRange && other.low == low && other.high == high;

  @override
  int get hashCode => Object.hash(low, high);

  @override
  String toString() => 'LabRange($low–$high)';
}

abstract final class LabFlags {
  /// Default borderline margin: 5 % of the range width.
  static const double defaultMargin = 0.05;

  /// Largest margin the settings allow.
  static const double maxMargin = 0.25;

  /// The borderline band's width in the test's unit (0 when there is none),
  /// or null without any bound.
  static double? marginWidth(LabRange range, {double margin = defaultMargin}) {
    final (lo, hi) = range.ordered;
    if (lo == null && hi == null) return null;
    final m = margin.clamp(0.0, maxMargin);
    if (m == 0) return 0;
    if (lo != null && hi != null) return (hi - lo) * m;
    return (lo ?? hi)!.abs() * m;
  }

  /// Classifies [value] against [range]. A null [value] is a qualitative
  /// result.
  static LabFlag classify(double? value, LabRange range, {double margin = defaultMargin}) {
    if (value == null || value.isNaN) return LabFlag.qualitative;
    final (lo, hi) = range.ordered;
    if (lo == null && hi == null) return LabFlag.noRange;
    if (lo != null && value < lo) return LabFlag.low;
    if (hi != null && value > hi) return LabFlag.high;
    final m = marginWidth(range, margin: margin) ?? 0;
    if (m <= 0) return LabFlag.inRange;
    final nearLow = lo != null && value < lo + m;
    final nearHigh = hi != null && value > hi - m;
    if (nearLow && nearHigh) {
      return (value - lo) <= (hi - value) ? LabFlag.borderlineLow : LabFlag.borderlineHigh;
    }
    if (nearLow) return LabFlag.borderlineLow;
    if (nearHigh) return LabFlag.borderlineHigh;
    return LabFlag.inRange;
  }
}
