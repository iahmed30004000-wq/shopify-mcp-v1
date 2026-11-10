/// The shelf of lanterns: each lights when the star count reaches its
/// threshold. Only ever lit, never put out: the count never goes down.
abstract final class Lanterns {
  /// Stars needed for lantern 1, 2, 3 ...
  static const List<int> thresholds = [3, 6, 10, 15, 20, 30, 40, 55, 75];

  static int get total => thresholds.length;

  /// How many lanterns are lit with [stars] stars.
  static int litCount(int stars) {
    var n = 0;
    for (final t in thresholds) {
      if (stars >= t) n++;
    }
    return n;
  }

  /// The next threshold above [stars], or null when every lantern is lit.
  static int? nextThreshold(int stars) {
    for (final t in thresholds) {
      if (stars < t) return t;
    }
    return null;
  }

  /// Stars missing for the next lantern (0 when all are lit).
  static int starsToNext(int stars) {
    final next = nextThreshold(stars);
    return next == null ? 0 : next - stars;
  }

  /// 0..1 progress between the last lit lantern and the next one (1 when all
  /// are lit).
  static double progress(int stars) {
    final next = nextThreshold(stars);
    if (next == null) return 1;
    final lit = litCount(stars);
    final prev = lit == 0 ? 0 : thresholds[lit - 1];
    return ((stars - prev) / (next - prev)).clamp(0.0, 1.0);
  }
}
