import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/interaction/sheets/reminder_rule.dart';

void main() {
  group('ReminderRule JSON matches the Reminders.rule contract exactly', () {
    test('once', () {
      expect(OnceReminder(DateTime(2026, 10, 1, 9, 0, 42, 500)).toJson(), {
        'kind': 'once',
        'at': '2026-10-01T09:00:00',
      });
    });
    test('daily', () => expect(const DailyReminder('08:30').toJson(), {'kind': 'daily', 'time': '08:30'}));
    test('weekly weekdays are Dart weekdays, sorted and unique', () {
      expect(WeeklyReminder('08:30', [5, 1, 3, 3, 9, 0]).toJson(), {
        'kind': 'weekly',
        'time': '08:30',
        'weekdays': [1, 3, 5],
      });
    });
    test('prayer', () {
      expect(const PrayerReminder(PrayerWindow.asr, 10).toJson(), {'kind': 'prayer', 'window': 'asr', 'offsetMin': 10});
      expect(const PrayerReminder(PrayerWindow.fajr, -15).toJson()['offsetMin'], -15);
    });
    test('beforeDue', () => expect(const BeforeDueReminder(1440).toJson(), {'kind': 'beforeDue', 'minutes': 1440}));
  });

  group('fromJson', () {
    test('round-trips every documented example', () {
      final examples = <Map<String, Object?>>[
        {'kind': 'once', 'at': '2026-10-01T09:00:00'},
        {'kind': 'daily', 'time': '08:30'},
        {
          'kind': 'weekly',
          'time': '08:30',
          'weekdays': [1, 3, 5],
        },
        {'kind': 'prayer', 'window': 'asr', 'offsetMin': 10},
        {'kind': 'beforeDue', 'minutes': 1440},
      ];
      for (final e in examples) {
        expect(ReminderRule.fromJson(e)!.toJson(), e);
      }
    });
    test('tolerates loose shapes', () {
      expect(ReminderRule.fromJson({'kind': 'daily', 'time': '٨:٥'}), const DailyReminder('08:05'));
      expect(
        ReminderRule.fromJson({'kind': 'prayer', 'window': 'maghrib'}),
        const PrayerReminder(PrayerWindow.maghrib, 0),
      );
      expect(ReminderRule.fromJson({'kind': 'beforeDue', 'minutes': 30.4}), const BeforeDueReminder(30));
    });
    test('rejects malformed rules', () {
      expect(ReminderRule.fromJson(null), isNull);
      expect(ReminderRule.fromJson({}), isNull);
      expect(ReminderRule.fromJson({'kind': 'hourly'}), isNull);
      expect(ReminderRule.fromJson({'kind': 'once', 'at': 'tomorrow'}), isNull);
      expect(ReminderRule.fromJson({'kind': 'daily', 'time': '25:00'}), isNull);
      expect(ReminderRule.fromJson({'kind': 'weekly', 'time': '08:00', 'weekdays': []}), isNull);
      expect(ReminderRule.fromJson({'kind': 'prayer', 'window': 'anytime'}), isNull);
      expect(ReminderRule.fromJson({'kind': 'beforeDue', 'minutes': 0}), isNull);
    });
    test('formatLocal pads every field', () {
      expect(ReminderRule.formatLocal(DateTime(987, 1, 2, 3, 4, 5)), '0987-01-02T03:04:05');
    });
  });

  group('ReminderDraft', () {
    final now = DateTime(2026, 9, 27, 14, 20); // Sunday afternoon

    test('defaults: once at the next whole hour today', () {
      final d = ReminderDraft(now: now);
      expect(d.kind, ReminderKind.once);
      expect(d.build(), OnceReminder(DateTime(2026, 9, 27, 15)));
      expect(d.weekdays, [DateTime.sunday]);
      expect(d.isDirty, isFalse);
    });

    test('late at night the default moves to tomorrow morning', () {
      final d = ReminderDraft(now: DateTime(2026, 9, 27, 23, 40));
      expect(d.build(), OnceReminder(DateTime(2026, 9, 28, 9)));
    });

    test('a due date makes "before due" the default and available', () {
      final d = ReminderDraft(now: now, dueDate: DateTime(2026, 10, 3));
      expect(d.kind, ReminderKind.beforeDue);
      expect(d.availableKinds, contains(ReminderKind.beforeDue));
      expect(d.build()!.toJson(), {'kind': 'beforeDue', 'minutes': 1440});
      expect(ReminderDraft(now: now).availableKinds, isNot(contains(ReminderKind.beforeDue)));
    });

    test('prayer-relative can be disabled', () {
      final d = ReminderDraft(now: now, allowPrayerRelative: false);
      expect(d.availableKinds, [ReminderKind.once, ReminderKind.daily, ReminderKind.weekly]);
      d.kind = ReminderKind.prayer;
      expect(d.kind, ReminderKind.once);
    });

    test('a one-off reminder in the past is invalid', () {
      final d = ReminderDraft(now: now)..time = '13:00';
      expect(d.issue, ReminderIssue.inPast);
      expect(d.build(), isNull);
      d.date = DateTime(2026, 9, 28);
      expect(d.isValid, isTrue);
      expect(d.build()!.toJson(), {'kind': 'once', 'at': '2026-09-28T13:00:00'});
    });

    test('weekly needs at least one day', () {
      final d = ReminderDraft(now: now)..kind = ReminderKind.weekly;
      d.toggleWeekday(DateTime.sunday);
      expect(d.issue, ReminderIssue.noWeekdays);
      d.weekdays = [DateTime.thursday, DateTime.sunday, DateTime.monday];
      d.time = '7:15';
      expect(d.build()!.toJson(), {
        'kind': 'weekly',
        'time': '07:15',
        'weekdays': [1, 4, 7],
      });
    });

    test('prayer relation sets the offset sign', () {
      final d = ReminderDraft(now: now)
        ..kind = ReminderKind.prayer
        ..window = PrayerWindow.maghrib
        ..offsetMinutes = 15;
      expect(d.build()!.toJson(), {'kind': 'prayer', 'window': 'maghrib', 'offsetMin': 15});
      d.relation = PrayerRelation.before;
      expect(d.offsetMin, -15);
      d.relation = PrayerRelation.at;
      expect(d.build()!.toJson()['offsetMin'], 0);
      d.window = PrayerWindow.anytime;
      expect(d.window, PrayerWindow.maghrib, reason: 'anytime is not a prayer');
    });

    test('switching kinds keeps each kind\'s picks', () {
      final d = ReminderDraft(now: now)
        ..kind = ReminderKind.prayer
        ..window = PrayerWindow.fajr
        ..kind = ReminderKind.daily
        ..time = '06:00'
        ..kind = ReminderKind.prayer;
      expect((d.build()! as PrayerReminder).window, PrayerWindow.fajr);
    });

    test('an initial rule is restored and is not dirty until changed', () {
      final d = ReminderDraft(now: now, initial: {'kind': 'prayer', 'window': 'isha', 'offsetMin': -20});
      expect(d.kind, ReminderKind.prayer);
      expect(d.window, PrayerWindow.isha);
      expect(d.relation, PrayerRelation.before);
      expect(d.offsetMinutes, 20);
      expect(d.isDirty, isFalse);
      d.offsetMinutes = 30;
      expect(d.isDirty, isTrue);
    });

    test('an initial rule of an unavailable kind falls back to the default', () {
      final d = ReminderDraft(now: now, initial: {'kind': 'beforeDue', 'minutes': 60});
      expect(d.kind, ReminderKind.once);
    });

    test('notifies listeners', () {
      final d = ReminderDraft(now: now);
      var n = 0;
      d.addListener(() => n++);
      d
        ..kind = ReminderKind.daily
        ..time = '09:30'
        ..time = '09:30'; // unchanged: no notification
      expect(n, 2);
    });
  });
}
