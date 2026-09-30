/// Falling Blocks: a generic implementation of the public falling-block
/// mechanics with original naming.
///
/// * a 10-wide well with 20 visible rows and 2 hidden spawn rows;
/// * seven four-cell shapes dealt from a seeded 7-bag with a 5-piece
///   preview and a once-per-piece hold;
/// * four rotation states per shape with a five-test wall-kick table
///   (the widely documented "super rotation" offsets);
/// * gravity from a per-level speed curve (60 frames per second), soft drop
///   (1 point per row) and hard drop (2 points per row), 30-frame lock delay
///   with at most 15 resets;
/// * line clears score 100 / 300 / 500 / 800 × level; the level rises every
///   10 lines;
/// * the game ends when a new piece cannot spawn or a piece locks entirely
///   inside the hidden rows.
///
/// Undo returns to the spawn of the previously locked piece.
library;

import 'dart:math' as math;

import '../core/puzzle_game.dart';
import '../core/seeded_rng.dart';

enum BlockShape { bar, box, tee, skewRight, skewLeft, hookLeft, hookRight }

const int kWellWidth = 10;
const int kWellHeight = 22;
const int kHiddenRows = 2;
const int kPreview = 5;
const int kLockDelayFrames = 30;
const int kMaxLockResets = 15;

/// Cell offsets per shape and rotation (y grows downwards).
final Map<BlockShape, List<List<(int, int)>>> kShapeCells = {
  for (final s in BlockShape.values) s: _rotations(s),
};

List<List<(int, int)>> _rotations(BlockShape s) {
  final (List<(int, int)> base, int box) = switch (s) {
    BlockShape.bar => (const [(0, 1), (1, 1), (2, 1), (3, 1)], 4),
    BlockShape.box => (const [(1, 0), (2, 0), (1, 1), (2, 1)], 0),
    BlockShape.tee => (const [(1, 0), (0, 1), (1, 1), (2, 1)], 3),
    BlockShape.skewRight => (const [(1, 0), (2, 0), (0, 1), (1, 1)], 3),
    BlockShape.skewLeft => (const [(0, 0), (1, 0), (1, 1), (2, 1)], 3),
    BlockShape.hookLeft => (const [(0, 0), (0, 1), (1, 1), (2, 1)], 3),
    BlockShape.hookRight => (const [(2, 0), (0, 1), (1, 1), (2, 1)], 3),
  };
  final out = <List<(int, int)>>[base];
  for (var r = 1; r < 4; r++) {
    out.add(box == 0 ? base : [for (final (x, y) in out.last) (box - 1 - y, x)]);
  }
  return out;
}

/// Kick offsets (x, y-down) for rotating from state `from` to `to`.
List<(int, int)> kicks(BlockShape s, int from, int to) {
  if (s == BlockShape.box) return const [(0, 0)];
  // Tables are written y-up; convert.
  const jlstz = {
    '01': [(0, 0), (-1, 0), (-1, 1), (0, -2), (-1, -2)],
    '10': [(0, 0), (1, 0), (1, -1), (0, 2), (1, 2)],
    '12': [(0, 0), (1, 0), (1, -1), (0, 2), (1, 2)],
    '21': [(0, 0), (-1, 0), (-1, 1), (0, -2), (-1, -2)],
    '23': [(0, 0), (1, 0), (1, 1), (0, -2), (1, -2)],
    '32': [(0, 0), (-1, 0), (-1, -1), (0, 2), (-1, 2)],
    '30': [(0, 0), (-1, 0), (-1, -1), (0, 2), (-1, 2)],
    '03': [(0, 0), (1, 0), (1, 1), (0, -2), (1, -2)],
  };
  const bar = {
    '01': [(0, 0), (-2, 0), (1, 0), (-2, -1), (1, 2)],
    '10': [(0, 0), (2, 0), (-1, 0), (2, 1), (-1, -2)],
    '12': [(0, 0), (-1, 0), (2, 0), (-1, 2), (2, -1)],
    '21': [(0, 0), (1, 0), (-2, 0), (1, -2), (-2, 1)],
    '23': [(0, 0), (2, 0), (-1, 0), (2, 1), (-1, -2)],
    '32': [(0, 0), (-2, 0), (1, 0), (-2, -1), (1, 2)],
    '30': [(0, 0), (1, 0), (-2, 0), (1, -2), (-2, 1)],
    '03': [(0, 0), (-1, 0), (2, 0), (-1, 2), (2, -1)],
  };
  final table = s == BlockShape.bar ? bar : jlstz;
  final key = '$from$to';
  final list = table[key];
  if (list == null) return const [(0, 0)]; // 180° turns: no kicks
  return [for (final (x, y) in list) (x, -y)];
}

/// Seconds per row at [level] (1-based) from the common speed curve.
double secondsPerRow(int level) {
  final l = math.max(1, level);
  return math.pow(0.8 - (l - 1) * 0.007, l - 1).toDouble();
}

final class FallingConfig {
  const FallingConfig({this.startLevel = 1, this.seed = 0});

  factory FallingConfig.forDifficulty(PuzzleDifficulty d, {int seed = 0}) => FallingConfig(
    seed: seed,
    startLevel: switch (d) {
      PuzzleDifficulty.easy => 1,
      PuzzleDifficulty.medium => 4,
      PuzzleDifficulty.hard => 8,
      PuzzleDifficulty.expert => 12,
    },
  );

  final int startLevel;
  final int seed;

  Map<String, Object?> toJson() => {'level': startLevel, 'seed': seed};

  factory FallingConfig.fromJson(Map<String, Object?> j) =>
      FallingConfig(startLevel: jsonInt(j, 'level', 1), seed: jsonInt(j, 'seed'));
}

/// The active piece.
final class ActivePiece {
  const ActivePiece(this.shape, this.rotation, this.x, this.y);
  final BlockShape shape;
  final int rotation;
  final int x;
  final int y;

  List<(int, int)> get cells => [for (final (dx, dy) in kShapeCells[shape]![rotation]) (x + dx, y + dy)];

  ActivePiece moved(int dx, int dy, [int? rotation]) => ActivePiece(shape, rotation ?? this.rotation, x + dx, y + dy);

  Map<String, Object?> toJson() => {'s': shape.index, 'r': rotation, 'x': x, 'y': y};

  factory ActivePiece.fromJson(Map<String, Object?> j) =>
      ActivePiece(BlockShape.values[jsonInt(j, 's')], jsonInt(j, 'r'), jsonInt(j, 'x'), jsonInt(j, 'y'));

  static ActivePiece spawn(BlockShape s) => ActivePiece(s, 0, 3, 0);

  @override
  bool operator ==(Object other) =>
      other is ActivePiece && other.shape == shape && other.rotation == rotation && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(shape, rotation, x, y);
}

final class FallingState extends PuzzleState {
  const FallingState({
    required this.well,
    required this.piece,
    required this.queue,
    required this.rng,
    this.hold,
    this.holdUsed = false,
    this.level = 1,
    this.lines = 0,
    this.score = 0,
    this.gravity = 0,
    this.lockFrames = 0,
    this.lockResets = 0,
    this.lowestY = 0,
    this.pieces = 1,
    this.frames = 0,
    this.lastClear = 0,
    this.over = false,
  });

  /// Row-major cells: 0 empty, else `shape.index + 1`.
  final List<int> well;
  final ActivePiece piece;
  final List<BlockShape> queue;
  final List<int> rng;
  final BlockShape? hold;
  final bool holdUsed;
  final int level;
  final int lines;
  final int score;

  /// Fractional rows accumulated by gravity.
  final double gravity;
  final int lockFrames;
  final int lockResets;
  final int lowestY;

  /// Pieces spawned so far (increments at each lock).
  final int pieces;
  final int frames;

  /// Lines cleared by the last lock.
  final int lastClear;
  final bool over;

  /// The next [kPreview] shapes.
  List<BlockShape> get preview => queue.take(kPreview).toList();

  FallingState copyWith({
    List<int>? well,
    ActivePiece? piece,
    List<BlockShape>? queue,
    List<int>? rng,
    BlockShape? hold,
    bool clearHold = false,
    bool? holdUsed,
    int? level,
    int? lines,
    int? score,
    double? gravity,
    int? lockFrames,
    int? lockResets,
    int? lowestY,
    int? pieces,
    int? frames,
    int? lastClear,
    bool? over,
  }) => FallingState(
    well: well ?? this.well,
    piece: piece ?? this.piece,
    queue: queue ?? this.queue,
    rng: rng ?? this.rng,
    hold: clearHold ? null : (hold ?? this.hold),
    holdUsed: holdUsed ?? this.holdUsed,
    level: level ?? this.level,
    lines: lines ?? this.lines,
    score: score ?? this.score,
    gravity: gravity ?? this.gravity,
    lockFrames: lockFrames ?? this.lockFrames,
    lockResets: lockResets ?? this.lockResets,
    lowestY: lowestY ?? this.lowestY,
    pieces: pieces ?? this.pieces,
    frames: frames ?? this.frames,
    lastClear: lastClear ?? this.lastClear,
    over: over ?? this.over,
  );

  @override
  Map<String, Object?> toJson() => {
    'well': well,
    'piece': piece.toJson(),
    'queue': [for (final s in queue) s.index],
    'rng': rng,
    'hold': hold?.index,
    'holdUsed': holdUsed,
    'level': level,
    'lines': lines,
    'score': score,
    'gravity': gravity,
    'lock': lockFrames,
    'resets': lockResets,
    'lowest': lowestY,
    'pieces': pieces,
    'frames': frames,
    'lastClear': lastClear,
    'over': over,
  };

  factory FallingState.fromJson(Map<String, Object?> j) => FallingState(
    well: List.unmodifiable(jsonInts(j['well'])),
    piece: ActivePiece.fromJson(jsonObject(j['piece'])),
    queue: List.unmodifiable([for (final i in jsonInts(j['queue'])) BlockShape.values[i]]),
    rng: jsonInts(j['rng']),
    hold: j['hold'] == null ? null : BlockShape.values[jsonInt(j, 'hold')],
    holdUsed: j['holdUsed'] == true,
    level: jsonInt(j, 'level', 1),
    lines: jsonInt(j, 'lines'),
    score: jsonInt(j, 'score'),
    gravity: (j['gravity'] as num?)?.toDouble() ?? 0,
    lockFrames: jsonInt(j, 'lock'),
    lockResets: jsonInt(j, 'resets'),
    lowestY: jsonInt(j, 'lowest'),
    pieces: jsonInt(j, 'pieces', 1),
    frames: jsonInt(j, 'frames'),
    lastClear: jsonInt(j, 'lastClear'),
    over: j['over'] == true,
  );
}

enum FallingAction implements PuzzleAction {
  moveLeft,
  moveRight,
  rotateCw,
  rotateCcw,
  softDrop,
  hardDrop,
  hold,

  /// Advances one 1/60 s frame (gravity and lock delay).
  tick;

  @override
  Map<String, Object?> toJson() => {'a': name};

  static FallingAction fromJson(Map<String, Object?> j) => FallingAction.values.byName(j['a']! as String);
}

/// A best placement found by the hint AI.
final class BlockPlacement {
  const BlockPlacement(this.rotation, this.x, this.score);
  final int rotation;
  final int x;
  final double score;
}

/// A Falling Blocks game.
final class FallingBlocksGame extends PuzzleBase<FallingState, FallingAction> {
  FallingBlocksGame._(this.config, super.initial, {super.history}) : _pieceStart = initial;

  factory FallingBlocksGame(FallingConfig config) {
    final rng = SeededRng(config.seed);
    final queue = <BlockShape>[];
    _refill(queue, rng);
    final first = queue.removeAt(0);
    _refill(queue, rng);
    return FallingBlocksGame._(
      config,
      FallingState(
        well: List.unmodifiable(List<int>.filled(kWellWidth * kWellHeight, 0)),
        piece: ActivePiece.spawn(first),
        queue: List.unmodifiable(queue),
        rng: rng.state,
        level: config.startLevel,
      ),
    );
  }

  factory FallingBlocksGame.fromJson(Map<String, Object?> json) {
    checkKind(json, PuzzleKind.fallingBlocks);
    return FallingBlocksGame._(
      FallingConfig.fromJson(jsonObject(json['config'])),
      FallingState.fromJson(jsonObject(json['state'])),
      history: jsonHistory(json, FallingState.fromJson),
    );
  }

  final FallingConfig config;
  FallingState _pieceStart;
  double _clock = 0;

  @override
  PuzzleKind get kind => PuzzleKind.fallingBlocks;

  static void _refill(List<BlockShape> queue, SeededRng rng) {
    while (queue.length < 7) {
      final bag = List<BlockShape>.from(BlockShape.values);
      rng.shuffle(bag);
      queue.addAll(bag);
    }
  }

  static bool fits(List<int> well, ActivePiece p) {
    for (final (x, y) in p.cells) {
      if (x < 0 || x >= kWellWidth || y < 0 || y >= kWellHeight) return false;
      if (well[y * kWellWidth + x] != 0) return false;
    }
    return true;
  }

  static bool _grounded(List<int> well, ActivePiece p) => !fits(well, p.moved(0, 1));

  /// The piece dropped as far as it goes.
  static ActivePiece ghost(List<int> well, ActivePiece p) {
    var g = p;
    while (fits(well, g.moved(0, 1))) {
      g = g.moved(0, 1);
    }
    return g;
  }

  @override
  bool apply(FallingAction action) {
    final before = state;
    final next = transition(before, action);
    if (next == null) return false;
    if (next.pieces != before.pieces) {
      pushHistory(_pieceStart);
      _pieceStart = next;
    }
    replaceState(next);
    return true;
  }

  @override
  bool undo() {
    final ok = super.undo();
    if (ok) _pieceStart = state;
    return ok;
  }

  /// Runs gravity for [seconds] of real time at 60 frames per second;
  /// returns the frames played.
  int advance(double seconds) {
    _clock += seconds;
    var n = 0;
    while (_clock >= 1 / 60 && !isOver) {
      _clock -= 1 / 60;
      apply(FallingAction.tick);
      n++;
    }
    return n;
  }

  /// After a successful move / rotation: lock-delay reset rules.
  FallingState _afterShift(FallingState s, ActivePiece p) {
    var resets = s.lockResets;
    var lock = s.lockFrames;
    var lowest = s.lowestY;
    if (p.y > lowest) {
      lowest = p.y;
      resets = 0;
      lock = 0;
    } else if (lock > 0 && resets < kMaxLockResets) {
      resets++;
      lock = 0;
    }
    return s.copyWith(piece: p, lockFrames: lock, lockResets: resets, lowestY: lowest);
  }

  @override
  FallingState? transition(FallingState s, FallingAction a) {
    if (s.over) return null;
    final well = s.well;
    final p = s.piece;
    switch (a) {
      case FallingAction.moveLeft || FallingAction.moveRight:
        final q = p.moved(a == FallingAction.moveLeft ? -1 : 1, 0);
        if (!fits(well, q)) return null;
        return _afterShift(s, q);
      case FallingAction.rotateCw || FallingAction.rotateCcw:
        final to = (p.rotation + (a == FallingAction.rotateCw ? 1 : 3)) % 4;
        for (final (kx, ky) in kicks(p.shape, p.rotation, to)) {
          final q = ActivePiece(p.shape, to, p.x + kx, p.y + ky);
          if (fits(well, q)) return _afterShift(s, q);
        }
        return null;
      case FallingAction.softDrop:
        final q = p.moved(0, 1);
        if (!fits(well, q)) return null;
        return _afterShift(s.copyWith(score: s.score + 1, gravity: 0), q);
      case FallingAction.hardDrop:
        final g = ghost(well, p);
        return _lock(s.copyWith(score: s.score + 2 * (g.y - p.y)), g);
      case FallingAction.hold:
        if (s.holdUsed) return null;
        final queue = List<BlockShape>.from(s.queue);
        final rng = SeededRng.fromState(s.rng);
        BlockShape next;
        if (s.hold == null) {
          next = queue.removeAt(0);
          _refill(queue, rng);
        } else {
          next = s.hold!;
        }
        final spawned = ActivePiece.spawn(next);
        if (!fits(well, spawned)) return s.copyWith(over: true);
        return s.copyWith(
          piece: spawned,
          hold: p.shape,
          holdUsed: true,
          queue: List.unmodifiable(queue),
          rng: rng.state,
          gravity: 0,
          lockFrames: 0,
          lockResets: 0,
          lowestY: 0,
        );
      case FallingAction.tick:
        var st = s.copyWith(frames: s.frames + 1);
        var piece = p;
        var g = st.gravity + 1 / (secondsPerRow(st.level) * 60);
        while (g >= 1) {
          g -= 1;
          final q = piece.moved(0, 1);
          if (!fits(well, q)) {
            g = 0;
            break;
          }
          piece = q;
        }
        st = st.copyWith(gravity: g, piece: piece);
        if (piece.y > st.lowestY) st = st.copyWith(lowestY: piece.y, lockResets: 0, lockFrames: 0);
        if (_grounded(well, piece)) {
          final lock = st.lockFrames + 1;
          if (lock >= kLockDelayFrames) return _lock(st, piece);
          return st.copyWith(lockFrames: lock);
        }
        return st.copyWith(lockFrames: 0);
    }
  }

  /// Locks [p], clears lines, scores and spawns the next piece.
  FallingState _lock(FallingState s, ActivePiece p) {
    final well = List<int>.from(s.well);
    var allHidden = true;
    for (final (x, y) in p.cells) {
      well[y * kWellWidth + x] = p.shape.index + 1;
      if (y >= kHiddenRows) allHidden = false;
    }
    // Clear full rows.
    var cleared = 0;
    for (var y = kWellHeight - 1; y >= 0; y--) {
      var full = true;
      for (var x = 0; x < kWellWidth; x++) {
        if (well[y * kWellWidth + x] == 0) {
          full = false;
          break;
        }
      }
      if (!full) continue;
      cleared++;
      for (var yy = y; yy > 0; yy--) {
        for (var x = 0; x < kWellWidth; x++) {
          well[yy * kWellWidth + x] = well[(yy - 1) * kWellWidth + x];
        }
      }
      for (var x = 0; x < kWellWidth; x++) {
        well[x] = 0;
      }
      y++; // re-check the row that moved down
    }
    final lines = s.lines + cleared;
    final level = math.max(s.level, config.startLevel + lines ~/ 10);
    final points = const [0, 100, 300, 500, 800][cleared] * s.level;
    final queue = List<BlockShape>.from(s.queue);
    final rng = SeededRng.fromState(s.rng);
    final next = queue.removeAt(0);
    _refill(queue, rng);
    final spawned = ActivePiece.spawn(next);
    final over = allHidden || !fits(well, spawned);
    return FallingState(
      well: List.unmodifiable(well),
      piece: spawned,
      queue: List.unmodifiable(queue),
      rng: rng.state,
      hold: s.hold,
      holdUsed: false,
      level: level,
      lines: lines,
      score: s.score + points,
      pieces: s.pieces + 1,
      frames: s.frames,
      lastClear: cleared,
      over: over,
    );
  }

  @override
  bool get isSolved => false;

  /// Falling Blocks is endless: it is over when the stack tops out.
  @override
  bool get isOver => state.over;

  // -------------------------------------------------------------------------
  // Hint AI (feature-weighted placement search).

  /// The best final rotation / column for the current piece.
  static BlockPlacement? bestPlacement(List<int> well, BlockShape shape) {
    BlockPlacement? best;
    for (var r = 0; r < 4; r++) {
      for (var x = -3; x < kWellWidth + 3; x++) {
        final start = ActivePiece(shape, r, x, 0);
        if (!fits(well, start)) continue;
        final g = ghost(well, start);
        final score = _evaluate(well, g);
        if (best == null || score > best.score) best = BlockPlacement(r, x, score);
      }
    }
    return best;
  }

  static double _evaluate(List<int> well0, ActivePiece p) {
    final well = List<int>.from(well0);
    for (final (x, y) in p.cells) {
      well[y * kWellWidth + x] = 1;
    }
    var cleared = 0;
    final full = <int>{};
    for (var y = 0; y < kWellHeight; y++) {
      var f = true;
      for (var x = 0; x < kWellWidth; x++) {
        if (well[y * kWellWidth + x] == 0) f = false;
      }
      if (f) {
        cleared++;
        full.add(y);
      }
    }
    final rows = [
      for (var y = 0; y < kWellHeight; y++)
        if (!full.contains(y)) [for (var x = 0; x < kWellWidth; x++) well[y * kWellWidth + x] != 0],
    ];
    final h = rows.length;
    final landing = kWellHeight - p.cells.map((c) => c.$2).reduce(math.max);
    var rowTrans = 0, colTrans = 0, holes = 0, wells = 0;
    for (final row in rows) {
      var prev = true;
      for (final c in row) {
        if (c != prev) rowTrans++;
        prev = c;
      }
      if (!prev) rowTrans++;
    }
    for (var x = 0; x < kWellWidth; x++) {
      var prev = false;
      var seenBlock = false;
      for (var y = 0; y < h; y++) {
        final c = rows[y][x];
        if (c != prev) colTrans++;
        if (c) seenBlock = true;
        if (!c && seenBlock) holes++;
        prev = c;
      }
      if (!prev) colTrans++;
      var depth = 0;
      for (var y = 0; y < h; y++) {
        final left = x == 0 || rows[y][x - 1];
        final right = x == kWellWidth - 1 || rows[y][x + 1];
        if (!rows[y][x] && left && right) {
          depth++;
          wells += depth;
        } else {
          depth = 0;
        }
      }
    }
    return -4.5 * landing + 3.4 * cleared - 3.2 * rowTrans - 9.3 * colTrans - 7.9 * holes - 3.4 * wells;
  }

  /// The next input towards the AI's best placement (`placement`), with the
  /// target cells as focus (row-major indices).
  @override
  PuzzleHint<FallingAction>? hint() {
    if (isOver) return null;
    final s = state;
    final best = bestPlacement(s.well, s.piece.shape);
    if (best == null) return const PuzzleHint(FallingAction.hardDrop, technique: 'placement');
    final target = ghost(s.well, ActivePiece(s.piece.shape, best.rotation, best.x, 0));
    final focus = [for (final (x, y) in target.cells) y * kWellWidth + x];
    final p = s.piece;
    FallingAction action;
    if (p.rotation != best.rotation) {
      action = (best.rotation - p.rotation + 4) % 4 == 3 ? FallingAction.rotateCcw : FallingAction.rotateCw;
    } else if (p.x != best.x) {
      action = p.x < best.x ? FallingAction.moveRight : FallingAction.moveLeft;
    } else {
      action = FallingAction.hardDrop;
    }
    if (transition(s, action) == null) action = FallingAction.hardDrop;
    return PuzzleHint(action, technique: 'placement', focus: focus);
  }

  @override
  Map<String, Object?> configJson() => config.toJson();
}
