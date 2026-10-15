import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/domain/enums.dart';

const _v2Tables = ['quran_bookmarks', 'quran_sessions', 'wird_plans', 'hifz_items', 'hifz_reviews'];
const _v3Tables = ['foods', 'food_logs', 'meal_plans', 'meal_slots', 'meal_slot_foods', 'food_rules'];
const _v4Tables = ['applied_plans', 'applied_plan_items'];
const _v5Tables = ['record_lists', 'record_list_items'];
const _v6Tables = ['pantry_items', 'recipes', 'recipe_ingredients', 'cooked_meals', 'kitchen_rules'];
const _v7Tables = ['tasmee_sessions', 'tasmee_ayat', 'tasmee_mistakes'];
const _v8Tables = ['hifz_goals', 'hifz_marks'];

Future<Set<String>> _columns(MadarDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return {for (final r in rows) r.read<String>('name')};
}

Future<Set<String>> _tables(MadarDatabase db) async {
  final rows = await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'table'").get();
  return {for (final r in rows) r.read<String>('name')};
}

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('madar_migration');
    file = File('${dir.path}/madar.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('a fresh database is created at schema v8 with the Quran / wird / Hifz, nutrition, AI-plan, list, kitchen and recitation tables', () async {
    final db = MadarDatabase(NativeDatabase(file));
    expect(db.schemaVersion, 8);
    expect(await _tables(db), containsAll([..._v2Tables, ..._v3Tables, ..._v4Tables, ..._v5Tables, ..._v6Tables, ..._v7Tables, ..._v8Tables]));
    expect(await _columns(db, 'record_lists'), containsAll(['host_table', 'host_id', 'name', 'currency', 'posted_at', 'posted_tx_id', 'posted_amount_milli', 'posted_item_count']));
    expect(await _columns(db, 'record_list_items'), containsAll(['list_id', 'title', 'quantity', 'unit', 'price_milli', 'done', 'done_at', 'note']));
    expect(
      await _columns(db, 'pantry_items'),
      containsAll(['name', 'aliases', 'quantity', 'unit', 'place', 'low_at', 'low', 'expires', 'staple', 'archived']),
    );
    expect(
      await _columns(db, 'recipes'),
      containsAll(['name', 'steps', 'servings', 'minutes', 'tags', 'photos', 'source', 'source_name', 'favorite']),
    );
    expect(
      await _columns(db, 'recipe_ingredients'),
      containsAll(['recipe_id', 'name', 'quantity', 'unit', 'optional', 'note']),
    );
    expect(await _columns(db, 'cooked_meals'), containsAll(['recipe_id', 'name', 'day', 'servings', 'overrode']));
    expect(await _columns(db, 'kitchen_rules'), containsAll(['kind', 'term', 'who', 'note', 'active']));
    expect(
      await _columns(db, 'tasmee_sessions'),
      containsAll([
        'started_at', 'day', 'mode', 'from_surah', 'from_ayah', 'to_surah', 'to_ayah', //
        'word_count', 'right_count', 'wrong_count', 'skipped_count', 'unsure_count', 'pending_count',
        'extra_count', 'hint_count', 'tashkeel_diff_count', 'seconds', 'recogniser_id', 'recogniser_version',
        'text_source', 'tashkeel_checked', 'seed', 'note',
      ]),
    );
    expect(
      await _columns(db, 'tasmee_ayat'),
      containsAll(['session_id', 'day', 'surah', 'ayah', 'word_count', 'right_count', 'hint_count']),
    );
    expect(
      await _columns(db, 'tasmee_mistakes'),
      containsAll([
        'session_id', 'at', 'day', 'surah', 'ayah', 'word_index', 'kind', 'expected', //
        'span_start', 'span_end', 'heard', 'hinted', 'confidence', 'tashkeel_only',
      ]),
    );
    // There is no audio anywhere in the recitation log, by construction.
    for (final table in ['tasmee_sessions', 'tasmee_ayat', 'tasmee_mistakes']) {
      final columns = await _columns(db, table);
      expect(
        columns.where((c) => c.contains('audio') || c.contains('record') || c.contains('path') || c.contains('file')),
        isEmpty,
        reason: '$table must hold no recording',
      );
    }
    expect(await _columns(db, 'conditions'), contains('color'));
    expect(await _columns(db, 'applied_plans'), contains('name'));
    expect(await _columns(db, 'applied_plan_items'), containsAll(['done', 'done_at', 'before_json', 'after_json']));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 8);
    await db.close();
  });

  test('a fresh database carries «الحفظ»\'s goals and marks with their defaults', () async {
    final db = MadarDatabase(NativeDatabase(file));
    expect(
      await _columns(db, 'hifz_goals'),
      containsAll([
        'title', 'kind', 'from_surah', 'from_ayah', 'to_surah', 'to_ayah', 'weekday', //
        'amount', 'unit', 'window', 'offset_minutes', 'remind', 'active', 'sort_order',
      ]),
    );
    expect(
      await _columns(db, 'hifz_marks'),
      containsAll(['kind', 'from_surah', 'from_ayah', 'to_surah', 'to_ayah', 'since', 'note']),
    );
    await db.into(db.hifzGoals).insert(
      HifzGoalsCompanion.insert(id: const Value('g1'), title: 'الكهف كل جمعة', kind: HifzGoalKind.rangeOnWeekday),
    );
    final goal = (await db.select(db.hifzGoals).get()).single;
    expect(goal.title, 'الكهف كل جمعة', reason: 'his own words, stored verbatim');
    expect(goal.unit, WirdUnit.pages);
    expect(goal.offsetMinutes, 15);
    expect(goal.remind, isTrue);
    expect(goal.active, isTrue);
    expect(goal.window, isNull, reason: 'no prayer chosen yet, so no reminder can be planned');
    await db.into(db.hifzMarks).insert(
      HifzMarksCompanion.insert(
        kind: HifzMarkKind.skipReview,
        fromSurah: 2,
        fromAyah: 1,
        toSurah: 2,
        toAyah: 5,
      ),
    );
    final mark = (await db.select(db.hifzMarks).get()).single;
    expect(mark.kind, HifzMarkKind.skipReview);
    expect(mark.since, isNull);
    await db.close();
  });

  test('a v1 database upgrades to v8 and keeps its data', () async {
    // Build a v1 file: the current schema minus the v2, v3, v4 and v5
    // tables and the v3 column, user_version 1.
    final v1 = MadarDatabase(NativeDatabase(file));
    await v1.into(v1.tasks).insert(TasksCompanion.insert(title: 'قبل الترقية'));
    for (final t in [..._v2Tables, ..._v3Tables, ..._v4Tables, ..._v5Tables, ..._v6Tables, ..._v7Tables, ..._v8Tables]) {
      await v1.customStatement('DROP TABLE $t');
    }
    await v1.customStatement('ALTER TABLE conditions DROP COLUMN color');
    await v1.customStatement('PRAGMA user_version = 1');
    await v1.close();

    final db = MadarDatabase(NativeDatabase(file));
    expect(await _tables(db), containsAll([..._v2Tables, ..._v3Tables, ..._v4Tables, ..._v5Tables, ..._v6Tables, ..._v7Tables, ..._v8Tables]));
    expect((await db.select(db.tasks).get()).single.title, 'قبل الترقية');

    // The new tables are usable, with their defaults.
    await db.into(db.hifzItems).insert(HifzItemsCompanion.insert(surah: const Value(1), ayahFrom: const Value(1), ayahTo: const Value(7)));
    final item = (await db.select(db.hifzItems).get()).single;
    expect(item.kind, HifzKind.ayat);
    expect(item.easeFactor, 2.5);
    expect(item.due, isNull);
    await db.into(db.wirdPlans).insert(WirdPlansCompanion.insert(name: 'ختمة', amountPerDay: 20, startDate: DateTime(2026, 10, 1)));
    final plan = (await db.select(db.wirdPlans).get()).single;
    expect(plan.unit, WirdUnit.pages);
    expect(plan.startDate, DateTime(2026, 10, 1));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 8);
    await db.close();
  });

  test('a v2 database upgrades to v8, keeps its data and gets the nutrition tables', () async {
    // Build a v2 file: the current schema minus the v3, v4 and v5 tables
    // and the colour column on conditions, user_version 2.
    final v2 = MadarDatabase(NativeDatabase(file));
    await v2.into(v2.tasks).insert(TasksCompanion.insert(title: 'مهمة قديمة'));
    await v2
        .into(v2.conditions)
        .insert(ConditionsCompanion.insert(id: const Value('cond-1'), name: 'الضغط', notes: const Value('مزمن')));
    await v2.into(v2.painEntries).insert(PainEntriesCompanion.insert(at: DateTime(2026, 9, 1, 20), score: 7));
    for (final t in [..._v3Tables, ..._v4Tables, ..._v5Tables, ..._v6Tables, ..._v7Tables, ..._v8Tables]) {
      await v2.customStatement('DROP TABLE $t');
    }
    await v2.customStatement('ALTER TABLE conditions DROP COLUMN color');
    await v2.customStatement('PRAGMA user_version = 2');
    await v2.close();

    final db = MadarDatabase(NativeDatabase(file));
    expect(await _tables(db), containsAll([..._v3Tables, ..._v4Tables, ..._v5Tables, ..._v6Tables, ..._v7Tables, ..._v8Tables]));
    expect(
      await _columns(db, 'pantry_items'),
      containsAll(['name', 'aliases', 'quantity', 'unit', 'place', 'low_at', 'low', 'expires', 'staple', 'archived']),
    );
    expect(
      await _columns(db, 'recipes'),
      containsAll(['name', 'steps', 'servings', 'minutes', 'tags', 'photos', 'source', 'source_name', 'favorite']),
    );
    expect(
      await _columns(db, 'recipe_ingredients'),
      containsAll(['recipe_id', 'name', 'quantity', 'unit', 'optional', 'note']),
    );
    expect(await _columns(db, 'cooked_meals'), containsAll(['recipe_id', 'name', 'day', 'servings', 'overrode']));
    expect(await _columns(db, 'kitchen_rules'), containsAll(['kind', 'term', 'who', 'note', 'active']));
    expect(
      await _columns(db, 'tasmee_sessions'),
      containsAll([
        'started_at', 'day', 'mode', 'from_surah', 'from_ayah', 'to_surah', 'to_ayah', //
        'word_count', 'right_count', 'wrong_count', 'skipped_count', 'unsure_count', 'pending_count',
        'extra_count', 'hint_count', 'tashkeel_diff_count', 'seconds', 'recogniser_id', 'recogniser_version',
        'text_source', 'tashkeel_checked', 'seed', 'note',
      ]),
    );
    expect(
      await _columns(db, 'tasmee_ayat'),
      containsAll(['session_id', 'day', 'surah', 'ayah', 'word_count', 'right_count', 'hint_count']),
    );
    expect(
      await _columns(db, 'tasmee_mistakes'),
      containsAll([
        'session_id', 'at', 'day', 'surah', 'ayah', 'word_index', 'kind', 'expected', //
        'span_start', 'span_end', 'heard', 'hinted', 'confidence', 'tashkeel_only',
      ]),
    );
    // There is no audio anywhere in the recitation log, by construction.
    for (final table in ['tasmee_sessions', 'tasmee_ayat', 'tasmee_mistakes']) {
      final columns = await _columns(db, table);
      expect(
        columns.where((c) => c.contains('audio') || c.contains('record') || c.contains('path') || c.contains('file')),
        isEmpty,
        reason: '$table must hold no recording',
      );
    }
    expect(await _columns(db, 'conditions'), contains('color'));

    // Nothing of v2 was lost, and the old condition keeps a null colour.
    expect((await db.select(db.tasks).get()).single.title, 'مهمة قديمة');
    final condition = (await db.select(db.conditions).get()).single;
    expect(condition.name, 'الضغط');
    expect(condition.notes, 'مزمن');
    expect(condition.active, isTrue);
    expect(condition.color, isNull);
    expect((await db.select(db.painEntries).get()).single.score, 7);

    // The new tables are usable, with their defaults.
    await db.into(db.foods).insert(FoodsCompanion.insert(name: 'فلافل'));
    final food = (await db.select(db.foods).get()).single;
    expect(food.tags, isEmpty);
    expect(food.favorite, isFalse);
    expect(food.archived, isFalse);
    expect(food.defaultPortion, isNull);

    await db.into(db.mealPlans).insert(MealPlansCompanion.insert(id: const Value('plan-1'), name: 'خطتي'));
    expect((await db.select(db.mealPlans).get()).single.active, isFalse);
    await db
        .into(db.mealSlots)
        .insert(MealSlotsCompanion.insert(planId: 'plan-1', name: 'فطور', timeMinutes: 480));
    final slot = (await db.select(db.mealSlots).get()).single;
    expect(slot.weekdays, isEmpty);
    expect(slot.remind, isFalse);
    await db.into(db.mealSlotFoods).insert(MealSlotFoodsCompanion.insert(slotId: slot.id, name: 'فلافل'));
    expect((await db.select(db.mealSlotFoods).get()).single.name, 'فلافل');

    await db
        .into(db.foodLogs)
        .insert(FoodLogsCompanion.insert(name: 'فلافل', at: DateTime(2026, 10, 10, 8, 30), foodId: Value(food.id)));
    final log = (await db.select(db.foodLogs).get()).single;
    expect(log.tags, isEmpty);
    expect(log.slotId, isNull);

    await db.into(db.foodRules).insert(
      FoodRulesCompanion.insert(
        conditionId: const Value('cond-1'),
        target: const Value(FoodRuleTarget.tag),
        tag: const Value('ملح عالي'),
        weight: const Value(RiskWeight.high),
        note: const Value('الملح يرفع ضغطي'),
      ),
    );
    final rule = (await db.select(db.foodRules).get()).single;
    expect(rule.target, FoodRuleTarget.tag);
    expect(rule.weight, RiskWeight.high);
    expect(rule.active, isTrue);
    expect(rule.maxPerDay, isNull);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 8);
    await db.close();
  });

  test('a v3 database upgrades to v8 and gets the AI-plan tables, usable with their defaults', () async {
    // Build a v3 file: the current schema minus the v4 and v5 tables,
    // user_version 3.
    final v3 = MadarDatabase(NativeDatabase(file));
    await v3.into(v3.tasks).insert(TasksCompanion.insert(title: 'مهمة من قبل'));
    await v3.into(v3.foods).insert(FoodsCompanion.insert(id: const Value('f1'), name: 'فلافل'));
    for (final t in [..._v4Tables, ..._v5Tables, ..._v6Tables, ..._v7Tables, ..._v8Tables]) {
      await v3.customStatement('DROP TABLE $t');
    }
    await v3.customStatement('PRAGMA user_version = 3');
    await v3.close();

    final db = MadarDatabase(NativeDatabase(file));
    expect(await _tables(db), containsAll([..._v4Tables, ..._v5Tables, ..._v6Tables, ..._v7Tables, ..._v8Tables]));
    expect((await db.select(db.tasks).get()).single.title, 'مهمة من قبل');
    expect((await db.select(db.foods).get()).single.name, 'فلافل');

    await db.into(db.appliedPlans).insert(
      AppliedPlansCompanion.insert(
        id: const Value('p1'),
        planKey: 'k1',
        name: 'خطة تشرين الأول',
        raw: '{"madar":"plan"}',
      ),
    );
    final plan = (await db.select(db.appliedPlans).get()).single;
    expect(plan.name, 'خطة تشرين الأول');
    expect(plan.formatVersion, 1);
    expect(plan.origin, PlanOrigin.file);
    expect(plan.itemCount, 0);
    expect(plan.source, isEmpty);

    await db.into(db.appliedPlanItems).insert(
      AppliedPlanItemsCompanion.insert(planId: 'p1', itemKey: 'h1', kind: 'habit', title: 'مشي', reason: 'سبب'),
    );
    final item = (await db.select(db.appliedPlanItems).get()).single;
    expect(item.state, PlanItemState.pending);
    expect(item.done, isFalse);
    expect(item.doneAt, isNull);
    expect(item.beforeJson, isEmpty);

    // One plan cannot hold the same suggestion twice (idempotence rests on it).
    await expectLater(
      db.into(db.appliedPlanItems).insert(
        AppliedPlanItemsCompanion.insert(planId: 'p1', itemKey: 'h1', kind: 'habit', title: 'مشي', reason: 'سبب'),
      ),
      throwsA(isA<Exception>()),
    );

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 8);
    await db.close();
  });

  test('a v4 database upgrades to v8 and gets the list tables, usable with their defaults', () async {
    // Build a v4 file: the current schema minus the v5 tables, user_version 4.
    final v4 = MadarDatabase(NativeDatabase(file));
    await v4.into(v4.tasks).insert(TasksCompanion.insert(title: 'مهمة من قبل'));
    await v4
        .into(v4.budgetItems)
        .insert(BudgetItemsCompanion.insert(id: const Value('b-food'), name: 'بقالة', amountMilli: const Value(200000)));
    for (final t in _v5Tables) {
      await v4.customStatement('DROP TABLE $t');
    }
    await v4.customStatement('PRAGMA user_version = 4');
    await v4.close();

    final db = MadarDatabase(NativeDatabase(file));
    expect(await _tables(db), containsAll(_v5Tables));
    expect((await db.select(db.tasks).get()).single.title, 'مهمة من قبل');
    expect((await db.select(db.budgetItems).get()).single.name, 'بقالة');

    // A list of an envelope, with nothing posted and no prices yet.
    await db.into(db.recordLists).insert(
      RecordListsCompanion.insert(
        id: const Value('l1'),
        hostTable: 'budget_items',
        hostId: 'b-food',
        name: 'أغراض البقالة',
      ),
    );
    final list = (await db.select(db.recordLists).get()).single;
    expect(list.currency, isNull);
    expect(list.postedAt, isNull);
    expect(list.postedTxId, isNull);
    expect(list.postedAmountMilli, isNull);
    expect(list.postedItemCount, isNull);
    expect(list.sortOrder, 0);

    await db.into(db.recordListItems).insert(RecordListItemsCompanion.insert(listId: 'l1', title: 'رز'));
    final item = (await db.select(db.recordListItems).get()).single;
    expect(item.done, isFalse);
    expect(item.doneAt, isNull);
    expect(item.quantity, isNull);
    expect(item.unit, isNull);
    expect(item.priceMilli, isNull);
    expect(item.note, isNull);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 8);
    await db.close();
  });

  test('a v5 database upgrades to v8 and gets the kitchen tables of «السفرة», usable with their defaults', () async {
    // Build a v5 file: the current schema minus the v6 tables, user_version 5.
    final v5 = MadarDatabase(NativeDatabase(file));
    await v5.into(v5.tasks).insert(TasksCompanion.insert(title: 'مهمة من قبل'));
    await v5
        .into(v5.recordLists)
        .insert(RecordListsCompanion.insert(hostTable: 'trips', hostId: 't1', name: 'شنطة السفر'));
    for (final t in [..._v6Tables, ..._v7Tables, ..._v8Tables]) {
      await v5.customStatement('DROP TABLE $t');
    }
    await v5.customStatement('PRAGMA user_version = 5');
    await v5.close();

    final db = MadarDatabase(NativeDatabase(file));
    expect(await _tables(db), containsAll([..._v6Tables, ..._v7Tables, ..._v8Tables]));
    expect((await db.select(db.tasks).get()).single.title, 'مهمة من قبل');
    expect((await db.select(db.recordLists).get()).single.name, 'شنطة السفر');

    // A thing in the house, typed with a word and nothing else.
    await db.into(db.pantryItems).insert(PantryItemsCompanion.insert(name: 'رز'));
    final pantry = (await db.select(db.pantryItems).get()).single;
    expect(pantry.aliases, isEmpty);
    expect(pantry.quantity, isNull);
    expect(pantry.unit, isNull);
    expect(pantry.place, isNull);
    expect(pantry.lowAt, isNull);
    expect(pantry.low, isFalse);
    expect(pantry.expires, isNull);
    expect(pantry.staple, isFalse);
    expect(pantry.archived, isFalse);

    // A dish, hers by default.
    await db.into(db.recipes).insert(RecipesCompanion.insert(id: const Value('r1'), name: 'مجدرة'));
    final recipe = (await db.select(db.recipes).get()).single;
    expect(recipe.source, RecipeSource.mine);
    expect(recipe.sourceName, isNull);
    expect(recipe.steps, isEmpty);
    expect(recipe.tags, isEmpty);
    expect(recipe.photos, isEmpty);
    expect(recipe.servings, isNull);
    expect(recipe.minutes, isNull);
    expect(recipe.favorite, isFalse);

    await db.into(db.recipeIngredients).insert(RecipeIngredientsCompanion.insert(recipeId: 'r1', name: 'عدس'));
    final ingredient = (await db.select(db.recipeIngredients).get()).single;
    expect(ingredient.quantity, isNull);
    expect(ingredient.unit, isNull);
    expect(ingredient.optional, isFalse);

    // The cooked log keeps a zone-free calendar day.
    await db
        .into(db.cookedMeals)
        .insert(CookedMealsCompanion.insert(recipeId: const Value('r1'), name: 'مجدرة', day: DateTime(2026, 10, 14)));
    final cooked = (await db.select(db.cookedMeals).get()).single;
    expect(cooked.day, DateTime(2026, 10, 14));
    expect(cooked.overrode, isFalse);
    expect(cooked.servings, isNull);

    // A constraint of hers: «avoid», active, no one named.
    await db.into(db.kitchenRules).insert(KitchenRulesCompanion.insert(term: 'حار'));
    final rule = (await db.select(db.kitchenRules).get()).single;
    expect(rule.kind, KitchenRuleKind.avoid);
    expect(rule.active, isTrue);
    expect(rule.who, isNull);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 8);
    await db.close();
  });

  test('a v6 database upgrades to v8 and gets «التسميع»\'s log, usable with its defaults', () async {
    // Build a v6 file: the current schema minus the v7 and v8 tables,
    // user_version 6.
    final v6 = MadarDatabase(NativeDatabase(file));
    await v6.into(v6.tasks).insert(TasksCompanion.insert(title: 'مهمة من قبل'));
    await v6.into(v6.pantryItems).insert(PantryItemsCompanion.insert(name: 'رز'));
    for (final t in [..._v7Tables, ..._v8Tables]) {
      await v6.customStatement('DROP TABLE $t');
    }
    await v6.customStatement('PRAGMA user_version = 6');
    await v6.close();

    final db = MadarDatabase(NativeDatabase(file));
    expect(await _tables(db), containsAll(_v7Tables));
    expect((await db.select(db.tasks).get()).single.title, 'مهمة من قبل');
    expect((await db.select(db.pantryItems).get()).single.name, 'رز');

    // One recitation, with nothing but the range filled in.
    await db.into(db.tasmeeSessions).insert(
      TasmeeSessionsCompanion.insert(
        id: const Value('s1'),
        startedAt: DateTime(2026, 10, 15, 20, 12),
        day: DateTime(2026, 10, 15),
        fromSurah: 2,
        fromAyah: 255,
        toSurah: 2,
        toAyah: 255,
      ),
    );
    final session = (await db.select(db.tasmeeSessions).get()).single;
    expect(session.mode, TasmeeMode.recite);
    expect(session.day, DateTime(2026, 10, 15));
    expect(session.wordCount, 0);
    expect(session.hintCount, 0);
    expect(session.seconds, 0);
    expect(session.textSource, 'tanzil-uthmani');
    expect(session.tashkeelChecked, isFalse, reason: 'the tashkeel check is off by default');
    expect(session.seed, isNull);
    expect(session.note, isNull);

    await db.into(db.tasmeeAyat).insert(
      TasmeeAyatCompanion.insert(sessionId: 's1', day: DateTime(2026, 10, 15), surah: 2, ayah: 255),
    );
    final ayah = (await db.select(db.tasmeeAyat).get()).single;
    expect(ayah.sessionId, 's1');
    expect(ayah.rightCount, 0);
    expect(ayah.pendingCount, 0);

    await db.into(db.tasmeeMistakes).insert(
      TasmeeMistakesCompanion.insert(
        sessionId: 's1',
        at: DateTime(2026, 10, 15, 20, 12, 9),
        day: DateTime(2026, 10, 15),
        surah: 2,
        ayah: 255,
        wordIndex: 7,
        kind: MistakeKind.skipped,
        expected: 'كلمة',
        spanStart: 34,
        spanEnd: 41,
      ),
    );
    final mistake = (await db.select(db.tasmeeMistakes).get()).single;
    expect(mistake.kind, MistakeKind.skipped);
    expect(mistake.heard, isNull, reason: 'nothing was heard where a word was skipped');
    expect(mistake.hinted, isFalse);
    expect(mistake.confidence, isNull);
    expect(mistake.tashkeelOnly, isFalse);
    expect(mistake.day, DateTime(2026, 10, 15));

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 8);
    await db.close();
  });

  test('a v7 database upgrades to v8 and gets «الحفظ»\'s goals and marks, keeping the recitation log', () async {
    // Build a v7 file: the current schema minus the v8 tables, user_version 7.
    final v7 = MadarDatabase(NativeDatabase(file));
    await v7.into(v7.tasks).insert(TasksCompanion.insert(title: 'مهمة من قبل'));
    await v7.into(v7.tasmeeSessions).insert(
      TasmeeSessionsCompanion.insert(
        id: const Value('s1'),
        startedAt: DateTime(2026, 10, 14, 20, 12),
        day: DateTime(2026, 10, 14),
        fromSurah: 18,
        fromAyah: 1,
        toSurah: 18,
        toAyah: 5,
      ),
    );
    await v7.into(v7.hifzItems).insert(
      HifzItemsCompanion.insert(surah: const Value(18), ayahFrom: const Value(1), ayahTo: const Value(10)),
    );
    for (final t in _v8Tables) {
      await v7.customStatement('DROP TABLE $t');
    }
    await v7.customStatement('PRAGMA user_version = 7');
    await v7.close();

    final db = MadarDatabase(NativeDatabase(file));
    expect(await _tables(db), containsAll(_v8Tables));
    expect((await db.select(db.tasks).get()).single.title, 'مهمة من قبل');
    expect((await db.select(db.tasmeeSessions).get()).single.id, 's1', reason: 'the v7 log is untouched');
    expect((await db.select(db.hifzItems).get()).single.surah, 18);

    await db.into(db.hifzGoals).insert(
      HifzGoalsCompanion.insert(
        id: const Value('g1'),
        title: 'راجع جزء عمّ',
        kind: HifzGoalKind.rangeReview,
        fromSurah: const Value(78),
        fromAyah: const Value(1),
        toSurah: const Value(114),
        toAyah: const Value(6),
        window: const Value(PrayerWindow.fajr),
      ),
    );
    final goal = (await db.select(db.hifzGoals).get()).single;
    expect(goal.kind, HifzGoalKind.rangeReview);
    expect(goal.window, PrayerWindow.fajr);
    expect(goal.fromSurah, 78);
    expect(goal.sortOrder, 0);

    await db.into(db.hifzMarks).insert(
      HifzMarksCompanion.insert(
        kind: HifzMarkKind.resetStrength,
        fromSurah: 18,
        fromAyah: 1,
        toSurah: 18,
        toAyah: 10,
        since: Value(DateTime(2026, 10, 15)),
        note: const Value('بلّشت من جديد'),
      ),
    );
    final mark = (await db.select(db.hifzMarks).get()).single;
    expect(mark.kind, HifzMarkKind.resetStrength);
    expect(mark.since, DateTime(2026, 10, 15), reason: 'a day is stored zone-free');
    expect(mark.note, 'بلّشت من جديد');

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 8);
    await db.close();
  });
}