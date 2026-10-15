import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/providers.dart';
import '../domain/backup_codec.dart';
import '../domain/summary_input.dart';
import 'backup_service.dart';
import 'data_repository.dart';
import 'file_bridge.dart';

/// "Now" for exports and backups (overridden in tests).
final dataClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Share sheet / save dialog / file picker / clipboard.
final dataFileBridgeProvider = Provider<DataFileBridge>((ref) => const PlatformDataFileBridge());

/// Backup encryption (tests override with cheap key derivation).
final backupCodecProvider = Provider<MadarBackupCodec>((ref) => const MadarBackupCodec());

/// App-private folder of the safety copies taken before a restore.
final safetyCopiesDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => () async => Directory('${(await getApplicationSupportDirectory()).path}/safety_backups'),
);

final dataExportRepositoryProvider = Provider<DataExportRepository>(
  (ref) => DataExportRepository(ref.watch(databaseProvider), useIsolate: ref.watch(backupCodecProvider).useIsolate),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(databaseProvider),
    codec: ref.watch(backupCodecProvider),
    safetyDirectory: ref.watch(safetyCopiesDirectoryProvider),
    clock: ref.watch(dataClockProvider),
  ),
);

/// The AI summary's input, loaded fresh each time a preview opens.
final summaryInputProvider = FutureProvider.autoDispose<SummaryInput>(
  (ref) => ref.watch(dataExportRepositoryProvider).loadSummaryInput(ref.watch(dataClockProvider)()),
);

/// Safety copies on this device (newest first).
final safetyCopiesProvider = FutureProvider.autoDispose<List<SafetyCopy>>(
  (ref) => ref.watch(backupServiceProvider).safetyCopies(),
);
