import '../../engine/cinema_engine.dart';
import 'flappy_orbit_game.dart';

/// Catalog entry of "Flappy Orbit" (Tier 1, 1930s rubber-hose flyer).
final GameCatalogEntry flappyOrbitEntry = GameCatalogEntry(
  id: 'flappy_orbit',
  title: (l) => l.cinemaFlappyOrbitTitle,
  tagline: (l) => l.cinemaFlappyOrbitTagline,
  homage: (l) => l.cinemaFlappyOrbitHomage,
  era: Era.rubberHose,
  tier: GameTier.feature,
  genre: GameGenre.flyer,
  builder: (context) => FlappyOrbitGame(context: context),
);
