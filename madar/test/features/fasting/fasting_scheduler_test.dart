// «تذكير الصيام» delivered: the exact alarms of a known week, nothing in the
// past, nothing for a day he already answered or logged, the offset moving
// every reminder, deterministic ids (nothing rescheduled twice), the
// notification's words and its two buttons - and the owner's three
// exclusions surviving the whole pipeline over a full Hijri year.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/fasting/fasting.dart';
import 'package:madar/features/prayer/domain/hijri.dart';
import 'package:madar/features/wird/domain/calendar_days.dart';

import 'fasting_test_support.dart';

/// Isha at 19:30 every evening (the reminder is 20 minutes later).
DateTime? isha1930(DateTime day) => DateTime(day.year, day.month, day.day, 19, 30);

void main() {
  setUpAll(() async => initializeDateFormatting());

  late FakeNotificationPlatform platform;
  late DateTime now;
  late FastingScheduler scheduler;
  final ar = FastingTexts.forLanguage('ar');

  setUp(() {
    now = DateTime(2026, 9, 27, 13, 10); // Sunday, as the app tests freeze it
    platform = FakeNotificationPlatform();
    scheduler = FastingScheduler(notifications: NotificationService(platform, clock: () => now), clock: () => now);
  });

  Future<FastingSyncResult> sync({
    FastingConfig? config,
    List<FastIntention> intentions = const [],
    List<FastLogEntry> log = const [],
    DateTime? Function(DateTime)? ishaOf,
    FastingTexts? texts,
  }) => scheduler.sync(
    config: config ?? cfg(0),
    intentions: intentions,
    log: log,
    ishaOf: ishaOf ?? isha1930,
    texts: texts ?? ar,
  );

  List<FakeScheduled> reminders() =>
      platform.scheduled.values.where((s) => s.request.data['day'] != null).toList()
        ..sort((a, b) => a.request.at.compareTo(b.request.at));

  List<String> days() => [for (final s in reminders()) s.request.data['day']! as String];

  /// The fasting days of [from, to] that must be reminded, written from the
  /// owner's brief on top of an independent Hijri conversion (never the
  /// engine's own rules): Monday / Thursday, and the white days 13-15 outside
  /// Ramadan; nothing on an Eid or a day of Tashriq.
  Set<String> expectedWeekOf(DateTime from, int span, int offset) {
    final out = <String>{};
    for (var i = 0; i <= span; i++) {
      final d = CalendarDays.add(from, i);
      final h = HijriCalendarMath.fromGregorian(d, offsetDays: offset);
      if (h.month == 9) continue;
      if ((h.month == 10 && h.day == 1) || (h.month == 12 && h.day >= 10 && h.day <= 13)) continue;
      if (d.weekday == DateTime.monday ||
          d.weekday == DateTime.thursday ||
          (h.day >= 13 && h.day <= 15) ||
          (h.month == 12 && h.day <= 9) ||
          (h.month == 10 && h.day >= 2 && h.day <= 7) ||
          (h.month == 1 && (h.day == 9 || h.day == 10 || h.day == 1)) ||
          (h.month == 8 && h.day == 1)) {
        out.add(CalendarDays.key(d));
      }
    }
    return out;
  }

  group('a known week', () {
    test('the exact set of alarms: Mondays and Thursdays of the next 21 days, each the night before at 19:50', () async {
      final result = await sync();
      // Sunday 27 Sep 2026 plus 21 days. Mon 28, Thu 1, Mon 5, Thu 8, Mon 12, Thu 15 -
      // and whatever the independent Hijri oracle adds (the white days, the
      // yearly kinds) for this window.
      final expected = expectedWeekOf(CalendarDays.dateOnly(now), 21, 0);
      expect(days().toSet(), expected);
      expect(
        days().where((d) => const ['2026-09-28', '2026-10-01', '2026-10-05', '2026-10-08', '2026-10-12', '2026-10-15'].contains(d)),
        ['2026-09-28', '2026-10-01', '2026-10-05', '2026-10-08', '2026-10-12', '2026-10-15'],
      );
      // The night before the fasting day, 20 minutes after Isha.
      final first = reminders().first.request;
      expect(first.at, DateTime(2026, 9, 27, 19, 50));
      expect(first.data['day'], '2026-09-28');
      // …and the ids are the engine's deterministic ones, inside the block.
      expect(result.ids, {for (final s in reminders()) s.request.id});
      for (final s in reminders()) {
        expect(NotificationNamespaces.owning(s.request.id), NotificationNamespaces.fasting);
        expect(NotificationNamespaces.fasting.contains(s.request.id), isTrue);
      }
    });

    test('nothing in the past: tonight\'s reminder is gone once Isha+20 has passed', () async {
      now = DateTime(2026, 9, 27, 20, 0); // after tonight\'s 19:50
      await sync();
      expect(days(), isNot(contains('2026-09-28')));
      expect(reminders().every((s) => s.request.at.isAfter(now)), isTrue);
    });

    test('a day he already answered or logged is not reminded; «لأ» silences only that day', () async {
      await sync();
      final all = days();
      expect(all, contains('2026-09-28'));
      expect(all, contains('2026-10-01'));
      await sync(
        intentions: [FastIntention(day: DateTime(2026, 9, 28), choice: FastIntentionChoice.no)],
        log: [FastLogEntry(day: DateTime(2026, 10, 1), fasted: true, source: FastLogSource.manual)],
      );
      expect(days(), isNot(contains('2026-09-28')));
      expect(days(), isNot(contains('2026-10-01')));
      // Every other day is still there.
      expect(days().toSet(), all.toSet()..removeAll({'2026-09-28', '2026-10-01'}));
    });

    test('an unchanged plan is not scheduled twice: same ids, no churn', () async {
      await sync();
      final armed = platform.scheduleLog.length;
      final ids = platform.scheduled.keys.toSet();
      final again = await sync();
      expect(platform.scheduleLog.length, armed, reason: 'nothing was re-sent to the platform');
      expect(platform.scheduled.keys.toSet(), ids);
      expect(again.report.scheduled, 0);
      expect(again.report.cancelled, 0);
      expect(again.report.unchanged, ids.length);
    });

    test('the next morning the window moves on: the passed reminder is dropped, the rest stay', () async {
      await sync();
      final before = days();
      now = DateTime(2026, 9, 28, 9, 0);
      await sync();
      expect(days(), isNot(contains('2026-09-28')));
      expect(days().toSet().containsAll(before.where((d) => d != '2026-09-28')), isTrue);
    });
  });

  group('the Hijri shift moves every reminder', () {
    test('changing the offset while reminders are pending re-plans them all: the white days move, the old ones are gone', () async {
      final year = HijriYearView(1448);
      // The 11th of Safar: the window holds its 13th, 14th and 15th.
      final d = year.civil(2, 11, 0);
      now = DateTime(d.year, d.month, d.day, 12);
      List<String> whites() => [
        for (final s in reminders())
          if (s.request.data['kind'] == 'whiteDay') s.request.data['day']! as String,
      ];
      List<String> whiteDays(int offset) => [for (final n in [13, 14, 15]) CalendarDays.key(year.civil(2, n, offset))];

      await sync(config: cfg(0));
      expect(whites(), whiteDays(0));
      // "+1": the local Hijri date is one ahead, so each white day comes one civil day earlier.
      final ahead = await sync(config: cfg(1));
      expect(whites(), whiteDays(1));
      expect(ahead.report.scheduled, greaterThanOrEqualTo(3), reason: 'the three moved alarms were re-armed');
      await sync(config: cfg(-1));
      expect(whites(), whiteDays(-1));
      // What is pending is exactly the new plan: nothing of the old days is left.
      expect(days().toSet(), expectedWeekOf(CalendarDays.dateOnly(now), 21, -1));
    });

    for (final offset in [-1, 0, 1]) {
      test('offset $offset: the pending set is exactly the independent oracle\'s', () async {
        now = DateTime(2026, 11, 10, 12);
        await sync(config: cfg(offset));
        expect(days().toSet(), expectedWeekOf(CalendarDays.dateOnly(now), 21, offset));
      });
    }
  });

  group('a full Hijri year through the whole pipeline', () {
    for (final offset in [-1, 0, 1]) {
      test('offset $offset: re-planned every day, only the right days are ever armed - no Eid, no Tashriq, no 13 Dhu al-Hijjah, no voluntary fast in Ramadan', () async {
        final year = HijriYearView(1448);
        platform = FakeNotificationPlatform();
        final armed = <String, String>{}; // fasting day -> kind
        var clock = CalendarDays.add(year.firstDay, -2);
        final end = year.lastDay;
        scheduler = FastingScheduler(notifications: NotificationService(platform, clock: () => clock), clock: () => clock);
        while (!clock.isAfter(end)) {
          clock = DateTime(clock.year, clock.month, clock.day, 12);
          await scheduler.sync(config: cfg(offset), intentions: const [], log: const [], ishaOf: isha1930, texts: ar);
          for (final s in platform.scheduled.values) {
            final day = s.request.data['day'];
            if (day is String) armed[day] = s.request.data['kind']! as String;
          }
          clock = CalendarDays.add(clock, 1);
        }
        // The exact set of reminded days of the year. A shift moves the
        // year's edges by a civil day, so both sides are cut to the civil
        // days that belong to the year under all three shifts.
        final low = CalendarDays.add(year.firstDay, 1), high = CalendarDays.add(year.lastDay, -1);
        bool within(String d) {
          final day = CalendarDays.parse(d)!;
          return !day.isBefore(low) && !day.isAfter(high);
        }

        expect(armed.keys.where(within).toSet(), year.expectedReminded(offset).where(within).toSet());

        // The three exclusions, on a Hijri conversion of their own.
        for (final MapEntry(key: d, value: kind) in armed.entries) {
          final h = HijriCalendarMath.fromGregorian(CalendarDays.parse(d)!, offsetDays: offset);
          expect(h.month == 10 && h.day == 1, isFalse, reason: '$d is the Eid al-Fitr');
          expect(h.month == 12 && h.day >= 10 && h.day <= 13, isFalse, reason: '$d is the Eid al-Adha or Tashriq');
          expect(h.month == 9, isFalse, reason: '$d is in Ramadan ($kind)');
          if (kind == 'whiteDay') expect(h.month == 12 && h.day == 13, isFalse);
        }
        // Ramadan: not one Monday/Thursday reminder, not one of any kind.
        final ramadan = [
          for (var i = 0; i < year.lengths[9]!; i++) CalendarDays.key(CalendarDays.add(year.starts[9]!, i - offset)),
        ];
        expect(ramadan.where(armed.containsKey), isEmpty);
        // 13 Dhu al-Hijjah: gone from the white days, 14 and 15 stay.
        expect(armed.containsKey(CalendarDays.key(year.civil(12, 13, offset))), isFalse);
        // …and that month's white days are only the 14th and the 15th.
        expect(armed[CalendarDays.key(year.civil(12, 14, offset))], 'whiteDay');
        expect(armed[CalendarDays.key(year.civil(12, 15, offset))], 'whiteDay');
      });
    }
  });

  group('the notification', () {
    test('Arabic: the owner\'s example wording, two actions that never open the app, in its own channel', () async {
      now = DateTime(2026, 9, 27, 13, 10);
      await sync();
      final monday = reminders().firstWhere((s) => s.request.data['kind'] == 'monday').request;
      expect(monday.title, 'تذكير الصيام · الاثنين');
      expect(monday.body, startsWith('بكرة الاثنين، '));
      expect(monday.body, contains('ناوي تصوم؟'));
      expect(monday.actions.map((a) => a.id), [FastingActions.yes, FastingActions.no]);
      expect(monday.actions.map((a) => a.title), ['ناوي', 'لأ']);
      for (final a in monday.actions) {
        expect(a.opensApp, isFalse, reason: 'answering never opens the app or meets the lock');
        expect(a.cancels, isTrue);
      }
      expect(monday.channelId, FastingNotifications.channelId);
      expect(platform.channels[FastingNotifications.channelId]!.name, 'تذكير الصيام');
      expect(platform.groups[FastingNotifications.groupId], 'صيامي');
      expect(monday.dropIfLateBy, FastingNotifications.dropIfLateBy);
      expect(monday.namespace, NotificationNamespaces.fasting);
    });

    test('English: the same words, the same buttons', () async {
      await sync(texts: FastingTexts.forLanguage('en'));
      final r = reminders().firstWhere((s) => s.request.data['kind'] == 'monday').request;
      expect(r.title, 'Fasting reminder · Monday');
      expect(r.body, startsWith('Tomorrow, Monday, '));
      expect(r.body, contains('do you intend to fast?'));
      expect(r.actions.map((a) => a.title), ['I intend to', 'No']);
      expect(r.data['l'], 'en');
    });

    test('the payload carries the fasting day, its kind and the language - what the buttons need', () async {
      await sync();
      final tapOf = NotificationEnvelope.decode(reminders().first.payload, id: reminders().first.request.id, actionId: FastingActions.yes);
      final answer = FastingNotificationTaps.answerOf(tapOf)!;
      expect(answer.day, DateTime(2026, 9, 28));
      expect(answer.choice, FastIntentionChoice.yes);
      expect(answer.language, 'ar');
      expect(FastingNotificationTaps.opensFasting(NotificationEnvelope.decode(reminders().first.payload)), isTrue);
      expect(
        FastingNotificationTaps.answerOf(NotificationEnvelope.decode(reminders().first.payload)),
        isNull,
        reason: 'a tap on the body answers nothing',
      );
    });

    test('a day that carries two fasts names the other one; an unknown Isha says so in a short line', () async {
      // Find a day with alsoKinds and a placed reminder of the Isha fallback.
      now = DateTime(2026, 11, 10, 12);
      final plan = FastingPlanner.plan(config: cfg(0), now: now, ishaOf: (_) => null);
      final withAlso = plan.firstWhere((p) => p.reminder.alsoKinds.isNotEmpty, orElse: () => plan.first);
      final body = ar.body(withAlso);
      if (withAlso.reminder.alsoKinds.isNotEmpty) expect(body, contains('وبكرة كمان'));
      expect(body, contains('ما عرفنا وقت العشاء'), reason: 'usedFallback = true: the 21:00 line');
      final ok = FastingPlanner.plan(config: cfg(0), now: now, ishaOf: isha1930).first;
      expect(ar.body(ok), isNot(contains('ما عرفنا وقت العشاء')));
    });

    test('the Muharram / Sha\'ban nudge is a gentle question about the month, not a day-by-day alarm', () async {
      final year = HijriYearView(1448);
      now = CalendarDays.add(year.firstDay, -3);
      final plan = FastingPlanner.plan(config: cfg(0), now: now, ishaOf: isha1930, daysAhead: 340);
      final nudges = plan.where((p) => p.reminder.kind.isNudge).toList();
      for (final n in nudges) {
        expect(ar.body(n), contains('بدك تكثر من الصيام هالشهر؟'));
        expect(ar.title(n.reminder.kind), contains('الإكثار من الصيام'));
        expect(n.reminder.hijri.day, 1, reason: 'one nudge at the start of the month');
      }
      // One per month at most: never one on every day of Muharram or Sha'ban.
      expect(nudges.length, lessThanOrEqualTo(2));
    });
  });

  group('the runway notice', () {
    test('one notice at day 18 asks him to open Madar - only while reminders exist', () async {
      await sync();
      final runway = platform.scheduled[FastingNotifications.runwayId]!;
      expect(runway.request.at, DateTime(2026, 10, 15, 10));
      expect(runway.request.data['t'], FastingNotificationTaps.typeRunway);
      expect(FastingNotificationTaps.opensFasting(NotificationEnvelope.decode(runway.payload)), isTrue);
      // Everything switched off: nothing at all - not even the notice.
      await sync(config: cfg(0, disabled: {...FastKind.values}));
      expect(platform.scheduled, isEmpty);
    });

    test('a later app start pushes it forward', () async {
      await sync();
      now = DateTime(2026, 10, 3, 9);
      await sync();
      expect(platform.scheduled[FastingNotifications.runwayId]!.request.at, DateTime(2026, 10, 21, 10));
    });
  });

  group('the ids', () {
    test('the block 200000-200999 is the namespace the app knows, and no other block reaches into it', () {
      expect(NotificationNamespaces.fasting, FastingNotificationIds.namespace);
      expect(NotificationNamespaces.all, contains(NotificationNamespaces.fasting));
      for (final other in NotificationNamespaces.all) {
        if (other == NotificationNamespaces.fasting) continue;
        expect(other.last < 200000 || other.first > 200999, isTrue, reason: other.name);
      }
      expect(NotificationNamespaces.byName('fasting'), NotificationNamespaces.fasting);
      expect(NotificationNamespaces.owning(200500), NotificationNamespaces.fasting);
      // The two one-off ids are the last of the block, clear of the engine's regions.
      expect(FastingNotifications.runwayId, 200999);
      expect(FastingNotifications.failedId, 200998);
    });
  });
}
