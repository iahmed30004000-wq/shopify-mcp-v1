import '../audio/era_scores.dart';
import '../fx/era_grades.dart';
import '../rig/era_inks.dart';
import '../stage/era_stages.dart';
import 'era.dart';
import 'era_palettes.dart';
import 'era_skin.dart';

/// Assembles the [EraSkin] of every era from the per-aspect tables each
/// engine agent owns (see [EraSkin] for the ownership table). The tables are
/// pure data that import only core types, so this is the only place core
/// reaches into the agents' folders.
abstract final class EraSkins {
  static final Map<Era, EraSkin> _cache = {};

  static EraSkin of(Era era) => _cache[era] ??= EraSkin(
    era: era,
    palette: eraPalette(era),
    grade: eraGrade(era),
    halftone: eraHalftone(era),
    hatch: eraHatch(era),
    ink: eraInk(era),
    score: eraScore(era),
    stage: eraStage(era),
    titles: eraTitles(era),
  );

  static List<EraSkin> get all => [for (final era in Era.values) of(era)];

  /// Forgets cached skins (hot reload of a table, tests).
  static void clearCache() => _cache.clear();
}
