// «ناوي» / «لأ» pressed in the notification shade with Madar dead.
//
// The answer runs in its own isolate with its own database connection and
// must write EXACTLY ONE record for the fasting day - a double tap, or both
// buttons, still leave one - and never lose the answer silently. «لأ»
// silences only that day. The meds' and the iqama's background tests are the
// pattern: a real file with two connections, as production has.
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/app/background_notifications.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/fasting/fasting.dart';
import 'package:madar/features/notification_center/notification_center.dart';

import 'fasting_test_support.dart';

class _NoApp implements FastingActionTransport {
  @override
  Future<bool> forward(NotificationTap tap) async => false;
}

class _AppAlive implements FastingActionTransport {
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
  setUpAll(() async => initializeDateFormatting());

  var now = DateTime(2026, 11, 15, 20, 5);
  late Directory dir;
  late File file;
  late MadarDatabase db;
  late Repositories repos;
  late FastingRepository repo;
  late FakeNotificationPlatform platform;
  late NotificationGate gate;
  late NotificationService notifications;

  FastingBackgroundHandler handlerWith({FastingActionTransport? transport, bool databaseExists = true}) =>
      FastingBackgroundHandler(
        transport: transport ?? _NoApp(),
        openDatabase: () async => databaseExists ? MadarDatabase(NativeDatabase(file)) : null,
        notifications: notifications,
        clock: () => now,
      );

  // A file, not memory: the handler closes the database it opened (as the
  // real isolate does), so the test keeps its own connection to the same
  // file - exactly the two connections production has.
  setUp(() {
    now = DateTime(2026, 11, 15, 20, 5);
    dir = Directory.systemTemp.createTempSync('madar_fasting_bg_');
    file = File('${dir.path}/madar.db');
    db = MadarDatabase(NativeDatabase(file));
    repos = Repositories(db);
    repo = FastingRepository(repos.keyValues);
    platform = FakeNotificationPlatform();
    gate = NotificationGate.background(clock: () => now);
    notifications = NotificationService(madarBackgroundGateSeams(gate).wrapPlatform(platform), clock: () => now);
  });

  tearDown(() async {
    await notifications.dispose();
    await db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  // The reminder of Monday 16 Nov 2026, sent the night before.
  NotificationTap tap({String action = FastingActions.yes, String day = '2026-11-16', String kind = 'monday'}) =>
      NotificationTap(
        id: 200123,
        namespace: 'fasting',
        actionId: action,
        channelId: FastingNotifications.channelId,
        data: {'day': day, 'kind': kind, 'l': 'ar', 'g': 'auto'},
      );

  group('«ناوي» with the app dead', () {
    test('writes exactly one record: the intention of that fasting day', () async {
      expect(await repo.intentions(), isEmpty);
      expect(await handlerWith().handle(tap()), FastingBackgroundOutcome.recorded);

      final rows = await repo.intentions();
      expect(rows, hasLength(1));
      expect(rows.single.day, DateTime(2026, 11, 16));
      expect(rows.single.choice, FastIntentionChoice.yes);
      // The log is untouched: «ناوي» is an intention, not a fast he has done.
      expect(await repo.log(), isEmpty);
      // Nothing was shown: a recorded answer is quiet.
      expect(platform.shown, isEmpty);
    });

    test('the same button twice is still exactly one record', () async {
      final h = handlerWith();
      expect(await h.handle(tap()), FastingBackgroundOutcome.recorded);
      final stored = await repos.keyValues.getJson(FastingRepository.intentionsKey);
      expect(await h.handle(tap()), FastingBackgroundOutcome.alreadyRecorded);
      expect(await repo.intentions(), hasLength(1));
      expect(await repos.keyValues.getJson(FastingRepository.intentionsKey), stored);
    });

    test('«ناوي» then «لأ» on the same night: one record, the last answer', () async {
      final h = handlerWith();
      await h.handle(tap());
      await h.handle(tap(action: FastingActions.no));
      final rows = await repo.intentions();
      expect(rows, hasLength(1));
      expect(rows.single.choice, FastIntentionChoice.no);
    });
  });

  group('«لأ» silences only that day', () {
    test('writes one «لأ» for that day; the next reminder is still planned', () async {
      expect(await handlerWith().handle(tap(action: FastingActions.no)), FastingBackgroundOutcome.recorded);
      final rows = await repo.intentions();
      expect(rows.single.choice, FastIntentionChoice.no);
      expect(rows.single.day, DateTime(2026, 11, 16));

      // The planner now leaves that day out and nothing else.
      DateTime? isha(DateTime d) => DateTime(d.year, d.month, d.day, 19, 30);
      final planNow = DateTime(2026, 11, 15, 12); // before that evening's reminder
      final plan = FastingPlanner.plan(config: cfg(0), now: planNow, ishaOf: isha, intentions: rows);
      final without = FastingPlanner.plan(config: cfg(0), now: planNow, ishaOf: isha);
      expect(without.map((p) => p.reminder.key), contains('2026-11-16.monday'));
      expect(plan.map((p) => p.reminder.key), isNot(contains('2026-11-16.monday')));
      expect(plan.length, without.length - 1);
      final thursday = plan.firstWhere((p) => p.reminder.kind == FastKind.thursday);
      expect(thursday.reminder.day.weekday, DateTime.thursday, reason: 'the week\'s other reminders still come');
    });
  });

  group('the app is alive, and everything else', () {
    test('a running app records it: the handler writes nothing itself', () async {
      final alive = _AppAlive();
      expect(await handlerWith(transport: alive).handle(tap()), FastingBackgroundOutcome.forwarded);
      expect(alive.calls, 1);
      expect(await repo.intentions(), isEmpty, reason: 'the app writes it on its own connection');
    });

    test('a tap on the body, a notice, another feature\'s notification: nothing written', () async {
      final h = handlerWith();
      expect(
        await h.handle(NotificationTap(id: 1, namespace: 'fasting', data: const {'day': '2026-11-16'})),
        FastingBackgroundOutcome.ignored,
        reason: 'the body opens the screen, it answers nothing',
      );
      expect(
        await h.handle(
          NotificationTap(
            id: FastingNotifications.runwayId,
            namespace: 'fasting',
            actionId: FastingActions.yes,
            data: const {'t': 'runway', 'day': '2026-11-16'},
          ),
        ),
        FastingBackgroundOutcome.ignored,
      );
      expect(await h.handle(NotificationTap(id: 1, namespace: 'iqama', actionId: FastingActions.yes, data: const {'day': '2026-11-16'})), FastingBackgroundOutcome.ignored);
      expect(
        await h.handle(tap(day: 'not-a-day')),
        FastingBackgroundOutcome.ignored,
        reason: 'a malformed payload is never guessed at',
      );
      expect(await repo.intentions(), isEmpty);
    });

    test('no database: the answer is not lost silently - a notice asks him to open Madar, through the gate', () async {
      final outcome = await handlerWith(databaseExists: false).handle(tap());
      expect(outcome, FastingBackgroundOutcome.failed);
      final notice = platform.shown.values.single.request;
      expect(notice.title, 'ما انحفظ جوابك');
      expect(notice.body, 'افتح مدار وجرّب مرّة ثانية.');
      expect(notice.namespace, NotificationNamespaces.fasting);
      expect(await repo.intentions(), isEmpty);
    });

    test('the notice is in the language the reminder was written in', () async {
      final english = NotificationTap(
        id: 1,
        namespace: 'fasting',
        actionId: FastingActions.no,
        data: const {'day': '2026-11-16', 'kind': 'monday', 'l': 'en', 'g': 'auto'},
      );
      await handlerWith(databaseExists: false).handle(english);
      expect(platform.shown.values.single.request.title, 'Your answer was not saved');
    });
  });

  group('the app\'s background entry point', () {
    test('the answers are routed by their namespace: fasting taps are recognised, nothing else is', () {
      expect(FastingNotificationTaps.isFasting(tap()), isTrue);
      expect(FastingNotificationTaps.answerOf(tap())?.choice, FastIntentionChoice.yes);
      expect(FastingNotificationTaps.answerOf(tap(action: FastingActions.no))?.choice, FastIntentionChoice.no);
      expect(FastingNotificationTaps.answerOf(tap(action: 'iqama.prayed')), isNull);
      expect(FastingActions.yes, isNot(FastingActions.no));
    });
  });
}
