/// Rummy family (Hand هاند, Konkan كونكان): moves, round results and the
/// serialisable match state. The options are in rummy_options.dart
/// (re-exported here).
library;

import '../core/card_game.dart';
import '../core/card_rng.dart';
import '../core/deck.dart';
import '../core/playing_card.dart';
import 'rummy_meld.dart';
import 'rummy_options.dart';

export 'rummy_options.dart';

enum RummyPhase {
  /// After the deal, a seat dealt enough identical pairs decides whether to
  /// cancel the deal (option `pairsRedeal`).
  redealOffer,

  /// The seat to act draws from the stock or takes the top discard.
  draw,

  /// Lay-downs, then a discard that ends the turn.
  play,
  over,
}

enum RummyMoveKind {
  drawStock,
  takeDiscard,

  /// A closed player's first lay-down (several melds, at least the opening
  /// minimum).
  open,

  /// One more meld after opening.
  meld,
  layoff,

  /// Natural card(s) in place of a table wild, which goes to the hand.
  swapJoker,
  discard,

  /// A closed player lays down every card but one and discards it, in one
  /// move (no opening minimum when `oneTurnFinishWaivesThreshold`).
  finish,

  /// Cancel the deal (identical pairs), same dealer deals again.
  callRedeal,

  /// Keep the dealt hand.
  keepHand,
}

/// One lay-off inside a [RummyMove.finish], applied in order.
class RummyLayoff {
  const RummyLayoff(this.card, this.target, {this.atLow = false});

  factory RummyLayoff.fromJson(Object? json) {
    final j = json! as List;
    return RummyLayoff(PlayingCard.parse(j[0]! as String), j[1]! as int, atLow: j.length > 2 && j[2] == true);
  }

  final PlayingCard card;

  /// Index of the table meld.
  final int target;

  /// A wild goes to the low end of a run (else the high end when free).
  final bool atLow;

  List<Object?> toJson() => [card.id, target, if (atLow) true];

  @override
  bool operator ==(Object other) =>
      other is RummyLayoff && other.card == card && other.target == target && other.atLow == atLow;

  @override
  int get hashCode => Object.hash(card, target, atLow);

  @override
  String toString() => '$card→$target${atLow ? '↓' : ''}';
}

final class RummyMove extends CardMove {
  const RummyMove._(
    this.kind, {
    this.card,
    this.card2,
    this.target,
    this.melds = const [],
    this.lows = const [],
    this.atLow = false,
    this.layoffs = const [],
  });

  const RummyMove.drawStock() : this._(RummyMoveKind.drawStock);

  const RummyMove.takeDiscard() : this._(RummyMoveKind.takeDiscard);

  /// First lay-down: several melds at once (their total must reach the
  /// opening minimum). `wildLow[i]` puts the end wild of run `melds[i]` at
  /// its low end (default: the high end when it is free).
  factory RummyMove.open(List<List<PlayingCard>> melds, {List<bool>? wildLow}) {
    final (ms, ls) = _canon(melds, wildLow);
    return RummyMove._(RummyMoveKind.open, melds: ms, lows: ls);
  }

  /// One more meld after opening.
  factory RummyMove.meld(List<PlayingCard> cards, {bool wildLow = false}) {
    final (ms, ls) = _canon([cards], [wildLow]);
    return RummyMove._(RummyMoveKind.meld, melds: ms, lows: ls);
  }

  /// Adds [card] to table meld [target] ([atLow]: a wild at the low end of
  /// a run).
  const RummyMove.layoff(PlayingCard card, int target, {bool atLow = false})
    : this._(RummyMoveKind.layoff, card: card, target: target, atLow: atLow);

  /// Puts [card] (and [card2], for a set of two naturals and a wild that
  /// needs both missing suits) in place of the wild of table meld [target]
  /// and takes the wild.
  factory RummyMove.swapJoker(PlayingCard card, int target, {PlayingCard? card2}) {
    final swapped = card2 != null && card2.code < card.code;
    return RummyMove._(
      RummyMoveKind.swapJoker,
      card: swapped ? card2 : card,
      card2: swapped ? card : card2,
      target: target,
    );
  }

  const RummyMove.discard(PlayingCard card) : this._(RummyMoveKind.discard, card: card);

  /// Goes out in one turn from a closed hand: [melds], then [layoffs] on
  /// table melds, then [discard] (the last card).
  factory RummyMove.finish({
    required List<List<PlayingCard>> melds,
    List<bool>? wildLow,
    List<RummyLayoff> layoffs = const [],
    required PlayingCard discard,
  }) {
    final (ms, ls) = _canon(melds, wildLow);
    return RummyMove._(RummyMoveKind.finish, melds: ms, lows: ls, layoffs: List.unmodifiable(layoffs), card: discard);
  }

  const RummyMove.callRedeal() : this._(RummyMoveKind.callRedeal);

  const RummyMove.keepHand() : this._(RummyMoveKind.keepHand);

  factory RummyMove.fromJson(Map<String, Object?> j) {
    final melds = j['m'] == null ? const <List<PlayingCard>>[] : handsFromJson(j['m']);
    final lows = j['lo'] == null ? List.filled(melds.length, false) : (j['lo']! as List).cast<bool>().toList();
    return RummyMove._(
      RummyMoveKind.values.byName(j['k']! as String),
      card: j['c'] == null ? null : PlayingCard.parse(j['c']! as String),
      card2: j['c2'] == null ? null : PlayingCard.parse(j['c2']! as String),
      target: j['t'] as int?,
      melds: melds,
      lows: melds.isEmpty ? const [] : lows,
      atLow: j['a'] == true,
      layoffs: j['l'] == null ? const [] : [for (final l in j['l']! as List) RummyLayoff.fromJson(l)],
    );
  }

  static (List<List<PlayingCard>>, List<bool>) _canon(List<List<PlayingCard>> melds, List<bool>? wildLow) {
    final pairs = [
      for (var i = 0; i < melds.length; i++)
        (sortedCards(melds[i]), wildLow != null && i < wildLow.length && wildLow[i]),
    ];
    String key((List<PlayingCard>, bool) p) => '${p.$1.map((c) => c.code).join(',')}${p.$2 ? '^' : ''}';
    pairs.sort((a, b) => key(a).compareTo(key(b)));
    return ([for (final p in pairs) p.$1], [for (final p in pairs) p.$2]);
  }

  final RummyMoveKind kind;

  /// The card laid off, swapped in or discarded (the discard of a finish).
  final PlayingCard? card;

  /// The second natural of a two-card swap.
  final PlayingCard? card2;
  final int? target;

  /// The melds laid down (open, meld, finish), each sorted.
  final List<List<PlayingCard>> melds;

  /// Per meld: its end wild goes to the low end.
  final List<bool> lows;

  /// Lay-off of a wild at the low end of a run.
  final bool atLow;

  /// The lay-offs of a finish.
  final List<RummyLayoff> layoffs;

  List<PlayingCard> get meldCards => [for (final m in melds) ...m];

  bool lowAt(int i) => i < lows.length && lows[i];

  @override
  Map<String, Object?> toJson() => {
    'k': kind.name,
    if (card != null) 'c': card!.id,
    if (card2 != null) 'c2': card2!.id,
    if (target != null) 't': target,
    if (melds.isNotEmpty) 'm': handsToJson(melds),
    if (lows.any((x) => x)) 'lo': lows,
    if (atLow) 'a': true,
    if (layoffs.isNotEmpty) 'l': [for (final l in layoffs) l.toJson()],
  };

  String get _meldKey =>
      [for (var i = 0; i < melds.length; i++) '${melds[i].map((c) => c.code).join(',')}${lowAt(i) ? '^' : ''}']
          .join('|');

  @override
  bool operator ==(Object other) =>
      other is RummyMove &&
      other.kind == kind &&
      other.card == card &&
      other.card2 == card2 &&
      other.target == target &&
      other.atLow == atLow &&
      other._meldKey == _meldKey &&
      other.layoffs.length == layoffs.length &&
      Iterable<int>.generate(layoffs.length).every((i) => other.layoffs[i] == layoffs[i]);

  @override
  int get hashCode => Object.hash(kind, card, card2, target, atLow, _meldKey, Object.hashAll(layoffs));

  @override
  String toString() =>
      'Rummy(${kind.name} ${card ?? ''}${card2 == null ? '' : '+$card2'}${target == null ? '' : '→$target'}'
      '${atLow ? '↓' : ''}${melds.isEmpty ? '' : ' $melds'}${lows.any((x) => x) ? ' lows $lows' : ''}'
      '${layoffs.isEmpty ? '' : ' $layoffs'})';
}

class RummyRoundResult {
  const RummyRoundResult({
    required this.winner,
    required this.handFinish,
    required this.points,
    List<int>? seatPoints,
    this.counted = true,
    this.multiplier = 1,
    this.eliminated = const [],
  }) : seatPoints = seatPoints ?? points;

  factory RummyRoundResult.fromJson(Map<String, Object?> j) {
    final points = (j['points']! as List).cast<int>().toList();
    return RummyRoundResult(
      winner: j['winner'] as int?,
      handFinish: j['handFinish']! as bool,
      points: points,
      seatPoints: j['seatPoints'] == null ? points : (j['seatPoints']! as List).cast<int>().toList(),
      counted: j['counted'] as bool? ?? true,
      multiplier: j['multiplier'] as int? ?? 1,
      eliminated: j['eliminated'] == null ? const [] : (j['eliminated']! as List).cast<int>().toList(),
    );
  }

  /// Null for a void round (stock exhausted).
  final int? winner;

  /// A full hand (هاند / كونكان): gone out in one turn from a closed hand
  /// with only new melds of one's own.
  final bool handFinish;

  /// Added to each seat's total (in a partnership both partners get their
  /// team's points).
  final List<int> points;

  /// Each seat's own points (the winner's score, a penalty, 0 for the
  /// winner's partner): what decides the next dealer.
  final List<int> seatPoints;

  /// Counts toward the rounds of the match (a void round does not, unless it
  /// is skipped after repeated voids).
  final bool counted;

  /// Bonus factor of a full hand (option bonuses), 1 otherwise.
  final int multiplier;

  /// Seats eliminated after this round (Konkan).
  final List<int> eliminated;

  Map<String, Object?> toJson() => {
    'winner': winner,
    'handFinish': handFinish,
    'points': points,
    'seatPoints': seatPoints,
    'counted': counted,
    'multiplier': multiplier,
    'eliminated': eliminated,
  };
}

class RummyState extends CardGameState {
  RummyState({
    required this.options,
    required this.rng,
    required this.phase,
    required this.dealer,
    required this.starter,
    required this.dealNumber,
    required this.hands,
    required this.stock,
    required this.discardPile,
    required this.table,
    required this.opened,
    required this.openAtTurnStart,
    required this.tableAtTurnStart,
    required this.usedOldMelds,
    required this.turnsTaken,
    required this.turn,
    required this.mustUse,
    required this.pendingWilds,
    required this.known,
    required this.recycles,
    required this.highestOpening,
    required this.indicator,
    required this.eliminated,
    required this.eliminatedAt,
    required this.voidStreak,
    required this.tieBreakRounds,
    required this.seatScores,
    required this.results,
    required this.over,
  });

  factory RummyState.newMatch({required RummyOptions options, required int seed}) {
    final reason = options.invalidReason;
    if (reason != null) throw ArgumentError.value(options, 'options', reason);
    final s = RummyState._empty(options, CardRng(seed));
    s.dealFromRng();
    return s;
  }

  /// A position built by hand (tests / puzzles). The seat to act is [turn]
  /// in [phase]; [stock] is drawn from the end. By default every seat has
  /// already played a turn ([turnsTaken] 1) and the starter is the seat
  /// after [dealer].
  factory RummyState.custom({
    required RummyOptions options,
    required List<List<PlayingCard>> hands,
    List<PlayingCard> stock = const [],
    List<PlayingCard> discardPile = const [],
    List<Meld> table = const [],
    List<bool>? opened,
    int turn = 0,
    RummyPhase phase = RummyPhase.draw,
    int dealer = 3,
    int? starter,
    List<int>? turnsTaken,
    PlayingCard? indicator,
    List<bool>? eliminated,
    int highestOpening = 0,
    int seed = 0,
  }) {
    final n = options.players;
    final s = RummyState._empty(options, CardRng(seed))
      ..dealer = dealer % n
      ..dealNumber = 1
      ..hands = [for (final h in hands) List.of(h)]
      ..stock = List.of(stock)
      ..discardPile = List.of(discardPile)
      ..table = List.of(table)
      ..opened = opened ?? List.filled(n, false)
      ..turnsTaken = turnsTaken ?? List.filled(n, 1)
      ..indicator = indicator
      ..eliminated = eliminated ?? List.filled(n, false)
      ..highestOpening = highestOpening
      ..turn = turn
      ..phase = phase;
    s.starter = starter ?? s.nextActive(s.dealer);
    s.openAtTurnStart = s.opened[turn];
    s.tableAtTurnStart = s.table.length;
    return s;
  }

  factory RummyState._empty(RummyOptions options, CardRng rng) => RummyState(
    options: options,
    rng: rng,
    phase: RummyPhase.play,
    dealer: options.players - 1,
    starter: 0,
    dealNumber: 0,
    hands: [for (var i = 0; i < options.players; i++) <PlayingCard>[]],
    stock: [],
    discardPile: [],
    table: [],
    opened: List.filled(options.players, false),
    openAtTurnStart: false,
    tableAtTurnStart: 0,
    usedOldMelds: false,
    turnsTaken: List.filled(options.players, 0),
    turn: 0,
    mustUse: null,
    pendingWilds: [],
    known: [for (var i = 0; i < options.players; i++) <PlayingCard>[]],
    recycles: 0,
    highestOpening: 0,
    indicator: null,
    eliminated: List.filled(options.players, false),
    eliminatedAt: List.filled(options.players, 0),
    voidStreak: 0,
    tieBreakRounds: 0,
    seatScores: List.filled(options.players, 0),
    results: [],
    over: false,
  );

  /// Reads [toJson]; saves from before the Jordanian defaults load with the
  /// state they did not store defaulted (everyone has played a turn).
  factory RummyState.fromJson(Map<String, Object?> j) {
    final options = RummyOptions.fromJson((j['options']! as Map).cast<String, Object?>());
    final n = options.players;
    final table = [for (final m in j['table']! as List) Meld.fromJson((m as Map).cast<String, Object?>())];
    final dealer = j['dealer']! as int;
    List<T> list<T>(String key, List<T> fallback) => j[key] == null ? fallback : (j[key]! as List).cast<T>().toList();
    return RummyState(
      options: options,
      rng: CardRng.fromJson(j['rng']),
      phase: RummyPhase.values.byName(j['phase']! as String),
      dealer: dealer,
      starter: j['starter'] as int? ?? (dealer + 1) % n,
      dealNumber: j['dealNumber']! as int,
      hands: handsFromJson(j['hands']),
      stock: cardsFromJson(j['stock']),
      discardPile: cardsFromJson(j['discardPile']),
      table: table,
      opened: (j['opened']! as List).cast<bool>().toList(),
      openAtTurnStart: j['openAtTurnStart']! as bool,
      tableAtTurnStart: j['tableAtTurnStart'] as int? ?? table.length,
      usedOldMelds: j['usedOldMelds'] as bool? ?? false,
      turnsTaken: list('turnsTaken', List.filled(n, 1)),
      turn: j['turn']! as int,
      mustUse: j['mustUse'] == null ? null : PlayingCard.parse(j['mustUse']! as String),
      pendingWilds: j['pendingWilds'] == null ? [] : cardsFromJson(j['pendingWilds']),
      known: handsFromJson(j['known']),
      recycles: j['recycles']! as int,
      highestOpening: j['highestOpening'] as int? ?? 0,
      indicator: j['indicator'] == null ? null : PlayingCard.parse(j['indicator']! as String),
      eliminated: list('eliminated', List.filled(n, false)),
      eliminatedAt: list('eliminatedAt', List.filled(n, 0)),
      voidStreak: j['voidStreak'] as int? ?? 0,
      tieBreakRounds: j['tieBreakRounds'] as int? ?? 0,
      seatScores: (j['seatScores']! as List).cast<int>().toList(),
      results: [for (final r in j['results']! as List) RummyRoundResult.fromJson((r as Map).cast<String, Object?>())],
      over: j['over']! as bool,
    );
  }

  final RummyOptions options;
  CardRng rng;
  RummyPhase phase;
  int dealer;

  /// The seat after the dealer, dealt one card more; its first turn is a
  /// discard.
  int starter;
  @override
  int dealNumber;
  List<List<PlayingCard>> hands;

  /// Face-down stock; the next card is the last one.
  List<PlayingCard> stock;

  /// Discard pile; the top card is the last one.
  List<PlayingCard> discardPile;

  /// Melds on the table (lay-offs and wild swaps change them in place).
  List<Meld> table;
  List<bool> opened;

  /// Whether the seat to act had opened when its turn began.
  bool openAtTurnStart;

  /// Melds on the table when the turn began (the older ones).
  int tableAtTurnStart;

  /// The seat to act laid off on, or swapped from, an older meld this turn.
  bool usedOldMelds;

  /// Turns each seat has finished this round.
  List<int> turnsTaken;
  int turn;

  /// A discard taken this turn that must be melded before discarding.
  PlayingCard? mustUse;

  /// Wilds freed this turn that must be laid down again (option
  /// `swappedWildMustBeUsed`).
  List<PlayingCard> pendingWilds;

  /// Cards publicly known to be in each hand (a taken discard not melded yet,
  /// a wild taken by a swap).
  List<List<PlayingCard>> known;
  int recycles;

  /// Highest opening total this round (option `openingMustBeatPrevious`).
  int highestOpening;

  /// The face-up indicator card of the round (option `wildIndicator`).
  PlayingCard? indicator;

  /// Seats knocked out of the match (Konkan elimination).
  List<bool> eliminated;

  /// Counted round after which each seat was eliminated (0: still in).
  List<int> eliminatedAt;

  /// Void rounds in a row.
  int voidStreak;

  /// Extra rounds played to break a tie for the lowest total.
  int tieBreakRounds;
  List<int> seatScores;
  List<RummyRoundResult> results;
  bool over;

  MeldRules? _rules;
  PlayingCard? _rulesFor;

  /// Wild cards and meld values of the current round.
  MeldRules get meldRules {
    final cached = _rules;
    if (cached != null && _rulesFor == indicator) return cached;
    _rulesFor = indicator;
    return _rules = MeldRules(
      wildAceSuit: indicator == null || indicator!.isJoker || indicator!.rank == Rank.ace ? null : indicator!.suit,
      maxWilds: options.maxWildsPerMeld,
      aceLowValue: options.aceLowOpeningValue,
      aceHighValue: options.aceHighOpeningValue,
      setSwapNeedsBoth: options.setWildSwap == RummySetWildSwap.bothMissing,
    );
  }

  @override
  CardGameId get gameId => options.variant == RummyVariant.hand ? CardGameId.hand : CardGameId.konkan;

  @override
  int get playerCount => options.players;

  @override
  bool get lowerScoreWins => true;

  @override
  int? get currentPlayer => over ? null : turn;

  @override
  bool get isOver => over;

  @override
  List<int> get scores => List.of(seatScores);

  @override
  int teamOf(int seat) => options.partnership ? seat % 2 : seat;

  bool isActive(int seat) => !eliminated[seat];

  List<int> get activeSeats => [
    for (var i = 0; i < playerCount; i++)
      if (!eliminated[i]) i,
  ];

  /// The next seat still in the match after [seat].
  int nextActive(int seat) {
    for (var i = 1; i <= playerCount; i++) {
      final s = (seat + i) % playerCount;
      if (!eliminated[s]) return s;
    }
    return seat;
  }

  @override
  List<int> get winners {
    if (!over) return const [];
    if (options.matchEnd == RummyMatchEnd.elimination) {
      final left = activeSeats;
      if (left.isNotEmpty) return left;
      // Everybody still in crossed together: the lowest of them wins.
      final last = eliminatedAt.reduce((a, b) => a > b ? a : b);
      final group = [
        for (var i = 0; i < playerCount; i++)
          if (eliminatedAt[i] == last) i,
      ];
      final best = group.map((i) => seatScores[i]).reduce((a, b) => a < b ? a : b);
      return [
        for (final i in group)
          if (seatScores[i] == best) i,
      ];
    }
    final best = seatScores.reduce((a, b) => a < b ? a : b);
    return [
      for (var i = 0; i < playerCount; i++)
        if (seatScores[i] == best) i,
    ];
  }

  /// Rounds that count toward the match (void rounds do not).
  int get roundsPlayed => results.where((r) => r.counted).length;

  PlayingCard? get topDiscard => discardPile.isEmpty ? null : discardPile.last;

  /// Penalty of a card left in hand.
  int penaltyOf(PlayingCard c) {
    final r = meldRules;
    if (r.isWild(c)) return options.jokerPenalty;
    final rank = r.rankOf(c);
    if (rank == Rank.ace) return options.acePenalty;
    return rank.value > 10 ? 10 : rank.value;
  }

  int handPenalty(int seat) => hands[seat].fold(0, (a, c) => a + penaltyOf(c));

  /// Whether [seat]'s hand may cancel the deal: four identical pairs, three
  /// and a wild, or two and both wilds.
  bool canCallRedeal(int seat) {
    final r = meldRules;
    var wilds = 0;
    final counts = <int, int>{};
    for (final c in hands[seat]) {
      if (r.isWild(c)) {
        wilds++;
      } else {
        final k = r.suitOf(c).index * 16 + r.rankOf(c).index;
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
    final pairs = counts.values.where((n) => n >= 2).length;
    return pairs >= 4 || (pairs >= 3 && wilds >= 1) || (pairs >= 2 && wilds >= 2);
  }

  /// Deals a round: 14 cards to every seat still in, 15 to the starter (the
  /// next seat after [dealer]), the indicator if used, the rest to the
  /// stock. Then either the redeal offer or the starter's first turn.
  void dealFromRng() {
    final deck = buildDeck(copies: options.decks, jokers: options.jokers);
    rng.shuffle(deck);
    starter = nextActive(dealer);
    hands = [for (var i = 0; i < playerCount; i++) <PlayingCard>[]];
    var seat = starter;
    for (var i = 0; i < activeSeats.length; i++) {
      final n = options.handSize + (seat == starter ? 1 : 0);
      hands[seat] = (deck.sublist(deck.length - n)..sort());
      deck.length -= n;
      seat = nextActive(seat);
    }
    indicator = null;
    if (options.wildIndicator) {
      var card = deck.removeLast();
      while (card.isJoker) {
        deck.insert(deck.length ~/ 2, card);
        card = deck.removeLast();
      }
      indicator = card;
    }
    stock = deck;
    discardPile = [];
    table = [];
    opened = List.filled(playerCount, false);
    known = [for (var i = 0; i < playerCount; i++) <PlayingCard>[]];
    turnsTaken = List.filled(playerCount, 0);
    recycles = 0;
    highestOpening = 0;
    mustUse = null;
    pendingWilds = [];
    usedOldMelds = false;
    tableAtTurnStart = 0;
    openAtTurnStart = false;
    dealNumber++;
    final offer = redealCandidate(after: null);
    turn = offer ?? starter;
    phase = offer == null ? RummyPhase.play : RummyPhase.redealOffer;
  }

  /// The next seat (in turn order from the starter, after [after]) that may
  /// cancel the deal, or null.
  int? redealCandidate({required int? after}) {
    if (!options.pairsRedeal) return null;
    final order = <int>[starter];
    for (var s = nextActive(starter); s != starter; s = nextActive(s)) {
      order.add(s);
    }
    final from = after == null ? 0 : order.indexOf(after) + 1;
    for (var i = from; i < order.length; i++) {
      if (canCallRedeal(order[i])) return order[i];
    }
    return null;
  }

  @override
  List<PlayingCard> cardsInPlay() => [
    for (final h in hands) ...h,
    ...stock,
    ...discardPile,
    for (final m in table) ...m.cards,
    ?indicator,
  ];

  @override
  List<PlayingCard> fullDeck() => buildDeck(copies: options.decks, jokers: options.jokers);

  @override
  RummyState copy() => RummyState(
    options: options,
    rng: rng.copy(),
    phase: phase,
    dealer: dealer,
    starter: starter,
    dealNumber: dealNumber,
    hands: [for (final h in hands) List.of(h)],
    stock: List.of(stock),
    discardPile: List.of(discardPile),
    table: List.of(table),
    opened: List.of(opened),
    openAtTurnStart: openAtTurnStart,
    tableAtTurnStart: tableAtTurnStart,
    usedOldMelds: usedOldMelds,
    turnsTaken: List.of(turnsTaken),
    turn: turn,
    mustUse: mustUse,
    pendingWilds: List.of(pendingWilds),
    known: [for (final k in known) List.of(k)],
    recycles: recycles,
    highestOpening: highestOpening,
    indicator: indicator,
    eliminated: List.of(eliminated),
    eliminatedAt: List.of(eliminatedAt),
    voidStreak: voidStreak,
    tieBreakRounds: tieBreakRounds,
    seatScores: List.of(seatScores),
    results: List.of(results),
    over: over,
  );

  @override
  Map<String, Object?> toJson() => {
    'game': gameId.name,
    'options': options.toJson(),
    'rng': rng.toJson(),
    'phase': phase.name,
    'dealer': dealer,
    'starter': starter,
    'dealNumber': dealNumber,
    'hands': handsToJson(hands),
    'stock': cardsToJson(stock),
    'discardPile': cardsToJson(discardPile),
    'table': [for (final m in table) m.toJson()],
    'opened': opened,
    'openAtTurnStart': openAtTurnStart,
    'tableAtTurnStart': tableAtTurnStart,
    'usedOldMelds': usedOldMelds,
    'turnsTaken': turnsTaken,
    'turn': turn,
    'mustUse': mustUse?.id,
    'pendingWilds': cardsToJson(pendingWilds),
    'known': handsToJson(known),
    'recycles': recycles,
    'highestOpening': highestOpening,
    'indicator': indicator?.id,
    'eliminated': eliminated,
    'eliminatedAt': eliminatedAt,
    'voidStreak': voidStreak,
    'tieBreakRounds': tieBreakRounds,
    'seatScores': seatScores,
    'results': [for (final r in results) r.toJson()],
    'over': over,
  };
}
