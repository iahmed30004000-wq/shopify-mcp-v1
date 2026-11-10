// The Riverpod wiring of the Nutrition package over a real in-memory
// database: the streams the screens watch, the derived models, the rating and
// the summary, plus one pass of the reminder planner through a recording
// scheduler.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/nutrition/nutrition.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saturday 10 Oct 2026, 13:40.
final _now = DateTime(2026, 10, 10, 13, 40);
final _today = DateTime(2026, 10, 10);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  TestWidgetsFlutterBinding.ensureInitialized();

  late MadarDatabase db;
  late Repositories repos;
  late NutritionService service;
  late ProviderContainer container;
  late RecordingMealReminderScheduler scheduler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = MadarDatabase(NativeDatabase.memory());
    repos = Repositories(db);
    service = NutritionService(repos, clock: () => _now);
    scheduler = RecordingMealReminderScheduler();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        nutritionClockProvider.overrideWithValue(() => _now),
        nutritionTodayProvider.overrideWithValue(_today),
        // Plain activity rows instead of the orbit's pulse hub.
        nutritionActivityRecorderProvider.overrideWithValue(null),
        nutritionReminderSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Keeps the row streams subscribed for the whole test (providers are
  /// auto-dispose, so a bare `read` would drop the subscription at once).
  void keepAlive() {
    for (final p in [
      nutritionFoodRowsProvider,
      nutritionLogRowsProvider,
      nutritionPlanRowsProvider,
      nutritionSlotRowsProvider,
      nutritionSlotFoodRowsProvider,
      nutritionRuleRowsProvider,
      nutritionConditionRowsProvider,
    ]) {
      container.listen(p, (_, _) {});
    }
    container.listen(nutritionMetricRowsProvider, (_, _) {});
  }

  /// Waits for the row streams the derived providers read.
  Future<void> settle() async {
    keepAlive();
    await container.read(nutritionFoodRowsProvider.future);
    await container.read(nutritionLogRowsProvider.future);
    await container.read(nutritionPlanRowsProvider.future);
    await container.read(nutritionSlotRowsProvider.future);
    await container.read(nutritionSlotFoodRowsProvider.future);
    await container.read(nutritionRuleRowsProvider.future);
    await container.read(nutritionConditionRowsProvider.future);
  }

  test('a fresh install: empty lists, no plan, no rating, an empty summary', () async {
    await settle();
    expect(container.read(nutritionFoodsProvider), isEmpty);
    expect(container.read(nutritionEntriesProvider), isEmpty);
    expect(container.read(nutritionPlansProvider), isEmpty);
    expect(container.read(nutritionActivePlanProvider), MealPlan.none);
    expect(container.read(nutritionHasRatingProvider), isFalse);
    expect(container.read(nutritionTodayRiskProvider), isNull);
    final summary = container.read(nutritionSummaryProvider);
    expect(summary.hasPlan, isFalse);
    expect(summary.planetScore, isNull);
    expect(container.read(nutritionReadinessProvider).ready, isFalse);
  });

  test('the library, the log and the quick-entry lists come through the providers', () async {
    final (oats, _) = await service.addFood(const FoodDraft(name: 'شوفان', tags: ['نشويات'], defaultPortion: 1, unit: 'كوب'));
    await service.addFood(const FoodDraft(name: 'بطاطا مقلية', tags: ['مقلي']));
    await service.logFood(FoodLogDraft.of(oats, at: DateTime(2026, 10, 10, 8)));
    await service.logFood(FoodLogDraft(name: 'قهوة', at: DateTime(2026, 10, 10, 9)));
    await settle();

    expect(container.read(nutritionFoodsProvider).map((f) => f.name), ['شوفان', 'بطاطا مقلية']);
    expect(container.read(nutritionFoodsByIdProvider)[oats.id]!.unit, 'كوب');
    expect(container.read(nutritionTodayEntriesProvider).map((e) => e.name), ['شوفان', 'قهوة']);
    expect(container.read(nutritionUsageProvider), {oats.id: 1});
    expect(container.read(nutritionTagsProvider), ['مقلي', 'نشويات'], reason: 'one food each, so alphabetical');
    expect(container.read(nutritionFoodSearchProvider('شوفان')).single.food.id, oats.id);
    expect(container.read(nutritionFoodSearchProvider('بطا')).single.food.name, 'بطاطا مقلية');
    expect(container.read(nutritionRecentProvider).first.name, 'قهوة');
    expect(container.read(nutritionFrequentProvider).map((u) => u.name), containsAll(['شوفان', 'قهوة']));
  });

  test('planned vs eaten and the summary read the active plan', () async {
    final (plan, _) = await service.addPlan(const MealPlanDraft(name: 'خطتي', active: true));
    final (breakfast, _) = await service.addSlot(
      MealSlotDraft(planId: plan.id, name: 'فطور', timeMinutes: 8 * 60, remind: true),
    );
    await service.addSlotFood(PlannedFoodDraft(slotId: breakfast.id, name: 'شوفان'));
    await service.addSlot(MealSlotDraft(planId: plan.id, name: 'عشا', timeMinutes: 19 * 60));
    await service.logFood(FoodLogDraft(name: 'شوفان', at: DateTime(2026, 10, 10, 8, 15)));
    await settle();

    final active = container.read(nutritionActivePlanProvider);
    expect(active.id, plan.id);
    expect(active.ordered.map((s) => s.name), ['فطور', 'عشا']);

    final today = container.read(nutritionTodayPlanProvider);
    expect(today.onTime, 1);
    expect(today.pending, 1, reason: 'dinner is still ahead at 13:40');
    expect(today.adherence, 1);

    final summary = container.read(nutritionSummaryProvider);
    expect(summary.hasPlan, isTrue);
    expect(summary.entryCountToday, 1);
    expect(summary.nextMeal!.slot.name, 'عشا');
    expect(summary.streakDays, 1);

    expect(container.read(nutritionWeekPlanProvider), hasLength(7));
    expect(container.read(nutritionDayPlanProvider(DateTime(2026, 10, 9))).skipped, 2);
  });

  test('a rating appears only once he has written a rule, with his words', () async {
    final (condition, _) = await service.addCondition(const ConditionDraft(name: 'المعدة'));
    final (food, _) = await service.addFood(const FoodDraft(name: 'فلافل', tags: ['مقلي']));
    await service.logFood(FoodLogDraft.of(food, at: DateTime(2026, 10, 10, 8)));
    await settle();
    expect(container.read(nutritionHasRatingProvider), isFalse);
    expect(container.read(nutritionTodayRiskProvider), isNull);
    final entry = container.read(nutritionTodayEntriesProvider).single;
    expect(container.read(nutritionEntryRiskProvider(entry)), isNull);

    await service.addRule(
      FoodRuleDraft(
        target: FoodRuleTarget.tag,
        tag: 'مقلي',
        conditionId: condition.id,
        weight: RiskWeight.high,
        note: 'علّمت المقلي كخطر على معدتي',
      ),
    );
    await settle();
    expect(container.read(nutritionHasRatingProvider), isTrue);
    expect(container.read(nutritionLiveRulesProvider).single.foodName, isNull);
    final rating = container.read(nutritionEntryRiskProvider(entry))!;
    expect(rating.score, 3);
    expect(rating.reasons.single.note, 'علّمت المقلي كخطر على معدتي');
    expect(rating.reasons.single.conditionName, 'المعدة');

    final day = container.read(nutritionTodayRiskProvider)!;
    expect(day.score, 3);
    expect(day.perEntry[entry.id]!.score, 3);
    expect(container.read(nutritionSummaryProvider).level, RiskLevel.low);
  });

  test('a food rule carries the food\'s current name into its reason', () async {
    final (coffee, _) = await service.addFood(const FoodDraft(name: 'قهوة'));
    await service.addRule(FoodRuleDraft(target: FoodRuleTarget.food, foodId: coffee.id, weight: RiskWeight.low));
    await settle();
    expect(container.read(nutritionRulesProvider).single.foodName, 'قهوة');
    await service.updateFood(coffee, const FoodDraft(name: 'قهوة تركية'));
    await settle();
    expect(container.read(nutritionRulesProvider).single.foodName, 'قهوة تركية');
  });

  test('the insights stay silent until there is enough data, then read the other planets', () async {
    for (var i = 0; i < 12; i++) {
      final day = DateTime(2026, 10, 10 - i);
      await service.logFood(
        FoodLogDraft(name: 'أكل', at: DateTime(day.year, day.month, day.day, 13), tags: i.isEven ? ['مقلي'] : const []),
      );
      await repos.painEntries.insert(
        PainEntriesCompanion.insert(at: DateTime(day.year, day.month, day.day, 21), score: i.isEven ? 8 : 2),
      );
    }
    await settle();
    await container.read(nutritionMetricRowsProvider.future);
    final set = container.read(nutritionInsightsProvider('أكل متأخر'));
    expect(set.readiness.ready, isTrue);
    expect(set.readiness.daysLogged, 12);
    final mean = set.means.firstWhere((m) => m.metric == NutritionMetric.pain);
    expect(mean.marker.label, 'مقلي');
    expect(mean.daysWith, 6);
    expect(mean.meanWith, 8);
    expect(mean.meanWithout, 2);
  });

  test('the reminder sync plans the active plan\'s reminding slots and cancels when they are off', () async {
    final (plan, _) = await service.addPlan(const MealPlanDraft(name: 'خطتي', active: true));
    final (slot, _) = await service.addSlot(
      MealSlotDraft(planId: plan.id, name: 'عشا', timeMinutes: 19 * 60, remind: true),
    );
    await settle();
    container.read(nutritionReminderSyncProvider);
    await container.read(nutritionReminderSyncProvider.notifier).syncNow();
    expect(scheduler.current, isNotEmpty);
    expect(scheduler.current.first.slotName, 'عشا');
    expect(scheduler.current.first.at, DateTime(2026, 10, 10, 19));
    expect(scheduler.current.every((n) => MealReminderIds.owns(n.id)), isTrue);

    await service.setSlotRemind(slot, false);
    await settle();
    await container.read(nutritionReminderSyncProvider.notifier).syncNow();
    expect(scheduler.current, isEmpty);
  });

  test('logging through the service records the meal on the Body planet', () async {
    await settle();
    final (row, _) = await service.logFood(FoodLogDraft(name: 'منسف', at: _now));
    final activity = await repos.activity.since(DateTime(2026, 10, 1));
    expect(activity.single.planetKey, 'body');
    expect(activity.single.kind, 'nutrition.meal');
    expect(activity.single.refId, row.id);
  });
}
