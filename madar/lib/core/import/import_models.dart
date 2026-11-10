/// Plan and report types of the prototype importer (pure Dart).
library;

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../db/database.dart';
import 'import_aliases.dart';

// ------------------------------------------------------------------ shape --

/// How the export is wrapped.
enum ImportContainer {
  /// `{"data": {...}, "logs": {...}}` – the prototype's export.
  wrapped,

  /// `{"data": {...}}` without logs.
  dataOnly,

  /// `{"logs": {...}}` without data.
  logsOnly,

  /// Sections directly at the top level.
  flat,

  /// A bare JSON array of records.
  list,
}

/// The dominant spelling of the keys.
enum ImportKeyStyle { camelCase, snakeCase, arabic, mixed, plain }

/// What [PrototypeImporter.analyze] recognised about the file's layout.
@immutable
class ImportShape {
  const ImportShape({
    required this.container,
    required this.keyStyle,
    this.domains = const [],
    this.dayKeyedLogs = false,
    this.typedEventLists = false,
    this.idKeyedMaps = false,
    this.meta = const {},
  });

  final ImportContainer container;
  final ImportKeyStyle keyStyle;

  /// Grouping keys the sections were nested in (`health`, `money` …), as
  /// planet keys.
  final List<String> domains;

  /// Logs keyed by day (`{"2026-01-10": {"pain": 3, …}}`).
  final bool dayKeyedLogs;

  /// Lists of `{"type": "pain", …}` events dispatched by type.
  final bool typedEventLists;

  /// Collections stored as `{"<id>": {...}}` maps instead of arrays.
  final bool idKeyedMaps;

  /// Export metadata (`version`, `exportedAt` …).
  final Map<String, Object?> meta;

  bool get nestedByDomain => domains.isNotEmpty;

  Map<String, Object?> toJson() => {
    'container': container.name,
    'keyStyle': keyStyle.name,
    'domains': domains,
    'dayKeyedLogs': dayKeyedLogs,
    'typedEventLists': typedEventLists,
    'idKeyedMaps': idKeyedMaps,
    'meta': meta,
  };
}

// ----------------------------------------------------------------- issues --

/// Everything the importer tells the user about. The UI localises by code;
/// [ImportIssue.detail] carries the raw value / field / reference.
enum ImportIssueCode {
  /// The text is not JSON.
  invalidJson,

  /// Empty input.
  emptyInput,

  /// The JSON is a scalar, not an object or array.
  notAnObject,

  /// A date could not be read; the row used the day it belongs to or was
  /// skipped (see [missingRequired]).
  unparsedDate,

  /// An amount could not be read.
  unparsedAmount,

  /// A clock time could not be read.
  unparsedTime,

  /// A number could not be read.
  unparsedNumber,

  /// A word was turned into a default clock time (`morning` → 08:00).
  inferredTime,

  /// A required value is missing; the row was not imported (it stays in
  /// the archive).
  missingRequired,

  /// A reference points nowhere and the row was not imported.
  unresolvedReference,

  /// A reference pointed nowhere, so its target was created by name.
  createdReference,

  /// An enum word was not recognised; the default was used.
  unknownValue,

  /// Water given as a small number was read as glasses of 250 ml.
  assumedGlasses,

  /// A fasting session without a target used its duration (or 16 h).
  assumedFastingTarget,

  /// A required date was missing; a sensible default was used (e.g. the
  /// next due date of a bill).
  assumedDate,

  /// A required number was missing; a default was used (e.g. a goal target).
  assumedValue,

  /// Amounts in a currency other than their wallet's went to a companion
  /// wallet in that currency (nothing is converted).
  currencyWallet,

  /// A currency without a rate was added with rate 1 – set the real rate.
  missingRate,

  /// Two records shared one source id; the second got a suffix.
  duplicateSourceId,

  /// A budget check (children vs parent, percents) – see [BudgetWarningKind].
  budget,

  /// This exact file was imported before.
  duplicateFile,

  /// A section setting (weeks per month, base currency) was read.
  settingRead,
}

@immutable
class ImportIssue {
  const ImportIssue(this.code, {this.section, this.path, this.detail, this.args = const {}});

  final ImportIssueCode code;
  final ImportSection? section;

  /// JSON path of the value (`data.health.meds[2].times`).
  final String? path;

  /// The raw value, field name or reference concerned.
  final String? detail;

  /// Structured parameters (budget warnings: `kind`, `name`, `milli`,
  /// `percent`, `currency`).
  final Map<String, Object?> args;

  Map<String, Object?> toJson() => {
    'code': code.name,
    if (section != null) 'section': section!.name,
    if (path != null) 'path': path,
    if (detail != null) 'detail': detail,
    if (args.isNotEmpty) 'args': args,
  };

  @override
  String toString() => 'ImportIssue(${code.name}${section == null ? '' : ' ${section!.name}'} $path $detail)';
}

/// A value nothing in Madar maps to. Lists of objects never end up here –
/// they become custom modules; this is for scalars, lists of scalars and
/// record fields the table has no column for.
@immutable
class UnmappedEntry {
  const UnmappedEntry({required this.path, required this.kind, this.preview, this.count = 1});

  final String path;

  /// `scalar`, `list`, `object` or `field`.
  final String kind;

  /// Short text preview of the value.
  final String? preview;

  /// For `field`: how many records carried it.
  final int count;

  Map<String, Object?> toJson() => {'path': path, 'kind': kind, 'preview': ?preview, 'count': count};
}

/// A custom module generated for an unknown list of records.
@immutable
class ImportedModuleSummary {
  const ImportedModuleSummary({
    required this.id,
    required this.name,
    required this.sourcePath,
    required this.entries,
    required this.fieldTypes,
  });

  final String id;
  final String name;
  final String sourcePath;
  final int entries;

  /// Field label → field type name.
  final Map<String, String> fieldTypes;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'sourcePath': sourcePath,
    'entries': entries,
    'fields': fieldTypes,
  };
}

/// Per-section counts.
class ImportSectionReport {
  ImportSectionReport(this.section);

  final ImportSection section;

  /// Rows planned by `analyze`.
  int planned = 0;

  /// Rows written by `commit` (null before commit).
  int? inserted;

  /// Planned rows that already existed (same stable id) and were kept as they
  /// are (null before commit).
  int? existing;

  /// Rows the source had but that could not be imported (see issues).
  int skipped = 0;

  /// Where the rows came from.
  final Set<String> sourcePaths = {};

  Map<String, Object?> toJson() => {
    'planned': planned,
    'inserted': ?inserted,
    'existing': ?existing,
    if (skipped > 0) 'skipped': skipped,
    'sources': sourcePaths.toList(),
  };
}

/// The previous import of the same file.
@immutable
class ImportDuplicate {
  const ImportDuplicate({required this.archiveId, required this.importedAt});
  final String archiveId;
  final DateTime importedAt;
}

/// What happened (after `analyze`) or will happen / happened (after
/// `commit`).
class ImportReport {
  ImportReport({
    required this.shape,
    required this.contentHash,
    required this.sections,
    required this.issues,
    required this.unmapped,
    required this.modules,
    this.duplicate,
    this.budgetTotalMilli,
    this.budgetCurrency,
    this.settings = const {},
    this.archiveId,
    this.committedAt,
  });

  /// An empty report for input that could not be analysed.
  factory ImportReport.failed(ImportIssueCode code, {String? detail}) => ImportReport(
    shape: const ImportShape(container: ImportContainer.flat, keyStyle: ImportKeyStyle.plain),
    contentHash: '',
    sections: const {},
    issues: [ImportIssue(code, detail: detail)],
    unmapped: const [],
    modules: const [],
  );

  final ImportShape shape;

  /// SHA-256 of the canonical JSON (key order and whitespace do not matter).
  final String contentHash;
  final Map<ImportSection, ImportSectionReport> sections;
  final List<ImportIssue> issues;
  final List<UnmappedEntry> unmapped;
  final List<ImportedModuleSummary> modules;
  final ImportDuplicate? duplicate;

  /// Monthly budget total of the imported tree (base currency), via
  /// `BudgetMath`.
  final int? budgetTotalMilli;
  final String? budgetCurrency;

  /// Settings read from the file (`weeksPerMonth`, `baseCurrency`, `rates`).
  final Map<String, Object?> settings;

  /// Set by `commit`.
  final String? archiveId;
  final DateTime? committedAt;

  bool get isFailure => issues.any(
    (i) => i.code == ImportIssueCode.invalidJson || i.code == ImportIssueCode.emptyInput || i.code == ImportIssueCode.notAnObject,
  );
  bool get isCommitted => committedAt != null;
  bool get isDuplicate => duplicate != null;

  int get totalPlanned => sections.values.fold(0, (a, s) => a + s.planned);
  int get totalInserted => sections.values.fold(0, (a, s) => a + (s.inserted ?? 0));
  int get totalExisting => sections.values.fold(0, (a, s) => a + (s.existing ?? 0));

  /// Planned rows of [section] (0 when absent).
  int count(ImportSection section) => sections[section]?.planned ?? 0;

  /// Issues grouped by code, most frequent first.
  List<(ImportIssueCode, int)> get issueCounts {
    final m = <ImportIssueCode, int>{};
    for (final i in issues) {
      m[i.code] = (m[i.code] ?? 0) + 1;
    }
    return m.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
  }

  ImportReport copyWith({ImportDuplicate? duplicate, bool clearDuplicate = false, String? archiveId, DateTime? committedAt}) =>
      ImportReport(
        shape: shape,
        contentHash: contentHash,
        sections: sections,
        issues: issues,
        unmapped: unmapped,
        modules: modules,
        duplicate: clearDuplicate ? null : (duplicate ?? this.duplicate),
        budgetTotalMilli: budgetTotalMilli,
        budgetCurrency: budgetCurrency,
        settings: settings,
        archiveId: archiveId ?? this.archiveId,
        committedAt: committedAt ?? this.committedAt,
      );

  Map<String, Object?> toJson() => {
    'hash': contentHash,
    'shape': shape.toJson(),
    'sections': {for (final e in sections.entries) e.key.name: e.value.toJson()},
    'issues': [for (final i in issues) i.toJson()],
    'unmapped': [for (final u in unmapped) u.toJson()],
    'modules': [for (final m in modules) m.toJson()],
    'budgetTotalMilli': ?budgetTotalMilli,
    'budgetCurrency': ?budgetCurrency,
    'settings': settings,
    'committedAt': ?committedAt?.toIso8601String(),
  };
}

// ------------------------------------------------------------------- rows --

/// Rows planned for one table, typed so `commit` can batch-insert them.
final class ImportTableRows<T extends Table, D> {
  ImportTableRows(this.section, this._table);

  final ImportSection section;
  final TableInfo<T, D> Function(MadarDatabase db) _table;
  final List<Insertable<D>> rows = [];

  TableInfo<T, D> tableOf(MadarDatabase db) => _table(db);

  /// Inserts every row, keeping rows that already exist (same primary or
  /// unique key) untouched. Returns how many were actually written.
  ///
  /// Ordered tables get the imported rows *after* the rows already there:
  /// every planned `sort_order` (numbered from 0 per parent by the mapper)
  /// is shifted by `MAX(sort_order) + 1`, which keeps the imported relative
  /// order without interleaving with existing rows.
  Future<int> write(MadarDatabase db) async {
    if (rows.isEmpty) return 0;
    final table = _table(db);
    Future<int> count() async {
      final r = await db.customSelect('SELECT COUNT(*) AS c FROM "${table.actualTableName}"').getSingle();
      return r.read<int>('c');
    }

    final before = await count();
    var toInsert = rows;
    if (table.columnsByName['sort_order'] != null) {
      final r = await db
          .customSelect('SELECT COALESCE(MAX(sort_order), -1) + 1 AS o FROM "${table.actualTableName}"')
          .getSingle();
      final offset = r.read<int>('o');
      if (offset != 0) {
        toInsert = [
          for (final row in rows)
            () {
              final cols = row.toColumns(false);
              return RawValuesInsertable<D>({...cols, 'sort_order': Variable<int>(_intOf(cols['sort_order']) + offset)});
            }(),
        ];
      }
    }
    await db.batch((b) => b.insertAll(table, toInsert, mode: InsertMode.insertOrIgnore));
    return await count() - before;
  }

  static int _intOf(Expression<Object>? e) => switch (e) {
    Variable(:final int value) => value,
    Constant(:final int value) => value,
    _ => 0,
  };
}
