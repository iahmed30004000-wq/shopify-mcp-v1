// «رمضان» wired into the app: the scheduler is watched at the root right after
// the notification centre (one gate, the owner's mutes already in it), a Prayer
// (Faith) mute holds the reminders and an un-mute re-arms them, a restore
// re-plans from the restored data, the Hijri shift in the prayer settings moves
// every alarm, the day changing re-plans, a Ramadan that began while the app
// was closed is noticed, a tap on the body opens «رمضان», and «صلّيت» answered
// while Madar runs writes the same single entry the background isolate would.
// The fasting wiring test is the pattern.
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderBase;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_services.dart';
import 'package:madar/app/system_services.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/db/snapshot.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/features/data/data.dart' show RestoreResult, SafetyCopy;
import 'package:madar/features/notification_center/notification_center.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/prayer/application/prayer_settings_controller.dart' show prayerSettingsControllerProvider;
import 'package:madar/features/ramadan/ramadan.dart';

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';
import '../orbit/presentation/orbit_scene_fixtures.dart';

Future<void> _asyncFrames(WidgetTester tester, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Records the order providers are first created in.
final class _StartOrder extends ProviderObserver {
  _StartOrder(this.watched);

  final Map<ProviderBase<Object?>, String> watched;
  final List<String> started = [];

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    final name = watched[context.provider];
    if (name != null && !started.contains(name)) started.add(name);
  }
}

Iterable<FakeScheduled> _alarms(FakeNotificationPlatform platform) => platform.scheduled.values.where(
  (s) => NotificationNamespaces.ramadan.contains(s.request.id) && s.request.id != RamadanNotifications.runwayId,
);

Set<int> _ids(FakeNotificationPlatform platform) => {for (final s in _alarms(platform)) s.request.id};

/// 19 days before the first day of Ramadan 1448 (8 February 2027): the alarms are armed.
final _beforeRamadan = DateTime(2027, 1, 20, 12);

Future<void> _amman(MadarDatabase db, {int offset = 0}) =>
    OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings().copyWith(hijriOffsetDays: offset));

RawNotificationTap _tap({String? action, String type = 'taraweeh', int night = 5, int year = 1448}) {
  const id = 210105;
  return RawNotificationTap(
    id: id,
    actionId: action,
    payload: NotificationEnvelope.encode(
      NotificationRequest(
        namespace: NotificationNamespaces.ramadan,
        id: id,
        channelId: RamadanNotifications.channelId,
        title: 'رمضان · التراويح',
        body: 'ليلة $night',
        at: DateTime(2027, 2, 11, 19, 15),
        data: {'t': type, 'n': night, 'y': year, 'l': 'ar', 'g': 'auto'},
      ),
    ),
  );
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('the notification centre sees «رمضان»', () {
    testWidgets('the app starts with the scheduler watched at the root, after the centre, and the month\'s alarms are armed', (tester) async {
      final order = _StartOrder({
        notificationCenterProvider: 'centre',
        ramadanRegistrationProvider: 'registration',
        ramadanSyncProvider: 'sync',
        ramadanBridgeProvider: 'bridge',
      });
      final platform = FakeNotificationPlatform();
      final app = await pumpMadarApp(
        tester,
        settle: false,
        now: _beforeRamadan,
        observers: [order],
        notifications: platform,
        beforePump: _amman,
        overrides: LockFixture.empty().overrides,
      );
      await _asyncFrames(tester, 20);

      expect(order.started, containsAll(['centre', 'registration', 'sync', 'bridge']));
      expect(order.started.indexOf('centre'), 0, reason: 'the mutes are in the gate before anything re-plans');
      expect(order.started.indexOf('registration'), lessThan(order.started.indexOf('sync')), reason: order.started.join(','));

      expect(_ids(platform), isNotEmpty, reason: 'the app planned Ramadan on its own');
      for (final s in _alarms(platform)) {
        expect(s.request.namespace, NotificationNamespaces.ramadan);
      }
      expect(platform.channels.containsKey(RamadanNotifications.channelId), isTrue);
      final result = app.container.read(ramadanSyncProvider).last;
      expect(result?.plan.span.first, DateTime(2027, 2, 8));
      expect(result!.plan.reminders, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a restore (and an un-mute) re-plans: the namespace has its hook', (tester) async {
      final app = await pumpMadarApp(tester, overrides: LockFixture.empty().overrides);
      final hooks = app.container.read(systemReplanHooksProvider);
      expect(hooks.namespaces, contains(NotificationNamespaces.ramadan.name));
      await expectLater(hooks[NotificationNamespaces.ramadan.name]!(), completes);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('they belong to Prayer: one Faith mute holds them with the adhan, and un-muting re-arms them', (tester) async {
      final platform = FakeNotificationPlatform();
      final app = await pumpMadarApp(
        tester,
        gated: true,
        settle: false,
        now: _beforeRamadan,
        notifications: platform,
        overrides: LockFixture.empty().overrides,
        beforePump: (MadarDatabase db) async {
          await _amman(db);
          // Muted well past the whole month.
          await NotificationCenterStore(Repositories(db).keyValues).savePolicy(
            CenterPolicy.empty.mute(NotificationGroup.prayer, _beforeRamadan.add(const Duration(days: 90))),
          );
        },
      );
      await _asyncFrames(tester, 20);

      final registry = app.container.read(notificationDescribersProvider);
      final notice = CenterNotice(
        id: 210150,
        namespace: NotificationNamespaces.ramadan.name,
        at: DateTime(2027, 2, 12, 17, 5).toUtc(),
        data: const {'t': 'iftar', 'n': 5, 'y': 1448},
      );
      expect(registry.groupOf(notice), NotificationGroup.prayer);
      final gate = app.container.read(notificationGateProvider);
      expect(gate.withholds(notice), isTrue, reason: 'Prayer is muted');
      expect(
        gate.withholds(CenterNotice(id: 110500, namespace: 'adhkar', at: notice.at, data: const {'set': 'morning'})),
        isFalse,
        reason: 'only the muted group is held',
      );
      // The sync ran (it planned) but not one reminder reached the plugin.
      expect(app.container.read(ramadanSyncProvider).last?.plan.reminders, isNotEmpty);
      expect(_alarms(platform), isEmpty, reason: 'held back by the gate');

      // Un-mute: what the gate held is armed.
      await tester.runAsync(() => gate.setPolicy(CenterPolicy.empty));
      await _asyncFrames(tester, 12);
      expect(_alarms(platform), isNotEmpty, reason: 'un-muting brings the reminders back');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('it re-plans by itself', () {
    testWidgets('when the Hijri day shift changes in the prayer settings: every alarm moves, the old ones are cancelled', (tester) async {
      final platform = FakeNotificationPlatform();
      final app = await pumpMadarApp(
        tester,
        now: _beforeRamadan,
        settle: false,
        notifications: platform,
        beforePump: _amman,
        overrides: LockFixture.empty().overrides,
      );
      await _asyncFrames(tester, 20);
      DateTime? firstIftar() => platform.scheduled[210051]?.request.at;
      final before = firstIftar()!;
      expect((before.month, before.day), (2, 8));

      await tester.runAsync(() => app.container.read(prayerSettingsControllerProvider.notifier).setHijriOffset(1));
      await _asyncFrames(tester, 20);
      expect(firstIftar()!.day, 7, reason: 'one setting: the prayer settings\' shift moved the alarm');
      expect(app.container.read(ramadanCalendarProvider).offsetDays, 1);

      await tester.runAsync(() => app.container.read(prayerSettingsControllerProvider.notifier).setHijriOffset(-1));
      await _asyncFrames(tester, 20);
      expect(firstIftar()!.day, 9);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('when the day changes at midnight: re-planned from the new day, what is past is gone', (tester) async {
      var now = DateTime(2027, 2, 12, 23, 59);
      final platform = FakeNotificationPlatform();
      final app = await pumpMadarApp(
        tester,
        clock: () => now,
        settle: false,
        notifications: platform,
        beforePump: _amman,
        overrides: LockFixture.empty().overrides,
      );
      await _asyncFrames(tester, 20);
      final first = app.container.read(ramadanSyncProvider).last!;
      expect(first.at, DateTime(2027, 2, 12, 23, 59));
      expect(_ids(platform), isNot(contains(210005)), reason: 'the suhoor of day 5 has passed');
      expect(_ids(platform), contains(210006));

      now = DateTime(2027, 2, 13, 0, 0, 30);
      await tester.pump(const Duration(seconds: 70)); // OrbitToday's midnight timer
      await _asyncFrames(tester, 10);
      final last = app.container.read(ramadanSyncProvider).last!;
      expect(last.at.day, 13, reason: 're-planned for the new day');
      expect(last.plan.reminders.every((r) => r.at.isAfter(now)), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('a Ramadan that starts while the app is closed', () {
    testWidgets('the app was last open on 5 February and opens on 9: it says it crossed the start; the month is already on', (tester) async {
      final platform = FakeNotificationPlatform();
      final app = await pumpMadarApp(
        tester,
        now: DateTime(2027, 2, 9, 10),
        settle: false,
        notifications: platform,
        overrides: LockFixture.empty().overrides,
        beforePump: (db) async {
          await _amman(db);
          await RamadanRepository(Repositories(db).keyValues).setLastSeen(DateTime(2027, 2, 5));
        },
      );
      await _asyncFrames(tester, 20);
      final state = app.container.read(ramadanSyncProvider);
      expect(state.crossed.started, isTrue);
      expect(state.crossed.eidReached, isFalse);
      // Nothing was waiting for him to open the app: the month and the atmosphere are derived from the date.
      expect(app.container.read(ramadanStatusProvider).dayOfRamadan, 2);
      expect(app.container.read(ramadanAtmosphereProvider), isTrue);
      // The remaining alarms are armed (day 2 is today).
      expect(_ids(platform), contains(210052));
      // And the day he looked is kept for next time.
      expect(await tester.runAsync(() => RamadanRepository(app.repos.keyValues).lastSeen()), DateTime(2027, 2, 9));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('closed across the Eid: it says so, the atmosphere is gone and no Ramadan alarm is left', (tester) async {
      final platform = FakeNotificationPlatform();
      final app = await pumpMadarApp(
        tester,
        now: DateTime(2027, 3, 12, 10),
        settle: false,
        notifications: platform,
        overrides: LockFixture.empty().overrides,
        beforePump: (db) async {
          await _amman(db);
          await RamadanRepository(Repositories(db).keyValues).setLastSeen(DateTime(2027, 3, 5));
        },
      );
      await _asyncFrames(tester, 20);
      final state = app.container.read(ramadanSyncProvider);
      expect(state.crossed.eidReached, isTrue);
      expect(state.crossed.started, isFalse);
      expect(app.container.read(ramadanAtmosphereProvider), isFalse);
      expect(_alarms(platform), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a clock set back by hand crosses nothing', (tester) async {
      final app = await pumpMadarApp(
        tester,
        now: DateTime(2027, 2, 9, 10),
        settle: false,
        overrides: LockFixture.empty().overrides,
        beforePump: (db) async {
          await _amman(db);
          await RamadanRepository(Repositories(db).keyValues).setLastSeen(DateTime(2027, 3, 20));
        },
      );
      await _asyncFrames(tester, 20);
      expect(app.container.read(ramadanSyncProvider).crossed.any, isFalse, reason: 'the phone\'s clock was changed by hand');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('restore', () {
    testWidgets('after a restore the reminders are re-planned from the restored data', (tester) async {
      final platform = FakeNotificationPlatform();
      final app = await pumpMadarApp(
        tester,
        now: _beforeRamadan,
        settle: false,
        notifications: platform,
        beforePump: _amman,
        overrides: LockFixture.empty().overrides,
      );
      await _asyncFrames(tester, 20);
      expect(_ids(platform), contains(210001), reason: 'suhoor is on by default');
      final oldSuhoor = _ids(platform).where((id) => id >= 210001 && id <= 210049).toSet();
      expect(oldSuhoor, isNotEmpty);

      // The backup he restores was made with the suhoor reminder off.
      final other = testDatabase();
      addTearDown(() => tester.runAsync(other.close));
      final snapshot = await tester.runAsync(() async {
        await _amman(other);
        await RamadanRepository(Repositories(other).keyValues).saveConfig(const RamadanConfig(suhoorReminder: false));
        return exportSnapshot(other);
      });
      await tester.runAsync(() => restoreSnapshot(app.db, snapshot!));

      final safety = Directory.systemTemp.createTempSync('madar_ramadan_restore_');
      addTearDown(() => safety.deleteSync(recursive: true));
      final copy = File('${safety.path}/x.madarbackup')..writeAsStringSync('x');
      var finished = false;
      unawaited(
        app.container
            .read(afterRestoreProvider)(
              RestoreResult(safetyCopy: SafetyCopy(file: copy, createdAt: DateTime(2027, 1, 20), size: 1), restoredRecords: 3, previousRecords: 1),
            )
            .then((_) => finished = true),
      );
      await _asyncFrames(tester, 40);
      expect(finished, isTrue);

      expect(_ids(platform).where((id) => id >= 210001 && id <= 210049), isEmpty, reason: 'the restored data has no suhoor reminders');
      expect(_ids(platform), contains(210051), reason: 'the rest is still armed');
      for (final id in oldSuhoor) {
        expect(platform.scheduled.containsKey(id), isFalse, reason: 'the old data\'s alarm $id was cancelled');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('taps', () {
    test('the body of a reminder leads to «رمضان»; its button leads nowhere', () {
      NotificationTap tap({String? action, Map<String, Object?> data = const {'t': 'taraweeh', 'n': 5, 'y': 1448}}) =>
          NotificationTap(id: 210105, namespace: 'ramadan', data: data, actionId: action);
      expect(AppNotificationRouter.locationOf(tap()), AppRoutes.ramadan);
      expect(AppRoutes.ramadan, '/faith/ramadan');
      expect(AppNotificationRouter.locationOf(tap(action: RamadanActions.prayed)), isNull);
      // The "open Madar to set up the reminders" notice opens the same screen.
      expect(AppNotificationRouter.locationOf(tap(data: const {'t': 'runway'})), AppRoutes.ramadan);
      // Another feature's tap is not ours.
      expect(AppNotificationRouter.locationOf(const NotificationTap(id: 1, namespace: 'fasting', data: {'day': '2027-02-01'})), isNot(AppRoutes.ramadan));
      expect(centerLocationOf(tap()), AppRoutes.ramadan, reason: 'a row in the centre opens it too');
    });

    testWidgets('a tap on the body while Madar runs opens the screen; back returns', (tester) async {
      final app = await pumpMadarApp(tester, overrides: LockFixture.empty().overrides);
      app.notifications.tap(_tap());
      await settleApp(tester);
      expect(app.location, AppRoutes.ramadan);
      expect(find.byType(RamadanScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(app.location, AppRoutes.home);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('«صلّيت» answered while Madar runs writes exactly one entry, and does not navigate', (tester) async {
      final app = await pumpMadarApp(tester, overrides: LockFixture.empty().overrides);
      await tester.runAsync(() => app.container.read(notificationServiceProvider).init());
      app.notifications.tap(_tap(action: RamadanActions.prayed));
      app.notifications.tap(_tap(action: RamadanActions.prayed)); // a double tap
      await _asyncFrames(tester, 8);
      final book = await tester.runAsync(() => RamadanRepository(app.repos.keyValues).logBook());
      final entries = book!.of(1448)!.taraweeh.entries;
      expect(entries, hasLength(1));
      expect(entries[5]!.done, isTrue);
      expect(app.location, AppRoutes.home, reason: 'the button never opens the app');
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
