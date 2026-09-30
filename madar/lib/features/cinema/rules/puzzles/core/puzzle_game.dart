/// The uniform interface of the Madar Cinema Tier 2 puzzles.
///
/// Pure Dart: no Flutter imports and no user-facing text. Every enum value
/// and every `technique` id is a stable identifier the UI localises.
library;

/// The puzzles implemented under `rules/puzzles`.
enum PuzzleKind {
  merge2048,
  sudoku,
  minesweeper,
  nonogram,
  mahjong,
  slidingTiles,
  lightsOut,
  pipeConnect,
  tangram,
  starMemory,
  soukJewels,
  fallingBlocks,
}

/// Difficulty shared by every generator.
enum PuzzleDifficulty { easy, medium, hard, expert }

/// A complete immutable snapshot of the mutable part of a puzzle.
abstract class PuzzleState {
  const PuzzleState();

  Map<String, Object?> toJson();
}

/// One player action. Actions are immutable values with structural equality
/// and survive a JSON round trip (used by deterministic replays).
abstract class PuzzleAction {
  const PuzzleAction();

  Map<String, Object?> toJson();
}

/// A suggested next action.
///
/// [technique] is a stable id (e.g. `hiddenSingle`, `safeReveal`) that the UI
/// maps to an explanation; [focus] lists game-specific cell indices worth
/// highlighting alongside the action.
final class PuzzleHint<A extends PuzzleAction> {
  const PuzzleHint(this.action, {this.technique = 'solver', this.focus = const []});

  final A action;
  final String technique;
  final List<int> focus;

  @override
  String toString() => 'PuzzleHint($action, $technique, $focus)';
}

/// The contract every puzzle implements.
abstract interface class PuzzleGame<S extends PuzzleState, A extends PuzzleAction> {
  PuzzleKind get kind;

  /// The current snapshot.
  S get state;

  /// Applies [action]; returns false (and changes nothing) when it is illegal.
  bool apply(A action);

  /// True when the puzzle was completed successfully.
  bool get isSolved;

  /// True when no further progress is possible (solved or lost).
  bool get isOver;

  /// A suggested next action, or null when none is available.
  PuzzleHint<A>? hint();

  bool get canUndo;

  /// Restores the snapshot before the last recorded action.
  bool undo();

  /// Configuration, current state and undo history.
  Map<String, Object?> toJson();
}

/// Shared plumbing: immutable snapshots, a bounded undo stack and JSON.
abstract class PuzzleBase<S extends PuzzleState, A extends PuzzleAction> implements PuzzleGame<S, A> {
  PuzzleBase(S initial, {Iterable<S> history = const [], this.undoLimit = 1000})
    : _state = initial,
      _history = [...history];

  /// Maximum number of snapshots kept for [undo] (0 disables undo).
  final int undoLimit;

  S _state;
  final List<S> _history;

  @override
  S get state => _state;

  /// Computes the snapshot after [action], or null when it is illegal.
  S? transition(S state, A action);

  /// Serialises the immutable configuration (seed, size, givens…).
  Map<String, Object?> configJson();

  /// Replaces the current snapshot without touching the history (used by
  /// subclasses for non-undoable bookkeeping such as elapsed time).
  void replaceState(S next) => _state = next;

  /// Pushes a snapshot onto the undo stack.
  void pushHistory(S snapshot) {
    if (undoLimit <= 0) return;
    _history.add(snapshot);
    if (_history.length > undoLimit) _history.removeAt(0);
  }

  /// The recorded snapshots, oldest first.
  List<S> get history => List<S>.unmodifiable(_history);

  @override
  bool apply(A action) {
    final next = transition(_state, action);
    if (next == null) return false;
    pushHistory(_state);
    _state = next;
    return true;
  }

  @override
  bool get canUndo => _history.isNotEmpty;

  @override
  bool undo() {
    if (_history.isEmpty) return false;
    _state = _history.removeLast();
    return true;
  }

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'v': 1,
    'config': configJson(),
    'state': _state.toJson(),
    'history': [for (final s in _history) s.toJson()],
  };
}

/// Thrown by `fromJson` when the payload belongs to another puzzle.
final class PuzzleFormatException implements Exception {
  const PuzzleFormatException(this.message);
  final String message;

  @override
  String toString() => 'PuzzleFormatException: $message';
}

// ---------------------------------------------------------------------------
// JSON helpers shared by the puzzles.

/// Reads a JSON object.
Map<String, Object?> jsonObject(Object? json) => (json! as Map).cast<String, Object?>();

/// Parses a JSON list of numbers into a `List<int>`.
List<int> jsonInts(Object? json) => json == null ? <int>[] : [for (final v in json as List) (v as num).toInt()];

/// Parses a JSON list of booleans.
List<bool> jsonBools(Object? json) => json == null ? <bool>[] : [for (final v in json as List) v == true];

/// Reads an int field with a default.
int jsonInt(Map<String, Object?> json, String key, [int fallback = 0]) => (json[key] as num?)?.toInt() ?? fallback;

/// Reads the list of history snapshots of [json] through [parse].
List<S> jsonHistory<S>(Map<String, Object?> json, S Function(Map<String, Object?>) parse) => [
  for (final h in (json['history'] as List?) ?? const []) parse(jsonObject(h)),
];

/// Checks the `kind` of a serialised puzzle.
void checkKind(Map<String, Object?> json, PuzzleKind kind) {
  if (json['kind'] != kind.name) {
    throw PuzzleFormatException('expected ${kind.name}, got ${json['kind']}');
  }
}

/// Element-wise list equality.
bool sameList<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Number of set bits of a non-negative int below 2^32.
int bitCount(int v) {
  var x = v & 0xFFFFFFFF;
  x = x - ((x >> 1) & 0x55555555);
  x = (x & 0x33333333) + ((x >> 2) & 0x33333333);
  x = (x + (x >> 4)) & 0x0F0F0F0F;
  x = x + (x >> 8);
  x = x + (x >> 16);
  return x & 0x3F;
}

/// Index of the lowest set bit (v != 0).
int lowestBit(int v) {
  var i = 0;
  while ((v >> i) & 1 == 0) {
    i++;
  }
  return i;
}
