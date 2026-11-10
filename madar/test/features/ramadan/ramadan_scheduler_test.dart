// «رمضان» delivered: the exact alarms of a known Ramadan, nothing outside it,
// nothing in the past, the Hijri shift moving every one of them, deterministic
// ids (nothing re-sent), the notifications' words in both languages, the one
// button that never opens the app, and the notice for the app that was not
// opened - against the notification platform fake.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/ramadan/ramadan.dart';

import 'ramadan_test_support.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  late FakeNotificationPlatform platform;
  late DateTime now;
  late RamadanScheduler scheduler;
  final ar = RamadanTexts.forLanguage('ar');
  final en = RamadanTexts.forLanguage('en');

  setUp(() {
    now = DateTime(2027, 1, 20, 12);
    platform = FakeNotificationPlatform();
    scheduler = RamadanScheduler(notifications: NotificationService(platform, clock: () => now), clock: () => now);
  });

  Future<RamadanSyncResult> sync({
    RamadanConfig config = const RamadanConfig(),
    int offset = 0,
    RamadanTexts? texts,
  }) => scheduler.sync(
    config: config,
    calendar: RamadanCalendar(offsetDays: offset),
    timesOf: fixedTimes,
    texts: texts ?? ar,
  );

  List<FakeScheduled> alarms() =>
      platform.scheduled.values.where((s) => s.request.data[RamadanNotificationTaps.kType] != RamadanNotificationTaps.typeRunway).toList()
        ..sort((a, b) => a.request.at.compareTo(b.request.at));

  Set<int> ids() => {for (final s in platform.scheduled.values) s.request.id};

  Set<int> expectedIds(int days) => {
    for (var n = 1; n <= days; n++) ...[suhoorId(n), iftarId(n), taraweehId(n)],
    for (var n = 21; n <= days; n++) lastTenId(n),
  };

  group('a known Ramadan', () {
    test('the pending set is exactly the ids of its 29 days, in the Ramadan block, namespace "ramadan"', () async {
      final result = await sync();
      expect(ids(), expectedIds(29));
      expect(result.ids, expectedIds(29));
      for (final s in platform.scheduled.values) {
        expect(s.request.namespace, NotificationNamespaces.ramadan);
        expect(NotificationNamespaces.owning(s.request.id), NotificationNamespaces.ramadan);
        expect(s.request.channelId, RamadanNotifications.channelId);
      }
      expect(platform.channels.containsKey(RamadanNotifications.channelId), isTrue);
      expect(platform.channels[RamadanNotifications.channelId]!.name, 'تذكيرات رمضان');
      expect(platform.groups[RamadanNotifications.groupId], 'رمضان');
    });

    test('nothing in the past and nothing outside the month', () async {
      now = DateTime(2027, 2, 20, 12); // day 13
      await sync();
      expect(alarms().every((s) => s.request.at.isAfter(now)), isTrue);
      expect(ids(), isNot(contains(suhoorId(13))));
      expect(ids(), contains(iftarId(13)));
      // After the Eid nothing of this Ramadan is left pending: only the notice for the next.
      now = DateTime(2027, 3, 9, 12);
      await sync();
      expect(alarms(), isEmpty);
      expect(ids(), {RamadanNotifications.runwayId});
    });

    test('an unchanged plan is not scheduled twice: same ids, no churn', () async {
      await sync();
      final armed = platform.scheduleLog.length;
      final before = ids();
      final again = await sync();
      expect(platform.scheduleLog.length, armed, reason: 'nothing was re-sent to the platform');
      expect(ids(), before);
      expect(again.report.scheduled, 0);
      expect(again.report.cancelled, 0);
      expect(again.report.unchanged, before.length);
    });

    test('the day moves on: what has passed is dropped, the rest stays', () async {
      await sync();
      now = DateTime(2027, 2, 12, 9); // day 5, after its suhoor
      await sync();
      expect(ids(), isNot(contains(suhoorId(5))));
      expect(ids(), contains(iftarId(5)));
      expect(ids(), isNot(contains(suhoorId(1))));
      expect(ids(), contains(suhoorId(6)));
    });

    test('after a restore the alarms are gone from the platform and one sync arms them again', () async {
      await sync();
      final before = ids();
      platform.scheduled.clear();
      await sync();
      expect(ids(), before);
    });
  });

  group('the Hijri shift moves every reminder', () {
    for (final (offset, first) in [(-1, DateTime(2027, 2, 9)), (0, DateTime(2027, 2, 8)), (1, DateTime(2027, 2, 7))]) {
      test('offset $offset: day 1\'s iftar rings on ${first.day} February at 17:05', () async {
        await sync(offset: offset);
        final iftar1 = platform.scheduled[iftarId(1)]!.request;
        expect(iftar1.at, DateTime(first.year, first.month, first.day, 17, 5));
        expect(platform.scheduled[taraweehId(1)]!.request.at, DateTime(first.year, first.month, first.day - 1, 19, 15));
      });
    }

    test('changing the offset while alarms are pending re-arms them all on the new days', () async {
      await sync(offset: 0);
      final r = await sync(offset: 1);
      expect(platform.scheduled[iftarId(1)]!.request.at, DateTime(2027, 2, 7, 17, 5));
      expect(r.report.scheduled, greaterThan(90), reason: 'every alarm moved by a day and was re-armed');
      await sync(offset: -1);
      expect(platform.scheduled[iftarId(1)]!.request.at, DateTime(2027, 2, 9, 17, 5));
      // What is pending is exactly the new plan.
      final span = const RamadanCalendar(offsetDays: -1).spanOfYear(1448);
      expect(ids(), expectedIds(span.length));
    });
  });

  group('switches', () {
    test('switching a reminder off cancels exactly its alarms and no other', () async {
      await sync();
      await sync(config: const RamadanConfig(suhoorReminder: false));
      expect(ids().where((id) => id >= 210001 && id <= 210049), isEmpty);
      expect(ids(), expectedIds(29)..removeAll({for (var n = 1; n <= 29; n++) suhoorId(n)}));
      await sync(config: const RamadanConfig(taraweehReminder: false, lastTenReminder: false));
      expect(ids().where((id) => id >= 210100 && id <= 210299), isEmpty);
      expect(ids(), contains(iftarId(1)));
    });

    test('a changed lead time re-arms with the new moment', () async {
      await sync();
      await sync(config: const RamadanConfig(iftarLeadMinutes: 30));
      expect(platform.scheduled[iftarId(3)]!.request.at, DateTime(2027, 2, 10, 16, 50));
      await sync(config: const RamadanConfig(iftarLeadMinutes: 30, suhoorLeadMinutes: 60));
      expect(platform.scheduled[suhoorId(3)]!.request.at, DateTime(2027, 2, 10, 4, 30));
    });

    test('everything off: nothing pending, not even a notice, once Ramadan is near', () async {
      await sync();
      await sync(config: const RamadanConfig(suhoorReminder: false, iftarReminder: false, taraweehReminder: false, lastTenReminder: false));
      expect(platform.scheduled, isEmpty);
    });
  });

  group('the notifications', () {
    test('Arabic: plain wording with the time, the Taraweeh one carries «صلّيت» that never opens the app', () async {
      await sync();
      final iftar = platform.scheduled[iftarId(5)]!.request;
      expect(iftar.title, 'رمضان · الإفطار');
      expect(iftar.body, startsWith('بعد '));
      expect(iftar.body, contains('بيأذّن المغرب'));
      expect(iftar.body, contains(ar.fmt.formatTime(DateTime(2027, 2, 12, 17, 20))));
      expect(iftar.actions, isEmpty);
      final suhoor = platform.scheduled[suhoorId(5)]!.request;
      expect(suhoor.title, 'رمضان · السحور');
      expect(suhoor.body, contains('بيأذّن الفجر'));
      final taraweeh = platform.scheduled[taraweehId(5)]!.request;
      expect(taraweeh.title, 'رمضان · التراويح');
      expect(taraweeh.body, startsWith('ليلة '));
      expect(taraweeh.body, contains('صلّيت'));
      expect(taraweeh.actions.map((a) => a.id), [RamadanActions.prayed]);
      expect(taraweeh.actions.single.title, 'صلّيت');
      expect(taraweeh.actions.single.opensApp, isFalse, reason: 'answering never opens the app or meets the lock');
      expect(taraweeh.actions.single.cancels, isTrue);
      expect(taraweeh.dropIfLateBy, RamadanNotifications.dropIfLateBy);
      // No ruling is claimed anywhere.
      for (final s in platform.scheduled.values) {
        expect('${s.request.title} ${s.request.body}', isNot(anyOf(contains('واجب'), contains('فرض'), contains('حرام'))));
      }
    });

    test('English: the same, with the minutes and the time', () async {
      await sync(texts: en);
      final iftar = platform.scheduled[iftarId(5)]!.request;
      expect(iftar.title, 'Ramadan · Iftar');
      expect(iftar.body, startsWith('In 15 minutes the Maghrib adhan is at 5:20'));
      final suhoor = platform.scheduled[suhoorId(5)]!.request;
      expect(suhoor.body, startsWith('In 45 minutes the Fajr adhan is at 5:30'));
      final taraweeh = platform.scheduled[taraweehId(5)]!.request;
      expect(taraweeh.actions.single.title, 'I prayed');
      expect(taraweeh.data[RamadanNotificationTaps.kLanguage], 'en');
    });

    test('the last ten nights: one more notice per night, "an odd night" on 21, 23, 25, 27 and 29 only', () async {
      await sync(texts: en);
      for (final n in [21, 22, 23, 24, 25, 26, 27, 28, 29]) {
        final r = platform.scheduled[lastTenId(n)]!.request;
        expect(r.title, 'Last ten nights · night $n');
        expect(r.body.contains('an odd night'), n.isOdd, reason: 'night $n');
      }
      expect(platform.scheduled.containsKey(lastTenId(20)), isFalse);
    });

    test('the payload carries the kind, the night, the year and the language - what the button needs', () async {
      await sync();
      final s = platform.scheduled[taraweehId(12)]!;
      final tap = NotificationEnvelope.decode(s.payload, id: s.request.id, actionId: RamadanActions.prayed);
      final answer = RamadanNotificationTaps.prayedOf(tap)!;
      expect((answer.hijriYear, answer.night, answer.language), (1448, 12, 'ar'));
      final body = NotificationEnvelope.decode(s.payload, id: s.request.id);
      expect(RamadanNotificationTaps.opensRamadan(body), isTrue);
      expect(RamadanNotificationTaps.prayedOf(body), isNull, reason: 'a tap on the body marks nothing');
      // Another reminder's button, or a foreign notification, marks nothing.
      final iftar = platform.scheduled[iftarId(5)]!;
      expect(RamadanNotificationTaps.prayedOf(NotificationEnvelope.decode(iftar.payload, id: iftar.request.id, actionId: RamadanActions.prayed)), isNull);
      expect(RamadanNotificationTaps.prayedOf(const NotificationTap(id: 1, namespace: 'fasting', data: {}, actionId: RamadanActions.prayed)), isNull);
    });
  });

  group('the notice for the app that was not opened', () {
    test('far from Ramadan: no alarm, one notice 40 days before the first day, that opens the Ramadan screen', () async {
      now = DateTime(2026, 11, 10, 9);
      final r = await sync();
      expect(alarms(), isEmpty);
      final runway = platform.scheduled[RamadanNotifications.runwayId]!;
      expect(runway.request.at, DateTime(2026, 12, 30, 10));
      expect(runway.request.data[RamadanNotificationTaps.kType], RamadanNotificationTaps.typeRunway);
      expect(RamadanNotificationTaps.opensRamadan(NotificationEnvelope.decode(runway.payload)), isTrue);
      expect(r.ids, {RamadanNotifications.runwayId});
    });

    test('once Ramadan is near, the alarms replace the notice', () async {
      now = DateTime(2026, 11, 10, 9);
      await sync();
      now = DateTime(2026, 12, 28, 9);
      await sync();
      expect(platform.scheduled.containsKey(RamadanNotifications.runwayId), isFalse);
      expect(ids(), expectedIds(29));
    });
  });

  group('the ids and the gate', () {
    test('the block 210000-210999 is the namespace the app knows, and no other block reaches into it', () {
      expect(NotificationNamespaces.ramadan.first, 210000);
      expect(NotificationNamespaces.ramadan.last, 210999);
      expect(NotificationNamespaces.all, contains(NotificationNamespaces.ramadan));
      for (final other in NotificationNamespaces.all) {
        if (other == NotificationNamespaces.ramadan) continue;
        expect(other.last < 210000 || other.first > 210999, isTrue, reason: other.name);
      }
      expect(NotificationNamespaces.byName('ramadan'), NotificationNamespaces.ramadan);
      expect(NotificationNamespaces.owning(210123), NotificationNamespaces.ramadan);
      expect(RamadanNotifications.runwayId, 210999);
      expect(RamadanNotifications.failedId, 210998);
    });

    test('a Ramadan sync never touches another feature\'s alarms', () async {
      final other = NotificationService(platform, clock: () => now);
      await other.sync(NotificationNamespaces.fasting, [
        NotificationRequest(
          namespace: NotificationNamespaces.fasting,
          id: 200123,
          channelId: 'x',
          title: 't',
          body: 'b',
          at: DateTime(2027, 2, 1, 20),
        ),
      ]);
      await sync();
      expect(platform.scheduled.containsKey(200123), isTrue);
      await sync(config: const RamadanConfig(suhoorReminder: false, iftarReminder: false, taraweehReminder: false, lastTenReminder: false));
      expect(platform.scheduled.containsKey(200123), isTrue);
    });
  });
}
