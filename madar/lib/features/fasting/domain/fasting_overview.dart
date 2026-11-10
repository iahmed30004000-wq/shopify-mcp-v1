/// What the «صيامي» screen shows, computed from the engine's rules and the
/// owner's own records (pure Dart: no clock, no storage, no widgets).
library;

import 'package:meta/meta.dart';

import '../../wird/domain/calendar_days.dart';
import 'fasting_log.dart';
import 'fasting_models.dart';
import 'fasting_rules.dart';

/// One reminder still to come, with what he already answered for its day.
@immutable
final class UpcomingFast {
  const UpcomingFast({required this.reminder, this.answer, this.logged = false});

  final FastReminder reminder;

  /// His «ناوي» / «لأ» for that day (null = not answered yet).
  final FastIntentionChoice? answer;

  /// A log entry already exists for that day (he fasted it).
  final bool logged;
}

/// The kinds that one switch on the screen turns on and off together.
enum FastKindGroup {
  /// Monday and Thursday.
  weekly({FastKind.monday, FastKind.thursday}),

  /// 13, 14 and 15 of the Hijri month.
  white({FastKind.whiteDay}),

  /// Arafah, Tasu'a and Ashura, the first of Dhu al-Hijjah and the six of Shawwal.
  yearly({FastKind.arafah, FastKind.ashura, FastKind.tasua, FastKind.dhuHijjahTen, FastKind.sixShawwal}),

  /// The gentle Muharram / Sha'ban nudge.
  nudge({FastKind.muharramMore, FastKind.shabanMore});

  const FastKindGroup(this.kinds);

  final Set<FastKind> kinds;

  /// On while any of its kinds still gets a reminder.
  bool isOn(FastingConfig config) => kinds.any(config.isEnabled);

  /// [config] with the whole group switched [on] or off.
  FastingConfig set(FastingConfig config, bool on) =>
      config.copyWith(disabled: on ? ({...config.disabled}..removeAll(kinds)) : {...config.disabled, ...kinds});
}

abstract final class FastingOverview {
  /// How far ahead the screen looks for [count] reminders (a few Hijri
  /// months, so a switched-on yearly kind still shows up).
  static const int horizonDays = 400;

  /// The next [count] reminded fasting days from [today] on (today counts:
  /// he may be fasting it), one per day, in day order.
  static List<UpcomingFast> upcoming({
    required FastingConfig config,
    required DateTime today,
    Iterable<FastIntention> intentions = const [],
    Iterable<FastLogEntry> log = const [],
    int count = 10,
  }) {
    final answers = {for (final i in intentions) CalendarDays.key(i.day): i.choice};
    final fasted = {
      for (final e in log)
        if (e.fasted) CalendarDays.key(e.day),
    };
    final start = CalendarDays.dateOnly(today);
    final out = <UpcomingFast>[];
    for (var d = start; out.length < count && CalendarDays.between(start, d) <= horizonDays; d = CalendarDays.add(d, 1)) {
      final r = FastingRules.reminderOn(d, config);
      if (r == null) continue;
      final key = CalendarDays.key(d);
      out.add(UpcomingFast(reminder: r, answer: answers[key], logged: fasted.contains(key)));
    }
    return out;
  }

  /// Days he said «ناوي» to in the last [days] days (today and yesterday
  /// first) that his log does not hold yet: the screen asks him to confirm.
  static List<DateTime> toConfirm({
    required DateTime today,
    required Iterable<FastIntention> intentions,
    required Iterable<FastLogEntry> log,
    int days = 7,
  }) {
    final t = CalendarDays.dateOnly(today);
    final from = CalendarDays.add(t, -days);
    final logged = {for (final e in log) CalendarDays.key(e.day)};
    return [
      for (final i in intentions)
        if (i.intends && !i.day.isBefore(from) && !i.day.isAfter(t) && !logged.contains(CalendarDays.key(i.day))) i.day,
    ]..sort((a, b) => b.compareTo(a));
  }
}
