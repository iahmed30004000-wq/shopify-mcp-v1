/// Checkers / draughts (داما / ضامة) on 8×8 – one configurable engine.
///
/// * [CheckersConfig.american] (default): English/American draughts – 12 men
///   each on the dark squares, men move and capture diagonally forward,
///   kings move one square, capturing is compulsory (any sequence, which must
///   be completed), a man that reaches the far row is crowned and the move
///   ends.
/// * [CheckersConfig.americanFlyingKings]: the same with long-range kings.
/// * [CheckersConfig.turkish]: Turkish/Levantine "Dama" (الضامة) – 16 men each
///   on rows 2–3, orthogonal movement (men forward or sideways), flying kings,
///   captured pieces vanish immediately, the maximum capture is compulsory
///   and a king may not reverse direction between two jumps.
///
/// Player 0 starts on rows 0..2 (moving up the board) and moves first.
/// Squares are `row * 8 + col`, row 0 = player 0's back row.
library;

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';

enum CheckersGeometry { diagonal, orthogonal }

/// What happens when a man reaches the far row in the middle of a capture.
enum CheckersPromotionInCapture {
  /// The move ends there and the man is crowned (American).
  endsMove,

  /// It keeps capturing as a man and is crowned if it finishes on the far
  /// row (assumed for Turkish Dama).
  continueAsMan,
}

final class CheckersConfig {
  const CheckersConfig({
    this.geometry = CheckersGeometry.diagonal,
    this.flyingKings = false,
    this.menCaptureBackward = false,
    this.maximumCapture = false,
    this.removeCapturedImmediately = false,
    this.forbidReverseInCapture = false,
    this.promotionInCapture = CheckersPromotionInCapture.endsMove,
    this.noProgressLimit = 80,
  });

  factory CheckersConfig.fromJson(Map<String, Object?> json) => CheckersConfig(
    geometry: CheckersGeometry.values.byName(json['geometry']! as String),
    flyingKings: json['flyingKings']! as bool,
    menCaptureBackward: json['menCaptureBackward']! as bool,
    maximumCapture: json['maximumCapture']! as bool,
    removeCapturedImmediately: json['removeCapturedImmediately']! as bool,
    forbidReverseInCapture: json['forbidReverseInCapture']! as bool,
    promotionInCapture: CheckersPromotionInCapture.values.byName(json['promotionInCapture']! as String),
    noProgressLimit: (json['noProgressLimit']! as num).toInt(),
  );

  static const CheckersConfig american = CheckersConfig();
  static const CheckersConfig americanFlyingKings = CheckersConfig(flyingKings: true);
  static const CheckersConfig turkish = CheckersConfig(
    geometry: CheckersGeometry.orthogonal,
    flyingKings: true,
    maximumCapture: true,
    removeCapturedImmediately: true,
    forbidReverseInCapture: true,
    promotionInCapture: CheckersPromotionInCapture.continueAsMan,
  );

  final CheckersGeometry geometry;
  final bool flyingKings;
  final bool menCaptureBackward;

  /// Must take the sequence capturing the most pieces.
  final bool maximumCapture;

  /// Captured pieces leave the board at once (Turkish) instead of at the end
  /// of the move (they then block and cannot be jumped twice).
  final bool removeCapturedImmediately;
  final bool forbidReverseInCapture;
  final CheckersPromotionInCapture promotionInCapture;

  /// Plies without a capture or a man move before the game is drawn
  /// (80 = forty moves each).
  final int noProgressLimit;

  Map<String, Object?> toJson() => {
    'geometry': geometry.name,
    'flyingKings': flyingKings,
    'menCaptureBackward': menCaptureBackward,
    'maximumCapture': maximumCapture,
    'removeCapturedImmediately': removeCapturedImmediately,
    'forbidReverseInCapture': forbidReverseInCapture,
    'promotionInCapture': promotionInCapture.name,
    'noProgressLimit': noProgressLimit,
  };

  @override
  bool operator ==(Object other) => other is CheckersConfig && _key == other._key;

  @override
  int get hashCode => _key.hashCode;

  String get _key => toJson().toString();
}

/// Board cell values.
abstract final class CheckersPiece {
  static const int empty = 0;
  static const int man0 = 1;
  static const int king0 = 2;
  static const int man1 = -1;
  static const int king1 = -2;

  static int owner(int v) => v > 0 ? 0 : 1;
  static bool isKing(int v) => v == king0 || v == king1;
}

/// A move: the squares visited (first = origin) and the squares captured.
final class CheckersMove extends GameMove {
  CheckersMove(List<int> path, [List<int> captures = const []])
    : path = List.unmodifiable(path),
      captures = List.unmodifiable(captures);

  factory CheckersMove.fromJson(Map<String, Object?> json) =>
      CheckersMove(intList(json['path']), intList(json['captures']));

  final List<int> path;
  final List<int> captures;

  int get from => path.first;
  int get to => path.last;
  bool get isCapture => captures.isNotEmpty;

  @override
  Map<String, Object?> toJson() => {'path': path, 'captures': captures};

  @override
  bool operator ==(Object other) =>
      other is CheckersMove && listEquals(other.path, path) && listEquals(other.captures, captures);

  @override
  int get hashCode => Object.hash(Object.hashAll(path), Object.hashAll(captures));

  @override
  String toString() => '${path.join(isCapture ? 'x' : '-')}${isCapture ? ' $captures' : ''}';
}

// Zobrist keys for repetition detection (stable across runs).
final List<int> _zobrist = () {
  final rng = BoardRng(0xD4A3A);
  return List<int>.generate(5 * 64 + 1, (_) => (rng.nextUint32() << 32) ^ rng.nextUint32());
}();

int checkersHash(List<int> board, int player) {
  var h = player == 1 ? _zobrist[320] : 0;
  for (var sq = 0; sq < 64; sq++) {
    final v = board[sq];
    if (v != 0) h ^= _zobrist[(v + 2) * 64 + sq];
  }
  return h;
}

final class CheckersState extends GameState {
  CheckersState({
    required this.config,
    required List<int> board,
    required this.currentPlayer,
    this.pliesWithoutProgress = 0,
    List<int>? keys,
    this.lastMove,
    this.result,
  }) : board = List.unmodifiable(board),
       keys = List.unmodifiable(keys ?? [checkersHash(board, currentPlayer)]);

  factory CheckersState.initial([CheckersConfig config = CheckersConfig.american]) {
    final board = List<int>.filled(64, 0);
    for (var sq = 0; sq < 64; sq++) {
      final r = sq >> 3, c = sq & 7;
      if (config.geometry == CheckersGeometry.diagonal) {
        if ((r + c).isEven) {
          if (r <= 2) board[sq] = CheckersPiece.man0;
          if (r >= 5) board[sq] = CheckersPiece.man1;
        }
      } else {
        if (r == 1 || r == 2) board[sq] = CheckersPiece.man0;
        if (r == 5 || r == 6) board[sq] = CheckersPiece.man1;
      }
    }
    return CheckersState(config: config, board: board, currentPlayer: 0);
  }

  factory CheckersState.fromJson(Map<String, Object?> json) {
    final last = json['last'];
    final r = json['result'];
    return CheckersState(
      config: CheckersConfig.fromJson(jsonMap(json['config'])),
      board: intList(json['board']),
      currentPlayer: (json['player']! as num).toInt(),
      pliesWithoutProgress: (json['quiet']! as num).toInt(),
      keys: [for (final k in json['keys']! as List) int.parse(k as String, radix: 16)],
      lastMove: last == null ? null : CheckersMove.fromJson(jsonMap(last)),
      result: r == null ? null : GameResult.fromJson(jsonMap(r)),
    );
  }

  final CheckersConfig config;

  /// 64 cells, see [CheckersPiece].
  final List<int> board;
  @override
  final int currentPlayer;
  final int pliesWithoutProgress;

  /// Position hashes since the last capture / man move (current last).
  final List<int> keys;
  final CheckersMove? lastMove;
  @override
  final GameResult? result;

  @override
  int get playerCount => 2;

  int pieceCount(int player, {bool? kings}) {
    var n = 0;
    for (final v in board) {
      if (v == 0 || CheckersPiece.owner(v) != player) continue;
      if (kings == null || kings == CheckersPiece.isKing(v)) n++;
    }
    return n;
  }

  @override
  Map<String, Object?> toJson() => {
    'config': config.toJson(),
    'board': board,
    'player': currentPlayer,
    'quiet': pliesWithoutProgress,
    'keys': [for (final k in keys) k.toRadixString(16)],
    if (lastMove != null) 'last': lastMove!.toJson(),
    if (result != null) 'result': result!.toJson(),
  };
}

const List<List<int>> _diagDirs = [
  [1, 1], [1, -1], [-1, 1], [-1, -1], //
];
const List<List<int>> _orthDirs = [
  [1, 0], [0, 1], [0, -1], [-1, 0], //
];

/// Move generation shared with the AI (works on a mutable board copy).
final class CheckersMoveGen {
  CheckersMoveGen(this.config) : _dirs = config.geometry == CheckersGeometry.diagonal ? _diagDirs : _orthDirs;

  final CheckersConfig config;
  final List<List<int>> _dirs;

  static int _step(int sq, List<int> d) {
    final r = (sq >> 3) + d[0], c = (sq & 7) + d[1];
    if (r < 0 || r > 7 || c < 0 || c > 7) return -1;
    return r * 8 + c;
  }

  static bool isLastRow(int sq, int player) => player == 0 ? (sq >> 3) == 7 : (sq >> 3) == 0;

  /// Direction indices a man may move (not capture) in.
  List<int> _manMoveDirs(int player) {
    final fwd = player == 0 ? 1 : -1;
    return [
      for (var i = 0; i < _dirs.length; i++)
        if (_dirs[i][0] == fwd || (config.geometry == CheckersGeometry.orthogonal && _dirs[i][0] == 0)) i,
    ];
  }

  List<int> _manCaptureDirs(int player) {
    if (config.menCaptureBackward) return const [0, 1, 2, 3];
    return _manMoveDirs(player);
  }

  bool _isEnemy(int v, int player) => v != 0 && CheckersPiece.owner(v) != player;

  /// All legal moves for [player] on [board] (which is left unchanged).
  List<CheckersMove> generate(List<int> board, int player) {
    final b = List<int>.of(board);
    final captures = <CheckersMove>[];
    for (var sq = 0; sq < 64; sq++) {
      final v = b[sq];
      if (v == 0 || CheckersPiece.owner(v) != player) continue;
      b[sq] = 0; // lift the piece so it may pass its own origin
      _captures(b, v, sq, player, CheckersPiece.isKing(v), [sq], [], -1, captures);
      b[sq] = v;
    }
    if (captures.isNotEmpty) {
      if (!config.maximumCapture) return captures;
      var best = 0;
      for (final m in captures) {
        if (m.captures.length > best) best = m.captures.length;
      }
      return [
        for (final m in captures)
          if (m.captures.length == best) m,
      ];
    }
    final out = <CheckersMove>[];
    for (var sq = 0; sq < 64; sq++) {
      final v = b[sq];
      if (v == 0 || CheckersPiece.owner(v) != player) continue;
      final king = CheckersPiece.isKing(v);
      for (final di in king ? const [0, 1, 2, 3] : _manMoveDirs(player)) {
        var t = _step(sq, _dirs[di]);
        while (t >= 0 && b[t] == 0) {
          out.add(CheckersMove([sq, t]));
          if (!king || !config.flyingKings) break;
          t = _step(t, _dirs[di]);
        }
      }
    }
    return out;
  }

  void _captures(
    List<int> b,
    int piece,
    int sq,
    int player,
    bool king,
    List<int> path,
    List<int> captured,
    int lastDir,
    List<CheckersMove> out,
  ) {
    var extended = false;
    for (final di in king ? const [0, 1, 2, 3] : _manCaptureDirs(player)) {
      if (config.forbidReverseInCapture && lastDir >= 0 && di == 3 - lastDir) continue;
      final d = _dirs[di];
      var over = _step(sq, d);
      if (king && config.flyingKings) {
        while (over >= 0 && b[over] == 0) {
          over = _step(over, d);
        }
      }
      if (over < 0 || !_isEnemy(b[over], player) || captured.contains(over)) continue;
      var land = _step(over, d);
      while (land >= 0 && b[land] == 0) {
        extended = true;
        final victim = b[over];
        if (config.removeCapturedImmediately) b[over] = 0;
        path.add(land);
        captured.add(over);
        final crowns = !king && isLastRow(land, player);
        if (crowns && config.promotionInCapture == CheckersPromotionInCapture.endsMove) {
          out.add(CheckersMove(path, captured));
        } else {
          _captures(b, piece, land, player, king, path, captured, di, out);
        }
        path.removeLast();
        captured.removeLast();
        b[over] = victim;
        if (!king || !config.flyingKings) break;
        land = _step(land, d);
      }
    }
    if (!extended && captured.isNotEmpty) out.add(CheckersMove(path, captured));
  }

  /// Applies [m] to the mutable [b]; returns the undo record.
  List<int> make(List<int> b, CheckersMove m, int player) {
    final piece = b[m.from];
    final undo = <int>[m.from, piece];
    b[m.from] = 0;
    for (final c in m.captures) {
      undo
        ..add(c)
        ..add(b[c]);
      b[c] = 0;
    }
    var placed = piece;
    if (!CheckersPiece.isKing(piece) && isLastRow(m.to, player)) {
      placed = player == 0 ? CheckersPiece.king0 : CheckersPiece.king1;
    }
    b[m.to] = placed;
    return undo;
  }

  void unmake(List<int> b, CheckersMove m, List<int> undo) {
    b[m.to] = 0;
    for (var i = undo.length - 2; i >= 0; i -= 2) {
      b[undo[i]] = undo[i + 1];
    }
  }
}

final class CheckersRules extends GameRules<CheckersState, CheckersMove> {
  const CheckersRules();

  @override
  BoardGameId get id => BoardGameId.checkers;

  @override
  List<CheckersMove> legalMoves(CheckersState state) {
    if (state.isOver) return const [];
    return CheckersMoveGen(state.config).generate(state.board, state.currentPlayer);
  }

  @override
  CheckersState apply(CheckersState state, CheckersMove move) {
    final gen = CheckersMoveGen(state.config);
    final b = List<int>.of(state.board);
    final mover = state.currentPlayer;
    final wasMan = !CheckersPiece.isKing(b[move.from]);
    gen.make(b, move, mover);
    final next = 1 - mover;
    final progress = move.isCapture || wasMan;
    final quiet = progress ? 0 : state.pliesWithoutProgress + 1;
    final key = checkersHash(b, next);
    final keys = progress ? [key] : [...state.keys, key];
    GameResult? result;
    if (gen.generate(b, next).isEmpty) {
      result = GameResult(winners: [mover], reason: GameEndReason.noLegalMoves);
    } else if (quiet >= state.config.noProgressLimit) {
      result = const GameResult.draw(GameEndReason.noProgress);
    } else if (keys.where((k) => k == key).length >= 3) {
      result = const GameResult.draw(GameEndReason.threefoldRepetition);
    }
    return CheckersState(
      config: state.config,
      board: b,
      currentPlayer: next,
      pliesWithoutProgress: quiet,
      keys: keys,
      lastMove: move,
      result: result,
    );
  }

  @override
  CheckersState stateFromJson(Map<String, Object?> json) => CheckersState.fromJson(json);

  @override
  CheckersMove moveFromJson(Map<String, Object?> json) => CheckersMove.fromJson(json);

  /// Standard 1–32 numbering of a dark square (American notation), from
  /// player 0's side; -1 for light squares or orthogonal boards.
  static int squareNumber(int sq) {
    final r = sq >> 3, c = sq & 7;
    if ((r + c).isOdd) return -1;
    return r * 4 + (c >> 1) + 1;
  }
}

const checkersRules = CheckersRules();
