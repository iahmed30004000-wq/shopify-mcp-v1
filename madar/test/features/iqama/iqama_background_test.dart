// «صلّيت» pressed in the notification shade with Madar dead.
//
// Safety-critical, and the whole point of «الإقامة»: the answer runs in
// its own isolate with its own database connection and must write
// EXACTLY ONE `prayer_logs` row – the same row the tracker's own button
// writes – never a second one over a prayer he already logged by hand,
// and never none at all without telling him. «بعد شوي» is armed once and
// no more, and it passes the gate, so a Prayer mute is never re-armed
// around. The medication tracker's background test is the pattern.
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/app/background_notifications.dart';
import 'package:madar/features/iqama/iqama.dart';
import 'package:madar/features/notification_center/notification_center.dart';
import 'package:madar/features/prayer_tracker/prayer_tracker.dart';

class _NoApp implements IqamaActionTransport {
  @override
  Future<bool> forward(NotificationTap tap) async => false;
}

class _AppAlive implements IqamaActionTransport {
  var calls = 0;

  @override
  Future<bool> forward(NotificationTap tap) async {
    calls++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // Asr on 28 Sep 2026: adhan 15:50, iqama 16:05, Maghrib 18:30.
  final prayerAt = DateTime(2026, 9, 28, 15, 50);
  final nextAdhanAt = DateTime(2026, 9, 28, 18, 30);
  final day = DateTime.utc(2026, 9, 28);
  var now = DateTime(2026, 9, 28, 16, 6);

  late Directory dir;
  late File file;
  late MadarDatabase db;
  late Repositories repos;
  late PrayerTrackerRepository tracker;
  late FakeNotificationPlatform platform;
  late NotificationGate gate;
  late NotificationService notifications;
  late IqamaBackgroundHandler handler;

  // A file, not memory: the handler closes the database it opened (as the
  // real isolate does), so the test keeps its own connection to the same
  // file – exactly the two connections production has.
  setUp(() {
    now = DateTime(2026, 9, 28, 16, 6);
    dir = Directory.systemTemp.createTempSync('madar_iqama_bg_');
    file = File('${dir.path}/madar.db');
    db = MadarDatabase(NativeDatabase(file));
    repos = Repositories(db);
    tracker = PrayerTrackerRepository(repos, clock: () => now);
    platform = FakeNotificationPlatform();
    gate = NotificationGate.background(clock: () => now);
    final seams = madarBackgroundGateSeams(gate);
    notifications = NotificationService(seams.wrapPlatform(platform), clock: () => now);
    handler = IqamaBackgroundHandler(
      transport: _NoApp(),
      openDatabase: () async => MadarDatabase(NativeDatabase(file)),
      notifications: notifications,
      beforeSnooze: () => seams.beforeReplan(repos.keyValues),
      clock: () => now,
    );
  });

  tearDown(() async {
    await notifications.dispose();
    await db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  NotificationTap tap({
    String action = IqamaActions.prayed,
    AdhanSlot slot = AdhanSlot.asr,
    bool snooze = false,
    DateTime? next,
    int snoozeMinutes = 5,
  }) => NotificationTap(
    id: snooze ? IqamaIds.snooze : IqamaIds.of(day, slot),
    namespace: 'iqama',
    actionId: action,
    channelId: 'madar.iqama.call.tone-chime.v.1',
    data: {
      's': slot.name,
      'day': '2026-09-28',
      'p': prayerAt.toUtc().millisecondsSinceEpoch,
      'n': (next ?? nextAdhanAt).toUtc().millisecondsSinceEpoch,
      'z': snoozeMinutes,
      if (snooze) 'sn': 1,
      'l': 'ar',
      'g': 'auto',
    },
  );

  Future<List<PrayerLogRow>> logs() => repos.prayerLogs.getAll();

  Future<void> mutePrayer(DateTime until) =>
      NotificationCenterStore(repos.keyValues).savePolicy(CenterPolicy.empty.mute(NotificationGroup.prayer, until));

  group('«صلّيت» with the app dead', () {
    test('writes exactly one row – the row the tracker\'s own button writes', () async {
      expect(await logs(), isEmpty);
      expect(await handler.handle(tap()), IqamaBackgroundOutcome.logged);

      final rows = await logs();
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.prayer, Prayer.asr);
      expect(row.status, PrayerStatus.prayed);
      expect(row.day, '2026-09-28');
      expect(row.loggedAt, now);
      // …and the Faith completion the tracker writes with it.
      final activity = await repos.activityLog.getAll();
      expect(activity.where((a) => a.refTable == PrayerTrackerRepository.table), hasLength(1));
      expect(activity.single.kind, PrayerTrackerRepository.obligatoryKind);
      // Nothing was shown: a recorded answer is quiet.
      expect(platform.shown, isEmpty);
    });

    test('the same button twice is still exactly one row, and the second says so', () async {
      expect(await handler.handle(tap()), IqamaBackgroundOutcome.logged);
      now = now.add(const Duration(minutes: 2));
      expect(await handler.handle(tap()), IqamaBackgroundOutcome.alreadyLogged);

      expect(await logs(), hasLength(1));
      expect((await logs()).single.loggedAt, DateTime(2026, 9, 28, 16, 6), reason: 'the first answer stands');
      final notice = platform.shown.values.single.request;
      expect(notice.title, 'العصر مسجّلة من قبل');
      expect(notice.id, IqamaIds.already(AdhanSlot.asr));
    });

    test('already logged by hand before the iqama arrives: no second row, and it says so', () async {
      // He logged Asr himself at 16:00, before the iqama called.
      now = DateTime(2026, 9, 28, 16, 0);
      await tracker.setStatus(DateTime(2026, 9, 28), Prayer.asr, PrayerStatus.prayed);
      final before = (await logs()).single;
      now = DateTime(2026, 9, 28, 16, 6);

      expect(await handler.handle(tap()), IqamaBackgroundOutcome.alreadyLogged);

      final after = await logs();
      expect(after, hasLength(1), reason: 'no second row');
      expect(after.single.id, before.id);
      expect(after.single.loggedAt, before.loggedAt, reason: 'his own log was not even re-stamped');
      final notice = platform.shown.values.single.request;
      expect(notice.title, 'العصر مسجّلة من قبل');
      expect(notice.body, 'ما انسجّلت مرّتين؛ كنت سجّلتها بإيدك');
    });

    test('a prayer he marked missed is logged as prayed – still one row', () async {
      await tracker.setStatus(DateTime(2026, 9, 28), Prayer.asr, PrayerStatus.missed);
      expect(await handler.handle(tap()), IqamaBackgroundOutcome.logged);
      final rows = await logs();
      expect(rows, hasLength(1));
      expect(rows.single.status, PrayerStatus.prayed);
    });

    test('two prayers answered the same evening are two rows, one each', () async {
      expect(await handler.handle(tap()), IqamaBackgroundOutcome.logged);
      now = DateTime(2026, 9, 28, 18, 45);
      expect(await handler.handle(tap(slot: AdhanSlot.maghrib)), IqamaBackgroundOutcome.logged);
      final rows = await logs();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.prayer), unorderedEquals([Prayer.asr, Prayer.maghrib]));
    });

    test('the answer is never lost silently: no database, and he is asked to open Madar', () async {
      final failing = IqamaBackgroundHandler(
        transport: _NoApp(),
        openDatabase: () async => null,
        notifications: notifications,
        clock: () => now,
      );
      expect(await failing.handle(tap()), IqamaBackgroundOutcome.failed);
      final notice = platform.shown.values.single.request;
      expect(notice.title, 'ما انسجّلت الصلاة');
      expect(notice.id, IqamaIds.failed(AdhanSlot.asr));
    });

    test('with Madar running the answer goes to the app, and the isolate writes nothing', () async {
      final alive = _AppAlive();
      final forwarding = IqamaBackgroundHandler(
        transport: alive,
        openDatabase: () async => throw StateError('the background must not open the database'),
        notifications: notifications,
        clock: () => now,
      );
      expect(await forwarding.handle(tap()), IqamaBackgroundOutcome.forwarded);
      expect(alive.calls, 1);
      expect(await logs(), isEmpty);
    });

    test('a foreign notification, a body tap and a notice are left alone', () async {
      expect(await handler.handle(tap(action: 'meds.taken')), IqamaBackgroundOutcome.ignored);
      expect(
        await handler.handle(NotificationTap(id: 120001, namespace: 'meds', actionId: 'meds.taken', data: const {})),
        IqamaBackgroundOutcome.ignored,
      );
      expect(await logs(), isEmpty);
    });
  });

  group('«بعد شوي»', () {
    test('arms one snooze on the iqama\'s own one-off id, with «صلّيت» still on it', () async {
      expect(await handler.handle(tap(action: IqamaActions.later)), IqamaBackgroundOutcome.snoozed);
      final armed = platform.scheduled[IqamaIds.snooze]!;
      expect(armed.request.at, now.add(const Duration(minutes: 5)));
      expect(armed.request.title, 'لسّا الصلاة قائمة');
      expect(armed.request.actions.map((a) => a.id), [IqamaActions.prayed]);
      expect(armed.request.timing, NotificationTiming.alarmClock);
      expect(await logs(), isEmpty, reason: 'a snooze logs nothing');
    });

    test('it fires once and no more: «بعد شوي» on the snooze itself is refused', () async {
      expect(await handler.handle(tap(action: IqamaActions.later)), IqamaBackgroundOutcome.snoozed);
      final armedAt = platform.scheduled[IqamaIds.snooze]!.request.at;
      now = now.add(const Duration(minutes: 5));
      // The snoozed notification carries no «بعد شوي» at all; even if one
      // arrived, it is refused.
      expect(
        await handler.handle(tap(action: IqamaActions.later, snooze: true)),
        IqamaBackgroundOutcome.snoozeRefused,
      );
      expect(platform.scheduled[IqamaIds.snooze]!.request.at, armedAt, reason: 'nothing was re-armed');
    });

    test('«صلّيت» on the snooze still logs the prayer – one row', () async {
      await handler.handle(tap(action: IqamaActions.later));
      now = now.add(const Duration(minutes: 5));
      expect(await handler.handle(tap(snooze: true)), IqamaBackgroundOutcome.logged);
      expect(await logs(), hasLength(1));
    });

    test('a snooze that would land after the next adhan is refused, not moved', () async {
      now = DateTime(2026, 9, 28, 18, 27); // three minutes before Maghrib
      expect(
        await handler.handle(tap(action: IqamaActions.later)),
        IqamaBackgroundOutcome.snoozeRefused,
      );
      expect(platform.scheduled.containsKey(IqamaIds.snooze), isFalse);
    });

    test('it needs no database at all: the answer stands even when the file cannot be opened', () async {
      final noDb = IqamaBackgroundHandler(
        transport: _NoApp(),
        openDatabase: () async => null,
        notifications: notifications,
        clock: () => now,
      );
      expect(await noDb.handle(tap(action: IqamaActions.later)), IqamaBackgroundOutcome.snoozed);
      expect(platform.scheduled.containsKey(IqamaIds.snooze), isTrue);
    });
  });

  group('the notification gate', () {
    test('a Prayer mute holds the snooze the background would arm', () async {
      await mutePrayer(DateTime(2026, 9, 28, 20));
      expect(await handler.handle(tap(action: IqamaActions.later)), IqamaBackgroundOutcome.snoozed);
      expect(gate.policyLoaded, isTrue, reason: 'the stored policy was loaded before anything was armed');
      expect(
        platform.scheduled.containsKey(IqamaIds.snooze),
        isFalse,
        reason: 'a snooze inside a Prayer mute reached the system',
      );
    });

    test('the gate holds a planned iqama of a muted Faith namespace', () async {
      await mutePrayer(DateTime(2026, 9, 28, 20));
      final seams = madarBackgroundGateSeams(gate);
      await seams.beforeReplan(repos.keyValues);
      final request = IqamaNotifications.request(
        IqamaAlarm(
          id: IqamaIds.of(day, AdhanSlot.maghrib),
          slot: AdhanSlot.maghrib,
          at: DateTime(2026, 9, 28, 18, 45),
          prayerAt: DateTime(2026, 9, 28, 18, 30),
          day: day,
          minutes: 15,
        ),
        settings: const IqamaSettings(),
        texts: IqamaTexts.forLanguage('ar'),
        channelId: 'madar.iqama.call.tone-chime.v.1',
      );
      expect(gate.withholds(CenterNotice.fromRequest(request)), isTrue, reason: 'Prayer covers «الإقامة»');
      await notifications.schedule(request);
      expect(platform.scheduled.containsKey(request.id), isFalse);
    });

    test('the mute never costs him the prayer log, nor the "already logged" notice', () async {
      await mutePrayer(DateTime(2026, 9, 28, 20));
      expect(await handler.handle(tap()), IqamaBackgroundOutcome.logged);
      expect((await logs()).single.status, PrayerStatus.prayed);
      now = now.add(const Duration(minutes: 1));
      expect(await handler.handle(tap()), IqamaBackgroundOutcome.alreadyLogged);
      expect(platform.shown, isNotEmpty, reason: 'the notice must reach him whatever is muted');
    });
  });
}
