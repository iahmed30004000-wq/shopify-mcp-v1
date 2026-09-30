/// Madar Cinema Tier 2 puzzles: pure-Dart rules, generators, solvers and
/// hints behind the uniform [PuzzleGame] interface.
///
/// See `lib/features/cinema/rules/PUZZLES_ARCADE.md`.
library;

import 'blocks/falling_blocks.dart';
import 'core/puzzle_game.dart';
import 'jewels/souk_jewels.dart';
import 'lights_out/lights_out.dart';
import 'mahjong/mahjong.dart';
import 'memory/star_memory.dart';
import 'merge/merge_2048.dart';
import 'minesweeper/minesweeper.dart';
import 'nonogram/nonogram.dart';
import 'pipes/pipe_connect.dart';
import 'sliding/sliding_tiles.dart';
import 'sudoku/sudoku_game.dart';
import 'tangram/tangram_game.dart';

export 'blocks/falling_blocks.dart';
export 'core/grid.dart';
export 'core/puzzle_game.dart';
export 'core/seeded_rng.dart';
export 'jewels/souk_jewels.dart';
export 'lights_out/lights_out.dart';
export 'mahjong/mahjong.dart';
export 'memory/star_memory.dart';
export 'merge/merge_2048.dart';
export 'minesweeper/minesweeper.dart';
export 'nonogram/nonogram.dart';
export 'pipes/pipe_connect.dart';
export 'sliding/sliding_tiles.dart';
export 'sudoku/sudoku_core.dart';
export 'sudoku/sudoku_game.dart';
export 'sudoku/sudoku_generator.dart';
export 'sudoku/sudoku_logic.dart';
export 'tangram/tangram_game.dart';

/// Restores any puzzle saved with `toJson()`.
PuzzleGame<PuzzleState, PuzzleAction> puzzleFromJson(Map<String, Object?> json) {
  final kind = PuzzleKind.values.byName(json['kind']! as String);
  final PuzzleGame<PuzzleState, PuzzleAction> game = switch (kind) {
    PuzzleKind.merge2048 => Merge2048Game.fromJson(json),
    PuzzleKind.sudoku => SudokuGame.fromJson(json),
    PuzzleKind.minesweeper => MinesweeperGame.fromJson(json),
    PuzzleKind.nonogram => NonogramGame.fromJson(json),
    PuzzleKind.mahjong => MahjongGame.fromJson(json),
    PuzzleKind.slidingTiles => SlidingGame.fromJson(json),
    PuzzleKind.lightsOut => LightsOutGame.fromJson(json),
    PuzzleKind.pipeConnect => PipeGame.fromJson(json),
    PuzzleKind.tangram => TangramGame.fromJson(json),
    PuzzleKind.starMemory => StarMemoryGame.fromJson(json),
    PuzzleKind.soukJewels => JewelsGame.fromJson(json),
    PuzzleKind.fallingBlocks => FallingBlocksGame.fromJson(json),
  };
  return game;
}

/// Parses an action of [kind] saved with `toJson()` (replays).
PuzzleAction puzzleActionFromJson(PuzzleKind kind, Map<String, Object?> json) => switch (kind) {
  PuzzleKind.merge2048 => Merge2048Action.fromJson(json),
  PuzzleKind.sudoku => SudokuAction.fromJson(json),
  PuzzleKind.minesweeper => MinesweeperAction.fromJson(json),
  PuzzleKind.nonogram => NonogramAction.fromJson(json),
  PuzzleKind.mahjong => MahjongAction.fromJson(json),
  PuzzleKind.slidingTiles => SlidingAction.fromJson(json),
  PuzzleKind.lightsOut => LightsOutAction.fromJson(json),
  PuzzleKind.pipeConnect => PipeAction.fromJson(json),
  PuzzleKind.tangram => TangramAction.fromJson(json),
  PuzzleKind.starMemory => StarMemoryAction.fromJson(json),
  PuzzleKind.soukJewels => JewelsAction.fromJson(json),
  PuzzleKind.fallingBlocks => FallingAction.fromJson(json),
};

/// Creates a new puzzle of [kind] at [difficulty] from [seed] with the
/// default options of each game.
PuzzleGame<PuzzleState, PuzzleAction> newPuzzle(PuzzleKind kind, PuzzleDifficulty difficulty, int seed) =>
    switch (kind) {
      PuzzleKind.merge2048 => Merge2048Game(Merge2048Config.forDifficulty(difficulty, seed: seed)),
      PuzzleKind.sudoku => SudokuGame.generate(difficulty, seed),
      PuzzleKind.minesweeper => MinesweeperGame(MinesweeperConfig.forDifficulty(difficulty, seed: seed)),
      PuzzleKind.nonogram => NonogramGame.generate(difficulty, seed),
      PuzzleKind.mahjong => MahjongGame(MahjongConfig.forDifficulty(difficulty, seed: seed)),
      PuzzleKind.slidingTiles => SlidingGame(
        SlidingConfig(size: difficulty.index <= 1 ? 3 : (difficulty == PuzzleDifficulty.hard ? 4 : 5), difficulty: difficulty, seed: seed),
      ),
      PuzzleKind.lightsOut => LightsOutGame(LightsOutConfig(difficulty: difficulty, seed: seed)),
      PuzzleKind.pipeConnect => PipeGame(PipeConfig.forDifficulty(difficulty, seed: seed)),
      PuzzleKind.tangram => TangramGame(TangramConfig.forDifficulty(difficulty, seed)),
      PuzzleKind.starMemory => StarMemoryGame(StarMemoryConfig.forDifficulty(difficulty, seed: seed)),
      PuzzleKind.soukJewels => JewelsGame(JewelsConfig.forDifficulty(difficulty, seed: seed)),
      PuzzleKind.fallingBlocks => FallingBlocksGame(FallingConfig.forDifficulty(difficulty, seed: seed)),
    };
