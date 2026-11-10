/// What the owner answers and what he fasted: the two records the integrator
/// persists (pure, JSON in and out), and the counting for the Faith planet.
library;

import 'package:meta/meta.dart';

import '../../prayer/domain/hijri.dart';
import '../../wird/domain/calendar_days.dart';
import 'fasting_models.dart';
import 'fasting_rules.dart';

/// The answer to the evening notification.
enum FastIntentionChoice {
  /// «ناوي»
  yes,

  /// «لأ»
  no;

  static FastIntentionChoice? fromId(Object? id) {
    for (final c in values) {
      if (c.name == id) return c;
    }
    return null;
  }
}

/// «ناوي» / «لأ» for one fasting day. A «لأ» silences only that day.
@immutable
final class FastIntention {
  FastIntention({required DateTime day, required this.choice}) : day = CalendarDays.dateOnly(day);

  final DateTime day;
  final FastIntentionChoice choice;

  bool get intends => choice == FastIntentionChoice.yes;

  Map<String, Object?> toJson() => {'day': CalendarDays.key(day), 'choice': choice.name};

  /// Null when the stored row is malformed.
  static FastIntention? fromJson(Object? json) {
    if (json is! Map) return null;
    final day = CalendarDays.parse(json['day']);
    final choice = FastIntentionChoice.fromId(json['choice']);
    if (day == null || choice == null) return null;
    return FastIntention(day: day, choice: choice);
  }

  @override
  bool operator ==(Object other) =>
      other is FastIntention && CalendarDays.same(other.day, day) && other.choice == choice;

  @override
  int get hashCode => Object.hash(day.year, day.month, day.day, choice);
}

/// How a log entry came to be.
enum FastLogSource {
  /// From the evening reminder («ناوي», or confirmed the next day).
  reminded,

  /// Logged by hand, e.g. a day he fasted without being reminded.
  manual;

  static FastLogSource fromId(Object? id) {
    for (final s in values) {
      if (s.name == id) return s;
    }
    return FastLogSource.manual;
  }
}

/// One day of the fasting log.
@immutable
final class FastLogEntry {
  FastLogEntry({required DateTime day, this.kind, required this.fasted, required this.source})
    : day = CalendarDays.dateOnly(day);

  final DateTime day;

  /// The reminder kind the entry answers; null for a day fasted by hand that
  /// had no reminder.
  final FastKind? kind;
  final bool fasted;
  final FastLogSource source;

  Map<String, Object?> toJson() => {
    'day': CalendarDays.key(day),
    'kind': kind?.id,
    'fasted': fasted,
    'source': source.name,
  };

  /// Null when the stored row is malformed.
  static FastLogEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final day = CalendarDays.parse(json['day']);
    final fasted = json['fasted'];
    if (day == null || fasted is! bool) return null;
    return FastLogEntry(
      day: day,
      kind: FastKind.fromId(json['kind']),
      fasted: fasted,
      source: FastLogSource.fromId(json['source']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FastLogEntry &&
      CalendarDays.same(other.day, day) &&
      other.kind == kind &&
      other.fasted == fasted &&
      other.source == source;

  @override
  int get hashCode => Object.hash(day.year, day.month, day.day, kind, fasted, source);

  /// [log] with [entry] set: one entry per day, the new one replaces an old
  /// one of the same day.
  static List<FastLogEntry> upsert(Iterable<FastLogEntry> log, FastLogEntry entry) => [
    for (final e in log)
      if (!CalendarDays.same(e.day, entry.day)) e,
    entry,
  ];
}

/// Counts over the log, for the Faith planet.
///
/// Months and years are Hijri (under the same offset as the reminders), with
/// Gregorian variants. One day counts once however many entries it has (the
/// last entry for a day wins) and only when [FastLogEntry.fasted].
class FastingStats {
  FastingStats(Iterable<FastLogEntry> log, FastingConfig config) {
    final byDay = <String, FastLogEntry>{};
    for (final e in log) {
      byDay[CalendarDays.key(e.day)] = e;
    }
    for (final e in byDay.values) {
      if (e.fasted) _days.add((day: e.day, hijri: FastingRules.hijriOf(e.day, config)));
    }
  }

  /// The six of Shawwal: the goal of the progress line.
  static const int shawwalGoal = FastingConfig.shawwalDays;

  final List<({DateTime day, HijriDate hijri})> _days = [];

  int get totalFastedDays => _days.length;

  int fastedInHijriMonth(int year, int month) => _days.where((d) => d.hijri.year == year && d.hijri.month == month).length;

  int fastedInHijriYear(int year) => _days.where((d) => d.hijri.year == year).length;

  int fastedInGregorianMonth(int year, int month) => _days.where((d) => d.day.year == year && d.day.month == month).length;

  int fastedInGregorianYear(int year) => _days.where((d) => d.day.year == year).length;

  /// Progress "n of 6" of Shawwal of Hijri [year]: the fasted days of
  /// Shawwal other than its first day (the Eid), capped at six. Any Shawwal
  /// day counts, not only the six the reminders named.
  ({int done, int goal}) sixShawwalProgress(int year) {
    final n = _days.where((d) => d.hijri.year == year && d.hijri.month == 10 && d.hijri.day >= 2).length;
    return (done: n > shawwalGoal ? shawwalGoal : n, goal: shawwalGoal);
  }

  /// White days (13, 14, 15; never 13 Dhu al-Hijjah) fasted in Hijri
  /// [month] of [year]. Counted on their own: a white day that is also a
  /// Monday is one white day here and one fasted day in the month total.
  int whiteDaysFastedInMonth(int year, int month) =>
      _days.where((d) => d.hijri.year == year && d.hijri.month == month && _isWhite(d.hijri)).length;

  int whiteDaysFastedInYear(int year) => _days.where((d) => d.hijri.year == year && _isWhite(d.hijri)).length;

  static bool _isWhite(HijriDate h) =>
      !h.isRamadan && FastingRules.forbiddenDay(h) == null && h.day >= 13 && h.day <= 15;
}
