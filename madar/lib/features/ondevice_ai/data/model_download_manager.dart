/// Download, cancel and remove the optional weights (Part 15).
///
/// Built on the finished `ChunkedDownloader` of Part 17 (reused by import:
/// parts, resume, Wi-Fi rule, free-space check, whole-file SHA-256). What this
/// adds on top, and nothing else:
///
///  * **optional** – nothing starts by itself; a download is a tap;
///  * **fingerprint-gated** – [AuthGate] must say yes before the first byte
///    (the weights are big, and a child's tap must not start 3 GB);
///  * **unverified entries never start** – see `ModelCatalogEntry.canDownload`;
///  * **Wi-Fi only by default**;
///  * **private storage** – the sink the app plugs in writes under the app's
///    own files directory, never the APK;
///  * **removable** – one call frees everything.
///
/// The app is fully usable without any of this: no screen of the daily chat,
/// the day's summary or the bridge reads this manager.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import '../../reading/data/chunked_downloader.dart';
import '../../reading/data/download_ports.dart';
import '../../reading/domain/download_plan.dart';
import '../domain/model_catalog.dart';

/// «Is it really him?» – the fingerprint (or the app's PIN) before a big
/// download. The real one wraps the app lock's `BiometricAuth`.
abstract interface class AuthGate {
  Future<bool> confirm();
}

/// A sink that can also say whether the finished file is still there.
abstract interface class ModelFileSink implements FileSink {
  Future<bool> finalExists(String id);
}

enum StartRefusal {
  /// The entry's facts are placeholders (`unverified`).
  unverified,

  /// Verified, but something a download needs is missing (size, SHA-256, an
  /// HTTPS address).
  incomplete,

  /// The fingerprint was refused or cancelled.
  authDenied,

  /// This model is already downloading.
  alreadyRunning,
}

enum ModelInstallStatus { notInstalled, downloading, verifying, paused, installed, failed }

@immutable
class ModelInstallState {
  const ModelInstallState({
    required this.entryId,
    required this.status,
    this.completedBytes = 0,
    this.totalBytes = 0,
    this.pauseReason,
    this.failure,
    this.location,
  });

  const ModelInstallState.none(String entryId) : this(entryId: entryId, status: ModelInstallStatus.notInstalled);

  final String entryId;
  final ModelInstallStatus status;
  final int completedBytes;
  final int totalBytes;
  final PauseReason? pauseReason;
  final DownloadFailure? failure;

  /// Where the finished file is (only when installed).
  final String? location;

  double get fraction => totalBytes <= 0 ? 0 : (completedBytes / totalBytes).clamp(0.0, 1.0);

  bool get isBusy => status == ModelInstallStatus.downloading || status == ModelInstallStatus.verifying;
}

/// What [ModelDownloadManager.start] answers.
@immutable
class StartResult {
  const StartResult.started(this.finished) : refusal = null;
  const StartResult.refused(StartRefusal this.refusal) : finished = null;

  /// Completes with the final state when the run ends (done, paused, failed
  /// or cancelled). Null when refused.
  final Future<ModelInstallState>? finished;
  final StartRefusal? refusal;

  bool get started => refusal == null;
}

class ModelDownloadManager {
  ModelDownloadManager({
    required this.auth,
    required this.newDownloader,
    required this.store,
    required this.sink,
    this.planner = const DownloadPlanner(partSizeBytes: 16 * 1024 * 1024),
  });

  final AuthGate auth;

  /// A fresh downloader per run (one downloader runs one file at a time).
  final ChunkedDownloader Function() newDownloader;
  final DownloadStateStore store;
  final ModelFileSink sink;
  final DownloadPlanner planner;

  final Map<String, ChunkedDownloader> _running = {};
  final StreamController<ModelInstallState> _changes = StreamController<ModelInstallState>.broadcast();

  /// Every state change of every model.
  Stream<ModelInstallState> get changes => _changes.stream;

  /// Where [entry] stands now (also right after a restart: the saved state
  /// and the file on disk are the truth, not memory).
  Future<ModelInstallState> stateOf(ModelCatalogEntry entry) async {
    if (_running.containsKey(entry.id)) {
      return ModelInstallState(
        entryId: entry.id,
        status: ModelInstallStatus.downloading,
        totalBytes: entry.sizeBytes ?? 0,
      );
    }
    final saved = await store.load(entry.id);
    if (saved == null) return ModelInstallState.none(entry.id);
    switch (saved.status) {
      case DownloadStatus.completed:
        if (saved.location != null && await sink.finalExists(entry.id)) {
          return ModelInstallState(
            entryId: entry.id,
            status: ModelInstallStatus.installed,
            completedBytes: entry.sizeBytes ?? 0,
            totalBytes: entry.sizeBytes ?? 0,
            location: saved.location,
          );
        }
        return ModelInstallState.none(entry.id);
      case DownloadStatus.paused:
        return ModelInstallState(
          entryId: entry.id,
          status: ModelInstallStatus.paused,
          totalBytes: entry.sizeBytes ?? 0,
          pauseReason: saved.pauseReason,
        );
      case DownloadStatus.failed:
        return ModelInstallState(
          entryId: entry.id,
          status: ModelInstallStatus.failed,
          totalBytes: entry.sizeBytes ?? 0,
          failure: saved.failure,
        );
      case DownloadStatus.idle:
      case DownloadStatus.running:
      case DownloadStatus.verifying:
      case DownloadStatus.cancelled:
        // A run that died with the app: resumable from its saved parts.
        return ModelInstallState(
          entryId: entry.id,
          status: saved.completedParts.isEmpty ? ModelInstallStatus.notInstalled : ModelInstallStatus.paused,
          totalBytes: entry.sizeBytes ?? 0,
          pauseReason: saved.completedParts.isEmpty ? null : PauseReason.user,
        );
    }
  }

  /// Starts (or resumes) the download of [entry].
  Future<StartResult> start(ModelCatalogEntry entry, {bool wifiOnly = true}) async {
    // The facts first: nothing is asked of him for a download that cannot run.
    if (entry.unverified) return const StartResult.refused(StartRefusal.unverified);
    if (!entry.canDownload) return const StartResult.refused(StartRefusal.incomplete);
    if (_running.containsKey(entry.id)) return const StartResult.refused(StartRefusal.alreadyRunning);
    if (!await auth.confirm()) return const StartResult.refused(StartRefusal.authDenied);
    // The fingerprint dialog takes time: another tap may have started it.
    if (_running.containsKey(entry.id)) return const StartResult.refused(StartRefusal.alreadyRunning);

    final downloader = newDownloader();
    _running[entry.id] = downloader;
    final plan = planner.forSize(
      id: entry.id,
      url: Uri.parse(entry.downloadUrl!),
      totalBytes: entry.sizeBytes!,
      sha256: entry.sha256,
    );
    final sub = downloader.progress.listen((p) => _emit(_fromProgress(entry, p)));
    final finished = () async {
      try {
        final p = await downloader.download(plan, wifiOnly: wifiOnly);
        final s = _fromProgress(entry, p);
        _running.remove(entry.id);
        _emit(s);
        return s;
      } catch (_) {
        _running.remove(entry.id);
        final s = ModelInstallState(
          entryId: entry.id,
          status: ModelInstallStatus.failed,
          totalBytes: entry.sizeBytes ?? 0,
          failure: DownloadFailure.writeFailed,
        );
        _emit(s);
        return s;
      } finally {
        await sub.cancel();
        await downloader.dispose();
      }
    }();
    return StartResult.started(finished);
  }

  /// Stops a running download and throws away what it had fetched.
  void cancel(String entryId) => _running[entryId]?.cancel();

  /// Stops a running download but keeps its parts, so it can resume.
  void pause(String entryId) => _running[entryId]?.pause();

  /// Frees everything about [entry]: a running download, its parts and the
  /// finished file.
  Future<void> remove(ModelCatalogEntry entry) async {
    final running = _running[entry.id];
    if (running != null) {
      running.cancel();
      // Give the run a moment to wind down before its files go.
      for (var i = 0; i < 50 && _running.containsKey(entry.id); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
    await sink.discard(entry.id);
    await store.delete(entry.id);
    _emit(ModelInstallState.none(entry.id));
  }

  ModelInstallState _fromProgress(ModelCatalogEntry entry, DownloadProgress p) => ModelInstallState(
    entryId: entry.id,
    status: switch (p.status) {
      DownloadStatus.running => ModelInstallStatus.downloading,
      DownloadStatus.verifying => ModelInstallStatus.verifying,
      DownloadStatus.completed => ModelInstallStatus.installed,
      DownloadStatus.paused => ModelInstallStatus.paused,
      DownloadStatus.failed => ModelInstallStatus.failed,
      DownloadStatus.cancelled || DownloadStatus.idle => ModelInstallStatus.notInstalled,
    },
    completedBytes: p.status == DownloadStatus.cancelled ? 0 : p.completedBytes,
    totalBytes: p.totalBytes,
    pauseReason: p.pauseReason,
    failure: p.failure,
    location: p.location,
  );

  void _emit(ModelInstallState s) {
    if (!_changes.isClosed) _changes.add(s);
  }

  Future<void> dispose() => _changes.close();
}
