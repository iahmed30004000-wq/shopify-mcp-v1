/// The four home-screen widgets. [wire] is the name both sides of the
/// bridge use (the channel's `kind` argument, the Android provider's file
/// names) – never rename one.
enum MadarWidgetKind {
  /// The next prayer: a mini astrolabe, its name, time, a ticking countdown
  /// and the Hijri date.
  prayer('prayer'),

  /// Today's doses with their taken / pending state.
  meds('meds'),

  /// Today's Top 3 with their check state.
  tasks('tasks'),

  /// What is left of this month's (or week's) budget.
  budget('budget');

  const MadarWidgetKind(this.wire);

  final String wire;

  static MadarWidgetKind? fromWire(Object? wire) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    return null;
  }
}
