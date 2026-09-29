import 'package:flutter/material.dart';

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../domain/download_models.dart';
import '../domain/recitation_state.dart';
import '../domain/reciters.dart';

/// Localised labels of the recitation feature.
abstract final class RecitationLabels {
  static String style(L10n l, ReciterStyle s) => switch (s) {
    ReciterStyle.mujawwad => l.recitationStyleMujawwad,
    ReciterStyle.murattal => l.recitationStyleMurattal,
    ReciterStyle.muallim => l.recitationStyleMuallim,
  };

  static String styleHint(L10n l, ReciterStyle s) => switch (s) {
    ReciterStyle.mujawwad => l.recitationStyleMujawwadHint,
    ReciterStyle.murattal => l.recitationStyleMurattalHint,
    ReciterStyle.muallim => l.recitationStyleMuallimHint,
  };

  static IconData styleIcon(ReciterStyle s) => switch (s) {
    ReciterStyle.mujawwad => Icons.graphic_eq_rounded,
    ReciterStyle.murattal => Icons.record_voice_over_rounded,
    ReciterStyle.muallim => Icons.school_outlined,
  };

  static String bitrate(L10n l, MadarFormatter fmt, Reciter r) => l.recitationBitrate(fmt.formatInt(r.bitrate));

  /// `1.2 GB` / `٣٤٠ ميغابايت`.
  static String size(L10n l, MadarFormatter fmt, int bytes) {
    const kb = 1000, mb = kb * 1000, gb = mb * 1000;
    if (bytes >= gb) return l.recitationSizeGb(fmt.formatNumber(bytes / gb, maxDecimals: bytes >= 10 * gb ? 0 : 1));
    if (bytes >= mb) return l.recitationSizeMb(fmt.formatNumber(bytes / mb, maxDecimals: bytes >= 10 * mb ? 0 : 1));
    return l.recitationSizeKb(fmt.formatInt((bytes / kb).ceil()));
  }

  /// A repeat count ("مرتان", "5 times"); 0 = until stopped.
  static String times(L10n l, MadarFormatter fmt, int count) =>
      count <= 0 ? l.recitationEndless : fmt.localizeDigits(l.recitationTimes(count));

  static String speed(L10n l, MadarFormatter fmt, double speed) =>
      l.recitationSpeedValue(fmt.formatNumber(speed, maxDecimals: 2));

  static String status(L10n l, DownloadStatus s) => switch (s) {
    DownloadStatus.none => '',
    DownloadStatus.queued => l.recitationStatusQueued,
    DownloadStatus.downloading => l.recitationStatusDownloading,
    DownloadStatus.paused => l.recitationStatusPaused,
    DownloadStatus.waitingForWifi => l.recitationStatusWifi,
    DownloadStatus.failed => l.recitationStatusFailed,
    DownloadStatus.complete => l.recitationStatusComplete,
  };

  static String downloadError(L10n l, DownloadError e) => switch (e) {
    DownloadError.network => l.recitationErrorNetwork,
    DownloadError.notFound => l.recitationErrorNotFound,
    DownloadError.storage => l.recitationErrorStorage,
  };

  /// Why the player is paused / failing, or null when there is nothing to
  /// say.
  static String? playerNote(L10n l, RecitationState s) {
    if (s.error != null) {
      return switch (s.error!) {
        RecitationError.network => l.recitationPlaybackNetwork,
        RecitationError.notFound => l.recitationPlaybackNotFound,
        RecitationError.playback => l.recitationPlaybackFailed,
      };
    }
    if (s.loading && s.pausedBy == null) return l.recitationLoading;
    return switch (s.pausedBy) {
      RecitationPause.prayer => l.recitationPausedPrayer,
      RecitationPause.interruption => l.recitationPausedInterruption,
      RecitationPause.noisy => l.recitationPausedNoisy,
      RecitationPause.sleepTimer => l.recitationPausedSleep,
      _ => null,
    };
  }
}
