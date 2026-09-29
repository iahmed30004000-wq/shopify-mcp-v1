import 'package:meta/meta.dart';

import 'reciters.dart';
import 'surah_ayah_counts.dart';

/// Where a surah's download stands.
enum DownloadStatus {
  /// Nothing on disk.
  none,

  /// Waiting for a download slot.
  queued,
  downloading,

  /// Paused by the user (or by the app closing); resumes where it stopped.
  paused,

  /// "Wi-Fi only" is on and the phone is not on Wi-Fi.
  waitingForWifi,
  failed,
  complete;

  /// Counts as work the user asked for and has not finished.
  bool get pending => this == queued || this == downloading;

  /// Can be resumed.
  bool get resumable => this == paused || this == waitingForWifi || this == failed;
}

/// Why a download failed.
enum DownloadError { network, notFound, storage }

/// One surah of one reciter on disk.
@immutable
class SurahDownload {
  const SurahDownload({
    required this.reciterId,
    required this.surah,
    this.status = DownloadStatus.none,
    this.filesDone = 0,
    int? filesTotal,
    this.bytes = 0,
    this.error,
  }) : filesTotal = filesTotal ?? 0;

  final String reciterId;
  final int surah;
  final DownloadStatus status;

  /// Finished files (the surah's ayat plus the basmala file when it needs
  /// one) out of [filesTotal].
  final int filesDone;
  final int filesTotal;

  /// Bytes on disk, partial files included.
  final int bytes;
  final DownloadError? error;

  double get progress => filesTotal == 0 ? 0 : (filesDone / filesTotal).clamp(0.0, 1.0);
  bool get isComplete => status == DownloadStatus.complete;
  bool get hasFiles => bytes > 0 || filesDone > 0;

  SurahDownload copyWith({
    DownloadStatus? status,
    int? filesDone,
    int? filesTotal,
    int? bytes,
    DownloadError? Function()? error,
  }) => SurahDownload(
    reciterId: reciterId,
    surah: surah,
    status: status ?? this.status,
    filesDone: filesDone ?? this.filesDone,
    filesTotal: filesTotal ?? this.filesTotal,
    bytes: bytes ?? this.bytes,
    error: error == null ? this.error : error(),
  );

  Map<String, Object?> toJson() => {
    's': status.name,
    'done': filesDone,
    'total': filesTotal,
    'bytes': bytes,
    if (error != null) 'err': error!.name,
  };

  /// From the persisted index. Work that was in flight when the app closed
  /// comes back paused: nothing downloads until the user resumes it.
  static SurahDownload? fromJson(String reciterId, int surah, Object? json) {
    if (json is! Map) return null;
    DownloadStatus status = DownloadStatus.values.asNameMap()[json['s']] ?? DownloadStatus.none;
    if (status.pending) status = DownloadStatus.paused;
    int n(Object? v) => v is num ? v.toInt() : 0;
    return SurahDownload(
      reciterId: reciterId,
      surah: surah,
      status: status,
      filesDone: n(json['done']),
      filesTotal: n(json['total']),
      bytes: n(json['bytes']),
      error: DownloadError.values.asNameMap()[json['err']],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SurahDownload &&
      other.reciterId == reciterId &&
      other.surah == surah &&
      other.status == status &&
      other.filesDone == filesDone &&
      other.filesTotal == filesTotal &&
      other.bytes == bytes &&
      other.error == error;

  @override
  int get hashCode => Object.hash(reciterId, surah, status, filesDone, filesTotal, bytes, error);

  @override
  String toString() => 'SurahDownload($reciterId $surah ${status.name} $filesDone/$filesTotal $bytes B)';
}

/// Files a surah's download consists of: its ayat, plus the basmala file
/// (stored once per reciter) for surahs that open with one.
int downloadFileCount(int surah) => SurahMath.ayahCount(surah) + (EveryAyah.surahNeedsBasmala(surah) ? 1 : 0);

/// A reciter's downloads at a glance.
@immutable
class ReciterDownloads {
  const ReciterDownloads({
    required this.reciterId,
    this.completeSurahs = 0,
    this.bytes = 0,
    this.active = 0,
    this.paused = 0,
  });

  final String reciterId;
  final int completeSurahs;
  final int bytes;

  /// Surahs queued or downloading.
  final int active;

  /// Surahs paused, waiting for Wi-Fi or failed.
  final int paused;

  bool get isEmpty => bytes == 0 && active == 0 && paused == 0 && completeSurahs == 0;
  bool get wholeMushaf => completeSurahs == 114;
}
