/// Star Memory: find the pairs of face-down star cards.
///
/// Rules: flip one card, then a second; a matching pair stays face up,
/// a mismatch stays visible until the next flip (or an explicit `conceal`).
/// A move is one pair of flips. Scoring rewards few moves and little time:
/// `score = pairs × 100 + max(0, par − moves) × 20 − (moves − pairs) × 5 −
/// seconds`, clamped at zero, where `par = 2 × pairs − 1` (the moves a
/// player with perfect memory needs on average, rounded).
library;

import 'dart:math' as math;

import '../core/puzzle_game.dart';
import '../core/seeded_rng.dart';

final class StarMemoryConfig {
  const StarMemoryConfig({this.columns = 4, this.rows = 4, this.seed = 0})
    : assert(columns * rows >= 4 && columns * rows % 2 == 0);

  /// Board sizes: 3×4, 4×4, 4×5 and 6×6.
  factory StarMemoryConfig.forDifficulty(PuzzleDifficulty d, {int seed = 0}) => switch (d) {
    PuzzleDifficulty.easy => StarMemoryConfig(columns: 3, rows: 4, seed: seed),
    PuzzleDifficulty.medium => StarMemoryConfig(columns: 4, rows: 4, seed: seed),
    PuzzleDifficulty.hard => StarMemoryConfig(columns: 4, rows: 5, seed: seed),
    PuzzleDifficulty.expert => StarMemoryConfig(columns: 6, rows: 6, seed: seed),
  };

  final int columns;
  final int rows;
  final int seed;

  int get cards => columns * rows;
  int get pairs => cards ~/ 2;

  Map<String, Object?> toJson() => {'cols': columns, 'rows': rows, 'seed': seed};

  factory StarMemoryConfig.fromJson(Map<String, Object?> j) =>
      StarMemoryConfig(columns: jsonInt(j, 'cols', 4), rows: jsonInt(j, 'rows', 4), seed: jsonInt(j, 'seed'));
}

final class StarMemoryState extends PuzzleState {
  const StarMemoryState({
    required this.faces,
    required this.matched,
    required this.seen,
    this.up = const [],
    this.moves = 0,
    this.elapsedMs = 0,
    this.streak = 0,
    this.bestStreak = 0,
  });

  /// Star id (0..pairs-1) of each card.
  final List<int> faces;
  final List<bool> matched;

  /// Cards that have been face up at least once.
  final List<bool> seen;

  /// Unmatched face-up cards (0, 1 or 2 – two means a pending mismatch).
  final List<int> up;
  final int moves;
  final int elapsedMs;
  final int streak;
  final int bestStreak;

  int get pairsFound => matched.where((m) => m).length ~/ 2;

  StarMemoryState copyWith({
    List<bool>? matched,
    List<bool>? seen,
    List<int>? up,
    int? moves,
    int? elapsedMs,
    int? streak,
    int? bestStreak,
  }) => StarMemoryState(
    faces: faces,
    matched: matched ?? this.matched,
    seen: seen ?? this.seen,
    up: up ?? this.up,
    moves: moves ?? this.moves,
    elapsedMs: elapsedMs ?? this.elapsedMs,
    streak: streak ?? this.streak,
    bestStreak: bestStreak ?? this.bestStreak,
  );

  @override
  Map<String, Object?> toJson() => {
    'faces': faces,
    'matched': [for (final m in matched) m ? 1 : 0],
    'seen': [for (final s in seen) s ? 1 : 0],
    'up': up,
    'moves': moves,
    'ms': elapsedMs,
    'streak': streak,
    'best': bestStreak,
  };

  factory StarMemoryState.fromJson(Map<String, Object?> j) => StarMemoryState(
    faces: List.unmodifiable(jsonInts(j['faces'])),
    matched: List.unmodifiable([for (final v in jsonInts(j['matched'])) v == 1]),
    seen: List.unmodifiable([for (final v in jsonInts(j['seen'])) v == 1]),
    up: List.unmodifiable(jsonInts(j['up'])),
    moves: jsonInt(j, 'moves'),
    elapsedMs: jsonInt(j, 'ms'),
    streak: jsonInt(j, 'streak'),
    bestStreak: jsonInt(j, 'best'),
  );
}

enum StarMemoryActionType { flip, conceal }

final class StarMemoryAction extends PuzzleAction {
  const StarMemoryAction.flip(this.card) : type = StarMemoryActionType.flip;

  /// Turns a pending mismatch face down.
  const StarMemoryAction.conceal() : type = StarMemoryActionType.conceal, card = -1;

  final StarMemoryActionType type;
  final int card;

  @override
  Map<String, Object?> toJson() => {'t': type.name, 'c': card};

  factory StarMemoryAction.fromJson(Map<String, Object?> j) => j['t'] == StarMemoryActionType.conceal.name
      ? const StarMemoryAction.conceal()
      : StarMemoryAction.flip(jsonInt(j, 'c'));

  @override
  bool operator ==(Object other) => other is StarMemoryAction && other.type == type && other.card == card;

  @override
  int get hashCode => Object.hash(type, card);

  @override
  String toString() => 'StarMemoryAction(${type.name}, $card)';
}

/// Score for a finished (or current) game.
int starMemoryScore({required int pairs, required int moves, required int elapsedMs}) {
  final par = 2 * pairs - 1;
  final s = pairs * 100 + math.max(0, par - moves) * 20 - math.max(0, moves - pairs) * 5 - elapsedMs ~/ 1000;
  return math.max(0, s);
}

/// A Star Memory game.
final class StarMemoryGame extends PuzzleBase<StarMemoryState, StarMemoryAction> {
  StarMemoryGame._(this.config, super.initial, {super.history});

  factory StarMemoryGame(StarMemoryConfig config) {
    final faces = [for (var p = 0; p < config.pairs; p++) ...[p, p]];
    SeededRng(config.seed).shuffle(faces);
    final n = faces.length;
    return StarMemoryGame._(
      config,
      StarMemoryState(
        faces: List.unmodifiable(faces),
        matched: List.unmodifiable(List<bool>.filled(n, false)),
        seen: List.unmodifiable(List<bool>.filled(n, false)),
      ),
    );
  }

  factory StarMemoryGame.fromJson(Map<String, Object?> json) {
    checkKind(json, PuzzleKind.starMemory);
    return StarMemoryGame._(
      StarMemoryConfig.fromJson(jsonObject(json['config'])),
      StarMemoryState.fromJson(jsonObject(json['state'])),
      history: jsonHistory(json, StarMemoryState.fromJson),
    );
  }

  final StarMemoryConfig config;

  @override
  PuzzleKind get kind => PuzzleKind.starMemory;

  /// Whether [card] is currently face up.
  bool isFaceUp(int card) => state.matched[card] || state.up.contains(card);

  @override
  StarMemoryState? transition(StarMemoryState s, StarMemoryAction a) {
    if (isSolved) return null;
    switch (a.type) {
      case StarMemoryActionType.conceal:
        if (s.up.length != 2) return null;
        return s.copyWith(up: const []);
      case StarMemoryActionType.flip:
        final c = a.card;
        if (c < 0 || c >= s.faces.length || s.matched[c]) return null;
        var up = s.up;
        if (up.length == 2) up = const []; // a pending mismatch turns down
        if (up.contains(c)) return null;
        final seen = List<bool>.from(s.seen)..[c] = true;
        if (up.isEmpty) {
          return s.copyWith(up: List.unmodifiable([c]), seen: List.unmodifiable(seen));
        }
        final first = up.first;
        final moves = s.moves + 1;
        if (s.faces[first] == s.faces[c]) {
          final matched = List<bool>.from(s.matched)
            ..[first] = true
            ..[c] = true;
          final streak = s.streak + 1;
          return s.copyWith(
            matched: List.unmodifiable(matched),
            seen: List.unmodifiable(seen),
            up: const [],
            moves: moves,
            streak: streak,
            bestStreak: math.max(streak, s.bestStreak),
          );
        }
        return s.copyWith(up: List.unmodifiable([first, c]), seen: List.unmodifiable(seen), moves: moves, streak: 0);
    }
  }

  /// Adds play time (not undoable; the UI calls it from its ticker).
  void addTime(Duration d) => replaceState(state.copyWith(elapsedMs: state.elapsedMs + d.inMilliseconds));

  @override
  bool get isSolved => !state.matched.contains(false);

  @override
  bool get isOver => isSolved;

  int get score => starMemoryScore(pairs: config.pairs, moves: state.moves, elapsedMs: state.elapsedMs);

  /// Uses only what the player has already seen: complete a known pair,
  /// else flip an unseen card (`explore`).
  @override
  PuzzleHint<StarMemoryAction>? hint() {
    if (isSolved) return null;
    final s = state;
    final up = s.up.length == 2 ? const <int>[] : s.up;
    final n = s.faces.length;
    if (up.length == 1) {
      final first = up.first;
      for (var i = 0; i < n; i++) {
        if (i != first && !s.matched[i] && s.seen[i] && s.faces[i] == s.faces[first]) {
          return PuzzleHint(StarMemoryAction.flip(i), technique: 'knownPair', focus: [first, i]);
        }
      }
      for (var i = 0; i < n; i++) {
        if (i != first && !s.matched[i] && !s.seen[i]) {
          return PuzzleHint(StarMemoryAction.flip(i), technique: 'explore', focus: [i]);
        }
      }
    } else {
      for (var i = 0; i < n; i++) {
        if (s.matched[i] || !s.seen[i]) continue;
        for (var j = i + 1; j < n; j++) {
          if (!s.matched[j] && s.seen[j] && s.faces[j] == s.faces[i]) {
            return PuzzleHint(StarMemoryAction.flip(i), technique: 'knownPair', focus: [i, j]);
          }
        }
      }
      for (var i = 0; i < n; i++) {
        if (!s.matched[i] && !s.seen[i]) {
          return PuzzleHint(StarMemoryAction.flip(i), technique: 'explore', focus: [i]);
        }
      }
    }
    // Everything seen: flip any unmatched card whose partner is known.
    for (var i = 0; i < n; i++) {
      if (!s.matched[i] && !up.contains(i)) return PuzzleHint(StarMemoryAction.flip(i), technique: 'knownPair', focus: [i]);
    }
    return null;
  }

  @override
  Map<String, Object?> configJson() => config.toJson();
}
