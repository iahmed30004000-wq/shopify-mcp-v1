// A dose answered in the notification shade, while the app is dead, runs in
// its own isolate with its own database – and it RE-PLANS the next doses.
//
// Safety-critical: without a gate carrying the owner's stored mutes, that
// re-plan re-arms exactly the doses a "Medications" mute is holding back,
// so answering one dose in the shade would make the muted ones sound. These
// tests run the very seams `madarAppNotificationBackgroundTap` uses
// (`madarBackgroundGateSeams`), over a fake plugin and an in-memory
// database.
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/background_notifications.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/health/meds/meds.dart';
import 'package:madar/features/notification_center/notification_center.dart';

class _NoApp implements MedsActionTransport {
  @override
  Future<bool> forward(MedDoseAction action) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final texts = MedsTexts.forLanguage('ar');
  var now = DateTime(2026, 9, 29, 8, 3);

  late Directory dir;
  late File file;
  late MadarDatabase db;
  late MedsService service;
  late FakeNotificationPlatform platform;
  late NotificationGate gate;
  late NotificationService notifications;
  late MedsBackgroundHandler handler;
  var replanned = 0;
  Future<void> Function(KeyValueRepository keyValues)? beforeReplan;

  // A file, not memory: the background handler closes the database it
  // opened (as the real isolate does), so the test keeps its own connection
  // to the same file – exactly the two connections production has.
  setUp(() {
    now = DateTime(2026, 9, 29, 8, 3);
    replanned = 0;
    dir = Directory.systemTemp.createTempSync('madar_meds_gate_');
    file = File('${dir.path}/madar.db');
    db = MadarDatabase(NativeDatabase(file));
    service = MedsService(Repositories(db), clock: () => now);
    platform = FakeNotificationPlatform();
    // Exactly what the app's background entry point builds.
    gate = NotificationGate.background(clock: () => now);
    final seams = madarBackgroundGateSeams(gate);
    beforeReplan = seams.beforeReplan;
    notifications = NotificationService(seams.wrapPlatform(platform), clock: () => now);
    handler = MedsBackgroundHandler(
      transport: _NoApp(),
      // A connection of its own, closed again by the handler.
      openDatabase: () async => MadarDatabase(NativeDatabase(file)),
      notifications: notifications,
      engineFor: (s, t) async {
        replanned++;
        await beforeReplan!(s.repos.keyValues);
        return MedsReminderEngine(service: s, notifications: notifications, texts: texts, clock: () => now);
      },
      clock: () => now,
    );
  });
  tearDown(() async {
    await notifications.dispose();
    await db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<MedSpec> addMed(List<String> times, {int? stock, int? refillAt}) => service.saveMed(
    MedDraft(
      name: 'Levo',
      dose: '10 mg',
      slots: [for (final t in times) MedSlot(ClockHm.tryParse(t)!)],
      stock: stock,
      refillAt: refillAt,
    ),
  );

  Future<void> mute(DateTime until) =>
      NotificationCenterStore(Repositories(db).keyValues).savePolicy(
        CenterPolicy.empty.mute(NotificationGroup.medications, until),
      );

  NotificationTap tap(MedSpec m, String action, {int hour = 8}) => NotificationTap(
    id: 120001,
    namespace: 'meds',
    actionId: action,
    data: {'k': 'dose', 'm': m.id, 's': DateTime(2026, 9, 29, hour).millisecondsSinceEpoch, 'z': 30, 'l': 'ar'},
  );

  List<FakeScheduled> doses() =>
      platform.scheduled.values.where((s) => MedsNotificationIds.isDose(s.request.id)).toList()
        ..sort((a, b) => a.request.at.compareTo(b.request.at));

  test('a stored mute keeps the background re-plan from arming the doses it holds', () async {
    final m = await addMed(['08:00', '20:00']);
    // Muted until tomorrow noon: today's 20:00 and tomorrow's 08:00 are held.
    await mute(DateTime(2026, 9, 30, 12));

    expect(await handler.handle(tap(m, MedsNotificationTaps.actionTaken)), MedsBackgroundOutcome.applied);
    expect(replanned, 1, reason: 'the answer re-plans the next doses');
    expect(gate.policyLoaded, isTrue, reason: 'the stored policy was loaded before the re-plan');

    // The answer itself is recorded whatever the policy says.
    expect((await Repositories(db).medDoses.getAll()).single.status, DoseStatus.taken);

    final armed = doses().map((s) => s.request.at).toList();
    expect(
      armed.where((at) => at.isBefore(DateTime(2026, 9, 30, 12))),
      isEmpty,
      reason: 'a muted dose reached the platform: $armed',
    );
    expect(armed, isNotEmpty, reason: 'doses after the mute ends must still be armed');
    expect(armed.first.isAfter(DateTime(2026, 9, 30, 12)), isTrue);
  });

  test('with nothing muted, the same answer arms the next dose', () async {
    final m = await addMed(['08:00', '20:00']);
    expect(await handler.handle(tap(m, MedsNotificationTaps.actionTaken)), MedsBackgroundOutcome.applied);
    expect(doses().first.request.at, DateTime(2026, 9, 29, 20));
  });

  test('the "answer not recorded" notice is never silenced by a mute', () async {
    final m = await addMed(['08:00']);
    await mute(DateTime(2026, 9, 30, 12));
    // The database cannot be opened: the answer is lost, the user must know.
    final failing = MedsBackgroundHandler(
      transport: _NoApp(),
      openDatabase: () async => null,
      notifications: notifications,
      engineFor: (s, t) async => throw StateError('unreachable'),
      clock: () => now,
    );
    // The policy is in the gate (loaded by the run above would not have
    // happened here), so load it as the isolate does before failing.
    await beforeReplan!(Repositories(db).keyValues);
    expect(await failing.handle(tap(m, MedsNotificationTaps.actionSkip)), MedsBackgroundOutcome.failed);
    final notice = platform.shown.values.single.request;
    expect(notice.title, 'لم تُسجَّل الجرعة');
    expect(
      gate.withholds(CenterNotice.fromRequest(notice)),
      isTrue,
      reason: 'the mute does cover this group – and the notice must still have been shown',
    );
  });

  test('a policy that cannot be read holds nothing back, and never loses the answer', () async {
    final m = await addMed(['08:00', '20:00']);
    // A corrupt policy row (a string where the object belongs).
    await Repositories(db).keyValues.setJson(NotificationCenterStore.policyKey, 'not a policy');
    expect(await handler.handle(tap(m, MedsNotificationTaps.actionTaken)), MedsBackgroundOutcome.applied);
    expect((await Repositories(db).medDoses.getAll()).single.status, DoseStatus.taken);
    expect(doses(), isNotEmpty, reason: 'fails open: the reminders stay planned');
  });

  test('loading the policy cannot cost the answer, however it fails', () async {
    final m = await addMed(['08:00', '20:00']);
    beforeReplan = (_) async => throw StateError('the policy store is unavailable');
    // The dose is recorded whatever happens on the way to the re-plan (the
    // handler swallows a broken engine; `runMedsBackgroundAction` swallows
    // this one even earlier, so there the re-plan still runs).
    expect(await handler.handle(tap(m, MedsNotificationTaps.actionTaken)), MedsBackgroundOutcome.applied);
    expect((await Repositories(db).medDoses.getAll()).single.status, DoseStatus.taken);
    expect(platform.shown, isEmpty, reason: 'no "not recorded" notice: it was recorded');
  });

  test('the background gate never sweeps and never silences an immediate notice', () {
    final background = NotificationGate.background();
    expect(background.holdImmediate, isFalse);
  });
}
