/// Madar Cinema – Tier 2 board games: pure-Dart rules engines and AI
/// opponents behind one interface.
///
/// ```dart
/// final kit = boardGameKits[BoardGameId.chess]!;
/// final engine = kit.engine(players: 2, seed: 42);
/// final move = kit.ai.chooseMove(engine.state, AiLevel.hard, BoardRng(7));
/// engine.apply(move);
/// ```
///
/// [boardGameKits] starts every game as commonly played in Jordan (the
/// default mode). [boardVariantKits] has one kit per lobby mode
/// ([BoardVariantId]): «الضامة» and the diagonal draughts presets, the three
/// tawla games («شيش بيش», «محبوسة», «٣١») and international backgammon, the
/// domino presets, Ludo and Ludo in partnerships, Kalah and Oware. Options
/// beyond the presets are set through each game's config and
/// `…State.initial(config: …)`.
///
/// Variants, Arabic names and every rules decision: see `RULES.md` next to
/// this file.
library;

import 'backgammon/backgammon_ai.dart';
import 'backgammon/backgammon_rules.dart';
import 'checkers/checkers_ai.dart';
import 'checkers/checkers_rules.dart';
import 'chess/chess_ai.dart';
import 'chess/chess_rules.dart';
import 'connect_four/connect_four_ai.dart';
import 'connect_four/connect_four_rules.dart';
import 'core/engine.dart';
import 'core/game_types.dart';
import 'dominoes/dominoes_ai.dart';
import 'dominoes/dominoes_rules.dart';
import 'ludo/ludo_ai.dart';
import 'ludo/ludo_rules.dart';
import 'mancala/mancala_ai.dart';
import 'mancala/mancala_rules.dart';
import 'tic_tac_toe/tic_tac_toe_ai.dart';
import 'tic_tac_toe/tic_tac_toe_rules.dart';

export 'backgammon/backgammon_ai.dart' show BackgammonAi;
export 'backgammon/backgammon_rules.dart'
    show
        BackgammonConfig,
        BackgammonMove,
        BackgammonMoveKind,
        BackgammonPhase,
        BackgammonRules,
        BackgammonState,
        BackgammonStep,
        MahbusaScoring,
        Tawla31Layout,
        Tawla31RunnerTarget,
        TawlaGameEnd,
        TawlaGameSummary,
        TawlaNextStarter,
        TawlaTriple,
        TawlaVariant,
        backgammonRules,
        tawlaEndReason;
export 'checkers/checkers_ai.dart' show CheckersAi;
export 'checkers/checkers_rules.dart'
    show
        CheckersConfig,
        CheckersGameEnd,
        CheckersGeometry,
        CheckersMove,
        CheckersPiece,
        CheckersPromotionInCapture,
        CheckersRules,
        CheckersState,
        CheckersVariant,
        checkersEndReason,
        checkersRules;
export 'chess/chess_ai.dart' show ChessAi;
export 'chess/chess_rules.dart'
    show ChessMove, ChessPiece, ChessPieceType, ChessRules, ChessState, chessRules, kStartFen, parseSquare, squareName;
export 'connect_four/connect_four_ai.dart' show ConnectFourAi;
export 'connect_four/connect_four_rules.dart'
    show ConnectFourMove, ConnectFourRules, ConnectFourState, connectFourRules, kC4Cols, kC4Rows;
export 'core/ai_isolate.dart';
export 'core/engine.dart';
export 'core/game_types.dart'
    show
        AiBudget,
        AiLevel,
        BoardGameId,
        BoardVariantId,
        GameEndReason,
        GameMove,
        GameResult,
        GameState,
        IllegalMoveException;
export 'core/rng.dart';
export 'dominoes/dominoes_ai.dart' show DominoAi;
export 'dominoes/dominoes_rules.dart'
    show
        Domino,
        DominoBlockedCompare,
        DominoBlockedScoring,
        DominoBlockedTie,
        DominoConfig,
        DominoEnd,
        DominoMove,
        DominoMoveKind,
        DominoNoDoubleOpening,
        DominoPhase,
        DominoRoundEnd,
        DominoRoundSummary,
        DominoRounding,
        DominoRules,
        DominoScoring,
        DominoState,
        PlacedDomino,
        dominoRules;
export 'ludo/ludo_ai.dart' show LudoAi;
export 'ludo/ludo_rules.dart'
    show
        LudoConfig,
        LudoFirstPlayer,
        LudoMove,
        LudoMoveKind,
        LudoPhase,
        LudoRules,
        LudoSafeSquares,
        LudoState,
        kLudoBeforeStart,
        kLudoHome,
        kLudoLastTrack,
        kLudoYard,
        ludoRules;
export 'mancala/mancala_ai.dart' show MancalaAi;
export 'mancala/mancala_rules.dart'
    show MancalaConfig, MancalaMove, MancalaRules, MancalaState, MancalaVariant, mancalaRules;
export 'tic_tac_toe/tic_tac_toe_ai.dart' show TicTacToeAi;
export 'tic_tac_toe/tic_tac_toe_rules.dart'
    show TicTacToeMove, TicTacToeRules, TicTacToeState, kTicTacToeLines, ticTacToeRules;

/// One kit per lobby mode, keyed by [BoardVariantId] in declaration order
/// (each game's default mode first). A kit's `newGame` starts that mode; the
/// rules and the AI are shared by every mode of a game.
final Map<BoardVariantId, BoardGameKit<GameState, GameMove>> boardVariantKits = {
  for (final v in BoardVariantId.values) v: _kit(v),
};

/// Every game in its default mode – as commonly played in Jordan – keyed by
/// id. Games with options expose their own `…State.initial(config: …)` for
/// the lobby; [boardVariantKits] has the named presets.
final Map<BoardGameId, BoardGameKit<GameState, GameMove>> boardGameKits = {
  for (final id in BoardGameId.values) id: boardVariantKits[BoardVariantId.defaultOf(id)]!,
};

/// The kits of every mode of [game], the default first.
List<BoardGameKit<GameState, GameMove>> boardVariantKitsOf(BoardGameId game) => [
  for (final v in BoardVariantId.of(game)) boardVariantKits[v]!,
];

BoardGameKit<GameState, GameMove> _kit(BoardVariantId v) => switch (v) {
  BoardVariantId.chess => BoardGameKit<ChessState, ChessMove>(
    id: BoardGameId.chess,
    variant: v,
    rules: chessRules,
    ai: ChessAi(),
    minPlayers: 2,
    maxPlayers: 2,
    newGame: ({int players = 2, int seed = 0}) => ChessState.initial(),
  ),
  BoardVariantId.damaJordan => _checkers(v, CheckersConfig.jordan),
  BoardVariantId.damaTurkish => _checkers(v, CheckersConfig.turkish),
  BoardVariantId.draughtsAmerican => _checkers(v, CheckersConfig.american),
  BoardVariantId.draughtsAmericanFlyingKings => _checkers(v, CheckersConfig.americanFlyingKings),
  BoardVariantId.tawlaSheshBesh => _tawla(v, BackgammonConfig.jordan),
  BoardVariantId.tawlaMahbusa => _tawla(v, BackgammonConfig.mahbusa),
  BoardVariantId.tawla31 => _tawla(v, BackgammonConfig.tawla31),
  BoardVariantId.backgammonInternational => _tawla(v, BackgammonConfig.international),
  BoardVariantId.dominoesJordan => _dominoes(v, (n) => DominoConfig.jordan(players: n)),
  BoardVariantId.dominoesAllFives => _dominoes(v, (n) => DominoConfig.allFives(players: n)),
  BoardVariantId.dominoesBlock => _dominoes(v, (n) => DominoConfig.block(players: n)),
  BoardVariantId.dominoesPlayOutLock => _dominoes(v, (n) => DominoConfig.playOutLock(players: n)),
  BoardVariantId.ludoJordan => BoardGameKit<LudoState, LudoMove>(
    id: BoardGameId.ludo,
    variant: v,
    rules: ludoRules,
    ai: const LudoAi(),
    minPlayers: 2,
    maxPlayers: 4,
    newGame: ({int players = 2, int seed = 0}) => LudoState.initial(
      seed: seed,
      config: LudoConfig.jordan(players: players),
    ),
  ),
  BoardVariantId.ludoTeams => BoardGameKit<LudoState, LudoMove>(
    id: BoardGameId.ludo,
    variant: v,
    rules: ludoRules,
    ai: const LudoAi(),
    minPlayers: 4,
    maxPlayers: 4,
    newGame: ({int players = 4, int seed = 0}) => LudoState.initial(
      seed: seed,
      config: LudoConfig(players: players, teams: true),
    ),
  ),
  BoardVariantId.mancalaKalah => _mancala(v, MancalaConfig.kalah),
  BoardVariantId.mancalaOware => _mancala(v, MancalaConfig.oware),
  BoardVariantId.connectFour => BoardGameKit<ConnectFourState, ConnectFourMove>(
    id: BoardGameId.connectFour,
    variant: v,
    rules: connectFourRules,
    ai: const ConnectFourAi(),
    minPlayers: 2,
    maxPlayers: 2,
    newGame: ({int players = 2, int seed = 0}) => ConnectFourState.initial(),
  ),
  BoardVariantId.ticTacToe => BoardGameKit<TicTacToeState, TicTacToeMove>(
    id: BoardGameId.ticTacToe,
    variant: v,
    rules: ticTacToeRules,
    ai: const TicTacToeAi(),
    minPlayers: 2,
    maxPlayers: 2,
    newGame: ({int players = 2, int seed = 0}) => TicTacToeState.initial(),
  ),
};

BoardGameKit<CheckersState, CheckersMove> _checkers(BoardVariantId v, CheckersConfig config) =>
    BoardGameKit<CheckersState, CheckersMove>(
      id: BoardGameId.checkers,
      variant: v,
      rules: checkersRules,
      ai: const CheckersAi(),
      minPlayers: 2,
      maxPlayers: 2,
      newGame: ({int players = 2, int seed = 0}) => CheckersState.initial(config),
    );

/// A tawla mode starts a match (to 5, or 31 for ٣١; international: one
/// game) whose opening roll comes from [seed].
BoardGameKit<BackgammonState, BackgammonMove> _tawla(BoardVariantId v, BackgammonConfig config) =>
    BoardGameKit<BackgammonState, BackgammonMove>(
      id: BoardGameId.backgammon,
      variant: v,
      rules: backgammonRules,
      ai: const BackgammonAi(),
      minPlayers: 2,
      maxPlayers: 2,
      newGame: ({int players = 2, int seed = 0}) => BackgammonState.initial(seed: seed, config: config),
    );

BoardGameKit<DominoState, DominoMove> _dominoes(BoardVariantId v, DominoConfig Function(int players) config) =>
    BoardGameKit<DominoState, DominoMove>(
      id: BoardGameId.dominoes,
      variant: v,
      rules: dominoRules,
      ai: const DominoAi(),
      minPlayers: 2,
      maxPlayers: 4,
      newGame: ({int players = 2, int seed = 0}) => DominoState.initial(seed: seed, config: config(players)),
    );

BoardGameKit<MancalaState, MancalaMove> _mancala(BoardVariantId v, MancalaConfig config) =>
    BoardGameKit<MancalaState, MancalaMove>(
      id: BoardGameId.mancala,
      variant: v,
      rules: mancalaRules,
      ai: const MancalaAi(),
      minPlayers: 2,
      maxPlayers: 2,
      newGame: ({int players = 2, int seed = 0}) => MancalaState.initial(config),
    );
