/// The doors the resumable downloader goes through. Each is abstract so the
/// domain logic is tested with fakes and the integrator plugs in the real
/// transport, disk and phone probes.
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';

@immutable
final class HeadInfo {
  const HeadInfo({required this.contentLength, required this.acceptsRanges});

  final int contentLength;
  final bool acceptsRanges;
}

/// A failed request. [retryable] is the client's verdict: a cut connection, a
/// timeout, a 5xx or a 429 are retryable; a 403 or 404 are not.
final class TransportException implements Exception {
  const TransportException(this.message, {this.statusCode, this.retryable = true});

  final String message;
  final int? statusCode;
  final bool retryable;

  @override
  String toString() => 'TransportException($message${statusCode == null ? '' : ', $statusCode'})';
}

abstract interface class RangeHttpClient {
  /// Length of the file and whether the server accepts `Range` requests.
  Future<HeadInfo> head(Uri url);

  /// Bytes [start]..[end] INCLUSIVE (an HTTP Range). Throws
  /// [TransportException].
  Future<Uint8List> getRange(Uri url, int start, int end);
}

/// Thrown by [FileSink.writePart] when the phone has no room left.
final class StorageFullException implements Exception {
  const StorageFullException();

  @override
  String toString() => 'StorageFullException';
}

abstract interface class FreeSpaceProbe {
  Future<int> freeBytes();
}

enum NetworkKind { none, wifi, ethernet, cellular, other }

abstract interface class ConnectivityProbe {
  Future<NetworkKind> current();
}

/// Where the parts go. A part is stored whole or not at all (write to a
/// temporary name, then rename), so a crash never leaves half a part that
/// looks finished.
abstract interface class FileSink {
  /// Stored length of a part, or null when it is not there.
  Future<int?> partLength(String id, int index);

  /// Throws [StorageFullException] when the disk is full.
  Future<void> writePart(String id, int index, Uint8List bytes);
  Stream<List<int>> readPart(String id, int index);
  Future<void> deletePart(String id, int index);

  /// Joins the parts in order into the final file, removes them, and returns
  /// where the file is.
  Future<String> finalize(String id, int partCount);

  /// Removes every part and any partial file of [id].
  Future<void> discard(String id);
}

enum DownloadStatus { idle, running, paused, verifying, completed, failed, cancelled }

enum PauseReason { user, storageFull, waitingForWifi, offline, connectionLost }

enum DownloadFailure { sizeMismatch, rangesUnsupported, serverRejected, partChecksumMismatch, checksumMismatch, writeFailed }

/// What survives a restart: which parts are done.
@immutable
final class DownloadState {
  const DownloadState({
    required this.id,
    required this.fingerprint,
    this.completedParts = const {},
    this.status = DownloadStatus.idle,
    this.pauseReason,
    this.failure,
    this.location,
  });

  final String id;

  /// `DownloadPlan.fingerprint` of the plan these parts belong to.
  final String fingerprint;
  final Set<int> completedParts;
  final DownloadStatus status;
  final PauseReason? pauseReason;
  final DownloadFailure? failure;
  final String? location;

  Map<String, Object?> toJson() => {
    'id': id,
    'fingerprint': fingerprint,
    'completedParts': (completedParts.toList()..sort()),
    'status': status.name,
    if (pauseReason != null) 'pauseReason': pauseReason!.name,
    if (failure != null) 'failure': failure!.name,
    if (location != null) 'location': location,
  };

  factory DownloadState.fromJson(Map<String, Object?> json) => DownloadState(
    id: json['id'] as String,
    fingerprint: json['fingerprint'] as String,
    completedParts: {for (final i in (json['completedParts'] as List? ?? const [])) i as int},
    status: DownloadStatus.values.byName(json['status'] as String? ?? 'idle'),
    pauseReason: json['pauseReason'] == null ? null : PauseReason.values.byName(json['pauseReason'] as String),
    failure: json['failure'] == null ? null : DownloadFailure.values.byName(json['failure'] as String),
    location: json['location'] as String?,
  );
}

abstract interface class DownloadStateStore {
  Future<DownloadState?> load(String id);
  Future<void> save(DownloadState state);
  Future<void> delete(String id);
}
