/// Rummy family (Hand هاند, Konkan كونكان): options, moves and state.
library;

import '../core/card_game.dart';
import '../core/card_rng.dart';
import '../core/deck.dart';
import '../core/playing_card.dart';
import 'rummy_meld.dart';

enum RummyVariant { hand, konkan }

/// How a match ends.
enum RummyMatchEnd {
  /// After a fixed number of rounds.
  rounds,

  /// When a player's total reaches the target.
  targetScore,
}

class RummyOptions {
  const RummyOptions({
    required this.variant,
    this.players = 4,
    this.decks = 2,
    this.jokers = 4,
    this.handSize = 14,
    this.openingThreshold = 51,
    this.openingRequiresRun = false,
    this.discardMustBeUsed = true,
    this.winnerScore = -30,
    this.handWinnerScore = -60,
    this.handMultiplier = 2,
    this.notOpenedPenalty = 100,
    this.jokerPenalty = 25,
    this.acePenalty = 11,
    this.jokerSwap = true,
    this.matchEnd = RummyMatchEnd.rounds,
    this.rounds = 5,
    this.targetScore = 500,
    this.maxStockRecycles = 2,
  }) : assert(players >= 2 && players <= 4);

  /// Hand (هاند) as played in Jordan: see RULES.md.
  const RummyOptions.hand({
    int players = 4,
    int rounds = 5,
    int openingThreshold = 51,
    int jokerPenalty = 25,
  }) : this(
         variant: RummyVariant.hand,
         players: players,
         rounds: rounds,
         openingThreshold: openingThreshold,
         jokerPenalty: jokerPenalty,
       );

  /// Konkan (كونكان) as played in Jordan: see RULES.md.
  const RummyOptions.konkan({
    int players = 4,
    RummyMatchEnd matchEnd = RummyMatchEnd.targetScore,
    int targetScore = 500,
    int rounds = 5,
    int openingThreshold = 51,
  }) : this(
         variant: RummyVariant.konkan,
         players: players,
         jokers: 2,
         winnerScore: 0,
         handWinnerScore: 0,
         handMultiplier: 2,
         matchEnd: matchEnd,
         targetScore: targetScore,
         rounds: rounds,
         openingThreshold: openingThreshold,
       );

  factory RummyOptions.fromJson(Map<String, Object?> j) => RummyOptions(
    variant: RummyVariant.values.byName(j['variant']! as String),
    players: j['players']! as int,
    decks: j['decks']! as int,
    jokers: j['jokers']! as int,
    handSize: j['handSize']! as int,
    openingThreshold: j['openingThreshold']! as int,
    openingRequiresRun: j['openingRequiresRun']! as bool,
    discardMustBeUsed: j['discardMustBeUsed']! as bool,
    winnerScore: j['winnerScore']! as int,
    handWinnerScore: j['handWinnerScore']! as int,
    handMultiplier: j['handMultiplier']! as int,
    notOpenedPenalty: j['notOpenedPenalty']! as int,
    jokerPenalty: j['jokerPenalty']! as int,
    acePenalty: j['acePenalty']! as int,
    jokerSwap: j['jokerSwap']! as bool,
    matchEnd: RummyMatchEnd.values.byName(j['matchEnd']! as String),
    rounds: j['rounds']! as int,
    targetScore: j['targetScore']! as int,
    maxStockRecycles: j['maxStockRecycles']! as int,
  );

  final RummyVariant variant;
  final int players;
  final int decks;
  final int jokers;

  /// Cards per player; the first player gets one more and starts by
  /// discarding.
  final int handSize;

  /// Minimum total of a player's first lay-down.
  final int openingThreshold;
  final bool openingRequiresRun;

  /// The top discard may only be taken to be melded at once.
  final bool discardMustBeUsed;

  /// Score of the player who goes out (negative is good).
  final int winnerScore;

  /// … when going out in one turn without having opened before ("hand").
  final int handWinnerScore;

  /// The others' penalties are multiplied by this after a "hand".
  final int handMultiplier;

  /// Penalty of a player who never opened.
  final int notOpenedPenalty;
  final int jokerPenalty;
  final int acePenalty;

  /// An opened player may take a table joker by putting the card it stands
  /// for in its place.
  final bool jokerSwap;
  final RummyMatchEnd matchEnd;
  final int rounds;
  final int targetScore;

  /// Times the discard pile may be reshuffled into an empty stock before
  /// the round is abandoned without score.
  final int maxStockRecycles;

  Map<String, Object?> toJson() => {
    'variant': variant.name,
    'players': players,
    'decks': decks,
    'jokers': jokers,
    'handSize': handSize,
    'openingThreshold': openingThreshold,
    'openingRequiresRun': openingRequiresRun,
    'discardMustBeUsed': discardMustBeUsed,
    'winnerScore': winnerScore,
    'handWinnerScore': handWinnerScore,
    'handMultiplier': handMultiplier,
    'notOpenedPenalty': notOpenedPenalty,
    'jokerPenalty': jokerPenalty,
    'acePenalty': acePenalty,
    'jokerSwap': jokerSwap,
    'matchEnd': matchEnd.name,
    'rounds': rounds,
    'targetScore': targetScore,
    'maxStockRecycles': maxStockRecycles,
  };
}

enum RummyPhase { draw, play, over }

enum RummyMoveKind { drawStock, takeDiscard, open, meld, layoff, swapJoker, discard }

final class RummyMove extends CardMove {
  const RummyMove._(this.kind, {this.card, this.target, this.melds = const []});

  const RummyMove.drawStock() : this._(RummyMoveKind.drawStock);

  const RummyMove.takeDiscard() : this._(RummyMoveKind.takeDiscard);

  /// First lay-down: several melds at once (their total must reach the
  /// opening threshold).
  RummyMove.open(List<List<PlayingCard>> melds) : this._(RummyMoveKind.open, melds: _canon(melds));

  /// One more meld after opening.
  RummyMove.meld(List<PlayingCard> cards) : this._(RummyMoveKind.meld, melds: _canon([cards]));

  /// Adds [card] to table meld [target].
  const RummyMove.layoff(PlayingCard card, int target) : this._(RummyMoveKind.layoff, card: card, target: target);

  /// Puts [card] in place of the joker of table meld [target] and takes it.
  const RummyMove.swapJoker(PlayingCard card, int target)
    : this._(RummyMoveKind.swapJoker, card: card, target: target);

  const RummyMove.discard(PlayingCard card) : this._(RummyMoveKind.discard, card: card);

  factory RummyMove.fromJson(Map<String, Object?> j) => RummyMove._(
    RummyMoveKind.values.byName(j['k']! as String),
    card: j['c'] == null ? null : PlayingCard.parse(j['c']! as String),
    target: j['t'] as int?,
    melds: j['m'] == null ? const [] : handsFromJson(j['m']),
  );

  static List<List<PlayingCard>> _canon(List<List<PlayingCard>> melds) {
    final out = [for (final m in melds) sortedCards(m)];
    out.sort((a, b) => a.map((c) => c.code).join(',').compareTo(b.map((c) => c.code).join(',')));
    return out;
  }

  final RummyMoveKind kind;
  final PlayingCard? card;
  final int? target;
  final List<List<PlayingCard>> melds;

  List<PlayingCard> get meldCards => [for (final m in melds) ...m];

  @override
  Map<String, Object?> toJson() => {
    'k': kind.name,
    if (card != null) 'c': card!.id,
    if (target != null) 't': target,
    if (melds.isNotEmpty) 'm': handsToJson(melds),
  };

  String get _meldKey => melds.map((m) => m.map((c) => c.code).join(',')).join('|');

  @override
  bool operator ==(Object other) =>
      other is RummyMove && other.kind == kind && other.card == card && other.target == target && other._meldKey == _meldKey;

  @override
  int get hashCode => Object.hash(kind, card, target, _meldKey);

  @override
  String toString() => 'Rummy(${kind.name} ${card ?? ''}${target ?? ''}${melds.isEmpty ? '' : melds})';
}

class RummyRoundResult {
  const RummyRoundResult({required this.winner, required this.handFinish, required this.points});

  factory RummyRoundResult.fromJson(Map<String, Object?> j) => RummyRoundResult(
    winner: j['winner'] as int?,
    handFinish: j['handFinish']! as bool,
    points: (j['points']! as List).cast<int>(),
  );

  /// Null for an abandoned round (stock exhausted).
  final int? winner;

  /// The winner went out in one turn without having opened ("hand").
  final bool handFinish;
  final List<int> points;

  Map<String, Object?> toJson() => {'winner': winner, 'handFinish': handFinish, 'points': points};
}

class RummyState extends CardGameState {
  RummyState({
    required this.options,
    required this.rng,
    required this.phase,
    required this.dealer,
    required this.dealNumber,
    required this.hands,
    required this.stock,
    required this.discardPile,
    required this.table,
    required this.opened,
    required this.openAtTurnStart,
    required this.turn,
    required this.mustUse,
    required this.known,
    required this.recycles,
    required this.seatScores,
    required this.results,
    required this.over,
  });

  factory RummyState.newMatch({required RummyOptions options, required int seed}) {
    final s = RummyState._empty(options, CardRng(seed));
    s.dealFromRng();
    return s;
  }

  /// A position built by hand (tests / puzzles). The seat to act is
  /// [turn] in [phase]; [stock] is drawn from the end.
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
    int seed = 0,
  }) {
    final s = RummyState._empty(options, CardRng(seed))
      ..dealer = dealer
      ..dealNumber = 1
      ..hands = [for (final h in hands) List.of(h)]
      ..stock = List.of(stock)
      ..discardPile = List.of(discardPile)
      ..table = List.of(table)
      ..opened = opened ?? List.filled(options.players, false)
      ..turn = turn
      ..phase = phase;
    s.openAtTurnStart = s.opened[turn];
    return s;
  }

  factory RummyState._empty(RummyOptions options, CardRng rng) => RummyState(
    options: options,
    rng: rng,
    phase: RummyPhase.play,
    dealer: options.players - 1,
    dealNumber: 0,
    hands: [for (var i = 0; i < options.players; i++) <PlayingCard>[]],
    stock: [],
    discardPile: [],
    table: [],
    opened: List.filled(options.players, false),
    openAtTurnStart: false,
    turn: 0,
    mustUse: null,
    known: [for (var i = 0; i < options.players; i++) <PlayingCard>[]],
    recycles: 0,
    seatScores: List.filled(options.players, 0),
    results: [],
    over: false,
  );

  factory RummyState.fromJson(Map<String, Object?> j) => RummyState(
    options: RummyOptions.fromJson((j['options']! as Map).cast<String, Object?>()),
    rng: CardRng.fromJson(j['rng']),
    phase: RummyPhase.values.byName(j['phase']! as String),
    dealer: j['dealer']! as int,
    dealNumber: j['dealNumber']! as int,
    hands: handsFromJson(j['hands']),
    stock: cardsFromJson(j['stock']),
    discardPile: cardsFromJson(j['discardPile']),
    table: [for (final m in j['table']! as List) Meld.fromJson((m as Map).cast<String, Object?>())],
    opened: (j['opened']! as List).cast<bool>().toList(),
    openAtTurnStart: j['openAtTurnStart']! as bool,
    turn: j['turn']! as int,
    mustUse: j['mustUse'] == null ? null : PlayingCard.parse(j['mustUse']! as String),
    known: handsFromJson(j['known']),
    recycles: j['recycles']! as int,
    seatScores: (j['seatScores']! as List).cast<int>().toList(),
    results: [for (final r in j['results']! as List) RummyRoundResult.fromJson((r as Map).cast<String, Object?>())],
    over: j['over']! as bool,
  );

  final RummyOptions options;
  CardRng rng;
  RummyPhase phase;
  int dealer;
  @override
  int dealNumber;
  List<List<PlayingCard>> hands;

  /// Face-down stock; the next card is the last one.
  List<PlayingCard> stock;

  /// Discard pile; the top card is the last one.
  List<PlayingCard> discardPile;

  /// Melds on the table (lay-offs and joker swaps change them in place).
  List<Meld> table;
  List<bool> opened;

  /// Whether the seat to act had opened when its turn began.
  bool openAtTurnStart;
  int turn;

  /// A discard taken this turn that must be melded before discarding.
  PlayingCard? mustUse;

  /// Cards publicly known to be in each hand (taken from the discard pile
  /// and not yet melded).
  List<List<PlayingCard>> known;
  int recycles;
  List<int> seatScores;
  List<RummyRoundResult> results;
  bool over;

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
  List<int> get winners {
    if (!over) return const [];
    final best = seatScores.reduce((a, b) => a < b ? a : b);
    return [for (var i = 0; i < playerCount; i++) if (seatScores[i] == best) i];
  }

  int get roundsPlayed => results.length;

  PlayingCard? get topDiscard => discardPile.isEmpty ? null : discardPile.last;

  /// Penalty of a card left in hand.
  int penaltyOf(PlayingCard c) {
    if (c.isJoker) return options.jokerPenalty;
    if (c.rank == Rank.ace) return options.acePenalty;
    return c.rank.value > 10 ? 10 : c.rank.value;
  }

  int handPenalty(int seat) => hands[seat].fold(0, (a, c) => a + penaltyOf(c));

  void dealFromRng() {
    final deck = buildDeck(copies: options.decks, jokers: options.jokers);
    rng.shuffle(deck);
    final first = (dealer + 1) % playerCount;
    hands = [for (var i = 0; i < playerCount; i++) <PlayingCard>[]];
    for (var i = 0; i < playerCount; i++) {
      final seat = (first + i) % playerCount;
      final n = options.handSize + (seat == first ? 1 : 0);
      hands[seat] = (deck.sublist(deck.length - n)..sort());
      deck.length -= n;
    }
    stock = deck;
    discardPile = [];
    table = [];
    opened = List.filled(playerCount, false);
    known = [for (var i = 0; i < playerCount; i++) <PlayingCard>[]];
    recycles = 0;
    mustUse = null;
    turn = first;
    phase = RummyPhase.play;
    openAtTurnStart = false;
    dealNumber++;
  }

  @override
  List<PlayingCard> cardsInPlay() => [
    for (final h in hands) ...h,
    ...stock,
    ...discardPile,
    for (final m in table) ...m.cards,
  ];

  @override
  List<PlayingCard> fullDeck() => buildDeck(copies: options.decks, jokers: options.jokers);

  @override
  RummyState copy() => RummyState(
    options: options,
    rng: rng.copy(),
    phase: phase,
    dealer: dealer,
    dealNumber: dealNumber,
    hands: [for (final h in hands) List.of(h)],
    stock: List.of(stock),
    discardPile: List.of(discardPile),
    table: List.of(table),
    opened: List.of(opened),
    openAtTurnStart: openAtTurnStart,
    turn: turn,
    mustUse: mustUse,
    known: [for (final k in known) List.of(k)],
    recycles: recycles,
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
    'dealNumber': dealNumber,
    'hands': handsToJson(hands),
    'stock': cardsToJson(stock),
    'discardPile': cardsToJson(discardPile),
    'table': [for (final m in table) m.toJson()],
    'opened': opened,
    'openAtTurnStart': openAtTurnStart,
    'turn': turn,
    'mustUse': mustUse?.id,
    'known': handsToJson(known),
    'recycles': recycles,
    'seatScores': seatScores,
    'results': [for (final r in results) r.toJson()],
    'over': over,
  };
}
