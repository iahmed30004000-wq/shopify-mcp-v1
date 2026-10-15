import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../orbit/data/orbit_providers.dart';
import '../domain/appointment_plan.dart';
import '../domain/lab_flags.dart';
import '../domain/lab_series.dart';
import '../domain/record_settings.dart';
import '../pdf/report_fonts.dart';
import 'appointment_reminders.dart';
import 'doctor_report.dart';
import 'record_service.dart';

// ------------------------------------------------------------- basics ----

/// The record's wall clock (follows the orbit's, so tests freeze both).
final recordClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// Today's calendar day (turns at local midnight).
final recordTodayProvider = Provider<DateTime>((ref) => ref.watch(orbitTodayProvider));

/// Logs completions on the Health planet through the orbit's pulse hub (the
/// world flares). Tests may override it with null (plain activity rows).
final recordActivityRecorderProvider = Provider<RecordActivityRecorder?>((ref) {
  final hub = ref.watch(orbitPulseHubProvider);
  return (kind, table, id, {value}) => hub.recordCompletion(RecordService.planetKey, kind, table, id, value: value);
});

final recordServiceProvider = Provider<RecordService>(
  (ref) => RecordService(
    ref.watch(repositoriesProvider),
    clock: ref.watch(recordClockProvider),
    recorder: ref.watch(recordActivityRecorderProvider),
  ),
);

// -------------------------------------------------------------- streams ----

/// Every standing alert (pinned and unpinned), in the user's order.
final healthAlertsProvider = StreamProvider<List<HealthAlertRow>>(
  (ref) => ref.watch(recordServiceProvider).watchAlerts(),
);

/// The pinned alerts the banner shows.
final pinnedHealthAlertsProvider = Provider<AsyncValue<List<HealthAlertRow>>>(
  (ref) => ref
      .watch(healthAlertsProvider)
      .whenData(
        (all) => [
          for (final a in all)
            if (a.pinned) a,
        ],
      ),
);

final conditionsProvider = StreamProvider<List<ConditionRow>>(
  (ref) => ref.watch(recordServiceProvider).watchConditions(),
);

final labTestsProvider = StreamProvider<List<LabTestRow>>((ref) => ref.watch(recordServiceProvider).watchTests());

final labReadingsProvider = StreamProvider<List<LabReadingRow>>(
  (ref) => ref.watch(recordServiceProvider).watchReadings(),
);

final appointmentsProvider = StreamProvider<List<AppointmentRow>>(
  (ref) => ref.watch(recordServiceProvider).watchAppointments(),
);

final doctorQuestionsProvider = StreamProvider<List<DoctorQuestionRow>>(
  (ref) => ref.watch(recordServiceProvider).watchQuestions(),
);

final recordSettingsProvider = StreamProvider<RecordSettings>(
  (ref) => ref.watch(recordServiceProvider).watchSettings(),
);

/// The settings, defaults until loaded.
final recordSettingsValueProvider = Provider<RecordSettings>(
  (ref) => ref.watch(recordSettingsProvider).value ?? const RecordSettings(),
);

// -------------------------------------------------------------- derived ----

/// A lab test with its classified readings.
@immutable
class LabTestView {
  const LabTestView({required this.test, required this.points, required this.decimals, required this.margin});

  final LabTestRow test;

  /// Oldest first.
  final List<LabPoint> points;

  /// Decimal places for this test's numbers.
  final int decimals;
  final double margin;

  LabRange get range => LabSeries.rangeOf(test);
  LabSummary? get summary => LabSeries.summary(points);
  LabPoint? get latest => points.isEmpty ? null : points.last;
  LabFlag? get latestFlag => latest?.flag;
  bool get hasNumbers => points.any((p) => p.isNumeric);
}

AsyncValue<T> _combine2<A, B, T>(AsyncValue<A> a, AsyncValue<B> b, T Function(A, B) f) {
  if (a.hasError) return AsyncError(a.error!, a.stackTrace ?? StackTrace.current);
  if (b.hasError) return AsyncError(b.error!, b.stackTrace ?? StackTrace.current);
  final av = a.value, bv = b.value;
  if (av == null || bv == null) return const AsyncLoading();
  return AsyncData(f(av, bv));
}

/// Every test with its points, in the user's order.
final labTestViewsProvider = Provider<AsyncValue<List<LabTestView>>>((ref) {
  final margin = ref.watch(recordSettingsValueProvider).borderlineMargin;
  return _combine2(ref.watch(labTestsProvider), ref.watch(labReadingsProvider), (tests, readings) {
    final byTest = LabSeries.byTest(readings);
    return [
      for (final t in tests)
        () {
          final points = LabSeries.points(byTest[t.id] ?? const [], t, margin: margin);
          return LabTestView(test: t, points: points, decimals: LabDecimals.forTest(t, points), margin: margin);
        }(),
    ];
  });
});

/// One test (null once it is deleted).
final labTestViewProvider = Provider.family<AsyncValue<LabTestView?>, String>(
  (ref, id) => ref.watch(labTestViewsProvider).whenData((all) => all.where((v) => v.test.id == id).firstOrNull),
);

/// Tests whose latest reading is out of range or borderline (out of range
/// first).
final flaggedLabTestsProvider = Provider<AsyncValue<List<LabTestView>>>(
  (ref) => ref.watch(labTestViewsProvider).whenData((all) {
    final flagged = [
      for (final v in all)
        if (v.latestFlag?.isFlagged ?? false) v,
    ];
    final order = {for (var i = 0; i < flagged.length; i++) flagged[i].test.id: i};
    flagged.sort((a, b) {
      final c = b.latestFlag!.attention.compareTo(a.latestFlag!.attention);
      return c != 0 ? c : order[a.test.id]!.compareTo(order[b.test.id]!);
    });
    return flagged;
  }),
);

/// Upcoming (soonest first) and past (latest first) appointments.
final appointmentBucketsProvider = Provider<AsyncValue<({List<AppointmentRow> upcoming, List<AppointmentRow> past})>>((
  ref,
) {
  final now = ref.watch(recordClockProvider)();
  ref.watch(recordTodayProvider);
  return ref.watch(appointmentsProvider).whenData((all) => AppointmentTimeline.split(all, now));
});

final nextAppointmentProvider = Provider<AsyncValue<AppointmentRow?>>(
  (ref) => ref.watch(appointmentBucketsProvider).whenData((b) => b.upcoming.firstOrNull),
);

// ----------------------------------------------------------- reminders ----

(L10n, MadarFormatter) recordTextsOf(Ref ref) {
  final settings = ref.read(appSettingsProvider);
  return (lookupL10n(settings.locale), MadarFormatter(languageCode: settings.languageCode, digits: settings.digits));
}

/// The real scheduler: Madar's notification service, the record's id block
/// of the health namespace, channel named in the UI language.
final recordNotificationSchedulerProvider = Provider<AppointmentReminderScheduler>(
  (ref) => NotificationAppointmentReminderScheduler(
    notifications: ref.watch(notificationServiceProvider),
    texts: () {
      final (l, _) = recordTextsOf(ref);
      return (
        group: l.recordReminderGroup,
        name: l.recordReminderChannelName,
        description: l.recordReminderChannelDescription,
      );
    },
  ),
);

/// Delivers appointment reminders; tests override it with
/// [RecordingAppointmentReminderScheduler].
final recordReminderSchedulerProvider = Provider<AppointmentReminderScheduler>(
  (ref) => ref.watch(recordNotificationSchedulerProvider),
);

/// Keeps appointment reminders planned (day before + 2 h before by default,
/// see [RecordSettings.reminderOffsets]) whenever appointments, settings,
/// the language or the day change. Watch it once from the app root; its
/// state is the last plan.
final recordReminderSyncProvider = NotifierProvider<RecordReminderSync, List<AppointmentNotice>?>(
  RecordReminderSync.new,
);

class RecordReminderSync extends Notifier<List<AppointmentNotice>?> {
  static const Duration debounce = Duration(milliseconds: 600);

  Timer? _debounce;
  bool _running = false;
  bool _again = false;

  @override
  List<AppointmentNotice>? build() {
    ref.listen(appointmentsProvider, (_, _) => _schedule());
    ref.listen(recordSettingsProvider, (_, _) => _schedule());
    ref.listen(appSettingsProvider.select((s) => (s.languageCode, s.digits)), (_, _) => _schedule());
    ref.listen(recordTodayProvider, (_, _) => _schedule());
    ref.onDispose(() => _debounce?.cancel());
    _schedule();
    return null;
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(debounce, _run);
  }

  Future<void> _run() async {
    if (_running) {
      _again = true;
      return;
    }
    final appointments = ref.read(appointmentsProvider).value;
    final settings = ref.read(recordSettingsProvider).value;
    if (appointments == null || settings == null) return;
    _running = true;
    try {
      await initializeDateFormatting();
      final scheduler = ref.read(recordReminderSchedulerProvider);
      final reminders = AppointmentReminderPlanner.plan(
        appointments: appointments,
        now: ref.read(recordClockProvider)(),
        offsets: settings.effectiveOffsets,
      );
      final (l, fmt) = recordTextsOf(ref);
      final notices = AppointmentNoticeTexts.build(reminders, {for (final a in appointments) a.id: a}, l, fmt);
      await scheduler.replaceAll(notices);
      state = notices;
    } catch (e) {
      debugPrint('appointment reminders: $e');
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        _schedule();
      }
    }
  }

  /// Plans now (skips the debounce).
  Future<void> syncNow() async {
    _debounce?.cancel();
    await _run();
  }
}

// -------------------------------------------------------------- report ----

final reportFontLoaderProvider = Provider<ReportFontLoader>((ref) => ReportFontLoader());

final doctorReportBuilderProvider = Provider<DoctorReportBuilder>(
  (ref) => DoctorReportBuilder(
    dataSource: DoctorReportDataSource(ref.watch(repositoriesProvider)),
    fonts: ref.watch(reportFontLoaderProvider),
  ),
);

/// Share / save; tests override it with [RecordingReportExporter].
final reportExporterProvider = Provider<ReportExporter>((ref) => const PlatformReportExporter());
