/// The words for what the pure domain decided: the domain returns enums and
/// numbers, this turns them into the owner's Jordanian Arabic (and English).
library;

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../data/model_download_manager.dart';
import '../domain/capability_check.dart';
import '../domain/model_catalog.dart';
import '../domain/model_path.dart';
import '../domain/model_router.dart';
import '../domain/religious_guard.dart';
import '../../reading/data/download_ports.dart';

abstract final class OnDeviceLabels {
  static const int _gib = 1024 * 1024 * 1024;

  /// «٣» / «٠٫٥»: whole gigabytes without a tail, otherwise one decimal.
  static String gb(MadarFormatter fmt, int bytes) => fmt.formatNumber(bytes / _gib, maxDecimals: 1);

  static String pathName(L10n l, ModelPath p) => switch (p) {
    ModelPath.aicore => l.ondevicePathAicore,
    ModelPath.inAppEngine => l.ondevicePathEngine,
    ModelPath.bridge => l.ondevicePathBridge,
  };

  static String pathHint(L10n l, ModelPath p) => switch (p) {
    ModelPath.aicore => l.ondevicePathAicoreHint,
    ModelPath.inAppEngine => l.ondevicePathEngineHint,
    ModelPath.bridge => l.ondevicePathBridgeHint,
  };

  /// Short form for the choice pills.
  static String pathShort(L10n l, ModelPath? p) => switch (p) {
    null => l.ondeviceChoiceAuto,
    ModelPath.aicore => l.ondeviceChoiceAicore,
    ModelPath.inAppEngine => l.ondeviceChoiceEngine,
    ModelPath.bridge => l.ondeviceChoiceBridge,
  };

  /// Why this path was chosen.
  static String reason(L10n l, PathReason r) => switch (r.code) {
    PathReasonCode.aicoreReady => l.ondeviceReasonAicore,
    PathReasonCode.engineReady => l.ondeviceReasonEngine,
    PathReasonCode.bridgeOnly => l.ondeviceReasonBridge,
    PathReasonCode.userForced => l.ondeviceReasonForced,
    PathReasonCode.userForcedBlocked => l.ondeviceReasonForcedBlocked,
  };

  /// Why a path is not possible, with the numbers.
  static String block(L10n l, MadarFormatter fmt, PathBlock b) {
    String gbOf(int? v) => v == null ? l.ondeviceFactUnknown : gb(fmt, v);
    return switch (b.code) {
      BlockCode.aicoreUnsupported => l.ondeviceBlockAicoreUnsupported,
      BlockCode.aicoreUnknown || BlockCode.engineUnknown || BlockCode.numbersUnknown => l.ondeviceBlockUnknown,
      BlockCode.aicoreChanged || BlockCode.engineChanged => l.ondeviceBlockChanged,
      BlockCode.engineUnsupported => l.ondeviceBlockEngineUnsupported,
      BlockCode.sdkTooLow => l.ondeviceBlockSdk(
        fmt.formatInt(b.needed ?? 0, grouping: false),
        fmt.formatInt(b.have ?? 0, grouping: false),
      ),
      BlockCode.ramTooLow => l.ondeviceBlockRamTooLow(gbOf(b.needed), gbOf(b.have)),
      BlockCode.ramBusy => l.ondeviceBlockRamBusy(gbOf(b.needed), gbOf(b.have)),
      BlockCode.storageLow => l.ondeviceBlockStorage(gbOf(b.needed), gbOf(b.have)),
      BlockCode.weightsMissing => l.ondeviceBlockWeights,
      BlockCode.batterySaver => l.ondeviceBlockBatterySaver,
      BlockCode.thermal => l.ondeviceBlockThermal,
    };
  }

  static String heat(L10n l, ThermalState t) => switch (t) {
    ThermalState.unknown => l.ondeviceFactUnknown,
    ThermalState.none || ThermalState.light => l.ondeviceHeatNormal,
    ThermalState.moderate => l.ondeviceHeatWarm,
    ThermalState.severe || ThermalState.critical => l.ondeviceHeatHot,
  };

  /// The fixed message shown instead of a refused answer (never any of the
  /// refused text).
  static String refusal(L10n l, GuardKind kind) =>
      kind == GuardKind.health ? l.ondeviceRefusalHealth : l.ondeviceRefusalReligious;

  /// One line saying why the bridge is being used instead of the model.
  static String? bridgeReason(L10n l, BridgeReason r) => switch (r) {
    BridgeReason.pathIsBridge => null,
    BridgeReason.modelNotReady || BridgeReason.inputTooLong => l.ondeviceBridgeNotReady,
    BridgeReason.failedMidAnswer || BridgeReason.emptyAnswer => l.ondeviceBridgeFailed,
    BridgeReason.outOfMemory => l.ondeviceBridgeMemory,
    BridgeReason.timedOut => l.ondeviceBridgeSlow,
  };

  static String kind(L10n l, ModelKind k) =>
      k == ModelKind.language ? l.ondeviceModelKindLanguage : l.ondeviceModelKindRecitation;

  /// The state line under a model; null when there is nothing to say.
  static String? installLine(L10n l, MadarFormatter fmt, ModelInstallState s) => switch (s.status) {
    ModelInstallStatus.notInstalled => null,
    ModelInstallStatus.installed => l.ondeviceInstalled,
    ModelInstallStatus.downloading => l.ondeviceDownloading(fmt.formatPercent(s.fraction)),
    ModelInstallStatus.verifying => l.ondeviceVerifying,
    ModelInstallStatus.paused => switch (s.pauseReason) {
      PauseReason.storageFull => l.ondevicePausedStorage,
      PauseReason.waitingForWifi => l.ondevicePausedWifi,
      PauseReason.offline => l.ondevicePausedOffline,
      PauseReason.connectionLost => l.ondevicePausedLost,
      PauseReason.user || null => l.ondevicePausedUser,
    },
    ModelInstallStatus.failed =>
      s.failure == DownloadFailure.checksumMismatch || s.failure == DownloadFailure.partChecksumMismatch
          ? l.ondeviceFailedChecksum
          : l.ondeviceFailed,
  };

  /// What to tell him when a download did not start (null: say nothing, it
  /// is already running).
  static String? refusedStart(L10n l, StartRefusal r) => switch (r) {
    StartRefusal.unverified || StartRefusal.incomplete => l.ondeviceRefusedUnverified,
    StartRefusal.authDenied => l.ondeviceRefusedAuth,
    StartRefusal.alreadyRunning => null,
  };
}
