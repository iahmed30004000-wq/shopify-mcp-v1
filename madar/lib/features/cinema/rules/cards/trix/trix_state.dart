/// Trix (تركس): options, moves and the serialisable match state.
library;

import '../core/card_game.dart';
import '../core/card_rng.dart';
import '../core/deck.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';

/// The contracts ("games") of a kingdom.
enum TrixContract {
  /// King of hearts (ملك الكبة / الشيخ).
  king,

  /// Queens (البنات).
  queens,

  /// Diamonds (الديناري).
  diamonds,

  /// Collections / tricks (اللطوش).
  ltoush,

  /// The layout game (تركس).
  trix,

  /// Complex (كومبلكس): king, queens, diamonds and ltoush in one deal.
  complex,
}

enum TrixMode {
  /// Five contracts per kingdom: king, queens, diamonds, ltoush, trix.
  classic,

  /// Two contracts per kingdom: complex and trix.
  complex,
}

class TrixOptions {
  const TrixOptions({
    this.partnership = false,
    this.mode = TrixMode.classic,
    this.doubling = true,
    this.kingPenalty = 75,
    this.queenPenalty = 25,
    this.diamondPenalty = 10,
    this.trickPenalty = 15,
    this.trixScores = const [200, 150, 100, 50],
    this.noHeartLeadInKing = true,
    this.kingMustBeDiscarded = true,
    this.firstOwner = 0,
  });

  factory TrixOptions.fromJson(Map<String, Object?> j) => TrixOptions(
    partnership: j['partnership']! as bool,
    mode: TrixMode.values.byName(j['mode']! as String),
    doubling: j['doubling']! as bool,
    kingPenalty: j['kingPenalty']! as int,
    queenPenalty: j['queenPenalty']! as int,
    diamondPenalty: j['diamondPenalty']! as int,
    trickPenalty: j['trickPenalty']! as int,
    trixScores: (j['trixScores']! as List).cast<int>(),
    noHeartLeadInKing: j['noHeartLeadInKing']! as bool,
    kingMustBeDiscarded: j['kingMustBeDiscarded']! as bool,
    firstOwner: j['firstOwner']! as int,
  );

  /// Partners sit opposite and add their scores.
  final bool partnership;
  final TrixMode mode;

  /// The holder of the king of hearts / a queen may double it.
  final bool doubling;
  final int kingPenalty;
  final int queenPenalty;
  final int diamondPenalty;
  final int trickPenalty;

  /// Trix scores by finishing place.
  final List<int> trixScores;

  /// In the king (and complex) contract hearts may not be led while the
  /// leader holds another suit.
  final bool noHeartLeadInKing;

  /// In the king (and complex) contract the holder of K♥ must throw it at
  /// the first trick whose suit they cannot follow.
  final bool kingMustBeDiscarded;

  /// Owner of the first kingdom (then counter-seat order).
  final int firstOwner;

  List<TrixContract> get contracts => mode == TrixMode.classic
      ? const [TrixContract.king, TrixContract.queens, TrixContract.diamonds, TrixContract.ltoush, TrixContract.trix]
      : const [TrixContract.complex, TrixContract.trix];

  Map<String, Object?> toJson() => {
    'partnership': partnership,
    'mode': mode.name,
    'doubling': doubling,
    'kingPenalty': kingPenalty,
    'queenPenalty': queenPenalty,
    'diamondPenalty': diamondPenalty,
    'trickPenalty': trickPenalty,
    'trixScores': trixScores,
    'noHeartLeadInKing': noHeartLeadInKing,
    'kingMustBeDiscarded': kingMustBeDiscarded,
    'firstOwner': firstOwner,
  };
}

enum TrixPhase { contract, doubling, tricks, layout, over }

enum TrixMoveKind { contract, double, play, pass }

final class TrixMove extends CardMove {
  const TrixMove._(this.kind, {this.contract, this.card, this.cards = const []});

  const TrixMove.contract(TrixContract contract) : this._(TrixMoveKind.contract, contract: contract);

  /// Doubles [cards] (possibly none: the "no double" answer).
  TrixMove.double(List<PlayingCard> cards) : this._(TrixMoveKind.double, cards: sortedCards(cards));

  const TrixMove.play(PlayingCard card) : this._(TrixMoveKind.play, card: card);

  const TrixMove.pass() : this._(TrixMoveKind.pass);

  factory TrixMove.fromJson(Map<String, Object?> j) => TrixMove._(
    TrixMoveKind.values.byName(j['k']! as String),
    contract: j['t'] == null ? null : TrixContract.values.byName(j['t']! as String),
    card: j['c'] == null ? null : PlayingCard.parse(j['c']! as String),
    cards: j['cs'] == null ? const [] : cardsFromJson(j['cs']),
  );

  final TrixMoveKind kind;
  final TrixContract? contract;
  final PlayingCard? card;
  final List<PlayingCard> cards;

  @override
  Map<String, Object?> toJson() => {
    'k': kind.name,
    if (contract != null) 't': contract!.name,
    if (card != null) 'c': card!.id,
    if (kind == TrixMoveKind.double) 'cs': cardsToJson(cards),
  };

  @override
  bool operator ==(Object other) =>
      other is TrixMove &&
      other.kind == kind &&
      other.contract == contract &&
      other.card == card &&
      other.cards.length == cards.length &&
      Iterable<int>.generate(cards.length).every((i) => other.cards[i] == cards[i]);

  @override
  int get hashCode => Object.hash(kind, contract, card, Object.hashAll(cards));

  @override
  String toString() => 'Trix(${kind.name} ${contract?.name ?? card ?? cards})';
}

class TrixDealResult {
  const TrixDealResult(this.owner, this.contract, this.points);

  factory TrixDealResult.fromJson(Map<String, Object?> j) => TrixDealResult(
    j['owner']! as int,
    TrixContract.values.byName(j['contract']! as String),
    (j['points']! as List).cast<int>(),
  );

  final int owner;
  final TrixContract contract;

  /// Points per seat.
  final List<int> points;

  Map<String, Object?> toJson() => {'owner': owner, 'contract': contract.name, 'points': points};
}

class TrixState extends CardGameState {
  TrixState({
    required this.options,
    required this.rng,
    required this.phase,
    required this.kingdom,
    required this.owner,
    required this.used,
    required this.dealNumber,
    required this.hands,
    required this.contract,
    required this.turn,
    required this.doubled,
    required this.doublingAnswers,
    required this.trick,
    required this.tricks,
    required this.taken,
    required this.tricksTaken,
    required this.layoutLow,
    required this.layoutHigh,
    required this.layoutCards,
    required this.finished,
    required this.cannotHold,
    required this.seatScores,
    required this.results,
  });

  factory TrixState.newMatch({TrixOptions options = const TrixOptions(), required int seed}) {
    final s = TrixState._empty(options, CardRng(seed));
    s.dealFromRng();
    return s;
  }

  /// A match whose first deal is [hands] (tests / puzzles).
  factory TrixState.withHands(
    List<List<PlayingCard>> hands, {
    TrixOptions options = const TrixOptions(),
    int seed = 0,
  }) {
    final s = TrixState._empty(options, CardRng(seed));
    s.startDeal([for (final h in hands) List.of(h)]);
    return s;
  }

  factory TrixState._empty(TrixOptions options, CardRng rng) => TrixState(
    options: options,
    rng: rng,
    phase: TrixPhase.contract,
    kingdom: 0,
    owner: options.firstOwner,
    used: [],
    dealNumber: 0,
    hands: [for (var i = 0; i < 4; i++) <PlayingCard>[]],
    contract: null,
    turn: options.firstOwner,
    doubled: {},
    doublingAnswers: 0,
    trick: null,
    tricks: [],
    taken: [for (var i = 0; i < 4; i++) <PlayingCard>[]],
    tricksTaken: List.filled(4, 0),
    layoutLow: List.filled(4, 0),
    layoutHigh: List.filled(4, 0),
    layoutCards: [],
    finished: [],
    cannotHold: [for (var i = 0; i < 4; i++) <PlayingCard>{}],
    seatScores: List.filled(4, 0),
    results: [],
  );

  factory TrixState.fromJson(Map<String, Object?> j) => TrixState(
    options: TrixOptions.fromJson((j['options']! as Map).cast<String, Object?>()),
    rng: CardRng.fromJson(j['rng']),
    phase: TrixPhase.values.byName(j['phase']! as String),
    kingdom: j['kingdom']! as int,
    owner: j['owner']! as int,
    used: [for (final u in j['used']! as List) TrixContract.values.byName(u as String)],
    dealNumber: j['dealNumber']! as int,
    hands: handsFromJson(j['hands']),
    contract: j['contract'] == null ? null : TrixContract.values.byName(j['contract']! as String),
    turn: j['turn']! as int,
    doubled: {for (final d in j['doubled']! as List) PlayingCard.parse((d as List)[0] as String): d[1] as int},
    doublingAnswers: j['doublingAnswers']! as int,
    trick: j['trick'] == null ? null : Trick.fromJson((j['trick']! as Map).cast<String, Object?>()),
    tricks: [for (final t in j['tricks']! as List) Trick.fromJson((t as Map).cast<String, Object?>())],
    taken: handsFromJson(j['taken']),
    tricksTaken: (j['tricksTaken']! as List).cast<int>().toList(),
    layoutLow: (j['layoutLow']! as List).cast<int>().toList(),
    layoutHigh: (j['layoutHigh']! as List).cast<int>().toList(),
    layoutCards: cardsFromJson(j['layoutCards']),
    finished: (j['finished']! as List).cast<int>().toList(),
    cannotHold: [for (final h in j['cannotHold']! as List) cardsFromJson(h).toSet()],
    seatScores: (j['seatScores']! as List).cast<int>().toList(),
    results: [for (final r in j['results']! as List) TrixDealResult.fromJson((r as Map).cast<String, Object?>())],
  );

  final TrixOptions options;
  CardRng rng;
  TrixPhase phase;

  /// 0..3; the match ends after the fourth kingdom.
  int kingdom;

  /// Owner of the current kingdom: chooses each contract and leads.
  int owner;

  /// Contracts the owner already played in this kingdom.
  List<TrixContract> used;
  @override
  int dealNumber;
  List<List<PlayingCard>> hands;
  TrixContract? contract;
  int turn;

  /// Doubled card → the seat that doubled it.
  Map<PlayingCard, int> doubled;
  int doublingAnswers;
  Trick? trick;
  List<Trick> tricks;

  /// Cards each seat took in tricks this deal.
  List<List<PlayingCard>> taken;
  List<int> tricksTaken;

  /// Trix layout per suit index: lowest and highest rank value played
  /// (0 while the jack of that suit is not down).
  List<int> layoutLow;
  List<int> layoutHigh;
  List<PlayingCard> layoutCards;

  /// Trix finishing order.
  List<int> finished;

  /// Cards a seat is known not to hold (it passed while they were playable).
  List<Set<PlayingCard>> cannotHold;
  List<int> seatScores;
  List<TrixDealResult> results;

  @override
  CardGameId get gameId => CardGameId.trix;

  @override
  int get playerCount => 4;

  @override
  int? get currentPlayer => phase == TrixPhase.over ? null : turn;

  @override
  bool get isOver => phase == TrixPhase.over;

  @override
  int teamOf(int seat) => options.partnership ? seat % 2 : seat;

  @override
  List<int> get scores => options.partnership
      ? [for (var i = 0; i < 4; i++) seatScores[i % 2] + seatScores[i % 2 + 2]]
      : List.of(seatScores);

  @override
  List<int> get winners {
    if (!isOver) return const [];
    final sc = scores;
    final best = sc.reduce((a, b) => a > b ? a : b);
    return [
      for (var i = 0; i < 4; i++)
        if (sc[i] == best) i,
    ];
  }

  /// Deals played in the match so far.
  int get dealsPlayed => results.length;

  Iterable<PlayingCard> get playedCards sync* {
    for (final t in tricks) {
      yield* t.cards;
    }
    if (trick != null) yield* trick!.cards;
    yield* layoutCards;
  }

  void dealFromRng() {
    final deck = buildDeck();
    rng.shuffle(deck);
    startDeal([for (var i = 0; i < 4; i++) deck.sublist(i * 13, i * 13 + 13)..sort()]);
  }

  void startDeal(List<List<PlayingCard>> newHands) {
    hands = newHands;
    phase = TrixPhase.contract;
    contract = null;
    turn = owner;
    doubled = {};
    doublingAnswers = 0;
    trick = null;
    tricks = [];
    taken = [for (var i = 0; i < 4; i++) <PlayingCard>[]];
    tricksTaken = List.filled(4, 0);
    layoutLow = List.filled(4, 0);
    layoutHigh = List.filled(4, 0);
    layoutCards = [];
    finished = [];
    cannotHold = [for (var i = 0; i < 4; i++) <PlayingCard>{}];
    dealNumber++;
  }

  @override
  List<PlayingCard> cardsInPlay() => [for (final h in hands) ...h, ...playedCards];

  @override
  List<PlayingCard> fullDeck() => buildDeck();

  @override
  TrixState copy() => TrixState(
    options: options,
    rng: rng.copy(),
    phase: phase,
    kingdom: kingdom,
    owner: owner,
    used: List.of(used),
    dealNumber: dealNumber,
    hands: [for (final h in hands) List.of(h)],
    contract: contract,
    turn: turn,
    doubled: Map.of(doubled),
    doublingAnswers: doublingAnswers,
    trick: trick?.copy(),
    tricks: [for (final t in tricks) t.copy()],
    taken: [for (final t in taken) List.of(t)],
    tricksTaken: List.of(tricksTaken),
    layoutLow: List.of(layoutLow),
    layoutHigh: List.of(layoutHigh),
    layoutCards: List.of(layoutCards),
    finished: List.of(finished),
    cannotHold: [for (final c in cannotHold) Set.of(c)],
    seatScores: List.of(seatScores),
    results: List.of(results),
  );

  @override
  Map<String, Object?> toJson() => {
    'game': gameId.name,
    'options': options.toJson(),
    'rng': rng.toJson(),
    'phase': phase.name,
    'kingdom': kingdom,
    'owner': owner,
    'used': [for (final u in used) u.name],
    'dealNumber': dealNumber,
    'hands': handsToJson(hands),
    'contract': contract?.name,
    'turn': turn,
    'doubled': [
      for (final e in doubled.entries) [e.key.id, e.value],
    ],
    'doublingAnswers': doublingAnswers,
    'trick': trick?.toJson(),
    'tricks': [for (final t in tricks) t.toJson()],
    'taken': handsToJson(taken),
    'tricksTaken': tricksTaken,
    'layoutLow': layoutLow,
    'layoutHigh': layoutHigh,
    'layoutCards': cardsToJson(layoutCards),
    'finished': finished,
    'cannotHold': [for (final c in cannotHold) cardsToJson(sortedCards(c))],
    'seatScores': seatScores,
    'results': [for (final r in results) r.toJson()],
  };
}
