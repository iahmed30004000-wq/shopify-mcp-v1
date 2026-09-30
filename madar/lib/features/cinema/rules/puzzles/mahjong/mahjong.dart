/// Mahjong Solitaire: solvable deals by reverse construction, free-tile
/// rules, matching (any flower with any flower, any season with any
/// season), solvable shuffles, a search-based hint and undo.
library;

import '../core/puzzle_game.dart';
import '../core/seeded_rng.dart';
import 'mahjong_layouts.dart';

export 'mahjong_layouts.dart';

/// Tile faces 0..41: 0–8 circles, 9–17 bamboos, 18–26 characters,
/// 27–30 winds, 31–33 dragons, 34–37 flowers, 38–41 seasons.
abstract final class MahjongFaces {
  static const int count = 42;
  static const int firstFlower = 34;
  static const int firstSeason = 38;

  /// Faces that match each other share a group.
  static int group(int face) => face >= firstSeason ? -2 : (face >= firstFlower ? -1 : face);

  static bool matches(int a, int b) => group(a) == group(b);

  /// The 72 matching pairs of the full 144-tile set.
  static List<(int, int)> fullPairs() => [
    for (var f = 0; f < firstFlower; f++) ...[(f, f), (f, f)],
    (34, 35),
    (36, 37),
    (38, 39),
    (40, 41),
  ];
}

final class MahjongConfig {
  const MahjongConfig({this.layout = MahjongLayoutId.turtle, this.seed = 0, this.shuffles = 3});

  /// Difficulty sets the number of shuffles allowed when stuck.
  factory MahjongConfig.forDifficulty(
    PuzzleDifficulty d, {
    MahjongLayoutId layout = MahjongLayoutId.turtle,
    int seed = 0,
  }) => MahjongConfig(
    layout: layout,
    seed: seed,
    shuffles: switch (d) {
      PuzzleDifficulty.easy => 5,
      PuzzleDifficulty.medium => 3,
      PuzzleDifficulty.hard => 1,
      PuzzleDifficulty.expert => 0,
    },
  );

  final MahjongLayoutId layout;
  final int seed;
  final int shuffles;

  Map<String, Object?> toJson() => {'layout': layout.name, 'seed': seed, 'shuffles': shuffles};

  factory MahjongConfig.fromJson(Map<String, Object?> j) => MahjongConfig(
    layout: MahjongLayoutId.values.byName(j['layout']! as String),
    seed: jsonInt(j, 'seed'),
    shuffles: jsonInt(j, 'shuffles', 3),
  );
}

final class MahjongState extends PuzzleState {
  const MahjongState({
    required this.faces,
    required this.present,
    required this.rng,
    required this.shufflesLeft,
    this.moves = 0,
  });

  /// Face per slot (kept after removal for rendering history).
  final List<int> faces;
  final List<bool> present;
  final List<int> rng;
  final int shufflesLeft;
  final int moves;

  int get remaining => present.where((p) => p).length;

  @override
  Map<String, Object?> toJson() => {
    'faces': faces,
    'present': [for (final p in present) p ? 1 : 0],
    'rng': rng,
    'shuffles': shufflesLeft,
    'moves': moves,
  };

  factory MahjongState.fromJson(Map<String, Object?> j) => MahjongState(
    faces: List.unmodifiable(jsonInts(j['faces'])),
    present: List.unmodifiable([for (final v in jsonInts(j['present'])) v == 1]),
    rng: jsonInts(j['rng']),
    shufflesLeft: jsonInt(j, 'shuffles'),
    moves: jsonInt(j, 'moves'),
  );
}

enum MahjongActionType { remove, shuffle }

final class MahjongAction extends PuzzleAction {
  const MahjongAction.remove(this.a, this.b) : type = MahjongActionType.remove;
  const MahjongAction.shuffle() : type = MahjongActionType.shuffle, a = -1, b = -1;

  final MahjongActionType type;
  final int a;
  final int b;

  @override
  Map<String, Object?> toJson() => {'t': type.name, 'a': a, 'b': b};

  factory MahjongAction.fromJson(Map<String, Object?> j) => j['t'] == MahjongActionType.shuffle.name
      ? const MahjongAction.shuffle()
      : MahjongAction.remove(jsonInt(j, 'a'), jsonInt(j, 'b'));

  @override
  bool operator ==(Object other) =>
      other is MahjongAction &&
      other.type == type &&
      ((other.a == a && other.b == b) || (other.a == b && other.b == a));

  @override
  int get hashCode => Object.hash(type, a < b ? a : b, a < b ? b : a);

  @override
  String toString() => 'MahjongAction(${type.name}, $a, $b)';
}

/// Deal construction and solving helpers.
abstract final class MahjongDealer {
  /// Assigns [pairs] to the [slots] of [layout] (other slots absent) by
  /// removing random free pairs from the full structure. The removal order
  /// is returned with the faces: replayed forwards it clears the board, so
  /// the deal is solvable by construction. Null after [attempts] failures.
  static ({List<int> faces, List<(int, int)> order})? construct(
    MahjongLayout layout,
    List<int> slots,
    List<(int, int)> pairs,
    SeededRng rng, {
    int attempts = 200,
  }) {
    for (var attempt = 0; attempt < attempts; attempt++) {
      final present = List<bool>.filled(layout.length, false);
      for (final s in slots) {
        present[s] = true;
      }
      final faces = List<int>.filled(layout.length, -1);
      final order = List<(int, int)>.from(pairs);
      rng.shuffle(order);
      final removal = <(int, int)>[];
      var ok = true;
      for (final (fa, fb) in order) {
        final free = [
          for (final s in slots)
            if (layout.isFree(s, present)) s,
        ];
        if (free.length < 2) {
          ok = false;
          break;
        }
        // Prefer high and covering tiles: they are the ones that strand others.
        free.sort((x, y) {
          final zx = layout.slots[x].z, zy = layout.slots[y].z;
          return zx != zy ? zy - zx : x - y;
        });
        final topZ = layout.slots[free.first].z;
        final top = free.where((s) => layout.slots[s].z == topZ).toList();
        final first = rng.nextInt(3) == 0 ? rng.pick(free) : rng.pick(top);
        present[first] = false;
        final rest = [
          for (final s in free)
            if (s != first && layout.isFree(s, present)) s,
        ];
        if (rest.isEmpty) {
          ok = false;
          break;
        }
        final second = rng.pick(rest);
        present[second] = false;
        faces[first] = fa;
        faces[second] = fb;
        removal.add((first, second));
      }
      if (ok) return (faces: faces, order: removal);
    }
    return null;
  }

  /// Free matching pairs of [present].
  static List<(int, int)> moves(MahjongLayout layout, List<int> faces, List<bool> present) {
    final free = [
      for (var i = 0; i < layout.length; i++)
        if (layout.isFree(i, present)) i,
    ];
    final out = <(int, int)>[];
    for (var i = 0; i < free.length; i++) {
      for (var j = i + 1; j < free.length; j++) {
        if (MahjongFaces.matches(faces[free[i]], faces[free[j]])) out.add((free[i], free[j]));
      }
    }
    return out;
  }

  /// Depth-first search for a full clearing sequence within [nodeBudget].
  static List<(int, int)>? solve(MahjongLayout layout, List<int> faces, List<bool> present, {int nodeBudget = 20000}) {
    final seen = <String>{};
    var nodes = 0;
    final path = <(int, int)>[];
    final cur = List<bool>.from(present);
    var left = cur.where((p) => p).length;

    String key() {
      final sb = StringBuffer();
      var word = 0, bits = 0;
      for (final p in cur) {
        word = (word << 1) | (p ? 1 : 0);
        if (++bits == 30) {
          sb.write(word.toRadixString(36));
          sb.write(',');
          word = 0;
          bits = 0;
        }
      }
      sb.write(word.toRadixString(36));
      return sb.toString();
    }

    int blocks(int s) {
      var n = 0;
      for (final i in layout.blocks(s)) {
        if (cur[i]) n++;
      }
      return n;
    }

    bool dfs() {
      if (left == 0) return true;
      if (++nodes > nodeBudget) return false;
      if (!seen.add(key())) return false;
      final ms = moves(layout, faces, cur);
      if (ms.isEmpty) return false;
      // Groups whose remaining tiles are all free are safe to clear first.
      final remainingByGroup = <int, int>{};
      final freeByGroup = <int, int>{};
      for (var i = 0; i < layout.length; i++) {
        if (!cur[i]) continue;
        final g = MahjongFaces.group(faces[i]);
        remainingByGroup[g] = (remainingByGroup[g] ?? 0) + 1;
        if (layout.isFree(i, cur)) freeByGroup[g] = (freeByGroup[g] ?? 0) + 1;
      }
      int score((int, int) m) {
        final g = MahjongFaces.group(faces[m.$1]);
        final safe = remainingByGroup[g] == freeByGroup[g] ? 1000 : 0;
        return safe + (blocks(m.$1) + blocks(m.$2)) * 10 + layout.slots[m.$1].z + layout.slots[m.$2].z;
      }

      final scored = [for (final m in ms) (m, score(m))]..sort((x, y) => y.$2 - x.$2);
      for (final (m, s) in scored) {
        cur[m.$1] = false;
        cur[m.$2] = false;
        left -= 2;
        path.add(m);
        if (dfs()) return true;
        path.removeLast();
        cur[m.$1] = true;
        cur[m.$2] = true;
        left += 2;
        if (s >= 1000) return false; // a safe move failing means no other will do better
        if (nodes > nodeBudget) return false;
      }
      return false;
    }

    return dfs() ? List.unmodifiable(path) : null;
  }
}

/// A Mahjong Solitaire game.
final class MahjongGame extends PuzzleBase<MahjongState, MahjongAction> {
  MahjongGame._(this.config, super.initial, {super.history}) : layout = MahjongLayout.of(config.layout);

  /// Deals a new solvable game.
  factory MahjongGame(MahjongConfig config) {
    final layout = MahjongLayout.of(config.layout);
    final rng = SeededRng(config.seed);
    var pairs = MahjongFaces.fullPairs();
    rng.shuffle(pairs);
    pairs = pairs.sublist(0, layout.length ~/ 2);
    final slots = List<int>.generate(layout.length, (i) => i);
    final deal = MahjongDealer.construct(layout, slots, pairs, rng);
    if (deal == null) throw StateError('mahjong deal failed');
    return MahjongGame._(
      config,
      MahjongState(
        faces: List.unmodifiable(deal.faces),
        present: List.unmodifiable(List<bool>.filled(layout.length, true)),
        rng: rng.state,
        shufflesLeft: config.shuffles,
      ),
    );
  }

  factory MahjongGame.fromJson(Map<String, Object?> json) {
    checkKind(json, PuzzleKind.mahjong);
    return MahjongGame._(
      MahjongConfig.fromJson(jsonObject(json['config'])),
      MahjongState.fromJson(jsonObject(json['state'])),
      history: jsonHistory(json, MahjongState.fromJson),
    );
  }

  final MahjongConfig config;
  final MahjongLayout layout;

  @override
  PuzzleKind get kind => PuzzleKind.mahjong;

  bool isFree(int slot) => layout.isFree(slot, state.present);

  /// Free matching pairs available now.
  List<(int, int)> availableMoves() => MahjongDealer.moves(layout, state.faces, state.present);

  bool get isStuck => !isSolved && availableMoves().isEmpty;

  @override
  MahjongState? transition(MahjongState s, MahjongAction a) {
    switch (a.type) {
      case MahjongActionType.remove:
        final n = layout.length;
        if (a.a == a.b || a.a < 0 || a.b < 0 || a.a >= n || a.b >= n) return null;
        if (!layout.isFree(a.a, s.present) || !layout.isFree(a.b, s.present)) return null;
        if (!MahjongFaces.matches(s.faces[a.a], s.faces[a.b])) return null;
        final present = List<bool>.from(s.present)
          ..[a.a] = false
          ..[a.b] = false;
        return MahjongState(
          faces: s.faces,
          present: List.unmodifiable(present),
          rng: s.rng,
          shufflesLeft: s.shufflesLeft,
          moves: s.moves + 1,
        );
      case MahjongActionType.shuffle:
        if (s.shufflesLeft <= 0 || s.remaining == 0) return null;
        final rng = SeededRng.fromState(s.rng);
        final slots = [
          for (var i = 0; i < layout.length; i++)
            if (s.present[i]) i,
        ];
        // Re-pair the remaining faces by matching group.
        final byGroup = <int, List<int>>{};
        for (final i in slots) {
          (byGroup[MahjongFaces.group(s.faces[i])] ??= []).add(s.faces[i]);
        }
        final pairs = <(int, int)>[];
        for (final fs in byGroup.values) {
          for (var k = 0; k + 1 < fs.length; k += 2) {
            pairs.add((fs[k], fs[k + 1]));
          }
        }
        final dealt = MahjongDealer.construct(layout, slots, pairs, rng);
        if (dealt == null) return null;
        final faces = List<int>.from(s.faces);
        for (final i in slots) {
          faces[i] = dealt.faces[i];
        }
        return MahjongState(
          faces: List.unmodifiable(faces),
          present: s.present,
          rng: rng.state,
          shufflesLeft: s.shufflesLeft - 1,
          moves: s.moves + 1,
        );
    }
  }

  @override
  bool get isSolved => !state.present.contains(true);

  @override
  bool get isOver => isSolved || (isStuck && state.shufflesLeft == 0);

  /// The first move of a clearing sequence found by search (`solver`), a
  /// heuristic pair when the search budget runs out (`heuristic`), or a
  /// shuffle when stuck (`shuffle`).
  @override
  PuzzleHint<MahjongAction>? hint({int nodeBudget = 20000}) {
    if (isSolved) return null;
    final s = state;
    final ms = availableMoves();
    if (ms.isEmpty) {
      return s.shufflesLeft > 0 ? const PuzzleHint(MahjongAction.shuffle(), technique: 'shuffle') : null;
    }
    final path = MahjongDealer.solve(layout, s.faces, s.present, nodeBudget: nodeBudget);
    if (path != null && path.isNotEmpty) {
      final m = path.first;
      return PuzzleHint(MahjongAction.remove(m.$1, m.$2), technique: 'solver', focus: [m.$1, m.$2]);
    }
    final m = ms.first;
    return PuzzleHint(MahjongAction.remove(m.$1, m.$2), technique: 'heuristic', focus: [m.$1, m.$2]);
  }

  @override
  Map<String, Object?> configJson() => config.toJson();
}
