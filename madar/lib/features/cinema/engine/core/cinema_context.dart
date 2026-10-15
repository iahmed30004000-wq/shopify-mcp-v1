import 'dart:ui';

import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import 'cinema_env.dart';
import 'cinema_kit.dart';
import 'era_skin.dart';
import 'score.dart';

/// What a game gets from the host when it is built (see CinemaGameView).
class CinemaContext {
  CinemaContext({
    required this.kit,
    required this.l10n,
    required this.sound,
    this.haptics,
    this.scoreSink,
    this.direction = TextDirection.rtl,
    this.reducedMotion = false,
    this.skipOpening = false,
    this.seed = 0,
  });

  /// The engine implementations (standard kit, or fakes in tests).
  final CinemaKit kit;

  /// Localised strings for intertitles and HUD labels.
  final L10n l10n;

  /// App sound service – cinema audio plays on its games bus.
  final SoundService sound;
  final HapticsService? haptics;
  final ScoreSink? scoreSink;
  final TextDirection direction;
  final bool reducedMotion;

  /// Start straight into gameplay (attract mode, screenshots, tests).
  final bool skipOpening;
  final int seed;

  CinemaEnv envFor(EraSkin skin) => CinemaEnv(
    skin: skin,
    direction: direction,
    reducedMotion: reducedMotion,
    seed: seed,
    languageCode: l10n.localeName,
  );
}
