/// Blackjack 21 (بلاك جاك ٢١): options, moves, hands and the serialisable
/// table state.
///
/// One to three seats play against one dealer (الموزّع), whose play is fixed
/// and happens inside `apply`. Results are kept as a points tally: nothing is
/// put up before a deal and no amount changes hands. `const
/// BlackjackOptions()` is the Madar default (`BlackjackOptions.jordan()`):
/// the standard international table rules, six packs, dealer stands on
/// soft 17, the dealer peeks for a natural. See RULES.md.
library;

import '../core/card_game.dart';
import '../core/card_rng.dart';
import '../core/deck.dart';
import '../core/determinize.dart' show cardsMinus;
import '../core/playing_card.dart';

/// The registry id of this game: `CardGameId.blackjack` once it is added to
/// the enum in `core/card_game.dart`. Until then the state reports the first
/// id of the enum; its JSON always says `blackjack`.
final CardGameId blackjackGameId = CardGameId.values.firstWhere(
  (g) => g.name == BlackjackState.gameKey,
  orElse: () => CardGameId.values.first,
);

/// When the dealer's second card arrives (B-21, B-25).
enum BlackjackHoleCard {
  /// Face down at the deal; with an ace or a 10-value up card the dealer
  /// checks it for a natural before anyone acts (default).
  peek,

  /// The dealer gets a second card only after every seat has finished.
  europeanNoHoleCard,
}

/// Which two-card hands may double (B-33).
enum BlackjackDoubleOn {
  /// Any first two cards, hard or soft (default).
  any,

  /// Hard 9, 10 and 11 only.
  nineToEleven,
}

enum BlackjackSurrender {
  /// Never (default).
  off,

  /// First decision on the original two-card hand, after the peek (B-40).
  late,
}

/// How hand results add up (B-62).
enum BlackjackTally {
  /// Wins add, losses take away (default).
  net,

  /// Only wins add; a lost hand scores 0.
  winsOnly,
}

/// The strategy hint (B-75).
enum BlackjackAdvisor {
  off,

  /// A hint button (default).
  onRequest,

  /// After every decision that differs from the chart, the engine reports
  /// the recommended action (event `adviceGiven`).
  coach,
}

class BlackjackOptions {
  const BlackjackOptions({
    this.decks = 6,
    this.penetration = 0.75,
    this.burnCard = true,
    this.continuousShuffle = false,
    this.holeCard = BlackjackHoleCard.peek,
    this.originalOnly = false,
    this.dealerHitsSoft17 = false,
    this.blackjackBonus = 3,
    this.doubleOn = BlackjackDoubleOn.any,
    this.doubleAfterSplit = true,
    this.maxHands = 4,
    this.splitTensByRankOnly = false,
    this.resplitAces = false,
    this.hitSplitAces = false,
    this.surrender = BlackjackSurrender.off,
    this.autoStandOn21 = true,
    this.tally = BlackjackTally.net,
    this.sessionRounds = 20,
    this.seats = 1,
    this.advisor = BlackjackAdvisor.onRequest,
  }) : assert(decks >= 1 && decks <= 8),
       assert(penetration >= 0.5 && penetration <= 0.85),
       assert(blackjackBonus == 2 || blackjackBonus == 3),
       assert(maxHands >= 2 && maxHands <= 4),
       assert(seats >= 1 && seats <= 3),
       assert(sessionRounds == null || sessionRounds > 0);

  /// The Madar default, identical to `const BlackjackOptions()`: the
  /// standard international rules as people in Jordan meet them in apps,
  /// with results kept as points only.
  const BlackjackOptions.jordan({int seats = 1, int? sessionRounds = 20})
    : this(seats: seats, sessionRounds: sessionRounds);

  /// The European table: no hole card, so a dealer natural found after the
  /// players have acted takes every hand's full value (B-25); surrender is
  /// never available there.
  const BlackjackOptions.european({int seats = 1, int? sessionRounds = 20, bool originalOnly = false})
    : this(
        seats: seats,
        sessionRounds: sessionRounds,
        holeCard: BlackjackHoleCard.europeanNoHoleCard,
        originalOnly: originalOnly,
      );

  factory BlackjackOptions.fromJson(Map<String, Object?> j) => BlackjackOptions(
    decks: j['decks']! as int,
    penetration: (j['penetration']! as num).toDouble(),
    burnCard: j['burnCard']! as bool,
    continuousShuffle: j['continuousShuffle']! as bool,
    holeCard: BlackjackHoleCard.values.byName(j['holeCard']! as String),
    originalOnly: j['originalOnly']! as bool,
    dealerHitsSoft17: j['dealerHitsSoft17']! as bool,
    blackjackBonus: j['blackjackBonus']! as int,
    doubleOn: BlackjackDoubleOn.values.byName(j['doubleOn']! as String),
    doubleAfterSplit: j['doubleAfterSplit']! as bool,
    maxHands: j['maxHands']! as int,
    splitTensByRankOnly: j['splitTensByRankOnly']! as bool,
    resplitAces: j['resplitAces']! as bool,
    hitSplitAces: j['hitSplitAces']! as bool,
    surrender: BlackjackSurrender.values.byName(j['surrender']! as String),
    autoStandOn21: j['autoStandOn21']! as bool,
    tally: BlackjackTally.values.byName(j['tally']! as String),
    sessionRounds: j['sessionRounds'] as int?,
    seats: j['seats']! as int,
    advisor: BlackjackAdvisor.values.byName(j['advisor']! as String),
  );

  /// Packs in the shoe (B-1): 1, 2, 4, 6 or 8.
  final int decks;

  /// Share of the shoe dealt before the reshuffle (B-2), 0.50–0.85.
  final double penetration;

  /// One unseen card to the discards after every shuffle (B-3).
  final bool burnCard;

  /// Every card is shuffled back before every round (B-4); no burn.
  final bool continuousShuffle;
  final BlackjackHoleCard holeCard;

  /// European table only: a dealer natural costs each seat one base result
  /// (−2) however many hands it split into or doubled (B-25, B-61g).
  final bool originalOnly;

  /// H17: the dealer hits a soft 17 (B-52). Off: the dealer stands (S17).
  final bool dealerHitsSoft17;

  /// Points for a natural: 3 (the 3 : 2 ratio of a normal win of 2) or 2.
  final int blackjackBonus;
  final BlackjackDoubleOn doubleOn;

  /// Double a two-card hand made by a split (never split aces) (B-34).
  final bool doubleAfterSplit;

  /// Most hands one seat may hold after splits (B-36): 2, 3 or 4.
  final int maxHands;

  /// Off: any two 10-value cards (K + Q) split. On: identical ranks only.
  final bool splitTensByRankOnly;
  final bool resplitAces;

  /// Split aces may take more cards (they never double).
  final bool hitSplitAces;
  final BlackjackSurrender surrender;

  /// Any 21 stands by itself (B-31).
  final bool autoStandOn21;
  final BlackjackTally tally;

  /// Rounds in a session: 10, 20, 50, or null for an endless session that
  /// ends with the `endSession` move (B-64).
  final int? sessionRounds;

  /// Seats at the table, 1–3. Which of them are people and which are AI
  /// (easy / medium / hard) is the table screen's choice.
  final int seats;
  final BlackjackAdvisor advisor;

  bool get european => holeCard == BlackjackHoleCard.europeanNoHoleCard;

  /// Late surrender exists only with a peek (B-25, B-40).
  bool get surrenderAllowed => surrender == BlackjackSurrender.late && !european;

  /// The per-seat rule applies only on the European table.
  bool get originalOnlyApplies => european && originalOnly;

  /// Cards in a full shoe.
  int get shoeSize => decks * 52;

  /// The shoe is reshuffled before a round when it holds fewer cards than
  /// this (78 of 312 at the default 75 %).
  int get reshuffleBelow => ((1 - penetration) * shoeSize).round();

  BlackjackOptions copyWith({
    int? decks,
    double? penetration,
    bool? burnCard,
    bool? continuousShuffle,
    BlackjackHoleCard? holeCard,
    bool? originalOnly,
    bool? dealerHitsSoft17,
    int? blackjackBonus,
    BlackjackDoubleOn? doubleOn,
    bool? doubleAfterSplit,
    int? maxHands,
    bool? splitTensByRankOnly,
    bool? resplitAces,
    bool? hitSplitAces,
    BlackjackSurrender? surrender,
    bool? autoStandOn21,
    BlackjackTally? tally,
    int? sessionRounds,
    bool endless = false,
    int? seats,
    BlackjackAdvisor? advisor,
  }) => BlackjackOptions(
    decks: decks ?? this.decks,
    penetration: penetration ?? this.penetration,
    burnCard: burnCard ?? this.burnCard,
    continuousShuffle: continuousShuffle ?? this.continuousShuffle,
    holeCard: holeCard ?? this.holeCard,
    originalOnly: originalOnly ?? this.originalOnly,
    dealerHitsSoft17: dealerHitsSoft17 ?? this.dealerHitsSoft17,
    blackjackBonus: blackjackBonus ?? this.blackjackBonus,
    doubleOn: doubleOn ?? this.doubleOn,
    doubleAfterSplit: doubleAfterSplit ?? this.doubleAfterSplit,
    maxHands: maxHands ?? this.maxHands,
    splitTensByRankOnly: splitTensByRankOnly ?? this.splitTensByRankOnly,
    resplitAces: resplitAces ?? this.resplitAces,
    hitSplitAces: hitSplitAces ?? this.hitSplitAces,
    surrender: surrender ?? this.surrender,
    autoStandOn21: autoStandOn21 ?? this.autoStandOn21,
    tally: tally ?? this.tally,
    sessionRounds: endless ? null : (sessionRounds ?? this.sessionRounds),
    seats: seats ?? this.seats,
    advisor: advisor ?? this.advisor,
  );

  Map<String, Object?> toJson() => {
    'decks': decks,
    'penetration': penetration,
    'burnCard': burnCard,
    'continuousShuffle': continuousShuffle,
    'holeCard': holeCard.name,
    'originalOnly': originalOnly,
    'dealerHitsSoft17': dealerHitsSoft17,
    'blackjackBonus': blackjackBonus,
    'doubleOn': doubleOn.name,
    'doubleAfterSplit': doubleAfterSplit,
    'maxHands': maxHands,
    'splitTensByRankOnly': splitTensByRankOnly,
    'resplitAces': resplitAces,
    'hitSplitAces': hitSplitAces,
    'surrender': surrender.name,
    'autoStandOn21': autoStandOn21,
    'tally': tally.name,
    'sessionRounds': sessionRounds,
    'seats': seats,
    'advisor': advisor.name,
  };

  @override
  bool operator ==(Object other) =>
      other is BlackjackOptions && _jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

bool _jsonEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

/// What a seat can do. `deal` (وزّع) starts a round and belongs to seat 0;
/// `endSession` ends an endless session between rounds.
enum BlackjackAction { deal, hit, stand, double, split, surrender, endSession }

final class BlackjackMove extends CardMove {
  const BlackjackMove(this.action);

  factory BlackjackMove.fromJson(Map<String, Object?> j) =>
      BlackjackMove(BlackjackAction.values.byName(j['a']! as String));

  static const deal = BlackjackMove(BlackjackAction.deal);
  static const hit = BlackjackMove(BlackjackAction.hit);
  static const stand = BlackjackMove(BlackjackAction.stand);
  static const doubleHand = BlackjackMove(BlackjackAction.double);
  static const split = BlackjackMove(BlackjackAction.split);
  static const surrender = BlackjackMove(BlackjackAction.surrender);
  static const endSession = BlackjackMove(BlackjackAction.endSession);

  final BlackjackAction action;

  @override
  Map<String, Object?> toJson() => {'a': action.name};

  @override
  bool operator ==(Object other) => other is BlackjackMove && other.action == action;

  @override
  int get hashCode => action.hashCode;

  @override
  String toString() => 'Blackjack(${action.name})';
}

/// How one hand ended (B-55…B-61).
enum BlackjackOutcome {
  /// A natural that won (+3, or +2 with `blackjackBonus: 2`).
  blackjack,
  win,
  push,

  /// Lost, busted included (see [BlackjackHand.bust]).
  loss,

  /// Given up for half a loss (−1).
  surrendered,
}

/// Blackjack value of one card (B-10): 2–10 face value, J Q K 10, ace 1
/// (the hand total decides whether it counts 11).
int blackjackCardValue(PlayingCard c) => switch (c.rank) {
  Rank.ace => 1,
  Rank.jack || Rank.queen || Rank.king => 10,
  _ => c.rank.value,
};

/// Total and softness of [cards] (B-11).
({int total, bool soft}) blackjackTotal(List<PlayingCard> cards) {
  var sum = 0;
  var ace = false;
  for (final c in cards) {
    final v = blackjackCardValue(c);
    sum += v;
    if (v == 1) ace = true;
  }
  if (ace && sum + 10 <= 21) return (total: sum + 10, soft: true);
  return (total: sum, soft: false);
}

/// Ace plus a 10-value card as two cards (whether it counts as a natural
/// also depends on the hand not coming from a split, B-12).
bool isTwoCardTwentyOne(List<PlayingCard> cards) =>
    cards.length == 2 && blackjackTotal(cards).total == 21;

/// One player hand.
class BlackjackHand {
  BlackjackHand({
    List<PlayingCard>? cards,
    this.doubled = false,
    this.fromSplit = false,
    this.splitAces = false,
    this.done = false,
    this.surrendered = false,
    this.outcome,
    this.points = 0,
  }) : cards = cards ?? <PlayingCard>[];

  factory BlackjackHand.fromJson(Map<String, Object?> j) => BlackjackHand(
    cards: cardsFromJson(j['cards']),
    doubled: j['doubled']! as bool,
    fromSplit: j['fromSplit']! as bool,
    splitAces: j['splitAces']! as bool,
    done: j['done']! as bool,
    surrendered: j['surrendered']! as bool,
    outcome: j['outcome'] == null ? null : BlackjackOutcome.values.byName(j['outcome']! as String),
    points: j['points']! as int,
  );

  List<PlayingCard> cards;

  /// Took exactly one card after doubling; its result counts twice.
  bool doubled;
  bool fromSplit;

  /// Made by splitting aces (one card each, B-38).
  bool splitAces;

  /// No more decisions on this hand.
  bool done;
  bool surrendered;

  /// Set when the hand is settled (a bust, a natural or a surrender at
  /// once, everything else after the dealer).
  BlackjackOutcome? outcome;

  /// The hand's points in the tally (valid once [outcome] is set).
  int points;

  int get total => blackjackTotal(cards).total;
  bool get soft => blackjackTotal(cards).soft;
  bool get bust => total > 21;

  /// A natural: ace + 10-value as the first two cards, not from a split.
  bool get natural => !fromSplit && isTwoCardTwentyOne(cards);

  bool get settled => outcome != null;

  BlackjackHand copy() => BlackjackHand(
    cards: List.of(cards),
    doubled: doubled,
    fromSplit: fromSplit,
    splitAces: splitAces,
    done: done,
    surrendered: surrendered,
    outcome: outcome,
    points: points,
  );

  Map<String, Object?> toJson() => {
    'cards': cardsToJson(cards),
    'doubled': doubled,
    'fromSplit': fromSplit,
    'splitAces': splitAces,
    'done': done,
    'surrendered': surrendered,
    'outcome': outcome?.name,
    'points': points,
  };
}

/// One seat: its hands this round and its session record (B-62…B-65).
class BlackjackSeat {
  BlackjackSeat({
    List<BlackjackHand>? hands,
    this.points = 0,
    this.handsWon = 0,
    this.handsLost = 0,
    this.handsPushed = 0,
    this.blackjacks = 0,
    this.busts = 0,
    this.doublesWon = 0,
    this.splits = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.decisions = 0,
    this.decisionsMatched = 0,
  }) : hands = hands ?? <BlackjackHand>[];

  factory BlackjackSeat.fromJson(Map<String, Object?> j) => BlackjackSeat(
    hands: [for (final h in j['hands']! as List) BlackjackHand.fromJson((h as Map).cast<String, Object?>())],
    points: j['points']! as int,
    handsWon: j['handsWon']! as int,
    handsLost: j['handsLost']! as int,
    handsPushed: j['handsPushed']! as int,
    blackjacks: j['blackjacks']! as int,
    busts: j['busts']! as int,
    doublesWon: j['doublesWon']! as int,
    splits: j['splits']! as int,
    streak: j['streak']! as int,
    bestStreak: j['bestStreak']! as int,
    decisions: j['decisions']! as int,
    decisionsMatched: j['decisionsMatched']! as int,
  );

  List<BlackjackHand> hands;

  /// The session tally.
  int points;
  int handsWon;
  int handsLost;
  int handsPushed;
  int blackjacks;
  int busts;
  int doublesWon;
  int splits;

  /// Rounds in a row with a positive net result (a zero round leaves it).
  int streak;
  int bestStreak;

  /// Decisions made and how many matched the strategy chart (B-75).
  int decisions;
  int decisionsMatched;

  int get handsPlayed => handsWon + handsLost + handsPushed;

  /// Share of decisions that matched the chart (1.0 before any decision).
  double get accuracy => decisions == 0 ? 1.0 : decisionsMatched / decisions;

  BlackjackSeat copy() => BlackjackSeat(
    hands: [for (final h in hands) h.copy()],
    points: points,
    handsWon: handsWon,
    handsLost: handsLost,
    handsPushed: handsPushed,
    blackjacks: blackjacks,
    busts: busts,
    doublesWon: doublesWon,
    splits: splits,
    streak: streak,
    bestStreak: bestStreak,
    decisions: decisions,
    decisionsMatched: decisionsMatched,
  );

  Map<String, Object?> toJson() => {
    'hands': [for (final h in hands) h.toJson()],
    'points': points,
    'handsWon': handsWon,
    'handsLost': handsLost,
    'handsPushed': handsPushed,
    'blackjacks': blackjacks,
    'busts': busts,
    'doublesWon': doublesWon,
    'splits': splits,
    'streak': streak,
    'bestStreak': bestStreak,
    'decisions': decisions,
    'decisionsMatched': decisionsMatched,
  };
}

/// The last finished round, for the summary strip.
class BlackjackRoundSummary {
  const BlackjackRoundSummary({
    required this.round,
    required this.seatPoints,
    required this.dealerTotal,
    required this.dealerBlackjack,
    required this.dealerBust,
  });

  factory BlackjackRoundSummary.fromJson(Map<String, Object?> j) => BlackjackRoundSummary(
    round: j['round']! as int,
    seatPoints: (j['seatPoints']! as List).cast<int>().toList(),
    dealerTotal: j['dealerTotal']! as int,
    dealerBlackjack: j['dealerBlackjack']! as bool,
    dealerBust: j['dealerBust']! as bool,
  );

  /// 1-based round number.
  final int round;

  /// Points each seat scored this round (tally rules applied).
  final List<int> seatPoints;
  final int dealerTotal;
  final bool dealerBlackjack;
  final bool dealerBust;

  Map<String, Object?> toJson() => {
    'round': round,
    'seatPoints': seatPoints,
    'dealerTotal': dealerTotal,
    'dealerBlackjack': dealerBlackjack,
    'dealerBust': dealerBust,
  };
}

enum BlackjackPhase {
  /// Waiting for seat 0 to deal (or to end an endless session).
  betweenRounds,

  /// A seat is playing its hand [BlackjackState.handIndex].
  playerTurn,

  /// The session is over.
  over,
}

class BlackjackState extends CardGameState {
  BlackjackState({
    required this.options,
    required this.rng,
    required this.phase,
    required this.shoe,
    required this.discards,
    required this.dealer,
    required this.holeHidden,
    required this.seats,
    required this.turn,
    required this.handIndex,
    required this.roundsPlayed,
    required this.dealNumber,
    required this.lastRound,
  });

  /// A new session: the shoe is shuffled (and a card burned); seat 0 deals
  /// the first round with the `deal` move.
  factory BlackjackState.newMatch({BlackjackOptions options = const BlackjackOptions(), required int seed}) {
    final s = BlackjackState._empty(options, CardRng(seed));
    final deck = buildDeck(copies: options.decks);
    s.rng.shuffle(deck);
    s.shoe = deck;
    if (options.burnCard && !options.continuousShuffle) s.discards.add(s.shoe.removeLast());
    return s;
  }

  /// A table built by hand (tests): the shoe gives [drawOrder] first, in
  /// that order. With [fillRest] the other cards of the full shoe follow
  /// (in pack order) so every card is somewhere; without it the shoe holds
  /// only [drawOrder]. [discards] start the discard pile. Later shuffles
  /// come from [seed].
  factory BlackjackState.custom({
    BlackjackOptions options = const BlackjackOptions(),
    required List<PlayingCard> drawOrder,
    List<PlayingCard> discards = const [],
    bool fillRest = true,
    int seed = 0,
  }) {
    final s = BlackjackState._empty(options, CardRng(seed));
    final rest = fillRest
        ? cardsMinus(buildDeck(copies: options.decks), [...drawOrder, ...discards])
        : <PlayingCard>[];
    // The next card is the last one.
    s.shoe = [...rest.reversed, ...drawOrder.reversed];
    s.discards.addAll(discards);
    return s;
  }

  factory BlackjackState._empty(BlackjackOptions options, CardRng rng) => BlackjackState(
    options: options,
    rng: rng,
    phase: BlackjackPhase.betweenRounds,
    shoe: [],
    discards: [],
    dealer: [],
    holeHidden: false,
    seats: [for (var i = 0; i < options.seats; i++) BlackjackSeat()],
    turn: 0,
    handIndex: 0,
    roundsPlayed: 0,
    dealNumber: 0,
    lastRound: null,
  );

  factory BlackjackState.fromJson(Map<String, Object?> j) => BlackjackState(
    options: BlackjackOptions.fromJson((j['options']! as Map).cast<String, Object?>()),
    rng: CardRng.fromJson(j['rng']),
    phase: BlackjackPhase.values.byName(j['phase']! as String),
    shoe: cardsFromJson(j['shoe']),
    discards: cardsFromJson(j['discards']),
    dealer: cardsFromJson(j['dealer']),
    holeHidden: j['holeHidden']! as bool,
    seats: [for (final s in j['seats']! as List) BlackjackSeat.fromJson((s as Map).cast<String, Object?>())],
    turn: j['turn']! as int,
    handIndex: j['handIndex']! as int,
    roundsPlayed: j['roundsPlayed']! as int,
    dealNumber: j['dealNumber']! as int,
    lastRound: j['lastRound'] == null
        ? null
        : BlackjackRoundSummary.fromJson((j['lastRound']! as Map).cast<String, Object?>()),
  );

  /// The `game` key of the JSON (and the future `CardGameId` name).
  static const String gameKey = 'blackjack';

  final BlackjackOptions options;
  CardRng rng;
  BlackjackPhase phase;

  /// Undealt cards; the next card is the last one.
  List<PlayingCard> shoe;

  /// Played and burned cards, waiting for the next shuffle.
  List<PlayingCard> discards;

  /// The dealer's cards: the up card first, then the hole card (hidden while
  /// [holeHidden]) and any cards drawn.
  List<PlayingCard> dealer;
  bool holeHidden;
  List<BlackjackSeat> seats;

  /// Seat to act while [phase] is `playerTurn`.
  int turn;

  /// Hand of [turn] being played.
  int handIndex;

  /// Rounds settled so far this session.
  int roundsPlayed;
  @override
  int dealNumber;
  BlackjackRoundSummary? lastRound;

  @override
  CardGameId get gameId => blackjackGameId;

  @override
  int get playerCount => options.seats;

  @override
  int? get currentPlayer => switch (phase) {
    BlackjackPhase.over => null,
    BlackjackPhase.betweenRounds => 0,
    BlackjackPhase.playerTurn => turn,
  };

  @override
  bool get isOver => phase == BlackjackPhase.over;

  /// Each seat's points tally.
  @override
  List<int> get scores => [for (final s in seats) s.points];

  /// Higher points; ties go to more hands won, then more naturals, then
  /// fewer busts; seats still equal share the win (B-67). A single seat is
  /// always listed (see [soloSessionWon]).
  @override
  List<int> get winners {
    if (!isOver) return const [];
    int cmp(BlackjackSeat a, BlackjackSeat b) {
      if (a.points != b.points) return a.points.compareTo(b.points);
      if (a.handsWon != b.handsWon) return a.handsWon.compareTo(b.handsWon);
      if (a.blackjacks != b.blackjacks) return a.blackjacks.compareTo(b.blackjacks);
      return b.busts.compareTo(a.busts);
    }

    var best = seats.first;
    for (final s in seats) {
      if (cmp(s, best) > 0) best = s;
    }
    return [
      for (var i = 0; i < seats.length; i++)
        if (cmp(seats[i], best) == 0) i,
    ];
  }

  /// A solo session counts as won when it ends above zero (stats only).
  bool get soloSessionWon => isOver && seats.first.points > 0;

  /// The dealer's up card (null between sessions' first deal).
  PlayingCard? get upCard => dealer.isEmpty ? null : dealer.first;

  /// The dealer's cards as the players see them (the hole card left out
  /// while it is face down).
  List<PlayingCard> get dealerVisible => holeHidden ? dealer.sublist(0, 1) : List.of(dealer);

  /// The hand being played, if any.
  BlackjackHand? get activeHand =>
      phase == BlackjackPhase.playerTurn ? seats[turn].hands[handIndex] : null;

  /// The active hand may take a card (B-30, B-38).
  bool get canHit {
    final h = activeHand;
    if (h == null || h.done || h.doubled) return false;
    return !h.splitAces || options.hitSplitAces;
  }

  /// First decision on a two-card hand (B-33, B-34); never on split aces.
  bool get canDouble {
    final h = activeHand;
    if (h == null || h.done || h.doubled || h.cards.length != 2 || h.splitAces) return false;
    if (h.fromSplit && !options.doubleAfterSplit) return false;
    if (options.doubleOn == BlackjackDoubleOn.nineToEleven) {
      final t = blackjackTotal(h.cards);
      return !t.soft && t.total >= 9 && t.total <= 11;
    }
    return true;
  }

  /// Two cards of equal value while the seat holds fewer than `maxHands`
  /// hands (B-35, B-36, B-38).
  bool get canSplit {
    final h = activeHand;
    if (h == null || h.done || h.doubled || h.cards.length != 2) return false;
    if (seats[turn].hands.length >= options.maxHands) return false;
    final a = h.cards[0];
    final b = h.cards[1];
    final v = blackjackCardValue(a);
    if (v != blackjackCardValue(b)) return false;
    if (v == 10 && options.splitTensByRankOnly && a.rank != b.rank) return false;
    if (v == 1 && h.splitAces && !options.resplitAces) return false;
    return true;
  }

  /// Late surrender: first decision on the original two-card hand, never on
  /// the European table (B-40, B-25).
  bool get canSurrender {
    final h = activeHand;
    if (h == null || !options.surrenderAllowed || h.done || h.doubled) return false;
    return !h.fromSplit && seats[turn].hands.length == 1 && h.cards.length == 2;
  }

  /// True when the next `deal` shuffles every card first (B-2, B-4).
  bool get needsReshuffle => options.continuousShuffle || shoe.length < options.reshuffleBelow;

  @override
  List<PlayingCard> cardsInPlay() => [
    ...shoe,
    ...discards,
    ...dealer,
    for (final s in seats)
      for (final h in s.hands) ...h.cards,
  ];

  @override
  List<PlayingCard> fullDeck() => buildDeck(copies: options.decks);

  @override
  BlackjackState copy() => BlackjackState(
    options: options,
    rng: rng.copy(),
    phase: phase,
    shoe: List.of(shoe),
    discards: List.of(discards),
    dealer: List.of(dealer),
    holeHidden: holeHidden,
    seats: [for (final s in seats) s.copy()],
    turn: turn,
    handIndex: handIndex,
    roundsPlayed: roundsPlayed,
    dealNumber: dealNumber,
    lastRound: lastRound,
  );

  @override
  Map<String, Object?> toJson() => {
    'game': gameKey,
    'options': options.toJson(),
    'rng': rng.toJson(),
    'phase': phase.name,
    'shoe': cardsToJson(shoe),
    'discards': cardsToJson(discards),
    'dealer': cardsToJson(dealer),
    'holeHidden': holeHidden,
    'seats': [for (final s in seats) s.toJson()],
    'turn': turn,
    'handIndex': handIndex,
    'roundsPlayed': roundsPlayed,
    'dealNumber': dealNumber,
    'lastRound': lastRound?.toJson(),
  };
}
