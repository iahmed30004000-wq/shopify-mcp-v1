import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/core/notifications/notification_service.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/health/record/record.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_app.dart';

void main() {
  final now = DateTime(2026, 9, 29, 10);
  late MadarDatabase db;
  late Repositories repos;
  late RecordService s;

  setUp(() {
    db = testDatabase(seed: false);
    repos = Repositories(db);
    s = RecordService(repos, clock: () => now);
  });
  tearDown(() => db.close());

  Future<List<ActivityRow>> health() => repos.activity.since(DateTime(2000), planetKey: 'health');

  test('alerts: add, pin, edit, reorder and delete – each undoable', () async {
    final (a, undoAdd) = await s.addAlert(body: ' No cortisone ');
    final (b, _) = await s.addAlert(body: 'Penicillin', severity: Severity.warning);
    expect(a.body, 'No cortisone');
    expect(a.pinned, isTrue);
    expect(a.severity, Severity.critical);

    final unpin = await s.setAlertPinned(a.id, false);
    expect((await repos.healthAlerts.byId(a.id))!.pinned, isFalse);
    await unpin();
    expect((await repos.healthAlerts.byId(a.id))!.pinned, isTrue);

    final undoEdit = await s.updateAlert(a.copyWith(body: 'Changed', severity: Severity.info));
    expect((await repos.healthAlerts.byId(a.id))!.severity, Severity.info);
    await undoEdit();
    expect((await repos.healthAlerts.byId(a.id))!.body, 'No cortisone');

    final undoOrder = await s.reorderAlerts([b.id, a.id]);
    expect((await repos.healthAlerts.getAll()).map((r) => r.id), [b.id, a.id]);
    await undoOrder();
    expect((await repos.healthAlerts.getAll()).map((r) => r.id), [a.id, b.id]);

    final undoDelete = await s.deleteAlert(a.id);
    expect(await repos.healthAlerts.byId(a.id), isNull);
    await undoDelete!();
    expect((await repos.healthAlerts.byId(a.id))!.body, 'No cortisone');
    await undoAdd();
    expect(await repos.healthAlerts.count(), 1);
    expect(await s.deleteAlert('missing'), isNull);
  });

  test('conditions: active flag, notes cleared, reorder', () async {
    final (c, _) = await s.addCondition(name: 'A', notes: '  ', since: DateTime(2021, 3, 1));
    expect(c.notes, isNull);
    expect(c.since, DateTime(2021, 3, 1));
    final undo = await s.setConditionActive(c.id, false);
    expect((await repos.conditions.byId(c.id))!.active, isFalse);
    await undo();
    expect((await repos.conditions.byId(c.id))!.active, isTrue);
  });

  test('labs: readings log on the Health planet; deleting a test takes its readings and comes back', () async {
    final (t, _) = await s.addTest(name: 'TSH', unit: 'mIU/L', low: 0.4, high: 4, category: ' Thyroid ');
    expect(t.category, 'Thyroid');
    final (r, undoReading) = await s.addReading(
      testId: t.id,
      date: DateTime(2026, 9, 12),
      input: LabValueInput.parse('3.85'),
    );
    expect(r.value, 3.85);
    expect((await health()).single.kind, RecordActivityKinds.labReading);
    await undoReading();
    expect(await repos.labReadings.count(), 0);
    expect(await health(), isEmpty);

    await s.addReading(testId: t.id, date: DateTime(2026, 9, 12), input: LabValueInput.parse('negative'));
    final undoDelete = await s.deleteTest(t.id);
    expect(await repos.labTests.count(), 0);
    expect(await repos.labReadings.count(), 0);
    await undoDelete!();
    expect(await repos.labTests.count(), 1);
    expect((await repos.labReadings.getAll()).single.valueText, 'negative');
  });

  test('a lab visit saves several results at once and undoes as one', () async {
    final (a, _) = await s.addTest(name: 'A');
    final (b, _) = await s.addTest(name: 'B');
    final (c, _) = await s.addTest(name: 'C');
    final (rows, undo) = await s.addVisit(
      date: DateTime(2026, 9, 12),
      entries: [
        (testId: a.id, input: LabValueInput.parse('1.5'), note: null),
        (testId: b.id, input: LabValueInput.parse(''), note: null),
        (testId: c.id, input: LabValueInput.parse('trace'), note: ' x '),
      ],
    );
    expect(rows, hasLength(2));
    expect(rows.every((r) => r.date == DateTime(2026, 9, 12)), isTrue);
    expect(rows.last.note, 'x');
    final logs = await health();
    expect(logs.single.kind, RecordActivityKinds.labVisit);
    expect(logs.single.value, 2);
    await undo();
    expect(await repos.labReadings.count(), 0);
    expect(await health(), isEmpty);
  });

  test('appointments: done logs a completion; deleting keeps its questions as general ones', () async {
    final (a, _) = await s.addAppointment(
      title: 'Endo',
      at: DateTime(2026, 10, 6, 10, 30),
      doctor: ' ',
      place: 'Clinic',
    );
    expect(a.doctor, isNull);
    final (q, _) = await s.addQuestion(question: 'Q?', appointmentId: a.id);

    final undoDone = await s.setAppointmentDone(a.id, true);
    expect((await repos.appointments.byId(a.id))!.done, isTrue);
    expect((await health()).single.kind, RecordActivityKinds.appointmentDone);
    await undoDone();
    expect((await repos.appointments.byId(a.id))!.done, isFalse);
    expect(await health(), isEmpty);

    await s.setAppointmentDone(a.id, true);
    final undoDelete = await s.deleteAppointment(a.id);
    expect(await repos.appointments.count(), 0);
    expect((await repos.doctorQuestions.byId(q.id))!.appointmentId, isNull);
    expect(await health(), isEmpty);
    await undoDelete!();
    expect((await repos.appointments.byId(a.id))!.done, isTrue);
    expect((await repos.doctorQuestions.byId(q.id))!.appointmentId, a.id);
    expect(await health(), hasLength(1));
  });

  test('questions: answering logs, reopening removes, reorder undo', () async {
    final (q1, _) = await s.addQuestion(question: 'One');
    final (q2, _) = await s.addQuestion(question: 'Two');
    final undoAnswer = await s.setAnswered(q1.id, true, answer: ' Yes ');
    final answered = (await repos.doctorQuestions.byId(q1.id))!;
    expect(answered.answered, isTrue);
    expect(answered.answer, 'Yes');
    expect((await health()).single.kind, RecordActivityKinds.questionAnswered);
    await undoAnswer();
    expect((await repos.doctorQuestions.byId(q1.id))!.answered, isFalse);
    expect(await health(), isEmpty);

    await s.setAnswered(q1.id, true);
    final undoReopen = await s.setAnswered(q1.id, false);
    expect(await health(), isEmpty);
    await undoReopen();
    expect(await health(), hasLength(1));

    final undoOrder = await s.reorderQuestions([q2.id, q1.id]);
    expect((await repos.doctorQuestions.getAll()).first.id, q2.id);
    await undoOrder();
    expect((await repos.doctorQuestions.getAll()).first.id, q1.id);
  });

  test('settings are stored under health.record and undoable', () async {
    expect(await s.settings(), const RecordSettings());
    final undo = await s.saveSettings(const RecordSettings(borderlineMargin: 0.1));
    expect((await s.settings()).borderlineMargin, 0.1);
    expect(await repos.keyValues.getJson(RecordSettings.storageKey), isA<Map<String, Object?>>());
    await undo();
    expect(await s.settings(), const RecordSettings());
  });

  group('appointment reminders', () {
    late FakeNotificationPlatform platform;
    late NotificationService service;
    late NotificationAppointmentReminderScheduler scheduler;
    final l = lookupL10n(const Locale('ar'));
    final fmt = const MadarFormatter();

    setUp(() {
      platform = FakeNotificationPlatform();
      service = NotificationService(platform, clock: () => now);
      scheduler = NotificationAppointmentReminderScheduler(
        notifications: service,
        texts: () => (group: 'g', name: 'n', description: 'd'),
      );
    });

    test('sync touches only the record block of the health namespace', () async {
      // Another health package's notification (e.g. a refill) stays.
      await service.schedule(
        NotificationRequest(
          namespace: NotificationNamespaces.health,
          id: 150600,
          channelId: 'x',
          title: 'refill',
          body: '',
          at: now.add(const Duration(days: 2)),
        ),
      );
      final a = AppointmentRow(
        id: 'a',
        createdAt: now,
        updatedAt: now,
        title: 'مراجعة',
        doctor: 'د. سلمى',
        at: DateTime(2026, 10, 6, 10, 30),
        done: false,
      );
      final reminders = AppointmentReminderPlanner.plan(appointments: [a], now: now, offsets: const [1440, 120]);
      await initializeDateFormatting();
      final notices = AppointmentNoticeTexts.build(reminders, {'a': a}, l, fmt);
      expect(notices, hasLength(2));
      expect(notices.first.title, contains('مراجعة'));
      expect(notices.first.body, contains(l.recordTomorrow));
      expect(notices.last.body, contains(l.recordReminderIn('').trim()));
      await scheduler.replaceAll(notices);
      final pending = await service.pendingIn(NotificationNamespaces.health);
      expect(pending.map((p) => p.id).toSet(), {150000, 150001, 150600});
      final tap = pending.firstWhere((p) => p.id == 150000);
      expect(AppointmentReminderTaps.appointmentOf(tap), 'a');

      await scheduler.cancelAll();
      expect((await service.pendingIn(NotificationNamespaces.health)).map((p) => p.id), [150600]);
    });
  });

  test('the reminder sync plans from the appointments and settings', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final recorder = RecordingAppointmentReminderScheduler();
    await s.addAppointment(title: 'Endo', at: DateTime(2026, 10, 1, 9));
    await s
        .addAppointment(title: 'Done', at: DateTime(2026, 10, 2, 9))
        .then((r) => s.setAppointmentDone(r.$1.id, true));
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        homeClockProvider.overrideWithValue(() => now),
        recordReminderSchedulerProvider.overrideWithValue(recorder),
        appSettingsProvider.overrideWith(() => _En()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(recordReminderSyncProvider, (_, _) {});
    await container.read(appointmentsProvider.future);
    await container.read(recordSettingsProvider.future);
    await container.read(recordReminderSyncProvider.notifier).syncNow();
    expect(recorder.current.map((n) => n.reminder.offsetMinutes), [1440, 120]);
    expect(recorder.current.first.title, 'Appointment: \u2068Endo\u2069');

    await s.saveSettings(const RecordSettings(remindersEnabled: false));
    await container.read(recordSettingsProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await container.read(recordReminderSyncProvider.notifier).syncNow();
    expect(recorder.current, isEmpty);
  });
}

class _En extends AppSettingsController {
  @override
  AppSettings build() => const AppSettings(languageCode: 'en');
}
