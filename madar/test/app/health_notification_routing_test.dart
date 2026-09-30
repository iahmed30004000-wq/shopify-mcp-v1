// Health notifications into the running app, end to end (router, database
// gate, adhan host, app lock, the app's services):
// * at start the app plans the next 48 h of dose reminders (with Taken /
//   Snooze / Skip), appointment reminders and the worry window's notice;
// * a tap on a dose, refill, appointment or worry-window notification opens
//   its screen (cold start or warm), under the app lock like every deep link;
// * a dose's Taken / Snooze / Skip button is recorded – never opened – and
//   production hands the shade's buttons to the meds background entry.
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/health_services.dart';
import 'package:madar/app/suspending_flows.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/health/meds/meds.dart';
import 'package:madar/features/health/record/record.dart';
import 'package:madar/features/health/wellbeing/wellbeing.dart';
import 'package:madar/features/lock/presentation/lock_screen.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';

import '../features/lock/lock_test_utils.dart';
import '../features/orbit/presentation/orbit_scene_fixtures.dart';
import '../helpers/test_app.dart';

final DateTime _now = DateTime(2026, 9, 29, 7, 30);
const _english = AppSettings(onboarded: true, languageCode: 'en');

RawNotificationTap _tap(
  NotificationNamespace ns,
  int id,
  Map<String, Object?> data, {
  String? action,
  bool launch = false,
}) => RawNotificationTap(
  id: id,
  actionId: action,
  fromLaunch: launch,
  payload: NotificationEnvelope.encode(
    NotificationRequest(namespace: ns, id: id, channelId: 'test', title: 't', body: '', at: _now, data: data),
  ),
);

RawNotificationTap _doseTap(String medId, DateTime slot, {String? action, bool launch = false}) => _tap(
  NotificationNamespaces.meds,
  120001,
  {'k': MedsNotificationTaps.kDose, 'm': medId, 's': slot.millisecondsSinceEpoch, 'z': 10, 'l': 'en'},
  action: action,
  launch: launch,
);

NotificationTap _decoded(RawNotificationTap raw) =>
    NotificationEnvelope.decode(raw.payload, id: raw.id, actionId: raw.actionId);

/// Lets database writes and the reminder syncs' debounces finish.
Future<void> _writes(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// A medication at 08:00 and 20:00, saved through the tracker.
Future<String> _seedMed(MadarDatabase db) async {
  await OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings());
  final med = await MedsService(Repositories(db), clock: () => _now).saveMed(
    const MedDraft(name: 'Metformin', dose: '500 mg', slots: [MedSlot(ClockHm(8, 0)), MedSlot(ClockHm(20, 0))]),
  );
  return med.id;
}

void main() {
  group('where a tap leads (pure)', () {
    final slot = DateTime(2026, 9, 29, 8);
    test('dose, refill and notice bodies open the medications; buttons never navigate', () {
      expect(healthNotificationLocation(_decoded(_doseTap('m1', slot))), AppRoutes.meds);
      expect(
        healthNotificationLocation(_decoded(_doseTap('m1', slot, action: MedsNotificationTaps.actionTaken))),
        isNull,
      );
      expect(
        healthNotificationLocation(_decoded(_doseTap('m1', slot, action: MedsNotificationTaps.actionSkip))),
        isNull,
      );
      final refill = _tap(NotificationNamespaces.meds, 129001, {'k': MedsNotificationTaps.kRefill, 'm': 'm1'});
      expect(healthNotificationLocation(_decoded(refill)), '/meds?tab=meds');
      final notice = _tap(NotificationNamespaces.meds, 129501, {'k': MedsNotificationTaps.kNotice, 'm': 'm1'});
      expect(healthNotificationLocation(_decoded(notice)), AppRoutes.meds);
    });

    test('an appointment reminder lights its appointment; the worry window opens the worries', () {
      final appt = _tap(NotificationNamespaces.health, 150010, {'kind': 'appointment', 'appointment': 'a1'});
      expect(healthNotificationLocation(_decoded(appt)), '/record/appointments?highlight=a1');
      final worry = _tap(NotificationNamespaces.health, WorryReminderIds.first, {'kind': 'worryWindow'});
      expect(healthNotificationLocation(_decoded(worry)), '/wellbeing?tab=worries');
      final adhkar = _tap(NotificationNamespaces.adhkar, 110000, {'set': 'morning'});
      expect(healthNotificationLocation(_decoded(adhkar)), isNull);
    });
  });

  testWidgets('at start the health reminders are planned: doses, appointments, the worry window', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      now: _now,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) async {
        await _seedMed(db);
        final record = RecordService(Repositories(db), clock: () => _now);
        await record.addAppointment(title: 'Check-up', at: DateTime(2026, 10, 2, 10, 30));
        await WellbeingService(
          Repositories(db),
          clock: () => _now,
        ).updateSettings((s) => s.copyWith(worry: const WorryWindowSettings(enabled: true, minuteOfDay: 18 * 60)));
      },
    );
    await _writes(tester);
    final scheduled = app.notifications.scheduled;
    final doses = scheduled.values.where((s) => MedsNotificationIds.isDose(s.request.id)).toList();
    // Today 08:00 and 20:00, tomorrow 08:00 and 20:00, and the day after's
    // 08:00 fall in the next 48 hours.
    expect(doses.length, greaterThanOrEqualTo(4));
    expect(doses.every((d) => d.request.actions.length == 3), isTrue, reason: 'Taken / Snooze / Skip');
    expect(scheduled.keys.any(AppointmentReminderIds.owns), isTrue);
    expect(scheduled.keys.any(WorryReminderIds.owns), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('warm: a dose body tap opens the medications; Taken is recorded without navigating', (tester) async {
    late String medId;
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      now: _now,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) async => medId = await _seedMed(db),
    );
    final slot = DateTime(2026, 9, 29, 8);
    app.notifications.tap(_doseTap(medId, slot, action: MedsNotificationTaps.actionTaken));
    await _writes(tester);
    expect(app.location, AppRoutes.home, reason: 'a button answers, it never opens');
    final rows = (await tester.runAsync(() => Repositories(app.db).medDoses.getAll()))!;
    expect(rows.single.status, DoseStatus.taken);
    expect(rows.single.scheduledAt, slot);

    app.notifications.tap(_doseTap(medId, slot));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.meds);
    expect(find.byType(MedsScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Snooze from the shade is recorded as a snooze', (tester) async {
    late String medId;
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      now: _now,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) async => medId = await _seedMed(db),
    );
    app.notifications.tap(_doseTap(medId, DateTime(2026, 9, 29, 8), action: MedsNotificationTaps.actionSnooze));
    await _writes(tester);
    final rows = (await tester.runAsync(() => Repositories(app.db).medDoses.getAll()))!;
    expect(rows.single.status, DoseStatus.snoozed);
    expect(app.location, AppRoutes.home);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('cold start from an appointment reminder lights it on the appointments', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      now: _now,
      notifications: FakeNotificationPlatform(
        launch: _tap(NotificationNamespaces.health, 150003, {'kind': 'appointment', 'appointment': 'a9'}, launch: true),
      ),
      overrides: LockFixture.empty().overrides,
    );
    expect(app.router.state.uri.toString(), '/record/appointments?highlight=a9');
    expect(tester.widget<AppointmentsScreen>(find.byType(AppointmentsScreen)).highlightId, 'a9');
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.record);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a worry-window tap while locked moves the router under the lock', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    final app = await pumpMadarApp(tester, settings: _english, now: _now, overrides: fx.overrides);
    expect(find.byType(LockScreen), findsOneWidget);
    app.notifications.tap(_tap(NotificationNamespaces.health, WorryReminderIds.first, {'kind': 'worryWindow'}));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), '/wellbeing?tab=worries');
    expect(find.byType(LockScreen), findsOneWidget, reason: 'a deep link never lifts the lock');
    expect(find.byType(WellbeingScreen), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  test('production hands the shade\'s dose buttons to the meds background entry', () {
    final container = ProviderContainer(overrides: suspendingFlowOverrides());
    addTearDown(container.dispose);
    final platform = container.read(notificationPlatformProvider);
    expect(platform, isA<SuspendingNotificationPlatform>());
    final inner = (platform as SuspendingNotificationPlatform).inner;
    expect(inner, isA<FlutterLocalNotificationsPlatform>());
    expect((inner as FlutterLocalNotificationsPlatform).backgroundHandler, same(medsNotificationBackgroundTap));
  });

  test('the doctor report and the dialler leave the app suspended (the lock never trips on them)', () async {
    final calls = <String>[];
    Future<T> suspend<T>(Future<T> Function() action) async {
      calls.add('in');
      try {
        return await action();
      } finally {
        calls.add('out');
      }
    }

    final recording = RecordingReportExporter();
    final exporter = SuspendingReportExporter(recording, suspend);
    final file = DoctorReportFile(
      bytes: Uint8List(4),
      fileName: 'madar-health-report-2026-09-29.pdf',
      document: ReportDocument(
        languageCode: 'en',
        title: 't',
        periodLine: 'p',
        generatedLine: 'g',
        nameLabel: 'n',
        footer: 'f',
        pageLabel: (page, total) => '$page/$total',
        blocks: const [],
      ),
    );
    await exporter.share(file, subject: 's');
    expect(await exporter.save(file), isTrue);
    expect(recording.shared.single, same(file));
    expect(recording.saved.single, same(file));
    final dialer = RecordingPhoneDialer();
    expect(await SuspendingPhoneDialer(dialer, suspend).dial('911'), isTrue);
    expect(dialer.dialed, ['911']);
    expect(calls, ['in', 'out', 'in', 'out', 'in', 'out']);

    final container = ProviderContainer(overrides: suspendingFlowOverrides());
    addTearDown(container.dispose);
    expect(container.read(reportExporterProvider), isA<SuspendingReportExporter>());
    expect(container.read(phoneDialerProvider), isA<SuspendingPhoneDialer>());
  });
}
