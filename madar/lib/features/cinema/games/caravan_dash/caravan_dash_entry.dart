import '../../engine/cinema_engine.dart';

/// Catalog entry – announced, not playable yet. Owner: the game agent that
/// builds this game (set [GameCatalogEntry.builder] when it is playable;
/// keep the id).
final GameCatalogEntry caravanDashEntry = GameCatalogEntry(
  id: 'caravan_dash',
  title: (l) => l.cinemaCaravanTitle,
  tagline: (l) => l.cinemaCaravanTagline,
  homage: (l) => l.cinemaCaravanHomage,
  era: Era.technicolor,
  tier: GameTier.feature,
  genre: GameGenre.runner,
);
