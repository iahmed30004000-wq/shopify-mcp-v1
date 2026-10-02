import '../../engine/cinema_engine.dart';

/// Catalog entry – announced, not playable yet. Owner: the game agent that
/// builds this game (set [GameCatalogEntry.builder] when it is playable;
/// keep the id).
final GameCatalogEntry metropolisMachineEntry = GameCatalogEntry(
  id: 'metropolis_machine',
  title: (l) => l.cinemaMetropolisTitle,
  tagline: (l) => l.cinemaMetropolisTagline,
  homage: (l) => l.cinemaMetropolisHomage,
  era: Era.silent,
  tier: GameTier.feature,
  genre: GameGenre.bossRush,
);
