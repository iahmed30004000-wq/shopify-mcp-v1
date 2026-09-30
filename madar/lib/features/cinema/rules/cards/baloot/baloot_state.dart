/// Baloot (بلوت): options, moves, projects and the serialisable match state.
library;

import '../core/card_game.dart';
import '../core/card_rng.dart';
import '../core/deck.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';

enum BalootMode {
  /// No trumps (صن).
  sun,

  /// Trumps (حكم).
  hokom,
}

class BalootOptions {
  const BalootOptions({
    this.targetScore = 152,
    this.doubling = true,
    this.sunDoubleOnlyWhenBehind = true,
    this.mustTrumpWhenPartnerWinning = true,
    this.mustOvertrump = true,
    this.buyerWinsTies = false,
    this.firstDealer = 3,
  });

  factory BalootOptions.fromJson(Map<String, Object?> j) => BalootOptions(
    targetScore: j['targetScore']! as int,
    doubling: j['doubling']! as bool,
    sunDoubleOnlyWhenBehind: j['sunDoubleOnlyWhenBehind']! as bool,
    mustTrumpWhenPartnerWinning: j['mustTrumpWhenPartnerWinning']! as bool,
    mustOvertrump: j['mustOvertrump']! as bool,
    buyerWinsTies: j['buyerWinsTies']! as bool,
    firstDealer: j['firstDealer']! as int,
  );

  /// 152 (الصكة).
  final int targetScore;

  /// Double → triple → four → gahwa (Hokom); double only (Sun).
  final bool doubling;

  /// Sun may be doubled only when the buyers have more than 100 and the
  /// defenders less than 100.
  final bool sunDoubleOnlyWhenBehind;

  /// A player void in the led suit must trump even when their partner is
  /// winning the trick.
  final bool mustTrumpWhenPartnerWinning;

  /// Must beat the highest trump already in the trick when able.
  final bool mustOvertrump;

  /// A tie between buyers and defenders counts as made (default: failed).
  final bool buyerWinsTies;
  final int firstDealer;

  Map<String, Object?> toJson() => {
    'targetScore': targetScore,
    'doubling': doubling,
    'sunDoubleOnlyWhenBehind': sunDoubleOnlyWhenBehind,
    'mustTrumpWhenPartnerWinning': mustTrumpWhenPartnerWinning,
    'mustOvertrump': mustOvertrump,
    'buyerWinsTies': buyerWinsTies,
    'firstDealer': firstDealer,
  };
}

enum BalootPhase { bidding, doubling, playing, over }

enum BalootMoveKind {
  /// Bidding: pass (بس). Doubling: decline.
  pass,
  hokom,
  sun,

  /// Doubling: double / triple / four / gahwa, by the current level.
  raise,
  play,
}

final class BalootMove extends CardMove {
  const BalootMove._(this.kind, {this.suit, this.card});

  const BalootMove.pass() : this._(BalootMoveKind.pass);

  const BalootMove.hokom(Suit suit) : this._(BalootMoveKind.hokom, suit: suit);

  const BalootMove.sun() : this._(BalootMoveKind.sun);

  const BalootMove.raise() : this._(BalootMoveKind.raise);

  const BalootMove.play(PlayingCard card) : this._(BalootMoveKind.play, card: card);

  factory BalootMove.fromJson(Map<String, Object?> j) => BalootMove._(
    BalootMoveKind.values.byName(j['k']! as String),
    suit: j['s'] == null ? null : Suit.fromCode(j['s']! as String),
    card: j['c'] == null ? null : PlayingCard.parse(j['c']! as String),
  );

  final BalootMoveKind kind;
  final Suit? suit;
  final PlayingCard? card;

  @override
  Map<String, Object?> toJson() => {'k': kind.name, if (suit != null) 's': suit!.code, if (card != null) 'c': card!.id};

  @override
  bool operator ==(Object other) =>
      other is BalootMove && other.kind == kind && other.suit == suit && other.card == card;

  @override
  int get hashCode => Object.hash(kind, suit, card);

  @override
  String toString() => 'Baloot(${kind.name} ${suit?.code ?? card ?? ''})';
}

/// Project (مشروع) types.
enum BalootProjectType {
  /// Three in sequence (سرا).
  sira,

  /// Four in sequence (خمسين).
  fifty,

  /// Five in sequence, or four 10s / Ks / Qs / Js (or aces in Hokom) (مية).
  hundred,

  /// Four aces in Sun (أربعمية).
  fourHundred,
}

/// Natural sequence order used by projects: 7 8 9 10 J Q K A.
int naturalIndex(Rank r) => r == Rank.ace ? 7 : r.value - 7;

class BalootProject {
  const BalootProject(this.type, this.seat, this.cards);

  factory BalootProject.fromJson(Map<String, Object?> j) => BalootProject(
    BalootProjectType.values.byName(j['type']! as String),
    j['seat']! as int,
    cardsFromJson(j['cards']),
  );

  final BalootProjectType type;
  final int seat;
  final List<PlayingCard> cards;

  /// Value in game points (abnat) under [mode].
  int value(BalootMode mode) => switch ((type, mode)) {
    (BalootProjectType.sira, BalootMode.sun) => 4,
    (BalootProjectType.sira, BalootMode.hokom) => 2,
    (BalootProjectType.fifty, BalootMode.sun) => 10,
    (BalootProjectType.fifty, BalootMode.hokom) => 5,
    (BalootProjectType.hundred, BalootMode.sun) => 20,
    (BalootProjectType.hundred, BalootMode.hokom) => 10,
    (BalootProjectType.fourHundred, _) => 40,
  };

  int get topIndex => cards.map((c) => naturalIndex(c.rank)).reduce((a, b) => a > b ? a : b);

  Map<String, Object?> toJson() => {'type': type.name, 'seat': seat, 'cards': cardsToJson(cards)};
}

class BalootRoundResult {
  const BalootRoundResult({
    required this.buyer,
    required this.mode,
    required this.trump,
    required this.raw,
    required this.points,
    required this.level,
    required this.made,
  });

  factory BalootRoundResult.fromJson(Map<String, Object?> j) => BalootRoundResult(
    buyer: j['buyer']! as int,
    mode: BalootMode.values.byName(j['mode']! as String),
    trump: j['trump'] == null ? null : Suit.fromCode(j['trump']! as String),
    raw: (j['raw']! as List).cast<int>(),
    points: (j['points']! as List).cast<int>(),
    level: j['level']! as int,
    made: j['made']! as bool,
  );

  final int buyer;
  final BalootMode mode;
  final Suit? trump;

  /// Card points (incl. last trick) per team.
  final List<int> raw;

  /// Game points per team.
  final List<int> points;

  /// 1 plain, 2 double, 3 triple, 4 four; 5 gahwa.
  final int level;
  final bool made;

  Map<String, Object?> toJson() => {
    'buyer': buyer,
    'mode': mode.name,
    'trump': trump?.code,
    'raw': raw,
    'points': points,
    'level': level,
    'made': made,
  };
}

class BalootState extends CardGameState {
  BalootState({
    required this.options,
    required this.rng,
    required this.phase,
    required this.dealer,
    required this.dealNumber,
    required this.hands,
    required this.stock,
    required this.upCard,
    required this.turnedUp,
    required this.turn,
    required this.bidRound,
    required this.bidQueue,
    required this.mode,
    required this.trump,
    required this.buyer,
    required this.level,
    required this.gahwa,
    required this.doubler,
    required this.doublingQueue,
    required this.trick,
    required this.tricks,
    required this.projects,
    required this.belote,
    required this.teamScores,
    required this.results,
    required this.winnerTeam,
  });

  factory BalootState.newMatch({BalootOptions options = const BalootOptions(), required int seed}) {
    final s = BalootState._empty(options, CardRng(seed), options.firstDealer);
    s.dealFromRng();
    return s;
  }

  /// A deal built by hand: five cards per seat, the turned-up card and the
  /// eleven remaining cards ([stock], drawn from the end).
  factory BalootState.withDeal({
    required List<List<PlayingCard>> hands,
    required PlayingCard upCard,
    required List<PlayingCard> stock,
    BalootOptions options = const BalootOptions(),
    int dealer = 3,
    int seed = 0,
  }) {
    final s = BalootState._empty(options, CardRng(seed), dealer);
    s.startDeal([for (final h in hands) List.of(h)], upCard, List.of(stock));
    return s;
  }

  factory BalootState._empty(BalootOptions options, CardRng rng, int dealer) => BalootState(
    options: options,
    rng: rng,
    phase: BalootPhase.bidding,
    dealer: dealer,
    dealNumber: 0,
    hands: [for (var i = 0; i < 4; i++) <PlayingCard>[]],
    stock: [],
    upCard: null,
    turnedUp: null,
    turn: (dealer + 1) % 4,
    bidRound: 1,
    bidQueue: [],
    mode: null,
    trump: null,
    buyer: -1,
    level: 1,
    gahwa: false,
    doubler: -1,
    doublingQueue: [],
    trick: null,
    tricks: [],
    projects: [],
    belote: -1,
    teamScores: [0, 0],
    results: [],
    winnerTeam: null,
  );

  factory BalootState.fromJson(Map<String, Object?> j) => BalootState(
    options: BalootOptions.fromJson((j['options']! as Map).cast<String, Object?>()),
    rng: CardRng.fromJson(j['rng']),
    phase: BalootPhase.values.byName(j['phase']! as String),
    dealer: j['dealer']! as int,
    dealNumber: j['dealNumber']! as int,
    hands: handsFromJson(j['hands']),
    stock: cardsFromJson(j['stock']),
    upCard: j['upCard'] == null ? null : PlayingCard.parse(j['upCard']! as String),
    turnedUp: j['turnedUp'] == null ? null : PlayingCard.parse(j['turnedUp']! as String),
    turn: j['turn']! as int,
    bidRound: j['bidRound']! as int,
    bidQueue: (j['bidQueue']! as List).cast<int>().toList(),
    mode: j['mode'] == null ? null : BalootMode.values.byName(j['mode']! as String),
    trump: j['trump'] == null ? null : Suit.fromCode(j['trump']! as String),
    buyer: j['buyer']! as int,
    level: j['level']! as int,
    gahwa: j['gahwa']! as bool,
    doubler: j['doubler']! as int,
    doublingQueue: (j['doublingQueue']! as List).cast<int>().toList(),
    trick: j['trick'] == null ? null : Trick.fromJson((j['trick']! as Map).cast<String, Object?>()),
    tricks: [for (final t in j['tricks']! as List) Trick.fromJson((t as Map).cast<String, Object?>())],
    projects: [for (final p in j['projects']! as List) BalootProject.fromJson((p as Map).cast<String, Object?>())],
    belote: j['belote']! as int,
    teamScores: (j['teamScores']! as List).cast<int>().toList(),
    results: [for (final r in j['results']! as List) BalootRoundResult.fromJson((r as Map).cast<String, Object?>())],
    winnerTeam: j['winnerTeam'] as int?,
  );

  final BalootOptions options;
  CardRng rng;
  BalootPhase phase;
  int dealer;
  @override
  int dealNumber;
  List<List<PlayingCard>> hands;

  /// Cards still to be dealt after the auction (drawn from the end).
  List<PlayingCard> stock;

  /// The turned-up card (الورقة المكشوفة) until the buyer takes it.
  PlayingCard? upCard;

  /// The card turned up this deal (public; stays known after the buyer
  /// takes it).
  PlayingCard? turnedUp;
  int turn;

  /// 1 or 2.
  int bidRound;

  /// Seats still to speak in this bidding round, in order.
  List<int> bidQueue;
  BalootMode? mode;
  Suit? trump;

  /// Current (then final) buyer; -1 while nobody bid.
  int buyer;

  /// 1 plain, 2 double, 3 triple, 4 four.
  int level;
  bool gahwa;

  /// The defender who doubled (-1 if none).
  int doubler;
  List<int> doublingQueue;
  Trick? trick;
  List<Trick> tricks;

  /// Declared projects of the deal (all seats; only the best team's count).
  List<BalootProject> projects;

  /// Seat holding K+Q of trumps (belote), or -1.
  int belote;
  List<int> teamScores;
  List<BalootRoundResult> results;
  int? winnerTeam;

  @override
  CardGameId get gameId => CardGameId.baloot;

  @override
  int get playerCount => 4;

  @override
  int teamOf(int seat) => seat % 2;

  @override
  int? get currentPlayer => phase == BalootPhase.over ? null : turn;

  @override
  bool get isOver => phase == BalootPhase.over;

  @override
  List<int> get scores => [teamScores[0], teamScores[1], teamScores[0], teamScores[1]];

  @override
  List<int> get winners => winnerTeam == null ? const [] : [winnerTeam!, winnerTeam! + 2];

  int get firstPlayer => (dealer + 1) % 4;

  /// Projects are public once the first trick is complete.
  bool get projectsRevealed => tricks.isNotEmpty;

  Iterable<PlayingCard> get playedCards sync* {
    for (final t in tricks) {
      yield* t.cards;
    }
    if (trick != null) yield* trick!.cards;
  }

  void dealFromRng() {
    final deck = buildDeck(ranks: balootRanks);
    rng.shuffle(deck);
    final hs = [for (var i = 0; i < 4; i++) deck.sublist(i * 5, i * 5 + 5)..sort()];
    startDeal(hs, deck[20], deck.sublist(21));
  }

  void startDeal(List<List<PlayingCard>> newHands, PlayingCard up, List<PlayingCard> rest) {
    hands = newHands;
    upCard = up;
    turnedUp = up;
    stock = rest;
    phase = BalootPhase.bidding;
    bidRound = 1;
    bidQueue = [for (var i = 0; i < 4; i++) (firstPlayer + i) % 4];
    turn = bidQueue.first;
    mode = null;
    trump = null;
    buyer = -1;
    level = 1;
    gahwa = false;
    doubler = -1;
    doublingQueue = [];
    trick = null;
    tricks = [];
    projects = [];
    belote = -1;
    dealNumber++;
  }

  @override
  List<PlayingCard> cardsInPlay() => [for (final h in hands) ...h, ...stock, ?upCard, ...playedCards];

  @override
  List<PlayingCard> fullDeck() => buildDeck(ranks: balootRanks);

  @override
  BalootState copy() => BalootState(
    options: options,
    rng: rng.copy(),
    phase: phase,
    dealer: dealer,
    dealNumber: dealNumber,
    hands: [for (final h in hands) List.of(h)],
    stock: List.of(stock),
    upCard: upCard,
    turnedUp: turnedUp,
    turn: turn,
    bidRound: bidRound,
    bidQueue: List.of(bidQueue),
    mode: mode,
    trump: trump,
    buyer: buyer,
    level: level,
    gahwa: gahwa,
    doubler: doubler,
    doublingQueue: List.of(doublingQueue),
    trick: trick?.copy(),
    tricks: [for (final t in tricks) t.copy()],
    projects: List.of(projects),
    belote: belote,
    teamScores: List.of(teamScores),
    results: List.of(results),
    winnerTeam: winnerTeam,
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
    'upCard': upCard?.id,
    'turnedUp': turnedUp?.id,
    'turn': turn,
    'bidRound': bidRound,
    'bidQueue': bidQueue,
    'mode': mode?.name,
    'trump': trump?.code,
    'buyer': buyer,
    'level': level,
    'gahwa': gahwa,
    'doubler': doubler,
    'doublingQueue': doublingQueue,
    'trick': trick?.toJson(),
    'tricks': [for (final t in tricks) t.toJson()],
    'projects': [for (final p in projects) p.toJson()],
    'belote': belote,
    'teamScores': teamScores,
    'results': [for (final r in results) r.toJson()],
    'winnerTeam': winnerTeam,
  };
}
