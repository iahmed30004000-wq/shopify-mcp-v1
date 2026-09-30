import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Table, TableInfo;

import '../../../core/db/database.dart';
import '../../../core/db/repositories/key_value_repository.dart';
import '../../../core/db/snapshot.dart';
import '../../../core/domain/budget_math.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../health/record/domain/lab_flags.dart';
import '../domain/ai_summary.dart';
import '../domain/csv_export.dart';
import '../domain/export_range.dart';
import '../domain/summary_input.dart';

/// A file ready to be shared or saved.
class DataFile {
  const DataFile({required this.name, required this.bytes, required this.mimeType, required this.encrypted, this.records});

  final String name;
  final Uint8List bytes;
  final String mimeType;

  /// Only `.madarbackup` files are encrypted; every export is plain text.
  final bool encrypted;

  /// Rows / records inside, when known.
  final int? records;

  int get size => bytes.length;

  String get extension => name.contains('.') ? name.substring(name.lastIndexOf('.') + 1) : '';
}

/// Reads the database for exports: the full JSON snapshot, CSV tables and
/// the AI summary's input. Nothing here writes to the database except the
/// summary choices ([saveSummaryOptions]).
class DataExportRepository {
  DataExportRepository(this.db, {this.useIsolate = true});

  final MadarDatabase db;

  /// Encode large JSON on a background isolate.
  final bool useIsolate;

  KeyValueRepository get _kv => KeyValueRepository(db);

  /// `health.record` → `borderlineMargin` (the user's lab flag margin).
  Future<double> labMargin() async {
    final json = await _kv.getJson('health.record');
    final m = json is Map ? json['borderlineMargin'] : null;
    return m is num && m.isFinite ? m.toDouble().clamp(0.0, LabFlags.maxMargin) : LabFlags.defaultMargin;
  }

  /// `2026-09-30`-stamped file name.
  static String fileName(String stem, String extension, DateTime now, {String? tag}) =>
      'madar-$stem-${tag ?? isoDay(now)}.$extension';

  // --------------------------------------------------------------- JSON --

  /// The full snapshot as pretty-printed UTF-8 JSON (every table, lossless –
  /// the same data the encrypted backup holds, unencrypted).
  Future<DataFile> jsonExport(DateTime now) async {
    final snapshot = await exportSnapshot(db, exportedAt: now);
    final counts = snapshotRowCounts(snapshot);
    final bytes = await encodeJson(snapshot, pretty: true, useIsolate: useIsolate);
    return DataFile(
      name: fileName('export', 'json', now),
      bytes: bytes,
      mimeType: 'application/json',
      encrypted: false,
      records: counts.values.fold<int>(0, (a, b) => a + b),
    );
  }

  static Future<Uint8List> encodeJson(Map<String, Object?> data, {bool pretty = false, bool useIsolate = true}) {
    Uint8List work() => Uint8List.fromList(utf8.encode(pretty ? const JsonEncoder.withIndent(' ').convert(data) : jsonEncode(data)));
    return useIsolate ? Isolate.run(work) : Future.value(work());
  }

  // ---------------------------------------------------------------- CSV --

  Future<CsvTable> csvTable(DataCsvKind kind, L10n l, {ExportDateRange range = ExportDateRange.all}) async {
    final builder = DataCsvBuilder(l, labMargin: await labMargin());
    return switch (kind) {
      DataCsvKind.labs => builder.labs(
        await db.select(db.labTests).get(),
        await db.select(db.labReadings).get(),
        range: range,
      ),
      DataCsvKind.transactions => builder.transactions(
        wallets: await db.select(db.wallets).get(),
        currencies: await db.select(db.currencies).get(),
        budgetItems: await db.select(db.budgetItems).get(),
        transactions: await db.select(db.transactions).get(),
        range: range,
      ),
      DataCsvKind.pain => builder.pain(await db.select(db.painEntries).get(), range: range),
      DataCsvKind.mood => builder.mood(await db.select(db.moodEntries).get(), range: range),
    };
  }

  static String csvStem(DataCsvKind kind) => switch (kind) {
    DataCsvKind.labs => 'labs',
    DataCsvKind.transactions => 'transactions',
    DataCsvKind.pain => 'pain',
    DataCsvKind.mood => 'mood',
  };

  Future<DataFile> csvExport(DataCsvKind kind, L10n l, DateTime now, {ExportDateRange range = ExportDateRange.all}) async {
    final table = await csvTable(kind, l, range: range);
    return DataFile(
      name: fileName(csvStem(kind), 'csv', now, tag: range.isAll ? null : range.fileTag),
      bytes: table.encodeBytes(),
      mimeType: 'text/csv',
      encrypted: false,
      records: table.rows.length,
    );
  }

  /// Rows each CSV would hold for [range] (for the export sheet's counts).
  Future<Map<DataCsvKind, int>> csvCounts({ExportDateRange range = ExportDateRange.all}) async => {
    DataCsvKind.labs: (await db.select(db.labReadings).get()).where((r) => range.contains(r.date)).length,
    DataCsvKind.transactions: (await db.select(db.transactions).get()).where((r) => range.contains(r.date)).length,
    DataCsvKind.pain: (await db.select(db.painEntries).get()).where((r) => range.contains(r.at)).length,
    DataCsvKind.mood: (await db.select(db.moodEntries).get()).where((r) => range.contains(r.at)).length,
  };

  // ------------------------------------------------------------ summary --

  Future<AiSummaryOptions> summaryOptions() async => AiSummaryOptions.fromJson(await _kv.getJson(AiSummaryOptions.storageKey));

  Future<void> saveSummaryOptions(AiSummaryOptions options) => _kv.setJson(AiSummaryOptions.storageKey, options.toJson());

  static DataFile summaryFile(String markdown, DateTime now) => DataFile(
    name: fileName('summary', 'md', now),
    bytes: Uint8List.fromList(utf8.encode(markdown)),
    mimeType: 'text/markdown',
    encrypted: false,
  );

  /// Everything the summary builder reads, in one pass.
  Future<SummaryInput> loadSummaryInput(DateTime now) async {
    Future<List<R>> all<T extends Table, R>(TableInfo<T, R> t) => db.select(t).get();
    final archived = await _kv.getJson('work.archivedBoards');
    final water = await _kv.getJson('body.waterTargetMl');
    final weeks = await _kv.getJson(BudgetSettings.weeksPerMonthKey);
    return SummaryInput(
      now: now,
      place: SummaryPlace.fromJson(await _kv.getJson('prayer.settings')),
      prayerLogs: await all(db.prayerLogs),
      quranSessions: await all(db.quranSessions),
      wirdPlans: await all(db.wirdPlans),
      hifzItems: await all(db.hifzItems),
      hifzReviews: await all(db.hifzReviews),
      healthAlerts: await all(db.healthAlerts),
      conditions: await all(db.conditions),
      medications: await all(db.medications),
      labTests: await all(db.labTests),
      labReadings: await all(db.labReadings),
      painEntries: await all(db.painEntries),
      moodEntries: await all(db.moodEntries),
      labMargin: await labMargin(),
      currencies: await all(db.currencies),
      wallets: await all(db.wallets),
      transactions: await all(db.transactions),
      budgetItems: await all(db.budgetItems),
      weeksPerMonth: weeks is num && weeks > 0 && weeks.isFinite ? weeks : BudgetSettings.defaultWeeksPerMonth,
      jars: await all(db.jars),
      jarDeposits: await all(db.jarDeposits),
      debts: await all(db.debts),
      debtPayments: await all(db.debtPayments),
      obligations: await all(db.obligations),
      people: await all(db.people),
      contactLogs: await all(db.contactLogs),
      tasks: await all(db.tasks),
      boards: await all(db.boards),
      boardCards: await all(db.boardCards),
      archivedBoardIds: {
        if (archived is List)
          for (final id in archived)
            if (id is String) id,
      },
      projects: await all(db.projects),
      projectItems: await all(db.projectItems),
      learningGoals: await all(db.learningGoals),
      goalLogs: await all(db.goalLogs),
      exercises: await all(db.exercises),
      workoutLogs: await all(db.workoutLogs),
      fastingSessions: await all(db.fastingSessions),
      waterLogs: await all(db.waterLogs),
      waterTargetMl: water is num && water > 0 ? water.round() : null,
      avoidItems: await all(db.avoidItems),
      trips: await all(db.trips),
      travelDocuments: await all(db.travelDocuments),
      customModules: await all(db.customModules),
      customEntries: await all(db.customEntries),
    );
  }
}
