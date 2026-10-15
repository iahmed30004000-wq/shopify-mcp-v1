import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/import/import.dart';
import '../../core/providers.dart';

/// Where the import flow is.
enum ImportStage { idle, analyzing, preview, importing, done, failure }

/// Why the flow stopped.
enum ImportFailure { invalidJson, empty, notAnObject, unreadable, commitFailed }

/// A picked file: its name and decoded text.
typedef PickedJson = ({String name, String text});

/// Opens the system picker for a `.json` file (null when cancelled).
/// Overridden in tests.
final importFilePickerProvider = Provider<Future<PickedJson?> Function()>((ref) => pickJsonFile);

/// The platform picker: `.json` (and `.txt`, for exports saved as text).
Future<PickedJson?> pickJsonFile() async {
  final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['json', 'txt']);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return (name: file.name, text: utf8.decode(bytes, allowMalformed: true));
}

@immutable
class ImportState {
  const ImportState({
    this.stage = ImportStage.idle,
    this.plan,
    this.result,
    this.progress = 0,
    this.fileName,
    this.failure,
    this.allowDuplicate = false,
    this.duplicate,
  });

  final ImportStage stage;

  /// The analysis being previewed / imported.
  final ImportPlan? plan;

  /// The committed report.
  final ImportReport? result;

  /// 0..1 while importing.
  final double progress;
  final String? fileName;
  final ImportFailure? failure;

  /// The user confirmed importing a file that was imported before.
  final bool allowDuplicate;

  /// The earlier import of this same file, if any.
  final ImportDuplicate? duplicate;

  ImportReport? get report => result ?? plan?.report;

  bool get needsDuplicateConfirmation => duplicate != null;

  /// Whether the Import action is enabled.
  bool get canImport =>
      stage == ImportStage.preview && plan != null && plan!.canCommit && (!needsDuplicateConfirmation || allowDuplicate);

  ImportState copyWith({
    ImportStage? stage,
    double? progress,
    ImportReport? result,
    ImportFailure? failure,
    bool? allowDuplicate,
    ImportDuplicate? duplicate,
  }) => ImportState(
    stage: stage ?? this.stage,
    plan: plan,
    result: result ?? this.result,
    progress: progress ?? this.progress,
    fileName: fileName,
    failure: failure ?? this.failure,
    allowDuplicate: allowDuplicate ?? this.allowDuplicate,
    duplicate: duplicate ?? this.duplicate,
  );
}

/// Drives the import screen: pick / paste → analyse → preview → commit.
final importControllerProvider = NotifierProvider.autoDispose<ImportController, ImportState>(ImportController.new);

class ImportController extends Notifier<ImportState> {
  PrototypeImporter? _importer;

  @override
  ImportState build() => const ImportState();

  /// Opens the file picker and analyses the chosen file. Cancelling keeps
  /// the current state.
  Future<void> pickFile(ImportLabels labels) async {
    final PickedJson? picked;
    try {
      picked = await ref.read(importFilePickerProvider)();
    } catch (_) {
      if (ref.mounted) state = const ImportState(stage: ImportStage.failure, failure: ImportFailure.unreadable);
      return;
    }
    if (picked == null || !ref.mounted) return;
    await analyzeText(picked.text, labels: labels, fileName: picked.name);
  }

  /// Analyses pasted or picked JSON [text] against the open database.
  Future<void> analyzeText(String text, {required ImportLabels labels, String? fileName}) async {
    state = ImportState(stage: ImportStage.analyzing, fileName: fileName);
    // Let the analysing state paint before the (synchronous) analysis runs.
    await Future<void>.delayed(Duration.zero);
    if (!ref.mounted) return;
    final db = ref.read(databaseProvider);
    final ImportPlan plan;
    try {
      plan = await PrototypeImporter.analyzeFor(db, text, labels: labels, fileName: fileName);
    } catch (_) {
      if (ref.mounted) state = ImportState(stage: ImportStage.failure, failure: ImportFailure.unreadable, fileName: fileName);
      return;
    }
    if (!ref.mounted) return;
    _importer = PrototypeImporter(labels: labels, defaultCurrency: plan.budgetSettings.baseCurrency);
    final failure = _failureOf(plan.report);
    state = failure != null
        ? ImportState(stage: ImportStage.failure, failure: failure, fileName: fileName)
        : ImportState(stage: ImportStage.preview, plan: plan, fileName: fileName, duplicate: plan.report.duplicate);
  }

  static ImportFailure? _failureOf(ImportReport report) {
    if (!report.isFailure) return null;
    return switch (report.issues.first.code) {
      ImportIssueCode.invalidJson => ImportFailure.invalidJson,
      ImportIssueCode.emptyInput => ImportFailure.empty,
      _ => ImportFailure.notAnObject,
    };
  }

  /// Confirms (or withdraws) importing a file that was imported before.
  void setAllowDuplicate(bool allow) {
    if (state.stage != ImportStage.preview) return;
    state = state.copyWith(allowDuplicate: allow);
  }

  /// Writes the previewed plan.
  Future<void> commit() async {
    final plan = state.plan;
    final importer = _importer;
    if (!state.canImport || plan == null || importer == null) return;
    state = state.copyWith(stage: ImportStage.importing, progress: 0);
    try {
      final report = await importer.commit(
        ref.read(databaseProvider),
        plan,
        allowDuplicate: state.allowDuplicate,
        onProgress: (p) {
          if (ref.mounted) state = state.copyWith(progress: p);
        },
      );
      if (ref.mounted) state = state.copyWith(stage: ImportStage.done, result: report, progress: 1);
    } on ImportDuplicateException catch (e) {
      // Imported meanwhile (e.g. twice in a row): ask for confirmation.
      if (ref.mounted) {
        state = state.copyWith(stage: ImportStage.preview, allowDuplicate: false, duplicate: e.previous);
      }
    } catch (_) {
      if (ref.mounted) state = state.copyWith(stage: ImportStage.failure, failure: ImportFailure.commitFailed);
    }
  }

  /// Back to the start.
  void reset() {
    _importer = null;
    state = const ImportState();
  }
}
