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
/// Variants, Arabic names and every rules assumption: see `RULES.md` next to
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
        backgammonRules;
export 'checkers/checkers_ai.dart' show CheckersAi;
export 'checkers/checkers_rules.dart'
    show
        CheckersConfig,
        CheckersGeometry,
        CheckersMove,
        CheckersPiece,
        CheckersPromotionInCapture,
        CheckersRules,
        CheckersState,
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
    show AiBudget, AiLevel, BoardGameId, GameEndReason, GameMove, GameResult, GameState, IllegalMoveException;
export 'core/rng.dart';
export 'dominoes/dominoes_ai.dart' show DominoAi;
export 'dominoes/dominoes_rules.dart'
    show
        Domino,
        DominoConfig,
        DominoEnd,
        DominoMove,
        DominoMoveKind,
        DominoPhase,
        DominoRoundEnd,
        DominoRoundSummary,
        DominoRules,
        DominoState,
        PlacedDomino,
        dominoRules;
export 'ludo/ludo_ai.dart' show LudoAi;
export 'ludo/ludo_rules.dart'
    show
        LudoConfig,
        LudoMove,
        LudoMoveKind,
        LudoPhase,
        LudoRules,
        LudoSafeSquares,
        LudoState,
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

/// Every game with default options, keyed by id. Games with options expose
/// their own `…State.initial(config: …)` for the lobby.
final Map<BoardGameId, BoardGameKit<GameState, GameMove>> boardGameKits = {
  BoardGameId.chess: BoardGameKit<ChessState, ChessMove>(
    id: BoardGameId.chess,
    rules: chessRules,
    ai: ChessAi(),
    minPlayers: 2,
    maxPlayers: 2,
    newGame: ({int players = 2, int seed = 0}) => ChessState.initial(),
  ),
  BoardGameId.checkers: BoardGameKit<CheckersState, CheckersMove>(
    id: BoardGameId.checkers,
    rules: checkersRules,
    ai: const CheckersAi(),
    minPlayers: 2,
    maxPlayers: 2,
    newGame: ({int players = 2, int seed = 0}) => CheckersState.initial(),
  ),
  BoardGameId.backgammon: BoardGameKit<BackgammonState, BackgammonMove>(
    id: BoardGameId.backgammon,
    rules: backgammonRules,
    ai: const BackgammonAi(),
    minPlayers: 2,
    maxPlayers: 2,
    newGame: ({int players = 2, int seed = 0}) => BackgammonState.initial(seed: seed),
  ),
  BoardGameId.dominoes: BoardGameKit<DominoState, DominoMove>(
    id: BoardGameId.dominoes,
    rules: dominoRules,
    ai: const DominoAi(),
    minPlayers: 2,
    maxPlayers: 4,
    newGame: ({int players = 2, int seed = 0}) => DominoState.initial(
      seed: seed,
      config: DominoConfig(players: players),
    ),
  ),
  BoardGameId.ludo: BoardGameKit<LudoState, LudoMove>(
    id: BoardGameId.ludo,
    rules: ludoRules,
    ai: const LudoAi(),
    minPlayers: 2,
    maxPlayers: 4,
    newGame: ({int players = 2, int seed = 0}) => LudoState.initial(
      seed: seed,
      config: LudoConfig(players: players),
    ),
  ),
  BoardGameId.mancala: BoardGameKit<MancalaState, MancalaMove>(
    id: BoardGameId.mancala,
    rules: mancalaRules,
    ai: const MancalaAi(),
    minPlayers: 2,
    maxPlayers: 2,
    newGame: ({int players = 2, int seed = 0}) => MancalaState.initial(),
  ),
  BoardGameId.connectFour: BoardGameKit<ConnectFourState, ConnectFourMove>(
    id: BoardGameId.connectFour,
    rules: connectFourRules,
    ai: const ConnectFourAi(),
    minPlayers: 2,
    maxPlayers: 2,
    newGame: ({int players = 2, int seed = 0}) => ConnectFourState.initial(),
  ),
  BoardGameId.ticTacToe: BoardGameKit<TicTacToeState, TicTacToeMove>(
    id: BoardGameId.ticTacToe,
    rules: ticTacToeRules,
    ai: const TicTacToeAi(),
    minPlayers: 2,
    maxPlayers: 2,
    newGame: ({int players = 2, int seed = 0}) => TicTacToeState.initial(),
  ),
};
