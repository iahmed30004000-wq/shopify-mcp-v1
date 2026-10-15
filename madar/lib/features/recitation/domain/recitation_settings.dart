import 'package:meta/meta.dart';

import 'reciters.dart';

/// The user's recitation preferences (KeyValues `recitation.settings`).
@immutable
class RecitationSettings {
  const RecitationSettings({
    this.reciterId = 'abdulbasit.mujawwad',
    this.repeatAyah = 1,
    this.repeatRange = 1,
    this.gapSeconds = 0,
    this.speed = 1.0,
    this.basmala = true,
    this.wifiOnly = true,
  });

  static const storageKey = 'recitation.settings';
  static const version = 1;

  /// Choices offered in the UI.
  static const repeatChoices = [1, 2, 3, 5, 7, 10];

  /// Range passes; 0 = until stopped.
  static const rangeRepeatChoices = [1, 2, 3, 5, 0];
  static const gapChoices = [0, 2, 4, 6, 10];
  static const speedChoices = [0.75, 1.0, 1.25, 1.5];
  static const maxRepeat = 99;

  final String reciterId;

  /// Default repetitions of each ayah (1–99).
  final int repeatAyah;

  /// Default passes over the range (1–99; 0 = until stopped).
  final int repeatRange;

  /// Silence after each recitation of an ayah, in seconds (0 = none).
  final int gapSeconds;

  /// Playback speed (0.5–2.0).
  final double speed;

  /// Recite the basmala before ayah 1 of each surah (not 1 and 9).
  final bool basmala;

  /// Downloads only on Wi-Fi.
  final bool wifiOnly;

  Reciter get reciter => Reciters.byId(reciterId);
  Duration get gap => Duration(seconds: gapSeconds);

  RecitationSettings copyWith({
    String? reciterId,
    int? repeatAyah,
    int? repeatRange,
    int? gapSeconds,
    double? speed,
    bool? basmala,
    bool? wifiOnly,
  }) => RecitationSettings(
    reciterId: reciterId ?? this.reciterId,
    repeatAyah: repeatAyah ?? this.repeatAyah,
    repeatRange: repeatRange ?? this.repeatRange,
    gapSeconds: gapSeconds ?? this.gapSeconds,
    speed: speed ?? this.speed,
    basmala: basmala ?? this.basmala,
    wifiOnly: wifiOnly ?? this.wifiOnly,
  );

  Map<String, Object?> toJson() => {
    'v': version,
    'reciter': reciterId,
    'repeatAyah': repeatAyah,
    'repeatRange': repeatRange,
    'gap': gapSeconds,
    'speed': speed,
    'basmala': basmala,
    'wifiOnly': wifiOnly,
  };

  /// Tolerant: unknown or out-of-range values fall back to the defaults.
  static RecitationSettings fromJson(Object? json) {
    const d = RecitationSettings();
    if (json is! Map) return d;
    int intIn(Object? v, int min, int max, int fallback) =>
        v is num && v.toInt() >= min && v.toInt() <= max ? v.toInt() : fallback;
    final speed = json['speed'];
    final reciter = json['reciter'];
    return RecitationSettings(
      reciterId: reciter is String && Reciters.byIdOrNull(reciter) != null ? reciter : d.reciterId,
      repeatAyah: intIn(json['repeatAyah'], 1, maxRepeat, d.repeatAyah),
      repeatRange: intIn(json['repeatRange'], 0, maxRepeat, d.repeatRange),
      gapSeconds: intIn(json['gap'], 0, 60, d.gapSeconds),
      speed: speed is num && speed >= 0.5 && speed <= 2.0 ? speed.toDouble() : d.speed,
      basmala: json['basmala'] is bool ? json['basmala'] as bool : d.basmala,
      wifiOnly: json['wifiOnly'] is bool ? json['wifiOnly'] as bool : d.wifiOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RecitationSettings &&
      other.reciterId == reciterId &&
      other.repeatAyah == repeatAyah &&
      other.repeatRange == repeatRange &&
      other.gapSeconds == gapSeconds &&
      other.speed == speed &&
      other.basmala == basmala &&
      other.wifiOnly == wifiOnly;

  @override
  int get hashCode => Object.hash(reciterId, repeatAyah, repeatRange, gapSeconds, speed, basmala, wifiOnly);
}
