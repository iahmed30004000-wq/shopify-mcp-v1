import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/features/fasting/domain/fasting_log.dart';
import 'package:madar/features/fasting/domain/fasting_models.dart';
import 'package:madar/features/fasting/domain/fasting_planner.dart';
import 'package:madar/features/fasting/domain/fasting_rules.dart';
import 'package:madar/features/wird/domain/calendar_days.dart';

import 'fasting_test_support.dart';

DateTime? isha1930(DateTime day) => DateTime(day.year, day.month, day.day, 19, 30);

void main() {
  final y1448 = HijriYearView(1448);

  group('placing at Isha', () {
    test('the evening before, Isha plus the minutes', () {
      final r = FastingRules.reminderOn(y1448.civil(12, 9, 0), cfg(0))!;
      final p = FastingPlanner.placeAtIsha(r, ishaOf: isha1930);
      final eve = CalendarDays.add(r.day, -1);
      expect(p.at, DateTime(eve.year, eve.month, eve.day, 19, 50));
      expect(p.usedFallback, isFalse);
      expect(FastingPlanner.placeAtIsha(r, ishaOf: isha1930, afterIshaMinutes: 0).at, DateTime(eve.year, eve.month, eve.day, 19, 30));
      expect(FastingPlanner.placeAtIsha(r, ishaOf: isha1930, afterIshaMinutes: -5).at, DateTime(eve.year, eve.month, eve.day, 19, 30));
    });

    test('the callback is asked for the EVENING before, not the fasting day', () {
      final asked = <DateTime>[];
      final r = FastingRules.reminderOn(y1448.civil(12, 9, 0), cfg(0))!;
      FastingPlanner.placeAtIsha(
        r,
        ishaOf: (d) {
          asked.add(d);
          return null;
        },
      );
      expect(asked, [CalendarDays.add(r.day, -1)]);
    });

    test('Isha missing: not skipped, 21:00 of that evening, flagged', () {
      final r = FastingRules.reminderOn(y1448.civil(12, 9, 0), cfg(0))!;
      final p = FastingPlanner.placeAtIsha(r, ishaOf: (_) => null);
      final eve = CalendarDays.add(r.day, -1);
      expect(p.at, DateTime(eve.year, eve.month, eve.day, 21));
      expect(p.usedFallback, isTrue);
    });
  });

  group('plan', () {
    final now = DateTime(2026, 11, 10, 12);

    test('sorted by time, all in the future, one per fasting day', () {
      final plan = FastingPlanner.plan(config: cfg(0), now: now, ishaOf: isha1930);
      expect(plan, isNotEmpty);
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].at.isAfter(plan[i - 1].at), isTrue);
      }
      expect(plan.every((p) => p.at.isAfter(now)), isTrue);
      expect({for (final p in plan) CalendarDays.key(p.reminder.day)}.length, plan.length);
    });

    test('matches the rules day by day over a window', () {
      final plan = FastingPlanner.plan(config: cfg(0), now: now, ishaOf: isha1930, daysAhead: 60);
      final today = CalendarDays.dateOnly(now);
      final ruleDays = FastingRules.remindersBetween(today, CalendarDays.add(today, 60), cfg(0)).map((r) => CalendarDays.key(r.day)).toSet();
      // The evening before day 0 is already gone; every other rule day is planned.
      expect({for (final p in plan) CalendarDays.key(p.reminder.day)}, ruleDays.difference({CalendarDays.key(today)}));
    });

    test('a reminder whose evening has passed is not planned; one still ahead is', () {
      final r = FastingRules.reminderOn(y1448.civil(12, 9, 0), cfg(0))!;
      final eve = CalendarDays.add(r.day, -1);
      List<PlannedFastReminder> at(DateTime t) => FastingPlanner.plan(config: cfg(0), now: t, ishaOf: isha1930, daysAhead: 3);
      expect(at(DateTime(eve.year, eve.month, eve.day, 19, 49)).any((p) => p.reminder.kind == FastKind.arafah), isTrue);
      expect(at(DateTime(eve.year, eve.month, eve.day, 19, 51)).any((p) => p.reminder.kind == FastKind.arafah), isFalse);
    });

    test('works for any far future date with no stored schedule', () {
      final far = DateTime(2060, 3, 1, 8);
      final plan = FastingPlanner.plan(config: cfg(0), now: far, ishaOf: isha1930, daysAhead: 40);
      expect(plan, isNotEmpty);
      expect(plan.every((p) => p.reminder.day.year >= 2060), isTrue);
    });

    test('«لأ» silences only that day; «ناوي» already answered is not asked again', () {
      final base = FastingPlanner.plan(config: cfg(0), now: now, ishaOf: isha1930);
      final target = base[2].reminder.day;
      final other = base[3].reminder.day;
      final no = FastingPlanner.plan(
        config: cfg(0),
        now: now,
        ishaOf: isha1930,
        intentions: [FastIntention(day: target, choice: FastIntentionChoice.no)],
      );
      expect(no.length, base.length - 1);
      expect(no.any((p) => CalendarDays.same(p.reminder.day, target)), isFalse);
      expect(no.any((p) => CalendarDays.same(p.reminder.day, other)), isTrue);
      final yes = FastingPlanner.plan(
        config: cfg(0),
        now: now,
        ishaOf: isha1930,
        intentions: [FastIntention(day: target, choice: FastIntentionChoice.yes)],
      );
      expect(yes.length, base.length - 1);
    });

    test('Isha unknown on one evening only affects that evening', () {
      final base = FastingPlanner.plan(config: cfg(0), now: now, ishaOf: isha1930);
      final badEve = CalendarDays.add(base[1].reminder.day, -1);
      final plan = FastingPlanner.plan(
        config: cfg(0),
        now: now,
        ishaOf: (d) => CalendarDays.same(d, badEve) ? null : isha1930(d),
      );
      expect(plan.map((p) => p.usedFallback).toList(), [for (var i = 0; i < base.length; i++) i == 1]);
      expect(plan.map((p) => p.reminder.key).toList().toSet(), base.map((p) => p.reminder.key).toSet());
    });

    test('offset changed while reminders are pending: a fresh plan equals a plan made fresh', () {
      final a = FastingPlanner.plan(config: cfg(0), now: now, ishaOf: isha1930, daysAhead: 400);
      final b = FastingPlanner.plan(config: cfg(1), now: now, ishaOf: isha1930, daysAhead: 400);
      final b2 = FastingPlanner.plan(config: FastingConfig.fromJson(cfg(1).toJson()), now: now, ishaOf: isha1930, daysAhead: 400);
      expect(b, b2);
      expect(b, isNot(a));
      // The weekday reminders (and their ids) are untouched; the Hijri ones moved.
      Set<String> weekday(List<PlannedFastReminder> l) =>
          {for (final p in l) if (p.reminder.kind == FastKind.monday || p.reminder.kind == FastKind.thursday) p.reminder.key};
      expect(weekday(a).intersection(weekday(b)).length, greaterThan(40));
    });

    test('re-arming across a month boundary and a year boundary', () {
      // From the last days of Dhu al-Hijjah 1448 the next plan reaches
      // Muharram 1449 by itself, with no stored schedule in between.
      final now2 = CalendarDays.add(y1448.lastDay, -6);
      final plan = FastingPlanner.plan(config: cfg(0), now: now2, ishaOf: isha1930, daysAhead: 20);
      expect(plan.map((p) => p.reminder.hijri.year).toSet(), {1448, 1449});
      expect(plan.any((p) => p.reminder.hijri.month == 1 && p.reminder.hijri.year == 1449), isTrue);
      // Month boundary: end of Sha'ban into Ramadan: no reminder inside Ramadan.
      final sha = HijriYearView(1448);
      final lastSha = CalendarDays.add(sha.starts[8]!, sha.lengths[8]! - 1);
      final p2 = FastingPlanner.plan(config: cfg(0), now: CalendarDays.add(lastSha, -6), ishaOf: isha1930, daysAhead: 20);
      expect(p2.any((p) => p.reminder.hijri.month == 9), isFalse);
      expect(p2.any((p) => p.reminder.hijri.month == 8), isTrue);
    });

    test('a plan serialises its action payload', () {
      final p = FastingPlanner.plan(config: cfg(0), now: now, ishaOf: isha1930).first;
      expect(p.data['day'], CalendarDays.key(p.reminder.day));
      expect(FastKind.fromId(p.data['kind']), p.reminder.kind);
    });
  });

  group('notification ids', () {
    test('the block is 200000-200999 and cannot overlap a known namespace', () {
      expect(FastingNotificationIds.namespace.first, 200000);
      expect(FastingNotificationIds.namespace.last, 200999);
      expect(NotificationNamespaces.fasting, FastingNotificationIds.namespace);
      for (final ns in NotificationNamespaces.all) {
        if (ns == NotificationNamespaces.fasting) continue;
        expect(ns.contains(200000) || ns.contains(200999), isFalse, reason: ns.name);
      }
    });

    for (final offset in [-1, 0, 1]) {
      test('offset $offset: five Hijri years of reminders, all inside the block and collision-free', () {
        final from = HijriYearView(1448).firstDay;
        final to = HijriYearView(1452).lastDay;
        final rs = FastingRules.remindersBetween(from, to, cfg(offset));
        expect(rs.length, greaterThan(500));
        final byId = <int, String>{};
        for (final r in rs) {
          final id = FastingNotificationIds.idFor(r);
          expect(FastingNotificationIds.namespace.contains(id), isTrue, reason: r.key);
          expect(byId.containsKey(id), isFalse, reason: '${r.key} collides with ${byId[id]}');
          byId[id] = r.key;
        }
      });
    }

    test('every possible (day, kind) of five years gets an id in the block, and the same one each time', () {
      // Beyond the winners: also the lower-priority kinds a day could carry.
      final from = HijriYearView(1448).firstDay;
      final to = HijriYearView(1452).lastDay;
      final seen = <String, int>{};
      for (var d = from; !d.isAfter(to); d = CalendarDays.add(d, 1)) {
        final h = FastingRules.hijriOf(d, cfg(0));
        for (final k in FastingRules.applicable(h, d.weekday)) {
          final r = FastReminder(day: d, hijri: h, kind: k);
          final id = FastingNotificationIds.idFor(r);
          expect(FastingNotificationIds.namespace.contains(id), isTrue);
          expect(FastingNotificationIds.idFor(r), id);
          seen['${CalendarDays.key(d)}.${k.id}'] = id;
        }
      }
      // Two different (day, kind) of the same kind never share an id.
      for (final k in FastKind.values) {
        final ids = [for (final e in seen.entries) if (e.key.endsWith('.${k.id}')) e.value];
        expect(ids.toSet().length, ids.length, reason: k.id);
      }
    });

    test('same fasting day + kind => same id, whatever else changes', () {
      final r = FastingRules.reminderOn(y1448.civil(12, 9, 0), cfg(0))!;
      final again = FastReminder(day: r.day, hijri: r.hijri, kind: r.kind, alsoKinds: const [FastKind.monday]);
      expect(FastingNotificationIds.idFor(again), FastingNotificationIds.idFor(r));
      final planned = FastingPlanner.placeAtIsha(r, ishaOf: isha1930);
      expect(planned.notificationId, FastingNotificationIds.idFor(r));
    });
  });
}
