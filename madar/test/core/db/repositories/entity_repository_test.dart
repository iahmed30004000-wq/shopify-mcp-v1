import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';

import '../fixtures.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late MadarDatabase db;
  late Repositories repos;

  setUp(() {
    db = MadarDatabase(NativeDatabase.memory());
    repos = Repositories(db);
  });

  tearDown(() => db.close());

  Future<List<String>> titles(EntityRepository<$TasksTable, TaskRow> r) async =>
      (await r.getAll()).map((t) => t.title).toList();

  group('Tasks', () {
    test('insert appends at the end and watchAll is ordered', () async {
      final a = await repos.tasks.insert(TasksCompanion.insert(title: 'a'));
      final b = await repos.tasks.insert(TasksCompanion.insert(title: 'b', sortOrder: const Value(-50)));
      final c = await repos.tasks.insert(TasksCompanion.insert(title: 'c', window: const Value(PrayerWindow.fajr)));
      expect([a.sortOrder, b.sortOrder, c.sortOrder], [0, 1, 2]);
      expect(a.id, isNotEmpty);
      expect(a.window, PrayerWindow.anytime);

      final stream = repos.tasks.watchAll(where: (t) => t.window.equalsValue(PrayerWindow.fajr));
      expect(await stream.first, [c]);
      expect(await titles(repos.tasks), ['a', 'b', 'c']);
      expect(await repos.tasks.count(), 3);
      expect(await repos.tasks.byId(b.id), b);
      expect(await repos.tasks.byId('missing'), isNull);
    });

    test('update writes present fields, clears with Value(null) and bumps updatedAt', () async {
      final t = await repos.tasks.insert(
        TasksCompanion.insert(
          title: 'a',
          notes: const Value('n'),
          createdAt: Value(DateTime(2020)),
          updatedAt: Value(DateTime(2020)),
        ),
      );
      await repos.tasks.update(TasksCompanion(id: Value(t.id), title: const Value('A'), notes: const Value(null)));
      final after = (await repos.tasks.byId(t.id))!;
      expect(after.title, 'A');
      expect(after.notes, isNull);
      expect(after.createdAt, DateTime(2020));
      expect(after.updatedAt.isAfter(DateTime(2020)), isTrue);
      expect(() => repos.tasks.update(const TasksCompanion(title: Value('x'))), throwsArgumentError);
    });

    test('updating a stale data class never undoes a reorder', () async {
      final a = await repos.tasks.insert(TasksCompanion.insert(title: 'a'));
      await repos.tasks.insert(TasksCompanion.insert(title: 'b'));
      final stale = (await repos.tasks.byId(a.id))!;
      await repos.tasks.reorder([(await repos.tasks.getAll()).last.id, a.id]);
      await repos.tasks.update(stale.copyWith(title: 'a2', notes: const Value('x')));
      expect(await titles(repos.tasks), ['b', 'a2']);
      expect((await repos.tasks.byId(a.id))!.createdAt, stale.createdAt);
    });

    test('delete returns the row and restore brings it back exactly', () async {
      final a = await repos.tasks.insert(TasksCompanion.insert(title: 'a', recurrence: const Value({'every': 'day'})));
      await repos.tasks.insert(TasksCompanion.insert(title: 'b'));
      final deleted = await repos.tasks.delete(a.id);
      expect(deleted!.id, a.id);
      expect(await repos.tasks.byId(a.id), isNull);
      expect(await repos.tasks.delete(a.id), isNull);

      await repos.tasks.restore(deleted);
      final back = (await repos.tasks.byId(a.id))!;
      expect(back.toColumns(false).toString(), a.toColumns(false).toString());
      expect(await titles(repos.tasks), ['a', 'b']);
      await repos.tasks.restore(deleted); // idempotent
      expect(await repos.tasks.count(), 2);
    });

    test('duplicate places the copy right after the original with new identity', () async {
      final a = await repos.tasks.insert(TasksCompanion.insert(title: 'a'));
      final b = await repos.tasks.insert(TasksCompanion.insert(title: 'b', isTop3: const Value(true)));
      await repos.tasks.insert(TasksCompanion.insert(title: 'c'));
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final copy = await repos.tasks.duplicate(b.id, overrides: {'title': 'b copy', 'window': PrayerWindow.isha});
      expect(copy.id, isNot(b.id));
      expect(copy.createdAt.isAfter(b.createdAt), isTrue);
      expect(copy.isTop3, isTrue);
      expect(copy.window, PrayerWindow.isha);
      expect(await titles(repos.tasks), ['a', 'b', 'b copy', 'c']);
      expect((await repos.tasks.byId(a.id))!.sortOrder, 0);
      expect(() => repos.tasks.duplicate('missing'), throwsStateError);
    });

    test('reorder keeps the view inside its slots and ignores unknown ids', () async {
      for (final t in ['a', 'b', 'c', 'd', 'e']) {
        await repos.tasks.insert(TasksCompanion.insert(title: t));
      }
      final all = await repos.tasks.getAll();
      String id(String title) => all.firstWhere((t) => t.title == title).id;
      // Reorder only b, d (a sub-view): they swap their slots 1 and 3.
      await repos.tasks.reorder([id('d'), 'unknown', id('b'), id('d')]);
      expect(await titles(repos.tasks), ['a', 'd', 'c', 'b', 'e']);
      await repos.tasks.reorder([id('e'), id('a'), id('d'), id('c'), id('b')]);
      expect(await titles(repos.tasks), ['e', 'a', 'd', 'c', 'b']);
      await repos.tasks.reorder(const []);
    });

    test('reorder spreads rows that share a sort order', () async {
      await db.batch((b) {
        for (final t in ['a', 'b', 'c']) {
          b.insert(db.tasks, TasksCompanion.insert(id: Value(t), title: t));
        }
      });
      await repos.tasks.reorder(['c', 'a', 'b']);
      final rows = await repos.tasks.getAll();
      expect(rows.map((r) => r.title), ['c', 'a', 'b']);
      expect(rows.map((r) => r.sortOrder), [0, 1, 2]);
    });

    test('setColumn moves between windows (enum value or name) and can append', () async {
      final a = await repos.tasks.insert(TasksCompanion.insert(title: 'a'));
      await repos.tasks.insert(TasksCompanion.insert(title: 'b'));
      await repos.tasks.setColumn(a.id, 'window', PrayerWindow.dhuhr, moveToEnd: true);
      var row = (await repos.tasks.byId(a.id))!;
      expect(row.window, PrayerWindow.dhuhr);
      expect(await titles(repos.tasks), ['b', 'a']);
      expect(row.updatedAt.isBefore(a.updatedAt), isFalse);

      await repos.tasks.setColumn(a.id, 'window', 'asr');
      await repos.tasks.setColumn(a.id, 'isTop3', true);
      await repos.tasks.setColumn(a.id, 'planet_key', 'work');
      await repos.tasks.setColumn(a.id, 'date', DateTime(2026, 10, 1));
      await repos.tasks.setColumn(a.id, 'recurrence', {'every': 'day'});
      row = (await repos.tasks.byId(a.id))!;
      expect(row.window, PrayerWindow.asr);
      expect(row.isTop3, isTrue);
      expect(row.planetKey, 'work');
      expect(row.date, DateTime(2026, 10, 1));
      expect(row.recurrence, {'every': 'day'});

      await repos.tasks.setColumns(a.id, {'recurrence': null, 'date': null});
      row = (await repos.tasks.byId(a.id))!;
      expect(row.recurrence, isNull);
      expect(row.date, isNull);
    });

    test('setColumn rejects bad input', () async {
      final a = await repos.tasks.insert(TasksCompanion.insert(title: 'a'));
      expect(() => repos.tasks.setColumn(a.id, 'nope', 1), throwsArgumentError);
      expect(() => repos.tasks.setColumn(a.id, 'title', null), throwsArgumentError);
      expect(() => repos.tasks.setColumn(a.id, 'priority', 'high'), throwsArgumentError);
      expect(() => repos.tasks.setColumn(a.id, 'id', 'x'), throwsArgumentError);
      expect((await repos.tasks.byId(a.id))!.title, 'a');
    });
  });

  group('Medications', () {
    test('CRUD, JSON lists, duplicate and undo', () async {
      final m = await repos.medications.insert(
        MedicationsCompanion.insert(name: 'A', times: const Value(['08:00']), kind: const Value(MedKind.supplement)),
      );
      await repos.medications.insert(MedicationsCompanion.insert(name: 'B'));
      await repos.medications.setColumn(m.id, 'times', ['08:00', '21:00']);
      await repos.medications.setColumn(m.id, 'doseAmount', 5); // int into a REAL column
      await repos.medications.setColumn(m.id, 'titration', jsonDecode('[{"from":"2026-10-01","dose":"5 mg"}]'));
      expect((await repos.medications.byId(m.id))!.titration, [
        {'from': '2026-10-01', 'dose': '5 mg'},
      ]);
      final updated = (await repos.medications.byId(m.id))!;
      expect(updated.times, ['08:00', '21:00']);
      expect(updated.doseAmount, 5.0);

      final copy = await repos.medications.duplicate(m.id, overrides: {'name': 'A (2)'});
      expect(copy.times, ['08:00', '21:00']);
      expect(copy.kind, MedKind.supplement);
      expect((await repos.medications.getAll()).map((r) => r.name), ['A', 'A (2)', 'B']);

      final deleted = (await repos.medications.delete(copy.id))!;
      expect((await repos.medications.getAll()).map((r) => r.name), ['A', 'B']);
      await repos.medications.restore(deleted);
      expect((await repos.medications.getAll()).map((r) => r.name), ['A', 'A (2)', 'B']);

      await repos.medications.update(updated.copyWith(active: false, stock: const Value(3)));
      final after = (await repos.medications.byId(m.id))!;
      expect(after.active, isFalse);
      expect(after.stock, 3);

      // A List<dynamic> from jsonDecode for a List<String> column.
      await repos.medications.setColumn(m.id, 'times', jsonDecode('["07:00", "19:30"]'));
      expect((await repos.medications.byId(m.id))!.times, ['07:00', '19:30']);
    });
  });

  group('BudgetItems', () {
    test('nested items: move to another parent and cascade undo', () async {
      final food = await repos.budgetItems.insert(BudgetItemsCompanion.insert(name: 'Food'));
      final home = await repos.budgetItems.insert(BudgetItemsCompanion.insert(name: 'Home'));
      final groceries = await repos.budgetItems.insert(
        BudgetItemsCompanion.insert(name: 'Groceries', parentId: Value(food.id), amountMilli: const Value(120000)),
      );
      await repos.budgetItems.insert(
        BudgetItemsCompanion.insert(
          name: 'Dining',
          parentId: Value(food.id),
          mode: const Value(BudgetMode.percent),
          percent: const Value(10),
        ),
      );

      await repos.budgetItems.setColumn(groceries.id, 'parentId', home.id, moveToEnd: true);
      expect((await repos.budgetItems.byId(groceries.id))!.parentId, home.id);
      await repos.budgetItems.setColumn(groceries.id, 'percentOf', PercentBase.total);
      expect((await repos.budgetItems.byId(groceries.id))!.percentOf, PercentBase.total);

      final removed = await repos.budgetItems.deleteWhere((t) => t.parentId.equals(food.id) | t.id.equals(food.id));
      expect(removed.map((r) => r.name), unorderedEquals(['Food', 'Dining']));
      expect((await repos.budgetItems.getAll()).map((r) => r.name), ['Home', 'Groceries']);

      await repos.budgetItems.restoreAll(removed);
      expect((await repos.budgetItems.getAll()).map((r) => r.name), ['Food', 'Home', 'Dining', 'Groceries']);
      final dining = (await repos.budgetItems.getAll(where: (t) => t.name.equals('Dining'))).single;
      expect(dining.mode, BudgetMode.percent);
      expect(dining.percent, 10.0);
    });
  });

  group('BoardCards', () {
    test('move a card between columns and reorder inside a column', () async {
      final board = await repos.boards.insert(BoardsCompanion.insert(name: 'Board'));
      Future<BoardCardRow> card(String title, [String column = 'todo']) =>
          repos.boardCards.insert(BoardCardsCompanion.insert(boardId: board.id, title: title, columnId: Value(column)));
      final a = await card('a');
      final b = await card('b');
      final c = await card('c', 'doing');
      final d = await card('d');

      Future<List<String>> column(String id) async =>
          (await repos.boardCards.getAll(where: (t) => t.boardId.equals(board.id) & t.columnId.equals(id)))
              .map((r) => r.title)
              .toList();

      expect(await column('todo'), ['a', 'b', 'd']);
      await repos.boardCards.setColumn(a.id, 'columnId', 'doing', moveToEnd: true);
      expect(await column('todo'), ['b', 'd']);
      expect(await column('doing'), ['c', 'a']);

      await repos.boardCards.reorder([a.id, c.id]);
      expect(await column('doing'), ['a', 'c']);
      expect(await column('todo'), ['b', 'd']);

      final copy = await repos.boardCards.duplicate(
        b.id,
        overrides: {'window': 'fajr', 'due_date': DateTime(2026, 12, 1)},
      );
      expect(copy.window, PrayerWindow.fajr);
      expect(copy.dueDate, DateTime(2026, 12, 1));
      expect(await column('todo'), ['b', 'b', 'd']);
      await repos.boardCards.setColumn(copy.id, 'window', null);
      expect((await repos.boardCards.byId(copy.id))!.window, isNull);
      expect(d.sortOrder, lessThan((await repos.boardCards.byId(d.id))!.sortOrder));
    });

    test('watchAll emits on changes', () async {
      final board = await repos.boards.insert(BoardsCompanion.insert(name: 'Board'));
      final emissions = <List<String>>[];
      final sub = repos.boardCards.watchAll().listen((rows) => emissions.add(rows.map((r) => r.title).toList()));
      addTearDown(sub.cancel);
      await pumpEventQueue();
      final a = await repos.boardCards.insert(BoardCardsCompanion.insert(boardId: board.id, title: 'a'));
      await pumpEventQueue();
      await repos.boardCards.setColumn(a.id, 'title', 'A');
      await pumpEventQueue();
      await repos.boardCards.delete(a.id);
      await pumpEventQueue();
      expect(emissions, [
        <String>[],
        ['a'],
        ['A'],
        <String>[],
      ]);
    });
  });

  group('Repositories', () {
    test('cover every Entity table and resolve Dart column names', () async {
      await populateAllTables(db);
      final entityTables = db.allTables
          .where((t) => t.columnsByName.containsKey('id') && t.columnsByName.containsKey('created_at'))
          .map((t) => t.actualTableName)
          .toSet();
      expect(repos.byTable.keys.toSet(), entityTables);
      expect(entityTables, hasLength(db.allTables.length - 2)); // key_values, currencies
      expect(repos.forTable('board_cards'), same(repos.boardCards));
      expect(repos.forTable('nope'), isNull);

      for (final repo in repos.byTable.values) {
        final rows = await repo.getAll();
        expect(rows, isNotEmpty, reason: repo.tableName);
        for (final dartName in rows.first.toJson().keys) {
          expect(() => repo.columnNamed(dartName), returnsNormally, reason: '${repo.tableName}.$dartName');
        }
      }
    });

    test('generic access through byTable works for Move/Delete/Undo', () async {
      final t = await repos.tasks.insert(TasksCompanion.insert(title: 'a'));
      final repo = repos.forTable('tasks')!;
      await repo.setColumn(t.id, 'window', 'maghrib');
      final deleted = await repo.delete(t.id);
      expect(await repos.tasks.byId(t.id), isNull);
      await repo.restore(deleted!);
      expect((await repos.tasks.byId(t.id))!.window, PrayerWindow.maghrib);
    });

    test('non-ordered tables append by time and refuse reorder', () async {
      final a = await repos.waterLogs.insert(WaterLogsCompanion.insert(at: DateTime(2026), ml: 250));
      expect(repos.waterLogs.isOrdered, isFalse);
      expect(() => repos.waterLogs.reorder([a.id]), throwsUnsupportedError);
      final copy = await repos.waterLogs.duplicate(a.id);
      expect(copy.ml, 250);
      expect(await repos.waterLogs.count(), 2);
    });

    test('snakeCase follows drift naming', () {
      expect(EntityRepository.snakeCase('isTop3'), 'is_top3');
      expect(EntityRepository.snakeCase('medAId'), 'med_a_id');
      expect(EntityRepository.snakeCase('toAmountMilli'), 'to_amount_milli');
      expect(EntityRepository.snakeCase('title'), 'title');
    });
  });
}
