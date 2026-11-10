import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/seed/seeder.dart' show SeedKeys;
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/import/import.dart';

String fixture(String name) => File('test/fixtures/import/$name.json').readAsStringSync();

final _now = DateTime(2026, 9, 6);
final _importer = PrototypeImporter(labels: ImportLabels.forLanguage('en'));

ImportPlan analyze(String json, {Map<String, ImportDuplicate> known = const {}}) =>
    _importer.analyze(json, now: _now, knownImports: known);

Future<int> countOf(MadarDatabase db, TableInfo<Table, Object?> table) async {
  final r = await db.customSelect('SELECT COUNT(*) AS c FROM "${table.actualTableName}"').getSingle();
  return r.read<int>('c');
}

void main() {
  group('analyze – nested English export (data + logs, by domain)', () {
    late ImportPlan plan;
    setUpAll(() => plan = analyze(fixture('prototype_nested_en')));

    test('detects the shape', () {
      final shape = plan.report.shape;
      expect(shape.container, ImportContainer.wrapped);
      expect(shape.domains, containsAll(['health', 'money', 'family', 'work', 'growth', 'body', 'travel']));
      expect(shape.nestedByDomain, isTrue);
      expect(shape.dayKeyedLogs, isTrue);
      expect(shape.meta['version'], 3);
      expect(plan.report.contentHash, hasLength(64));
    });

    test('counts per section', () {
      final r = plan.report;
      final expected = {
        ImportSection.currencies: 3,
        ImportSection.healthAlerts: 1,
        ImportSection.conditions: 1,
        ImportSection.medications: 4,
        ImportSection.medDoses: 2,
        ImportSection.labTests: 3,
        ImportSection.labReadings: 7,
        ImportSection.appointments: 1,
        ImportSection.doctorQuestions: 1,
        ImportSection.painEntries: 2,
        ImportSection.moodEntries: 2,
        ImportSection.habits: 1,
        ImportSection.habitLogs: 3,
        ImportSection.wallets: 3,
        ImportSection.budgetItems: 8,
        ImportSection.transactions: 5,
        ImportSection.jars: 1,
        ImportSection.jarDeposits: 1,
        ImportSection.debts: 1,
        ImportSection.obligations: 1,
        ImportSection.people: 2,
        ImportSection.contactLogs: 1,
        ImportSection.projects: 1,
        ImportSection.projectItems: 2,
        ImportSection.boards: 2,
        ImportSection.boardCards: 5,
        ImportSection.trips: 1,
        ImportSection.tripItems: 2,
        ImportSection.learningGoals: 1,
        ImportSection.exercises: 1,
        ImportSection.workoutLogs: 1,
        ImportSection.avoidItems: 2,
        ImportSection.fastingSessions: 1,
        ImportSection.waterLogs: 2,
        ImportSection.prayerLogs: 5,
        ImportSection.customModules: 1,
        ImportSection.customEntries: 2,
      };
      expected.forEach((section, n) => expect(r.count(section), n, reason: section.name));
      expect(r.totalPlanned, expected.values.fold<int>(0, (a, b) => a + b));
      expect(r.sections.values.every((s) => s.skipped == 0), isTrue);
    });

    test('reports settings, assumptions and leftovers', () {
      final r = plan.report;
      expect(r.settings['baseCurrency'], 'JOD');
      expect(r.settings['weeksPerMonth'], 4);
      expect((r.settings['rates'] as Map)['USD'], 0.709);
      final codes = r.issues.map((i) => i.code).toSet();
      expect(codes, containsAll([ImportIssueCode.assumedGlasses, ImportIssueCode.assumedFastingTarget, ImportIssueCode.assumedDate]));
      expect(codes, isNot(contains(ImportIssueCode.unparsedDate)));
      expect(codes, isNot(contains(ImportIssueCode.unresolvedReference)));
      expect(r.unmapped.map((u) => u.path), contains('data.theme'));
      expect(r.modules.single.name, 'Reading list');
      expect(r.modules.single.entries, 2);
      expect(r.isDuplicate, isFalse);
    });

    test('budget preview through BudgetMath', () {
      expect(plan.report.budgetTotalMilli, 350000);
      expect(plan.report.budgetCurrency, 'JOD');
      final math = plan.budget;
      expect(math.totalMonthlyMilli, 350000);
      expect(math.warnings, isEmpty);
      expect(math['imp.budgetItems.b1a']!.percentOfParent, closeTo(50, 1e-9));
    });

    test('ids are namespaced, stable and preserve source ids', () {
      final again = analyze(fixture('prototype_nested_en'));
      List<String> ids(ImportPlan p) => [
        for (final t in p.rows.all)
          for (final row in t.rows) '${row.toColumns(false)['id'] ?? row.toColumns(false)['code']}',
      ];
      expect(ids(again), ids(plan));
      expect(ids(plan), contains('Variable(imp.medications.m1)'));
      expect(ids(plan).toSet(), hasLength(ids(plan).length));
    });
  });

  group('commit – nested English export', () {
    late MadarDatabase db;
    late ImportPlan plan;
    late ImportReport report;

    setUpAll(() async {
      db = MadarDatabase(NativeDatabase.memory());
      plan = analyze(fixture('prototype_nested_en'));
      final progress = <double>[];
      report = await _importer.commit(db, plan, onProgress: progress.add);
      expect(progress.last, 1);
    });
    tearDownAll(() => db.close());

    test('writes every planned row', () async {
      expect(report.isCommitted, isTrue);
      expect(report.totalInserted, plan.report.totalPlanned);
      expect(report.totalExisting, 0);
      expect(await countOf(db, db.labReadings), 7);
      expect(await countOf(db, db.medications), 4);
      expect(await countOf(db, db.customEntries), 2);
    });

    test('every lab reading, linked to its test', () async {
      final tests = {for (final t in await db.select(db.labTests).get()) t.name: t};
      expect(tests.keys, containsAll(['HbA1c', 'Vitamin D (25-OH)', 'Ferritin']));
      final hba1c = tests['HbA1c']!;
      expect(hba1c.id, 'imp.labTests.t1');
      expect((hba1c.unit, hba1c.low, hba1c.high), ('%', 4.0, 5.6));
      expect((tests['Vitamin D (25-OH)']!.low, tests['Vitamin D (25-OH)']!.high), (30.0, 100.0));
      expect((tests['Ferritin']!.low, tests['Ferritin']!.high), (30.0, 400.0));

      Future<List<(DateTime, double?)>> readings(String testId) async {
        final rows = await (db.select(db.labReadings)
              ..where((r) => r.testId.equals(testId))
              ..orderBy([(r) => OrderingTerm.asc(r.date)]))
            .get();
        return [for (final r in rows) (r.date, r.value)];
      }

      expect(await readings(hba1c.id), [
        (DateTime(2026, 1, 10), 5.4),
        (DateTime(2026, 4, 12), 5.5),
        (DateTime(2026, 7, 15), 5.3),
      ]);
      expect(await readings(tests['Vitamin D (25-OH)']!.id), [(DateTime(2026, 2, 1), 22.0), (DateTime(2026, 6, 1), 34.0)]);
      // Readings are calendar days: an epoch timestamp keeps its local day.
      final epoch = DateTime.fromMillisecondsSinceEpoch(1780000000000);
      expect(await readings(tests['Ferritin']!.id), [
        (DateTime(2026, 3, 5), 18.0),
        (DateTime(epoch.year, epoch.month, epoch.day), 45.0),
      ]);
    });

    test('every med time and taken-with slot', () async {
      final meds = {for (final m in await db.select(db.medications).get()) m.name: m};
      expect(meds['Vitamin D']!.times, ['08:00']);
      expect(meds['Vitamin D']!.takenWith, TakenWith.breakfast);
      expect(meds['Vitamin D']!.kind, MedKind.supplement);
      expect((meds['Vitamin D']!.doseAmount, meds['Vitamin D']!.doseUnit), (1000.0, 'IU'));
      expect(meds['Omega 3']!.times, ['08:00', '20:00']);
      expect(meds['Omega 3']!.takenWith, TakenWith.dinner);
      expect(meds['Omega 3']!.dose, '2 caps');
      expect(meds['Magnesium']!.times, ['21:00']);
      expect(meds['Magnesium']!.takenWith, TakenWith.bedtime);
      expect(meds['Magnesium']!.stock, 40);
      expect(meds['Iron']!.times, ['07:30', '13:00']);
      expect(meds['Iron']!.takenWith, TakenWith.emptyStomach);

      final doses = await db.select(db.medDoses).get();
      final taken = doses.firstWhere((d) => d.status == DoseStatus.taken);
      expect(taken.medicationId, 'imp.medications.m1');
      expect(taken.takenAt, DateTime(2026, 9, 1, 8, 5));
      expect(doses.firstWhere((d) => d.status == DoseStatus.skipped).medicationId, 'imp.medications.m2');
    });

    test('the nested budget tree with parent links, totals and percentages', () async {
      final rows = await db.select(db.budgetItems).get();
      final byName = {for (final r in rows) r.name: r};
      final home = byName['Home food']!;
      for (final child in ['Proteins', 'Spices', 'Treats', 'Fruit & vegetables']) {
        expect(byName[child]!.parentId, home.id, reason: child);
      }
      expect(byName['Car fuel']!.parentId, isNull);
      expect(byName["Wife's allowance"]!.period, BudgetPeriod.weekly);
      expect(byName["Wife's allowance"]!.amountMilli, 5000);
      expect(byName['Emergency']!.amountMilli, 30000);
      expect(byName['Spices']!.sortOrder, 1);

      final weeks = await (db.select(db.keyValues)..where((k) => k.key.equals(BudgetSettings.weeksPerMonthKey))).getSingle();
      final math = BudgetMath(rows.map(budgetNodeFromRow), settings: BudgetSettings(weeksPerMonth: num.parse(weeks.value)));
      expect(math.totalMonthlyMilli, 350000);
      expect(math[home.id]!.childrenSumMilli, 200000);
      expect(math[byName['Proteins']!.id]!.percentOfParent, closeTo(50, 1e-9));
      expect(math[byName['Fruit & vegetables']!.id]!.percentOfParent, closeTo(25, 1e-9));
      expect(math[byName["Wife's allowance"]!.id]!.monthlyMilli, 20000);
      expect(math.warnings, isEmpty);
      expect(BudgetMath(rows.map(budgetNodeFromRow), settings: const BudgetSettings(weeksPerMonth: 4.345)).totalMonthlyMilli, 351725);
    });

    test('currency amounts in milli, per wallet currency', () async {
      final txs = {for (final t in await db.select(db.transactions).get()) t.id: t};
      expect(txs['imp.transactions.x1']!.amountMilli, 42750);
      expect(txs['imp.transactions.x1']!.budgetItemId, 'imp.budgetItems.b1a');
      expect(txs['imp.transactions.x2']!.walletId, 'imp.wallets.w1');
      expect(txs['imp.transactions.x2']!.budgetItemId, 'imp.budgetItems.b2');
      expect(txs['imp.transactions.x3']!.amountMilli, 19990);
      expect(txs['imp.transactions.x3']!.walletId, 'imp.wallets.w2');
      expect(txs['imp.transactions.x4']!.kind, TxKind.income);
      expect(txs['imp.transactions.x4']!.amountMilli, 500000);
      expect(txs['imp.transactions.x5']!.amountMilli, 150000);

      final wallets = {for (final w in await db.select(db.wallets).get()) w.id: w};
      expect(wallets['imp.wallets.w1']!.openingMilli, 150000);
      expect(wallets['imp.wallets.w2']!.currency, 'USD');
      // "balance" is after its transactions: 1 250.50 + 19.99 spent.
      expect(wallets['imp.wallets.w2']!.openingMilli, 1270490);
      final egp = wallets[txs['imp.transactions.x5']!.walletId]!;
      expect(egp.currency, 'EGP');
      expect(egp.name, 'Main wallet · EGP');

      final currencies = {for (final c in await db.select(db.currencies).get()) c.code: c};
      expect(currencies['JOD']!.isBase, isTrue);
      expect(currencies['USD']!.rateToBase, 0.709);
      expect(currencies['USD']!.decimals, 2);
      expect(currencies['JOD']!.decimals, 3);

      final jar = await db.select(db.jars).getSingle();
      expect(jar.targetMilli, 800000);
      final deposit = await db.select(db.jarDeposits).getSingle();
      expect((deposit.jarId, deposit.amountMilli, deposit.note), (jar.id, 120000, 'Opening balance'));
      final debt = await db.select(db.debts).getSingle();
      expect((debt.direction, debt.amountMilli), (DebtDirection.owedToMe, 40000));
      final bill = await db.select(db.obligations).getSingle();
      expect((bill.nextDue, bill.budgetItemId), (DateTime(2026, 9, 12), 'imp.budgetItems.b3'));
    });

    test('people, boards with columns, projects, trips, body', () async {
      final people = {for (final p in await db.select(db.people).get()) p.name: p};
      expect(people['Mother']!.rhythmDays, 7);
      expect(people['Brother']!.rhythmDays, 14);
      final call = await db.select(db.contactLogs).getSingle();
      expect((call.personId, call.channel), (people['Mother']!.id, ContactChannel.call));

      final cards = {for (final c in await db.select(db.boardCards).get()) c.title: c};
      expect(cards['Renew trade licence']!.columnId, 'todo');
      expect(cards['Quarterly report']!.columnId, 'doing');
      expect(cards['Hire a designer']!.columnId, 'done');
      expect(cards['Supplier contract']!.columnId, 'review');
      expect(cards['Supplier contract']!.boardId, 'imp.boards.bd2');
      final egypt = await (db.select(db.boards)..where((b) => b.id.equals('imp.boards.bd2'))).getSingle();
      expect(egypt.columns.map((c) => (c as Map)['id']), ['todo', 'doing', 'done', 'review']);

      final items = await db.select(db.projectItems).get();
      expect(items.map((i) => (i.body, i.done)), containsAll([('Buy shelves', true), ('Sort books', false)]));
      final trip = await db.select(db.trips).getSingle();
      expect((trip.status, trip.startDate), (TripStatus.planned, DateTime(2027, 4, 10)));
      expect((await db.select(db.tripItems).get()).map((i) => i.body), ['Passport', 'Charger']);
      final goal = await db.select(db.learningGoals).getSingle();
      expect((goal.target, goal.initial, goal.unit), (604.0, 120.0, 'pages'));
      final exercise = await db.select(db.exercises).getSingle();
      expect(exercise.weekdays, [1, 3, 5]);
      final workout = await db.select(db.workoutLogs).getSingle();
      expect((workout.exerciseId, workout.sets), (exercise.id, 3));
      expect((await db.select(db.avoidItems).get()).map((a) => a.body), ['Heavy lifting', 'Running on concrete']);
    });

    test('pain, mood, water, prayers, habits and fasting logs', () async {
      final pain = await (db.select(db.painEntries)..orderBy([(p) => OrderingTerm.asc(p.at)])).get();
      expect(pain.map((p) => (p.at, p.score)), [(DateTime(2026, 9, 1), 4), (DateTime(2026, 9, 2, 21), 6)]);
      expect(pain.map((p) => p.locations), [
        ['lower back'],
        ['knees', 'hips'],
      ]);
      expect(pain.first.triggers, ['sitting']);
      final mood = await (db.select(db.moodEntries)..orderBy([(m) => OrderingTerm.asc(m.at)])).get();
      expect(mood.map((m) => (m.mood, m.stress, m.sleepHours)), [(4, 3, 7.5), (3, 6, null)]);
      final water = await (db.select(db.waterLogs)..orderBy([(w) => OrderingTerm.asc(w.at)])).get();
      expect(water.map((w) => w.ml), [1500, 1750]);
      final prayers = {for (final p in await db.select(db.prayerLogs).get()) p.prayer: p};
      expect(prayers.values.every((p) => p.day == '2026-09-01'), isTrue);
      expect(prayers[Prayer.fajr]!.status, PrayerStatus.prayed);
      expect(prayers[Prayer.dhuhr]!.status, PrayerStatus.late);
      expect(prayers[Prayer.maghrib]!.inJamaah, isTrue);
      expect(prayers[Prayer.isha]!.status, PrayerStatus.missed);
      final habitLogs = await (db.select(db.habitLogs)..orderBy([(h) => OrderingTerm.asc(h.day)])).get();
      expect(habitLogs.map((h) => (h.day, h.done)), [('2026-08-30', true), ('2026-08-31', false), ('2026-09-01', true)]);
      final fast = await db.select(db.fastingSessions).getSingle();
      expect((fast.targetHours, fast.end), (16.0, DateTime(2026, 9, 2, 12)));
      final question = await db.select(db.doctorQuestions).getSingle();
      expect(question.appointmentId, 'imp.appointments.ap1');
      final appt = await db.select(db.appointments).getSingle();
      expect(appt.at, DateTime(2026, 10, 5, 10, 30));
    });

    test('the unknown section became a custom module', () async {
      final module = await db.select(db.customModules).getSingle();
      expect(module.name, 'Reading list');
      expect(module.kind, CustomModuleKind.list);
      expect(module.planetKey, 'growth');
      final fields = {for (final f in module.fields.cast<Map>()) f['label']: f};
      expect(fields['Title']!['type'], 'text');
      expect(fields['Author']!['type'], 'text');
      expect(fields['Rating']!['type'], 'rating');
      expect(fields['Started on']!['type'], 'date');
      final entries = await (db.select(db.customEntries)..orderBy([(e) => OrderingTerm.asc(e.sortOrder)])).get();
      expect(entries.map((e) => e.moduleId).toSet(), {module.id});
      expect(entries.map((e) => e.done), [true, false]);
      expect(entries.first.entryValues[fields['Title']!['id']], 'The Book of Healing');
      expect(entries.last.entryValues[fields['Rating']!['id']], 5);
    });

    test('the raw file is archived with the report', () async {
      final archive = await db.select(db.importArchive).getSingle();
      expect(archive.id, report.archiveId);
      expect(archive.raw, fixture('prototype_nested_en'));
      expect(archive.source, PrototypeImporter.archiveSource);
      expect(archive.summary['hash'], plan.report.contentHash);
      expect((archive.summary['leftovers'] as Map)['data.theme'], 'dark');
    });

    test('idempotent: re-importing the same file never duplicates', () async {
      final known = await PrototypeImporter.knownImports(db);
      final again = analyze(fixture('prototype_nested_en'), known: known);
      expect(again.report.isDuplicate, isTrue);
      expect(again.report.duplicate!.archiveId, report.archiveId);
      expect(again.report.issues.map((i) => i.code), contains(ImportIssueCode.duplicateFile));

      await expectLater(_importer.commit(db, again), throwsA(isA<ImportDuplicateException>()));
      final before = await countOf(db, db.labReadings);
      final forced = await _importer.commit(db, again, allowDuplicate: true);
      expect(forced.totalInserted, 0);
      expect(forced.totalExisting, again.report.totalPlanned);
      expect(await countOf(db, db.labReadings), before);
      expect(await countOf(db, db.budgetItems), 8);
      expect(await countOf(db, db.importArchive), 2);
    });
  });

  group('flat Arabic export (id-keyed maps, day-keyed log)', () {
    late MadarDatabase db;
    late ImportPlan plan;

    setUpAll(() async {
      db = MadarDatabase(NativeDatabase.memory());
      plan = analyze(fixture('prototype_flat_ar'));
      await _importer.commit(db, plan);
    });
    tearDownAll(() => db.close());

    test('shape and counts', () {
      final r = plan.report;
      expect(r.shape.container, ImportContainer.flat);
      expect(r.shape.keyStyle, ImportKeyStyle.arabic);
      expect(r.shape.idKeyedMaps, isTrue);
      expect(r.shape.dayKeyedLogs, isTrue);
      final expected = {
        ImportSection.medications: 3,
        ImportSection.labTests: 2,
        ImportSection.labReadings: 4,
        ImportSection.budgetItems: 8,
        ImportSection.wallets: 3,
        ImportSection.transactions: 4,
        ImportSection.people: 2,
        ImportSection.boards: 2,
        ImportSection.boardCards: 4,
        ImportSection.painEntries: 2,
        ImportSection.moodEntries: 2,
        ImportSection.waterLogs: 2,
        ImportSection.prayerLogs: 3,
        ImportSection.worries: 2,
        ImportSection.customModules: 1,
        ImportSection.customEntries: 2,
      };
      expected.forEach((section, n) => expect(r.count(section), n, reason: section.name));
      expect(r.unmapped.map((u) => u.path), contains('الوضع_الليلي'));
      expect(r.issues.map((i) => i.code), isNot(contains(ImportIssueCode.missingRequired)));
    });

    test('medications with Arabic times and slots', () async {
      final meds = {for (final m in await db.select(db.medications).get()) m.id: m};
      final d1 = meds['imp.medications.د1']!;
      expect((d1.name, d1.takenWith, d1.kind), ('فيتامين د', TakenWith.breakfast, MedKind.supplement));
      expect(d1.times, ['08:00']);
      final d2 = meds['imp.medications.د2']!;
      expect(d2.times, ['08:00', '20:00']);
      expect(d2.takenWith, TakenWith.dinner);
      final d3 = meds['imp.medications.د3']!;
      expect(d3.times, ['07:30']);
      expect((d3.takenWith, d3.doseAmount, d3.doseUnit), (TakenWith.emptyStomach, 65.0, 'ملغ'));
    });

    test('flat readings linked by id and by name', () async {
      final tests = {for (final t in await db.select(db.labTests).get()) t.name: t};
      final a1c = tests['السكر التراكمي']!;
      expect((a1c.low, a1c.high, a1c.unit), (4.0, 5.6, '%'));
      final readings = await (db.select(db.labReadings)..orderBy([(r) => OrderingTerm.asc(r.date)])).get();
      expect(readings.map((r) => (r.testId, r.date, r.value)), [
        (a1c.id, DateTime(2026, 1, 10), 5.4),
        (tests['فيتامين د']!.id, DateTime(2026, 2, 1), 22.0),
        (a1c.id, DateTime(2026, 4, 12), 5.5),
        (tests['فيتامين د']!.id, DateTime(2026, 6, 1), 34.0),
      ]);
    });

    test('budget written as nested maps', () async {
      final rows = await db.select(db.budgetItems).get();
      final byName = {for (final r in rows) r.name: r};
      final home = byName['طعام البيت']!;
      expect(home.amountMilli, 200000);
      for (final c in ['بروتينات', 'بهارات', 'حلويات', 'خضار وفواكه']) {
        expect(byName[c]!.parentId, home.id, reason: c);
      }
      expect((byName['مصروف الزوجة']!.amountMilli, byName['مصروف الزوجة']!.period), (5000, BudgetPeriod.weekly));
      final math = BudgetMath(rows.map(budgetNodeFromRow));
      expect(math.totalMonthlyMilli, 350000);
      expect(math[byName['بروتينات']!.id]!.percentOfParent, closeTo(50, 1e-9));
      expect(math.warnings, isEmpty);
    });

    test('Arabic amounts, currencies and wallets', () async {
      final txs = await db.select(db.transactions).get();
      final wallets = {for (final w in await db.select(db.wallets).get()) w.id: w};
      final proteins = (await db.select(db.budgetItems).get()).firstWhere((b) => b.name == 'بروتينات');
      final groceries = txs.firstWhere((t) => t.amountMilli == 42750);
      expect((groceries.kind, groceries.budgetItemId, groceries.walletId), (TxKind.expense, proteins.id, 'imp.wallets.م1'));
      final laptop = txs.firstWhere((t) => t.amountMilli == 1234500);
      expect(wallets[laptop.walletId]!.currency, 'USD');
      final egp = txs.firstWhere((t) => t.amountMilli == 300000);
      expect((egp.date, wallets[egp.walletId]!.currency), (DateTime(2026, 9, 4), 'EGP'));
      final salary = txs.firstWhere((t) => t.kind == TxKind.income);
      expect((salary.amountMilli, salary.note), (600000, 'راتب'));
      // Balance 700 after +600 − 42.75 → opening 142.750.
      expect(wallets['imp.wallets.م1']!.openingMilli, 142750);
    });

    test('kanban boards keyed by country, columns in Arabic', () async {
      final boards = {for (final b in await db.select(db.boards).get()) b.name: b};
      expect(boards.keys, containsAll(['الأردن', 'مصر']));
      final cards = {for (final c in await db.select(db.boardCards).get()) c.title: c};
      expect((cards['تجديد الرخصة']!.columnId, cards['تجديد الرخصة']!.boardId), ('todo', boards['الأردن']!.id));
      expect(cards['التقرير الربعي']!.columnId, 'doing');
      expect((cards['فتح حساب بنكي']!.columnId, cards['فتح حساب بنكي']!.boardId), ('done', boards['مصر']!.id));
      expect(cards['عقد المورد']!.columnId, 'todo');
    });

    test('a day-keyed log fans out into pain, mood, water and prayers', () async {
      final pain = await (db.select(db.painEntries)..orderBy([(p) => OrderingTerm.asc(p.at)])).get();
      expect(pain.map((p) => (p.at, p.score)), [(DateTime(2026, 9, 1), 4), (DateTime(2026, 9, 2), 2)]);
      expect(pain.map((p) => p.locations), [
        <String>[],
        ['الرقبة'],
      ]);
      final mood = await (db.select(db.moodEntries)..orderBy([(m) => OrderingTerm.asc(m.at)])).get();
      expect(mood.map((m) => (m.mood, m.stress, m.sleepHours, m.notes)), [(3, 6, 7.0, 'يوم طويل'), (4, null, null, null)]);
      final water = await (db.select(db.waterLogs)..orderBy([(w) => OrderingTerm.asc(w.at)])).get();
      expect(water.map((w) => w.ml), [2000, 1500]);
      final prayers = {for (final p in await db.select(db.prayerLogs).get()) p.prayer: p.status};
      expect(prayers, {Prayer.fajr: PrayerStatus.prayed, Prayer.dhuhr: PrayerStatus.late, Prayer.asr: PrayerStatus.prayed});
    });

    test('people, worries and the unknown list', () async {
      final people = {for (final p in await db.select(db.people).get()) p.name: p};
      expect((people['الوالدة']!.relation, people['الوالدة']!.rhythmDays), ('أم', 3));
      expect(people['صديق']!.lastContact, DateTime(2026, 8, 20));
      final worries = {for (final w in await db.select(db.worries).get()) w.body: w.resolved};
      expect(worries, {'موعد الامتحان': false, 'صيانة السيارة': true});
      final module = await db.select(db.customModules).getSingle();
      expect(module.name, 'قائمة الكتب');
      final types = {for (final f in module.fields.cast<Map>()) f['label']: f['type']};
      expect(types, {'العنوان': 'text', 'الصفحات': 'number', 'التقييم': 'rating'});
      expect((await db.select(db.customEntries).get()).map((e) => e.done), containsAll([true, false]));
    });
  });

  group('other shapes', () {
    test('invalid, empty and scalar input fail cleanly', () {
      expect(analyze('{not json').report.issues.single.code, ImportIssueCode.invalidJson);
      expect(analyze('   ').report.issues.single.code, ImportIssueCode.emptyInput);
      expect(analyze('{}').report.issues.single.code, ImportIssueCode.emptyInput);
      expect(analyze('42').report.issues.single.code, ImportIssueCode.notAnObject);
      expect(analyze('42').canCommit, isFalse);
    });

    test('typed event lists are dispatched by type', () {
      final plan = analyze('''
        {"logs": [
          {"type": "pain", "date": "2026-01-01", "score": 3},
          {"type": "water", "date": "2026-01-01", "ml": 500},
          {"type": "mood", "date": "2026-01-02", "mood": 4},
          {"type": "expense", "date": "2026-01-02", "amount": 7}
        ]}''');
      final r = plan.report;
      expect(r.shape.typedEventLists, isTrue);
      expect(r.shape.container, ImportContainer.logsOnly);
      expect([r.count(ImportSection.painEntries), r.count(ImportSection.waterLogs), r.count(ImportSection.moodEntries)], [1, 1, 1]);
      expect(r.count(ImportSection.transactions), 1);
    });

    test('flat readings create missing tests; panels fan out', () {
      final plan = analyze('''
        {"labResults": [
          {"test": "LDL", "date": "2026-01-01", "value": 120},
          {"date": "2026-02-01", "values": {"HbA1c": 5.4, "LDL": "118 mg/dL"}},
          {"test": "Urine protein", "date": "2026-02-01", "result": "negative"}
        ]}''');
      final r = plan.report;
      expect(r.count(ImportSection.labTests), 3);
      expect(r.count(ImportSection.labReadings), 4);
      expect(r.issues.where((i) => i.code == ImportIssueCode.createdReference), hasLength(3));
    });

    test('meds grouped by slot and budget percents', () {
      final plan = analyze('''
        {"meds": {"morning": [{"name": "A"}], "bedtime": ["B"]},
         "budget": [
           {"name": "Home", "amount": "1,000"},
           {"name": "Food", "parent": "Home", "percent": 60},
           {"name": "Rent", "parent": "Home", "amount": "50%"},
           {"name": "Savings", "percent": "10%", "of": "total"}
         ]}''');
      final meds = plan.rows.medications.rows.cast<MedicationsCompanion>();
      final a = meds.firstWhere((m) => m.name.value == 'A');
      final b = meds.firstWhere((m) => m.name.value == 'B');
      expect(a.times.value, ['08:00']);
      expect(b.takenWith.value, TakenWith.bedtime);
      expect(b.times.value, ['22:00']);
      final math = plan.budget;
      final byName = {for (final r in math.results.values) r.node.name: r};
      expect(byName['Food']!.monthlyMilli, 600000);
      expect(byName['Rent']!.monthlyMilli, 500000);
      expect(byName['Rent']!.node.mode, BudgetMode.percent);
      // T = 1000 + 0.1 T → 1 111.111
      expect(math.totalMonthlyMilli, 1111111);
      expect(
        plan.report.issues.where((i) => i.code == ImportIssueCode.budget).map((i) => i.args['kind']),
        contains(BudgetWarningKind.childrenOver.name),
      );
    });

    test('a seeded database: placeholder rates take the file\'s, new currencies warn', () async {
      final db = await openInMemoryMadarDatabase();
      addTearDown(db.close);
      final plan = analyze('''
        {"settings": {"rates": {"USD": 0.71}},
         "wallets": [{"name": "Riyal wallet", "currency": "SAR"}],
         "transactions": [{"wallet": "Riyal wallet", "amount": 10, "date": "2026-01-01"}]}''');
      final report = await _importer.commit(db, plan);
      final currencies = {for (final c in await db.select(db.currencies).get()) c.code: c};
      expect(currencies['JOD']!.isBase, isTrue);
      expect(currencies['USD']!.rateToBase, 0.71);
      expect((currencies['SAR']!.rateToBase, currencies['SAR']!.decimals, currencies['SAR']!.isBase), (1.0, 2, false));
      expect(report.issues.where((i) => i.code == ImportIssueCode.missingRate).map((i) => i.detail), ['SAR']);
      final tx = await db.select(db.transactions).getSingle();
      expect(tx.amountMilli, 10000);
    });

    test('a file with nothing recognisable is still archived as a module or leftover', () async {
      final db = MadarDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final plan = analyze('{"favouriteColours": ["teal", "gold"], "pets": [{"name": "Cat", "age": 3}]}');
      expect(plan.report.modules.single.name, 'Pets');
      expect(plan.report.unmapped.single.path, 'favouriteColours');
      final report = await _importer.commit(db, plan);
      expect(report.archiveId, isNotNull);
      expect(await countOf(db, db.importArchive), 1);
      expect(await countOf(db, db.customEntries), 1);
    });
  });

  group('regressions – locator', () {
    test('a budget category named like another section stays in the budget (Arabic)', () {
      final plan = analyze('{"الميزانية": {"طعام البيت": {"المبلغ": 200, "بروتينات": 100}, "ادخار": {"المبلغ": 50}}}');
      final r = plan.report;
      expect(r.count(ImportSection.budgetItems), 3);
      expect(r.count(ImportSection.jars), 0);
      expect(r.issues.where((i) => i.code == ImportIssueCode.missingRequired), isEmpty);
      final byName = {for (final x in plan.budget.results.values) x.node.name: x};
      expect(byName.keys, containsAll(['طعام البيت', 'بروتينات', 'ادخار']));
      expect(byName['ادخار']!.monthlyMilli, 50000);
      expect(byName['بروتينات']!.node.parentId, byName['طعام البيت']!.node.id);
      expect(plan.budget.totalMonthlyMilli, 250000);
    });

    test('a budget category named like another section stays in the budget (English)', () {
      final plan = analyze('{"budget": {"Bills": {"amount": 50}, "Food": 100}}');
      final r = plan.report;
      expect(r.count(ImportSection.budgetItems), 2);
      expect(r.count(ImportSection.obligations), 0);
      expect(plan.budget.totalMonthlyMilli, 150000);
    });

    test('only colliding category names with amounts are still a budget', () {
      final plan = analyze('{"budget": {"Bills": {"amount": 50}, "Savings": {"amount": 20}}}');
      expect(plan.report.count(ImportSection.budgetItems), 2);
      expect(plan.report.count(ImportSection.jars), 0);
      expect(plan.budget.totalMonthlyMilli, 70000);
    });

    test('a budget key holding other sections is still walked as a container', () {
      final plan = analyze('''
        {"budget": {
          "wallets": [{"name": "Cash", "currency": "JOD", "balance": 10}],
          "transactions": [{"wallet": "Cash", "amount": 5, "date": "2026-01-01", "type": "expense"}]
        }}''');
      final r = plan.report;
      expect(r.count(ImportSection.wallets), 1);
      expect(r.count(ImportSection.transactions), 1);
      expect(r.count(ImportSection.budgetItems), 0);
    });

    test('boards keyed by country with only card lists (English)', () {
      final plan = analyze('''
        {"work": {"Jordan": [{"title": "A", "status": "todo"}], "Egypt": [{"title": "B"}]}}''');
      final r = plan.report;
      expect(r.count(ImportSection.boards), 2);
      expect(r.count(ImportSection.boardCards), 2);
      final boards = plan.rows.boards.rows.cast<BoardsCompanion>();
      expect(boards.map((b) => b.name.value), ['Jordan', 'Egypt']);
      expect(boards.map((b) => b.country.value), ['Jordan', 'Egypt']);
      final cards = plan.rows.boardCards.rows.cast<BoardCardsCompanion>();
      expect(cards.map((c) => c.title.value), ['A', 'B']);
      final byId = {for (final b in boards) b.id.value: b.name.value};
      expect(cards.map((c) => byId[c.boardId.value]), ['Jordan', 'Egypt']);
      expect(r.issues.where((i) => i.code == ImportIssueCode.missingRequired), isEmpty);
    });

    test('boards keyed by country with only card lists (Arabic)', () {
      final plan = analyze('''
        {"عمل": {"الأردن": [{"العنوان": "تجديد الرخصة", "الحالة": "جديد"}, {"العنوان": "فتح حساب"}]}}''');
      final r = plan.report;
      expect(r.count(ImportSection.boards), 1);
      expect(r.count(ImportSection.boardCards), 2);
      final board = plan.rows.boards.rows.cast<BoardsCompanion>().single;
      expect((board.name.value, board.country.value), ('الأردن', 'الأردن'));
      expect(r.issues.where((i) => i.code == ImportIssueCode.missingRequired), isEmpty);
    });
  });

  group('regressions – mapping and commit', () {
    test('Libyan and Kuwaiti dinar symbols pick the right wallet currency', () {
      final plan = analyze('''
        {"wallets": [
          {"name": "Tripoli", "currency": "ل.د", "balance": "100 ل.د"},
          {"name": "Kuwait", "balance": "12 د.ك"}
        ]}''');
      final wallets = {for (final w in plan.rows.wallets.rows.cast<WalletsCompanion>()) w.name.value: w};
      expect(wallets['Tripoli']!.currency.value, 'LYD');
      expect(wallets['Tripoli']!.openingMilli.value, 100000);
      expect(plan.rows.currencies.rows.cast<CurrenciesCompanion>().map((c) => c.code.value), containsAll(['LYD', 'KWD']));
    });

    test('an unknown currency value is reported, never guessed', () {
      final plan = analyze('{"wallets": [{"name": "Box", "currency": "Table"}]}');
      final w = plan.rows.wallets.rows.cast<WalletsCompanion>().single;
      expect(w.currency.value, 'JOD');
      expect(
        plan.report.issues.where((i) => i.code == ImportIssueCode.unknownValue).map((i) => i.detail),
        contains('Table'),
      );
    });

    test('a wallet group name is only a currency when it is exactly one', () {
      final plan = analyze('{"wallets": {"Mobile": [{"name": "Phone wallet"}], "USD": [{"name": "Dollars"}]}}');
      final wallets = {for (final w in plan.rows.wallets.rows.cast<WalletsCompanion>()) w.name.value: w.currency.value};
      expect(wallets, {'Phone wallet': 'JOD', 'Dollars': 'USD'});
    });

    test('negative adjustments keep their sign: opening 120, balance 100', () async {
      final db = MadarDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final plan = analyze('''
        {"wallets": [{"id": "w", "name": "Cash", "currency": "JOD", "balance": 100}],
         "transactions": [{"wallet": "w", "type": "adjustment", "amount": -20, "date": "2026-01-01"}]}''');
      await _importer.commit(db, plan);
      final wallet = await db.select(db.wallets).getSingle();
      final tx = await db.select(db.transactions).getSingle();
      expect(tx.kind, TxKind.adjustment);
      expect(tx.amountMilli, -20000);
      expect(wallet.openingMilli, 120000);
      // The app's balance: opening + income + adjustments − expenses − transfers out.
      final txs = await db.select(db.transactions).get();
      final net = txs.fold<int>(
        0,
        (a, t) =>
            a +
            switch (t.kind) {
              TxKind.income || TxKind.adjustment => t.amountMilli,
              TxKind.expense || TxKind.transfer => -t.amountMilli,
            },
      );
      expect(wallet.openingMilli + net, 100000);
    });

    test('positive adjustments stay positive', () {
      final plan = analyze('{"transactions": [{"type": "adjustment", "amount": 20, "date": "2026-01-01"}]}');
      expect(plan.rows.transactions.rows.cast<TransactionsCompanion>().single.amountMilli.value, 20000);
    });

    test('a signed debt list keeps its directions', () {
      final plan = analyze('{"debts": [{"person": "Ali", "amount": -50}, {"person": "Omar", "amount": 70}]}');
      final debts = {for (final d in plan.rows.debts.rows.cast<DebtsCompanion>()) d.person.value: d};
      expect(debts['Ali']!.direction.value, DebtDirection.iOwe);
      expect(debts['Omar']!.direction.value, DebtDirection.owedToMe);
      expect(debts['Ali']!.amountMilli.value, 50000);
      expect(debts['Omar']!.amountMilli.value, 70000);
      expect(
        plan.report.issues.where((i) => i.code == ImportIssueCode.assumedValue && i.section == ImportSection.debts),
        hasLength(2),
      );
    });

    test('unsigned debts without a direction default to "I owe"; explicit directions win', () {
      final plan = analyze('''
        {"debts": [{"person": "Ali", "amount": 50}, {"person": "Omar", "amount": -70, "direction": "owed to me"}]}''');
      final debts = {for (final d in plan.rows.debts.rows.cast<DebtsCompanion>()) d.person.value: d.direction.value};
      expect(debts, {'Ali': DebtDirection.iOwe, 'Omar': DebtDirection.owedToMe});
    });

    test('a test value without a date becomes a reading dated the export day', () {
      final plan = analyze('''
        {"exportedAt": "2026-03-01",
         "labs": [{"name": "HbA1c", "value": 5.4}, {"name": "LDL", "value": 120, "date": "2026-01-01"}]}''');
      final r = plan.report;
      expect(r.count(ImportSection.labTests), 2);
      expect(r.count(ImportSection.labReadings), 2);
      expect(r.issues.where((i) => i.code == ImportIssueCode.missingRequired), isEmpty);
      expect(
        r.issues.where((i) => i.code == ImportIssueCode.assumedDate && i.section == ImportSection.labReadings),
        hasLength(1),
      );
      final readings = plan.rows.labReadings.rows.cast<LabReadingsCompanion>().toList();
      final hba1c = readings.firstWhere((x) => x.value.value == 5.4);
      expect((hba1c.date.value.year, hba1c.date.value.month, hba1c.date.value.day), (2026, 3, 1));
    });

    test('a test value without any date uses today', () {
      final plan = analyze('{"labs": [{"name": "HbA1c", "value": 5.4}]}');
      final reading = plan.rows.labReadings.rows.cast<LabReadingsCompanion>().single;
      expect((reading.date.value.year, reading.date.value.month, reading.date.value.day), (_now.year, _now.month, _now.day));
    });

    test('labs keyed by name with day-keyed values keep every reading', () {
      final plan = analyze('{"labs": {"LDL": {"unit": "mg/dL", "2026-01-01": 120, "2026-02-01": 110}}}');
      final r = plan.report;
      expect(r.count(ImportSection.labTests), 1);
      expect(r.count(ImportSection.labReadings), 2);
      expect(r.unmapped, isEmpty);
      final test = plan.rows.labTests.rows.cast<LabTestsCompanion>().single;
      expect((test.name.value, test.unit.value), ('LDL', 'mg/dL'));
      final readings = plan.rows.labReadings.rows.cast<LabReadingsCompanion>().toList();
      expect(readings.map((x) => x.value.value), [120, 110]);
      expect(readings.every((x) => x.testId.value == test.id.value), isTrue);
    });

    test('a file based on another currency is rebased to the database base', () async {
      final db = await openInMemoryMadarDatabase();
      addTearDown(db.close);
      final plan = analyze(
        '{"settings": {"baseCurrency": "USD", "rates": {"SAR": 0.2667}}, "wallets": [{"name": "R", "currency": "SAR"}]}',
      );
      final report = await _importer.commit(db, plan);
      final currencies = {for (final c in await db.select(db.currencies).get()) c.code: c};
      expect(currencies['JOD']!.isBase, isTrue);
      expect(currencies['SAR']!.rateToBase, closeTo(0.2667 * 0.709, 1e-9));
      expect(report.issues.where((i) => i.code == ImportIssueCode.missingRate), isEmpty);
    });

    test("rebasing uses the file's own rate for the database base", () async {
      final db = await openInMemoryMadarDatabase();
      addTearDown(db.close);
      final plan = analyze(
        '{"settings": {"baseCurrency": "EUR", "rates": {"JOD": 1.25, "SAR": 0.25}}, "wallets": [{"name": "R", "currency": "SAR"}]}',
      );
      final report = await _importer.commit(db, plan);
      final currencies = {for (final c in await db.select(db.currencies).get()) c.code: c};
      expect(currencies['EUR']!.rateToBase, closeTo(0.8, 1e-9));
      expect(currencies['SAR']!.rateToBase, closeTo(0.2, 1e-9));
      expect(currencies['JOD']!.rateToBase, 1.0);
      expect(report.issues.where((i) => i.code == ImportIssueCode.missingRate), isEmpty);
    });

    test('an unknown rebase factor warns for every affected currency', () async {
      final db = await openInMemoryMadarDatabase();
      addTearDown(db.close);
      final plan = analyze(
        '{"settings": {"baseCurrency": "EUR", "rates": {"SAR": 0.25}}, "wallets": [{"name": "R", "currency": "SAR"}]}',
      );
      final report = await _importer.commit(db, plan);
      final currencies = {for (final c in await db.select(db.currencies).get()) c.code: c};
      expect(currencies['SAR']!.rateToBase, 1.0);
      expect(currencies['EUR']!.rateToBase, 1.0);
      expect(report.issues.where((i) => i.code == ImportIssueCode.missingRate).map((i) => i.detail).toSet(), {'SAR', 'EUR'});
    });

    test('file rates written over the placeholders clear the placeholder marker', () async {
      final db = await openInMemoryMadarDatabase();
      addTearDown(db.close);
      Future<bool> flagged() async =>
          await (db.select(db.keyValues)..where((t) => t.key.equals(SeedKeys.currencyRatesAreDefaults))).getSingleOrNull() !=
          null;
      expect(await flagged(), isTrue);
      await _importer.commit(db, analyze('{"settings": {"rates": {"USD": 0.71}}}'));
      expect(await flagged(), isFalse);
      // A later file no longer overwrites the (now real) rates.
      await _importer.commit(db, analyze('{"settings": {"rates": {"USD": 0.5}}}'));
      final usd = await (db.select(db.currencies)..where((t) => t.code.equals('USD'))).getSingle();
      expect(usd.rateToBase, 0.71);
    });

    test('imported rows are appended after the rows already there', () async {
      final db = await openInMemoryMadarDatabase();
      addTearDown(db.close);
      final seeded = await db.select(db.habits).get();
      expect(seeded, isNotEmpty);
      await _importer.commit(db, analyze('{"habits": ["Read Quran", "Walk 10k", "No sugar"]}'));
      final all = await (db.select(db.habits)
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.createdAt)]))
          .get();
      expect(all.map((h) => h.name).skip(seeded.length), ['Read Quran', 'Walk 10k', 'No sugar']);
      expect(all.map((h) => h.sortOrder).toSet(), hasLength(all.length));
    });

    test('imported children keep their order under their parent', () async {
      final db = await openInMemoryMadarDatabase();
      addTearDown(db.close);
      await _importer.commit(db, analyze('{"budget": [{"name": "Old", "amount": 1}]}'));
      await _importer.commit(
        db,
        analyze('{"budget": [{"name": "Home", "children": [{"name": "A", "amount": 1}, {"name": "B", "amount": 2}]}]}'),
      );
      final byName = {for (final r in await db.select(db.budgetItems).get()) r.name: r};
      expect(byName['Home']!.sortOrder, greaterThan(byName['Old']!.sortOrder));
      expect(byName['A']!.sortOrder, lessThan(byName['B']!.sortOrder));
    });
  });
}
