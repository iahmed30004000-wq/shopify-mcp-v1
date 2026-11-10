import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/data/data/data_repository.dart';
import 'package:madar/features/data/domain/csv_export.dart';
import 'package:madar/features/data/domain/export_range.dart';
import 'package:madar/features/data/domain/plain_numbers.dart';

final en = lookupL10n(const Locale('en'));
final ar = lookupL10n(const Locale('ar'));
final now = DateTime(2026, 9, 30, 10);

/// Parses RFC 4180 text back into rows (quotes, doubled quotes, CRLF).
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
      i++;
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) rows.add([...row, field.toString()]);
  return rows;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('CsvText / CsvTable', () {
    test('RFC 4180 quoting', () {
      expect(CsvText.field('plain'), 'plain');
      expect(CsvText.field('a,b'), '"a,b"');
      expect(CsvText.field('say "hi"'), '"say ""hi"""');
      expect(CsvText.field('line1\nline2'), '"line1\nline2"');
      expect(CsvText.field('عربي، نص'), 'عربي، نص'); // Arabic comma is not a separator
    });

    test('formula injection guard on text cells only', () {
      expect(CsvText.field('=SUM(A1)', guardFormula: true), "'=SUM(A1)");
      expect(CsvText.field('+1', guardFormula: true), "'+1");
      expect(CsvText.field('@cmd', guardFormula: true), "'@cmd");
      expect(CsvText.field('-3 kg', guardFormula: true), "'-3 kg");
      expect(CsvText.field('-12.500'), '-12.500');
      const table = CsvTable(header: ['n', 't'], rows: [['-5', '=1+1']], textColumns: {1});
      expect(table.encode(), "n,t\r\n-5,'=1+1\r\n");
    });

    test('bytes carry a UTF-8 BOM and CRLF line ends', () {
      const table = CsvTable(header: ['التاريخ', 'x'], rows: [['2026-09-30', null]]);
      final bytes = table.encodeBytes();
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bytes.sublist(3)), 'التاريخ,x\r\n2026-09-30,\r\n');
    });
  });

  group('PlainNumbers', () {
    test('decimals use a point, no grouping, trailing zeros dropped', () {
      expect(PlainNumbers.decimal(5), '5');
      expect(PlainNumbers.decimal(5.0), '5');
      expect(PlainNumbers.decimal(6.25), '6.25');
      expect(PlainNumbers.decimal(1234567.5), '1234567.5');
      expect(PlainNumbers.decimal(-0.0001, maxDecimals: 2), '0');
      expect(PlainNumbers.decimal(double.nan), '');
      expect(PlainNumbers.decimal(1 / 3, maxDecimals: 3), '0.333');
    });

    test('milli-unit amounts keep the currency decimals', () {
      expect(PlainNumbers.milli(12500, decimals: 3), '12.500');
      expect(PlainNumbers.milli(-12500, decimals: 3), '-12.500');
      expect(PlainNumbers.milli(3505, decimals: 2), '3.51');
      expect(PlainNumbers.milli(-3505, decimals: 2), '-3.51');
      expect(PlainNumbers.milli(120000, decimals: 0), '120');
      expect(PlainNumbers.milli(4, decimals: 2), '0.00');
      expect(PlainNumbers.milli(-4, decimals: 2), '0.00');
      expect(PlainNumbers.percent(1, 4), 25);
      expect(PlainNumbers.percent(1, 0), isNull);
    });
  });

  group('ExportDateRange', () {
    test('presets are inclusive calendar days', () {
      final r = ExportDateRange.forPreset(ExportRangePreset.days30, now);
      expect(r.from, DateTime(2026, 9, 1));
      expect(r.to, DateTime(2026, 9, 30));
      expect(r.contains(DateTime(2026, 9, 1, 0, 0)), isTrue);
      expect(r.contains(DateTime(2026, 9, 30, 23, 59)), isTrue);
      expect(r.contains(DateTime(2026, 8, 31, 23, 59)), isFalse);
      expect(r.contains(DateTime(2026, 10, 1)), isFalse);
      expect(r.fileTag, '2026-09-01_2026-09-30');
      expect(ExportDateRange.all.contains(DateTime(1990)), isTrue);
      expect(ExportDateRange.all.fileTag, 'all');
      expect(ExportDateRange.forPreset(ExportRangePreset.year, now).from, DateTime(2025, 10, 1));
    });
  });

  group('tables from the database', () {
    late MadarDatabase db;
    late DataExportRepository repo;

    setUp(() async {
      db = MadarDatabase(NativeDatabase.memory());
      repo = DataExportRepository(db, useIsolate: false);
      await db.batch((b) {
        b.insertAll(db.currencies, [
          CurrenciesCompanion.insert(code: 'JOD', nameAr: 'دينار', nameEn: 'Dinar', symbol: 'JD', decimals: const Value(3), isBase: const Value(true)),
          CurrenciesCompanion.insert(code: 'USD', nameAr: 'دولار', nameEn: 'Dollar', symbol: r'$', decimals: const Value(2), rateToBase: const Value(0.709)),
          CurrenciesCompanion.insert(code: 'EGP', nameAr: 'جنيه', nameEn: 'Pound', symbol: 'E£', decimals: const Value(2), rateToBase: const Value(0)),
        ]);
        b.insertAll(db.wallets, [
          WalletsCompanion.insert(id: const Value('w-cash'), name: 'Cash, home', currency: 'JOD'),
          WalletsCompanion.insert(id: const Value('w-usd'), name: 'USD card', currency: 'USD'),
          WalletsCompanion.insert(id: const Value('w-egp'), name: 'Cairo', currency: 'EGP'),
        ]);
        b.insertAll(db.budgetItems, [
          BudgetItemsCompanion.insert(id: const Value('b-food'), name: 'Food'),
          BudgetItemsCompanion.insert(id: const Value('b-rest'), name: 'Restaurants', parentId: const Value('b-food')),
        ]);
        b.insertAll(db.transactions, [
          TransactionsCompanion.insert(
            id: const Value('t1'),
            walletId: 'w-cash',
            kind: TxKind.expense,
            amountMilli: 12500,
            date: DateTime(2026, 9, 29),
            budgetItemId: const Value('b-rest'),
            note: const Value('=HYPERLINK("x")'),
            tags: const Value(['family', 'weekend']),
          ),
          TransactionsCompanion.insert(id: const Value('t2'), walletId: 'w-usd', kind: TxKind.income, amountMilli: 100000, date: DateTime(2026, 9, 10)),
          TransactionsCompanion.insert(
            id: const Value('t3'),
            walletId: 'w-usd',
            kind: TxKind.transfer,
            amountMilli: 50000,
            toWalletId: const Value('w-cash'),
            toAmountMilli: const Value(35450),
            date: DateTime(2026, 9, 11),
          ),
          TransactionsCompanion.insert(id: const Value('t4'), walletId: 'w-cash', kind: TxKind.adjustment, amountMilli: -2000, date: DateTime(2026, 9, 12)),
          TransactionsCompanion.insert(id: const Value('t5'), walletId: 'w-egp', kind: TxKind.expense, amountMilli: 300000, date: DateTime(2026, 9, 13)),
          TransactionsCompanion.insert(id: const Value('old'), walletId: 'w-cash', kind: TxKind.expense, amountMilli: 1000, date: DateTime(2025, 1, 1)),
        ]);
        b.insertAll(db.labTests, [
          LabTestsCompanion.insert(id: const Value('lt-a1c'), name: 'HbA1c', unit: const Value('%'), low: const Value(4), high: const Value(5.6), category: const Value('Diabetes')),
          LabTestsCompanion.insert(id: const Value('lt-crp'), name: 'CRP', unit: const Value('mg/L'), high: const Value(5)),
          LabTestsCompanion.insert(id: const Value('lt-urine'), name: 'Urine protein'),
        ]);
        b.insertAll(db.labReadings, [
          LabReadingsCompanion.insert(testId: 'lt-a1c', date: DateTime(2026, 9, 1), value: const Value(6.1)),
          LabReadingsCompanion.insert(testId: 'lt-a1c', date: DateTime(2026, 3, 1), value: const Value(5.55), note: const Value('fasting, morning')),
          LabReadingsCompanion.insert(testId: 'lt-crp', date: DateTime(2026, 9, 2), value: const Value(2)),
          LabReadingsCompanion.insert(testId: 'lt-urine', date: DateTime(2026, 9, 3), valueText: const Value('negative')),
        ]);
        b.insertAll(db.painEntries, [
          PainEntriesCompanion.insert(at: DateTime(2026, 9, 29, 8, 5), score: 6, locations: const Value(['knee', 'lower back']), triggers: const Value(['stairs']), notes: const Value('after "long" walk')),
          PainEntriesCompanion.insert(at: DateTime(2026, 9, 28, 21, 40), score: 3, bodyPoints: const Value([{'x': 0.4, 'y': 0.3}])),
        ]);
        b.insertAll(db.moodEntries, [
          MoodEntriesCompanion.insert(at: DateTime(2026, 9, 29, 22), mood: const Value(4), stress: const Value(3), sleepHours: const Value(7.5), caffeineCups: const Value(2), factors: const Value(['work'])),
          MoodEntriesCompanion.insert(at: DateTime(2026, 9, 30, 7)),
        ]);
      });
    });

    tearDown(() => db.close());

    test('labs: test, unit, range and flag per reading, oldest first', () async {
      final t = await repo.csvTable(DataCsvKind.labs, en);
      expect(t.header, ['date', 'test', 'category', 'value', 'text_result', 'unit', 'range_low', 'range_high', 'flag', 'note']);
      final rows = parseCsv(t.encode()).skip(1).toList();
      expect(rows, [
        ['2026-03-01', 'HbA1c', 'Diabetes', '5.55', '', '%', '4', '5.6', 'borderline high', 'fasting, morning'],
        ['2026-09-01', 'HbA1c', 'Diabetes', '6.1', '', '%', '4', '5.6', 'high', ''],
        ['2026-09-02', 'CRP', '', '2', '', 'mg/L', '', '5', 'in range', ''],
        ['2026-09-03', 'Urine protein', '', '', 'negative', '', '', '', '', ''],
      ]);
      final recent = await repo.csvTable(DataCsvKind.labs, en, range: ExportDateRange(from: DateTime(2026, 9, 2), to: DateTime(2026, 9, 30)));
      expect(recent.rows.map((r) => r[1]), ['CRP', 'Urine protein']);
    });

    test('transactions: signed amounts in wallet currency and base', () async {
      final t = await repo.csvTable(DataCsvKind.transactions, en, range: ExportDateRange.forPreset(ExportRangePreset.days30, now));
      expect(t.header, [
        'date', 'kind', 'wallet', 'currency', 'amount', 'amount_base', 'base_currency', 'budget_item', 'to_wallet', 'to_amount', 'to_currency', 'note', 'tags',
      ]);
      final rows = parseCsv(t.encode()).skip(1).toList();
      expect(rows, [
        ['2026-09-10', 'income', 'USD card', 'USD', '100.00', '70.900', 'JOD', '', '', '', '', '', ''],
        ['2026-09-11', 'transfer', 'USD card', 'USD', '-50.00', '-35.450', 'JOD', '', 'Cash, home', '35.450', 'JOD', '', ''],
        ['2026-09-12', 'adjustment', 'Cash, home', 'JOD', '-2.000', '-2.000', 'JOD', '', '', '', '', '', ''],
        // No usable EGP rate: the base column stays empty rather than wrong.
        ['2026-09-13', 'expense', 'Cairo', 'EGP', '-300.00', '', 'JOD', '', '', '', '', '', ''],
        ['2026-09-29', 'expense', 'Cash, home', 'JOD', '-12.500', '-12.500', 'JOD', 'Food › Restaurants', '', '', '', "'=HYPERLINK(\"x\")", 'family; weekend'],
      ]);
      final all = await repo.csvTable(DataCsvKind.transactions, en);
      expect(all.rows.first[0], '2025-01-01');
    });

    test('pain and mood: ISO date + time, numbers, lists', () async {
      final pain = parseCsv((await repo.csvTable(DataCsvKind.pain, en)).encode());
      expect(pain[0], ['date', 'time', 'score_0_10', 'locations', 'triggers', 'body_points', 'notes']);
      expect(pain.skip(1).toList(), [
        ['2026-09-28', '21:40', '3', '', '', '1', ''],
        ['2026-09-29', '08:05', '6', 'knee; lower back', 'stairs', '0', 'after "long" walk'],
      ]);
      final mood = parseCsv((await repo.csvTable(DataCsvKind.mood, en)).encode());
      expect(mood[0], ['date', 'time', 'mood_1_5', 'stress_0_10', 'anxiety_0_10', 'energy_0_10', 'sleep_hours', 'caffeine_cups', 'factors', 'notes']);
      expect(mood.skip(1).toList(), [
        ['2026-09-29', '22:00', '4', '3', '', '', '7.5', '2', 'work', ''],
        ['2026-09-30', '07:00', '', '', '', '', '', '', '', ''],
      ]);
    });

    test('Arabic headers and words, same machine-readable values', () async {
      final t = await repo.csvTable(DataCsvKind.transactions, ar, range: ExportDateRange(from: DateTime(2026, 9, 29)));
      expect(t.header.first, 'التاريخ');
      expect(t.rows.single[1], 'مصروف');
      expect(t.rows.single[4], '-12.500');
      final labs = await repo.csvTable(DataCsvKind.labs, ar);
      expect(labs.rows[1][8], 'مرتفع');
    });

    test('files: names, BOM, counts', () async {
      final f = await repo.csvExport(DataCsvKind.mood, en, now);
      expect(f.name, 'madar-mood-2026-09-30.csv');
      expect(f.mimeType, 'text/csv');
      expect(f.encrypted, isFalse);
      expect(f.records, 2);
      expect(f.bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final ranged = await repo.csvExport(DataCsvKind.labs, en, now, range: ExportDateRange.forPreset(ExportRangePreset.days30, now));
      expect(ranged.name, 'madar-labs-2026-09-01_2026-09-30.csv');
      expect(ranged.records, 3);
      final counts = await repo.csvCounts(range: ExportDateRange.forPreset(ExportRangePreset.days30, now));
      expect(counts, {
        DataCsvKind.labs: 3,
        DataCsvKind.transactions: 5,
        DataCsvKind.pain: 2,
        DataCsvKind.mood: 2,
        // The food log is its own CSV; this fixture logs no food.
        DataCsvKind.food: 0,
      });
    });
  });
}
