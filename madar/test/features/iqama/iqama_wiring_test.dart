// «الإقامة» wired into the app: the notification centre sees it as Prayer
// (so one Faith mute covers the adhan and the iqama together), a restore
// re-plans it, its two buttons are answerable from a centre row, and a
// tap that reaches the running app writes the same single row the
// background isolate would.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/system_services.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/features/adhan/application/adhan_providers.dart' show adhanSystemProvider;
import 'package:madar/features/adhan/data/adhan_system.dart';
import 'package:madar/features/home/home_providers.dart' show homeClockProvider;
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/iqama/iqama.dart';
import 'package:madar/features/notification_center/notification_center.dart';
import 'package:madar/features/prayer_tracker/prayer_tracker.dart';

import '../../helpers/test_app.dart';

CenterNotice _notice({bool snooze = false}) => CenterNotice(
  id: snooze ? IqamaIds.snooze : IqamaIds.of(DateTime.utc(2026, 9, 28), AdhanSlot.asr),
  namespace: 'iqama',
  at: DateTime(2026, 9, 28, 16, 5).toUtc(),
  title: 'قامت الصلاة',
  data: {
    's': 'asr',
    'day': '2026-09-28',
    'p': DateTime(2026, 9, 28, 15, 50).millisecondsSinceEpoch,
    'n': DateTime(2026, 9, 28, 18, 30).millisecondsSinceEpoch,
    'z': 5,
    if (snooze) 'sn': 1,
    'l': 'ar',
  },
);

void main() {
  group('the notification centre', () {
    final registry = NotificationDescriberRegistry(builtInDescribers());
    final texts = CenterTexts.forLanguage('ar');

    test('an iqama belongs to Prayer, so one Faith mute covers it with the adhan', () {
      expect(registry.groupOf(_notice()), NotificationGroup.prayer);
      final d = registry.describe(_notice(), texts);
      expect(d.group, NotificationGroup.prayer);
      expect(d.title, 'قامت الصلاة');
      expect(d.kind, 'إقامة العصر');
      expect(d.snoozable, isFalse, reason: 'it has its own one snooze');
      expect(d.subject, 'prayer:asr');
    });

    test('a row offers «صلّيت» and «بعد شوي» – and the snooze only before it has been taken', () {
      expect(registry.describe(_notice(), texts).actions.map((a) => a.id), [
        IqamaActions.prayed,
        IqamaActions.later,
      ]);
      expect(registry.describe(_notice(snooze: true), texts).actions.map((a) => a.id), [IqamaActions.prayed]);
    });

    test('both buttons have a handler, so a centre row answers them like the shade does', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final handlers = container.read(notificationActionHandlersProvider);
      expect(handlers.handles(IqamaActions.prayed), isTrue);
      expect(handlers.handles(IqamaActions.later), isTrue);
    });

    test('a restore (and an un-mute) re-plans the iqamas: the namespace has its hook', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final hooks = container.read(systemReplanHooksProvider);
      expect(hooks.namespaces, contains(NotificationNamespaces.iqama.name));
      expect(hooks[NotificationNamespaces.iqama.name], isNotNull);
    });

    test('a hook asked before anything runs never starts a sync and never throws', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final hooks = container.read(systemReplanHooksProvider);
      await expectLater(hooks[NotificationNamespaces.iqama.name]!(), completes);
    });
  });

  group('answered while Madar runs', () {
    // A provider container, not a widget tree: the bridge is exactly what
    // the app shell watches, over an in-memory database and the fake
    // plugin.
    late MadarDatabase db;
    late Repositories repos;
    late FakeNotificationPlatform platform;
    late ProviderContainer container;
    var now = DateTime(2026, 9, 28, 16, 12);

    setUp(() {
      now = DateTime(2026, 9, 28, 16, 12);
      db = testDatabase();
      repos = Repositories(db);
      platform = FakeNotificationPlatform();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          homeClockProvider.overrideWithValue(() => now),
          notificationPlatformProvider.overrideWithValue(platform),
          notificationServiceProvider.overrideWithValue(NotificationService(platform, clock: () => now)),
          adhanSystemProvider.overrideWithValue(FakeAdhanSystem()),
          iqamaTextsProvider.overrideWithValue(IqamaTexts.forLanguage('ar')),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('«صلّيت» forwarded to the app writes exactly one row, and no second one', () async {
      final bridge = container.read(iqamaBridgeProvider);
      expect(await bridge.handle(_notice().toTap(actionId: IqamaActions.prayed)), isTrue);

      var rows = await repos.prayerLogs.getAll();
      expect(rows, hasLength(1));
      expect(rows.single.prayer, Prayer.asr);
      expect(rows.single.status, PrayerStatus.prayed);
      // The Faith world's completion, exactly as the tracker's own button
      // writes it.
      final activity = await repos.activityLog.getAll();
      expect(activity.where((a) => a.refTable == PrayerTrackerRepository.table), hasLength(1));

      // The same answer again: told, never written twice.
      now = now.add(const Duration(minutes: 2));
      expect(await bridge.handle(_notice().toTap(actionId: IqamaActions.prayed)), isTrue);
      rows = await repos.prayerLogs.getAll();
      expect(rows, hasLength(1));
      expect(rows.single.loggedAt, DateTime(2026, 9, 28, 16, 12), reason: 'the first answer stands');
      expect(platform.shown.values.map((s) => s.request.title), contains('العصر مسجّلة من قبل'));
    });

    test('a prayer logged by hand first is never written over from the shade', () async {
      await PrayerTrackerRepository(repos, clock: () => now).setStatus(DateTime(2026, 9, 28), Prayer.asr, PrayerStatus.prayed);
      final before = (await repos.prayerLogs.getAll()).single;
      now = now.add(const Duration(minutes: 3));
      expect(await container.read(iqamaBridgeProvider).handle(_notice().toTap(actionId: IqamaActions.prayed)), isTrue);
      final after = await repos.prayerLogs.getAll();
      expect(after, hasLength(1));
      expect(after.single.loggedAt, before.loggedAt);
      expect(platform.shown.values.map((s) => s.request.title), contains('العصر مسجّلة من قبل'));
    });

    test('«بعد شوي» arms the one snooze, and the snooze itself cannot ask for another', () async {
      final bridge = container.read(iqamaBridgeProvider);
      expect(await bridge.handle(_notice().toTap(actionId: IqamaActions.later)), isTrue);
      final armed = platform.scheduled[IqamaIds.snooze];
      expect(armed, isNotNull);
      expect(armed!.request.at, now.add(const Duration(minutes: 5)));
      expect(armed.request.actions.map((a) => a.id), [IqamaActions.prayed]);
      expect(armed.request.timing, NotificationTiming.alarmClock);
      expect(await repos.prayerLogs.getAll(), isEmpty, reason: 'a snooze logs nothing');

      expect(
        await bridge.handle(_notice(snooze: true).toTap(actionId: IqamaActions.later)),
        isFalse,
        reason: 'one snooze, and no more',
      );
    });

    test('a snooze that would land after the next adhan is not armed', () async {
      now = DateTime(2026, 9, 28, 18, 28); // Maghrib at 18:30 in the payload
      expect(await container.read(iqamaBridgeProvider).handle(_notice().toTap(actionId: IqamaActions.later)), isTrue);
      expect(platform.scheduled.containsKey(IqamaIds.snooze), isFalse);
    });
  });
}
