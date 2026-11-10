import 'rhythm.dart';

/// A person's next birthday.
class BirthdayInfo {
  const BirthdayInfo({required this.birthday, required this.next, required this.daysUntil, this.turning});

  /// The stored birthday (year [Birthdays.unknownYear] = year unknown).
  final DateTime birthday;

  /// The next occurrence (today when it is today).
  final DateTime next;

  /// Days until [next] (0 = today).
  final int daysUntil;

  /// The age reached on [next], when the birth year is known.
  final int? turning;

  bool get isToday => daysUntil == 0;
  bool get isTomorrow => daysUntil == 1;
}

/// Birthday maths (pure).
abstract final class Birthdays {
  /// Stored as the birth year when the user does not know it (a leap year,
  /// so 29 February survives).
  static const int unknownYear = 1904;

  static bool yearKnown(DateTime birthday) => birthday.year > unknownYear;

  /// [birthday] with the year replaced by [unknownYear] or kept.
  static DateTime normalize(DateTime birthday, {required bool yearKnown}) =>
      DateTime(yearKnown ? birthday.year : unknownYear, birthday.month, birthday.day);

  /// The birthday's date in [year] (29 February → 28 February in a common
  /// year).
  static DateTime inYear(DateTime birthday, int year) {
    if (birthday.month == 2 && birthday.day == 29 && !_leap(year)) return DateTime(year, 2, 28);
    return DateTime(year, birthday.month, birthday.day);
  }

  static bool _leap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  /// The next occurrence at or after [now]'s day, or null without a birthday.
  static BirthdayInfo? next(DateTime? birthday, DateTime now) {
    if (birthday == null) return null;
    final today = CalendarDays.dayOf(now);
    var next = inYear(birthday, today.year);
    if (next.isBefore(today)) next = inYear(birthday, today.year + 1);
    final age = yearKnown(birthday) ? next.year - birthday.year : null;
    return BirthdayInfo(
      birthday: birthday,
      next: next,
      daysUntil: CalendarDays.between(today, next),
      turning: age != null && age > 0 ? age : null,
    );
  }

  /// Birthdays within [withinDays] days (today included), soonest first.
  static List<(T, BirthdayInfo)> upcoming<T>(
    Iterable<T> items,
    DateTime? Function(T item) birthdayOf,
    DateTime now, {
    int withinDays = 30,
  }) {
    final out = <(T, BirthdayInfo)>[];
    for (final item in items) {
      final info = next(birthdayOf(item), now);
      if (info != null && info.daysUntil <= withinDays) out.add((item, info));
    }
    out.sort((a, b) => a.$2.daysUntil.compareTo(b.$2.daysUntil));
    return out;
  }
}
