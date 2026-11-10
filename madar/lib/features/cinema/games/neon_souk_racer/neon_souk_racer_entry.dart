import '../../engine/cinema_engine.dart';

/// Catalog entry – announced, not playable yet. Owner: the game agent that
/// builds this game (set [GameCatalogEntry.builder] when it is playable;
/// keep the id).
final GameCatalogEntry neonSoukRacerEntry = GameCatalogEntry(
  id: 'neon_souk_racer',
  title: (l) => l.cinemaNeonSoukTitle,
  tagline: (l) => l.cinemaNeonSoukTagline,
  homage: (l) => l.cinemaNeonSoukHomage,
  era: Era.vhs,
  tier: GameTier.feature,
  genre: GameGenre.racer,
);
