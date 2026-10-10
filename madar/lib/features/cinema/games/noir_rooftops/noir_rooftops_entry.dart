import '../../engine/cinema_engine.dart';

/// Catalog entry – announced, not playable yet. Owner: the game agent that
/// builds this game (set [GameCatalogEntry.builder] when it is playable;
/// keep the id).
final GameCatalogEntry noirRooftopsEntry = GameCatalogEntry(
  id: 'noir_rooftops',
  title: (l) => l.cinemaNoirTitle,
  tagline: (l) => l.cinemaNoirTagline,
  homage: (l) => l.cinemaNoirHomage,
  era: Era.noir,
  tier: GameTier.feature,
  genre: GameGenre.platformer,
);
