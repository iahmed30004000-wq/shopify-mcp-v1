/// Mutable chess position with pseudo-legal move generation, make/unmake,
/// Zobrist hashing and FEN – the fast core shared by the rules and the AI.
///
/// Squares are 0..63 with a1 = 0, h1 = 7, a8 = 56, h8 = 63.
/// Pieces are `color << 3 | type` with color 0 = white, 1 = black and
/// type 1..6 = pawn, knight, bishop, rook, queen, king (0 = empty).
///
/// Zobrist keys are 64-bit integers: this file targets the Dart VM / AOT
/// (Android, iOS, desktop), not the web.
library;

import 'dart:typed_data';

import '../core/rng.dart';

const int kWhite = 0;
const int kBlack = 1;

const int kPawn = 1;
const int kKnight = 2;
const int kBishop = 3;
const int kRook = 4;
const int kQueen = 5;
const int kKing = 6;

/// Castling-right bits.
const int kCastleWK = 1;
const int kCastleWQ = 2;
const int kCastleBK = 4;
const int kCastleBQ = 8;

/// Move flag bits (stored above bit 16 of an encoded move).
const int kFlagCapture = 1;
const int kFlagEnPassant = 2;
const int kFlagCastle = 4;
const int kFlagDoublePush = 8;

const String kStartFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

int encodeMove(int from, int to, [int promo = 0, int flags = 0]) => from | (to << 6) | (promo << 12) | (flags << 16);
int moveFrom(int m) => m & 63;
int moveTo(int m) => (m >> 6) & 63;
int movePromo(int m) => (m >> 12) & 7;
int moveFlags(int m) => m >> 16;

String squareName(int sq) => '${String.fromCharCode(97 + (sq & 7))}${(sq >> 3) + 1}';

/// Parses `e4` style names; returns -1 when malformed.
int parseSquare(String s) {
  if (s.length != 2) return -1;
  final f = s.codeUnitAt(0) - 97, r = s.codeUnitAt(1) - 49;
  if (f < 0 || f > 7 || r < 0 || r > 7) return -1;
  return r * 8 + f;
}

// ---------------------------------------------------------------------------
// Pre-computed tables.

const List<int> _dirFile = [0, 0, 1, -1, 1, -1, 1, -1];
const List<int> _dirRank = [1, -1, 0, 0, 1, 1, -1, -1];

List<Int8List> _stepTargets(List<List<int>> deltas) => List.generate(64, (sq) {
  final f = sq & 7, r = sq >> 3;
  final out = <int>[];
  for (final d in deltas) {
    final nf = f + d[0], nr = r + d[1];
    if (nf >= 0 && nf < 8 && nr >= 0 && nr < 8) out.add(nr * 8 + nf);
  }
  return Int8List.fromList(out);
}, growable: false);

final List<Int8List> knightTargets = _stepTargets(const [
  [1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2], //
]);
final List<Int8List> kingTargets = _stepTargets(const [
  [0, 1], [1, 1], [1, 0], [1, -1], [0, -1], [-1, -1], [-1, 0], [-1, 1], //
]);

/// `rays[sq * 8 + dir]`: squares from [sq] outward; dirs 0..3 orthogonal,
/// 4..7 diagonal.
final List<Int8List> rays = List.generate(64 * 8, (i) {
  final sq = i >> 3, dir = i & 7;
  var f = (sq & 7) + _dirFile[dir], r = (sq >> 3) + _dirRank[dir];
  final out = <int>[];
  while (f >= 0 && f < 8 && r >= 0 && r < 8) {
    out.add(r * 8 + f);
    f += _dirFile[dir];
    r += _dirRank[dir];
  }
  return Int8List.fromList(out);
}, growable: false);

/// `pawnAttacks[color * 64 + sq]`: squares a pawn of [color] on sq attacks.
final List<Int8List> pawnAttacks = List.generate(128, (i) {
  final color = i >> 6, sq = i & 63;
  final f = sq & 7, r = (sq >> 3) + (color == kWhite ? 1 : -1);
  final out = <int>[];
  if (r >= 0 && r < 8) {
    if (f > 0) out.add(r * 8 + f - 1);
    if (f < 7) out.add(r * 8 + f + 1);
  }
  return Int8List.fromList(out);
}, growable: false);

final Int8List _castleMask = () {
  final m = Int8List(64)..fillRange(0, 64, 15);
  m[0] = 15 & ~kCastleWQ;
  m[7] = 15 & ~kCastleWK;
  m[4] = 15 & ~(kCastleWK | kCastleWQ);
  m[56] = 15 & ~kCastleBQ;
  m[63] = 15 & ~kCastleBK;
  m[60] = 15 & ~(kCastleBK | kCastleBQ);
  return m;
}();

// Zobrist keys (fixed seed so hashes are stable across runs).
final _ZobristKeys _z = _ZobristKeys();

final class _ZobristKeys {
  _ZobristKeys() {
    final rng = BoardRng(0x5EED0C4E55);
    int next() => (rng.nextUint32() << 32) ^ rng.nextUint32();
    for (var i = 0; i < pieces.length; i++) {
      pieces[i] = next();
    }
    for (var i = 0; i < 16; i++) {
      castling[i] = next();
    }
    for (var i = 0; i < 8; i++) {
      ep[i] = next();
    }
    side = next();
  }
  final List<int> pieces = List<int>.filled(16 * 64, 0);
  final List<int> castling = List<int>.filled(16, 0);
  final List<int> ep = List<int>.filled(8, 0);
  late final int side;
}

// ---------------------------------------------------------------------------

/// A mutable chess position.
final class ChessPosition {
  ChessPosition._();

  factory ChessPosition.initial() => ChessPosition.fromFen(kStartFen);

  /// Parses a FEN. Castling rights without the king/rook on its home square
  /// are dropped; an en-passant square is kept only when a pawn of the side
  /// to move stands next to the double-pushed pawn (so FEN export normalises
  /// it to `-` otherwise). Throws [FormatException] on malformed input.
  factory ChessPosition.fromFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 4) throw FormatException('FEN needs at least 4 fields', fen);
    final p = ChessPosition._();
    final rows = parts[0].split('/');
    if (rows.length != 8) throw FormatException('FEN board needs 8 ranks', fen);
    var kings = [0, 0];
    for (var i = 0; i < 8; i++) {
      final rank = 7 - i;
      var file = 0;
      for (final ch in rows[i].split('')) {
        final digit = int.tryParse(ch);
        if (digit != null) {
          file += digit;
          continue;
        }
        final type = 'pnbrqk'.indexOf(ch.toLowerCase()) + 1;
        if (type == 0 || file > 7) throw FormatException('bad FEN piece "$ch"', fen);
        final color = ch == ch.toUpperCase() ? kWhite : kBlack;
        final sq = rank * 8 + file;
        p.board[sq] = (color << 3) | type;
        if (type == kKing) {
          kings[color]++;
          p.kingSq[color] = sq;
        }
        if (type == kPawn && (rank == 0 || rank == 7)) throw FormatException('pawn on back rank', fen);
        file++;
      }
      if (file != 8) throw FormatException('FEN rank ${8 - i} has $file files', fen);
    }
    if (kings[0] != 1 || kings[1] != 1) throw FormatException('each side needs exactly one king', fen);
    p.side = switch (parts[1]) {
      'w' => kWhite,
      'b' => kBlack,
      _ => throw FormatException('bad side to move', fen),
    };
    var c = 0;
    if (parts[2] != '-') {
      for (final ch in parts[2].split('')) {
        c |= switch (ch) {
          'K' => kCastleWK,
          'Q' => kCastleWQ,
          'k' => kCastleBK,
          'q' => kCastleBQ,
          _ => throw FormatException('bad castling "$ch"', fen),
        };
      }
    }
    final b = p.board;
    if (b[4] != kKing) c &= ~(kCastleWK | kCastleWQ);
    if (b[7] != kRook) c &= ~kCastleWK;
    if (b[0] != kRook) c &= ~kCastleWQ;
    if (b[60] != (8 | kKing)) c &= ~(kCastleBK | kCastleBQ);
    if (b[63] != (8 | kRook)) c &= ~kCastleBK;
    if (b[56] != (8 | kRook)) c &= ~kCastleBQ;
    p.castling = c;
    p.ep = -1;
    if (parts[3] != '-') {
      final sq = parseSquare(parts[3]);
      if (sq < 0) throw FormatException('bad en-passant square', fen);
      final expectedRank = p.side == kWhite ? 5 : 2;
      if ((sq >> 3) == expectedRank) {
        final pawnSq = p.side == kWhite ? sq - 8 : sq + 8;
        final theirPawn = ((p.side ^ 1) << 3) | kPawn;
        if (b[pawnSq] == theirPawn && b[sq] == 0 && p._hasAdjacentPawn(pawnSq, p.side)) p.ep = sq;
      }
    }
    p.halfmove = parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0;
    p.fullmove = parts.length > 5 ? int.tryParse(parts[5]) ?? 1 : 1;
    if (p.fullmove < 1) p.fullmove = 1;
    if (p.isAttacked(p.kingSq[p.side ^ 1], p.side)) {
      throw FormatException('side not to move is in check', fen);
    }
    p.hash = p.computeHash();
    return p;
  }

  final Int8List board = Int8List(64);
  final Int8List kingSq = Int8List(2);
  int side = kWhite;
  int castling = 0;
  int ep = -1;
  int halfmove = 0;
  int fullmove = 1;
  int hash = 0;

  /// Hash of every earlier position (before each move made), oldest first.
  /// Callers may pre-fill it with game history for repetition detection.
  final List<int> hashHistory = [];
  final List<int> _undo = [];

  ChessPosition copy() {
    final p = ChessPosition._();
    p.board.setAll(0, board);
    p.kingSq.setAll(0, kingSq);
    p.side = side;
    p.castling = castling;
    p.ep = ep;
    p.halfmove = halfmove;
    p.fullmove = fullmove;
    p.hash = hash;
    p.hashHistory.addAll(hashHistory);
    return p;
  }

  bool _hasAdjacentPawn(int sq, int color) {
    final pawn = (color << 3) | kPawn;
    final f = sq & 7;
    return (f > 0 && board[sq - 1] == pawn) || (f < 7 && board[sq + 1] == pawn);
  }

  int computeHash() {
    var h = 0;
    for (var sq = 0; sq < 64; sq++) {
      final pc = board[sq];
      if (pc != 0) h ^= _z.pieces[pc * 64 + sq];
    }
    h ^= _z.castling[castling];
    if (ep >= 0) h ^= _z.ep[ep & 7];
    if (side == kBlack) h ^= _z.side;
    return h;
  }

  String toFen() {
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
    sb.write(side == kWhite ? ' w ' : ' b ');
    if (castling == 0) {
      sb.write('-');
    } else {
      if (castling & kCastleWK != 0) sb.write('K');
      if (castling & kCastleWQ != 0) sb.write('Q');
      if (castling & kCastleBK != 0) sb.write('k');
      if (castling & kCastleBQ != 0) sb.write('q');
    }
    sb.write(' ${ep >= 0 ? squareName(ep) : '-'} $halfmove $fullmove');
    return sb.toString();
  }

  /// Whether [sq] is attacked by any piece of [by].
  bool isAttacked(int sq, int by) {
    final b = board;
    final pawn = (by << 3) | kPawn;
    for (final t in pawnAttacks[((by ^ 1) << 6) | sq]) {
      if (b[t] == pawn) return true;
    }
    final knight = (by << 3) | kKnight;
    for (final t in knightTargets[sq]) {
      if (b[t] == knight) return true;
    }
    final king = (by << 3) | kKing;
    for (final t in kingTargets[sq]) {
      if (b[t] == king) return true;
    }
    final rook = (by << 3) | kRook, bishop = (by << 3) | kBishop, queen = (by << 3) | kQueen;
    for (var dir = 0; dir < 8; dir++) {
      final slider = dir < 4 ? rook : bishop;
      for (final t in rays[(sq << 3) | dir]) {
        final pc = b[t];
        if (pc == 0) continue;
        if (pc == slider || pc == queen) return true;
        break;
      }
    }
    return false;
  }

  bool inCheck() => isAttacked(kingSq[side], side ^ 1);

  /// Writes pseudo-legal moves into [out] (length ≥ 256) and returns the
  /// count. With [capturesOnly], only captures and promotions.
  int generate(Int32List out, {bool capturesOnly = false}) {
    var n = 0;
    final b = board;
    final us = side, them = us ^ 1;
    for (var sq = 0; sq < 64; sq++) {
      final pc = b[sq];
      if (pc == 0 || (pc >> 3) != us) continue;
      final type = pc & 7;
      if (type == kPawn) {
        n = _pawnMoves(out, n, sq, us, capturesOnly);
      } else if (type == kKnight || type == kKing) {
        for (final t in (type == kKnight ? knightTargets : kingTargets)[sq]) {
          final target = b[t];
          if (target == 0) {
            if (!capturesOnly) out[n++] = encodeMove(sq, t);
          } else if ((target >> 3) == them) {
            out[n++] = encodeMove(sq, t, 0, kFlagCapture);
          }
        }
        if (type == kKing && !capturesOnly) n = _castles(out, n, sq, us);
      } else {
        final first = type == kBishop ? 4 : 0, last = type == kRook ? 4 : 8;
        for (var dir = first; dir < last; dir++) {
          for (final t in rays[(sq << 3) | dir]) {
            final target = b[t];
            if (target == 0) {
              if (!capturesOnly) out[n++] = encodeMove(sq, t);
              continue;
            }
            if ((target >> 3) == them) out[n++] = encodeMove(sq, t, 0, kFlagCapture);
            break;
          }
        }
      }
    }
    return n;
  }

  int _pawnMoves(Int32List out, int n, int sq, int us, bool capturesOnly) {
    final b = board;
    final dir = us == kWhite ? 8 : -8;
    final rank = sq >> 3;
    final promoRank = us == kWhite ? 6 : 1;
    final startRank = us == kWhite ? 1 : 6;
    final one = sq + dir;
    if (b[one] == 0) {
      if (rank == promoRank) {
        for (var p = kQueen; p >= kKnight; p--) {
          out[n++] = encodeMove(sq, one, p);
        }
      } else if (!capturesOnly) {
        out[n++] = encodeMove(sq, one);
        if (rank == startRank && b[one + dir] == 0) out[n++] = encodeMove(sq, one + dir, 0, kFlagDoublePush);
      }
    }
    for (final t in pawnAttacks[(us << 6) | sq]) {
      final target = b[t];
      if (target != 0 && (target >> 3) != us) {
        if (rank == promoRank) {
          for (var p = kQueen; p >= kKnight; p--) {
            out[n++] = encodeMove(sq, t, p, kFlagCapture);
          }
        } else {
          out[n++] = encodeMove(sq, t, 0, kFlagCapture);
        }
      } else if (t == ep) {
        out[n++] = encodeMove(sq, t, 0, kFlagCapture | kFlagEnPassant);
      }
    }
    return n;
  }

  int _castles(Int32List out, int n, int sq, int us) {
    final b = board;
    final them = us ^ 1;
    if (us == kWhite && sq == 4) {
      if (castling & kCastleWK != 0 && b[5] == 0 && b[6] == 0 && b[7] == kRook) {
        if (!isAttacked(4, them) && !isAttacked(5, them) && !isAttacked(6, them)) {
          out[n++] = encodeMove(4, 6, 0, kFlagCastle);
        }
      }
      if (castling & kCastleWQ != 0 && b[3] == 0 && b[2] == 0 && b[1] == 0 && b[0] == kRook) {
        if (!isAttacked(4, them) && !isAttacked(3, them) && !isAttacked(2, them)) {
          out[n++] = encodeMove(4, 2, 0, kFlagCastle);
        }
      }
    } else if (us == kBlack && sq == 60) {
      if (castling & kCastleBK != 0 && b[61] == 0 && b[62] == 0 && b[63] == (8 | kRook)) {
        if (!isAttacked(60, them) && !isAttacked(61, them) && !isAttacked(62, them)) {
          out[n++] = encodeMove(60, 62, 0, kFlagCastle);
        }
      }
      if (castling & kCastleBQ != 0 && b[59] == 0 && b[58] == 0 && b[57] == 0 && b[56] == (8 | kRook)) {
        if (!isAttacked(60, them) && !isAttacked(59, them) && !isAttacked(58, them)) {
          out[n++] = encodeMove(60, 58, 0, kFlagCastle);
        }
      }
    }
    return n;
  }

  /// Makes [m]. Returns false (and leaves the position unchanged) when the
  /// move would leave the mover's king in check.
  bool makeMove(int m) {
    final from = m & 63, to = (m >> 6) & 63, promo = (m >> 12) & 7, flags = m >> 16;
    final us = side, them = us ^ 1;
    final b = board;
    final piece = b[from];
    final captured = b[to];
    _undo
      ..add(m)
      ..add(captured | (castling << 4) | ((ep + 1) << 8) | (halfmove << 16));
    hashHistory.add(hash);

    final zp = _z.pieces;
    var h = hash;
    if (ep >= 0) h ^= _z.ep[ep & 7];
    h ^= _z.castling[castling];

    b[from] = 0;
    h ^= zp[piece * 64 + from];
    if (flags & kFlagEnPassant != 0) {
      final capSq = us == kWhite ? to - 8 : to + 8;
      h ^= zp[b[capSq] * 64 + capSq];
      b[capSq] = 0;
    } else if (captured != 0) {
      h ^= zp[captured * 64 + to];
    }
    final placed = promo != 0 ? ((us << 3) | promo) : piece;
    b[to] = placed;
    h ^= zp[placed * 64 + to];
    if (flags & kFlagCastle != 0) {
      final rf = to > from ? from + 3 : from - 4;
      final rt = to > from ? from + 1 : from - 1;
      final rookPc = b[rf];
      b[rf] = 0;
      b[rt] = rookPc;
      h ^= zp[rookPc * 64 + rf] ^ zp[rookPc * 64 + rt];
    }
    if ((piece & 7) == kKing) kingSq[us] = to;
    castling &= _castleMask[from] & _castleMask[to];
    h ^= _z.castling[castling];
    ep = -1;
    if (flags & kFlagDoublePush != 0 && _hasAdjacentPawn(to, them)) {
      ep = (from + to) >> 1;
      h ^= _z.ep[ep & 7];
    }
    if ((piece & 7) == kPawn || captured != 0 || flags & kFlagEnPassant != 0) {
      halfmove = 0;
    } else {
      halfmove++;
    }
    if (us == kBlack) fullmove++;
    side = them;
    h ^= _z.side;
    hash = h;
    if (isAttacked(kingSq[us], them)) {
      unmakeMove();
      return false;
    }
    return true;
  }

  /// Takes back the last [makeMove].
  void unmakeMove() {
    final packed = _undo.removeLast();
    final m = _undo.removeLast();
    hash = hashHistory.removeLast();
    final from = m & 63, to = (m >> 6) & 63, promo = (m >> 12) & 7, flags = m >> 16;
    side ^= 1;
    final us = side;
    if (us == kBlack) fullmove--;
    final captured = packed & 15;
    castling = (packed >> 4) & 15;
    ep = ((packed >> 8) & 127) - 1;
    halfmove = packed >> 16;
    final b = board;
    final piece = promo != 0 ? ((us << 3) | kPawn) : b[to];
    b[from] = piece;
    if (flags & kFlagEnPassant != 0) {
      b[to] = 0;
      b[us == kWhite ? to - 8 : to + 8] = ((us ^ 1) << 3) | kPawn;
    } else {
      b[to] = captured;
    }
    if (flags & kFlagCastle != 0) {
      final rf = to > from ? from + 3 : from - 4;
      final rt = to > from ? from + 1 : from - 1;
      b[rf] = b[rt];
      b[rt] = 0;
    }
    if ((piece & 7) == kKing) kingSq[us] = from;
  }

  /// Passes the move (search only; never while in check).
  void makeNullMove() {
    _undo
      ..add(0)
      ..add((castling << 4) | ((ep + 1) << 8) | (halfmove << 16));
    hashHistory.add(hash);
    var h = hash;
    if (ep >= 0) h ^= _z.ep[ep & 7];
    ep = -1;
    halfmove++;
    side ^= 1;
    hash = h ^ _z.side;
  }

  void unmakeNullMove() {
    final packed = _undo.removeLast();
    _undo.removeLast();
    hash = hashHistory.removeLast();
    side ^= 1;
    ep = ((packed >> 8) & 127) - 1;
    halfmove = packed >> 16;
  }

  /// All legal moves.
  List<int> legalMoves() {
    final buf = Int32List(256);
    final n = generate(buf);
    final out = <int>[];
    for (var i = 0; i < n; i++) {
      if (makeMove(buf[i])) {
        out.add(buf[i]);
        unmakeMove();
      }
    }
    return out;
  }

  bool hasLegalMove() {
    final buf = Int32List(256);
    final n = generate(buf);
    for (var i = 0; i < n; i++) {
      if (makeMove(buf[i])) {
        unmakeMove();
        return true;
      }
    }
    return false;
  }

  /// A position is a dead draw by material: K v K, K+minor v K, and any
  /// number of bishops that all stand on one square colour.
  bool insufficientMaterial() {
    var knights = 0, light = 0, dark = 0;
    for (var sq = 0; sq < 64; sq++) {
      final t = board[sq] & 7;
      if (t == 0 || t == kKing) continue;
      if (t == kPawn || t == kRook || t == kQueen) return false;
      if (t == kKnight) {
        knights++;
      } else if (((sq >> 3) + (sq & 7)) & 1 == 0) {
        dark++;
      } else {
        light++;
      }
    }
    if (knights == 0) return light == 0 || dark == 0;
    return knights == 1 && light == 0 && dark == 0;
  }

  /// Whether the current position already occurred since the last
  /// irreversible move (same side to move).
  bool isRepetition() {
    final n = hashHistory.length;
    final stop = n - halfmove;
    for (var i = n - 2; i >= 0 && i >= stop; i -= 2) {
      if (hashHistory[i] == hash) return true;
    }
    return false;
  }

  /// Number of times the current position occurred, including now.
  int repetitionCount() {
    var count = 1;
    final n = hashHistory.length;
    final stop = n - halfmove;
    for (var i = n - 2; i >= 0 && i >= stop; i -= 2) {
      if (hashHistory[i] == hash) count++;
    }
    return count;
  }

  /// Counts leaf nodes of the legal move tree (move-generator test).
  int perft(int depth) {
    if (depth == 0) return 1;
    final buf = Int32List(256);
    final n = generate(buf);
    var nodes = 0;
    for (var i = 0; i < n; i++) {
      if (!makeMove(buf[i])) continue;
      nodes += depth == 1 ? 1 : perft(depth - 1);
      unmakeMove();
    }
    return nodes;
  }
}
