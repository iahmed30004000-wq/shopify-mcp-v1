import '../../engine/cinema_engine.dart';
import 'metropolis_game.dart';

/// Catalog entry of Metropolis Machine (1920s silent sepia boss rush).
final GameCatalogEntry metropolisMachineEntry = GameCatalogEntry(
  id: 'metropolis_machine',
  title: (l) => l.cinemaMetropolisTitle,
  tagline: (l) => l.cinemaMetropolisTagline,
  homage: (l) => l.cinemaMetropolisHomage,
  era: Era.silent,
  tier: GameTier.feature,
  genre: GameGenre.bossRush,
  builder: (context) => MetropolisGame(context: context),
);
