import '../../engine/cinema_engine.dart';
import 'demo_game.dart';

/// Catalog entry of the engine demo.
final GameCatalogEntry demoEntry = GameCatalogEntry(
  id: 'demo',
  title: (l) => l.cinemaDemoTitle,
  tagline: (l) => l.cinemaDemoTagline,
  era: Era.rubberHose,
  tier: GameTier.short,
  genre: GameGenre.demo,
  builder: (context) => DemoGame(context: context),
);
