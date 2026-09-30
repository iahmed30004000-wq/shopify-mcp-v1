import 'package:flutter/foundation.dart';

import '../../../../core/i18n/gen/app_localizations.dart';
import 'cinema_context.dart';
import 'cinema_game.dart';
import 'era.dart';

/// Tier 1 = "features" (original action games with bosses, rigs, scores);
/// Tier 2 = "shorts" (card / board / arcade / word games on the same engine
/// and era skins).
enum GameTier {
  feature(1),
  short(2);

  const GameTier(this.number);
  final int number;
}

enum GameGenre { demo, flyer, bossRush, runner, platformer, racer, card, board, arcade, puzzle, word }

/// Builds a fresh game for one play (a restart builds another).
typedef CinemaGameBuilder = CinemaGame Function(CinemaContext context);

/// One entry of the Madar Cinema programme.
///
/// Names are ARB strings (Arabic primary) resolved through [L10n] – never
/// hard-coded. [builder] `null` = announced ("coming soon") but not playable.
@immutable
class GameCatalogEntry {
  const GameCatalogEntry({
    required this.id,
    required this.title,
    required this.tagline,
    required this.era,
    required this.tier,
    required this.genre,
    this.homage,
    this.builder,
  });

  /// Stable id: snake_case, also the games/<id>/ folder name and the score key.
  final String id;
  final String Function(L10n l10n) title;
  final String Function(L10n l10n) tagline;

  /// The film(s) the game pays homage to (style only – see ENGINE.md).
  final String Function(L10n l10n)? homage;
  final Era era;
  final GameTier tier;
  final GameGenre genre;
  final CinemaGameBuilder? builder;

  bool get isPlayable => builder != null;
}
