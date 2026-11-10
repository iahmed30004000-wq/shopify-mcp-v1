/// The three places an answer can be produced, and what the phone says about
/// itself (Part 15). Pure Dart: no channel, no widget.
///
/// The owner's order is fixed: the system's own model (AICore) first, then an
/// engine inside Madar, then the Part 3 bridge (copy / paste with any AI app),
/// which works on every phone and is therefore the floor.
library;

import 'package:meta/meta.dart';

enum ModelPath {
  /// Gemma through the system's AICore service (ML Kit Prompt API): the
  /// weights belong to Android, not to the app.
  aicore,

  /// An engine running inside Madar (Google AI Edge / LiteRT) over weights
  /// the owner chose to download.
  inAppEngine,

  /// Part 3's file / clipboard round trip. Needs no model and no network
  /// from Madar.
  bridge;

  /// The two paths that run a model on the phone (nothing leaves it).
  bool get runsOnPhone => this != ModelPath.bridge;
}

/// What a feature probe answered. «Unknown» is its own value on purpose: a
/// preview API that returns something we did not expect is never read as
/// «available».
enum ProbeStatus {
  available,
  unsupported,
  unknown;

  /// Anything that is not exactly a known word is [unknown], never
  /// [available]: feature-detect, pin, never assume.
  static ProbeStatus parse(Object? raw) => switch (raw) {
    'available' => ProbeStatus.available,
    'unsupported' => ProbeStatus.unsupported,
    _ => ProbeStatus.unknown,
  };
}

/// One probe's answer, with the version string the engine reported (when it
/// reported one) so a changed preview can be told apart from the one we
/// measured.
@immutable
class FeatureProbe {
  const FeatureProbe(this.status, {this.version});

  const FeatureProbe.unsupported() : this(ProbeStatus.unsupported);
  const FeatureProbe.unknown() : this(ProbeStatus.unknown);
  const FeatureProbe.available({String? version}) : this(ProbeStatus.available, version: version);

  final ProbeStatus status;
  final String? version;

  @override
  bool operator ==(Object other) => other is FeatureProbe && other.status == status && other.version == version;

  @override
  int get hashCode => Object.hash(status, version);

  @override
  String toString() => 'FeatureProbe(${status.name}${version == null ? '' : ' $version'})';
}

/// Android's PowerManager thermal status, folded. [unknown] (an old Android,
/// or no answer) is never treated as hot.
enum ThermalState {
  unknown,
  none,
  light,
  moderate,
  severe,
  critical;

  /// `PowerManager.THERMAL_STATUS_*`: 0 none, 1 light, 2 moderate, 3 severe,
  /// 4 critical, 5 emergency, 6 shutdown. Emergency and shutdown read as
  /// [critical]; anything else is [unknown].
  static ThermalState fromAndroid(Object? status) => switch (status) {
    0 => ThermalState.none,
    1 => ThermalState.light,
    2 => ThermalState.moderate,
    3 => ThermalState.severe,
    4 || 5 || 6 => ThermalState.critical,
    _ => ThermalState.unknown,
  };
}

/// Everything the capability check may look at. Numbers the phone did not
/// give are null (never zero): a missing number is not «no memory».
@immutable
class DeviceCapabilities {
  const DeviceCapabilities({
    this.sdkInt,
    this.totalRamBytes,
    this.availableRamBytes,
    this.freeStorageBytes,
    this.aicore = const FeatureProbe.unknown(),
    this.engine = const FeatureProbe.unknown(),
    this.thermal = ThermalState.unknown,
    this.batterySaver = false,
    this.weightsInstalled = false,
  });

  /// What a phone with no answer at all looks like (no channel, or a failed
  /// call): everything unknown, so the bridge is chosen.
  const DeviceCapabilities.unknown() : this();

  final int? sdkInt;
  final int? totalRamBytes;
  final int? availableRamBytes;
  final int? freeStorageBytes;

  /// The AICore feature probe (the platform's own «is the Prompt API
  /// available here» answer).
  final FeatureProbe aicore;

  /// The in-app engine's probe.
  final FeatureProbe engine;
  final ThermalState thermal;
  final bool batterySaver;

  /// The in-app engine's weights are already on the phone, so no download
  /// space is needed.
  final bool weightsInstalled;

  DeviceCapabilities copyWith({
    int? sdkInt,
    int? totalRamBytes,
    int? availableRamBytes,
    int? freeStorageBytes,
    FeatureProbe? aicore,
    FeatureProbe? engine,
    ThermalState? thermal,
    bool? batterySaver,
    bool? weightsInstalled,
  }) => DeviceCapabilities(
    sdkInt: sdkInt ?? this.sdkInt,
    totalRamBytes: totalRamBytes ?? this.totalRamBytes,
    availableRamBytes: availableRamBytes ?? this.availableRamBytes,
    freeStorageBytes: freeStorageBytes ?? this.freeStorageBytes,
    aicore: aicore ?? this.aicore,
    engine: engine ?? this.engine,
    thermal: thermal ?? this.thermal,
    batterySaver: batterySaver ?? this.batterySaver,
    weightsInstalled: weightsInstalled ?? this.weightsInstalled,
  );
}

/// The owner's own choice: automatic (null) or one path.
@immutable
class PathPrefs {
  const PathPrefs({this.forced, this.wifiOnly = true});

  /// `key_values` key.
  static const String storageKey = 'ondevice.prefs';

  /// Null = automatic (the order above).
  final ModelPath? forced;

  /// Downloads of the weights wait for Wi-Fi. On by default.
  final bool wifiOnly;

  PathPrefs copyWith({ModelPath? forced, bool clearForced = false, bool? wifiOnly}) =>
      PathPrefs(forced: clearForced ? null : forced ?? this.forced, wifiOnly: wifiOnly ?? this.wifiOnly);

  Map<String, Object?> toJson() => {if (forced != null) 'forced': forced!.name, 'wifiOnly': wifiOnly};

  /// Reads what was stored; anything unreadable gives the defaults.
  factory PathPrefs.fromJson(Object? json) {
    if (json is! Map) return const PathPrefs();
    final f = json['forced'];
    final forced = f is String ? ModelPath.values.where((p) => p.name == f).firstOrNull : null;
    return PathPrefs(forced: forced, wifiOnly: json['wifiOnly'] is bool ? json['wifiOnly'] as bool : true);
  }

  @override
  bool operator ==(Object other) => other is PathPrefs && other.forced == forced && other.wifiOnly == wifiOnly;

  @override
  int get hashCode => Object.hash(forced, wifiOnly);
}
