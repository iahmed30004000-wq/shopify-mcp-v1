/// CSV exports of the four tracking tables people most often want in a
/// spreadsheet: lab readings, transactions, pain and mood entries.
///
/// Files are RFC 4180 (CRLF line ends, fields with `,` `"` or line breaks
/// quoted, quotes doubled), UTF-8 with a byte-order mark so Excel detects
/// Arabic text, ISO dates (`2026-09-30`) and times (`08:30`), and numbers
/// with a `.` decimal point in every language. Text cells that a spreadsheet
/// would run as a formula (`=`, `+`, `-`, `@`, tab, CR) get a leading `'`.
/// Column headers and category words follow the app language. Pure Dart.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/enums.dart';
import '../../../core/domain/money.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../health/record/domain/lab_flags.dart';
import 'export_range.dart';
import 'plain_numbers.dart';

enum DataCsvKind { labs, transactions, pain, mood }

/// A CSV table before encoding.
@immutable
class CsvTable {
  const CsvTable({required this.header, required this.rows, this.textColumns = const {}});

  final List<String> header;

  /// Cells (null = empty).
  final List<List<String?>> rows;

  /// Column indexes holding free text (guarded against formulas).
  final Set<int> textColumns;

  /// The CSV text (no BOM).
  String encode() {
    final b = StringBuffer();
    void line(List<String?> cells, {bool guard = true}) {
      for (var i = 0; i < cells.length; i++) {
        if (i > 0) b.write(',');
        b.write(CsvText.field(cells[i] ?? '', guardFormula: guard && textColumns.contains(i)));
      }
      b.write('\r\n');
    }

    line(header, guard: false);
    for (final r in rows) {
      line(r);
    }
    return b.toString();
  }

  /// UTF-8 bytes with a byte-order mark.
  Uint8List encodeBytes() => Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(encode())]);
}

abstract final class CsvText {
  static final RegExp _needsQuotes = RegExp('[",\r\n]');
  static const _formulaStarts = {'=', '+', '-', '@', '\t', '\r'};

  /// One RFC 4180 field.
  static String field(String value, {bool guardFormula = false}) {
    var v = value;
    if (guardFormula && v.isNotEmpty && _formulaStarts.contains(v[0])) v = "'$v";
    if (!_needsQuotes.hasMatch(v)) return v;
    return '"${v.replaceAll('"', '""')}"';
  }
}

/// Builds the CSV tables from database rows.
class DataCsvBuilder {
  const DataCsvBuilder(this.l, {this.labMargin = LabFlags.defaultMargin});

  final L10n l;

  /// Borderline margin for lab flags (the user's Health setting).
  final double labMargin;

  static String _list(Iterable<String> items) => items.join('; ');

  // ------------------------------------------------------------------ labs --

  CsvTable labs(List<LabTestRow> tests, List<LabReadingRow> readings, {ExportDateRange range = ExportDateRange.all}) {
    final byId = {for (final t in tests) t.id: t};
    final rows = [
      for (final r in readings)
        if (range.contains(r.date)) r,
    ]..sort((a, b) {
        final c = a.date.compareTo(b.date);
        if (c != 0) return c;
        final n = (byId[a.testId]?.name ?? '').compareTo(byId[b.testId]?.name ?? '');
        return n != 0 ? n : a.id.compareTo(b.id);
      });
    return CsvTable(
      header: [
        l.dataCsvDate,
        l.dataCsvTest,
        l.dataCsvCategory,
        l.dataCsvValue,
        l.dataCsvTextResult,
        l.dataCsvUnit,
        l.dataCsvRangeLow,
        l.dataCsvRangeHigh,
        l.dataCsvFlag,
        l.dataCsvNote,
      ],
      textColumns: const {1, 2, 4, 5, 9},
      rows: [
        for (final r in rows)
          () {
            final t = byId[r.testId];
            final flag = LabFlags.classify(r.value, LabRange(low: t?.low, high: t?.high), margin: labMargin);
            return <String?>[
              isoDay(r.date),
              t?.name ?? '',
              t?.category,
              r.value == null ? null : PlainNumbers.decimal(r.value!),
              r.valueText,
              t?.unit,
              t?.low == null ? null : PlainNumbers.decimal(t!.low!),
              t?.high == null ? null : PlainNumbers.decimal(t!.high!),
              labFlagLabel(l, flag),
              r.note,
            ];
          }(),
      ],
    );
  }

  /// Neutral words for a lab flag (empty for "no range" / qualitative).
  static String labFlagLabel(L10n l, LabFlag flag) => switch (flag) {
    LabFlag.low => l.dataFlagLow,
    LabFlag.borderlineLow => l.dataFlagBorderlineLow,
    LabFlag.inRange => l.dataFlagInRange,
    LabFlag.borderlineHigh => l.dataFlagBorderlineHigh,
    LabFlag.high => l.dataFlagHigh,
    LabFlag.noRange || LabFlag.qualitative => '',
  };

  // ---------------------------------------------------------- transactions --

  CsvTable transactions({
    required List<WalletRow> wallets,
    required List<CurrencyRow> currencies,
    required List<BudgetItemRow> budgetItems,
    required List<TransactionRow> transactions,
    ExportDateRange range = ExportDateRange.all,
  }) {
    final walletById = {for (final w in wallets) w.id: w};
    final currencyByCode = {for (final c in currencies) c.code.toUpperCase(): c};
    final base = currencies.where((c) => c.isBase).firstOrNull;
    final baseCode = base?.code.toUpperCase();
    final baseDecimals = base?.decimals ?? 2;
    final items = {for (final b in budgetItems) b.id: b};

    String? path(String? id) {
      if (id == null || !items.containsKey(id)) return null;
      final parts = <String>[];
      var cur = items[id];
      final seen = <String>{};
      while (cur != null && seen.add(cur.id)) {
        parts.insert(0, cur.name);
        cur = cur.parentId == null ? null : items[cur.parentId];
      }
      return parts.join(' › ');
    }

    int decimalsOf(String code) =>
        currencyByCode[code.toUpperCase()]?.decimals ?? CurrencyCatalog.decimalsFor(code);

    String? toBase(int milli, String code) {
      if (baseCode == null) return null;
      final c = currencyByCode[code.toUpperCase()];
      final rate = code.toUpperCase() == baseCode ? 1.0 : c?.rateToBase;
      if (rate == null || rate <= 0 || !rate.isFinite) return null;
      return PlainNumbers.milli(Money(milli, code.toUpperCase()).toBase(rate, baseCode).milli, decimals: baseDecimals);
    }

    final rows = [
      for (final t in transactions)
        if (range.contains(t.date)) t,
    ]..sort((a, b) {
        final c = a.date.compareTo(b.date);
        if (c != 0) return c;
        final k = a.createdAt.compareTo(b.createdAt);
        return k != 0 ? k : a.id.compareTo(b.id);
      });

    return CsvTable(
      header: [
        l.dataCsvDate,
        l.dataCsvKind,
        l.dataCsvWallet,
        l.dataCsvCurrency,
        l.dataCsvAmount,
        l.dataCsvAmountBase,
        l.dataCsvBaseCurrency,
        l.dataCsvBudgetItem,
        l.dataCsvToWallet,
        l.dataCsvToAmount,
        l.dataCsvToCurrency,
        l.dataCsvNote,
        l.dataCsvTags,
      ],
      textColumns: const {2, 7, 8, 11, 12},
      rows: [
        for (final t in rows)
          () {
            final w = walletById[t.walletId];
            final code = (w?.currency ?? baseCode ?? '').toUpperCase();
            final signed = switch (t.kind) {
              TxKind.income => t.amountMilli.abs(),
              TxKind.expense || TxKind.transfer => -t.amountMilli.abs(),
              TxKind.adjustment => t.amountMilli,
            };
            final to = t.kind == TxKind.transfer ? walletById[t.toWalletId] : null;
            final toCode = to?.currency.toUpperCase();
            final received = t.kind == TxKind.transfer ? (t.toAmountMilli ?? t.amountMilli).abs() : null;
            return <String?>[
              isoDay(t.date),
              txKindLabel(l, t.kind),
              w?.name ?? '',
              code,
              PlainNumbers.milli(signed, decimals: decimalsOf(code)),
              code.isEmpty ? null : toBase(signed, code),
              baseCode,
              path(t.budgetItemId),
              to?.name,
              received == null || toCode == null ? null : PlainNumbers.milli(received, decimals: decimalsOf(toCode)),
              toCode,
              t.note,
              t.tags.isEmpty ? null : _list(t.tags),
            ];
          }(),
      ],
    );
  }

  static String txKindLabel(L10n l, TxKind kind) => switch (kind) {
    TxKind.expense => l.dataTxExpense,
    TxKind.income => l.dataTxIncome,
    TxKind.transfer => l.dataTxTransfer,
    TxKind.adjustment => l.dataTxAdjustment,
  };

  // ------------------------------------------------------------------ pain --

  CsvTable pain(List<PainEntryRow> entries, {ExportDateRange range = ExportDateRange.all}) {
    final rows = [
      for (final e in entries)
        if (range.contains(e.at)) e,
    ]..sort((a, b) {
        final c = a.at.compareTo(b.at);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return CsvTable(
      header: [
        l.dataCsvDate,
        l.dataCsvTime,
        l.dataCsvPainScore,
        l.dataCsvLocations,
        l.dataCsvTriggers,
        l.dataCsvBodyPoints,
        l.dataCsvNotes,
      ],
      textColumns: const {3, 4, 6},
      rows: [
        for (final e in rows)
          [
            isoDay(e.at),
            isoTime(e.at),
            '${e.score}',
            e.locations.isEmpty ? null : _list(e.locations),
            e.triggers.isEmpty ? null : _list(e.triggers),
            '${e.bodyPoints.length}',
            e.notes,
          ],
      ],
    );
  }

  // ------------------------------------------------------------------ mood --

  CsvTable mood(List<MoodEntryRow> entries, {ExportDateRange range = ExportDateRange.all}) {
    final rows = [
      for (final e in entries)
        if (range.contains(e.at)) e,
    ]..sort((a, b) {
        final c = a.at.compareTo(b.at);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    String? n(num? v) => v == null ? null : PlainNumbers.decimal(v);
    return CsvTable(
      header: [
        l.dataCsvDate,
        l.dataCsvTime,
        l.dataCsvMoodScore,
        l.dataCsvStress,
        l.dataCsvAnxiety,
        l.dataCsvEnergy,
        l.dataCsvSleepHours,
        l.dataCsvCaffeine,
        l.dataCsvFactors,
        l.dataCsvNotes,
      ],
      textColumns: const {8, 9},
      rows: [
        for (final e in rows)
          [
            isoDay(e.at),
            isoTime(e.at),
            n(e.mood),
            n(e.stress),
            n(e.anxiety),
            n(e.energy),
            n(e.sleepHours),
            n(e.caffeineCups),
            e.factors.isEmpty ? null : _list(e.factors),
            e.notes,
          ],
      ],
    );
  }
}
