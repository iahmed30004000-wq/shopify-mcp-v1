/// Your data: encrypted backup / restore, exports (AI-ready Markdown summary,
/// CSV, full JSON) and the entry to the prototype import.
///
/// Everything stays on the device; a file leaves only when the user shares
/// or saves it. Wire [DataCentreScreen] to a route (e.g. `/settings/data`);
/// [showExportPreviewSheet] in `select` mode returns the reviewed summary
/// for an AI chat.
library;

export 'data/backup_service.dart'
    show BackupService, OpenedBackup, RestoreException, RestorePhase, RestoreProblem, RestoreResult, SafetyCopy;
export 'data/data_providers.dart';
export 'data/data_repository.dart' show DataExportRepository, DataFile;
export 'data/file_bridge.dart' show DataFileBridge, PickedDataFile, PlatformDataFileBridge, RecordingDataFileBridge;
export 'domain/ai_summary.dart';
export 'domain/ai_summary_builder.dart' show AiSummaryBuilder;
export 'domain/backup_codec.dart' show BackupKey, MadarBackupCodec, OpenedBackupBytes;
export 'domain/backup_format.dart'
    show
        BackupException,
        BackupHeader,
        BackupKdfParams,
        BackupProblem,
        madarBackupExtension,
        madarBackupMimeType,
        madarBackupVersion;
export 'domain/csv_export.dart' show CsvTable, DataCsvBuilder, DataCsvKind;
export 'domain/export_range.dart' show ExportDateRange, ExportRangePreset;
export 'domain/passphrase_strength.dart';
export 'domain/summary_input.dart';
export 'presentation/backup_sheet.dart' show BackupSheet, lastBackupKey, showBackupSheet;
export 'presentation/csv_export_sheet.dart' show CsvExportSheet, showCsvExportSheet;
export 'presentation/data_centre_screen.dart' show DataCentreScreen, dataRecordCountProvider, lastBackupAtProvider;
export 'presentation/export_preview_sheet.dart' show ExportPreviewMode, ExportPreviewSheet, showExportPreviewSheet;
export 'presentation/restore_flow.dart' show RestoreFlow, RestoreStage;
