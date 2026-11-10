// «صلّيت» pressed on the Taraweeh reminder in the notification shade with
// Madar dead.
//
// The answer runs in its own isolate with its own database connection and must
// write EXACTLY ONE entry for the night - a double tap still leaves one, a
// night he had already logged with a rakaat count keeps it - and never lose the
// answer silently. A real file with two connections, as production has (the
// fasting, iqama and meds background tests are the pattern).
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/app/background_notifications.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/notification_center/notification_center.dart';
import 'package:madar/features/ramadan/ramadan.dart';

class _NoApp implements RamadanActionTransport {
  @override
  Future<bool> forward(NotificationTap tap) async => false;
}

class _AppAlive implements RamadanActionTransport {
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

  var now = DateTime(2027, 2, 14, 19, 20);
  late Directory dir;
  late File file;
  late MadarDatabase db;
  late Repositories repos;
  late RamadanRepository repo;
  late FakeNotificationPlatform platform;
  late NotificationGate gate;
  late NotificationService notifications;

  RamadanBackgroundHandler handlerWith({RamadanActionTransport? transport, bool databaseExists = true}) =>
      RamadanBackgroundHandler(
        transport: transport ?? _NoApp(),
        openDatabase: () async => databaseExists ? MadarDatabase(NativeDatabase(file)) : null,
        notifications: notifications,
        clock: () => now,
      );

  // A file, not memory: the handler closes the database it opened (as the real
  // isolate does), so the test keeps its own connection to the same file -
  // exactly the two connections production has.
  setUp(() {
    now = DateTime(2027, 2, 14, 19, 20);
    dir = Directory.systemTemp.createTempSync('madar_ramadan_bg_');
    file = File('${dir.path}/madar.db');
    db = MadarDatabase(NativeDatabase(file));
    repos = Repositories(db);
    repo = RamadanRepository(repos.keyValues);
    platform = FakeNotificationPlatform();
    gate = NotificationGate.background(clock: () => now);
    notifications = NotificationService(madarBackgroundGateSeams(gate).wrapPlatform(platform), clock: () => now);
  });

  tearDown(() async {
    await notifications.dispose();
    await db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  // The Taraweeh reminder of night 7 of Ramadan 1448 (14 February 2027).
  NotificationTap tap({
    String? action = RamadanActions.prayed,
    int night = 7,
    Object? year = 1448,
    String type = RamadanNotificationTaps.typeTaraweeh,
    String lang = 'ar',
  }) => NotificationTap(
    id: 210107,
    namespace: 'ramadan',
    actionId: action,
    channelId: RamadanNotifications.channelId,
    data: {'t': type, 'n': night, 'y': year, 'l': lang, 'g': 'auto'},
  );

  group('«صلّيت» with the app dead', () {
    test('writes exactly one entry: that night of that year', () async {
      expect((await repo.logBook()).years, isEmpty);
      expect(await handlerWith().handle(tap()), RamadanBackgroundOutcome.recorded);

      final entries = (await repo.logBook()).of(1448)!.taraweeh.entries;
      expect(entries, hasLength(1));
      expect(entries[7]!.done, isTrue);
      // Nothing else was touched and nothing was shown: a recorded answer is quiet.
      expect(await repos.keyValues.contains(RamadanRepository.khatmahKey), isFalse);
      expect(await repos.keyValues.contains(RamadanRepository.configKey), isFalse);
      expect(platform.shown, isEmpty);
    });

    test('the same button twice is still exactly one entry, and the stored row is byte-for-byte the same', () async {
      final h = handlerWith();
      expect(await h.handle(tap()), RamadanBackgroundOutcome.recorded);
      final stored = await repos.keyValues.getJson(RamadanRepository.logKey);
      expect(await h.handle(tap()), RamadanBackgroundOutcome.alreadyRecorded);
      expect((await repo.logBook()).of(1448)!.taraweeh.entries, hasLength(1));
      expect(await repos.keyValues.getJson(RamadanRepository.logKey), stored);
    });

    test('a night he had already logged by hand, with its rakaat and a note, is left exactly as it was', () async {
      await repo.setTaraweeh(1448, 7, const TaraweehEntry(night: 7, rakaat: 20, note: 'مع الأهل'));
      expect(await handlerWith().handle(tap()), RamadanBackgroundOutcome.alreadyRecorded);
      expect((await repo.logBook()).of(1448)!.taraweeh.entryOf(7), const TaraweehEntry(night: 7, rakaat: 20, note: 'مع الأهل'));
    });

    test('another night, or last year\'s, is a different entry: nothing is overwritten', () async {
      final h = handlerWith();
      await h.handle(tap());
      await h.handle(tap(night: 8));
      await h.handle(tap(year: 1447));
      final book = await repo.logBook();
      expect(book.of(1448)!.taraweeh.entries.keys.toSet(), {7, 8});
      expect(book.of(1447)!.taraweeh.entries.keys.toSet(), {7});
    });

    test('the year comes as text from the payload and still works (a payload is JSON)', () async {
      expect(await handlerWith().handle(tap(year: '1448')), RamadanBackgroundOutcome.recorded);
      expect((await repo.logBook()).of(1448)!.taraweeh.isDone(7), isTrue);
    });
  });

  group('the app is alive, and everything else', () {
    test('a running app records it: the handler writes nothing itself', () async {
      final alive = _AppAlive();
      expect(await handlerWith(transport: alive).handle(tap()), RamadanBackgroundOutcome.forwarded);
      expect(alive.calls, 1);
      expect((await repo.logBook()).years, isEmpty, reason: 'the app writes it on its own connection');
    });

    test('a tap on the body, a notice, another reminder\'s button, another feature\'s notification: nothing written', () async {
      final h = handlerWith();
      expect(await h.handle(tap(action: null)), RamadanBackgroundOutcome.ignored, reason: 'the body opens the screen, it answers nothing');
      expect(await h.handle(tap(type: RamadanNotificationTaps.typeRunway)), RamadanBackgroundOutcome.ignored);
      expect(await h.handle(tap(type: RamadanNotificationTaps.typeIftar)), RamadanBackgroundOutcome.ignored, reason: 'only the Taraweeh reminder has the button');
      expect(await h.handle(tap(action: 'iqama.prayed')), RamadanBackgroundOutcome.ignored);
      expect(await h.handle(const NotificationTap(id: 1, namespace: 'iqama', actionId: RamadanActions.prayed, data: {'t': 'taraweeh', 'n': 7, 'y': 1448})), RamadanBackgroundOutcome.ignored);
      for (final bad in [tap(night: 0), tap(night: 31), tap(year: 'x'), tap(year: 0), tap(year: null)]) {
        expect(await h.handle(bad), RamadanBackgroundOutcome.ignored, reason: 'a malformed payload is never guessed at');
      }
      expect((await repo.logBook()).years, isEmpty);
    });

    test('no database: the answer is not lost silently - a notice asks him to open Madar, through the gate', () async {
      final outcome = await handlerWith(databaseExists: false).handle(tap());
      expect(outcome, RamadanBackgroundOutcome.failed);
      final notice = platform.shown.values.single.request;
      expect(notice.title, 'ما انحفظت ليلة التراويح');
      expect(notice.body, 'افتح مدار وسجّلها بإيدك.');
      expect(notice.namespace, NotificationNamespaces.ramadan);
      expect((await repo.logBook()).years, isEmpty);
    });

    test('the notice is in the language the reminder was written in', () async {
      await handlerWith(databaseExists: false).handle(tap(lang: 'en'));
      expect(platform.shown.values.single.request.title, 'The Taraweeh night was not saved');
    });
  });

  group('the app\'s background entry point', () {
    test('taps are routed by their namespace: Ramadan\'s are recognised, nothing else is', () {
      expect(RamadanNotificationTaps.isRamadan(tap()), isTrue);
      expect(RamadanNotificationTaps.prayedOf(tap())?.night, 7);
      expect(RamadanNotificationTaps.prayedOf(tap(night: 12))?.night, 12);
      expect(RamadanNotificationTaps.prayedOf(tap(action: 'ramadan.other')), isNull);
      expect(RamadanNotificationTaps.opensRamadan(tap(action: null)), isTrue);
      expect(RamadanNotificationTaps.opensRamadan(tap()), isFalse);
    });
  });
}
