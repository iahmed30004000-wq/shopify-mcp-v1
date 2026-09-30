/// Tarneeb (طرنيب): options, moves and the serialisable match state.
///
/// `const TarneebOptions()` is the game as commonly played in Jordan (see
/// RULES.md): auction 7–13 where a pass is final, the same dealer redeals
/// when all four pass, the bidder names trump and leads, made = the tricks
/// taken, failed = minus the bid and the defenders score their tricks, 13
/// tricks = 16, a bid of 13 = +26 or −16 (defenders double), first to 31.
library;

import '../core/card_game.dart';
import '../core/card_rng.dart';
import '../core/deck.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';

/// What happens when all four players pass.
enum TarneebAllPass {
  /// The cards are thrown in and the **same dealer** deals again (Jordan
  /// default).
  redealSameDealer,

  /// The cards are thrown in and the next dealer deals.
  redealNextDealer,

  /// After three passes the dealer may not pass and must bid.
  dealerTakesMinimum,
}

/// What a bidding team that makes its contract scores.
enum TarneebMadeScore {
  /// The tricks it took (default).
  tricksTaken,

  /// Exactly its bid.
  bid,
}

/// What the defenders score when a contract of 7–12 fails.
enum TarneebFailScore {
  /// The tricks they took (default).
  defendersTricks,

  /// The failed bid.
  bid,

  /// Nothing (the bidders only lose their bid).
  nothing,
}

/// What the defenders score when a bid of 13 fails.
enum TarneebKabootFail {
  /// Twice the tricks they took (default).
  doubled,

  /// The tricks they took.
  single,
}

/// How trumps are decided.
enum TarneebTrumpMode {
  /// The winning bidder names any suit (default).
  bidderChooses,

  /// Syrian style: the dealer's last card is shown to everyone (and stays in
  /// the dealer's hand); trumps are the other suit of the same colour.
  exposedCardSisterSuit,
}

/// The other suit of the same colour: ♥ ↔ ♦, ♠ ↔ ♣.
Suit sisterSuit(Suit s) => switch (s) {
  Suit.hearts => Suit.diamonds,
  Suit.diamonds => Suit.hearts,
  Suit.spades => Suit.clubs,
  Suit.clubs => Suit.spades,
};

class TarneebOptions {
  /// The Jordanian game (every default below).
  const TarneebOptions({
    this.targetScore = 31,
    this.minBid = 7,
    this.passIsFinal = true,
    this.oneRoundAuction = false,
    this.allPass = TarneebAllPass.redealSameDealer,
    this.madeScore = TarneebMadeScore.tricksTaken,
    this.failScore = TarneebFailScore.defendersTricks,
    this.defendersScoreWhenMade = false,
    this.kabootScore = 16,
    this.kabootBidMadeScore = 26,
    this.kabootBidFailPenalty = 16,
    this.kabootFailDefenders = TarneebKabootFail.doubled,
    this.trumpMode = TarneebTrumpMode.bidderChooses,
    this.bidderLeads = true,
    this.firstLeadMustBeTrump = false,
    this.worthlessHandRedeal = false,
    this.loseAtNegativeTarget = false,
    this.firstDealer = 3,
  });

  /// Tarneeb as commonly played in Jordan (the same as `TarneebOptions()`).
  const TarneebOptions.jordan({int targetScore = 31}) : this(targetScore: targetScore);

  /// Syrian trump (طرنيب سوري): the dealer's last card is shown and trumps
  /// are the other suit of its colour; the auction winner only leads.
  const TarneebOptions.syrianTrump({int targetScore = 31})
    : this(targetScore: targetScore, trumpMode: TarneebTrumpMode.exposedCardSisterSuit);

  /// Lebanese auction: everybody speaks once and the dealer, last, may take
  /// the contract by equalling the highest bid.
  const TarneebOptions.lebaneseAuction({int targetScore = 31}) : this(targetScore: targetScore, oneRoundAuction: true);

  /// Open auction: a player who passed may bid again (three passes after a
  /// bid end it) and after three opening passes the dealer must bid 7.
  const TarneebOptions.openAuction({int targetScore = 31})
    : this(targetScore: targetScore, passIsFinal: false, allPass: TarneebAllPass.dealerTakesMinimum);

  /// Missing keys take the defaults; a save from before the Jordanian
  /// defaults (`allTricksScore`, `allPass: redeal`) keeps its old rules.
  factory TarneebOptions.fromJson(Map<String, Object?> j) {
    const d = TarneebOptions();
    final legacyAllTricks = j['kabootScore'] == null ? j['allTricksScore'] as int? : null;
    final allPass = j['allPass'] as String?;
    T pick<T>(String key, T fallback) => (j[key] as T?) ?? fallback;
    return TarneebOptions(
      targetScore: pick('targetScore', d.targetScore),
      minBid: pick('minBid', d.minBid),
      passIsFinal: pick('passIsFinal', d.passIsFinal),
      oneRoundAuction: pick('oneRoundAuction', d.oneRoundAuction),
      allPass: allPass == null
          ? d.allPass
          : allPass == 'redeal'
          ? TarneebAllPass.redealNextDealer
          : TarneebAllPass.values.byName(allPass),
      madeScore: j['madeScore'] == null ? d.madeScore : TarneebMadeScore.values.byName(j['madeScore']! as String),
      failScore: j['failScore'] == null ? d.failScore : TarneebFailScore.values.byName(j['failScore']! as String),
      defendersScoreWhenMade: pick('defendersScoreWhenMade', d.defendersScoreWhenMade),
      kabootScore: legacyAllTricks ?? pick('kabootScore', d.kabootScore),
      kabootBidMadeScore: legacyAllTricks ?? pick('kabootBidMadeScore', d.kabootBidMadeScore),
      kabootBidFailPenalty: legacyAllTricks != null ? 13 : pick('kabootBidFailPenalty', d.kabootBidFailPenalty),
      kabootFailDefenders: legacyAllTricks != null
          ? TarneebKabootFail.single
          : j['kabootFailDefenders'] == null
          ? d.kabootFailDefenders
          : TarneebKabootFail.values.byName(j['kabootFailDefenders']! as String),
      trumpMode: j['trumpMode'] == null ? d.trumpMode : TarneebTrumpMode.values.byName(j['trumpMode']! as String),
      bidderLeads: pick('bidderLeads', d.bidderLeads),
      firstLeadMustBeTrump: pick('firstLeadMustBeTrump', d.firstLeadMustBeTrump),
      worthlessHandRedeal: pick('worthlessHandRedeal', d.worthlessHandRedeal),
      loseAtNegativeTarget: pick('loseAtNegativeTarget', d.loseAtNegativeTarget),
      firstDealer: pick('firstDealer', d.firstDealer),
    );
  }

  /// The match targets offered in the UI (31 is the Jordanian default).
  static const List<int> targetChoices = [31, 41, 61];

  /// 31 by default; 41 and 61 are the longer games.
  final int targetScore;
  final int minBid;

  /// A player who passes may not bid again in that auction.
  final bool passIsFinal;

  /// Everybody speaks exactly once, from the dealer's right; the dealer, who
  /// speaks last, may equal the highest bid and so take the contract.
  final bool oneRoundAuction;
  final TarneebAllPass allPass;
  final TarneebMadeScore madeScore;
  final TarneebFailScore failScore;

  /// Defenders also score their tricks when the contract is made.
  final bool defendersScoreWhenMade;

  /// A bid of 7–12 that takes all 13 tricks (كبوت).
  final int kabootScore;

  /// A bid of 13 that is made.
  final int kabootBidMadeScore;

  /// What the bidders lose when a bid of 13 fails (they score minus this).
  final int kabootBidFailPenalty;

  /// What the defenders score when a bid of 13 fails.
  final TarneebKabootFail kabootFailDefenders;
  final TarneebTrumpMode trumpMode;

  /// The winning bidder leads the first trick (else the dealer's right).
  final bool bidderLeads;

  /// The first lead of the deal must be a trump when the leader has one.
  final bool firstLeadMustBeTrump;

  /// A player whose hand is worthless (no ace, no king with another card of
  /// its suit, no queen in a suit of 3+, no jack in a suit of 4+) may throw
  /// the cards in on their first turn to speak; the next dealer deals.
  final bool worthlessHandRedeal;

  /// A team at or below minus the target after a deal loses the match.
  final bool loseAtNegativeTarget;

  /// Dealer of the first deal; the first bidder is the next seat.
  final int firstDealer;

  TarneebOptions copyWith({
    int? targetScore,
    int? minBid,
    bool? passIsFinal,
    bool? oneRoundAuction,
    TarneebAllPass? allPass,
    TarneebMadeScore? madeScore,
    TarneebFailScore? failScore,
    bool? defendersScoreWhenMade,
    int? kabootScore,
    int? kabootBidMadeScore,
    int? kabootBidFailPenalty,
    TarneebKabootFail? kabootFailDefenders,
    TarneebTrumpMode? trumpMode,
    bool? bidderLeads,
    bool? firstLeadMustBeTrump,
    bool? worthlessHandRedeal,
    bool? loseAtNegativeTarget,
    int? firstDealer,
  }) => TarneebOptions(
    targetScore: targetScore ?? this.targetScore,
    minBid: minBid ?? this.minBid,
    passIsFinal: passIsFinal ?? this.passIsFinal,
    oneRoundAuction: oneRoundAuction ?? this.oneRoundAuction,
    allPass: allPass ?? this.allPass,
    madeScore: madeScore ?? this.madeScore,
    failScore: failScore ?? this.failScore,
    defendersScoreWhenMade: defendersScoreWhenMade ?? this.defendersScoreWhenMade,
    kabootScore: kabootScore ?? this.kabootScore,
    kabootBidMadeScore: kabootBidMadeScore ?? this.kabootBidMadeScore,
    kabootBidFailPenalty: kabootBidFailPenalty ?? this.kabootBidFailPenalty,
    kabootFailDefenders: kabootFailDefenders ?? this.kabootFailDefenders,
    trumpMode: trumpMode ?? this.trumpMode,
    bidderLeads: bidderLeads ?? this.bidderLeads,
    firstLeadMustBeTrump: firstLeadMustBeTrump ?? this.firstLeadMustBeTrump,
    worthlessHandRedeal: worthlessHandRedeal ?? this.worthlessHandRedeal,
    loseAtNegativeTarget: loseAtNegativeTarget ?? this.loseAtNegativeTarget,
    firstDealer: firstDealer ?? this.firstDealer,
  );

  Map<String, Object?> toJson() => {
    'targetScore': targetScore,
    'minBid': minBid,
    'passIsFinal': passIsFinal,
    'oneRoundAuction': oneRoundAuction,
    'allPass': allPass.name,
    'madeScore': madeScore.name,
    'failScore': failScore.name,
    'defendersScoreWhenMade': defendersScoreWhenMade,
    'kabootScore': kabootScore,
    'kabootBidMadeScore': kabootBidMadeScore,
    'kabootBidFailPenalty': kabootBidFailPenalty,
    'kabootFailDefenders': kabootFailDefenders.name,
    'trumpMode': trumpMode.name,
    'bidderLeads': bidderLeads,
    'firstLeadMustBeTrump': firstLeadMustBeTrump,
    'worthlessHandRedeal': worthlessHandRedeal,
    'loseAtNegativeTarget': loseAtNegativeTarget,
    'firstDealer': firstDealer,
  };

  @override
  bool operator ==(Object other) => other is TarneebOptions && _mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

enum TarneebPhase { bidding, trump, playing, over }

enum TarneebMoveKind { bid, pass, trump, play, throwIn }

final class TarneebMove extends CardMove {
  const TarneebMove._(this.kind, {this.amount, this.suit, this.card});

  const TarneebMove.bid(int amount) : this._(TarneebMoveKind.bid, amount: amount);

  const TarneebMove.pass() : this._(TarneebMoveKind.pass);

  const TarneebMove.trump(Suit suit) : this._(TarneebMoveKind.trump, suit: suit);

  const TarneebMove.play(PlayingCard card) : this._(TarneebMoveKind.play, card: card);

  /// Throw a worthless hand in (option `worthlessHandRedeal`).
  const TarneebMove.throwIn() : this._(TarneebMoveKind.throwIn);

  factory TarneebMove.fromJson(Map<String, Object?> j) => TarneebMove._(
    TarneebMoveKind.values.byName(j['k']! as String),
    amount: j['n'] as int?,
    suit: j['s'] == null ? null : Suit.fromCode(j['s']! as String),
    card: j['c'] == null ? null : PlayingCard.parse(j['c']! as String),
  );

  final TarneebMoveKind kind;
  final int? amount;
  final Suit? suit;
  final PlayingCard? card;

  @override
  Map<String, Object?> toJson() => {
    'k': kind.name,
    if (amount != null) 'n': amount,
    if (suit != null) 's': suit!.code,
    if (card != null) 'c': card!.id,
  };

  @override
  bool operator ==(Object other) =>
      other is TarneebMove && other.kind == kind && other.amount == amount && other.suit == suit && other.card == card;

  @override
  int get hashCode => Object.hash(kind, amount, suit, card);

  @override
  String toString() => 'Tarneeb(${kind.name} ${amount ?? suit?.code ?? card ?? ''})';
}

/// One call of the auction (amount 0 = pass).
class TarneebBid {
  const TarneebBid(this.seat, this.amount);

  final int seat;
  final int amount;

  bool get isPass => amount == 0;
}

/// The outcome of one played deal.
class TarneebRoundResult {
  const TarneebRoundResult({
    required this.bidder,
    required this.bid,
    required this.trump,
    required this.tricks,
    required this.points,
  });

  factory TarneebRoundResult.fromJson(Map<String, Object?> j) => TarneebRoundResult(
    bidder: j['bidder']! as int,
    bid: j['bid']! as int,
    trump: Suit.fromCode(j['trump']! as String),
    tricks: (j['tricks']! as List).cast<int>(),
    points: (j['points']! as List).cast<int>(),
  );

  final int bidder;
  final int bid;
  final Suit trump;

  /// Tricks per team (team = seat % 2).
  final List<int> tricks;

  /// Points per team for this deal.
  final List<int> points;

  bool get made => tricks[bidder % 2] >= bid;

  /// The bidding team took all 13 tricks.
  bool get kaboot => tricks[bidder % 2] == 13;

  Map<String, Object?> toJson() => {
    'bidder': bidder,
    'bid': bid,
    'trump': trump.code,
    'tricks': tricks,
    'points': points,
  };
}

class TarneebState extends CardGameState {
  TarneebState({
    required this.options,
    required this.rng,
    required this.phase,
    required this.dealer,
    required this.dealNumber,
    required this.roundNumber,
    required this.hands,
    required this.turn,
    required this.passed,
    required this.bids,
    required this.highBid,
    required this.highBidder,
    required this.consecutivePasses,
    required this.trump,
    required this.trick,
    required this.tricks,
    required this.tricksWon,
    required this.teamScores,
    required this.results,
    required this.winnerTeam,
    this.exposedCard,
  });

  /// A new match; the first deal is dealt from [seed].
  factory TarneebState.newMatch({TarneebOptions options = const TarneebOptions(), required int seed}) {
    final s = TarneebState._empty(options, CardRng(seed), options.firstDealer);
    s.dealFromRng();
    return s;
  }

  /// A match whose first deal is [hands] (for tests and puzzles); later
  /// deals come from [seed]. With Syrian trumps, [exposedCard] (default: the
  /// last card of the dealer's list) must be in the dealer's hand.
  factory TarneebState.withHands(
    List<List<PlayingCard>> hands, {
    TarneebOptions options = const TarneebOptions(),
    int dealer = 3,
    int seed = 0,
    PlayingCard? exposedCard,
  }) {
    final s = TarneebState._empty(options, CardRng(seed), dealer);
    final exposed = options.trumpMode == TarneebTrumpMode.exposedCardSisterSuit
        ? exposedCard ?? hands[dealer].last
        : null;
    if (exposed != null && !hands[dealer].contains(exposed)) {
      throw ArgumentError.value(exposed, 'exposedCard', 'must be in the dealer\'s hand');
    }
    s.startDeal([for (final h in hands) List.of(h)], exposed: exposed);
    return s;
  }

  factory TarneebState._empty(TarneebOptions options, CardRng rng, int dealer) => TarneebState(
    options: options,
    rng: rng,
    phase: TarneebPhase.bidding,
    dealer: dealer,
    dealNumber: 0,
    roundNumber: 0,
    hands: [for (var i = 0; i < 4; i++) <PlayingCard>[]],
    turn: (dealer + 1) % 4,
    passed: List.filled(4, false),
    bids: [],
    highBid: 0,
    highBidder: -1,
    consecutivePasses: 0,
    trump: null,
    trick: null,
    tricks: [],
    tricksWon: [0, 0],
    teamScores: [0, 0],
    results: [],
    winnerTeam: null,
  );

  factory TarneebState.fromJson(Map<String, Object?> j) => TarneebState(
    options: TarneebOptions.fromJson((j['options']! as Map).cast<String, Object?>()),
    rng: CardRng.fromJson(j['rng']),
    phase: TarneebPhase.values.byName(j['phase']! as String),
    dealer: j['dealer']! as int,
    dealNumber: j['dealNumber']! as int,
    roundNumber: j['roundNumber']! as int,
    hands: handsFromJson(j['hands']),
    turn: j['turn']! as int,
    passed: (j['passed']! as List).cast<bool>().toList(),
    bids: [for (final b in j['bids']! as List) TarneebBid((b as List)[0] as int, b[1] as int)],
    highBid: j['highBid']! as int,
    highBidder: j['highBidder']! as int,
    consecutivePasses: j['consecutivePasses']! as int,
    trump: j['trump'] == null ? null : Suit.fromCode(j['trump']! as String),
    trick: j['trick'] == null ? null : Trick.fromJson((j['trick']! as Map).cast<String, Object?>()),
    tricks: [for (final t in j['tricks']! as List) Trick.fromJson((t as Map).cast<String, Object?>())],
    tricksWon: (j['tricksWon']! as List).cast<int>().toList(),
    teamScores: (j['teamScores']! as List).cast<int>().toList(),
    results: [for (final r in j['results']! as List) TarneebRoundResult.fromJson((r as Map).cast<String, Object?>())],
    winnerTeam: j['winnerTeam'] as int?,
    exposedCard: j['exposedCard'] == null ? null : PlayingCard.parse(j['exposedCard']! as String),
  );

  final TarneebOptions options;
  CardRng rng;
  TarneebPhase phase;
  int dealer;
  @override
  int dealNumber;

  /// Deals played to the end (redeals excluded).
  int roundNumber;
  List<List<PlayingCard>> hands;
  int turn;
  List<bool> passed;
  List<TarneebBid> bids;

  /// 0 while nobody has bid.
  int highBid;

  /// -1 while nobody has bid.
  int highBidder;
  int consecutivePasses;

  /// Null until chosen; known from the deal with Syrian trumps.
  Suit? trump;

  /// Syrian trumps: the dealer's card everybody has seen (it stays in the
  /// dealer's hand until played). Null otherwise.
  PlayingCard? exposedCard;
  Trick? trick;

  /// Completed tricks of the current deal.
  List<Trick> tricks;

  /// Tricks per team in the current deal.
  List<int> tricksWon;
  List<int> teamScores;
  List<TarneebRoundResult> results;
  int? winnerTeam;

  @override
  CardGameId get gameId => CardGameId.tarneeb;

  @override
  int get playerCount => 4;

  @override
  int? get currentPlayer => phase == TarneebPhase.over ? null : turn;

  @override
  bool get isOver => phase == TarneebPhase.over;

  @override
  List<int> get scores => [teamScores[0], teamScores[1], teamScores[0], teamScores[1]];

  @override
  List<int> get winners => winnerTeam == null ? const [] : [winnerTeam!, winnerTeam! + 2];

  @override
  int teamOf(int seat) => seat % 2;

  TarneebRoundResult? get lastResult => results.isEmpty ? null : results.last;

  /// [seat] has already spoken in the current auction.
  bool hasSpoken(int seat) => bids.any((b) => b.seat == seat);

  /// Every card played in the current deal (completed tricks, then the
  /// current trick), in order.
  Iterable<PlayingCard> get playedCards sync* {
    for (final t in tricks) {
      yield* t.cards;
    }
    if (trick != null) yield* trick!.cards;
  }

  void dealFromRng() {
    final deck = buildDeck();
    rng.shuffle(deck);
    // The dealer's last dealt card (the Syrian exposed card).
    final last = deck[dealer * 13 + 12];
    startDeal([
      for (var i = 0; i < 4; i++) deck.sublist(i * 13, i * 13 + 13)..sort(),
    ], exposed: options.trumpMode == TarneebTrumpMode.exposedCardSisterSuit ? last : null);
  }

  void startDeal(List<List<PlayingCard>> newHands, {PlayingCard? exposed}) {
    hands = newHands;
    phase = TarneebPhase.bidding;
    turn = (dealer + 1) % 4;
    passed = List.filled(4, false);
    bids = [];
    highBid = 0;
    highBidder = -1;
    consecutivePasses = 0;
    exposedCard = exposed;
    trump = exposed == null ? null : sisterSuit(exposed.suit);
    trick = null;
    tricks = [];
    tricksWon = [0, 0];
    dealNumber++;
  }

  @override
  List<PlayingCard> cardsInPlay() => [for (final h in hands) ...h, ...playedCards];

  @override
  List<PlayingCard> fullDeck() => buildDeck();

  @override
  TarneebState copy() => TarneebState(
    options: options,
    rng: rng.copy(),
    phase: phase,
    dealer: dealer,
    dealNumber: dealNumber,
    roundNumber: roundNumber,
    hands: [for (final h in hands) List.of(h)],
    turn: turn,
    passed: List.of(passed),
    bids: List.of(bids),
    highBid: highBid,
    highBidder: highBidder,
    consecutivePasses: consecutivePasses,
    trump: trump,
    trick: trick?.copy(),
    tricks: [for (final t in tricks) t.copy()],
    tricksWon: List.of(tricksWon),
    teamScores: List.of(teamScores),
    results: List.of(results),
    winnerTeam: winnerTeam,
    exposedCard: exposedCard,
  );

  @override
  Map<String, Object?> toJson() => {
    'game': gameId.name,
    'options': options.toJson(),
    'rng': rng.toJson(),
    'phase': phase.name,
    'dealer': dealer,
    'dealNumber': dealNumber,
    'roundNumber': roundNumber,
    'hands': handsToJson(hands),
    'turn': turn,
    'passed': passed,
    'bids': [
      for (final b in bids) [b.seat, b.amount],
    ],
    'highBid': highBid,
    'highBidder': highBidder,
    'consecutivePasses': consecutivePasses,
    'trump': trump?.code,
    'exposedCard': exposedCard?.id,
    'trick': trick?.toJson(),
    'tricks': [for (final t in tricks) t.toJson()],
    'tricksWon': tricksWon,
    'teamScores': teamScores,
    'results': [for (final r in results) r.toJson()],
    'winnerTeam': winnerTeam,
  };
}
