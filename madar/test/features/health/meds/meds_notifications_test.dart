import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/health/meds/data/meds_background.dart';
import 'package:madar/features/health/meds/data/meds_notifications.dart';
import 'package:madar/features/health/meds/data/meds_service.dart';
import 'package:madar/features/health/meds/domain/dose_scheduler.dart';
import 'package:madar/features/health/meds/domain/med_models.dart';
import 'package:madar/features/health/meds/domain/meds_settings.dart';
import 'package:madar/features/health/meds/meds_texts.dart';

class _Transport implements MedsActionTransport {
  _Transport(this.accept);
  final bool accept;
  final List<MedDoseAction> sent = [];

  @override
  Future<bool> forward(MedDoseAction action) async {
    sent.add(action);
    return accept;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final texts = MedsTexts.forLanguage('ar');
  var now = DateTime(2026, 9, 29, 7, 0);

  late MadarDatabase db;
  late MedsService service;
  late FakeNotificationPlatform platform;
  late NotificationService notifications;
  late MedsReminderEngine engine;

  setUp(() {
    now = DateTime(2026, 9, 29, 7, 0);
    db = MadarDatabase(NativeDatabase.memory());
    service = MedsService(Repositories(db), clock: () => now);
    platform = FakeNotificationPlatform();
    notifications = NotificationService(platform, clock: () => now);
    engine = MedsReminderEngine(service: service, notifications: notifications, texts: texts, clock: () => now);
  });
  tearDown(() async {
    await notifications.dispose();
    await db.close();
  });

  Future<MedSpec> addMed(String name, List<String> times, {int? stock, int? refillAt}) => service.saveMed(
    MedDraft(
      name: name,
      dose: '10 mg',
      slots: [for (final t in times) MedSlot(ClockHm.tryParse(t)!)],
      takenWith: TakenWith.breakfast,
      stock: stock,
      refillAt: refillAt,
    ),
  );

  List<FakeScheduled> doseNotices() =>
      platform.scheduled.values.where((s) => MedsNotificationIds.isDose(s.request.id)).toList()
        ..sort((a, b) => a.request.at.compareTo(b.request.at));

  group('reminders', () {
    test('the next 48 hours of open doses, with Taken / Snooze / Skip in the background', () async {
      final m = await addMed('Levo', ['08:00', '20:00']);
      final report = await engine.resync();
      final list = doseNotices();
      expect(report.scheduled, 4); // today 08:00 & 20:00, tomorrow 08:00 & 20:00
      expect(list.map((s) => s.request.at), [
        DateTime(2026, 9, 29, 8),
        DateTime(2026, 9, 29, 20),
        DateTime(2026, 9, 30, 8),
        DateTime(2026, 9, 30, 20),
      ]);
      final first = list.first.request;
      expect(first.channelId, MedsReminderPlanner.channelId);
      expect(platform.channels.keys, contains(MedsReminderPlanner.channelId));
      expect(first.actions.map((a) => a.id), [
        MedsNotificationTaps.actionTaken,
        MedsNotificationTaps.actionSnooze,
        MedsNotificationTaps.actionSkip,
      ]);
      expect(first.actions.every((a) => !a.opensApp && a.cancels), isTrue);
      expect(first.title, contains('Levo'));
      expect(first.body, contains('مع الفطور'));
      expect(first.data['m'], m.id);
      expect(first.data['s'], DateTime(2026, 9, 29, 8).millisecondsSinceEpoch);
      expect(first.data['z'], 10);
      expect(first.publicOnLockScreen, isFalse);
      // The payload decodes back into the dose.
      final tap = NotificationEnvelope.decode(list.first.payload, id: first.id, actionId: MedsNotificationTaps.actionTaken);
      expect(MedsNotificationTaps.doseOf(tap)!.medId, m.id);
      expect(MedsNotificationTaps.actionOf(tap, now: now)!.kind, MedDoseActionKind.taken);
    });

    test('an answered dose drops out; a snoozed one comes back at its new time', () async {
      final m = await addMed('Levo', ['08:00', '20:00']);
      await engine.resync();
      now = DateTime(2026, 9, 29, 8, 2);
      await service.apply(
        MedDoseAction(medId: m.id, slot: DateTime(2026, 9, 29, 8), kind: MedDoseActionKind.taken, at: now),
      );
      await service.apply(
        MedDoseAction(
          medId: m.id,
          slot: DateTime(2026, 9, 29, 20),
          kind: MedDoseActionKind.snoozed,
          at: DateTime(2026, 9, 29, 8, 2),
          snooze: const Duration(hours: 13),
        ),
      );
      await engine.resync();
      final list = doseNotices();
      expect(list.first.request.at, DateTime(2026, 9, 29, 21, 2));
      expect(list.first.request.title, startsWith('تذكير'));
      expect(list.where((s) => s.request.at == DateTime(2026, 9, 29, 8)), isEmpty);
    });

    test('turning reminders off cancels the dose reminders but keeps other meds notices', () async {
      await addMed('Levo', ['08:00']);
      await engine.resync();
      expect(doseNotices(), isNotEmpty);
      await service.saveSettings(const MedsSettings(notify: false));
      await engine.resync();
      expect(doseNotices(), isEmpty);
    });

    test('ids are stable, in the dose block, collision-free', () {
      final keys = [for (var i = 0; i < 400; i++) 'med$i@${29000000 + i}'];
      final a = MedsNotificationIds.assign(keys);
      final b = MedsNotificationIds.assign(keys.reversed);
      expect(a, b);
      expect(a.values.toSet(), hasLength(400));
      expect(a.values.every(MedsNotificationIds.isDose), isTrue);
      expect(MedsNotificationIds.isDose(MedsNotificationIds.refill('x')), isFalse);
      expect(NotificationNamespaces.meds.contains(MedsNotificationIds.refill('x')), isTrue);
    });

    test('refill alert when the stock reaches its threshold', () async {
      final m = await addMed('Levo', ['08:00'], stock: 6, refillAt: 5);
      final r = await service.apply(
        MedDoseAction(medId: m.id, slot: DateTime(2026, 9, 29, 8), kind: MedDoseActionKind.taken, at: now),
      );
      await engine.refillIfNeeded(m.id, r);
      final shown = platform.shown[MedsNotificationIds.refill(m.id)]!.request;
      expect(shown.title, contains('Levo'));
      expect(shown.body, contains('٥'));
    });
  });

  group('background answers', () {
    NotificationTap tapFor(MedSpec m, String action, {int hour = 8}) => NotificationTap(
      id: 120001,
      namespace: 'meds',
      actionId: action,
      data: {'k': 'dose', 'm': m.id, 's': DateTime(2026, 9, 29, hour).millisecondsSinceEpoch, 'z': 30, 'l': 'ar'},
    );

    test('forwarded to the running app when it answers', () async {
      final m = await addMed('Levo', ['08:00']);
      final transport = _Transport(true);
      var opened = 0;
      final handler = MedsBackgroundHandler(
        transport: transport,
        openDatabase: () async {
          opened++;
          return null;
        },
        notifications: notifications,
        engineFor: (s, t) async => engine,
        clock: () => now,
      );
      expect(await handler.handle(tapFor(m, MedsNotificationTaps.actionTaken)), MedsBackgroundOutcome.forwarded);
      expect(transport.sent.single.kind, MedDoseActionKind.taken);
      expect(opened, 0);
      // A tap on the body (no action) is not an answer.
      final body = NotificationTap(id: 1, namespace: 'meds', data: tapFor(m, '').data);
      expect(await handler.handle(body), MedsBackgroundOutcome.ignored);
    });

    test('recorded through the encrypted database file when the app is not running', () async {
      final dir = Directory.systemTemp.createTempSync('madar_meds_bg_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/madar.db');
      const key = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      // The app created the file and a medication earlier.
      final appDb = await openMadarDatabase(key: key, file: file, seed: null);
      final m = await MedsService(Repositories(appDb)).saveMed(
        MedDraft(name: 'Levo', slots: const [MedSlot(ClockHm(8, 0))], stock: 6, refillAt: 5),
      );
      await appDb.close();

      final handler = MedsBackgroundHandler(
        transport: _Transport(false),
        openDatabase: () => openMadarDatabase(key: key, file: file, seed: null),
        notifications: notifications,
        engineFor: (s, t) async =>
            MedsReminderEngine(service: s, notifications: notifications, texts: texts, clock: () => now),
        clock: () => now,
      );
      now = DateTime(2026, 9, 29, 8, 3);
      expect(await handler.handle(tapFor(m, MedsNotificationTaps.actionTaken)), MedsBackgroundOutcome.applied);
      // Twice (a repeated delivery) changes nothing.
      expect(await handler.handle(tapFor(m, MedsNotificationTaps.actionTaken)), MedsBackgroundOutcome.applied);
      // Snooze on the answered dose changes nothing either.
      expect(
        await handler.handle(tapFor(m, MedsNotificationTaps.actionSnooze, hour: 8)),
        MedsBackgroundOutcome.applied,
      );

      final check = await openMadarDatabase(key: key, file: file, seed: null);
      addTearDown(check.close);
      final repos = Repositories(check);
      final rows = await repos.medDoses.getAll();
      expect(rows.single.status, DoseStatus.taken);
      expect(rows.single.takenAt, DateTime(2026, 9, 29, 8, 3));
      expect((await repos.medications.byId(m.id))!.stock, 5);
      expect(await repos.activity.since(DateTime(2026, 9, 1), planetKey: 'health'), hasLength(1));
      // Tomorrow's reminder is planned; the refill alert was shown.
      expect(doseNotices().first.request.at, DateTime(2026, 9, 30, 8));
      expect(platform.shown.keys, contains(MedsNotificationIds.refill(m.id)));
    });

    test('a failure is never silent: the user is asked to open the app', () async {
      final m = await addMed('Levo', ['08:00']);
      final handler = MedsBackgroundHandler(
        transport: _Transport(false),
        openDatabase: () async => null,
        notifications: notifications,
        engineFor: (s, t) async => engine,
        clock: () => now,
      );
      expect(await handler.handle(tapFor(m, MedsNotificationTaps.actionSkip)), MedsBackgroundOutcome.failed);
      final notice = platform.shown.values.single.request;
      expect(notice.title, 'لم تُسجَّل الجرعة');
      expect(MedsNotificationIds.namespace.contains(notice.id), isTrue);
    });

    test('isolate port round trip: the app receives, records and acknowledges', () async {
      final got = <MedDoseAction>[];
      final receiver = MedsActionReceiver((a) async {
        got.add(a);
        return true;
      })..open();
      addTearDown(receiver.close);
      final action = MedDoseAction(
        medId: 'm',
        slot: DateTime(2026, 9, 29, 8),
        kind: MedDoseActionKind.snoozed,
        at: now,
        snooze: const Duration(minutes: 30),
      );
      expect(await const IsolateMedsActionTransport().forward(action), isTrue);
      expect(got.single.snooze, const Duration(minutes: 30));
      receiver.close();
      expect(await const IsolateMedsActionTransport(timeout: Duration(milliseconds: 200)).forward(action), isFalse);
    });

    test('the entry point ignores other features’ responses', () {
      // A foreign payload must not throw (the adhan's Stop runs through the
      // same entry point).
      expect(() => MedsNotificationTaps.actionOf(NotificationEnvelope.decode('{"ns":"adhan","d":{}}'), now: now), returnsNormally);
      expect(MedsNotificationTaps.actionOf(NotificationEnvelope.decode('{"ns":"adhan","d":{}}'), now: now), isNull);
      expect(PlannedDose.doseKey('a', DateTime(2026, 9, 29, 8)), isNotEmpty);
    });
  });
}
