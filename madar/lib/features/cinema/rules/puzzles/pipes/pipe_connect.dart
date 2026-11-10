/// Pipe Connect: every tile of a generated network was rotated; rotate them
/// back so that all pipes join with no loose end and every tile is fed from
/// the source.
///
/// Generation grows a random spanning tree from the centre (randomised
/// Prim), so the network is connected and loop-free; tiles are then turned
/// by random quarter turns. Win detection checks the rules (all ends matched
/// and everything connected), not the original orientation, so any
/// alternative arrangement that satisfies them also wins.
///
/// Masks: up = 1, right = 2, down = 4, left = 8 (see [Dir4.bit]).
library;

import '../core/grid.dart';
import '../core/puzzle_game.dart';
import '../core/seeded_rng.dart';

/// Rotates a pipe mask by [turns] clockwise quarter turns.
int rotateMask(int mask, int turns) {
  var m = mask & 0xF;
  for (var i = 0; i < (turns % 4 + 4) % 4; i++) {
    m = ((m << 1) | (m >> 3)) & 0xF;
  }
  return m;
}

final class PipeConfig {
  const PipeConfig({this.width = 7, this.height = 7, this.wrap = false, this.seed = 0})
    : assert(width >= 2 && height >= 2);

  /// Sizes 5×5, 7×7, 9×9 and a wrapping 11×11 for expert.
  factory PipeConfig.forDifficulty(PuzzleDifficulty d, {int seed = 0}) => switch (d) {
    PuzzleDifficulty.easy => PipeConfig(width: 5, height: 5, seed: seed),
    PuzzleDifficulty.medium => PipeConfig(width: 7, height: 7, seed: seed),
    PuzzleDifficulty.hard => PipeConfig(width: 9, height: 9, seed: seed),
    PuzzleDifficulty.expert => PipeConfig(width: 11, height: 11, wrap: true, seed: seed),
  };

  final int width;
  final int height;

  /// Edges wrap around (a torus).
  final bool wrap;
  final int seed;

  int get source => (height ~/ 2) * width + width ~/ 2;

  Map<String, Object?> toJson() => {'w': width, 'h': height, 'wrap': wrap, 'seed': seed};

  factory PipeConfig.fromJson(Map<String, Object?> j) =>
      PipeConfig(width: jsonInt(j, 'w', 7), height: jsonInt(j, 'h', 7), wrap: j['wrap'] == true, seed: jsonInt(j, 'seed'));
}

/// The generated network.
final class PipeNetwork {
  const PipeNetwork(this.config, this.solution, this.scrambled);

  final PipeConfig config;

  /// Masks in the solved orientation.
  final List<int> solution;

  /// Masks as dealt.
  final List<int> scrambled;

  /// Neighbour of [i] in [d] honouring wrap-around (-1 off the board).
  static int neighbour(PipeConfig c, int i, Dir4 d) {
    var x = i % c.width + d.dx, y = i ~/ c.width + d.dy;
    if (c.wrap) {
      x = (x + c.width) % c.width;
      y = (y + c.height) % c.height;
    } else if (x < 0 || y < 0 || x >= c.width || y >= c.height) {
      return -1;
    }
    return y * c.width + x;
  }

  static PipeNetwork generate(PipeConfig config) {
    final rng = SeededRng(config.seed);
    final n = config.width * config.height;
    while (true) {
      final masks = List<int>.filled(n, 0);
      final inTree = List<bool>.filled(n, false);
      final frontier = <(int, Dir4)>[];
      void add(int c) {
        inTree[c] = true;
        for (final d in Dir4.values) {
          final nb = neighbour(config, c, d);
          if (nb >= 0 && !inTree[nb]) frontier.add((c, d));
        }
      }

      add(config.source);
      while (frontier.isNotEmpty) {
        final k = rng.nextInt(frontier.length);
        final (c, d) = frontier[k];
        frontier[k] = frontier.last;
        frontier.removeLast();
        final nb = neighbour(config, c, d);
        if (inTree[nb]) continue;
        // Prefer branching from tiles with fewer than three pipes, which
        // keeps 4-way crosses (nothing to rotate) rare.
        if (_bits(masks[c]) >= 3 && rng.nextInt(3) != 0 && frontier.any((e) => _bits(masks[e.$1]) < 3)) {
          frontier.add((c, d));
          continue;
        }
        masks[c] |= d.bit;
        masks[nb] |= d.opposite.bit;
        add(nb);
      }
      final scrambled = [for (final m in masks) rotateMask(m, rng.nextInt(4))];
      final net = PipeNetwork(config, List.unmodifiable(masks), List.unmodifiable(scrambled));
      if (!isSolvedLayout(config, scrambled)) return net;
    }
  }

  static int _bits(int m) => bitCount(m);

  /// Tiles fed from the source through matched connections.
  static List<bool> powered(PipeConfig c, List<int> masks) {
    final n = masks.length;
    final on = List<bool>.filled(n, false);
    final stack = [c.source];
    on[c.source] = true;
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      for (final d in Dir4.values) {
        if (masks[i] & d.bit == 0) continue;
        final nb = neighbour(c, i, d);
        if (nb < 0 || on[nb] || masks[nb] & d.opposite.bit == 0) continue;
        on[nb] = true;
        stack.add(nb);
      }
    }
    return on;
  }

  /// All ends matched and every tile powered.
  static bool isSolvedLayout(PipeConfig c, List<int> masks) {
    for (var i = 0; i < masks.length; i++) {
      for (final d in Dir4.values) {
        if (masks[i] & d.bit == 0) continue;
        final nb = neighbour(c, i, d);
        if (nb < 0 || masks[nb] & d.opposite.bit == 0) return false;
      }
    }
    return !powered(c, masks).contains(false);
  }
}

final class PipeState extends PuzzleState {
  const PipeState({required this.rotations, required this.locked, this.moves = 0});

  /// Clockwise quarter turns applied to each dealt tile (0..3).
  final List<int> rotations;

  /// Tiles the player locked against rotation.
  final List<bool> locked;
  final int moves;

  @override
  Map<String, Object?> toJson() => {
    'rot': rotations,
    'locked': [for (final l in locked) l ? 1 : 0],
    'moves': moves,
  };

  factory PipeState.fromJson(Map<String, Object?> j) => PipeState(
    rotations: List.unmodifiable(jsonInts(j['rot'])),
    locked: List.unmodifiable([for (final v in jsonInts(j['locked'])) v == 1]),
    moves: jsonInt(j, 'moves'),
  );
}

enum PipeActionType { rotate, lock }

final class PipeAction extends PuzzleAction {
  /// Rotates [cell] by [turns] clockwise quarter turns (1..3).
  const PipeAction.rotate(this.cell, [this.turns = 1]) : type = PipeActionType.rotate;

  /// Toggles the lock of [cell].
  const PipeAction.lock(this.cell) : type = PipeActionType.lock, turns = 0;

  final PipeActionType type;
  final int cell;
  final int turns;

  @override
  Map<String, Object?> toJson() => {'t': type.name, 'c': cell, 'n': turns};

  factory PipeAction.fromJson(Map<String, Object?> j) => j['t'] == PipeActionType.lock.name
      ? PipeAction.lock(jsonInt(j, 'c'))
      : PipeAction.rotate(jsonInt(j, 'c'), jsonInt(j, 'n', 1));

  @override
  bool operator ==(Object other) => other is PipeAction && other.type == type && other.cell == cell && other.turns == turns;

  @override
  int get hashCode => Object.hash(type, cell, turns);

  @override
  String toString() => 'PipeAction(${type.name}, $cell, $turns)';
}

/// A Pipe Connect game.
final class PipeGame extends PuzzleBase<PipeState, PipeAction> {
  PipeGame._(this.network, super.initial, {super.history});

  factory PipeGame(PipeConfig config) {
    final net = PipeNetwork.generate(config);
    final n = config.width * config.height;
    return PipeGame._(
      net,
      PipeState(
        rotations: List.unmodifiable(List<int>.filled(n, 0)),
        locked: List.unmodifiable(List<bool>.filled(n, false)),
      ),
    );
  }

  factory PipeGame.fromJson(Map<String, Object?> json) {
    checkKind(json, PuzzleKind.pipeConnect);
    final net = PipeNetwork.generate(PipeConfig.fromJson(jsonObject(json['config'])));
    return PipeGame._(
      net,
      PipeState.fromJson(jsonObject(json['state'])),
      history: jsonHistory(json, PipeState.fromJson),
    );
  }

  final PipeNetwork network;

  PipeConfig get config => network.config;

  @override
  PuzzleKind get kind => PuzzleKind.pipeConnect;

  /// Current masks.
  List<int> get masks => [
    for (var i = 0; i < network.scrambled.length; i++) rotateMask(network.scrambled[i], state.rotations[i]),
  ];

  /// Tiles currently fed from the source (for rendering).
  List<bool> powered() => PipeNetwork.powered(config, masks);

  @override
  PipeState? transition(PipeState s, PipeAction a) {
    if (a.cell < 0 || a.cell >= s.rotations.length || isSolved) return null;
    switch (a.type) {
      case PipeActionType.rotate:
        if (s.locked[a.cell] || a.turns % 4 == 0) return null;
        return PipeState(
          rotations: List.unmodifiable(List<int>.from(s.rotations)..[a.cell] = (s.rotations[a.cell] + a.turns) % 4),
          locked: s.locked,
          moves: s.moves + 1,
        );
      case PipeActionType.lock:
        return PipeState(
          rotations: s.rotations,
          locked: List.unmodifiable(List<bool>.from(s.locked)..[a.cell] = !s.locked[a.cell]),
          moves: s.moves,
        );
    }
  }

  @override
  bool get isSolved => PipeNetwork.isSolvedLayout(config, masks);

  @override
  bool get isOver => isSolved;

  /// Turns a tile towards the generated solution: first an unlocked tile
  /// fed from the source that is wrong, else any wrong tile (unlocking a
  /// wrongly locked one first).
  @override
  PuzzleHint<PipeAction>? hint() {
    if (isSolved) return null;
    final m = masks;
    final on = powered();
    int? pick;
    for (final wantPowered in const [true, false]) {
      for (var i = 0; i < m.length; i++) {
        if (m[i] != network.solution[i] && on[i] == wantPowered) {
          pick = i;
          break;
        }
      }
      if (pick != null) break;
    }
    if (pick == null) return null;
    if (state.locked[pick]) return PuzzleHint(PipeAction.lock(pick), technique: 'unlock', focus: [pick]);
    for (var t = 1; t < 4; t++) {
      if (rotateMask(m[pick], t) == network.solution[pick]) {
        return PuzzleHint(PipeAction.rotate(pick, t), technique: 'rotate', focus: [pick]);
      }
    }
    return null;
  }

  @override
  Map<String, Object?> configJson() => config.toJson();
}
