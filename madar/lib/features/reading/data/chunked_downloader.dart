/// Resumable, part-by-part download of one big file (Part 17: "in parts, the
/// size written first, survives a dropped connection and resumes").
///
/// The shape of a run:
///  1. the plan already told the screen the total size (no client involved);
///  2. before the first request: Wi-Fi rule and free space for what is missing;
///  3. HEAD once, then each missing part as a Range request, retried with
///     capped backoff; every finished part is saved before the next starts, so
///     a cut connection, a pause or a full disk costs at most the part in
///     flight;
///  4. whole-file SHA-256, then the parts are joined.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:meta/meta.dart';

import '../domain/download_plan.dart';
import 'download_ports.dart';

@immutable
final class DownloaderConfig {
  const DownloaderConfig({
    this.maxParallel = 1,
    this.maxAttempts = 4,
    this.backoffBase = const Duration(seconds: 1),
    this.backoffCap = const Duration(seconds: 30),
    this.corruptRefetches = 1,
    this.reserveBytes = 32 * 1024 * 1024,
  });

  /// 1 = sequential. More than 1 fetches that many parts at once.
  final int maxParallel;

  /// Tries per part (the first one included) before the download pauses as
  /// "connection lost" and waits for him to resume.
  final int maxAttempts;
  final Duration backoffBase;
  final Duration backoffCap;

  /// How many times a part whose SHA-256 does not match is fetched again.
  final int corruptRefetches;

  /// Free space to leave on the phone on top of the download itself.
  final int reserveBytes;

  Duration backoff(int failedAttempts) {
    final ms = backoffBase.inMilliseconds * (1 << (failedAttempts - 1).clamp(0, 30));
    final capped = ms > backoffCap.inMilliseconds ? backoffCap.inMilliseconds : ms;
    return Duration(milliseconds: capped);
  }
}

@immutable
final class DownloadProgress {
  const DownloadProgress({
    required this.status,
    required this.completedBytes,
    required this.totalBytes,
    required this.completedParts,
    required this.totalParts,
    this.pauseReason,
    this.failure,
    this.location,
  });

  final DownloadStatus status;
  final int completedBytes;
  final int totalBytes;
  final int completedParts;
  final int totalParts;
  final PauseReason? pauseReason;
  final DownloadFailure? failure;

  /// Where the finished file is (only when [status] is completed).
  final String? location;

  double get fraction => totalBytes == 0 ? 0 : completedBytes / totalBytes;
}

typedef DelayFn = Future<void> Function(Duration);

/// Is there room for the part of [plan] that is still missing? The screen
/// can ask this before offering "Start".
Future<bool> hasRoomFor(DownloadPlan plan, Set<int> completedParts, FreeSpaceProbe probe, {int reserveBytes = 0}) async {
  final missing = plan.parts.where((p) => !completedParts.contains(p.index)).fold<int>(0, (a, p) => a + p.length);
  return await probe.freeBytes() >= missing + reserveBytes;
}

String sha256Hex(List<int> bytes) {
  final sink = const DartSha256().newHashSink()
    ..add(bytes)
    ..close();
  return _hex(sink.hashSync().bytes);
}

String _hex(List<int> bytes) => [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();

final class ChunkedDownloader {
  ChunkedDownloader({
    required this.client,
    required this.store,
    required this.space,
    required this.sink,
    required this.connectivity,
    DelayFn? delay,
    this.config = const DownloaderConfig(),
  }) : _delay = delay ?? Future<void>.delayed;

  final RangeHttpClient client;
  final DownloadStateStore store;
  final FreeSpaceProbe space;
  final FileSink sink;
  final ConnectivityProbe connectivity;
  final DownloaderConfig config;
  final DelayFn _delay;

  final StreamController<DownloadProgress> _progress = StreamController<DownloadProgress>.broadcast();

  Stream<DownloadProgress> get progress => _progress.stream;

  bool _running = false;
  bool _userPause = false;
  bool _cancel = false;
  PauseReason? _pause;
  DownloadFailure? _failure;
  Future<void> _saveChain = Future<void>.value();

  bool get isRunning => _running;

  /// Stops after the parts in flight finish; finished parts are kept.
  void pause() => _userPause = true;

  /// Stops and removes everything downloaded so far.
  void cancel() => _cancel = true;

  bool get _stopped => _userPause || _cancel || _pause != null || _failure != null;

  /// Runs (or resumes) [plan]. Completes when the file is done, paused,
  /// cancelled or failed; the returned progress says which.
  Future<DownloadProgress> download(DownloadPlan plan, {bool wifiOnly = false}) async {
    if (_running) throw StateError('A download is already running on this downloader');
    _running = true;
    _userPause = false;
    _cancel = false;
    _pause = null;
    _failure = null;
    try {
      return await _run(plan, wifiOnly);
    } finally {
      _running = false;
    }
  }

  Future<DownloadProgress> _run(DownloadPlan plan, bool wifiOnly) async {
    var state = await store.load(plan.id);
    if (state == null || state.fingerprint != plan.fingerprint) {
      // A different file under the same id: its parts are worthless.
      if (state != null) await sink.discard(plan.id);
      state = DownloadState(id: plan.id, fingerprint: plan.fingerprint);
    }
    if (state.status == DownloadStatus.completed && state.location != null) {
      // Already finished earlier; the parts were joined and removed.
      final p = DownloadProgress(
        status: DownloadStatus.completed,
        completedBytes: plan.totalBytes,
        totalBytes: plan.totalBytes,
        completedParts: plan.partCount,
        totalParts: plan.partCount,
        location: state.location,
      );
      _emit(p);
      return p;
    }
    // Trust the disk, not the note: a part counts only if it is really there.
    final done = <int>{};
    for (final i in state.completedParts) {
      if (i < 0 || i >= plan.partCount) continue;
      if (await sink.partLength(plan.id, i) == plan.parts[i].length) done.add(i);
    }

    DownloadProgress snapshot(DownloadStatus s, {String? location}) => DownloadProgress(
      status: s,
      completedBytes: done.fold<int>(0, (a, i) => a + plan.parts[i].length),
      totalBytes: plan.totalBytes,
      completedParts: done.length,
      totalParts: plan.partCount,
      pauseReason: s == DownloadStatus.paused ? _pause ?? PauseReason.user : null,
      failure: s == DownloadStatus.failed ? _failure : null,
      location: location,
    );

    Future<DownloadProgress> finish(DownloadStatus s, {String? location, bool keepState = true}) async {
      final p = snapshot(s, location: location);
      await _saveChain;
      if (keepState) {
        await store.save(
          DownloadState(
            id: plan.id,
            fingerprint: plan.fingerprint,
            completedParts: Set.of(done),
            status: s,
            pauseReason: p.pauseReason,
            failure: p.failure,
            location: location,
          ),
        );
      } else {
        await store.delete(plan.id);
      }
      _emit(p);
      return p;
    }

    void persist() {
      final s = DownloadState(
        id: plan.id,
        fingerprint: plan.fingerprint,
        completedParts: Set.of(done),
        status: DownloadStatus.running,
      );
      _saveChain = _saveChain.then((_) => store.save(s));
    }

    _emit(snapshot(DownloadStatus.running));

    // Before any byte: network rule, then room on the phone.
    if (await _networkBlocks(wifiOnly)) return finish(DownloadStatus.paused);
    final missingBytes = plan.parts.where((p) => !done.contains(p.index)).fold<int>(0, (a, p) => a + p.length);
    if (missingBytes > 0 && await space.freeBytes() < missingBytes + config.reserveBytes) {
      _pause = PauseReason.storageFull;
      return finish(DownloadStatus.paused);
    }

    if (missingBytes > 0) {
      final head = await _retry(() => client.head(plan.url));
      if (head != null) {
        if (!head.acceptsRanges) {
          _failure = DownloadFailure.rangesUnsupported;
        } else if (head.contentLength != plan.totalBytes) {
          _failure = DownloadFailure.sizeMismatch;
        }
      }
      if (!_stopped) {
        final queue = [for (final p in plan.parts) if (!done.contains(p.index)) p];
        var next = 0;
        Future<void> worker() async {
          while (!_stopped && next < queue.length) {
            final part = queue[next++];
            if (await _networkBlocks(wifiOnly)) return;
            if (await space.freeBytes() < part.length + config.reserveBytes) {
              _pause ??= PauseReason.storageFull;
              return;
            }
            if (await _fetchPart(plan, part)) {
              done.add(part.index);
              persist();
              _emit(snapshot(DownloadStatus.running));
            }
          }
        }

        final n = config.maxParallel.clamp(1, queue.length);
        await Future.wait([for (var i = 0; i < n; i++) worker()]);
      }
    }

    if (_cancel) {
      await _saveChain;
      await sink.discard(plan.id);
      done.clear();
      return finish(DownloadStatus.cancelled, keepState: false);
    }
    if (_failure != null) return finish(DownloadStatus.failed);
    if (_pause != null || _userPause || done.length < plan.partCount) {
      _pause ??= PauseReason.user;
      return finish(DownloadStatus.paused);
    }

    // All parts are in: check the whole file before it is called finished.
    _emit(snapshot(DownloadStatus.verifying));
    if (plan.sha256 != null) {
      final h = const DartSha256().newHashSink();
      for (var i = 0; i < plan.partCount; i++) {
        await for (final chunk in sink.readPart(plan.id, i)) {
          h.add(chunk);
        }
      }
      h.close();
      if (_hex(h.hashSync().bytes) != plan.sha256) {
        // Which part is bad is unknown here, so none can be trusted.
        await sink.discard(plan.id);
        done.clear();
        _failure = DownloadFailure.checksumMismatch;
        return finish(DownloadStatus.failed, keepState: false);
      }
    }
    final location = await sink.finalize(plan.id, plan.partCount);
    return finish(DownloadStatus.completed, location: location);
  }

  /// Applies the Wi-Fi rule; sets the pause reason and returns true when the
  /// download must not touch the network now.
  Future<bool> _networkBlocks(bool wifiOnly) async {
    if (_stopped) return true;
    final net = await connectivity.current();
    if (net == NetworkKind.none) {
      _pause ??= PauseReason.offline;
    } else if (wifiOnly && net != NetworkKind.wifi && net != NetworkKind.ethernet) {
      _pause ??= PauseReason.waitingForWifi;
    }
    return _pause != null;
  }

  /// Fetches, checks and stores one part. Returns true when it is on disk.
  Future<bool> _fetchPart(DownloadPlan plan, PlannedPart part) async {
    var corrupt = 0;
    while (!_stopped) {
      final bytes = await _retry(() async {
        final b = await client.getRange(plan.url, part.start, part.end);
        if (b.length != part.length) {
          throw TransportException('Short read: ${b.length} of ${part.length} bytes');
        }
        return b;
      });
      if (bytes == null) return false;
      if (_cancel) return false;
      if (part.sha256 != null && sha256Hex(bytes) != part.sha256) {
        if (++corrupt > config.corruptRefetches) {
          _failure = DownloadFailure.partChecksumMismatch;
          return false;
        }
        continue; // fetch it once more; nothing was written
      }
      try {
        await sink.writePart(plan.id, part.index, Uint8List.fromList(bytes));
      } on StorageFullException {
        _pause ??= PauseReason.storageFull;
        return false;
      } on Object {
        _failure = DownloadFailure.writeFailed;
        return false;
      }
      return true;
    }
    return false;
  }

  /// Runs [op] with capped backoff. Returns null when the run should stop:
  /// the tries are used up (pause: connection lost), the server said no
  /// (failure), or a pause/cancel arrived meanwhile.
  Future<T?> _retry<T>(Future<T> Function() op) async {
    for (var attempt = 1; !_stopped; attempt++) {
      try {
        return await op();
      } on TransportException catch (e) {
        if (!e.retryable) {
          _failure = DownloadFailure.serverRejected;
          return null;
        }
        if (attempt >= config.maxAttempts) {
          _pause ??= PauseReason.connectionLost;
          return null;
        }
        await _delay(config.backoff(attempt));
      }
    }
    return null;
  }

  void _emit(DownloadProgress p) {
    if (!_progress.isClosed) _progress.add(p);
  }

  Future<void> dispose() => _progress.close();
}
