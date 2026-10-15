import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/notifications/notification_models.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../home/home_providers.dart' show homeClockProvider, homeNowProvider;
import '../../../orbit/data/orbit_providers.dart' show orbitTodayProvider, prayerScheduleProvider;
import '../domain/dose_scheduler.dart';
import '../domain/dose_tracker.dart';
import '../domain/med_models.dart';
import '../domain/meds_planner.dart';
import '../domain/meds_settings.dart';
import '../meds_texts.dart';
import 'meds_background.dart';
import 'meds_notifications.dart';
import 'meds_prayer_times.dart';
import 'meds_service.dart';

/// Days of history the screens read (adherence 30 days + today).
const int medsHistoryDays = 31;

final medsServiceProvider = Provider<MedsService>(
  (ref) => MedsService(ref.watch(repositoriesProvider), clock: ref.watch(homeClockProvider)),
);

final medsSettingsProvider = StreamProvider<MedsSettings>((ref) => ref.watch(medsServiceProvider).watchSettings());

/// Every medication (active and paused), in the user's order.
final medsListProvider = StreamProvider<List<MedSpec>>((ref) => ref.watch(medsServiceProvider).watchMeds());

final medCoursesProvider = StreamProvider<List<CourseSpec>>((ref) => ref.watch(medsServiceProvider).watchCourses());

final medRulesProvider = StreamProvider<List<RuleSpec>>((ref) => ref.watch(medsServiceProvider).watchRules());

/// The health record's pinned standing alerts (read-only here).
final medsStandingAlertsProvider = StreamProvider<List<HealthAlertRow>>(
  (ref) => ref.watch(medsServiceProvider).watchAlerts(),
);

/// Today's calendar day (turns at local midnight).
final medsTodayDateProvider = Provider<DateTime>((ref) => ref.watch(orbitTodayProvider));

/// The dose log of the last [medsHistoryDays] days.
final medLogsProvider = StreamProvider<List<DoseLog>>((ref) {
  final today = ref.watch(medsTodayDateProvider);
  return ref.watch(medsServiceProvider).watchLogs(MedDays.add(today, -medsHistoryDays));
});

/// Prayer anchors resolved against the user's prayer schedule.
final medsPrayerTimeProvider = Provider<PrayerTimeOf>((ref) => prayerTimeOf(ref.watch(prayerScheduleProvider)));

/// The prayer window an instant falls in (for grouping doses).
final medsWindowOfProvider = Provider<PrayerWindow Function(DateTime at)>((ref) {
  final schedule = ref.watch(prayerScheduleProvider);
  return (at) {
    try {
      return schedule.windowAt(at).window;
    } catch (_) {
      return PrayerWindow.anytime;
    }
  };
});

/// The scheduler over the current data (null while loading).
final medsSchedulerProvider = Provider<DoseScheduler?>((ref) {
  final meds = ref.watch(medsListProvider).value;
  final courses = ref.watch(medCoursesProvider).value;
  final rules = ref.watch(medRulesProvider).value;
  final settings = ref.watch(medsSettingsProvider).value;
  if (meds == null || courses == null || rules == null || settings == null) return null;
  return DoseScheduler(
    meds: meds,
    courses: courses,
    rules: rules,
    settings: settings,
    prayerTime: ref.watch(medsPrayerTimeProvider),
  );
});

/// "Now" for dose states (ticks every minute while watched).
final medsNowProvider = Provider.autoDispose<DateTime>((ref) => ref.watch(homeNowProvider));

/// Everything the Today view shows.
@immutable
class MedsToday {
  const MedsToday({
    required this.day,
    required this.now,
    required this.doses,
    required this.conflicts,
    required this.refills,
    required this.asNeeded,
    required this.week,
    required this.meds,
  });

  final DateTime day;
  final DateTime now;

  /// Today's doses, tracked, by time.
  final List<TrackedDose> doses;
  final List<DoseConflict> conflicts;

  /// Active medications at or under their refill threshold.
  final List<MedSpec> refills;

  /// Active medications without times (logged by hand).
  final List<MedSpec> asNeeded;

  /// Adherence of the last seven days (today last).
  final AdherenceSummary week;
  final List<MedSpec> meds;

  int get total => doses.length;
  int get answered => doses.where((d) => d.state.done).length;
  int get taken => doses.where((d) => d.state == DoseState.taken).length;
  List<TrackedDose> get dueNow => MedsPlanner.dueNow(doses);
  TrackedDose? get next => MedsPlanner.next(doses);
  bool get hasMeds => meds.isNotEmpty;
}

final medsTodayProvider = Provider.autoDispose<MedsToday?>((ref) {
  final scheduler = ref.watch(medsSchedulerProvider);
  final logs = ref.watch(medLogsProvider).value;
  final meds = ref.watch(medsListProvider).value;
  if (scheduler == null || logs == null || meds == null) return null;
  final day = ref.watch(medsTodayDateProvider);
  final now = ref.watch(medsNowProvider);
  final week = MedsPlanner.period(scheduler, from: MedDays.add(day, -6), count: 7, logs: logs, now: now);
  final today = week.on(day);
  final active = meds.where((m) => m.active).toList();
  return MedsToday(
    day: day,
    now: now,
    doses: today,
    conflicts: week.plans.last.conflicts,
    refills: [for (final m in active) if (m.needsRefill) m],
    asNeeded: [for (final m in active) if (m.asNeeded && scheduler.coursesOf(m).isEmpty) m],
    week: DoseTracker.adherence(week.plans, logs, now, scheduler.settings),
    meds: meds,
  );
});

/// Doses waiting for an answer right now (due or late), oldest first – for
/// the Health hub, the home screen and a future home widget.
final medsDueNowProvider = Provider.autoDispose<List<TrackedDose>>(
  (ref) => ref.watch(medsTodayProvider)?.dueNow ?? const [],
);

/// Adherence over the last [days] days (today included).
final medsAdherenceProvider = Provider.autoDispose.family<AdherenceSummary?, int>((ref, days) {
  final scheduler = ref.watch(medsSchedulerProvider);
  final logs = ref.watch(medLogsProvider).value;
  if (scheduler == null || logs == null) return null;
  final day = ref.watch(medsTodayDateProvider);
  final now = ref.watch(medsNowProvider);
  final n = days.clamp(1, medsHistoryDays);
  final plans = scheduler.planDays(MedDays.add(day, -(n - 1)), n);
  return DoseTracker.adherence(plans, logs, now, scheduler.settings);
});

/// One medication's recent history.
@immutable
class MedHistory {
  const MedHistory({required this.med, required this.adherence, required this.doses, required this.offSchedule});

  final MedSpec med;

  /// The last 30 days.
  final AdherenceSummary adherence;

  /// Its planned doses up to now, newest first.
  final List<TrackedDose> doses;

  /// Doses logged outside the plan, newest first.
  final List<DoseLog> offSchedule;
}

final medHistoryProvider = Provider.autoDispose.family<MedHistory?, String>((ref, medId) {
  final scheduler = ref.watch(medsSchedulerProvider);
  final logs = ref.watch(medLogsProvider).value;
  final meds = ref.watch(medsListProvider).value;
  if (scheduler == null || logs == null || meds == null) return null;
  final med = meds.where((m) => m.id == medId).firstOrNull;
  if (med == null) return null;
  final day = ref.watch(medsTodayDateProvider);
  final now = ref.watch(medsNowProvider);
  const n = 30;
  final mine = [for (final l in logs) if (l.medId == medId) l];
  final period = MedsPlanner.period(scheduler, from: MedDays.add(day, -(n - 1)), count: n, logs: mine, now: now);
  final doses = [
    for (final t in period.tracked)
      if (t.dose.medId == medId && t.state != DoseState.upcoming) t,
  ]..sort((a, b) => b.dose.at.compareTo(a.dose.at));
  final matched = DoseTracker.match([for (final t in period.tracked) t.dose], mine).values.map((l) => l.id).toSet();
  final off = [
    for (final l in mine)
      if (l.slot == null && l.status == DoseStatus.taken && !matched.contains(l.id)) l,
  ]..sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));
  return MedHistory(
    med: med,
    adherence: DoseTracker.adherence(period.plans, mine, now, scheduler.settings, medId: medId),
    doses: doses,
    offSchedule: off,
  );
});

/// Texts for notifications, in the app's language and digit style.
final medsNotificationTextsProvider = Provider<MedsTexts>((ref) {
  final (language, digits) = ref.watch(appSettingsProvider.select((s) => (s.languageCode, s.digits)));
  return MedsTexts.forLanguage(language, digits: digits);
});

/// Keeps the next 48 hours of dose reminders scheduled: on every change of
/// medications, courses, rules, the dose log, the settings, the prayer
/// schedule or the language, at start, at midnight and every six hours
/// while the app runs (the plan is rolling).
final medsReminderSyncProvider = NotifierProvider<MedsReminderSync, NotificationSyncReport?>(MedsReminderSync.new);

class MedsReminderSync extends Notifier<NotificationSyncReport?> {
  static const Duration debounce = Duration(milliseconds: 700);
  static const Duration refreshEvery = Duration(hours: 6);

  Timer? _debounce;
  Timer? _periodic;
  bool _running = false;
  bool _again = false;
  MedsReminderEngine? _engine;

  MedsReminderEngine get engine => _engine ??= MedsReminderEngine(
    service: ref.read(medsServiceProvider),
    notifications: ref.read(notificationServiceProvider),
    texts: ref.read(medsNotificationTextsProvider),
    prayerTime: ref.read(medsPrayerTimeProvider),
    clock: ref.read(homeClockProvider),
  );

  @override
  NotificationSyncReport? build() {
    void changed() {
      _engine = null;
      _schedule();
    }

    ref.listen(medsListProvider, (_, _) => _schedule());
    ref.listen(medCoursesProvider, (_, _) => _schedule());
    ref.listen(medRulesProvider, (_, _) => _schedule());
    ref.listen(medLogsProvider, (_, _) => _schedule());
    ref.listen(medsSettingsProvider, (_, _) => _schedule());
    ref.listen(medsTodayDateProvider, (_, _) => _schedule());
    ref.listen(medsPrayerTimeProvider, (_, _) => changed());
    ref.listen(medsNotificationTextsProvider, (_, _) => changed());
    ref.listen(medsServiceProvider, (_, _) => changed());
    _periodic = Timer.periodic(refreshEvery, (_) => _schedule());
    ref.onDispose(() {
      _debounce?.cancel();
      _periodic?.cancel();
    });
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
    _running = true;
    try {
      final report = await engine.resync();
      if (ref.mounted) state = report;
    } catch (e) {
      debugPrint('meds reminders: $e');
    } finally {
      _running = false;
      if (_again && ref.mounted) {
        _again = false;
        _schedule();
      }
    }
  }

  /// Re-plans now (tests, app start).
  Future<void> syncNow() async {
    _debounce?.cancel();
    await _run();
  }

  /// After an answer in the app: removes the dose's shown notification
  /// ([doseKey] null for a dose logged outside the plan) and posts the refill
  /// alert when the stock reached its threshold.
  Future<void> afterAnswer(String? doseKey, String medId, DoseActionResult result) async {
    try {
      if (doseKey != null) await engine.dismiss(doseKey);
      await engine.refillIfNeeded(medId, result);
    } catch (e) {
      debugPrint('meds: after-answer notification work failed: $e');
    }
  }
}

/// The app's side of the dose notifications while it runs: answers given
/// with the notification buttons (forwarded by the background handler, or
/// delivered to the app directly) are recorded here, and the refill alert
/// follows. Watch it once from the app's services (below the database gate).
final medsNotificationBridgeProvider = Provider<MedsNotificationBridge>((ref) {
  final bridge = MedsNotificationBridge(ref);
  ref.onDispose(bridge.dispose);
  return bridge;
});

class MedsNotificationBridge {
  MedsNotificationBridge(this._ref) {
    _receiver = MedsActionReceiver(record)..open();
    _taps = _ref.read(notificationServiceProvider).taps.listen(_onTap);
  }

  final Ref _ref;
  late final MedsActionReceiver _receiver;
  late final StreamSubscription<NotificationTap> _taps;

  void _onTap(NotificationTap tap) {
    final action = MedsNotificationTaps.actionOf(tap, now: _ref.read(homeClockProvider)());
    if (action != null) unawaited(record(action));
  }

  /// Records [action]; true when it is in the database.
  Future<bool> record(MedDoseAction action) async {
    if (!_ref.mounted) return false;
    try {
      final result = await _ref.read(medsServiceProvider).apply(action);
      if (_ref.mounted && result.changed) {
        await _ref
            .read(medsReminderSyncProvider.notifier)
            .afterAnswer(PlannedDose.doseKey(action.medId, action.slot), action.medId, result);
      }
      return true;
    } catch (e) {
      debugPrint('meds: recording a notification answer failed: $e');
      return false;
    }
  }

  void dispose() {
    _receiver.close();
    unawaited(_taps.cancel());
  }
}
