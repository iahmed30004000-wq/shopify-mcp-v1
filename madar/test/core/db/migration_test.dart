import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/domain/enums.dart';

const _v2Tables = ['quran_bookmarks', 'quran_sessions', 'wird_plans', 'hifz_items', 'hifz_reviews'];

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

  test('a fresh database is created at schema v2 with the Quran / wird / Hifz tables', () async {
    final db = MadarDatabase(NativeDatabase(file));
    expect(db.schemaVersion, 2);
    expect(await _tables(db), containsAll(_v2Tables));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 2);
    await db.close();
  });

  test('a v1 database upgrades to v2 and keeps its data', () async {
    // Build a v1 file: the current schema minus the v2 tables, user_version 1.
    final v1 = MadarDatabase(NativeDatabase(file));
    await v1.into(v1.tasks).insert(TasksCompanion.insert(title: 'قبل الترقية'));
    for (final t in _v2Tables) {
      await v1.customStatement('DROP TABLE $t');
    }
    await v1.customStatement('PRAGMA user_version = 1');
    await v1.close();

    final db = MadarDatabase(NativeDatabase(file));
    expect(await _tables(db), containsAll(_v2Tables));
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
    expect(version.data.values.single, 2);
    await db.close();
  });
}
