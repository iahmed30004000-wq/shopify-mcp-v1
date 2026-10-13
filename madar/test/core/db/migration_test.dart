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

  test('a fresh database is created at schema v5 with the Quran / wird / Hifz, nutrition, AI-plan and list tables', () async {
    final db = MadarDatabase(NativeDatabase(file));
    expect(db.schemaVersion, 5);
    expect(await _tables(db), containsAll([..._v2Tables, ..._v3Tables, ..._v4Tables, ..._v5Tables]));
    expect(await _columns(db, 'record_lists'), containsAll(['host_table', 'host_id', 'name', 'currency', 'posted_at', 'posted_tx_id', 'posted_amount_milli', 'posted_item_count']));
    expect(await _columns(db, 'record_list_items'), containsAll(['list_id', 'title', 'quantity', 'unit', 'price_milli', 'done', 'done_at', 'note']));
    expect(await _columns(db, 'conditions'), contains('color'));
    expect(await _columns(db, 'applied_plans'), contains('name'));
    expect(await _columns(db, 'applied_plan_items'), containsAll(['done', 'done_at', 'before_json', 'after_json']));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 5);
    await db.close();
  });

  test('a v1 database upgrades to v5 and keeps its data', () async {
    // Build a v1 file: the current schema minus the v2, v3, v4 and v5
    // tables and the v3 column, user_version 1.
    final v1 = MadarDatabase(NativeDatabase(file));
    await v1.into(v1.tasks).insert(TasksCompanion.insert(title: 'قبل الترقية'));
    for (final t in [..._v2Tables, ..._v3Tables, ..._v4Tables, ..._v5Tables]) {
      await v1.customStatement('DROP TABLE $t');
    }
    await v1.customStatement('ALTER TABLE conditions DROP COLUMN color');
    await v1.customStatement('PRAGMA user_version = 1');
    await v1.close();

    final db = MadarDatabase(NativeDatabase(file));
    expect(await _tables(db), containsAll([..._v2Tables, ..._v3Tables, ..._v4Tables, ..._v5Tables]));
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
    expect(version.data.values.single, 5);
    await db.close();
  });

  test('a v2 database upgrades to v5, keeps its data and gets the nutrition tables', () async {
    // Build a v2 file: the current schema minus the v3, v4 and v5 tables
    // and the colour column on conditions, user_version 2.
    final v2 = MadarDatabase(NativeDatabase(file));
    await v2.into(v2.tasks).insert(TasksCompanion.insert(title: 'مهمة قديمة'));
    await v2
        .into(v2.conditions)
        .insert(ConditionsCompanion.insert(id: const Value('cond-1'), name: 'الضغط', notes: const Value('مزمن')));
    await v2.into(v2.painEntries).insert(PainEntriesCompanion.insert(at: DateTime(2026, 9, 1, 20), score: 7));
    for (final t in [..._v3Tables, ..._v4Tables, ..._v5Tables]) {
      await v2.customStatement('DROP TABLE $t');
    }
    await v2.customStatement('ALTER TABLE conditions DROP COLUMN color');
    await v2.customStatement('PRAGMA user_version = 2');
    await v2.close();

    final db = MadarDatabase(NativeDatabase(file));
    expect(await _tables(db), containsAll([..._v3Tables, ..._v4Tables, ..._v5Tables]));
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
    expect(version.data.values.single, 5);
    await db.close();
  });

  test('a v3 database upgrades to v5 and gets the AI-plan tables, usable with their defaults', () async {
    // Build a v3 file: the current schema minus the v4 and v5 tables,
    // user_version 3.
    final v3 = MadarDatabase(NativeDatabase(file));
    await v3.into(v3.tasks).insert(TasksCompanion.insert(title: 'مهمة من قبل'));
    await v3.into(v3.foods).insert(FoodsCompanion.insert(id: const Value('f1'), name: 'فلافل'));
    for (final t in [..._v4Tables, ..._v5Tables]) {
      await v3.customStatement('DROP TABLE $t');
    }
    await v3.customStatement('PRAGMA user_version = 3');
    await v3.close();

    final db = MadarDatabase(NativeDatabase(file));
    expect(await _tables(db), containsAll([..._v4Tables, ..._v5Tables]));
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
    expect(version.data.values.single, 5);
    await db.close();
  });

  test('a v4 database upgrades to v5 and gets the list tables, usable with their defaults', () async {
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
    expect(version.data.values.single, 5);
    await db.close();
  });
}
