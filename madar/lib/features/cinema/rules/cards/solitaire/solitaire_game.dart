/// Solitaire (سوليتير, Klondike): the game a player plays: one deal, the
/// score, the clock, unlimited undo, hints, "stuck" and auto-complete.
///
/// It has the same shape as the puzzles' `PuzzleBase` (apply, undo with
/// 1000 snapshots, hint, isSolved, toJson) without being one, so the card
/// games do not depend on the puzzle registry. Pure Dart, no user-facing
/// text: the UI localises every enum and id. See RULES.md.
library;

import 'dart:math' as math;

import '../core/playing_card.dart';
import 'solitaire_ai.dart';
import 'solitaire_board.dart';
import 'solitaire_options.dart';
import 'solitaire_solver.dart';

/// One thing that happened, in order, for the animations.
class SolitaireEvent {
  const SolitaireEvent(this.type, {this.cards = const [], this.from, this.to, this.points = 0});

  final SolitaireEventType type;
  final List<PlayingCard> cards;
  final SolitairePile? from;
  final SolitairePile? to;

  /// The score line of the event (S-40, S-46, S-47); the score itself never
  /// goes below 0.
  final int points;

  @override
  String toString() => 'SolitaireEvent(${type.name}, $cards, $from→$to, $points)';
}

/// The deal plus everything that changes while it is played.
class SolitaireState {
  SolitaireState({
    required this.board,
    this.score = 0,
    this.moves = 0,
    this.elapsedMs = 0,
    this.timeDeductions = 0,
    this.started = false,
    this.undos = 0,
  });

  factory SolitaireState.fromJson(Map<String, Object?> j) => SolitaireState(
    board: SolitaireBoard.fromPiles(
      columns: handsFromJson(j['columns']),
      faceDown: (j['faceDown']! as List).cast<int>(),
      stock: cardsFromJson(j['stock']),
      waste: cardsFromJson(j['waste']),
      foundations: handsFromJson(j['foundations']),
      recycles: j['recycles']! as int,
    ),
    score: j['score']! as int,
    moves: j['moves']! as int,
    elapsedMs: j['elapsedMs']! as int,
    timeDeductions: j['timeDeductions']! as int,
    started: j['started']! as bool,
    undos: j['undos']! as int,
  );

  final SolitaireBoard board;

  /// Standard score, never below 0 (S-40, S-41).
  int score;

  /// Draws, recycles and card movements, automatic ones included (S-72).
  int moves;

  /// Play time; it starts at the first action (S-45).
  int elapsedMs;

  /// Timed scoring: how many −2 deductions were made (S-46).
  int timeDeductions;
  bool started;
  int undos;

  /// The seven columns, deepest card first.
  List<List<PlayingCard>> get columns => [for (var c = 0; c < 7; c++) board.column(c)];

  /// Face-down cards at the start of each column.
  List<int> get faceDown => [for (var c = 0; c < 7; c++) board.down(c)];

  /// The stock, top card last.
  List<PlayingCard> get stock => board.stock;

  /// The waste, top card last (the UI fans the last three in draw three).
  List<PlayingCard> get waste => board.waste;

  /// The four foundation places, each from the ace up.
  List<List<PlayingCard>> get foundations => [for (var p = 0; p < 4; p++) board.foundation(p)];

  /// Cards home, 0–52 (S-49).
  int get cardsHome => board.cardsHome;
  int get recycles => board.recycles;
  bool get won => board.won;
  Duration get elapsed => Duration(milliseconds: elapsedMs);

  SolitaireState copy() => SolitaireState(
    board: board.copy(),
    score: score,
    moves: moves,
    elapsedMs: elapsedMs,
    timeDeductions: timeDeductions,
    started: started,
    undos: undos,
  );

  Map<String, Object?> toJson() => {
    'columns': handsToJson(columns),
    'faceDown': faceDown,
    'stock': cardsToJson(stock),
    'waste': cardsToJson(waste),
    'foundations': handsToJson(foundations),
    'recycles': recycles,
    'score': score,
    'moves': moves,
    'elapsedMs': elapsedMs,
    'timeDeductions': timeDeductions,
    'started': started,
    'undos': undos,
  };
}

/// One deal of Klondike.
class SolitaireGame {
  SolitaireGame._(this.options, this.seed, this._state, List<SolitaireState> history) : _history = history;

  /// Deal number [seed] (S-4, S-64): the same number gives the same deal on
  /// every device.
  factory SolitaireGame.newDeal({required int seed, SolitaireOptions options = const SolitaireOptions()}) =>
      SolitaireGame._(options, seed, SolitaireState(board: dealBoard(seed)), []);

  /// A position built by hand (tests, puzzles).
  factory SolitaireGame.custom(
    SolitaireBoard board, {
    SolitaireOptions options = const SolitaireOptions(),
    int score = 0,
    int seed = 0,
  }) => SolitaireGame._(options, seed, SolitaireState(board: board, score: score), []);

  factory SolitaireGame.fromJson(Map<String, Object?> json) {
    if (json['kind'] != kind) throw FormatException('Not a solitaire game', json['kind']);
    final config = (json['config']! as Map).cast<String, Object?>();
    return SolitaireGame._(
      SolitaireOptions.fromJson((config['options']! as Map).cast<String, Object?>()),
      config['seed']! as int,
      SolitaireState.fromJson((json['state']! as Map).cast<String, Object?>()),
      [
        for (final h in (json['history'] as List?) ?? const [])
          SolitaireState.fromJson((h as Map).cast<String, Object?>()),
      ],
    );
  }

  /// The S-4 deal of [seed].
  static SolitaireBoard dealBoard(int seed) => SolitaireBoard.forSeed(seed);

  static const String kind = 'solitaire';

  /// Snapshots kept for undo (as `PuzzleBase`).
  static const int undoLimit = 1000;

  final SolitaireOptions options;

  /// The deal number.
  final int seed;
  SolitaireState _state;
  final List<SolitaireState> _history;
  List<SolitaireEvent> _last = const [];

  SolitaireState get state => _state;

  /// What the last successful [apply], [undo] or [advanceClock] did.
  List<SolitaireEvent> get lastEvents => _last;

  /// The score to show, or null with `scoring: none` (S-50).
  int? get displayScore => options.scoring == SolitaireScoring.none ? null : _state.score;

  /// All 52 cards are home (S-30).
  bool get isSolved => _state.won;

  /// A deal ends only with the win (or when the player starts another).
  bool get isOver => _state.won;

  List<SolitaireAction> legalActions() => _state.board.legalActions(options);

  /// Null when [action] is legal, else a stable error id.
  String? validate(SolitaireAction action) => _state.board.check(action, options);

  /// Plays [action]; false (and nothing changes) when it is illegal.
  bool apply(SolitaireAction action) {
    if (validate(action) != null) return false;
    final next = _state.copy()..started = true;
    final events = <SolitaireEvent>[];
    next.board.apply(action, options, (type, cards, from, to, points, isMove) {
      next.score = math.max(0, next.score + points);
      if (isMove) next.moves++;
      events.add(
        SolitaireEvent(type, cards: [for (final c in cards) PlayingCard.fromCode(c)], from: from, to: to, points: points),
      );
    });
    if (next.won) {
      events.add(const SolitaireEvent(SolitaireEventType.won));
      final t = next.elapsedMs ~/ 1000;
      if (options.timedScoring && t >= 30) {
        final bonus = 700000 ~/ t;
        next.score += bonus;
        events.add(SolitaireEvent(SolitaireEventType.timeBonus, points: bonus));
      }
    }
    _history.add(_state);
    if (_history.length > undoLimit) _history.removeAt(0);
    _state = next;
    _last = events;
    return true;
  }

  /// Tap-to-send (S-5, S-10): the move that sends the top card of [from]
  /// (the waste, a column or nothing else) to its foundation, or null.
  SolitaireAction? sendHomeAction(SolitairePile from) {
    final b = _state.board;
    final int card;
    if (from.isWaste) {
      card = b.wasteTop;
    } else if (from.isColumn && b.colLen(from.index) > b.down(from.index)) {
      card = b.at(from.index, b.colLen(from.index) - 1);
    } else {
      return null;
    }
    final place = b.homePlace(card);
    if (place < 0) return null;
    final a = SolitaireAction.move(from, SolitairePile.foundation(place));
    return validate(a) == null ? a : null;
  }

  /// A tap on the stock: draw, or recycle an empty stock (S-22).
  bool tapStock() => apply(_state.board.stockCount > 0 ? SolitaireAction.draw : SolitaireAction.recycle);

  bool get canUndo => _history.isNotEmpty && !_state.won;

  /// S-35: restores the cards, recycles, cards home and move count. The
  /// score comes back too, except the time deductions made since (the clock
  /// is never rewound), minus `undoPenalty`.
  bool undo() {
    if (!canUndo) return false;
    final now = _state;
    final snap = _history.removeLast();
    final back = snap.copy()
      ..elapsedMs = now.elapsedMs
      ..timeDeductions = now.timeDeductions
      ..started = now.started
      ..undos = now.undos + 1;
    back.score = math.max(0, snap.score - 2 * (now.timeDeductions - snap.timeDeductions));
    back.score = math.max(0, back.score - options.undoPenalty);
    _state = back;
    _last = [SolitaireEvent(SolitaireEventType.undone, points: -options.undoPenalty)];
    return true;
  }

  /// The UI's clock tick (S-45, S-46). Time counts only after the first
  /// action and until the win; the UI stops calling while the app is in
  /// the background or paused. Returns the deductions made.
  List<SolitaireEvent> advanceClock(Duration played) {
    if (!_state.started || _state.won || played <= Duration.zero) return const [];
    _state.elapsedMs += played.inMilliseconds;
    final events = <SolitaireEvent>[];
    if (options.timedScoring) {
      final due = (_state.elapsedMs ~/ 1000) ~/ 10;
      while (_state.timeDeductions < due) {
        _state.timeDeductions++;
        _state.score = math.max(0, _state.score - 2);
        events.add(const SolitaireEvent(SolitaireEventType.timePenalty, points: -2));
      }
    }
    if (events.isNotEmpty) _last = events;
    return events;
  }

  /// Auto-complete can be offered (S-32).
  bool get canAutoComplete => _state.board.canAutoComplete(options);

  /// No progress is possible any more (S-31, exact and advisory).
  bool get isStuck => SolitaireSearch.isStuck(_state.board, options);

  /// The suggested next action (S-36, S-37). With `solverHints` in
  /// winnable-deal mode, the solver's plan is followed while the position is
  /// still proved winnable ([SolitaireHint.fromSolver]).
  SolitaireHint hint({int solverBudget = 50000}) {
    if (options.solverHints && options.winnableOnly && !_state.won) {
      final solution = SolitaireSolver(nodeBudget: solverBudget).solve(_state.board, options);
      if (solution.won && solution.plan.isNotEmpty) {
        final a = solution.plan.first;
        return SolitaireHint(a, SolitaireAutoPlayer.techniqueOf(_state.board, a), fromSolver: true);
      }
    }
    return SolitaireAutoPlayer.hint(_state.board, options, level: options.hintLevel);
  }

  Map<String, Object?> toJson() => {
    'kind': kind,
    'v': 1,
    'config': {'seed': seed, 'options': options.toJson()},
    'state': _state.toJson(),
    'history': [for (final s in _history) s.toJson()],
  };
}
