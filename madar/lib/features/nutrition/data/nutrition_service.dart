import 'dart:async';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../domain/food_library.dart';
import '../domain/food_log.dart';
import '../domain/food_rules.dart';
import '../domain/meal_plan.dart';
import '../domain/nutrition_insights.dart';

/// Reverses one change (the UI wraps it in an undo toast), exactly like the
/// Body and Health services.
typedef NutritionUndo = Future<void> Function();

/// Logs a completion on the planet Nutrition lives on (the Body planet). The
/// default writes an `activity_log` row; the app routes it through the
/// orbit's pulse hub so the planet flares at once.
typedef NutritionActivityRecorder =
    Future<void> Function(
      String kind,
      String? refTable,
      String? refId, {
      DateTime? at,
      double? value,
      Map<String, Object?> payload,
    });

/// A new or edited food of the library.
class FoodDraft {
  const FoodDraft({
    required this.name,
    this.notes,
    this.tags = const [],
    this.defaultPortion,
    this.unit,
    this.favorite = false,
    this.archived = false,
  });

  final String name;
  final String? notes;
  final List<String> tags;
  final double? defaultPortion;
  final String? unit;
  final bool favorite;
  final bool archived;
}

/// A new or edited log entry.
class FoodLogDraft {
  const FoodLogDraft({
    required this.name,
    required this.at,
    this.foodId,
    this.portion,
    this.unit,
    this.tags = const [],
    this.note,
    this.slotId,
  });

  /// Straight from a library food: its name, default portion and unit.
  factory FoodLogDraft.of(FoodRow food, {required DateTime at, double? portion, String? note, String? slotId}) =>
      FoodLogDraft(
        foodId: food.id,
        name: food.name,
        at: at,
        portion: portion ?? food.defaultPortion,
        unit: food.unit,
        note: note,
        slotId: slotId,
      );

  final String? foodId;
  final String name;
  final DateTime at;
  final double? portion;
  final String? unit;
  final List<String> tags;
  final String? note;
  final String? slotId;
}

/// A new or edited meal plan (its slots are edited on their own).
class MealPlanDraft {
  const MealPlanDraft({required this.name, this.notes, this.active = false});

  final String name;
  final String? notes;
  final bool active;
}

/// A new or edited slot of a plan.
class MealSlotDraft {
  const MealSlotDraft({
    required this.planId,
    required this.name,
    required this.timeMinutes,
    this.weekdays = const [],
    this.remind = false,
    this.notes,
  });

  final String planId;
  final String name;

  /// Minutes after local midnight (08:00 → 480).
  final int timeMinutes;

  /// `DateTime.weekday` values (1‥7); empty means every day.
  final List<int> weekdays;
  final bool remind;
  final String? notes;
}

/// A food planned inside a slot.
class PlannedFoodDraft {
  const PlannedFoodDraft({required this.slotId, required this.name, this.foodId, this.portion, this.unit});

  final String slotId;
  final String? foodId;
  final String name;
  final double? portion;
  final String? unit;
}

/// A rule the user writes himself.
class FoodRuleDraft {
  const FoodRuleDraft({
    required this.target,
    this.weight = RiskWeight.medium,
    this.conditionId,
    this.foodId,
    this.tag,
    this.minPortion,
    this.fromMinutes,
    this.toMinutes,
    this.maxPerDay,
    this.note,
    this.active = true,
  });

  final String? conditionId;
  final FoodRuleTarget target;
  final String? foodId;
  final String? tag;
  final double? minPortion;
  final int? fromMinutes;
  final int? toMinutes;
  final int? maxPerDay;
  final RiskWeight weight;
  final String? note;
  final bool active;
}

/// A new or edited chronic condition (the existing Health table, extended
/// with a colour in schema v3 – Nutrition never duplicates it).
class ConditionDraft {
  const ConditionDraft({required this.name, this.notes, this.since, this.active = true, this.color});

  final String name;
  final String? notes;
  final DateTime? since;
  final bool active;
  final int? color;
}

String? _clean(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

double? _positive(double? v) => v == null || v <= 0 ? null : v;

int? _minute(int? v) => v?.clamp(0, 24 * 60 - 1);

List<String> _tags(Iterable<String> tags) {
  final out = <String>[];
  for (final tag in tags) {
    final t = tag.trim();
    if (t.isNotEmpty && !out.contains(t)) out.add(t);
  }
  return out;
}

List<int> _weekdays(Iterable<int> days) => ({
  for (final d in days)
    if (d >= 1 && d <= 7) d,
}.toList()..sort());

/// Every write of the Nutrition package: the food library, the food log, the
/// meal plan with its slots and planned foods, the user's own food rules and
/// his chronic conditions.
///
/// Each write returns a [NutritionUndo] that restores the exact prior state
/// (deleting a plan or a slot restores its children too). Logging a meal is
/// recorded on the Body planet, so the orbit and the Neglect Radar react.
///
/// Nothing in here computes a rating: that is the pure `RiskEngine`.
class NutritionService {
  NutritionService(this.repos, {DateTime Function()? clock, this.recorder}) : clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() clock;

  /// Null: completions are written straight to `activity_log`.
  final NutritionActivityRecorder? recorder;

  /// Nutrition sits on the Body planet (beside fasting and water).
  static const String planetKey = 'body';

  /// `activity_log.kind` of a logged meal.
  static const String kindMeal = 'nutrition.meal';

  MadarDatabase get _db => repos.db;

  Future<void> _record(
    String kind,
    String table,
    String id, {
    DateTime? at,
    double? value,
    Map<String, Object?> payload = const {},
  }) {
    final r = recorder;
    if (r != null) return r(kind, table, id, at: at, value: value, payload: payload);
    return repos.activity.log(
      planetKey: planetKey,
      kind: kind,
      refTable: table,
      refId: id,
      at: at ?? clock(),
      value: value,
      payload: payload,
    );
  }

  Future<List<ActivityRow>> _unrecord(String table, String id, [String? kind]) =>
      repos.activity.removeFor(refTable: table, refId: id, kind: kind);

  // ---------------------------------------------------------- food library ----

  /// The library in the user's own order.
  Stream<List<FoodRow>> watchFoods() => repos.foods.watchAll();

  Future<FoodRow?> food(String id) => repos.foods.byId(id);

  FoodsCompanion _food(FoodDraft d) => FoodsCompanion(
    name: Value(d.name.trim()),
    notes: Value(_clean(d.notes)),
    tags: Value(_tags(d.tags)),
    defaultPortion: Value(_positive(d.defaultPortion)),
    unit: Value(_clean(d.unit)),
    favorite: Value(d.favorite),
    archived: Value(d.archived),
  );

  Future<(FoodRow, NutritionUndo)> addFood(FoodDraft d) async {
    final row = await repos.foods.insert(_food(d));
    return (row, () async => repos.foods.delete(row.id).then((_) {}));
  }

  Future<NutritionUndo> updateFood(FoodRow row, FoodDraft d) async {
    await repos.foods.update(_food(d).copyWith(id: Value(row.id)));
    return () => repos.foods.update(row);
  }

  Future<(FoodRow, NutritionUndo)> duplicateFood(FoodRow row, {String? name}) async {
    final copy = await repos.foods.duplicate(row.id, overrides: {'name': ?name});
    return (copy, () async => repos.foods.delete(copy.id).then((_) {}));
  }

  Future<NutritionUndo> setFoodFavorite(FoodRow row, bool favorite) async {
    await repos.foods.setColumn(row.id, 'favorite', favorite);
    return () => repos.foods.setColumn(row.id, 'favorite', row.favorite);
  }

  /// Archives a food instead of deleting it: old log entries keep their name
  /// and the picker stops offering it.
  Future<NutritionUndo> setFoodArchived(FoodRow row, bool archived) async {
    await repos.foods.setColumn(row.id, 'archived', archived);
    return () => repos.foods.setColumn(row.id, 'archived', row.archived);
  }

  /// Deletes a food. Its log entries stay (they carry their own name) and
  /// simply lose the link; rules that pointed at it stop matching it.
  Future<NutritionUndo> deleteFood(FoodRow row) async {
    final gone = await repos.foods.delete(row.id);
    return () async {
      if (gone != null) await repos.foods.restore(gone);
    };
  }

  Future<void> reorderFoods(List<String> ids) => repos.foods.reorder(ids);

  // -------------------------------------------------------------- food log ----

  /// Log entries at or after [since] (all when null), newest first.
  Stream<List<FoodLogRow>> watchLogs({DateTime? since}) {
    final q = _db.select(_db.foodLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.at), (t) => OrderingTerm.desc(t.createdAt)]);
    if (since != null) q.where((t) => t.at.isBiggerOrEqualValue(since));
    return q.watch();
  }

  FoodLogsCompanion _log(FoodLogDraft d) => FoodLogsCompanion(
    foodId: Value(d.foodId),
    name: Value(d.name.trim()),
    at: Value(d.at),
    portion: Value(_positive(d.portion)),
    unit: Value(_clean(d.unit)),
    tags: Value(_tags(d.tags)),
    note: Value(_clean(d.note)),
    slotId: Value(d.slotId),
  );

  /// Logs something eaten and records it on the planet.
  Future<(FoodLogRow, NutritionUndo)> logFood(FoodLogDraft d) async {
    final row = await repos.foodLogs.insert(
      FoodLogsCompanion.insert(
        foodId: Value(d.foodId),
        name: d.name.trim(),
        at: d.at,
        portion: Value(_positive(d.portion)),
        unit: Value(_clean(d.unit)),
        tags: Value(_tags(d.tags)),
        note: Value(_clean(d.note)),
        slotId: Value(d.slotId),
      ),
    );
    await _record(
      kindMeal,
      'food_logs',
      row.id,
      at: row.at,
      value: row.portion,
      payload: {'foodId': ?row.foodId, 'name': row.name, 'slotId': ?row.slotId},
    );
    return (
      row,
      () async {
        await repos.foodLogs.delete(row.id);
        await _unrecord('food_logs', row.id, kindMeal);
      },
    );
  }

  /// "I ate that again": logs [usage] (from `FoodLogStats.mostUsed` /
  /// `mostRecent`) at [at], with the library food's current portion when it
  /// still exists.
  Future<(FoodLogRow, NutritionUndo)> logAgain(FoodUsage usage, {DateTime? at, String? slotId}) async {
    final when = at ?? clock();
    final row = await (usage.foodId == null ? Future<FoodRow?>.value() : repos.foods.byId(usage.foodId!));
    if (row == null) {
      return logFood(FoodLogDraft(name: usage.name, at: when, slotId: slotId));
    }
    return logFood(FoodLogDraft.of(row, at: when, slotId: slotId));
  }

  Future<NutritionUndo> updateLog(FoodLogRow row, FoodLogDraft d) async {
    await repos.foodLogs.update(_log(d).copyWith(id: Value(row.id)));
    return () => repos.foodLogs.update(row);
  }

  /// Ties an entry to a meal-plan slot (or clears the tie with null).
  Future<NutritionUndo> setLogSlot(FoodLogRow row, String? slotId) async {
    await repos.foodLogs.setColumn(row.id, 'slot_id', slotId);
    return () => repos.foodLogs.setColumn(row.id, 'slot_id', row.slotId);
  }

  Future<NutritionUndo> deleteLog(FoodLogRow row) async {
    final gone = await repos.foodLogs.delete(row.id);
    final activity = await _unrecord('food_logs', row.id);
    return () async {
      if (gone != null) await repos.foodLogs.restore(gone);
      await repos.activityLog.restoreAll(activity);
    };
  }

  // ------------------------------------------------------------- meal plan ----

  Stream<List<MealPlanRow>> watchPlans() => repos.mealPlans.watchAll();

  Stream<List<MealSlotRow>> watchSlots() => repos.mealSlots.watchAll();

  Stream<List<MealSlotFoodRow>> watchSlotFoods() => repos.mealSlotFoods.watchAll();

  Future<(MealPlanRow, NutritionUndo)> addPlan(MealPlanDraft d) async {
    final row = await repos.mealPlans.insert(
      MealPlansCompanion(name: Value(d.name.trim()), notes: Value(_clean(d.notes)), active: Value(d.active)),
    );
    if (d.active) await _deactivateOthers(row.id);
    return (row, () async => repos.mealPlans.delete(row.id).then((_) {}));
  }

  Future<NutritionUndo> updatePlan(MealPlanRow row, MealPlanDraft d) async {
    await repos.mealPlans.update(
      MealPlansCompanion(
        id: Value(row.id),
        name: Value(d.name.trim()),
        notes: Value(_clean(d.notes)),
        active: Value(d.active),
      ),
    );
    if (d.active) await _deactivateOthers(row.id);
    return () => repos.mealPlans.update(row);
  }

  /// Makes [row] the active plan (a draft becomes the plan today is compared
  /// against) or, with [active] false, turns it back into a draft. Exactly
  /// one plan is ever active.
  Future<NutritionUndo> setPlanActive(MealPlanRow row, bool active) async {
    final before = await repos.mealPlans.getAll();
    await repos.mealPlans.setColumn(row.id, 'active', active);
    if (active) await _deactivateOthers(row.id);
    return () async {
      for (final p in before) {
        await repos.mealPlans.setColumn(p.id, 'active', p.active);
      }
    };
  }

  Future<void> _deactivateOthers(String keepId) async {
    final others = await repos.mealPlans.getAll(where: (t) => t.active.equals(true) & t.id.equals(keepId).not());
    for (final p in others) {
      await repos.mealPlans.setColumn(p.id, 'active', false);
    }
  }

  /// Deletes a plan with its slots and their planned foods; the undo brings
  /// all of it back. Log entries that pointed at a deleted slot keep their
  /// `slotId` (harmless: the comparison ignores unknown slots).
  Future<NutritionUndo> deletePlan(MealPlanRow row) async {
    final slots = await repos.mealSlots.getAll(where: (t) => t.planId.equals(row.id));
    final ids = [for (final s in slots) s.id];
    final foods = <MealSlotFoodRow>[];
    for (final id in ids) {
      foods.addAll(await repos.mealSlotFoods.deleteWhere((t) => t.slotId.equals(id)));
    }
    final goneSlots = await repos.mealSlots.deleteWhere((t) => t.planId.equals(row.id));
    final gone = await repos.mealPlans.delete(row.id);
    return () async {
      if (gone != null) await repos.mealPlans.restore(gone);
      await repos.mealSlots.restoreAll(goneSlots);
      await repos.mealSlotFoods.restoreAll(foods);
    };
  }

  /// Copies a plan with all its slots and planned foods, as a draft (so he
  /// can try a change without losing what works).
  Future<(MealPlanRow, NutritionUndo)> duplicatePlan(MealPlanRow row, {String? name}) async {
    final copy = await repos.mealPlans.insert(
      MealPlansCompanion(name: Value(name?.trim() ?? row.name), notes: Value(row.notes), active: const Value(false)),
    );
    final slots = await repos.mealSlots.getAll(where: (t) => t.planId.equals(row.id));
    for (final slot in slots) {
      final newSlot = await repos.mealSlots.insert(
        MealSlotsCompanion(
          planId: Value(copy.id),
          name: Value(slot.name),
          timeMinutes: Value(slot.timeMinutes),
          weekdays: Value(slot.weekdays),
          remind: Value(slot.remind),
          notes: Value(slot.notes),
        ),
      );
      final foods = await repos.mealSlotFoods.getAll(where: (t) => t.slotId.equals(slot.id));
      for (final f in foods) {
        await repos.mealSlotFoods.insert(
          MealSlotFoodsCompanion(
            slotId: Value(newSlot.id),
            foodId: Value(f.foodId),
            name: Value(f.name),
            portion: Value(f.portion),
            unit: Value(f.unit),
          ),
        );
      }
    }
    return (copy, () => deletePlan(copy).then((_) {}));
  }

  MealSlotsCompanion _slot(MealSlotDraft d) => MealSlotsCompanion(
    planId: Value(d.planId),
    name: Value(d.name.trim()),
    timeMinutes: Value(d.timeMinutes.clamp(0, 24 * 60 - 1)),
    weekdays: Value(_weekdays(d.weekdays)),
    remind: Value(d.remind),
    notes: Value(_clean(d.notes)),
  );

  Future<(MealSlotRow, NutritionUndo)> addSlot(MealSlotDraft d) async {
    final row = await repos.mealSlots.insert(_slot(d));
    return (row, () async => repos.mealSlots.delete(row.id).then((_) {}));
  }

  Future<NutritionUndo> updateSlot(MealSlotRow row, MealSlotDraft d) async {
    await repos.mealSlots.update(_slot(d).copyWith(id: Value(row.id)));
    return () => repos.mealSlots.update(row);
  }

  /// The per-slot reminder switch.
  Future<NutritionUndo> setSlotRemind(MealSlotRow row, bool remind) async {
    await repos.mealSlots.setColumn(row.id, 'remind', remind);
    return () => repos.mealSlots.setColumn(row.id, 'remind', row.remind);
  }

  /// Deletes a slot with its planned foods (undo restores both).
  Future<NutritionUndo> deleteSlot(MealSlotRow row) async {
    final foods = await repos.mealSlotFoods.deleteWhere((t) => t.slotId.equals(row.id));
    final gone = await repos.mealSlots.delete(row.id);
    return () async {
      if (gone != null) await repos.mealSlots.restore(gone);
      await repos.mealSlotFoods.restoreAll(foods);
    };
  }

  Future<void> reorderSlots(List<String> ids) => repos.mealSlots.reorder(ids);

  MealSlotFoodsCompanion _slotFood(PlannedFoodDraft d) => MealSlotFoodsCompanion(
    slotId: Value(d.slotId),
    foodId: Value(d.foodId),
    name: Value(d.name.trim()),
    portion: Value(_positive(d.portion)),
    unit: Value(_clean(d.unit)),
  );

  Future<(MealSlotFoodRow, NutritionUndo)> addSlotFood(PlannedFoodDraft d) async {
    final row = await repos.mealSlotFoods.insert(_slotFood(d));
    return (row, () async => repos.mealSlotFoods.delete(row.id).then((_) {}));
  }

  Future<NutritionUndo> updateSlotFood(MealSlotFoodRow row, PlannedFoodDraft d) async {
    await repos.mealSlotFoods.update(_slotFood(d).copyWith(id: Value(row.id)));
    return () => repos.mealSlotFoods.update(row);
  }

  Future<NutritionUndo> deleteSlotFood(MealSlotFoodRow row) async {
    final gone = await repos.mealSlotFoods.delete(row.id);
    return () async {
      if (gone != null) await repos.mealSlotFoods.restore(gone);
    };
  }

  Future<void> reorderSlotFoods(List<String> ids) => repos.mealSlotFoods.reorder(ids);

  /// Logs every planned food of [slot] as eaten at [at] (one tap on "I ate
  /// my breakfast"), tying each entry to the slot. The undo removes them
  /// all.
  Future<(List<FoodLogRow>, NutritionUndo)> logSlotAsPlanned(
    MealSlotRow slot, {
    DateTime? at,
    List<MealSlotFoodRow>? planned,
  }) async {
    final when = at ?? clock();
    final foods = planned ?? await repos.mealSlotFoods.getAll(where: (t) => t.slotId.equals(slot.id));
    final rows = <FoodLogRow>[];
    final undos = <NutritionUndo>[];
    for (final f in foods) {
      final (row, undo) = await logFood(
        FoodLogDraft(
          foodId: f.foodId,
          name: f.name,
          at: when,
          portion: f.portion,
          unit: f.unit,
          slotId: slot.id,
        ),
      );
      rows.add(row);
      undos.add(undo);
    }
    return (
      rows,
      () async {
        for (final undo in undos.reversed) {
          await undo();
        }
      },
    );
  }

  // ----------------------------------------------------------- his rules ----

  Stream<List<FoodRuleRow>> watchRules() => repos.foodRules.watchAll();

  FoodRulesCompanion _rule(FoodRuleDraft d) => FoodRulesCompanion(
    conditionId: Value(d.conditionId),
    target: Value(d.target),
    foodId: Value(d.target == FoodRuleTarget.food ? d.foodId : null),
    tag: Value(d.target == FoodRuleTarget.tag ? _clean(d.tag) : null),
    minPortion: Value(_positive(d.minPortion)),
    fromMinutes: Value(_minute(d.fromMinutes)),
    toMinutes: Value(_minute(d.toMinutes)),
    maxPerDay: Value(d.maxPerDay == null || d.maxPerDay! < 0 ? null : d.maxPerDay),
    weight: Value(d.weight),
    note: Value(_clean(d.note)),
    active: Value(d.active),
  );

  Future<(FoodRuleRow, NutritionUndo)> addRule(FoodRuleDraft d) async {
    final row = await repos.foodRules.insert(_rule(d));
    return (row, () async => repos.foodRules.delete(row.id).then((_) {}));
  }

  Future<NutritionUndo> updateRule(FoodRuleRow row, FoodRuleDraft d) async {
    await repos.foodRules.update(_rule(d).copyWith(id: Value(row.id)));
    return () => repos.foodRules.update(row);
  }

  Future<NutritionUndo> setRuleActive(FoodRuleRow row, bool active) async {
    await repos.foodRules.setColumn(row.id, 'active', active);
    return () => repos.foodRules.setColumn(row.id, 'active', row.active);
  }

  Future<NutritionUndo> deleteRule(FoodRuleRow row) async {
    final gone = await repos.foodRules.delete(row.id);
    return () async {
      if (gone != null) await repos.foodRules.restore(gone);
    };
  }

  Future<void> reorderRules(List<String> ids) => repos.foodRules.reorder(ids);

  // ------------------------------------------------------- his conditions ----

  /// His chronic conditions – the existing Health table, read and written
  /// here too so the food screens never need a second one.
  Stream<List<ConditionRow>> watchConditions() => repos.conditions.watchAll();

  ConditionsCompanion _condition(ConditionDraft d) => ConditionsCompanion(
    name: Value(d.name.trim()),
    notes: Value(_clean(d.notes)),
    since: Value(d.since),
    active: Value(d.active),
    color: Value(d.color),
  );

  Future<(ConditionRow, NutritionUndo)> addCondition(ConditionDraft d) async {
    final row = await repos.conditions.insert(_condition(d));
    return (row, () async => repos.conditions.delete(row.id).then((_) {}));
  }

  Future<NutritionUndo> updateCondition(ConditionRow row, ConditionDraft d) async {
    await repos.conditions.update(_condition(d).copyWith(id: Value(row.id)));
    return () => repos.conditions.update(row);
  }

  Future<NutritionUndo> setConditionActive(ConditionRow row, bool active) async {
    await repos.conditions.setColumn(row.id, 'active', active);
    return () => repos.conditions.setColumn(row.id, 'active', row.active);
  }

  /// Deletes a condition. His rules that pointed at it stay on disk but stop
  /// counting (a rule without a live condition never fires), so nothing he
  /// wrote is thrown away.
  Future<NutritionUndo> deleteCondition(ConditionRow row) async {
    final gone = await repos.conditions.delete(row.id);
    return () async {
      if (gone != null) await repos.conditions.restore(gone);
    };
  }

  Future<void> reorderConditions(List<String> ids) => repos.conditions.reorder(ids);

  // ------------------------------------------------------------- insights ----

  /// Pain, mood (with the sleep he logged), water and fasts at or after
  /// [since] – the other planets' own rows, read here so the insights stay
  /// pure functions over plain samples.
  Future<NutritionMetrics> metricsSince(DateTime since) async {
    final pains = await repos.painEntries.getAll(where: (t) => t.at.isBiggerOrEqualValue(since));
    final moods = await repos.moodEntries.getAll(where: (t) => t.at.isBiggerOrEqualValue(since));
    final waters = await repos.waterLogs.getAll(where: (t) => t.at.isBiggerOrEqualValue(since));
    final fasts = await repos.fastingSessions.getAll(where: (t) => t.start.isBiggerOrEqualValue(since));
    return (
      pains: [for (final p in pains) PainPoint(p.at, p.score)],
      moods: [for (final m in moods) MoodPoint(m.at, mood: m.mood, sleepHours: m.sleepHours)],
      waters: [for (final w in waters) WaterPoint(w.at, w.ml)],
      fasts: [for (final f in fasts) FastPoint(f.start, f.end)],
    );
  }

  // ------------------------------------------------------------- mapping ----

  static Food foodOf(FoodRow r) => Food(
    id: r.id,
    name: r.name,
    notes: r.notes,
    tags: r.tags,
    defaultPortion: r.defaultPortion,
    unit: r.unit,
    favorite: r.favorite,
    archived: r.archived,
  );

  static FoodEntry entryOf(FoodLogRow r) => FoodEntry(
    id: r.id,
    foodId: r.foodId,
    name: r.name,
    at: r.at,
    portion: r.portion,
    unit: r.unit,
    tags: r.tags,
    note: r.note,
    slotId: r.slotId,
  );

  static ConditionRef conditionOf(ConditionRow r) =>
      ConditionRef(id: r.id, name: r.name, active: r.active, color: r.color, notes: r.notes, since: r.since);

  /// A rule with the matched food's current name filled in (so a reason can
  /// read «لأنك علّمت المقلي…» without another lookup).
  static FoodRule ruleOf(FoodRuleRow r, {Map<String, FoodRow> foods = const {}}) => FoodRule(
    id: r.id,
    conditionId: r.conditionId,
    target: r.target,
    foodId: r.foodId,
    foodName: foods[r.foodId]?.name,
    tag: r.tag,
    minPortion: r.minPortion,
    fromMinutes: r.fromMinutes,
    toMinutes: r.toMinutes,
    maxPerDay: r.maxPerDay,
    weight: r.weight,
    note: r.note,
    active: r.active,
  );

  /// Assembles the plans with their slots and planned foods, in the user's
  /// own order.
  static List<MealPlan> plansOf(
    List<MealPlanRow> plans,
    List<MealSlotRow> slots,
    List<MealSlotFoodRow> slotFoods,
  ) {
    final bySlot = <String, List<PlannedFood>>{};
    for (final f in slotFoods) {
      bySlot
          .putIfAbsent(f.slotId, () => [])
          .add(PlannedFood(id: f.id, foodId: f.foodId, name: f.name, portion: f.portion, unit: f.unit));
    }
    final byPlan = <String, List<MealSlot>>{};
    for (final s in slots) {
      byPlan.putIfAbsent(s.planId, () => []).add(
        MealSlot(
          id: s.id,
          planId: s.planId,
          name: s.name,
          timeMinutes: s.timeMinutes,
          weekdays: s.weekdays,
          remind: s.remind,
          notes: s.notes,
          foods: bySlot[s.id] ?? const [],
          sortOrder: s.sortOrder,
        ),
      );
    }
    return [
      for (final p in plans)
        MealPlan(
          id: p.id,
          name: p.name,
          notes: p.notes,
          active: p.active,
          slots: byPlan[p.id] ?? const [],
        ),
    ];
  }
}
