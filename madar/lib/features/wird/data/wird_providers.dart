import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/quran/quran_catalog.dart';
import '../../../core/settings/app_settings.dart';
import '../../orbit/data/orbit_providers.dart';
import '../../orbit/domain/prayer_schedule.dart';
import '../domain/quran_axis.dart';
import '../domain/wird_engine.dart';
import '../domain/wird_plan.dart';
import '../domain/wird_reminders.dart';
import '../presentation/wird_labels.dart';
import 'wird_notifications.dart';
import 'wird_service.dart';

// ------------------------------------------------------------- basics ----

/// The wird's wall clock (follows the orbit's, so tests freeze both).
final wirdClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// Today's calendar day (turns at local midnight).
final wirdTodayProvider = Provider<DateTime>((ref) => ref.watch(orbitTodayProvider));

/// The Quran catalog once its structure has loaded (shared with Hifz).
final quranCatalogReadyProvider = FutureProvider<QuranCatalog>((ref) async {
  final catalog = ref.watch(quranCatalogProvider);
  await catalog.ensureLoaded();
  return catalog;
});

/// Ayah index and page / juz / hizb / ayat axes of the loaded catalog.
class WirdAxes {
  WirdAxes(this.catalog) : index = QuranIndex(catalog);

  final QuranCatalog catalog;
  final QuranIndex index;
  final Map<WirdUnit, QuranAxis> _axes = {};

  QuranAxis of(WirdUnit unit) => _axes[unit] ??= QuranAxis.of(catalog, unit, index: index);

  QuranAxis get pages => of(WirdUnit.pages);
}

final wirdAxesProvider = FutureProvider<WirdAxes>(
  (ref) async => WirdAxes(await ref.watch(quranCatalogReadyProvider.future)),
);

/// Where "read now" goes: the app routes it to the Quran reader at
/// [WirdReadRequest.start]. Null (the default) hides the button unless the
/// widget is given its own callback.
typedef WirdReadNow = void Function(BuildContext context, WirdReadRequest request);

/// What the reader should open.
@immutable
class WirdReadRequest {
  const WirdReadRequest({required this.planId, required this.start, this.range});

  final String planId;

  /// First ayah to show (where the plan stands).
  final AyahRef start;

  /// Today's remaining portion (null when nothing is owed).
  final AyahRange? range;
}

final wirdReadNowProvider = Provider<WirdReadNow?>((ref) => null);

// ------------------------------------------------------------- service ----

/// The activity recorder (through the orbit's pulse hub, so the Faith
/// world pulses at once).
final wirdActivityRecorderProvider = Provider<WirdActivityRecorder>((ref) {
  final hub = ref.watch(orbitPulseHubProvider);
  return ({required kind, required refTable, required refId, required at, value, payload = const {}}) =>
      hub.recordCompletion(WirdActivity.planetKey, kind, refTable, refId, at: at, value: value, payload: payload);
});

final wirdServiceProvider = Provider<WirdService>(
  (ref) => WirdService(
    ref.watch(repositoriesProvider),
    clock: ref.watch(wirdClockProvider),
    recorder: ref.watch(wirdActivityRecorderProvider),
  ),
);

final wirdPlanRowsProvider = StreamProvider<List<WirdPlanRow>>((ref) => ref.watch(wirdServiceProvider).watchRows());

final wirdMetaProvider = StreamProvider<Map<String, WirdPlanMeta>>((ref) => ref.watch(wirdServiceProvider).watchMeta());

final wirdPrimaryIdProvider = StreamProvider<String?>((ref) => ref.watch(wirdServiceProvider).watchPrimaryId());

final wirdSessionsProvider = StreamProvider<List<WirdSession>>((ref) => ref.watch(wirdServiceProvider).watchSessions());

/// All plans in their order.
final wirdPlansProvider = Provider<AsyncValue<List<WirdPlan>>>((ref) {
  final rows = ref.watch(wirdPlanRowsProvider);
  final meta = ref.watch(wirdMetaProvider);
  if (rows.hasError) return AsyncError(rows.error!, rows.stackTrace ?? StackTrace.current);
  final r = rows.value, m = meta.value;
  if (r == null || m == null) return const AsyncLoading();
  return AsyncData([for (final row in r) WirdPlan.fromRow(row, m[row.id] ?? const WirdPlanMeta())]);
});

/// Every plan's state today (plans in their order).
final wirdStatesProvider = Provider<AsyncValue<List<WirdPlanState>>>((ref) {
  final plans = ref.watch(wirdPlansProvider);
  final sessions = ref.watch(wirdSessionsProvider);
  final axes = ref.watch(wirdAxesProvider);
  final today = ref.watch(wirdTodayProvider);
  for (final a in [plans, sessions, axes]) {
    if (a.hasError) return AsyncError(a.error!, a.stackTrace ?? StackTrace.current);
  }
  final p = plans.value, s = sessions.value, x = axes.value;
  if (p == null || s == null || x == null) return const AsyncLoading();
  return AsyncData([
    for (final plan in p) WirdEngine.compute(plan: plan, sessions: s, axis: x.of(plan.unit), today: today),
  ]);
});

/// The primary plan's state (null when there are no plans).
final wirdPrimaryStateProvider = Provider<AsyncValue<WirdPlanState?>>((ref) {
  final states = ref.watch(wirdStatesProvider);
  final primaryId = ref.watch(wirdPrimaryIdProvider).value;
  return states.whenData((list) {
    final primary = WirdService.primaryOf([for (final s in list) s.plan], primaryId);
    if (primary == null) return null;
    return list.firstWhere((s) => s.plan.id == primary.id);
  });
});

/// Logs `quran.wird` when a plan's portion for today is read – however it
/// was read (the reader's sessions or "mark done") – and removes the entry
/// again when it is undone. Watch it once from the app root (the wird
/// screen and card watch it too).
final wirdCompletionSyncProvider = Provider<void>((ref) {
  final service = ref.watch(wirdServiceProvider);
  var pending = Future<void>.value();
  ref.listen<AsyncValue<List<WirdPlanState>>>(wirdStatesProvider, (_, next) {
    final states = next.value;
    if (states == null) return;
    pending = pending
        .then((_) async {
          for (final s in states) {
            await service.syncCompletion(s);
          }
        })
        .catchError((Object e, StackTrace st) => debugPrint('wird completion sync failed: $e'));
  }, fireImmediately: true);
});

// ----------------------------------------------------------- reminders ----

/// The UI language's strings and number style (texts built outside the
/// widget tree).
(L10n, MadarFormatter) wirdTextsOf(Ref ref) {
  final settings = ref.read(appSettingsProvider);
  return (lookupL10n(settings.locale), MadarFormatter(languageCode: settings.languageCode, digits: settings.digits));
}

/// The real scheduler: Madar's notification service, wird id block,
/// channel named in the UI language.
final wirdNotificationSchedulerProvider = Provider<WirdReminderScheduler>(
  (ref) => NotificationWirdReminderScheduler(
    notifications: ref.watch(notificationServiceProvider),
    texts: () {
      final (l, _) = wirdTextsOf(ref);
      return (group: l.wirdTitle, name: l.wirdReminderChannelName, description: l.wirdReminderChannelDescription);
    },
  ),
);

/// Delivers the reminders; tests override it with a fake.
final wirdReminderSchedulerProvider = Provider<WirdReminderScheduler>(
  (ref) => ref.watch(wirdNotificationSchedulerProvider),
);

final wirdReminderServiceProvider = Provider<WirdReminderService>(
  (ref) => WirdReminderService(
    scheduler: ref.watch(wirdReminderSchedulerProvider),
    schedule: () => ref.read(prayerScheduleProvider),
    clock: ref.watch(wirdClockProvider),
    texts: () => wirdTextsOf(ref),
  ),
);

/// Plans the wird reminders from the prayer times and hands them to the
/// [WirdReminderScheduler].
class WirdReminderService {
  WirdReminderService({required this.scheduler, required this.schedule, required this.clock, required this.texts});

  final WirdReminderScheduler scheduler;
  final PrayerSchedule Function() schedule;
  final DateTime Function() clock;
  final (L10n, MadarFormatter) Function() texts;

  Future<bool> ensurePermission() => scheduler.ensurePermission();

  /// Replaces the scheduled reminders with the plan for [states] (none when
  /// no plan asks for one).
  Future<List<WirdReminderNotice>> reschedule(List<WirdPlanState> states, {QuranCatalog? catalog, int days = 7}) async {
    final s = schedule();
    final reminders = WirdReminderPlanner.plan(states: states, timesFor: s.timesFor, now: clock(), days: days);
    if (reminders.isEmpty) {
      await scheduler.cancelAll();
      return const [];
    }
    final (l, fmt) = texts();
    final byId = {for (final st in states) st.plan.id: st};
    final notices = <WirdReminderNotice>[];
    for (final r in reminders) {
      final range = byId[r.planId]?.target.remaining;
      final body = r.today && range != null && catalog != null
          ? l.wirdReminderBodyToday(r.planName, WirdTexts(l, fmt, catalog).range(range))
          : l.wirdReminderBody(r.planName, wirdWindowLabel(l, r.window));
      notices.add(WirdReminderNotice(reminder: r, title: l.wirdReminderTitle, body: body));
    }
    await scheduler.replaceAll(notices);
    return notices;
  }
}

/// Keeps the wird reminders planned a week ahead: at start and whenever the
/// plans, today's progress, the prayer settings, the language or the day
/// change. Watch it once from the app root; its state is the last plan.
final wirdReminderSyncProvider = NotifierProvider<WirdReminderSync, List<WirdReminderNotice>?>(WirdReminderSync.new);

class WirdReminderSync extends Notifier<List<WirdReminderNotice>?> {
  static const Duration debounce = Duration(milliseconds: 600);

  Timer? _debounce;
  bool _running = false;
  bool _again = false;

  @override
  List<WirdReminderNotice>? build() {
    ref.listen(wirdStatesProvider, (_, _) => _schedule());
    ref.listen(prayerSettingsProvider, (_, _) => _schedule());
    ref.listen(appSettingsProvider.select((s) => (s.languageCode, s.digits)), (_, _) => _schedule());
    ref.listen(wirdTodayProvider, (_, _) => _schedule());
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
    final states = ref.read(wirdStatesProvider).value;
    if (states == null) return;
    _running = true;
    try {
      final catalog = ref.read(quranCatalogReadyProvider).value;
      state = await ref.read(wirdReminderServiceProvider).reschedule(states, catalog: catalog);
    } catch (e) {
      debugPrint('wird reminders: $e');
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        _schedule();
      }
    }
  }

  /// Plans now (skips the debounce), e.g. after the user saved a plan.
  Future<void> syncNow() async {
    _debounce?.cancel();
    await _run();
  }
}
