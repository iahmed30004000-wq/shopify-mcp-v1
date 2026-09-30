import '../../engine/cinema_engine.dart';

/// Catalog entry – announced, not playable yet. Owner: the game agent that
/// builds this game (set [GameCatalogEntry.builder] when it is playable;
/// keep the id).
final GameCatalogEntry flappyOrbitEntry = GameCatalogEntry(
  id: 'flappy_orbit',
  title: (l) => l.cinemaFlappyOrbitTitle,
  tagline: (l) => l.cinemaFlappyOrbitTagline,
  homage: (l) => l.cinemaFlappyOrbitHomage,
  era: Era.rubberHose,
  tier: GameTier.feature,
  genre: GameGenre.flyer,
);
