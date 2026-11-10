import 'body_clock.dart';

/// The training week: ISO weekdays (1 = Monday … 7 = Sunday, as stored in
/// `exercises.weekdays`) shown from the locale's first day – Saturday in
/// Arabic, Sunday in English (the same as the app's date pickers).
abstract final class BodyWeek {
  static const List<int> all = [1, 2, 3, 4, 5, 6, 7];

  /// First displayed weekday for [languageCode].
  static int startFor(String languageCode) => languageCode == 'ar' ? DateTime.saturday : DateTime.sunday;

  /// The seven ISO weekdays in display order, starting at [start].
  static List<int> ordered(int start) {
    assert(start >= 1 && start <= 7);
    return [for (var i = 0; i < 7; i++) (start - 1 + i) % 7 + 1];
  }

  /// Unique valid weekdays, sorted by ISO number (the stored form).
  static List<int> normalize(Iterable<int> days) => ({
    for (final d in days)
      if (d >= 1 && d <= 7) d,
  }.toList()..sort());

  /// [days] sorted in display order from [start].
  static List<int> inDisplayOrder(Iterable<int> days, int start) {
    final set = normalize(days).toSet();
    return [
      for (final d in ordered(start))
        if (set.contains(d)) d,
    ];
  }

  /// Whether a plan on [weekdays] trains on [day].
  static bool trainsOn(List<int> weekdays, DateTime day) => weekdays.contains(day.weekday);

  /// The first day of the display week containing [day].
  static DateTime weekStartOf(DateTime day, int start) {
    final back = (day.weekday - start + 7) % 7;
    return BodyDays.add(BodyDays.of(day), -back);
  }

  /// The seven calendar days of the display week containing [day].
  static List<DateTime> weekOf(DateTime day, int start) {
    final first = weekStartOf(day, start);
    return [for (var i = 0; i < 7; i++) BodyDays.add(first, i)];
  }

  /// The next day on or after [from] (today counts) on which a plan on
  /// [weekdays] trains; null for an empty plan.
  static DateTime? nextOn(List<int> weekdays, DateTime from) {
    if (weekdays.isEmpty) return null;
    final day = BodyDays.of(from);
    for (var i = 0; i < 7; i++) {
      final d = BodyDays.add(day, i);
      if (weekdays.contains(d.weekday)) return d;
    }
    return null;
  }

  /// How many of the seven weekdays a plan uses (a "3× a week" caption).
  static int perWeek(List<int> weekdays) => normalize(weekdays).length;
}
