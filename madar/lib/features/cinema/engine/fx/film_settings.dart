import 'package:flutter/foundation.dart';

import 'film_look.dart';

/// The player's film-look preferences, read by `createFilmFx` each time a
/// game starts (the FX entry point receives only a CinemaEnv, so the app
/// publishes them here).
///
/// Wiring (hall / CinemaGameView, once per build):
/// ```dart
/// FilmSettings.current = FilmSettings(
///   quality: userChoice,          // null = automatic
///   strength: userStrength,       // 0..1
///   batterySaver: settings.powerMode == PowerMode.batterySaver,
/// );
/// ```
/// Reduced motion is not a setting here: it comes from `CinemaEnv` through
/// `FilmFrame.reduceFlicker`.
@immutable
class FilmSettings {
  const FilmSettings({this.quality, this.strength = 1, this.batterySaver = false});

  /// Fixed quality, or `null` for automatic (balanced, with adaptive LOD in
  /// profile/release builds).
  final FilmQuality? quality;

  /// Strength of the film look, 0 (clean print, colour grade only) .. 1.
  final double strength;

  /// The app runs in battery-saver mode: always [FilmQuality.lowPower].
  final bool batterySaver;

  /// What a new game's FilmFx starts with.
  static FilmSettings current = const FilmSettings();

  FilmQuality get effectiveQuality => batterySaver ? FilmQuality.lowPower : (quality ?? FilmQuality.balanced);

  /// Adaptive LOD only in automatic mode (a fixed choice is respected).
  bool? get adaptive => (quality == null && !batterySaver) ? null : false;

  FilmSettings copyWith({FilmQuality? quality, bool clearQuality = false, double? strength, bool? batterySaver}) => FilmSettings(
    quality: clearQuality ? null : (quality ?? this.quality),
    strength: strength ?? this.strength,
    batterySaver: batterySaver ?? this.batterySaver,
  );

  @override
  bool operator ==(Object other) =>
      other is FilmSettings && other.quality == quality && other.strength == strength && other.batterySaver == batterySaver;

  @override
  int get hashCode => Object.hash(quality, strength, batterySaver);
}
