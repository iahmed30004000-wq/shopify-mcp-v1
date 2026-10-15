import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/nutrition/nutrition.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late MadarDatabase db;
  late Repositories repos;
  late NutritionService service;
  final now = DateTime(2026, 10, 10, 13);

  setUp(() {
    db = MadarDatabase(NativeDatabase.memory());
    repos = Repositories(db);
    service = NutritionService(repos, clock: () => now);
  });

  tearDown(() => db.close());

  group('a fresh database', () {
    test('starts completely empty: no foods, no plan, no rules, no conditions', () async {
      expect(await repos.foods.count(), 0);
      expect(await repos.foodLogs.count(), 0);
      expect(await repos.mealPlans.count(), 0);
      expect(await repos.mealSlots.count(), 0);
      expect(await repos.foodRules.count(), 0);
      expect(await repos.conditions.count(), 0);
    });
  });

  group('the food library', () {
    test('a food is trimmed, de-duplicated and reusable; undo removes it', () async {
      final (row, undo) = await service.addFood(
        const FoodDraft(
          name: '  فلافل  ',
          tags: ['مقلي', ' مقلي ', '  '],
          defaultPortion: 3,
          unit: ' حبة ',
          notes: '  ',
        ),
      );
      expect(row.name, 'فلافل');
      expect(row.tags, ['مقلي']);
      expect(row.defaultPortion, 3);
      expect(row.unit, 'حبة');
      expect(row.notes, isNull);
      expect(row.favorite, isFalse);

      await undo();
      expect(await repos.foods.count(), 0);
    });

    test('a non-positive portion is dropped rather than stored', () async {
      final (row, _) = await service.addFood(const FoodDraft(name: 'شاي', defaultPortion: 0));
      expect(row.defaultPortion, isNull);
    });

    test('favourite, archive and edit all undo to the exact prior state', () async {
      final (row, _) = await service.addFood(const FoodDraft(name: 'كنافة', tags: ['حلو']));
      final undoFavorite = await service.setFoodFavorite(row, true);
      expect((await service.food(row.id))!.favorite, isTrue);
      await undoFavorite();
      expect((await service.food(row.id))!.favorite, isFalse);

      final undoArchive = await service.setFoodArchived(row, true);
      expect((await service.food(row.id))!.archived, isTrue);
      await undoArchive();
      expect((await service.food(row.id))!.archived, isFalse);

      final undoEdit = await service.updateFood(row, const FoodDraft(name: 'كنافة ناعمة', tags: ['حلو', 'مكسرات']));
      expect((await service.food(row.id))!.name, 'كنافة ناعمة');
      await undoEdit();
      final back = (await service.food(row.id))!;
      expect(back.name, 'كنافة');
      expect(back.tags, ['حلو']);
    });

    test('deleting a food leaves its log entries with their own name', () async {
      final (food, _) = await service.addFood(const FoodDraft(name: 'فلافل'));
      final (log, _) = await service.logFood(FoodLogDraft.of(food, at: now));
      final undo = await service.deleteFood(food);
      final kept = (await repos.foodLogs.byId(log.id))!;
      expect(kept.name, 'فلافل');
      expect(kept.foodId, food.id, reason: 'the link stays, it simply resolves to nothing');
      await undo();
      expect(await repos.foods.count(), 1);
    });

    test('the lookup works over the rows as stored', () async {
      await service.addFood(const FoodDraft(name: 'بندورة', tags: ['خضار']));
      await service.addFood(const FoodDraft(name: 'بطاطا مقلية', tags: ['مقلي']));
      final foods = [for (final r in await repos.foods.getAll()) NutritionService.foodOf(r)];
      expect(FoodLookup.search(foods, 'بندوره').single.food.name, 'بندورة');
    });
  });

  group('the food log', () {
    test('logging records the meal on the planet, and the undo takes both back', () async {
      final (row, undo) = await service.logFood(
        FoodLogDraft(name: 'منسف', at: now, portion: 1, unit: 'طبق', note: 'بيت خالي'),
      );
      expect(row.name, 'منسف');
      final activity = await repos.activity.since(DateTime(2026, 10, 1));
      expect(activity.single.kind, NutritionService.kindMeal);
      expect(activity.single.planetKey, NutritionService.planetKey);
      expect(activity.single.refId, row.id);

      await undo();
      expect(await repos.foodLogs.count(), 0);
      expect(await repos.activity.since(DateTime(2026, 10, 1)), isEmpty);
    });

    test('deleting a logged meal removes its activity and the undo restores it', () async {
      final (row, _) = await service.logFood(FoodLogDraft(name: 'فلافل', at: now));
      final undo = await service.deleteLog(row);
      expect(await repos.foodLogs.count(), 0);
      expect(await repos.activity.since(DateTime(2026, 10, 1)), isEmpty);
      await undo();
      expect(await repos.foodLogs.count(), 1);
      expect(await repos.activity.since(DateTime(2026, 10, 1)), hasLength(1));
    });

    test('logAgain repeats a frequent meal with the food\'s current portion', () async {
      final (food, _) = await service.addFood(const FoodDraft(name: 'شوفان', defaultPortion: 1.5, unit: 'كوب'));
      await service.logFood(FoodLogDraft.of(food, at: DateTime(2026, 10, 9, 8)));
      final entries = [for (final r in await repos.foodLogs.getAll()) NutritionService.entryOf(r)];
      final usage = FoodLogStats.mostUsed(entries, today: DateTime(2026, 10, 10)).single;

      final (again, _) = await service.logAgain(usage);
      expect(again.foodId, food.id);
      expect(again.portion, 1.5);
      expect(again.unit, 'كوب');
      expect(again.at, now);

      // A free-text repeat works even though no food row exists.
      final (text, _) = await service.logFood(FoodLogDraft(name: 'قهوة', at: now));
      final textUsage = FoodLogStats.mostRecent([NutritionService.entryOf(text)]).single;
      final (textAgain, _) = await service.logAgain(textUsage);
      expect(textAgain.foodId, isNull);
      expect(textAgain.name, 'قهوة');
    });

    test('an entry can be tied to a slot and untied again', () async {
      final (row, _) = await service.logFood(FoodLogDraft(name: 'شوفان', at: now));
      final undo = await service.setLogSlot(row, 'slot-1');
      expect((await repos.foodLogs.byId(row.id))!.slotId, 'slot-1');
      await undo();
      expect((await repos.foodLogs.byId(row.id))!.slotId, isNull);
    });

    test('only entries of the window are watched', () async {
      await service.logFood(FoodLogDraft(name: 'قديم', at: DateTime(2026, 1, 1, 8)));
      await service.logFood(FoodLogDraft(name: 'جديد', at: now));
      final rows = await service.watchLogs(since: DateTime(2026, 10, 1)).first;
      expect(rows.map((r) => r.name), ['جديد']);
    });
  });

  group('the meal plan', () {
    Future<MealPlanRow> plan(String name, {bool active = false}) async {
      final (row, _) = await service.addPlan(MealPlanDraft(name: name, active: active));
      return row;
    }

    test('only one plan is active at a time, and undo restores which one it was', () async {
      final a = await plan('خطة الصيف', active: true);
      final b = await plan('خطة رمضان');
      expect((await repos.mealPlans.byId(a.id))!.active, isTrue);

      final undo = await service.setPlanActive(b, true);
      expect((await repos.mealPlans.byId(a.id))!.active, isFalse);
      expect((await repos.mealPlans.byId(b.id))!.active, isTrue);

      await undo();
      expect((await repos.mealPlans.byId(a.id))!.active, isTrue);
      expect((await repos.mealPlans.byId(b.id))!.active, isFalse);
    });

    test('slots keep only real weekdays and a time inside the day', () async {
      final p = await plan('خطتي');
      final (slot, _) = await service.addSlot(
        MealSlotDraft(planId: p.id, name: ' فطور ', timeMinutes: 8 * 60, weekdays: [0, 3, 1, 9, 7, 3]),
      );
      expect(slot.name, 'فطور');
      expect(slot.weekdays, [1, 3, 7]);

      final (late, _) = await service.addSlot(MealSlotDraft(planId: p.id, name: 'بعد نص الليل', timeMinutes: 5000));
      expect(late.timeMinutes, 24 * 60 - 1);
    });

    test('deleting a slot takes its planned foods and brings them all back', () async {
      final p = await plan('خطتي');
      final (slot, _) = await service.addSlot(MealSlotDraft(planId: p.id, name: 'فطور', timeMinutes: 480));
      await service.addSlotFood(PlannedFoodDraft(slotId: slot.id, name: 'شوفان', portion: 1, unit: 'كوب'));
      await service.addSlotFood(PlannedFoodDraft(slotId: slot.id, name: 'بيض'));
      final undo = await service.deleteSlot(slot);
      expect(await repos.mealSlots.count(), 0);
      expect(await repos.mealSlotFoods.count(), 0);
      await undo();
      expect(await repos.mealSlots.count(), 1);
      expect(await repos.mealSlotFoods.count(), 2);
    });

    test('deleting a plan takes its slots and foods, and the undo restores everything', () async {
      final p = await plan('خطتي', active: true);
      final (slot, _) = await service.addSlot(MealSlotDraft(planId: p.id, name: 'فطور', timeMinutes: 480));
      await service.addSlotFood(PlannedFoodDraft(slotId: slot.id, name: 'شوفان'));
      final undo = await service.deletePlan(p);
      expect(await repos.mealPlans.count(), 0);
      expect(await repos.mealSlots.count(), 0);
      expect(await repos.mealSlotFoods.count(), 0);
      await undo();
      expect(await repos.mealPlans.count(), 1);
      expect(await repos.mealSlots.count(), 1);
      expect(await repos.mealSlotFoods.count(), 1);
    });

    test('duplicating a plan deep-copies it as a draft', () async {
      final p = await plan('خطة رمضان', active: true);
      final (slot, _) = await service.addSlot(
        MealSlotDraft(planId: p.id, name: 'سحور', timeMinutes: 4 * 60, weekdays: [1, 2], remind: true),
      );
      await service.addSlotFood(PlannedFoodDraft(slotId: slot.id, name: 'لبنة', portion: 1));

      final (copy, undo) = await service.duplicatePlan(p, name: 'خطة رمضان – تجربة');
      expect(copy.active, isFalse);
      final plans = NutritionService.plansOf(
        await repos.mealPlans.getAll(),
        await repos.mealSlots.getAll(),
        await repos.mealSlotFoods.getAll(),
      );
      final copied = plans.firstWhere((x) => x.id == copy.id);
      expect(copied.name, 'خطة رمضان – تجربة');
      expect(copied.slots.single.name, 'سحور');
      expect(copied.slots.single.weekdays, [1, 2]);
      expect(copied.slots.single.remind, isTrue);
      expect(copied.slots.single.foods.single.name, 'لبنة');
      // The original is untouched.
      expect(plans.firstWhere((x) => x.id == p.id).slots.single.foods, hasLength(1));

      await undo();
      expect(await repos.mealPlans.count(), 1);
      expect(await repos.mealSlots.count(), 1);
      expect(await repos.mealSlotFoods.count(), 1);
    });

    test('plansOf assembles plans, slots and planned foods in the user\'s order', () async {
      final p = await plan('خطتي', active: true);
      final (dinner, _) = await service.addSlot(MealSlotDraft(planId: p.id, name: 'عشا', timeMinutes: 19 * 60));
      final (breakfast, _) = await service.addSlot(MealSlotDraft(planId: p.id, name: 'فطور', timeMinutes: 8 * 60));
      await service.addSlotFood(PlannedFoodDraft(slotId: dinner.id, name: 'لبنة'));
      await service.addSlotFood(PlannedFoodDraft(slotId: breakfast.id, name: 'شوفان'));

      final plans = NutritionService.plansOf(
        await repos.mealPlans.getAll(),
        await repos.mealSlots.getAll(),
        await repos.mealSlotFoods.getAll(),
      );
      final active = MealPlan.activeOf(plans);
      expect(active.id, p.id);
      // Stored in his order, read earliest-meal first.
      expect(active.slots.map((s) => s.name), ['عشا', 'فطور']);
      expect(active.ordered.map((s) => s.name), ['فطور', 'عشا']);
      expect(active.ordered.first.foods.single.name, 'شوفان');
    });

    test('logSlotAsPlanned logs every planned food against the slot, with one undo', () async {
      final p = await plan('خطتي', active: true);
      final (slot, _) = await service.addSlot(MealSlotDraft(planId: p.id, name: 'فطور', timeMinutes: 480));
      final (food, _) = await service.addFood(const FoodDraft(name: 'شوفان', defaultPortion: 1, unit: 'كوب'));
      await service.addSlotFood(
        PlannedFoodDraft(slotId: slot.id, foodId: food.id, name: 'شوفان', portion: 1, unit: 'كوب'),
      );
      await service.addSlotFood(PlannedFoodDraft(slotId: slot.id, name: 'بيض'));

      final (rows, undo) = await service.logSlotAsPlanned(slot, at: DateTime(2026, 10, 10, 8, 5));
      expect(rows, hasLength(2));
      expect(rows.every((r) => r.slotId == slot.id), isTrue);
      expect(rows.first.portion, 1);
      expect(await repos.activity.since(DateTime(2026, 10, 1)), hasLength(2));

      await undo();
      expect(await repos.foodLogs.count(), 0);
      expect(await repos.activity.since(DateTime(2026, 10, 1)), isEmpty);
    });

    test('planned vs eaten runs over the stored rows end to end', () async {
      final p = await plan('خطتي', active: true);
      final (breakfast, _) = await service.addSlot(MealSlotDraft(planId: p.id, name: 'فطور', timeMinutes: 8 * 60));
      await service.addSlotFood(PlannedFoodDraft(slotId: breakfast.id, name: 'شوفان'));
      final (lunch, _) = await service.addSlot(MealSlotDraft(planId: p.id, name: 'غدا', timeMinutes: 13 * 60));
      await service.addSlotFood(PlannedFoodDraft(slotId: lunch.id, name: 'دجاج'));
      await service.logFood(FoodLogDraft(name: 'شوفان', at: DateTime(2026, 10, 10, 8, 20)));
      await service.logFood(FoodLogDraft(name: 'منسف', at: DateTime(2026, 10, 10, 13, 10)));

      final plans = NutritionService.plansOf(
        await repos.mealPlans.getAll(),
        await repos.mealSlots.getAll(),
        await repos.mealSlotFoods.getAll(),
      );
      final entries = [for (final r in await repos.foodLogs.getAll()) NutritionService.entryOf(r)];
      final day = PlanCompare.compare(
        plan: MealPlan.activeOf(plans),
        entries: entries,
        day: DateTime(2026, 10, 10),
        now: DateTime(2026, 10, 10, 23),
      );
      expect(day.onTime, 1);
      expect(day.swapped, 1);
      expect(day.adherence, 0.5);
    });
  });

  group('his conditions and his rules', () {
    test('a condition is stored with his colour and note, and undo restores it', () async {
      final (row, undo) = await service.addCondition(
        ConditionDraft(name: 'الضغط', notes: 'من ٢٠٢٠', since: DateTime(2020, 1, 1), color: 0xFF112233),
      );
      expect(row.name, 'الضغط');
      expect(row.color, 0xFF112233);
      expect(row.since, DateTime(2020, 1, 1));
      expect(row.active, isTrue);
      await undo();
      expect(await repos.conditions.count(), 0);
    });

    test('a rule keeps only the fields of its own kind', () async {
      final (food, _) = await service.addFood(const FoodDraft(name: 'قهوة'));
      final (tagRule, _) = await service.addRule(
        FoodRuleDraft(
          target: FoodRuleTarget.tag,
          tag: ' ملح عالي ',
          foodId: food.id,
          weight: RiskWeight.high,
          note: 'الملح يرفع ضغطي',
        ),
      );
      expect(tagRule.tag, 'ملح عالي');
      expect(tagRule.foodId, isNull, reason: 'a tag rule stores no food');
      expect(tagRule.weight, RiskWeight.high);

      final (foodRule, _) = await service.addRule(
        FoodRuleDraft(target: FoodRuleTarget.food, foodId: food.id, tag: 'ملح عالي'),
      );
      expect(foodRule.foodId, food.id);
      expect(foodRule.tag, isNull);
      expect(foodRule.weight, RiskWeight.medium);
      expect(foodRule.active, isTrue);
    });

    test('a rule can be switched off and on again, and deleted with undo', () async {
      final (rule, _) = await service.addRule(const FoodRuleDraft(target: FoodRuleTarget.tag, tag: 'مقلي'));
      final undoOff = await service.setRuleActive(rule, false);
      expect((await repos.foodRules.byId(rule.id))!.active, isFalse);
      await undoOff();
      expect((await repos.foodRules.byId(rule.id))!.active, isTrue);

      final undoDelete = await service.deleteRule(rule);
      expect(await repos.foodRules.count(), 0);
      await undoDelete();
      expect(await repos.foodRules.count(), 1);
    });

    test('the rating runs end to end over the stored rows, with his words as the reason', () async {
      final (condition, _) = await service.addCondition(const ConditionDraft(name: 'المعدة'));
      final (food, _) = await service.addFood(const FoodDraft(name: 'بطاطا مقلية', tags: ['مقلي']));
      await service.addRule(
        FoodRuleDraft(
          target: FoodRuleTarget.tag,
          tag: 'مقلي',
          conditionId: condition.id,
          weight: RiskWeight.high,
          note: 'علّمت المقلي كخطر على معدتي',
        ),
      );
      final (log, _) = await service.logFood(FoodLogDraft.of(food, at: now));

      final foodRows = {for (final r in await repos.foods.getAll()) r.id: r};
      final rules = [for (final r in await repos.foodRules.getAll()) NutritionService.ruleOf(r, foods: foodRows)];
      final conditions = [for (final r in await repos.conditions.getAll()) NutritionService.conditionOf(r)];
      final rating = RiskEngine.rateEntry(
        NutritionService.entryOf(log),
        rules: rules,
        conditions: conditions,
        food: NutritionService.foodOf(food),
      )!;
      expect(rating.score, 3);
      expect(rating.reasons.single.note, 'علّمت المقلي كخطر على معدتي');
      expect(rating.reasons.single.conditionName, 'المعدة');

      // Turning the condition off removes the rating altogether.
      await service.setConditionActive(condition, false);
      final off = [for (final r in await repos.conditions.getAll()) NutritionService.conditionOf(r)];
      expect(RiskEngine.rateEntry(NutritionService.entryOf(log), rules: rules, conditions: off), isNull);
    });

    test('a deleted condition leaves his rule on disk but silent', () async {
      final (condition, _) = await service.addCondition(const ConditionDraft(name: 'المعدة'));
      await service.addRule(FoodRuleDraft(target: FoodRuleTarget.tag, tag: 'مقلي', conditionId: condition.id));
      await service.deleteCondition(condition);
      final rules = [for (final r in await repos.foodRules.getAll()) NutritionService.ruleOf(r)];
      expect(rules, hasLength(1));
      expect(RiskEngine.applicable(rules, const []), isEmpty);
    });
  });

  group('the insight samples', () {
    test('metricsSince reads pain, mood, water and fasts of the window only', () async {
      await repos.painEntries.insert(PainEntriesCompanion.insert(at: DateTime(2026, 10, 9, 21), score: 7));
      await repos.painEntries.insert(PainEntriesCompanion.insert(at: DateTime(2025, 1, 1, 21), score: 2));
      await repos.moodEntries.insert(
        MoodEntriesCompanion.insert(at: DateTime(2026, 10, 9, 22), mood: const Value(4), sleepHours: const Value(6.5)),
      );
      await repos.waterLogs.insert(WaterLogsCompanion.insert(at: DateTime(2026, 10, 9, 12), ml: 500));
      await repos.fastingSessions.insert(
        FastingSessionsCompanion.insert(
          start: DateTime(2026, 10, 9, 2),
          end: Value(DateTime(2026, 10, 9, 18)),
          targetHours: 16,
        ),
      );

      final metrics = await service.metricsSince(DateTime(2026, 10, 1));
      expect(metrics.pains.single.score, 7);
      expect(metrics.moods.single.sleepHours, 6.5);
      expect(metrics.waters.single.ml, 500);
      expect(metrics.fasts.single.end, DateTime(2026, 10, 9, 18));
    });
  });
}
