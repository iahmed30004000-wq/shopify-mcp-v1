/// «What can THIS phone run, and why» (Part 15, DoD: «a capability check
/// names which of the three paths this phone gets, with a reason he can
/// read»).
///
/// The rules, in his order:
///  1. AICore (the system's own model) when its feature probe says
///     «available»;
///  2. the in-app engine when the probe says «available», the phone has the
///     memory, the weights are on it (or there is room to download them);
///  3. the Part 3 bridge, always.
///
/// **Feature-detect, pin, never assume.** A probe that answers «unknown»
/// (a preview API that changed under us, a failed call, a word we did not
/// expect) downgrades; a version that is not one of the pinned ones
/// downgrades; a number the phone did not give is not read as «enough».
/// Nothing here throws on odd input.
///
/// **His choice wins when feasible.** A path he forces is used unless the
/// phone *cannot* run it (a hard blocker: unsupported, too little memory in
/// total, no room, too hot). A passing condition (battery saver, a warm
/// phone, other apps using the memory right now) is a soft blocker: it
/// steers the automatic choice away, but if he asked for the path he gets it
/// (the router still falls back to the bridge if it fails mid-answer).
///
/// The result carries enums and numbers only. The screen turns them into
/// Jordanian-friendly sentences (`ondevice_labels.dart`).
library;

import 'package:meta/meta.dart';

import 'model_path.dart';

/// Why a path is not available now.
enum BlockCode {
  aicoreUnsupported,
  aicoreUnknown,

  /// The probe says available, but with a version that is not one we pinned
  /// (a developer preview that changed).
  aicoreChanged,
  engineUnsupported,
  engineUnknown,
  engineChanged,

  /// Android older than the engine's minimum (`needed` / `have` = SDK ints).
  sdkTooLow,

  /// The phone did not tell us a number the check needs.
  numbersUnknown,

  /// Total memory too small (`needed` / `have` = bytes). Never passes.
  ramTooLow,

  /// Memory is mostly taken by other apps right now (bytes).
  ramBusy,

  /// Not enough free space for the weights (`needed` / `have` = bytes).
  storageLow,

  /// The engine is fine but its weights are not on the phone yet.
  weightsMissing,
  batterySaver,

  /// The phone is warm ([PathBlock.thermal]).
  thermal,
}

/// One reason a path cannot be used right now.
@immutable
class PathBlock {
  const PathBlock(this.code, {this.hard = true, this.needed, this.have, this.thermal});

  final BlockCode code;

  /// Hard: even a forced choice cannot make this path work. Soft: passes
  /// with time, or he can override it.
  final bool hard;

  /// Bytes (or an SDK level for [BlockCode.sdkTooLow]) wanted / present.
  final int? needed;
  final int? have;
  final ThermalState? thermal;

  @override
  bool operator ==(Object other) =>
      other is PathBlock &&
      other.code == code &&
      other.hard == hard &&
      other.needed == needed &&
      other.have == have &&
      other.thermal == thermal;

  @override
  int get hashCode => Object.hash(code, hard, needed, have, thermal);

  @override
  String toString() => 'PathBlock(${code.name}${hard ? '' : ' soft'}, need $needed, have $have)';
}

/// Why the chosen path was chosen.
enum PathReasonCode {
  /// AICore answers: «your phone runs the model itself through Android».
  aicoreReady,

  /// The in-app engine will run it.
  engineReady,

  /// Neither model path works here (see [PathReason.blocker]) so the bridge.
  bridgeOnly,

  /// He picked this path and the phone can run it.
  userForced,

  /// He picked a path the phone cannot run ([PathReason.blocker]); the
  /// automatic choice was used instead.
  userForcedBlocked,
}

@immutable
class PathReason {
  const PathReason(this.code, {this.blocker, this.forced});

  final PathReasonCode code;

  /// The headline obstacle when a model path was passed over.
  final PathBlock? blocker;

  /// The path he asked for ([PathReasonCode.userForced] and
  /// [PathReasonCode.userForcedBlocked]).
  final ModelPath? forced;

  @override
  String toString() => 'PathReason(${code.name}, $blocker)';
}

/// The answer: the path, why, and what each path's verdict is (the screen
/// shows all three).
@immutable
class PathChoice {
  const PathChoice({required this.path, required this.reason, required this.blocks});

  final ModelPath path;
  final PathReason reason;

  /// Per path: null = usable now, else why not. Bridge is always null.
  final Map<ModelPath, PathBlock?> blocks;

  bool canRun(ModelPath p) => blocks[p] == null;
}

/// Numbers the check compares against. **Placeholders until they are
/// measured on the Samsung S26 Ultra** (Part 15, step B): a wrong number
/// here only makes the check more or less eager, and the router's fallback
/// catches a model that fails anyway.
@immutable
class CapabilityThresholds {
  const CapabilityThresholds({
    this.minSdkInApp = 26,
    this.minTotalRamBytes = 6 * _gib,
    this.minAvailableRamBytes = _gib * 5 ~/ 2,
    this.weightsBytes = 3 * _gib,
    this.knownAiCoreVersions = const {},
    this.knownEngineVersions = const {},
  });

  static const int _gib = 1024 * 1024 * 1024;

  /// Lowest Android level the in-app engine is allowed on.
  final int minSdkInApp;

  /// Memory the whole phone must have.
  final int minTotalRamBytes;

  /// Memory that must be free when the model is about to load.
  final int minAvailableRamBytes;

  /// Free space needed to download the weights (the model plus a margin).
  final int weightsBytes;

  /// Versions we measured. Empty = no pin yet (any version the probe
  /// reports is accepted); once filled, a version outside the set is read as
  /// «changed» and downgrades.
  final Set<String> knownAiCoreVersions;
  final Set<String> knownEngineVersions;
}

abstract final class CapabilityCheck {
  /// The path this phone gets and why.
  static PathChoice choose(
    DeviceCapabilities caps,
    PathPrefs prefs, {
    CapabilityThresholds thresholds = const CapabilityThresholds(),
  }) {
    final blocks = <ModelPath, PathBlock?>{
      ModelPath.aicore: _aicore(caps, thresholds),
      ModelPath.inAppEngine: _engine(caps, thresholds),
      ModelPath.bridge: null,
    };

    final forced = prefs.forced;
    if (forced != null) {
      final b = blocks[forced];
      if (b == null || !b.hard) {
        return PathChoice(
          path: forced,
          reason: PathReason(PathReasonCode.userForced, forced: forced, blocker: b),
          blocks: blocks,
        );
      }
      final auto = _automatic(blocks);
      return PathChoice(
        path: auto.path,
        reason: PathReason(PathReasonCode.userForcedBlocked, blocker: b, forced: forced),
        blocks: blocks,
      );
    }
    return _automatic(blocks);
  }

  static PathChoice _automatic(Map<ModelPath, PathBlock?> blocks) {
    if (blocks[ModelPath.aicore] == null) {
      return PathChoice(path: ModelPath.aicore, reason: const PathReason(PathReasonCode.aicoreReady), blocks: blocks);
    }
    if (blocks[ModelPath.inAppEngine] == null) {
      return PathChoice(
        path: ModelPath.inAppEngine,
        reason: const PathReason(PathReasonCode.engineReady),
        blocks: blocks,
      );
    }
    // The headline obstacle: a passing one first (he can act on it), else
    // the in-app engine's (the last model path that was tried), else AICore's.
    final a = blocks[ModelPath.aicore]!;
    final e = blocks[ModelPath.inAppEngine]!;
    final PathBlock headline = !e.hard ? e : (!a.hard ? a : e);
    return PathChoice(
      path: ModelPath.bridge,
      reason: PathReason(PathReasonCode.bridgeOnly, blocker: headline),
      blocks: blocks,
    );
  }

  /// A probe's verdict: null when it is usable.
  static BlockCode? _probeBlock(FeatureProbe probe, Set<String> pinned, BlockCode unsupported, BlockCode unknown,
      BlockCode changed) {
    switch (probe.status) {
      case ProbeStatus.unsupported:
        return unsupported;
      case ProbeStatus.unknown:
        return unknown;
      case ProbeStatus.available:
        if (pinned.isNotEmpty && !pinned.contains(probe.version)) return changed;
        return null;
    }
  }

  /// Temperature and battery saver: shared by both model paths.
  static PathBlock? _runtime(DeviceCapabilities c) {
    switch (c.thermal) {
      case ThermalState.severe:
      case ThermalState.critical:
        return PathBlock(BlockCode.thermal, thermal: c.thermal);
      case ThermalState.moderate:
        return PathBlock(BlockCode.thermal, hard: false, thermal: c.thermal);
      case ThermalState.unknown:
      case ThermalState.none:
      case ThermalState.light:
        break;
    }
    if (c.batterySaver) return const PathBlock(BlockCode.batterySaver, hard: false);
    return null;
  }

  static PathBlock? _aicore(DeviceCapabilities c, CapabilityThresholds t) {
    final code = _probeBlock(
      c.aicore,
      t.knownAiCoreVersions,
      BlockCode.aicoreUnsupported,
      BlockCode.aicoreUnknown,
      BlockCode.aicoreChanged,
    );
    if (code != null) return PathBlock(code);
    return _runtime(c);
  }

  static PathBlock? _engine(DeviceCapabilities c, CapabilityThresholds t) {
    final code = _probeBlock(
      c.engine,
      t.knownEngineVersions,
      BlockCode.engineUnsupported,
      BlockCode.engineUnknown,
      BlockCode.engineChanged,
    );
    if (code != null) return PathBlock(code);

    final sdk = c.sdkInt, total = c.totalRamBytes;
    if (sdk == null || total == null) return const PathBlock(BlockCode.numbersUnknown);
    if (sdk < t.minSdkInApp) return PathBlock(BlockCode.sdkTooLow, needed: t.minSdkInApp, have: sdk);
    if (total < t.minTotalRamBytes) return PathBlock(BlockCode.ramTooLow, needed: t.minTotalRamBytes, have: total);

    if (!c.weightsInstalled) {
      final free = c.freeStorageBytes;
      if (free == null) return const PathBlock(BlockCode.numbersUnknown);
      if (free < t.weightsBytes) return PathBlock(BlockCode.storageLow, needed: t.weightsBytes, have: free);
      return const PathBlock(BlockCode.weightsMissing);
    }

    final runtime = _runtime(c);
    if (runtime != null) return runtime;
    final avail = c.availableRamBytes;
    if (avail == null) return const PathBlock(BlockCode.numbersUnknown, hard: false);
    if (avail < t.minAvailableRamBytes) {
      return PathBlock(BlockCode.ramBusy, hard: false, needed: t.minAvailableRamBytes, have: avail);
    }
    return null;
  }
}
