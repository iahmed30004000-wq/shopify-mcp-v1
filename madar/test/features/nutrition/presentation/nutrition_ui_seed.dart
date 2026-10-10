// Generic sample data for the food-screen tests and screenshots
// (test-only: the app itself starts completely empty, and none of this is
// in the shipped code).
import 'package:drift/drift.dart' show Value;
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/nutrition/nutrition.dart';

enum NutritionSeed {
  /// Foods with his own words on them, an active plan of three meals,
  /// today's and yesterday's entries (every slot status between them), a
  /// month of history, one condition and two rules of his.
  full,

  /// [full] without the condition and the rules – the "no rules, no rating"
  /// case.
  noRules,

  /// The library only: no plan, no log, no rules.
  libraryOnly,

  /// Foods and the plan, nothing logged yet.
  planOnly,

  /// A few days logged and his rules written, but far short of the minimum
  /// the observations need.
  earlyDays,
}

class _Food {
  const _Food(this.ar, this.en, this.tagsAr, this.tagsEn, {this.portion, this.unitAr, this.unitEn, this.favorite = false});

  final String ar;
  final String en;
  final List<String> tagsAr;
  final List<String> tagsEn;
  final double? portion;
  final String? unitAr;
  final String? unitEn;
  final bool favorite;
}

const _eggs = 0, _bread = 1, _coffee = 2, _mansaf = 3, _dates = 4;

const _foods = [
  _Food('بيض مقلي', 'Fried eggs', ['مقلي', 'بروتين'], ['fried', 'protein'], portion: 2, unitAr: 'حبة', unitEn: 'piece'),
  _Food('خبز', 'Bread', ['نشويات'], ['carbs'], portion: 1, unitAr: 'رغيف', unitEn: 'loaf'),
  _Food('قهوة', 'Coffee', ['كافيين'], ['caffeine'], portion: 1, unitAr: 'كوب', unitEn: 'cup'),
  _Food('منسف', 'Mansaf', ['دسم', 'مالح'], ['rich', 'salty'], portion: 1, unitAr: 'صحن', unitEn: 'plate'),
  _Food('تمر', 'Dates', ['حلو'], ['sweet'], portion: 3, unitAr: 'حبة', unitEn: 'piece', favorite: true),
];

Future<void> seedNutrition(MadarDatabase db, NutritionSeed seed, {required DateTime now, bool arabic = true}) async {
  final repos = Repositories(db);
  final service = NutritionService(repos, clock: () => now);
  final today = DateTime(now.year, now.month, now.day);
  DateTime at(int dayOffset, int hour, int minute) =>
      DateTime(today.year, today.month, today.day + dayOffset, hour, minute);

  // ------------------------------------------------------------ library ----
  final foodIds = <String>[];
  for (final f in _foods) {
    final (row, _) = await service.addFood(
      FoodDraft(
        name: arabic ? f.ar : f.en,
        tags: arabic ? f.tagsAr : f.tagsEn,
        defaultPortion: f.portion,
        unit: arabic ? f.unitAr : f.unitEn,
        favorite: f.favorite,
      ),
    );
    foodIds.add(row.id);
  }
  if (seed == NutritionSeed.libraryOnly) return;

  // --------------------------------------------------------------- plan ----
  final (plan, _) = await service.addPlan(
    MealPlanDraft(name: arabic ? 'خطتي' : 'My plan', active: true),
  );
  final (breakfast, _) = await service.addSlot(
    MealSlotDraft(planId: plan.id, name: arabic ? 'فطور' : 'Breakfast', timeMinutes: 8 * 60, remind: true),
  );
  final (lunch, _) = await service.addSlot(
    MealSlotDraft(planId: plan.id, name: arabic ? 'غدا' : 'Lunch', timeMinutes: 13 * 60),
  );
  final (dinner, _) = await service.addSlot(
    MealSlotDraft(planId: plan.id, name: arabic ? 'عشا' : 'Dinner', timeMinutes: 19 * 60),
  );
  Future<void> planFood(MealSlotRow slot, int index) async {
    final f = _foods[index];
    await service.addSlotFood(
      PlannedFoodDraft(
        slotId: slot.id,
        foodId: foodIds[index],
        name: arabic ? f.ar : f.en,
        portion: f.portion,
        unit: arabic ? f.unitAr : f.unitEn,
      ),
    );
  }

  await planFood(breakfast, _eggs);
  await planFood(breakfast, _bread);
  await planFood(lunch, _mansaf);
  await planFood(dinner, _bread);

  // ---------------------------------------------------------- his rules ----
  if (seed != NutritionSeed.noRules) {
    final (condition, _) = await service.addCondition(
      ConditionDraft(
        name: arabic ? 'قولون' : 'Gut',
        notes: arabic ? 'يتعبني بعد الأكل الدسم' : 'Worse after rich food',
        since: DateTime(today.year - 2, 4, 1),
        color: 0xFF7FB3D5,
      ),
    );
    await service.addRule(
      FoodRuleDraft(
        target: FoodRuleTarget.tag,
        tag: arabic ? 'مقلي' : 'fried',
        weight: RiskWeight.high,
        conditionId: condition.id,
        note: arabic ? 'المقلي يوجع قولوني' : 'Fried food hurts my gut',
      ),
    );
    await service.addRule(
      FoodRuleDraft(
        target: FoodRuleTarget.anyFood,
        fromMinutes: 21 * 60,
        toMinutes: 6 * 60,
        weight: RiskWeight.medium,
        conditionId: condition.id,
        note: arabic ? 'الأكل المتأخر يتعبني' : 'Eating late tires me',
      ),
    );
  }
  if (seed == NutritionSeed.planOnly) return;

  // ---------------------------------------------------------- the log ----
  Future<void> log(int dayOffset, int hour, int minute, int index, {String? slotId}) async {
    final f = _foods[index];
    await service.logFood(
      FoodLogDraft(
        foodId: foodIds[index],
        name: arabic ? f.ar : f.en,
        at: at(dayOffset, hour, minute),
        portion: f.portion,
        unit: arabic ? f.unitAr : f.unitEn,
        slotId: slotId,
      ),
    );
  }

  // Today: breakfast on time, lunch late, a coffee off plan, dinner still
  // ahead (the screen's "next meal").
  await log(0, 8, 10, _eggs);
  await log(0, 11, 15, _coffee);
  await log(0, 14, 5, _mansaf);

  // Yesterday: breakfast swapped (dates instead), lunch missed, dinner on
  // time – so every slot status is reachable in a test.
  await log(-1, 8, 5, _dates);
  await log(-1, 19, 10, _bread);

  if (seed == NutritionSeed.earlyDays) {
    // Four days logged in all: short of the ten the observations need.
    await log(-2, 13, 0, _bread);
    await log(-3, 13, 0, _bread);
    return;
  }

  // A month of history, with the fried days late in the evening and a
  // higher pain score on them – enough for the observations to speak.
  for (var d = -30; d <= -2; d++) {
    await log(d, 13, 0, _bread);
    final fried = d % 3 == 0;
    if (fried) await log(d, 21, 30, _eggs);
    await repos.painEntries.insert(
      PainEntriesCompanion.insert(at: at(d, 20, 0), score: fried ? 8 : 3),
    );
    await repos.moodEntries.insert(
      MoodEntriesCompanion.insert(at: at(d, 21, 0), mood: Value(fried ? 2 : 4), sleepHours: Value(fried ? 5 : 7.5)),
    );
  }
}
