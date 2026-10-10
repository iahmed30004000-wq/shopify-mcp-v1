import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/domain/enums.dart';

const _v2Tables = ['quran_bookmarks', 'quran_sessions', 'wird_plans', 'hifz_items', 'hifz_reviews'];
const _v3Tables = ['foods', 'food_logs', 'meal_plans', 'meal_slots', 'meal_slot_foods', 'food_rules'];

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

  test('a fresh database is created at schema v3 with the Quran / wird / Hifz and nutrition tables', () async {
    final db = MadarDatabase(NativeDatabase(file));
    expect(db.schemaVersion, 3);
    expect(await _tables(db), containsAll([..._v2Tables, ..._v3Tables]));
    expect(await _columns(db, 'conditions'), contains('color'));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 3);
    await db.close();
  });

  test('a v1 database upgrades to v3 and keeps its data', () async {
    // Build a v1 file: the current schema minus the v2 and v3 tables and the
    // v3 column, user_version 1.
    final v1 = MadarDatabase(NativeDatabase(file));
    await v1.into(v1.tasks).insert(TasksCompanion.insert(title: 'قبل الترقية'));
    for (final t in [..._v2Tables, ..._v3Tables]) {
      await v1.customStatement('DROP TABLE $t');
    }
    await v1.customStatement('ALTER TABLE conditions DROP COLUMN color');
    await v1.customStatement('PRAGMA user_version = 1');
    await v1.close();

    final db = MadarDatabase(NativeDatabase(file));
    expect(await _tables(db), containsAll([..._v2Tables, ..._v3Tables]));
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
    expect(version.data.values.single, 3);
    await db.close();
  });

  test('a v2 database upgrades to v3, keeps its data and gets the nutrition tables', () async {
    // Build a v2 file: the current schema minus the v3 tables and the colour
    // column on conditions, user_version 2.
    final v2 = MadarDatabase(NativeDatabase(file));
    await v2.into(v2.tasks).insert(TasksCompanion.insert(title: 'مهمة قديمة'));
    await v2
        .into(v2.conditions)
        .insert(ConditionsCompanion.insert(id: const Value('cond-1'), name: 'الضغط', notes: const Value('مزمن')));
    await v2.into(v2.painEntries).insert(PainEntriesCompanion.insert(at: DateTime(2026, 9, 1, 20), score: 7));
    for (final t in _v3Tables) {
      await v2.customStatement('DROP TABLE $t');
    }
    await v2.customStatement('ALTER TABLE conditions DROP COLUMN color');
    await v2.customStatement('PRAGMA user_version = 2');
    await v2.close();

    final db = MadarDatabase(NativeDatabase(file));
    expect(await _tables(db), containsAll(_v3Tables));
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
    expect(version.data.values.single, 3);
    await db.close();
  });
}
