import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/core/notifications/notification_service.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/wird/wird.dart';

import 'fake_quran_catalog.dart';

final _catalog = FakeQuranCatalog();
final _now = DateTime(2026, 9, 28, 13, 0); // after Dhuhr, before Asr

DayTimes _times(DateTime day) => DayTimes(
  day: day,
  fajr: DateTime(day.year, day.month, day.day, 4, 40),
  sunrise: DateTime(day.year, day.month, day.day, 6, 5),
  dhuhr: DateTime(day.year, day.month, day.day, 11, 50),
  asr: DateTime(day.year, day.month, day.day, 15, 15),
  maghrib: DateTime(day.year, day.month, day.day, 17, 45),
  isha: DateTime(day.year, day.month, day.day, 19, 5),
);

WirdPlanState _state(
  String id, {
  PrayerWindow? window = PrayerWindow.asr,
  bool remind = true,
  int offset = 15,
  bool active = true,
  List<WirdPause> pauses = const [],
  DateTime? start,
  int? khatmaDays,
  List<WirdSession> sessions = const [],
  int sortOrder = 0,
}) {
  final plan = WirdPlan(
    id: id,
    name: 'Plan $id',
    unit: WirdUnit.pages,
    amountPerDay: 2,
    start: khatmaDays == null ? const AyahRef(1, 1) : const AyahRef(114, 1),
    startDate: start ?? DateTime(2026, 9, 20),
    targetDate: khatmaDays == null ? null : CalendarDays.add(start ?? DateTime(2026, 9, 20), khatmaDays - 1),
    window: window,
    active: active,
    sortOrder: sortOrder,
    meta: WirdPlanMeta(remind: remind, remindOffsetMin: offset, pauses: pauses),
  );
  return WirdEngine.compute(
    plan: plan,
    sessions: sessions,
    axis: QuranAxis.of(_catalog, WirdUnit.pages),
    today: _now,
  );
}

void main() {
  group('planner', () {
    test('a week of reminders, the window prayer + offset', () {
      final r = WirdReminderPlanner.plan(states: [_state('a')], timesFor: _times, now: _now);
      expect(r.length, 7);
      expect(r.first.at, DateTime(2026, 9, 28, 15, 30));
      expect(r.first.today, isTrue);
      expect(r.last.at, DateTime(2026, 10, 4, 15, 30));
      expect(r.every((x) => WirdReminderIds.namespace.contains(x.notificationId)), isTrue);
      expect(r.map((x) => x.notificationId).toSet().length, 7);
    });

    test('anchors: Fajr, Duha at sunrise, Isha; no window or reminders off: none', () {
      final fajr = WirdReminderPlanner.plan(
        states: [_state('a', window: PrayerWindow.fajr, offset: 10)],
        timesFor: _times,
        now: _now,
      );
      // Today's Fajr has passed.
      expect(fajr.first.at, DateTime(2026, 9, 29, 4, 50));
      expect(fajr.length, 6);
      final duha = WirdReminderPlanner.plan(
        states: [_state('a', window: PrayerWindow.duha, offset: 20)],
        timesFor: _times,
        now: _now,
      );
      expect(duha.first.at, DateTime(2026, 9, 29, 6, 25));
      expect(WirdReminderPlanner.plan(states: [_state('a', window: PrayerWindow.anytime)], timesFor: _times, now: _now), isEmpty);
      expect(WirdReminderPlanner.plan(states: [_state('a', window: null)], timesFor: _times, now: _now), isEmpty);
      expect(WirdReminderPlanner.plan(states: [_state('a', remind: false)], timesFor: _times, now: _now), isEmpty);
    });

    test("today is skipped once today's portion is read", () {
      final done = _state(
        'a',
        sessions: [
          WirdSession(
            id: 's',
            day: DateTime(2026, 9, 28),
            range: const AyahRange(AyahRef(1, 1), AyahRef(114, 6)),
            planId: 'a',
            createdAt: DateTime(2026, 9, 28, 10),
          ),
        ],
      );
      expect(done.target.met, isTrue);
      final r = WirdReminderPlanner.plan(states: [done], timesFor: _times, now: _now);
      expect(r.first.day, DateTime(2026, 9, 29));
    });

    test('paused, not yet started and finished plans', () {
      final paused = _state('a', active: false, pauses: [WirdPause(DateTime(2026, 9, 27))]);
      expect(WirdReminderPlanner.plan(states: [paused], timesFor: _times, now: _now), isEmpty);
      final later = _state('b', start: DateTime(2026, 10, 1));
      final r = WirdReminderPlanner.plan(states: [later], timesFor: _times, now: _now);
      expect(r.first.day, DateTime(2026, 10, 1));
      expect(r.length, 4);
      final finished = _state(
        'c',
        khatmaDays: 3,
        start: DateTime(2026, 9, 27),
        sessions: [
          WirdSession(
            id: 's',
            day: DateTime(2026, 9, 27),
            range: const AyahRange(AyahRef(114, 1), AyahRef(114, 6)),
            planId: 'c',
            createdAt: DateTime(2026, 9, 27, 10),
          ),
        ],
      );
      expect(finished.completed, isTrue);
      expect(WirdReminderPlanner.plan(states: [finished], timesFor: _times, now: _now), isEmpty);
    });

    test('several plans get distinct ids per day, in plan order', () {
      final r = WirdReminderPlanner.plan(
        states: [_state('b', sortOrder: 1, window: PrayerWindow.isha), _state('a', sortOrder: 0)],
        timesFor: _times,
        now: _now,
      );
      expect(r.length, 14);
      expect(r.map((x) => x.notificationId).toSet().length, 14);
      final today = r.where((x) => x.today).toList();
      expect(today.map((x) => (x.planId, x.slot)), [('a', 0), ('b', 1)]);
    });
  });

  group('scheduling through the notification service', () {
    late FakeNotificationPlatform platform;
    late NotificationService notifications;
    final l = lookupL10n(const Locale('ar'));

    setUp(() {
      platform = FakeNotificationPlatform();
      notifications = NotificationService(platform, clock: () => _now);
    });

    Future<List<WirdReminderNotice>> sync(List<WirdPlanState> states) async {
      final reminders = WirdReminderPlanner.plan(states: states, timesFor: _times, now: _now);
      final notices = [
        for (final r in reminders) WirdReminderNotice(reminder: r, title: l.wirdReminderTitle, body: r.planName),
      ];
      await NotificationWirdReminderScheduler(
        notifications: notifications,
        texts: () => (group: l.wirdTitle, name: l.wirdReminderChannelName, description: l.wirdReminderChannelDescription),
      ).replaceAll(notices);
      return notices;
    }

    test('schedules the week in the wird id block on its own channel', () async {
      await sync([_state('a')]);
      expect(platform.scheduled.length, 7);
      expect(platform.channels.keys, contains(NotificationWirdReminderScheduler.channelId));
      final first = platform.scheduled.values.map((s) => s.request).reduce((a, b) => a.at.isBefore(b.at) ? a : b);
      expect(first.at, DateTime(2026, 9, 28, 15, 30));
      expect(first.namespace, WirdReminderIds.namespace);
      expect(first.data, {'plan': 'a'});
    });

    test('rescheduled when plans change: moved, cancelled, added', () async {
      await sync([_state('a')]);
      final before = Set.of(platform.scheduled.keys);
      await sync([_state('a', offset: 30), _state('b', window: PrayerWindow.maghrib, sortOrder: 1)]);
      expect(platform.scheduled.length, 14);
      final a = platform.scheduled.values.where((s) => s.request.data['plan'] == 'a');
      expect(a.every((s) => s.request.at.minute == 45), isTrue);
      expect(before.difference(platform.scheduled.keys.toSet()), isEmpty); // same ids, new times
      await sync([_state('b', window: PrayerWindow.maghrib, sortOrder: 1)]);
      expect(platform.scheduled.values.every((s) => s.request.data['plan'] == 'b'), isTrue);
      await sync(const []);
      expect(platform.scheduled, isEmpty);
    });

    test("the service names today's portion and cancels when nothing is wanted", () async {
      final withSchedule = WirdReminderService(
        scheduler: NotificationWirdReminderScheduler(
          notifications: notifications,
          texts: () => (group: l.wirdTitle, name: l.wirdReminderChannelName, description: l.wirdReminderChannelDescription),
        ),
        schedule: () => PrayerSchedule(const PrayerSettings()),
        clock: () => DateTime(2026, 9, 28, 0, 30),
        texts: () => (l, const MadarFormatter()),
      );
      final notices = await withSchedule.reschedule([_state('a')], catalog: _catalog);
      expect(notices, isNotEmpty);
      expect(notices.first.title, l.wirdReminderTitle);
      expect(notices.first.body, contains('الفاتحة'));
      expect(notices.skip(1).first.body, contains(l.wirdWindowAfter(l.prayerAsr)));
      expect(await withSchedule.reschedule([_state('a', remind: false)]), isEmpty);
      expect(platform.scheduled, isEmpty);
    });

    test('a tapped reminder names its plan', () {
      expect(
        WirdReminderTaps.planOf(const NotificationTap(id: 140001, namespace: 'wird', data: {'plan': 'p1'})),
        'p1',
      );
      expect(WirdReminderTaps.planOf(const NotificationTap(id: 110001, namespace: 'adhkar', data: {'plan': 'p1'})), isNull);
    });
  });
}
