import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../body/domain/body_clock.dart';
import '../../orbit/data/orbit_providers.dart';
import '../domain/food_library.dart';
import '../domain/food_log.dart';
import '../domain/food_rules.dart';
import '../domain/meal_plan.dart';
import '../domain/meal_reminders.dart';
import '../domain/nutrition_insights.dart';
import '../domain/nutrition_summary.dart';
import '../domain/plan_compare.dart';
import '../domain/risk.dart';
import 'nutrition_reminders.dart';
import 'nutrition_service.dart';

// ------------------------------------------------------------- basics ----

/// The Nutrition wall clock (follows the orbit's, so a test freezes them all
/// at once).
final nutritionClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// Today's calendar day (turns at local midnight).
final nutritionTodayProvider = Provider<DateTime>((ref) => ref.watch(orbitTodayProvider));

/// Wall times ↔ instants (tests inject a zone with a DST change).
final nutritionWallClockProvider = Provider<BodyWallClock>((ref) => const LocalBodyWallClock());

/// Logging a meal flares the Body planet through the orbit's pulse hub.
/// Tests may override it with null (plain activity rows).
final nutritionActivityRecorderProvider = Provider<NutritionActivityRecorder?>((ref) {
  final hub = ref.watch(orbitPulseHubProvider);
  return (kind, table, id, {at, value, payload = const {}}) =>
      hub.recordCompletion(NutritionService.planetKey, kind, table, id, at: at, value: value, payload: payload);
});

/// Every write of the package (see [NutritionService]).
final nutritionServiceProvider = Provider<NutritionService>(
  (ref) => NutritionService(
    ref.watch(repositoriesProvider),
    clock: ref.watch(nutritionClockProvider),
    recorder: ref.watch(nutritionActivityRecorderProvider),
  ),
);

// ------------------------------------------------------------ raw rows ----

final nutritionFoodRowsProvider = StreamProvider<List<FoodRow>>(
  (ref) => ref.watch(nutritionServiceProvider).watchFoods(),
);

/// Log entries of the last 400 days (today, the week, the insight window).
final nutritionLogRowsProvider = StreamProvider<List<FoodLogRow>>((ref) {
  final today = ref.watch(nutritionTodayProvider);
  return ref.watch(nutritionServiceProvider).watchLogs(since: DateTime(today.year, today.month, today.day - 400));
});

final nutritionPlanRowsProvider = StreamProvider<List<MealPlanRow>>(
  (ref) => ref.watch(nutritionServiceProvider).watchPlans(),
);

final nutritionSlotRowsProvider = StreamProvider<List<MealSlotRow>>(
  (ref) => ref.watch(nutritionServiceProvider).watchSlots(),
);

final nutritionSlotFoodRowsProvider = StreamProvider<List<MealSlotFoodRow>>(
  (ref) => ref.watch(nutritionServiceProvider).watchSlotFoods(),
);

final nutritionRuleRowsProvider = StreamProvider<List<FoodRuleRow>>(
  (ref) => ref.watch(nutritionServiceProvider).watchRules(),
);

final nutritionConditionRowsProvider = StreamProvider<List<ConditionRow>>(
  (ref) => ref.watch(nutritionServiceProvider).watchConditions(),
);

// ------------------------------------------------------------- models ----

/// The food library in his own order (archived foods included; filter with
/// `Food.archived`).
final nutritionFoodsProvider = Provider<List<Food>>(
  (ref) => [
    for (final r in ref.watch(nutritionFoodRowsProvider).value ?? const <FoodRow>[]) NutritionService.foodOf(r),
  ],
);

/// The food library by id (for resolving an entry's tags).
final nutritionFoodsByIdProvider = Provider<Map<String, Food>>(
  (ref) => {for (final f in ref.watch(nutritionFoodsProvider)) f.id: f},
);

/// Every log entry of the window, newest first.
final nutritionEntriesProvider = Provider<List<FoodEntry>>(
  (ref) => [
    for (final r in ref.watch(nutritionLogRowsProvider).value ?? const <FoodLogRow>[]) NutritionService.entryOf(r),
  ],
);

/// Today's entries, earliest first.
final nutritionTodayEntriesProvider = Provider<List<FoodEntry>>(
  (ref) => FoodLogStats.onDay(
    ref.watch(nutritionEntriesProvider),
    ref.watch(nutritionTodayProvider),
    clock: ref.watch(nutritionWallClockProvider),
  ),
);

/// How often each library food was logged (ties in the lookup).
final nutritionUsageProvider = Provider<Map<String, int>>(
  (ref) => FoodLogStats.useCountById(ref.watch(nutritionEntriesProvider)),
);

/// Fuzzy, Arabic-aware lookup for the quick-entry box. An empty query gives
/// the quick-pick list (favourites and the most logged).
final nutritionFoodSearchProvider = Provider.family<List<FoodMatch>, String>(
  (ref, query) => FoodLookup.search(
    ref.watch(nutritionFoodsProvider),
    query,
    usage: ref.watch(nutritionUsageProvider),
  ),
);

/// "Repeat a frequent meal": the most logged things of the last 30 days.
final nutritionFrequentProvider = Provider<List<FoodUsage>>(
  (ref) => FoodLogStats.mostUsed(
    ref.watch(nutritionEntriesProvider),
    today: ref.watch(nutritionTodayProvider),
    clock: ref.watch(nutritionWallClockProvider),
  ),
);

/// "Log it again": the distinct things eaten most recently.
final nutritionRecentProvider = Provider<List<FoodUsage>>(
  (ref) => FoodLogStats.mostRecent(ref.watch(nutritionEntriesProvider)),
);

/// Every tag he has used, most used first (the tag picker).
final nutritionTagsProvider = Provider<List<String>>(
  (ref) => FoodLookup.tagsOf(ref.watch(nutritionFoodsProvider)),
);

/// Every plan with its slots and planned foods, in his own order.
final nutritionPlansProvider = Provider<List<MealPlan>>(
  (ref) => NutritionService.plansOf(
    ref.watch(nutritionPlanRowsProvider).value ?? const <MealPlanRow>[],
    ref.watch(nutritionSlotRowsProvider).value ?? const <MealSlotRow>[],
    ref.watch(nutritionSlotFoodRowsProvider).value ?? const <MealSlotFoodRow>[],
  ),
);

/// The active plan, or `MealPlan.none` when he has none.
final nutritionActivePlanProvider = Provider<MealPlan>((ref) => MealPlan.activeOf(ref.watch(nutritionPlansProvider)));

/// His chronic conditions, in his own order.
final nutritionConditionsProvider = Provider<List<ConditionRef>>(
  (ref) => [
    for (final r in ref.watch(nutritionConditionRowsProvider).value ?? const <ConditionRow>[])
      NutritionService.conditionOf(r),
  ],
);

/// His own rules, with the matched food's current name resolved.
final nutritionRulesProvider = Provider<List<FoodRule>>((ref) {
  final foods = {
    for (final r in ref.watch(nutritionFoodRowsProvider).value ?? const <FoodRow>[]) r.id: r,
  };
  return [
    for (final r in ref.watch(nutritionRuleRowsProvider).value ?? const <FoodRuleRow>[])
      NutritionService.ruleOf(r, foods: foods),
  ];
});

/// The rules that count right now (switched on and tied to a live
/// condition).
final nutritionLiveRulesProvider = Provider<List<FoodRule>>(
  (ref) => RiskEngine.applicable(ref.watch(nutritionRulesProvider), ref.watch(nutritionConditionsProvider)),
);

/// Whether a rating exists at all: false until he writes his first rule.
final nutritionHasRatingProvider = Provider<bool>((ref) => ref.watch(nutritionLiveRulesProvider).isNotEmpty);

// ---------------------------------------------------------- comparison ----

/// Today's planned vs eaten.
final nutritionTodayPlanProvider = Provider<DayPlan>(
  (ref) => PlanCompare.compare(
    plan: ref.watch(nutritionActivePlanProvider),
    entries: ref.watch(nutritionEntriesProvider),
    day: ref.watch(nutritionTodayProvider),
    now: ref.watch(nutritionClockProvider)(),
    clock: ref.watch(nutritionWallClockProvider),
  ),
);

/// Planned vs eaten for one day (the day view and the week strip).
final nutritionDayPlanProvider = Provider.family<DayPlan, DateTime>(
  (ref, day) => PlanCompare.compare(
    plan: ref.watch(nutritionActivePlanProvider),
    entries: ref.watch(nutritionEntriesProvider),
    day: day,
    now: ref.watch(nutritionClockProvider)(),
    clock: ref.watch(nutritionWallClockProvider),
  ),
);

/// The last seven days' comparison, oldest first.
final nutritionWeekPlanProvider = Provider<List<DayPlan>>(
  (ref) => PlanCompare.lastDays(
    plan: ref.watch(nutritionActivePlanProvider),
    entries: ref.watch(nutritionEntriesProvider),
    today: ref.watch(nutritionTodayProvider),
    now: ref.watch(nutritionClockProvider)(),
    clock: ref.watch(nutritionWallClockProvider),
  ),
);

// --------------------------------------------------------------- risk ----

/// One entry's rating, or **null** when no rule of his applies (show
/// nothing, not a zero).
final nutritionEntryRiskProvider = Provider.family<RiskRating?, FoodEntry>(
  (ref, entry) => RiskEngine.rateEntry(
    entry,
    rules: ref.watch(nutritionRulesProvider),
    conditions: ref.watch(nutritionConditionsProvider),
    food: entry.foodId == null ? null : ref.watch(nutritionFoodsByIdProvider)[entry.foodId],
  ),
);

/// One day's rating, or null when no rule of his applies.
final nutritionDayRiskProvider = Provider.family<DayRisk?, DateTime>(
  (ref, day) => RiskEngine.rateDay(
    day: day,
    entries: FoodLogStats.onDay(
      ref.watch(nutritionEntriesProvider),
      day,
      clock: ref.watch(nutritionWallClockProvider),
    ),
    rules: ref.watch(nutritionRulesProvider),
    conditions: ref.watch(nutritionConditionsProvider),
    foodsById: ref.watch(nutritionFoodsByIdProvider),
  ),
);

/// Today's rating, or null.
final nutritionTodayRiskProvider = Provider<DayRisk?>(
  (ref) => ref.watch(nutritionDayRiskProvider(ref.watch(nutritionTodayProvider))),
);

// ----------------------------------------------------------- insights ----

/// How far his data is from the first observation (the empty state's text).
final nutritionReadinessProvider = Provider<NutritionReadiness>(
  (ref) => NutritionInsights.readiness(
    entries: ref.watch(nutritionEntriesProvider),
    today: ref.watch(nutritionTodayProvider),
    clock: ref.watch(nutritionWallClockProvider),
  ),
);

/// Pain, mood, sleep, water and fasting of the insight window, read from the
/// tables the other planets write.
final nutritionMetricRowsProvider = FutureProvider<NutritionMetrics>((ref) {
  final today = ref.watch(nutritionTodayProvider);
  final from = DateTime(today.year, today.month, today.day - NutritionInsights.windowDays);
  return ref.watch(nutritionServiceProvider).metricsSince(from);
});

/// The observations, or an empty set carrying the readiness when there is
/// not enough data yet. [lateLabel] comes from the UI language.
final nutritionInsightsProvider = Provider.family<NutritionInsightSet, String>((ref, lateLabel) {
  final metrics = ref.watch(nutritionMetricRowsProvider).value;
  if (metrics == null) return NutritionInsightSet(readiness: ref.watch(nutritionReadinessProvider));
  final entries = ref.watch(nutritionEntriesProvider);
  final foods = ref.watch(nutritionFoodsProvider);
  return NutritionInsights.compute(
    entries: entries,
    today: ref.watch(nutritionTodayProvider),
    foodsById: ref.watch(nutritionFoodsByIdProvider),
    pains: metrics.pains,
    moods: metrics.moods,
    waters: metrics.waters,
    fasts: metrics.fasts,
    markerLabels: NutritionInsights.markerLabelsFor(foods: foods, entries: entries, lateLabel: lateLabel),
    clock: ref.watch(nutritionWallClockProvider),
  );
});

// ------------------------------------------------------------ summary ----

/// Everything a card, the daily summary or the planet score needs.
final nutritionSummaryProvider = Provider<NutritionSummary>(
  (ref) => NutritionSummary.build(
    today: ref.watch(nutritionTodayProvider),
    now: ref.watch(nutritionClockProvider)(),
    plan: ref.watch(nutritionActivePlanProvider),
    entries: ref.watch(nutritionEntriesProvider),
    foods: ref.watch(nutritionFoodsProvider),
    ruleCount: ref.watch(nutritionRulesProvider).length,
    risk: ref.watch(nutritionTodayRiskProvider),
    clock: ref.watch(nutritionWallClockProvider),
  ),
);

// ---------------------------------------------------------- reminders ----

(L10n, MadarFormatter) nutritionTextsOf(Ref ref) {
  final settings = ref.read(appSettingsProvider);
  return (lookupL10n(settings.locale), MadarFormatter(languageCode: settings.languageCode, digits: settings.digits));
}

final nutritionNotificationSchedulerProvider = Provider<MealReminderScheduler>(
  (ref) => NotificationMealReminderScheduler(
    notifications: ref.watch(notificationServiceProvider),
    texts: () {
      final (l, _) = nutritionTextsOf(ref);
      return (
        group: l.nutritionNotifyGroup,
        name: l.nutritionNotifyChannel,
        description: l.nutritionNotifyChannelDescription,
      );
    },
    body: (notice) {
      final (l, fmt) = nutritionTextsOf(ref);
      final time = fmt.localizeDigits(notice.timeLabel);
      return notice.foods.isEmpty
          ? l.nutritionNotifyMealBody(time)
          : l.nutritionNotifyMealBodyWithFoods(time, notice.foods.join('، '));
    },
  ),
);

/// Delivers the meal reminders; tests override it with
/// [RecordingMealReminderScheduler].
final nutritionReminderSchedulerProvider = Provider<MealReminderScheduler>(
  (ref) => ref.watch(nutritionNotificationSchedulerProvider),
);

/// Keeps the meal reminders planned whenever the plan, its slots, the
/// language or the day change. Watch it once from the app root (the
/// Nutrition screen watches it too); its state is the last plan.
final nutritionReminderSyncProvider = NotifierProvider<NutritionReminderSync, List<MealNotice>?>(
  NutritionReminderSync.new,
);

class NutritionReminderSync extends Notifier<List<MealNotice>?> {
  static const Duration debounce = Duration(milliseconds: 600);

  Timer? _debounce;
  bool _running = false;
  bool _again = false;

  @override
  List<MealNotice>? build() {
    ref.listen(nutritionActivePlanProvider, (_, _) => _schedule());
    ref.listen(appSettingsProvider.select((s) => (s.languageCode, s.digits)), (_, _) => _schedule());
    ref.listen(nutritionTodayProvider, (_, _) => _schedule());
    ref.onDispose(() => _debounce?.cancel());
    _schedule();
    return null;
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(debounce, _run);
  }

  Future<void> _run() async {
    // Nothing is planned before the plan rows have arrived (an empty plan
    // would cancel reminders that are still wanted).
    if (ref.read(nutritionPlanRowsProvider).value == null || ref.read(nutritionSlotRowsProvider).value == null) {
      return;
    }
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      final notices = MealReminderPlanner.plan(
        plan: ref.read(nutritionActivePlanProvider),
        now: ref.read(nutritionClockProvider)(),
        clock: ref.read(nutritionWallClockProvider),
      );
      await ref.read(nutritionReminderSchedulerProvider).replaceAll(notices);
      // The app may have locked or reset meanwhile (the notifier is gone).
      if (ref.mounted) state = notices;
    } catch (e) {
      debugPrint('meal reminders: $e');
    } finally {
      _running = false;
      if (_again && ref.mounted) {
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
