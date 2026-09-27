/// Imports the JSON exported by Madar's HTML prototype
/// (`{"data": {...}, "logs": {...}}`, or any of the tolerated variants
/// documented in `docs/import-format.md`).
///
/// Two steps:
/// 1. [PrototypeImporter.analyze] – pure: decodes, locates every section,
///    maps it to Drift rows with stable ids and returns an [ImportPlan]
///    whose [ImportReport] says exactly what will happen.
/// 2. [PrototypeImporter.commit] – writes the plan in one transaction
///    (existing rows are never overwritten), stores the raw file in
///    `import_archive` and returns the final report.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/seed/seeder.dart' show SeedKeys;
import '../domain/budget_math.dart';
import '../domain/money.dart';
import 'import_aliases.dart';
import 'import_labels.dart';
import 'import_locator.dart';
import 'import_mapper.dart';
import 'import_models.dart';
import 'import_rows.dart';
import 'sha256.dart';

/// Everything `commit` needs, plus the report to show before committing.
class ImportPlan {
  ImportPlan._({
    required this.raw,
    required this.fileName,
    required this.report,
    required this.rows,
    required this.budgetNodes,
    required this.budgetSettings,
    required this.leftovers,
    required this.settings,
  });

  /// The file as given (archived verbatim).
  final String raw;
  final String? fileName;
  final ImportReport report;
  final ImportRows rows;

  /// The imported budget tree (for previews with [budget]).
  final List<BudgetNode> budgetNodes;
  final BudgetSettings budgetSettings;

  /// Values nothing maps to, by JSON path (also in the archived raw file).
  final Map<String, Object?> leftovers;

  /// Settings read from the file (`weeksPerMonth`, `baseCurrency`, `rates`).
  final Map<String, Object?> settings;

  /// The imported budget computed with [BudgetMath].
  BudgetMath get budget => BudgetMath(budgetNodes, settings: budgetSettings);

  /// False when the input could not be analysed at all.
  bool get canCommit => !report.isFailure;

  /// Nothing recognised (the file would only be archived).
  bool get isEmpty => rows.total == 0;
}

/// Thrown by [PrototypeImporter.commit] when the same file was imported
/// before and `allowDuplicate` is false.
class ImportDuplicateException implements Exception {
  const ImportDuplicateException(this.previous);
  final ImportDuplicate previous;

  @override
  String toString() => 'ImportDuplicateException(${previous.archiveId} at ${previous.importedAt})';
}

class PrototypeImporter {
  const PrototypeImporter({required this.labels, this.defaultCurrency = 'JOD'});

  /// Names the importer has to invent (localised).
  final ImportLabels labels;

  /// Currency of amounts without one when the file declares no base
  /// (pass the database's base currency).
  final String defaultCurrency;

  /// Source tag of archived prototype imports.
  static const archiveSource = 'prototype-json';

  // -------------------------------------------------------------- analyze --

  /// Analyses [json] without touching any database. [knownImports] (from
  /// [knownImports]) lets the report flag a file imported before; [now]
  /// fixes "today" for defaults (tests).
  ImportPlan analyze(
    String json, {
    String? fileName,
    Map<String, ImportDuplicate> knownImports = const {},
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    ImportPlan failed(ImportIssueCode code, [String? detail]) => ImportPlan._(
      raw: json,
      fileName: fileName,
      report: ImportReport.failed(code, detail: detail),
      rows: ImportRows(),
      budgetNodes: const [],
      budgetSettings: BudgetSettings(baseCurrency: defaultCurrency),
      leftovers: const {},
      settings: const {},
    );

    final text = json.trim().replaceFirst('\uFEFF', '');
    if (text.isEmpty) return failed(ImportIssueCode.emptyInput);
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      return failed(ImportIssueCode.invalidJson, e.message);
    }
    if (decoded is! Map && decoded is! List) return failed(ImportIssueCode.notAnObject);
    if ((decoded is Map && decoded.isEmpty) || (decoded is List && decoded.isEmpty)) {
      return failed(ImportIssueCode.emptyInput);
    }

    final hash = Sha256.ofString(Sha256.canonicalJson(decoded));
    final located = ImportLocator.locate(decoded);
    final mapper = ImportMapper(located: located, labels: labels, defaultCurrency: defaultCurrency, now: clock)..run();

    final issues = <ImportIssue>[...mapper.issues];
    final settings = Map<String, Object?>.of(located.settings);
    for (final e in settings.entries) {
      issues.add(ImportIssue(ImportIssueCode.settingRead, path: e.key, detail: e.value is Map ? jsonEncode(e.value) : '${e.value}'));
    }

    // Budget preview + checks through BudgetMath.
    final rates = <String, num>{};
    final fileRates = settings['rates'];
    if (fileRates is Map) {
      for (final e in fileRates.entries) {
        if (e.value is num) rates['${e.key}'] = e.value as num;
      }
    }
    final budgetSettings = BudgetSettings(
      weeksPerMonth: (settings['weeksPerMonth'] as num?) ?? BudgetSettings.defaultWeeksPerMonth,
      baseCurrency: mapper.baseCurrency,
      ratesToBase: rates,
    );
    int? budgetTotal;
    if (mapper.budgetNodes.isNotEmpty) {
      final math = BudgetMath(mapper.budgetNodes, settings: budgetSettings);
      budgetTotal = math.totalMonthlyMilli;
      final names = {for (final n in mapper.budgetNodes) n.id: n.name};
      for (final w in math.warnings) {
        issues.add(
          ImportIssue(
            ImportIssueCode.budget,
            section: ImportSection.budgetItems,
            detail: w.kind.name,
            args: {
              'kind': w.kind.name,
              'name': ?names[w.nodeId],
              'milli': ?w.amountMilli,
              'percent': ?w.percent,
              'currency': w.currency ?? mapper.baseCurrency,
            },
          ),
        );
      }
    }

    final duplicate = knownImports[hash];
    if (duplicate != null) issues.add(ImportIssue(ImportIssueCode.duplicateFile, detail: duplicate.archiveId));

    final unmapped = <UnmappedEntry>[
      for (final e in located.leftovers.entries) _leftoverEntry(e.key, e.value),
      ...mapper.unmappedFields,
    ];

    final report = ImportReport(
      shape: ImportShape(
        container: located.container,
        keyStyle: located.keyStyle,
        domains: located.domains.toList(),
        dayKeyedLogs: located.dayKeyed,
        typedEventLists: located.typedEvents,
        idKeyedMaps: located.idKeyed,
        meta: located.meta,
      ),
      contentHash: hash,
      sections: mapper.sections,
      issues: issues,
      unmapped: unmapped,
      modules: mapper.modules,
      duplicate: duplicate,
      budgetTotalMilli: budgetTotal,
      budgetCurrency: mapper.budgetNodes.isEmpty ? null : mapper.baseCurrency,
      settings: settings,
    );
    return ImportPlan._(
      raw: json,
      fileName: fileName,
      report: report,
      rows: mapper.rows,
      budgetNodes: List.unmodifiable(mapper.budgetNodes),
      budgetSettings: budgetSettings,
      leftovers: located.leftovers,
      settings: settings,
    );
  }

  static UnmappedEntry _leftoverEntry(String path, Object? v) {
    if (v is List) return UnmappedEntry(path: path, kind: 'list', preview: '[${v.length}]');
    if (v is Map) return UnmappedEntry(path: path, kind: 'object', preview: '{${v.length}}');
    final s = v == null ? 'null' : '$v';
    return UnmappedEntry(path: path, kind: 'scalar', preview: s.length > 60 ? '${s.substring(0, 57)}…' : s);
  }

  /// Hashes of files imported before → when (from `import_archive`).
  static Future<Map<String, ImportDuplicate>> knownImports(MadarDatabase db) async {
    final rows = await (db.select(db.importArchive)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
    return {
      for (final r in rows)
        if (r.summary['hash'] is String) r.summary['hash'] as String: ImportDuplicate(archiveId: r.id, importedAt: r.createdAt),
    };
  }

  /// [analyze] with the database's previous imports and base currency.
  static Future<ImportPlan> analyzeFor(
    MadarDatabase db,
    String json, {
    required ImportLabels labels,
    String? fileName,
    DateTime? now,
  }) async {
    final base = await (db.select(db.currencies)..where((t) => t.isBase.equals(true))).getSingleOrNull();
    final importer = PrototypeImporter(labels: labels, defaultCurrency: base?.code ?? 'JOD');
    return importer.analyze(json, fileName: fileName, knownImports: await knownImports(db), now: now);
  }

  // --------------------------------------------------------------- commit --

  /// Writes [plan] in a single transaction and archives the raw file.
  ///
  /// Rows whose stable id (or unique key) already exists are left exactly
  /// as they are, so re-importing never duplicates or overwrites. A file
  /// imported before throws [ImportDuplicateException] unless
  /// [allowDuplicate]. [onProgress] receives 0..1 as tables are written.
  Future<ImportReport> commit(
    MadarDatabase db,
    ImportPlan plan, {
    bool allowDuplicate = false,
    void Function(double progress)? onProgress,
  }) async {
    if (!plan.canCommit) throw StateError('The plan cannot be committed: ${plan.report.issues.first.code.name}');
    final written = <ImportSection, int>{};
    final extraIssues = <ImportIssue>[];
    final committedAt = DateTime.now();
    final archiveId = newId();

    await db.transaction(() async {
      final previous = (await knownImports(db))[plan.report.contentHash];
      if (previous != null && !allowDuplicate) throw ImportDuplicateException(previous);

      await _prepareCurrencies(db, plan, extraIssues);
      final batches = plan.rows.all;
      for (var i = 0; i < batches.length; i++) {
        final t = batches[i];
        if (t.rows.isNotEmpty) written[t.section] = await t.write(db);
        onProgress?.call((i + 1) / (batches.length + 1));
      }

      final weeks = plan.settings['weeksPerMonth'];
      if (weeks is num) {
        await db
            .into(db.keyValues)
            .insert(
              KeyValuesCompanion.insert(key: BudgetSettings.weeksPerMonthKey, value: jsonEncode(weeks)),
              mode: InsertMode.insertOrIgnore,
            );
      }

      final summary = <String, Object?>{
        ...plan.report.toJson(),
        'fileName': ?plan.fileName,
        'leftovers': plan.leftovers,
        'written': {for (final e in written.entries) e.key.name: e.value},
        'committedAt': committedAt.toIso8601String(),
      };
      await db
          .into(db.importArchive)
          .insert(
            ImportArchiveCompanion.insert(
              id: Value(archiveId),
              source: plan.fileName == null ? archiveSource : '$archiveSource:${plan.fileName}',
              raw: plan.raw,
              summary: Value(summary),
            ),
          );
      onProgress?.call(1);
    });

    for (final e in plan.report.sections.entries) {
      final w = written[e.key] ?? 0;
      e.value
        ..inserted = w
        ..existing = e.value.planned - w;
    }
    plan.report.issues.addAll(extraIssues);
    return plan.report.copyWith(archiveId: archiveId, committedAt: committedAt);
  }

  /// Missing currencies get the file's rate (or 1 + a warning); the file's
  /// rates also replace the seeded placeholder rates while the user has not
  /// set any. A database without a base currency adopts the plan's base.
  Future<void> _prepareCurrencies(MadarDatabase db, ImportPlan plan, List<ImportIssue> issues) async {
    final existing = {for (final c in await db.select(db.currencies).get()) c.code: c};
    final dbBase = existing.values.where((c) => c.isBase).firstOrNull?.code;
    final planBase = plan.budgetSettings.baseCurrency;
    final fileRates = plan.settings['rates'];
    final rates = <String, double>{
      if (fileRates is Map)
        for (final e in fileRates.entries)
          if (e.value is num) '${e.key}': (e.value as num).toDouble(),
    };
    final ratesAreDefaults =
        await (db.select(db.keyValues)..where((t) => t.key.equals(SeedKeys.currencyRatesAreDefaults))).getSingleOrNull() != null;
    final batch = plan.rows.currencies;
    for (var i = 0; i < batch.rows.length; i++) {
      final row = batch.rows[i] as CurrenciesCompanion;
      final code = row.code.value;
      if (existing.containsKey(code)) continue;
      if (dbBase == null && code == planBase) {
        batch.rows[i] = row.copyWith(isBase: const Value(true), rateToBase: const Value(1.0));
      } else if (!rates.containsKey(code) && code != (dbBase ?? planBase)) {
        issues.add(ImportIssue(ImportIssueCode.missingRate, section: ImportSection.currencies, detail: code));
      }
    }
    if (ratesAreDefaults && rates.isNotEmpty && (dbBase == null || dbBase == planBase)) {
      for (final e in rates.entries) {
        if (existing.containsKey(e.key) && e.value > 0 && e.key != dbBase) {
          await (db.update(db.currencies)..where((t) => t.code.equals(e.key))).write(CurrenciesCompanion(rateToBase: Value(e.value)));
        }
      }
    }
  }
}

/// A persisted budget row as a [BudgetNode] (for [BudgetMath]).
BudgetNode budgetNodeFromRow(BudgetItemRow row) => BudgetNode(
  id: row.id,
  name: row.name,
  parentId: row.parentId,
  mode: row.mode,
  amountMilli: row.amountMilli,
  percent: row.percent,
  percentOf: row.percentOf,
  period: row.period,
  currency: row.currency,
  sortOrder: row.sortOrder,
);

/// Rates of the `currencies` table as [BudgetSettings.ratesToBase].
Map<String, num> ratesFromRows(Iterable<CurrencyRow> rows) => {for (final c in rows) c.code: c.rateToBase};

/// Formats milli-units of [currency] for import summaries.
String formatImportMoney(int milli, String currency, {String locale = 'en'}) =>
    Money(milli, currency).format(locale: locale);
