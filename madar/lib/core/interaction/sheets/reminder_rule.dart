import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../domain/enums.dart';
import 'field_spec.dart' show ClockTime;

/// The five shapes of `Reminders.rule` (see `core_tables.dart`).
enum ReminderKind { once, daily, weekly, prayer, beforeDue }

/// A reminder rule in the exact JSON shape stored in `Reminders.rule`:
///
/// * `{"kind":"once","at":"2026-10-01T09:00:00"}` – local time, no zone
/// * `{"kind":"daily","time":"08:30"}`
/// * `{"kind":"weekly","time":"08:30","weekdays":[1,3,5]}` – Dart weekdays
///   (1 = Monday … 7 = Sunday), sorted, unique
/// * `{"kind":"prayer","window":"asr","offsetMin":10}` – negative = before
///   the adhan, 0 = with it, positive = after
/// * `{"kind":"beforeDue","minutes":1440}`
///
/// Pure Dart – unit-tested.
@immutable
sealed class ReminderRule {
  const ReminderRule();

  ReminderKind get kind;

  Map<String, Object?> toJson();

  /// Parses a stored rule; null for anything malformed or unknown.
  static ReminderRule? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final kind = ReminderKind.values.firstWhereOrNull((k) => k.name == json['kind']);
    switch (kind) {
      case ReminderKind.once:
        final at = json['at'];
        final parsed = at is String ? DateTime.tryParse(at) : null;
        if (parsed == null) return null;
        final local = parsed.isUtc ? parsed.toLocal() : parsed;
        return OnceReminder(local);
      case ReminderKind.daily:
        final time = ClockTime.normalize(json['time']);
        return time == null ? null : DailyReminder(time);
      case ReminderKind.weekly:
        final time = ClockTime.normalize(json['time']);
        final days = json['weekdays'];
        if (time == null || days is! List) return null;
        final list = normalizeWeekdays(days.whereType<num>().map((d) => d.toInt()));
        return list.isEmpty ? null : WeeklyReminder(time, list);
      case ReminderKind.prayer:
        final w = PrayerWindow.values.firstWhereOrNull((w) => w.name == json['window']);
        final offset = json['offsetMin'];
        if (w == null || w == PrayerWindow.anytime) return null;
        return PrayerReminder(w, offset is num ? offset.round() : 0);
      case ReminderKind.beforeDue:
        final minutes = json['minutes'];
        if (minutes is! num || minutes <= 0) return null;
        return BeforeDueReminder(minutes.round());
      case null:
        return null;
    }
  }

  /// Sorted, unique, valid (1..7) Dart weekdays.
  static List<int> normalizeWeekdays(Iterable<int> days) =>
      (days.where((d) => d >= DateTime.monday && d <= DateTime.sunday).toSet().toList()..sort());

  /// `2026-10-01T09:00:00` – local wall-clock time without zone or millis.
  static String formatLocal(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final y = d.year.toString().padLeft(4, '0');
    return '$y-${two(d.month)}-${two(d.day)}T${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }
}

final class OnceReminder extends ReminderRule {
  /// Truncated to the minute.
  OnceReminder(DateTime at) : at = DateTime(at.year, at.month, at.day, at.hour, at.minute);

  final DateTime at;

  @override
  ReminderKind get kind => ReminderKind.once;

  @override
  Map<String, Object?> toJson() => {'kind': 'once', 'at': ReminderRule.formatLocal(at)};

  @override
  bool operator ==(Object other) => other is OnceReminder && other.at == at;

  @override
  int get hashCode => Object.hash(kind, at);
}

final class DailyReminder extends ReminderRule {
  const DailyReminder(this.time);

  /// `HH:mm`.
  final String time;

  @override
  ReminderKind get kind => ReminderKind.daily;

  @override
  Map<String, Object?> toJson() => {'kind': 'daily', 'time': time};

  @override
  bool operator ==(Object other) => other is DailyReminder && other.time == time;

  @override
  int get hashCode => Object.hash(kind, time);
}

final class WeeklyReminder extends ReminderRule {
  WeeklyReminder(this.time, Iterable<int> weekdays)
    : weekdays = List.unmodifiable(ReminderRule.normalizeWeekdays(weekdays));

  final String time;

  /// Dart weekdays (1 = Monday … 7 = Sunday), sorted.
  final List<int> weekdays;

  @override
  ReminderKind get kind => ReminderKind.weekly;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'weekly',
    'time': time,
    'weekdays': [...weekdays],
  };

  @override
  bool operator ==(Object other) =>
      other is WeeklyReminder && other.time == time && const ListEquality<int>().equals(other.weekdays, weekdays);

  @override
  int get hashCode => Object.hash(kind, time, Object.hashAll(weekdays));
}

final class PrayerReminder extends ReminderRule {
  const PrayerReminder(this.window, this.offsetMin);

  /// Any window but [PrayerWindow.anytime]; the reminder is relative to the
  /// adhan (or sunrise for [PrayerWindow.duha]) that opens it.
  final PrayerWindow window;

  /// Minutes relative to the adhan: negative = before, positive = after.
  final int offsetMin;

  @override
  ReminderKind get kind => ReminderKind.prayer;

  @override
  Map<String, Object?> toJson() => {'kind': 'prayer', 'window': window.name, 'offsetMin': offsetMin};

  @override
  bool operator ==(Object other) => other is PrayerReminder && other.window == window && other.offsetMin == offsetMin;

  @override
  int get hashCode => Object.hash(kind, window, offsetMin);
}

final class BeforeDueReminder extends ReminderRule {
  const BeforeDueReminder(this.minutes);

  final int minutes;

  @override
  ReminderKind get kind => ReminderKind.beforeDue;

  @override
  Map<String, Object?> toJson() => {'kind': 'beforeDue', 'minutes': minutes};

  @override
  bool operator ==(Object other) => other is BeforeDueReminder && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(kind, minutes);
}

/// Where a prayer reminder sits relative to the adhan.
enum PrayerRelation { before, at, after }

/// Why a [ReminderDraft] cannot be saved yet.
enum ReminderIssue { inPast, noWeekdays, noDueDate }

/// Editable state behind the reminder sheet. It keeps every kind's fields at
/// once so switching kinds back and forth never loses what the user picked.
/// Pure logic (no widgets) – unit-tested.
class ReminderDraft extends ChangeNotifier {
  ReminderDraft({required DateTime now, this.dueDate, this.allowPrayerRelative = true, Map<String, Object?>? initial})
    : _now = now {
    final today = DateTime(now.year, now.month, now.day);
    // Sensible defaults: the next whole hour, today (or tomorrow late at
    // night); after Asr; a day before the due date.
    final next = DateTime(now.year, now.month, now.day, now.hour + 1);
    _date = DateTime(next.year, next.month, next.day);
    _time = ClockTime.format(next.hour, 0);
    if (_date.isAfter(today) && next.hour >= 0 && next.hour < 7) _time = '09:00';
    _weekdays = {now.weekday};
    _kind = dueDate != null ? ReminderKind.beforeDue : ReminderKind.once;

    final rule = ReminderRule.fromJson(initial);
    if (rule != null && isAvailable(rule.kind)) {
      _kind = rule.kind;
      switch (rule) {
        case OnceReminder(:final at):
          _date = DateTime(at.year, at.month, at.day);
          _time = ClockTime.format(at.hour, at.minute);
        case DailyReminder(:final time):
          _time = time;
        case WeeklyReminder(:final time, :final weekdays):
          _time = time;
          _weekdays = {...weekdays};
        case PrayerReminder(:final window, :final offsetMin):
          _window = window;
          _relation = offsetMin < 0
              ? PrayerRelation.before
              : offsetMin == 0
              ? PrayerRelation.at
              : PrayerRelation.after;
          if (offsetMin != 0) _offsetMinutes = offsetMin.abs();
        case BeforeDueReminder(:final minutes):
          _leadMinutes = minutes;
      }
    }
    _initial = build()?.toJson();
  }

  /// Offsets offered around the adhan.
  static const List<int> offsetChoices = [5, 10, 15, 20, 30, 45, 60];

  /// Lead times offered before a due date.
  static const List<int> leadChoices = [10, 30, 60, 120, 1440, 2880, 10080];

  final DateTime _now;
  final DateTime? dueDate;
  final bool allowPrayerRelative;

  late ReminderKind _kind;
  late DateTime _date;
  late String _time;
  late Set<int> _weekdays;
  PrayerWindow _window = PrayerWindow.asr;
  PrayerRelation _relation = PrayerRelation.after;
  int _offsetMinutes = 10;
  int _leadMinutes = 1440;
  Map<String, Object?>? _initial;

  ReminderKind get kind => _kind;
  DateTime get date => _date;
  String get time => _time;
  List<int> get weekdays => ReminderRule.normalizeWeekdays(_weekdays);
  PrayerWindow get window => _window;
  PrayerRelation get relation => _relation;
  int get offsetMinutes => _offsetMinutes;
  int get leadMinutes => _leadMinutes;
  DateTime get now => _now;

  /// Kinds offered by the sheet.
  List<ReminderKind> get availableKinds => [
    for (final k in ReminderKind.values)
      if (isAvailable(k)) k,
  ];

  bool isAvailable(ReminderKind k) => switch (k) {
    ReminderKind.prayer => allowPrayerRelative,
    ReminderKind.beforeDue => dueDate != null,
    _ => true,
  };

  set kind(ReminderKind k) {
    if (!isAvailable(k) || k == _kind) return;
    _kind = k;
    notifyListeners();
  }

  set date(DateTime d) {
    _date = DateTime(d.year, d.month, d.day);
    notifyListeners();
  }

  set time(String t) {
    final n = ClockTime.normalize(t);
    if (n == null || n == _time) return;
    _time = n;
    notifyListeners();
  }

  void toggleWeekday(int day) {
    if (!_weekdays.remove(day)) _weekdays.add(day);
    notifyListeners();
  }

  set weekdays(List<int> days) {
    _weekdays = {...ReminderRule.normalizeWeekdays(days)};
    notifyListeners();
  }

  set window(PrayerWindow w) {
    if (w == PrayerWindow.anytime) return;
    _window = w;
    notifyListeners();
  }

  set relation(PrayerRelation r) {
    _relation = r;
    notifyListeners();
  }

  set offsetMinutes(int m) {
    _offsetMinutes = m.abs();
    notifyListeners();
  }

  set leadMinutes(int m) {
    if (m <= 0) return;
    _leadMinutes = m;
    notifyListeners();
  }

  /// Signed offset stored in the rule.
  int get offsetMin => switch (_relation) {
    PrayerRelation.before => -_offsetMinutes,
    PrayerRelation.at => 0,
    PrayerRelation.after => _offsetMinutes,
  };

  /// The moment a one-off reminder fires.
  DateTime get onceAt {
    final (h, m) = ClockTime.parts(_time);
    return DateTime(_date.year, _date.month, _date.day, h, m);
  }

  ReminderIssue? get issue => switch (_kind) {
    ReminderKind.once => onceAt.isAfter(_now) ? null : ReminderIssue.inPast,
    ReminderKind.weekly => _weekdays.isEmpty ? ReminderIssue.noWeekdays : null,
    ReminderKind.beforeDue => dueDate == null ? ReminderIssue.noDueDate : null,
    _ => null,
  };

  bool get isValid => issue == null;

  /// Whether anything differs from the initial rule.
  bool get isDirty => !const DeepCollectionEquality().equals(build()?.toJson(), _initial);

  /// The rule for the current kind, or null while invalid.
  ReminderRule? build() {
    if (!isValid) return null;
    return switch (_kind) {
      ReminderKind.once => OnceReminder(onceAt),
      ReminderKind.daily => DailyReminder(_time),
      ReminderKind.weekly => WeeklyReminder(_time, _weekdays),
      ReminderKind.prayer => PrayerReminder(_window, offsetMin),
      ReminderKind.beforeDue => BeforeDueReminder(_leadMinutes),
    };
  }
}
