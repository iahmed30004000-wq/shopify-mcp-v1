/// Checkers / draughts on 8×8 – الضامة / الداما – one configurable engine.
///
/// * [CheckersConfig.jordan] (**default**): «الضامة» as commonly played in
///   Jordan – the orthogonal Turkish-family game. 16 men each on rows 2–3,
///   men step forward or sideways (never back), flying rook-like kings, the
///   capture taking the most pieces is compulsory, captured pieces leave the
///   board at once, no 180° turn between two jumps, and a man that reaches
///   the far row mid-capture keeps capturing as a man and is crowned when
///   the move ends. One piece each is a draw (unless the side to move must
///   capture) and two or more kings against a lone king win (unless the lone
///   king is to move and must capture); 50 plies without a capture or a
///   forward man step, or a threefold repetition, draw.
/// * [CheckersConfig.turkish]: the Turkish federation (TÜDAF) rules – as
///   [CheckersConfig.jordan] without the kings-v-lone-king adjudication.
/// * [CheckersConfig.american]: English/American draughts – 12 men each on
///   the dark squares, men move and capture diagonally forward, kings move
///   one square, capturing is compulsory (any sequence, which must be
///   completed), a man that reaches the far row is crowned and the move
///   ends.
/// * [CheckersConfig.americanFlyingKings]: a house rule – American draughts
///   with long-range kings.
///
/// Player 0 starts on rows 0..2 (moving up the board) and moves first (white
/// in Dama; the UI draws player 0 dark in American draughts).
/// Squares are `row * 8 + col`, row 0 = player 0's back row.
library;

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';

enum CheckersGeometry { diagonal, orthogonal }

/// What happens when a man reaches the far row in the middle of a capture.
enum CheckersPromotionInCapture {
  /// The move ends there and the man is crowned (American; a Dama option).
  endsMove,

  /// It keeps capturing as a man (sideways along the far row) and is crowned
  /// when the move ends there (TÜDAF rule R5; Jordanian default).
  continueAsMan,
}

/// The named rule sets a lobby offers. The UI localises [name].
enum CheckersVariant {
  /// «الضامة» – as commonly played in Jordan (default).
  jordan,

  /// «الضامة التركية» – Turkish federation rules.
  turkish,

  /// «الداما القُطرية» – English / American draughts.
  american,

  /// American draughts with flying kings (a house rule, not an established
  /// variant).
  americanFlyingKings;

  CheckersConfig get config => switch (this) {
    CheckersVariant.jordan => CheckersConfig.jordan,
    CheckersVariant.turkish => CheckersConfig.turkish,
    CheckersVariant.american => CheckersConfig.american,
    CheckersVariant.americanFlyingKings => CheckersConfig.americanFlyingKings,
  };
}

/// Every way a checkers game ends. [checkersEndReason] maps each one to the
/// shared [GameEndReason]; [CheckersState.end] keeps the exact value.
enum CheckersGameEnd {
  /// The player to move has no piece left or no legal move: they lose.
  noLegalMoves,

  /// One piece each and the side to move has no capture: draw.
  onePieceEach,

  /// Two or more kings against a lone king (the lone king's side has no
  /// forced capture): the kings' side wins.
  kingsVsLoneKing,

  /// Option (the "Samara" rule): a king against a lone man wins.
  kingVsLoneMan,

  /// [CheckersConfig.noProgressLimit] plies without a capture or a forward
  /// man step: draw.
  noProgress,

  /// The same position with the same side to move for the third time since
  /// the last irreversible move: draw.
  threefoldRepetition,
}

final Map<String, GameEndReason> _sharedReasons = GameEndReason.values.asNameMap();

/// The shared [GameEndReason] for [end]: the value with the same name once
/// `core/game_types.dart` has it, otherwise the nearest existing one.
GameEndReason checkersEndReason(CheckersGameEnd end) =>
    _sharedReasons[end.name] ??
    switch (end) {
      CheckersGameEnd.onePieceEach => GameEndReason.insufficientMaterial,
      CheckersGameEnd.noProgress => GameEndReason.noProgress,
      CheckersGameEnd.threefoldRepetition => GameEndReason.threefoldRepetition,
      CheckersGameEnd.noLegalMoves ||
      CheckersGameEnd.kingsVsLoneKing ||
      CheckersGameEnd.kingVsLoneMan => GameEndReason.noLegalMoves,
    };

/// An adjudicated end: [winner] is null for a draw.
typedef CheckersVerdict = ({CheckersGameEnd end, int? winner});

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
    this.onePieceEachDraw = false,
    this.kingsBeatLoneKing = false,
    this.kingBeatsLoneMan = false,
  });

  /// Reads [toJson]. Keys added later (the three adjudication flags) default
  /// to `false`, so older saves still load.
  factory CheckersConfig.fromJson(Map<String, Object?> json) => CheckersConfig(
    geometry: CheckersGeometry.values.byName(json['geometry']! as String),
    flyingKings: json['flyingKings']! as bool,
    menCaptureBackward: json['menCaptureBackward']! as bool,
    maximumCapture: json['maximumCapture']! as bool,
    removeCapturedImmediately: json['removeCapturedImmediately']! as bool,
    forbidReverseInCapture: json['forbidReverseInCapture']! as bool,
    promotionInCapture: CheckersPromotionInCapture.values.byName(json['promotionInCapture']! as String),
    noProgressLimit: (json['noProgressLimit']! as num).toInt(),
    onePieceEachDraw: json['onePieceEachDraw'] as bool? ?? false,
    kingsBeatLoneKing: json['kingsBeatLoneKing'] as bool? ?? false,
    kingBeatsLoneMan: json['kingBeatsLoneMan'] as bool? ?? false,
  );

  /// «الضامة» as commonly played in Jordan – the default.
  static const CheckersConfig jordan = CheckersConfig(
    geometry: CheckersGeometry.orthogonal,
    flyingKings: true,
    maximumCapture: true,
    removeCapturedImmediately: true,
    forbidReverseInCapture: true,
    promotionInCapture: CheckersPromotionInCapture.continueAsMan,
    noProgressLimit: 50,
    onePieceEachDraw: true,
    kingsBeatLoneKing: true,
  );

  /// Turkish federation (TÜDAF) rules: [jordan] without the kings-v-lone-king
  /// adjudication. (TÜDAF sets no move count; 50 plies is the app's rule.)
  static const CheckersConfig turkish = CheckersConfig(
    geometry: CheckersGeometry.orthogonal,
    flyingKings: true,
    maximumCapture: true,
    removeCapturedImmediately: true,
    forbidReverseInCapture: true,
    promotionInCapture: CheckersPromotionInCapture.continueAsMan,
    noProgressLimit: 50,
    onePieceEachDraw: true,
  );

  /// English / American draughts.
  static const CheckersConfig american = CheckersConfig();

  /// House rule: American draughts with flying kings.
  static const CheckersConfig americanFlyingKings = CheckersConfig(flyingKings: true);

  final CheckersGeometry geometry;
  final bool flyingKings;
  final bool menCaptureBackward;

  /// Must take the sequence capturing the most pieces (a king counts as one).
  final bool maximumCapture;

  /// Captured pieces leave the board at once (Dama) instead of at the end
  /// of the move (they then block and cannot be jumped twice).
  final bool removeCapturedImmediately;
  final bool forbidReverseInCapture;
  final CheckersPromotionInCapture promotionInCapture;

  /// Plies without a capture or a forward man step before the game is drawn
  /// (50 = 25 moves each; 80 = forty moves each).
  final int noProgressLimit;

  /// One piece each is a draw unless the side to move has a capture.
  final bool onePieceEachDraw;

  /// Two or more kings against a lone king win unless the lone king's side
  /// is to move and has a capture.
  final bool kingsBeatLoneKing;

  /// The "Samara" option: a king against a lone man wins unless the man's
  /// side is to move and has a capture.
  final bool kingBeatsLoneMan;

  /// The named preset equal to this config, or null for a custom mix.
  CheckersVariant? get variant {
    for (final v in CheckersVariant.values) {
      if (v.config == this) return v;
    }
    return null;
  }

  CheckersConfig copyWith({
    CheckersGeometry? geometry,
    bool? flyingKings,
    bool? menCaptureBackward,
    bool? maximumCapture,
    bool? removeCapturedImmediately,
    bool? forbidReverseInCapture,
    CheckersPromotionInCapture? promotionInCapture,
    int? noProgressLimit,
    bool? onePieceEachDraw,
    bool? kingsBeatLoneKing,
    bool? kingBeatsLoneMan,
  }) => CheckersConfig(
    geometry: geometry ?? this.geometry,
    flyingKings: flyingKings ?? this.flyingKings,
    menCaptureBackward: menCaptureBackward ?? this.menCaptureBackward,
    maximumCapture: maximumCapture ?? this.maximumCapture,
    removeCapturedImmediately: removeCapturedImmediately ?? this.removeCapturedImmediately,
    forbidReverseInCapture: forbidReverseInCapture ?? this.forbidReverseInCapture,
    promotionInCapture: promotionInCapture ?? this.promotionInCapture,
    noProgressLimit: noProgressLimit ?? this.noProgressLimit,
    onePieceEachDraw: onePieceEachDraw ?? this.onePieceEachDraw,
    kingsBeatLoneKing: kingsBeatLoneKing ?? this.kingsBeatLoneKing,
    kingBeatsLoneMan: kingBeatsLoneMan ?? this.kingBeatsLoneMan,
  );

  Map<String, Object?> toJson() => {
    'geometry': geometry.name,
    'flyingKings': flyingKings,
    'menCaptureBackward': menCaptureBackward,
    'maximumCapture': maximumCapture,
    'removeCapturedImmediately': removeCapturedImmediately,
    'forbidReverseInCapture': forbidReverseInCapture,
    'promotionInCapture': promotionInCapture.name,
    'noProgressLimit': noProgressLimit,
    'onePieceEachDraw': onePieceEachDraw,
    'kingsBeatLoneKing': kingsBeatLoneKing,
    'kingBeatsLoneMan': kingBeatsLoneMan,
  };

  @override
  bool operator ==(Object other) => other is CheckersConfig && _key == other._key;

  @override
  int get hashCode => _key.hashCode;

  String get _key => toJson().toString();

  @override
  String toString() => 'CheckersConfig(${variant?.name ?? _key})';
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
    this.end,
  }) : board = List.unmodifiable(board),
       keys = List.unmodifiable(keys ?? [checkersHash(board, currentPlayer)]);

  /// The opening position; [config] defaults to the Jordanian rules.
  factory CheckersState.initial([CheckersConfig config = CheckersConfig.jordan]) {
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
    final e = json['end'];
    return CheckersState(
      config: CheckersConfig.fromJson(jsonMap(json['config'])),
      board: intList(json['board']),
      currentPlayer: (json['player']! as num).toInt(),
      pliesWithoutProgress: (json['quiet']! as num).toInt(),
      keys: [for (final k in json['keys']! as List) int.parse(k as String, radix: 16)],
      lastMove: last == null ? null : CheckersMove.fromJson(jsonMap(last)),
      result: r == null ? null : GameResult.fromJson(jsonMap(r)),
      end: e == null ? null : CheckersGameEnd.values.byName(e as String),
    );
  }

  final CheckersConfig config;

  /// 64 cells, see [CheckersPiece].
  final List<int> board;
  @override
  final int currentPlayer;

  /// Plies since the last capture or forward man step.
  final int pliesWithoutProgress;

  /// Position hashes since the last capture or forward man step (current
  /// last). Sideways man steps and king moves are reversible, so they keep
  /// the history.
  final List<int> keys;
  final CheckersMove? lastMove;
  @override
  final GameResult? result;

  /// The exact way the game ended (finer than `result.reason`).
  final CheckersGameEnd? end;

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
    if (end != null) 'end': end!.name,
  };
}

const List<List<int>> _diagDirs = [
  [1, 1], [1, -1], [-1, 1], [-1, -1], //
];
const List<List<int>> _orthDirs = [
  [1, 0], [0, 1], [0, -1], [-1, 0], //
];

/// Move generation and adjudication shared with the AI (works on a mutable
/// board copy).
final class CheckersMoveGen {
  CheckersMoveGen(this.config)
    : _dirs = config.geometry == CheckersGeometry.diagonal ? _diagDirs : _orthDirs,
      _adjudicates = config.onePieceEachDraw || config.kingsBeatLoneKing || config.kingBeatsLoneMan;

  final CheckersConfig config;
  final List<List<int>> _dirs;
  final bool _adjudicates;

  // Scratch sets of [_captures], reused for every piece and call.
  final Set<(int, int, int)> _seen = {};
  final Set<(int, int)> _ends = {};

  static int _step(int sq, List<int> d) {
    final r = (sq >> 3) + d[0], c = (sq & 7) + d[1];
    if (r < 0 || r > 7 || c < 0 || c > 7) return -1;
    return r * 8 + c;
  }

  static bool isLastRow(int sq, int player) => player == 0 ? (sq >> 3) == 7 : (sq >> 3) == 0;

  /// Whether [m], made by [piece] (the value on its origin square before the
  /// move), can never be undone: a capture, or a man step that changes row.
  /// Sideways man steps and king moves are reversible.
  static bool isIrreversible(CheckersMove m, int piece) =>
      m.isCapture || (!CheckersPiece.isKing(piece) && (m.from >> 3) != (m.to >> 3));

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

  /// All legal moves for [player] on [board] (which is left unchanged). When
  /// a capture exists only captures are returned.
  ///
  /// Capture routes that take the same pieces with the same piece and end on
  /// the same square leave the same position, so they are one move, listed
  /// once with the route found first (a flying king taking two pieces on one
  /// line may stop anywhere between them; circling a group gives the same
  /// result either way round). Without this, a king among scattered pieces
  /// had hundreds of thousands of routes to only a few dozen positions.
  List<CheckersMove> generate(List<int> board, int player) {
    final b = List<int>.of(board);
    final captures = <CheckersMove>[];
    for (var sq = 0; sq < 64; sq++) {
      final v = b[sq];
      if (v == 0 || CheckersPiece.owner(v) != player) continue;
      b[sq] = 0; // lift the piece so it may pass its own origin
      _seen.clear();
      _ends.clear();
      _captures(b, sq, player, CheckersPiece.isKing(v), [sq], [], 0, -1, captures);
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

  /// Extends the capture route in [path] (victims [captured], also as the
  /// bit set [taken]) from [sq]. [_seen] holds the (square, last direction,
  /// victims) states already explored for this piece – what can follow
  /// depends on nothing else, so a state reached again by another route adds
  /// no new outcome. [_ends] holds the (last square, victims) outcomes
  /// already listed.
  void _captures(
    List<int> b,
    int sq,
    int player,
    bool king,
    List<int> path,
    List<int> captured,
    int taken,
    int lastDir,
    List<CheckersMove> out,
  ) {
    if (captured.isNotEmpty && !_seen.add((sq, config.forbidReverseInCapture ? lastDir : -1, taken))) return;
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
      if (over < 0 || !_isEnemy(b[over], player) || (taken >> over) & 1 == 1) continue;
      var land = _step(over, d);
      while (land >= 0 && b[land] == 0) {
        extended = true;
        final victim = b[over];
        if (config.removeCapturedImmediately) b[over] = 0;
        path.add(land);
        captured.add(over);
        final crowns = !king && isLastRow(land, player);
        if (crowns && config.promotionInCapture == CheckersPromotionInCapture.endsMove) {
          if (_ends.add((land, taken | 1 << over))) out.add(CheckersMove(path, captured));
        } else {
          _captures(b, land, player, king, path, captured, taken | 1 << over, di, out);
        }
        path.removeLast();
        captured.removeLast();
        b[over] = victim;
        if (!king || !config.flyingKings) break;
        land = _step(land, d);
      }
    }
    if (!extended && captured.isNotEmpty && _ends.add((sq, taken))) out.add(CheckersMove(path, captured));
  }

  /// The material adjudications checked at the start of [toMove]'s turn,
  /// after the no-legal-move check and before the no-progress and
  /// repetition draws. [captureForced] says whether [toMove]'s legal moves
  /// are captures. Returns null while play goes on.
  ///
  /// 1. Samara option – one piece each, one of them a king: the king's side
  ///    wins unless the man's side is to move and must capture.
  /// 2. One piece each: draw unless the side to move must capture.
  /// 3. Two or more kings (men may remain) against a lone king: the kings'
  ///    side wins unless the lone king's side is to move and must capture.
  CheckersVerdict? adjudicate(List<int> board, int toMove, {required bool captureForced}) {
    if (!_adjudicates) return null;
    var c0 = 0, c1 = 0, k0 = 0, k1 = 0;
    for (final v in board) {
      if (v > 0) {
        c0++;
        if (v == CheckersPiece.king0) k0++;
      } else if (v < 0) {
        c1++;
        if (v == CheckersPiece.king1) k1++;
      }
    }
    if (c0 != 1 && c1 != 1) return null;
    if (c0 == 1 && c1 == 1) {
      if (config.kingBeatsLoneMan && k0 + k1 == 1) {
        final kingSide = k0 == 1 ? 0 : 1;
        if (!(1 - kingSide == toMove && captureForced)) {
          return (end: CheckersGameEnd.kingVsLoneMan, winner: kingSide);
        }
      }
      if (config.onePieceEachDraw && !captureForced) return (end: CheckersGameEnd.onePieceEach, winner: null);
      return null;
    }
    if (config.kingsBeatLoneKing) {
      for (var x = 0; x < 2; x++) {
        final y = 1 - x;
        final kingsX = x == 0 ? k0 : k1;
        final countY = y == 0 ? c0 : c1;
        final kingsY = y == 0 ? k0 : k1;
        if (kingsX >= 2 && countY == 1 && kingsY == 1 && !(y == toMove && captureForced)) {
          return (end: CheckersGameEnd.kingsVsLoneKing, winner: x);
        }
      }
    }
    return null;
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

  /// Makes [move], then judges the position for the side about to move, in
  /// this order: no legal move (loss), [CheckersMoveGen.adjudicate], no
  /// progress, threefold repetition.
  @override
  CheckersState apply(CheckersState state, CheckersMove move) {
    final cfg = state.config;
    final gen = CheckersMoveGen(cfg);
    final b = List<int>.of(state.board);
    final mover = state.currentPlayer;
    final piece = b[move.from];
    gen.make(b, move, mover);
    final next = 1 - mover;
    final irreversible = CheckersMoveGen.isIrreversible(move, piece);
    final quiet = irreversible ? 0 : state.pliesWithoutProgress + 1;
    final key = checkersHash(b, next);
    final keys = irreversible ? [key] : [...state.keys, key];
    final replies = gen.generate(b, next);
    final CheckersVerdict? verdict;
    if (replies.isEmpty) {
      verdict = (end: CheckersGameEnd.noLegalMoves, winner: mover);
    } else {
      verdict =
          gen.adjudicate(b, next, captureForced: replies.first.isCapture) ??
          (quiet >= cfg.noProgressLimit
              ? (end: CheckersGameEnd.noProgress, winner: null)
              : keys.where((k) => k == key).length >= 3
              ? (end: CheckersGameEnd.threefoldRepetition, winner: null)
              : null);
    }
    return CheckersState(
      config: cfg,
      board: b,
      currentPlayer: next,
      pliesWithoutProgress: quiet,
      keys: keys,
      lastMove: move,
      result: verdict == null ? null : resultOf(verdict),
      end: verdict?.end,
    );
  }

  /// The [GameResult] for an adjudicated end.
  static GameResult resultOf(CheckersVerdict verdict) {
    final reason = checkersEndReason(verdict.end);
    final w = verdict.winner;
    return w == null ? GameResult.draw(reason) : GameResult(winners: [w], reason: reason);
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
