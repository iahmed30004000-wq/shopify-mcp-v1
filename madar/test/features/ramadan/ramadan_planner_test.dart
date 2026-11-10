// The plan of Ramadan's reminders: the exact id set for a known Ramadan,
// nothing outside it, nothing in the past, the Hijri shift moving every one of
// them, switches and lead times honoured, deterministic ids - all against
// numbers written in the test (fixed prayer times), never the planner's own
// arithmetic.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/fasting/domain/fasting_models.dart';
import 'package:madar/features/fasting/domain/fasting_rules.dart';
import 'package:madar/features/ramadan/domain/ramadan_calendar.dart';
import 'package:madar/features/ramadan/domain/ramadan_config.dart';
import 'package:madar/features/ramadan/domain/ramadan_notification_ids.dart';
import 'package:madar/features/ramadan/domain/ramadan_planner.dart';

import 'ramadan_test_support.dart';

void main() {
  const calendar = RamadanCalendar();

  RamadanPlan plan(DateTime now, {RamadanConfig config = const RamadanConfig(), RamadanCalendar cal = calendar}) =>
      RamadanPlanner.plan(config: config, calendar: cal, now: now, timesOf: fixedTimes);

  group('a known Ramadan (1448: 8 February 2027, 29 days)', () {
    final now = DateTime(2027, 1, 20, 12);

    test('the exact set of ids: suhoor, iftar and Taraweeh for each of 29 days, the last ten for nights 21-29', () {
      final p = plan(now);
      expect(p.span.first, DateTime(2027, 2, 8));
      expect(p.span.length, 29);
      final expected = {
        for (var n = 1; n <= 29; n++) ...[suhoorId(n), iftarId(n), taraweehId(n)],
        for (var n = 21; n <= 29; n++) lastTenId(n),
      };
      expect(p.ids, expected);
      expect(p.reminders, hasLength(29 * 3 + 9));
      expect(p.runwayAt, isNull, reason: 'the alarms themselves are armed');
      // Every id sits inside the namespace block.
      for (final id in p.ids) {
        expect(id, inInclusiveRange(210000, 210999));
        expect(RamadanNotificationIds.owns(id), isTrue);
      }
    });

    test('the moments: 45 minutes before Fajr, 15 before Maghrib, after Isha', () {
      final p = plan(now);
      PlannedRamadanReminder one(RamadanReminderKind k, int n) => p.reminders.singleWhere((r) => r.kind == k && r.number == n);
      // Day 5 is 12 February.
      expect(one(RamadanReminderKind.suhoor, 5).at, DateTime(2027, 2, 12, 4, 45));
      expect(one(RamadanReminderKind.suhoor, 5).eventAt, DateTime(2027, 2, 12, 5, 30));
      expect(one(RamadanReminderKind.iftar, 5).at, DateTime(2027, 2, 12, 17, 5));
      // Night 5 begins on the evening of 11 February: Isha 18:45 + 30 minutes.
      expect(one(RamadanReminderKind.taraweeh, 5).at, DateTime(2027, 2, 11, 19, 15));
      expect(one(RamadanReminderKind.taraweeh, 5).date, DateTime(2027, 2, 11));
      // Night 27 begins on the evening of 5 March: Isha + 60 minutes.
      expect(one(RamadanReminderKind.lastTenNight, 27).at, DateTime(2027, 3, 5, 19, 45));
      // Night 1 begins on the evening before the first day.
      expect(one(RamadanReminderKind.taraweeh, 1).date, DateTime(2027, 2, 7));
      expect(p.reminders.every((r) => r.hijriYear == 1448), isTrue);
    });

    test('nothing outside the month: no reminder before the evening of night 1 or after the last iftar', () {
      final p = plan(now);
      final firstMoment = DateTime(2027, 2, 7, 19, 15); // Taraweeh of night 1 is the earliest
      // The earliest suhoor is day 1 at 04:45 (8 February) - later than night 1's Taraweeh.
      expect(p.reminders.first.at, firstMoment);
      expect(p.reminders.last.at.isBefore(DateTime(2027, 3, 9)), isTrue, reason: '1 Shawwal (9 March) has no reminder');
      for (final r in p.reminders) {
        expect(calendar.isRamadan(r.date) || r.kind == RamadanReminderKind.taraweeh || r.kind == RamadanReminderKind.lastTenNight, isTrue);
      }
      // After the Eid the same call plans nothing for this year.
      final after = plan(DateTime(2027, 3, 9, 12));
      expect(after.reminders, isEmpty);
      expect(after.span.hijriYear, 1449, reason: 'the next Ramadan');
    });

    test('nothing in the past, mid-month', () {
      // Day 13 (20 February), 12:00.
      final mid = DateTime(2027, 2, 20, 12);
      final p = plan(mid);
      expect(p.reminders.every((r) => r.at.isAfter(mid)), isTrue);
      expect(p.reminders.where((r) => r.kind == RamadanReminderKind.suhoor).map((r) => r.number).toList(), [for (var n = 14; n <= 29; n++) n]);
      // Suhoor of day 13 (04:45 today) has gone; the iftar of day 13 (17:05) is still to come.
      expect(p.ids, isNot(contains(suhoorId(13))));
      expect(p.ids, contains(iftarId(13)));
      // Night 13 began last evening; night 14 begins this evening.
      expect(p.ids, isNot(contains(taraweehId(13))));
      expect(p.ids, contains(taraweehId(14)));
      // Exactly at a reminder's moment it is no longer in the future.
      final p2 = plan(DateTime(2027, 2, 20, 17, 5));
      expect(p2.ids, isNot(contains(iftarId(13))));
      expect(p2.ids, contains(iftarId(14)));
    });

    test('planning twice gives the same plan and the same ids', () {
      expect(plan(now).reminders, plan(now).reminders);
      expect(plan(now).ids, plan(now).ids);
    });

    test('the Eid and the days around it carry no fasting reminder (Part 9b\'s exclusion wins)', () {
      final span = calendar.spanOfYear(1448);
      const fasting = FastingConfig();
      for (var n = 1; n <= span.length; n++) {
        expect(FastingRules.reminderOn(span.dateOfDay(n), fasting), isNull, reason: 'day $n of Ramadan');
      }
      expect(FastingRules.reminderOn(span.eidDay, fasting), isNull, reason: '1 Shawwal');
    });
  });

  group('the Hijri shift moves every reminder', () {
    final now = DateTime(2027, 1, 20, 12);

    for (final (offset, first) in [(-1, DateTime(2027, 2, 9)), (0, DateTime(2027, 2, 8)), (1, DateTime(2027, 2, 7))]) {
      test('offset $offset: the first day is $first and the first iftar falls on it', () {
        final p = plan(now, cal: RamadanCalendar(offsetDays: offset));
        expect(p.span.first, first);
        final iftar1 = p.reminders.singleWhere((r) => r.kind == RamadanReminderKind.iftar && r.number == 1);
        expect(iftar1.date, first);
        expect(iftar1.at, DateTime(first.year, first.month, first.day, 17, 5));
        final taraweeh1 = p.reminders.singleWhere((r) => r.kind == RamadanReminderKind.taraweeh && r.number == 1);
        expect(taraweeh1.date, DateTime(first.year, first.month, first.day - 1));
        // The ids do not depend on the calendar, the moments do.
        final lastNight = p.span.length;
        expect(p.ids, containsAll([suhoorId(1), iftarId(lastNight), taraweehId(lastNight)]));
        expect(p.reminders.every((r) => r.number <= p.span.length), isTrue);
      });
    }
  });

  group('switches and lead times', () {
    final now = DateTime(2027, 1, 20, 12);

    test('each reminder can be switched off on its own', () {
      for (final (cfg, kind) in [
        (const RamadanConfig(suhoorReminder: false), RamadanReminderKind.suhoor),
        (const RamadanConfig(iftarReminder: false), RamadanReminderKind.iftar),
        (const RamadanConfig(taraweehReminder: false), RamadanReminderKind.taraweeh),
        (const RamadanConfig(lastTenReminder: false), RamadanReminderKind.lastTenNight),
      ]) {
        final p = plan(now, config: cfg);
        expect(p.reminders.where((r) => r.kind == kind), isEmpty, reason: kind.name);
        expect(p.reminders, isNotEmpty);
      }
      final none = plan(
        now,
        config: const RamadanConfig(suhoorReminder: false, iftarReminder: false, taraweehReminder: false, lastTenReminder: false),
      );
      expect(none.reminders, isEmpty);
      expect(none.runwayAt, isNull);
    });

    test('the lead times are the owner\'s: iftar 30 minutes before, suhoor 60 before', () {
      final p = plan(now, config: const RamadanConfig(iftarLeadMinutes: 30, suhoorLeadMinutes: 60));
      expect(p.reminders.singleWhere((r) => r.kind == RamadanReminderKind.iftar && r.number == 3).at, DateTime(2027, 2, 10, 16, 50));
      expect(p.reminders.singleWhere((r) => r.kind == RamadanReminderKind.suhoor && r.number == 3).at, DateTime(2027, 2, 10, 4, 30));
    });

    test('defaults are 15 and 45; a silly lead is clamped, never negative or past the event', () {
      const d = RamadanConfig();
      expect((d.iftarLeadMinutes, d.suhoorLeadMinutes), (15, 45));
      final p = plan(now, config: const RamadanConfig(iftarLeadMinutes: -5, suhoorLeadMinutes: 100000));
      final iftar = p.reminders.firstWhere((r) => r.kind == RamadanReminderKind.iftar);
      expect(iftar.at.isBefore(iftar.eventAt), isTrue);
      final suhoor = p.reminders.firstWhere((r) => r.kind == RamadanReminderKind.suhoor);
      expect(suhoor.eventAt.difference(suhoor.at), const Duration(minutes: 180));
    });

    test('the config survives its JSON and reads damage as the defaults', () {
      const c = RamadanConfig(atmosphere: false, iftarReminder: false, iftarLeadMinutes: 20, suhoorLeadMinutes: 90, hubKhatmah: false);
      expect(RamadanConfig.fromJson(c.toJson()), c);
      expect(RamadanConfig.fromJson('junk'), const RamadanConfig());
      expect(RamadanConfig.fromJson({'iftarLeadMinutes': 'x', 'atmosphere': 3}), const RamadanConfig());
    });
  });

  group('before Ramadan', () {
    test('far away: no alarm yet, one notice asks him to open Madar, 40 days before the first day at 10:00', () {
      final p = plan(DateTime(2026, 11, 10, 9));
      expect(p.reminders, isEmpty);
      expect(p.runwayAt, DateTime(2026, 12, 30, 10));
      expect(p.span.first, DateTime(2027, 2, 8));
    });

    test('the alarms are armed from 45 days before the first day, not 46', () {
      expect(plan(DateTime(2026, 12, 25, 12)).reminders, isNotEmpty);
      expect(plan(DateTime(2026, 12, 25, 12)).runwayAt, isNull);
      expect(plan(DateTime(2026, 12, 24, 12)).reminders, isEmpty);
      expect(plan(DateTime(2026, 12, 24, 12)).runwayAt, isNotNull);
    });

    test('the evening before the first day: night 1\'s Taraweeh and the first suhoor are still ahead', () {
      final p = plan(DateTime(2027, 2, 7, 12));
      expect(p.ids, containsAll([taraweehId(1), suhoorId(1), iftarId(1)]));
    });
  });

  group('ids', () {
    test('the kind blocks never meet and one-offs stay clear of them', () {
      final all = <int>{};
      for (final k in RamadanReminderKind.values) {
        for (var d = 1; d <= 30; d++) {
          expect(all.add(RamadanNotificationIds.forDay(k, d)), isTrue, reason: '${k.name} $d');
        }
      }
      expect(all.every((id) => id < RamadanNotificationIds.startingSoon), isTrue);
    });
  });
}
