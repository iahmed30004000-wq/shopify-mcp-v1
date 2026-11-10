/// «الحفظ» · what the screens of step 2 read (Part 14).
///
/// Thin by design: the engine is pure Dart in `domain/`, the service is the
/// only thing that touches the database, and these providers do nothing but
/// put the two together and keep them live.
///
/// **Everything here degrades.** `tasmeeAvailabilityProvider` answers
/// "there is no speech model in this build" without opening a microphone,
/// so [hifzMethodsProvider] marks «سمّع» unavailable and the written modes
/// ready, and [hifzDailyPlanProvider] plans around it. Nothing throws, no
/// screen is blocked, and the day's plan is still complete.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/settings/app_settings.dart';
import '../../orbit/data/orbit_providers.dart';
import '../../orbit/domain/prayer_schedule.dart';
import '../../recitation/application/recitation_providers.dart';
import '../../recitation/domain/reciters.dart';
import '../../tasmee/tasmee.dart';
import '../../wird/data/wird_providers.dart';
import '../../wird/domain/calendar_days.dart';
import '../domain/hifz_daily_plan.dart';
import '../domain/hifz_goal_reminders.dart';
import '../domain/hifz_goals.dart';
import '../domain/hifz_marks.dart';
import '../domain/hifz_modes.dart';
import '../domain/hifz_page_map.dart';
import '../domain/hifz_progress.dart';
import '../domain/hifz_strength.dart';
import '../domain/mushaf_shape.dart';
import 'hifz_goal_notifications.dart';
import 'hifz_plan_service.dart';
import 'hifz_providers.dart';

/// «الحفظ» follows the same clock as the wird and the Hifz cards, so a
/// test freezes them all at once.
final hifzPlanClockProvider = Provider<DateTime Function()>((ref) => ref.watch(wirdClockProvider));

/// The shape of the mushaf, over the app's own catalogue.
final hifzMushafShapeProvider = FutureProvider<MushafShape>(
  (ref) async => CatalogMushafShape.load(await ref.watch(quranCatalogReadyProvider.future)),
);

/// Every read and write of «الحفظ».
final hifzPlanServiceProvider = FutureProvider<HifzPlanService>(
  (ref) async => HifzPlanService(
    repos: ref.watch(repositoriesProvider),
    tasmee: ref.watch(tasmeeServiceProvider),
    shape: await ref.watch(hifzMushafShapeProvider.future),
    clock: ref.watch(hifzPlanClockProvider),
  ),
);

/// His own plan settings (how much new a day, the caps, the repetitions).
final hifzPlanSettingsProvider = StreamProvider<HifzPlanSettings>((ref) async* {
  final service = await ref.watch(hifzPlanServiceProvider.future);
  yield* service.watchSettings();
});

/// His goals, in his own words and his own order.
final hifzGoalsProvider = StreamProvider<List<HifzGoal>>((ref) async* {
  final service = await ref.watch(hifzPlanServiceProvider.future);
  yield* service.watchGoals();
});

/// The stretches he marked «مش عليّ» or reset.
final hifzMarksProvider = StreamProvider<HifzMarks>((ref) async* {
  final service = await ref.watch(hifzPlanServiceProvider.future);
  yield* service.watchMarks();
});

/// Whether one ayah's audio is on the phone for the chosen reciter – what
/// «اسمع وردّد» degrades on.
final hifzAudioDownloadedProvider = Provider<bool Function(AyahRef ref)>((ref) {
  final downloads = ref.watch(recitationDownloadsProvider);
  ref.watch(recitationDownloadsTickProvider);
  final Reciter reciter = ref.watch(recitationReciterProvider);
  return (ayah) => downloads.statusOf(reciter.id, ayah.surah).isComplete;
});

/// What every mode can do right now.
final hifzMethodsProvider = Provider<List<HifzMethodState>>((ref) {
  final availability = ref.watch(tasmeeAvailabilityProvider).value ??
      const RecogniserAvailability(trouble: RecogniserTrouble.notImplemented);
  return HifzMethods.all(recogniser: availability);
});

/// His inventory: the ayah ranges of his Hifz list, the paused ones left
/// out.
final hifzMemorisedProvider = Provider<AsyncValue<List<AyahRange>>>((ref) {
  final cards = ref.watch(hifzCardsProvider);
  return cards.whenData(
    (list) => [
      for (final c in list)
        if (c.kind == HifzKind.ayat && !c.suspended && c.range != null) c.range!,
    ],
  );
});

/// The strength of every ayah, recomputed from Part 13's log.
final hifzStrengthsProvider = Provider<AsyncValue<HifzStrengths>>((ref) {
  final log = ref.watch(tasmeeLogProvider);
  final marks = ref.watch(hifzMarksProvider);
  final today = ref.watch(wirdTodayProvider);
  if (log.hasError) return AsyncError(log.error!, log.stackTrace ?? StackTrace.current);
  final l = log.value;
  if (l == null) return const AsyncLoading();
  return AsyncData(HifzStrengths.of(l, today: today, marks: marks.value ?? HifzMarks.empty));
});

/// The days he actually turned up – «التسميع» and the Hifz reviews both
/// count.
final hifzActiveDaysProvider = Provider<AsyncValue<Set<DateTime>>>((ref) {
  final log = ref.watch(tasmeeLogProvider);
  final reviews = ref.watch(hifzReviewsProvider);
  final l = log.value, r = reviews.value;
  if (l == null || r == null) return const AsyncLoading();
  return AsyncData({
    for (final s in l)
      if (s.ayat.isNotEmpty) s.day,
    for (final review in r) CalendarDays.dateOnly(review.at),
  });
});

/// Today's plan: a new portion, the near review and the far rotation.
final hifzDailyPlanProvider = Provider<AsyncValue<HifzDailyPlan>>((ref) {
  final shape = ref.watch(hifzMushafShapeProvider);
  final memorised = ref.watch(hifzMemorisedProvider);
  final strengths = ref.watch(hifzStrengthsProvider);
  final settings = ref.watch(hifzPlanSettingsProvider);
  final active = ref.watch(hifzActiveDaysProvider);
  final today = ref.watch(wirdTodayProvider);
  final methods = ref.watch(hifzMethodsProvider);
  if (shape.hasError) return AsyncError(shape.error!, shape.stackTrace ?? StackTrace.current);
  final sh = shape.value, m = memorised.value, st = strengths.value, days = active.value;
  if (sh == null || m == null || st == null || days == null) return const AsyncLoading();
  return AsyncData(
    HifzPlanner.planFor(
      today: today,
      shape: sh,
      memorised: m,
      strengths: st,
      settings: settings.value ?? const HifzPlanSettings(),
      methods: methods,
      activeDays: days,
    ),
  );
});

/// The mushaf coloured by strength (the drawing is step 2).
final hifzPageMapProvider = Provider<AsyncValue<HifzPageMap>>((ref) {
  final shape = ref.watch(hifzMushafShapeProvider);
  final memorised = ref.watch(hifzMemorisedProvider);
  final strengths = ref.watch(hifzStrengthsProvider);
  final sh = shape.value, m = memorised.value, st = strengths.value;
  if (sh == null || m == null || st == null) return const AsyncLoading();
  return AsyncData(HifzPageMap.build(shape: sh, strengths: st, memorised: m));
});

/// Streaks and the heatmap.
final hifzProgressProvider = Provider<AsyncValue<HifzProgress>>((ref) {
  final stats = ref.watch(tasmeeStatsProvider);
  final strengths = ref.watch(hifzStrengthsProvider);
  final map = ref.watch(hifzPageMapProvider);
  final s = stats.value, st = strengths.value, m = map.value;
  if (s == null || st == null || m == null) return const AsyncLoading();
  return AsyncData(HifzProgress.of(stats: s, strengths: st, pageMap: m));
});

/// Where every goal stands today.
final hifzGoalProgressProvider = Provider<AsyncValue<List<HifzGoalProgress>>>((ref) {
  final goals = ref.watch(hifzGoalsProvider);
  final shape = ref.watch(hifzMushafShapeProvider);
  final log = ref.watch(tasmeeLogProvider);
  final today = ref.watch(wirdTodayProvider);
  final g = goals.value, sh = shape.value, l = log.value;
  if (g == null || sh == null || l == null) return const AsyncLoading();
  return AsyncData(HifzGoalProgressReader.all(g, day: today, shape: sh, log: l));
});

/// The words of one range of the verified text – Part 13's own target, so
/// there is only ever one reader of the Quran data.
final hifzTargetProvider = tasmeeTargetProvider;

// ----------------------------------------------------------- reminders ----

/// The UI language's strings and number style (texts built outside the
/// widget tree, exactly as the wird's reminders do it).
(L10n, MadarFormatter) hifzTextsOf(Ref ref) {
  final settings = ref.read(appSettingsProvider);
  return (lookupL10n(settings.locale), MadarFormatter(languageCode: settings.languageCode, digits: settings.digits));
}

/// «بعد الفجر» · «الضحى» … – the prayer a reminder hangs off, in words,
/// reusing the wird's own strings so the two never disagree.
String hifzWindowLabel(L10n l, PrayerWindow? window) => switch (window) {
  null || PrayerWindow.anytime => l.wirdWindowAnytime,
  PrayerWindow.fajr => l.wirdWindowAfter(l.prayerFajr),
  PrayerWindow.duha => l.wirdWindowDuha,
  PrayerWindow.dhuhr => l.wirdWindowAfter(l.prayerDhuhr),
  PrayerWindow.asr => l.wirdWindowAfter(l.prayerAsr),
  PrayerWindow.maghrib => l.wirdWindowAfter(l.prayerMaghrib),
  PrayerWindow.isha => l.wirdWindowAfter(l.prayerIsha),
};

/// The real scheduler: Madar's notification service, «الحفظ»'s own id
/// block, the channel named in the UI language.
final hifzGoalNotificationSchedulerProvider = Provider<HifzGoalScheduler>(
  (ref) => NotificationHifzGoalScheduler(
    notifications: ref.watch(notificationServiceProvider),
    texts: () {
      final (l, _) = hifzTextsOf(ref);
      return (group: l.hifzPlanTitle, name: l.hifzGoalChannelName, description: l.hifzGoalChannelDescription);
    },
  ),
);

/// Delivers the reminders; tests override it with a fake.
final hifzGoalSchedulerProvider = Provider<HifzGoalScheduler>(
  (ref) => ref.watch(hifzGoalNotificationSchedulerProvider),
);

final hifzGoalReminderServiceProvider = Provider<HifzGoalReminderService>(
  (ref) => HifzGoalReminderService(
    scheduler: ref.watch(hifzGoalSchedulerProvider),
    schedule: () => ref.read(prayerScheduleProvider),
    clock: ref.watch(hifzPlanClockProvider),
    texts: () => hifzTextsOf(ref),
  ),
);

/// Plans the goals' reminders off the prayer times and hands them to the
/// [HifzGoalScheduler].
class HifzGoalReminderService {
  HifzGoalReminderService({required this.scheduler, required this.schedule, required this.clock, required this.texts});

  final HifzGoalScheduler scheduler;
  final PrayerSchedule Function() schedule;
  final DateTime Function() clock;
  final (L10n, MadarFormatter) Function() texts;

  Future<bool> ensurePermission() => scheduler.ensurePermission();

  /// Replaces the scheduled reminders with the plan for [goals].
  Future<List<HifzGoalNotice>> reschedule(List<HifzGoalProgress> goals, {int days = 7}) async {
    final s = schedule();
    final reminders = HifzGoalReminderPlanner.plan(goals: goals, timesFor: s.timesFor, now: clock(), days: days);
    if (reminders.isEmpty) {
      await scheduler.cancelAll();
      return const [];
    }
    final (l, _) = texts();
    final notices = [
      for (final r in reminders)
        HifzGoalNotice(
          reminder: r,
          title: l.hifzGoalReminderTitle,
          body: l.hifzGoalReminderBody(r.title, hifzWindowLabel(l, r.window)),
        ),
    ];
    await scheduler.replaceAll(notices);
    return notices;
  }
}

/// Keeps the goals' reminders planned a week ahead: at start and whenever
/// the goals, today's progress, the prayer settings, the language or the
/// day change. Watch it once from the app root; its state is the last
/// plan.
final hifzGoalReminderSyncProvider =
    NotifierProvider<HifzGoalReminderSync, List<HifzGoalNotice>?>(HifzGoalReminderSync.new);

class HifzGoalReminderSync extends Notifier<List<HifzGoalNotice>?> {
  static const Duration debounce = Duration(milliseconds: 600);

  Timer? _debounce;
  bool _running = false;
  bool _again = false;

  @override
  List<HifzGoalNotice>? build() {
    ref.listen(hifzGoalProgressProvider, (_, _) => _schedule());
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
    final goals = ref.read(hifzGoalProgressProvider).value;
    if (goals == null) return;
    _running = true;
    try {
      state = await ref.read(hifzGoalReminderServiceProvider).reschedule(goals);
    } catch (e) {
      debugPrint('hifz goal reminders: $e');
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        _schedule();
      }
    }
  }

  /// Plans now (skips the debounce), e.g. right after he saved a goal.
  Future<void> syncNow() async {
    _debounce?.cancel();
    await _run();
  }
}
