// «أهدافه بكلامه» (Part 14): «الكهف كل جمعة» · «راجع جزء عمّ» · «N صفحات
// باليوم», read off the recitation log, with their reminders hung off the
// prayer times and nothing else.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/hifz/hifz_memorisation.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/tasmee/tasmee.dart';

import 'hifz_plan_fixtures.dart';

DayTimes _times(DateTime day) => DayTimes(
  day: day,
  fajr: DateTime(day.year, day.month, day.day, 4, 40),
  sunrise: DateTime(day.year, day.month, day.day, 6, 5),
  dhuhr: DateTime(day.year, day.month, day.day, 11, 50),
  asr: DateTime(day.year, day.month, day.day, 15, 15),
  maghrib: DateTime(day.year, day.month, day.day, 17, 45),
  isha: DateTime(day.year, day.month, day.day, 19, 5),
);

void main() {
  final shape = testShape();
  final friday = DateTime(2026, 10, 16); // Friday
  final thursday = DateTime(2026, 10, 15);
  const kahf = AyahRange(AyahRef(18, 1), AyahRef(18, 110));
  const juzAmma = AyahRange(AyahRef(78, 1), AyahRef(114, 6));

  HifzGoal kahfGoal({PrayerWindow? window = PrayerWindow.fajr, int offset = 15, bool remind = true}) => HifzGoal(
    id: 'g-kahf',
    title: 'الكهف كل جمعة',
    kind: HifzGoalKind.rangeOnWeekday,
    range: kahf,
    weekday: DateTime.friday,
    window: window,
    offsetMinutes: offset,
    remind: remind,
    createdAt: DateTime(2026, 10, 1),
  );

  test('«الكهف كل جمعة» is due on Friday and not on Thursday', () {
    final goal = kahfGoal();
    expect(goal.appliesOn(friday), isTrue);
    expect(goal.appliesOn(thursday), isFalse);
    final onFriday = HifzGoalProgressReader.of(goal, day: friday, shape: shape, log: const []);
    expect(onFriday.due, isTrue);
    expect(onFriday.target, 110);
    expect(onFriday.done, 0);
    expect(onFriday.met, isFalse);
    expect(HifzGoalProgressReader.of(goal, day: thursday, shape: shape, log: const []).due, isFalse);
  });

  test('it is met when the whole surah was actually recited that day, not before', () {
    final part = [cleanSessionOf(shape, const AyahRange(AyahRef(18, 1), AyahRef(18, 50)), friday)];
    final partly = HifzGoalProgressReader.of(kahfGoal(), day: friday, shape: shape, log: part);
    expect(partly.done, 50);
    expect(partly.met, isFalse);
    expect(partly.remaining!.first, const AyahRange(AyahRef(18, 51), AyahRef(18, 110)));

    final whole = [cleanSessionOf(shape, kahf, friday)];
    final done = HifzGoalProgressReader.of(kahfGoal(), day: friday, shape: shape, log: whole);
    expect(done.done, 110);
    expect(done.met, isTrue);
    expect(done.remaining, isEmpty);

    final lastWeek = [cleanSessionOf(shape, kahf, DateTime(2026, 10, 9))];
    final stale = HifzGoalProgressReader.of(kahfGoal(), day: friday, shape: shape, log: lastWeek);
    expect(stale.done, 0, reason: 'last Friday does not count for this one');
    expect(stale.lastDoneDay, DateTime(2026, 10, 9));
  });

  test('«راجع جزء عمّ» is a rolling week: it counts what was covered inside its window', () {
    final goal = HifzGoal(
      id: 'g-amma',
      title: 'راجع جزء عمّ',
      kind: HifzGoalKind.rangeReview,
      range: juzAmma,
      withinDays: 7,
      createdAt: DateTime(2026, 10, 1),
    );
    final log = [
      cleanSessionOf(shape, const AyahRange(AyahRef(78, 1), AyahRef(78, 40)), DateTime(2026, 10, 12)),
      cleanSessionOf(shape, const AyahRange(AyahRef(79, 1), AyahRef(79, 46)), DateTime(2026, 10, 14)),
      // outside the window: it does not count
      cleanSessionOf(shape, const AyahRange(AyahRef(80, 1), AyahRef(80, 42)), DateTime(2026, 10, 1)),
    ];
    final p = HifzGoalProgressReader.of(goal, day: thursday, shape: shape, log: log);
    expect(p.due, isTrue);
    expect(p.done, 86);
    expect(p.target, Mushaf.count(shape, juzAmma));
    expect(p.met, isFalse);
    expect(p.remaining!.any((r) => r.contains(const AyahRef(80, 1))), isTrue);
  });

  test('«صفحتين باليوم» counts the pages he actually touched today', () {
    final goal = HifzGoal(
      id: 'g-pages',
      title: 'صفحتين باليوم',
      kind: HifzGoalKind.amountPerDay,
      amount: 2,
      createdAt: DateTime(2026, 10, 1),
    );
    final log = [cleanSessionOf(shape, const AyahRange(AyahRef(18, 1), AyahRef(18, 20)), thursday)];
    final p = HifzGoalProgressReader.of(goal, day: thursday, shape: shape, log: log);
    expect(p.unitName, 'pages');
    expect(p.target, 2);
    expect(p.done, greaterThanOrEqualTo(2), reason: 'al-Kahf 1–20 covers more than two pages');
    expect(p.met, isTrue);

    final empty = HifzGoalProgressReader.of(goal, day: thursday, shape: shape, log: const []);
    expect(empty.done, 0);
    expect(empty.met, isFalse);
  });

  test('a lookup in «شازام القرآن» never counts towards a goal', () {
    final goal = kahfGoal();
    final log = [
      sessionOf(
        at: friday,
        mode: TasmeeMode.find,
        ayat: {for (final r in Mushaf.ayatIn(shape, kahf)) r: cleanCounts(10)},
      ),
    ];
    expect(HifzGoalProgressReader.of(goal, day: friday, shape: shape, log: log).done, 0);
  });

  group('the reminders hang off the prayer, not the clock', () {
    List<HifzGoalReminder> planFrom(List<HifzGoalProgress> goals, DateTime now, {int days = 7}) =>
        HifzGoalReminderPlanner.plan(goals: goals, timesFor: _times, now: now, days: days);

    HifzGoalProgress progressOf(HifzGoal goal, {DateTime? day, List<TasmeeSession> log = const []}) =>
        HifzGoalProgressReader.of(goal, day: day ?? thursday, shape: shape, log: log);

    test('a Friday goal is reminded on Friday only, after Fajr plus his offset', () {
      final now = DateTime(2026, 10, 15, 6, 0);
      final reminders = planFrom([progressOf(kahfGoal())], now);
      expect(reminders, hasLength(1));
      expect(reminders.single.day, friday);
      expect(reminders.single.at, DateTime(2026, 10, 16, 4, 55), reason: 'Fajr 4:40 + 15 minutes');
      expect(reminders.single.window, PrayerWindow.fajr);
      expect(reminders.single.title, 'الكهف كل جمعة', reason: 'his own words go on the notification');
    });

    test('a daily goal is reminded every day of the week ahead, and never in the past', () {
      final goal = HifzGoal(
        id: 'g-daily',
        title: 'صفحة بعد المغرب',
        kind: HifzGoalKind.amountPerDay,
        amount: 1,
        window: PrayerWindow.maghrib,
        offsetMinutes: 20,
        createdAt: DateTime(2026, 10, 1),
      );
      final afterMaghrib = DateTime(2026, 10, 15, 18, 30);
      final reminders = planFrom([progressOf(goal)], afterMaghrib);
      expect(reminders, hasLength(6), reason: 'today\'s Maghrib has already passed');
      expect(reminders.first.at, DateTime(2026, 10, 16, 18, 5));
      for (final r in reminders) {
        expect(r.at.isAfter(afterMaghrib), isTrue);
      }
    });

    test('today\'s reminder is dropped once today\'s goal is met', () {
      final goal = HifzGoal(
        id: 'g-daily',
        title: 'صفحة باليوم',
        kind: HifzGoalKind.amountPerDay,
        amount: 1,
        window: PrayerWindow.isha,
        createdAt: DateTime(2026, 10, 1),
      );
      final log = [cleanSessionOf(shape, const AyahRange(AyahRef(18, 1), AyahRef(18, 20)), thursday)];
      final now = DateTime(2026, 10, 15, 10, 0);
      final met = planFrom([progressOf(goal, log: log)], now, days: 1);
      expect(met, isEmpty, reason: 'he already did it, so he is not nagged tonight');
      final notMet = planFrom([progressOf(goal)], now, days: 1);
      expect(notMet, hasLength(1));
    });

    test('a goal that is off, or has no prayer chosen, is never planned', () {
      final now = DateTime(2026, 10, 15, 3, 0);
      expect(planFrom([progressOf(kahfGoal(remind: false))], now), isEmpty);
      expect(planFrom([progressOf(kahfGoal(window: null))], now), isEmpty);
      expect(planFrom([progressOf(kahfGoal(window: PrayerWindow.anytime))], now), isEmpty);
    });

    test('the ids live in «الحفظ»\'s own block and never collide with the wird\'s', () {
      final now = DateTime(2026, 10, 15, 3, 0);
      final goals = [
        progressOf(kahfGoal()),
        progressOf(
          HifzGoal(
            id: 'g2',
            title: 'جزء عمّ بعد العشاء',
            kind: HifzGoalKind.rangeReview,
            range: juzAmma,
            window: PrayerWindow.isha,
            sortOrder: 1,
            createdAt: DateTime(2026, 10, 1),
          ),
        ),
      ];
      final reminders = planFrom(goals, now);
      expect(reminders, isNotEmpty);
      final ids = {for (final r in reminders) r.notificationId};
      expect(ids.length, reminders.length, reason: 'one id per goal per day');
      for (final id in ids) {
        expect(NotificationNamespaces.hifz.contains(id), isTrue);
        expect(NotificationNamespaces.wird.contains(id), isFalse);
        expect(NotificationNamespaces.owning(id)?.name, 'hifz');
      }
    });

    test('planning the same day twice keeps the same ids, so nothing is rescheduled', () {
      final now = DateTime(2026, 10, 15, 3, 0);
      final a = planFrom([progressOf(kahfGoal())], now);
      final b = planFrom([progressOf(kahfGoal())], now);
      expect([for (final r in a) r.notificationId], [for (final r in b) r.notificationId]);
    });
  });
}
