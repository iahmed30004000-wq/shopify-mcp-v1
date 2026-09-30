/// Chess (شطرنج) – FIDE rules with automatic draws.
///
/// Players: 0 = white, 1 = black. Squares 0..63, a1 = 0 … h8 = 63.
library;

import '../core/engine.dart';
import '../core/game_types.dart';
import 'chess_position.dart';

export 'chess_position.dart' show kStartFen, parseSquare, squareName;

enum ChessPieceType { pawn, knight, bishop, rook, queen, king }

/// A piece on the board, for the UI.
final class ChessPiece {
  const ChessPiece(this.color, this.type);
  final int color; // 0 white, 1 black
  final ChessPieceType type;

  @override
  bool operator ==(Object other) => other is ChessPiece && other.color == color && other.type == type;

  @override
  int get hashCode => Object.hash(color, type);

  @override
  String toString() => '${color == 0 ? 'w' : 'b'}${type.name}';
}

/// A chess move in coordinate form (castling = king moves two squares).
final class ChessMove extends GameMove {
  const ChessMove(this.from, this.to, [this.promotion]);

  /// Parses UCI long algebraic (`e2e4`, `e7e8q`).
  factory ChessMove.fromUci(String uci) {
    final from = parseSquare(uci.length >= 2 ? uci.substring(0, 2) : '');
    final to = parseSquare(uci.length >= 4 ? uci.substring(2, 4) : '');
    if (from < 0 || to < 0 || uci.length > 5) throw FormatException('bad UCI move', uci);
    ChessPieceType? promo;
    if (uci.length == 5) {
      final i = 'nbrq'.indexOf(uci[4].toLowerCase());
      if (i < 0) throw FormatException('bad promotion', uci);
      promo = ChessPieceType.values[i + 1];
    }
    return ChessMove(from, to, promo);
  }

  factory ChessMove.fromJson(Map<String, Object?> json) => ChessMove.fromUci(json['uci']! as String);

  final int from;
  final int to;
  final ChessPieceType? promotion;

  String get uci => '${squareName(from)}${squareName(to)}${promotion == null ? '' : 'nbrq'[promotion!.index - 1]}';

  @override
  Map<String, Object?> toJson() => {'uci': uci};

  @override
  bool operator ==(Object other) =>
      other is ChessMove && other.from == from && other.to == to && other.promotion == promotion;

  @override
  int get hashCode => Object.hash(from, to, promotion);

  @override
  String toString() => uci;
}

/// Immutable chess state.
final class ChessState extends GameState {
  ChessState._({
    required List<int> board,
    required this.sideToMove,
    required this.castling,
    required this.epSquare,
    required this.halfmoveClock,
    required this.fullmoveNumber,
    required List<int> keys,
    required this.result,
    this.lastMove,
  }) : board = List.unmodifiable(board),
       keys = List.unmodifiable(keys);

  factory ChessState.initial() => ChessState.fromFen(kStartFen);

  /// A state from FEN (see [ChessPosition.fromFen] for normalisation).
  factory ChessState.fromFen(String fen) {
    final pos = ChessPosition.fromFen(fen);
    return ChessState._fromPosition(pos, [pos.hash]);
  }

  factory ChessState._fromPosition(ChessPosition pos, List<int> keys, [ChessMove? lastMove]) => ChessState._(
    board: pos.board,
    sideToMove: pos.side,
    castling: pos.castling,
    epSquare: pos.ep,
    halfmoveClock: pos.halfmove,
    fullmoveNumber: pos.fullmove,
    keys: keys,
    result: _resultOf(pos, keys),
    lastMove: lastMove,
  );

  factory ChessState.fromJson(Map<String, Object?> json) {
    final pos = ChessPosition.fromFen(json['fen']! as String);
    final keys = [for (final k in (json['keys'] as List? ?? const [])) int.parse(k as String, radix: 16)];
    if (keys.isEmpty || keys.last != pos.hash) keys.add(pos.hash);
    final last = json['last'] as String?;
    return ChessState._fromPosition(pos, keys, last == null ? null : ChessMove.fromUci(last));
  }

  /// 64 piece codes (`color << 3 | type`, 0 = empty); prefer [pieceAt].
  final List<int> board;
  final int sideToMove;

  /// Bits: 1 = white O-O, 2 = white O-O-O, 4 = black O-O, 8 = black O-O-O.
  final int castling;

  /// En-passant target square or -1 (only when a capture is possible).
  final int epSquare;
  final int halfmoveClock;
  final int fullmoveNumber;

  /// Zobrist keys since the last irreversible move, current last.
  final List<int> keys;
  final ChessMove? lastMove;

  @override
  final GameResult? result;

  @override
  int get playerCount => 2;

  @override
  int get currentPlayer => sideToMove;

  ChessPiece? pieceAt(int square) {
    final pc = board[square];
    return pc == 0 ? null : ChessPiece(pc >> 3, ChessPieceType.values[(pc & 7) - 1]);
  }

  /// A mutable copy for search / notation (hash history pre-filled).
  ChessPosition toPosition() {
    final pos = ChessPosition.fromFen(fen);
    pos.hashHistory.addAll(keys.take(keys.length - 1));
    return pos;
  }

  String get fen {
    final sb = StringBuffer();
    for (var rank = 7; rank >= 0; rank--) {
      var empty = 0;
      for (var file = 0; file < 8; file++) {
        final pc = board[rank * 8 + file];
        if (pc == 0) {
          empty++;
          continue;
        }
        if (empty > 0) sb.write(empty);
        empty = 0;
        final ch = ' pnbrqk'[pc & 7];
        sb.write((pc >> 3) == kWhite ? ch.toUpperCase() : ch);
      }
      if (empty > 0) sb.write(empty);
      if (rank > 0) sb.write('/');
    }
    final c = castling == 0
        ? '-'
        : [
            if (castling & kCastleWK != 0) 'K',
            if (castling & kCastleWQ != 0) 'Q',
            if (castling & kCastleBK != 0) 'k',
            if (castling & kCastleBQ != 0) 'q',
          ].join();
    return '$sb ${sideToMove == kWhite ? 'w' : 'b'} $c ${epSquare >= 0 ? squareName(epSquare) : '-'} '
        '$halfmoveClock $fullmoveNumber';
  }

  bool get inCheck => ChessPosition.fromFen(fen).inCheck();

  @override
  Map<String, Object?> toJson() => {
    'fen': fen,
    'keys': [for (final k in keys) k.toRadixString(16)],
    if (lastMove != null) 'last': lastMove!.uci,
  };

  static GameResult? _resultOf(ChessPosition pos, List<int> keys) {
    if (!pos.hasLegalMove()) {
      return pos.inCheck()
          ? GameResult(winners: [pos.side ^ 1], reason: GameEndReason.checkmate)
          : const GameResult.draw(GameEndReason.stalemate);
    }
    if (pos.insufficientMaterial()) return const GameResult.draw(GameEndReason.insufficientMaterial);
    if (pos.halfmove >= 100) return const GameResult.draw(GameEndReason.fiftyMoveRule);
    var count = 0;
    for (final k in keys) {
      if (k == pos.hash) count++;
    }
    if (count >= 3) return const GameResult.draw(GameEndReason.threefoldRepetition);
    return null;
  }
}

/// Chess rules.
final class ChessRules extends GameRules<ChessState, ChessMove> {
  const ChessRules();

  @override
  BoardGameId get id => BoardGameId.chess;

  @override
  List<ChessMove> legalMoves(ChessState state) {
    if (state.isOver) return const [];
    return [for (final m in state.toPosition().legalMoves()) toPublicMove(m)];
  }

  @override
  ChessState apply(ChessState state, ChessMove move) {
    final pos = state.toPosition();
    final m = _encode(pos, move);
    if (m == null || !pos.makeMove(m)) throw IllegalMoveException(move);
    final keys = pos.halfmove == 0 ? [pos.hash] : [...state.keys, pos.hash];
    return ChessState._fromPosition(pos, keys, move);
  }

  @override
  ChessState stateFromJson(Map<String, Object?> json) => ChessState.fromJson(json);

  @override
  ChessMove moveFromJson(Map<String, Object?> json) => ChessMove.fromJson(json);

  static ChessMove toPublicMove(int m) {
    final promo = movePromo(m);
    return ChessMove(moveFrom(m), moveTo(m), promo == 0 ? null : ChessPieceType.values[promo - 1]);
  }

  static int? _encode(ChessPosition pos, ChessMove move) {
    final promo = move.promotion == null ? 0 : move.promotion!.index + 1;
    for (final m in pos.legalMoves()) {
      if (moveFrom(m) == move.from && moveTo(m) == move.to && movePromo(m) == promo) return m;
    }
    return null;
  }

  /// Standard Algebraic Notation of a legal [move] (`Nbd7`, `exd6`,
  /// `e8=Q+`, `O-O-O#`).
  String toSan(ChessState state, ChessMove move) {
    final pos = state.toPosition();
    final legal = pos.legalMoves();
    final m = _encode(pos, move);
    if (m == null) throw IllegalMoveException(move);
    return sanOf(pos, m, legal);
  }

  /// Parses SAN (tolerates `0-0`, missing `=`, `+`/`#`/`!?` suffixes) or UCI.
  ChessMove fromSan(ChessState state, String san) {
    final pos = state.toPosition();
    final legal = pos.legalMoves();
    final want = _normaliseSan(san);
    ChessMove? found;
    for (final m in legal) {
      if (_normaliseSan(sanOf(pos, m, legal)) == want) {
        if (found != null) throw FormatException('ambiguous SAN', san);
        found = toPublicMove(m);
      }
    }
    if (found != null) return found;
    try {
      final uci = ChessMove.fromUci(san.trim());
      if (legal.any((m) => toPublicMove(m) == uci)) return uci;
    } on FormatException {
      // fall through
    }
    throw FormatException('no legal move matches', san);
  }

  /// SAN for a whole line of moves from [initial].
  List<String> toSanLine(ChessState initial, Iterable<ChessMove> moves) {
    final out = <String>[];
    var s = initial;
    for (final m in moves) {
      out.add(toSan(s, m));
      s = apply(s, m);
    }
    return out;
  }

  static String _normaliseSan(String san) {
    var s = san.trim().replaceAll(RegExp(r'[+#!?]'), '').replaceAll('e.p.', '').replaceAll('=', '').trim();
    s = s.replaceAll('0', 'O');
    return s;
  }

  /// SAN of the encoded legal move [m] in [pos] given all [legal] moves.
  static String sanOf(ChessPosition pos, int m, List<int> legal) {
    final from = moveFrom(m), to = moveTo(m), flags = moveFlags(m), promo = movePromo(m);
    final piece = pos.board[from];
    final type = piece & 7;
    final sb = StringBuffer();
    if (flags & kFlagCastle != 0) {
      sb.write(to > from ? 'O-O' : 'O-O-O');
    } else {
      final capture = flags & kFlagCapture != 0;
      if (type == kPawn) {
        if (capture) sb.write(squareName(from)[0]);
      } else {
        sb.write(' NBRQK'[type - 1]);
        var ambiguous = false, sameFile = false, sameRank = false;
        for (final o in legal) {
          if (o == m || moveTo(o) != to || pos.board[moveFrom(o)] != piece) continue;
          ambiguous = true;
          if ((moveFrom(o) & 7) == (from & 7)) sameFile = true;
          if ((moveFrom(o) >> 3) == (from >> 3)) sameRank = true;
        }
        if (ambiguous) {
          if (!sameFile) {
            sb.write(squareName(from)[0]);
          } else if (!sameRank) {
            sb.write(squareName(from)[1]);
          } else {
            sb.write(squareName(from));
          }
        }
      }
      if (capture) sb.write('x');
      sb.write(squareName(to));
      if (promo != 0) sb.write('=${' NBRQ'[promo - 1]}');
    }
    pos.makeMove(m);
    if (pos.inCheck()) sb.write(pos.hasLegalMove() ? '+' : '#');
    pos.unmakeMove();
    return sb.toString();
  }
}

/// Shared const instance.
const chessRules = ChessRules();
