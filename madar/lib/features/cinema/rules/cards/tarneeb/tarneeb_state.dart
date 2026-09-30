/// Tarneeb (طرنيب): options, moves and the serialisable match state.
library;

import '../core/card_game.dart';
import '../core/card_rng.dart';
import '../core/deck.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';

/// What happens when all four players pass.
enum TarneebAllPass {
  /// The deal is thrown in and the next dealer deals again (default).
  redeal,

  /// The dealer may not pass and must bid the minimum.
  dealerTakesMinimum,
}

/// What a bidding team that makes its contract scores.
enum TarneebMadeScore {
  /// The tricks it took (default).
  tricksTaken,

  /// Exactly its bid.
  bid,
}

/// What the defenders score when the bidding team fails.
enum TarneebFailScore {
  /// The tricks they took (default).
  defendersTricks,

  /// The failed bid.
  bid,

  /// Nothing (the bidders only lose their bid).
  nothing,
}

class TarneebOptions {
  const TarneebOptions({
    this.targetScore = 31,
    this.minBid = 7,
    this.passIsFinal = true,
    this.allPass = TarneebAllPass.redeal,
    this.madeScore = TarneebMadeScore.tricksTaken,
    this.failScore = TarneebFailScore.defendersTricks,
    this.defendersScoreWhenMade = false,
    this.allTricksScore = 16,
    this.bidderLeads = true,
    this.firstDealer = 3,
  });

  factory TarneebOptions.fromJson(Map<String, Object?> j) => TarneebOptions(
    targetScore: j['targetScore']! as int,
    minBid: j['minBid']! as int,
    passIsFinal: j['passIsFinal']! as bool,
    allPass: TarneebAllPass.values.byName(j['allPass']! as String),
    madeScore: TarneebMadeScore.values.byName(j['madeScore']! as String),
    failScore: TarneebFailScore.values.byName(j['failScore']! as String),
    defendersScoreWhenMade: j['defendersScoreWhenMade']! as bool,
    allTricksScore: j['allTricksScore']! as int,
    bidderLeads: j['bidderLeads']! as bool,
    firstDealer: j['firstDealer']! as int,
  );

  /// 31 by default; 41 is the other common target.
  final int targetScore;
  final int minBid;

  /// A player who passes may not bid again in that auction.
  final bool passIsFinal;
  final TarneebAllPass allPass;
  final TarneebMadeScore madeScore;
  final TarneebFailScore failScore;

  /// Defenders also score their tricks when the contract is made.
  final bool defendersScoreWhenMade;

  /// Score of a bidding team that takes all 13 tricks (kaboot / كبوت).
  final int allTricksScore;

  /// The winning bidder leads the first trick (else the dealer's right).
  final bool bidderLeads;

  /// Dealer of the first deal; the first bidder is the next seat.
  final int firstDealer;

  Map<String, Object?> toJson() => {
    'targetScore': targetScore,
    'minBid': minBid,
    'passIsFinal': passIsFinal,
    'allPass': allPass.name,
    'madeScore': madeScore.name,
    'failScore': failScore.name,
    'defendersScoreWhenMade': defendersScoreWhenMade,
    'allTricksScore': allTricksScore,
    'bidderLeads': bidderLeads,
    'firstDealer': firstDealer,
  };
}

enum TarneebPhase { bidding, trump, playing, over }

enum TarneebMoveKind { bid, pass, trump, play }

final class TarneebMove extends CardMove {
  const TarneebMove._(this.kind, {this.amount, this.suit, this.card});

  const TarneebMove.bid(int amount) : this._(TarneebMoveKind.bid, amount: amount);

  const TarneebMove.pass() : this._(TarneebMoveKind.pass);

  const TarneebMove.trump(Suit suit) : this._(TarneebMoveKind.trump, suit: suit);

  const TarneebMove.play(PlayingCard card) : this._(TarneebMoveKind.play, card: card);

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

/// One bid of the auction (amount 0 = pass).
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
  });

  /// A new match; the first deal is dealt from [seed].
  factory TarneebState.newMatch({TarneebOptions options = const TarneebOptions(), required int seed}) {
    final s = TarneebState._empty(options, CardRng(seed), options.firstDealer);
    s.dealFromRng();
    return s;
  }

  /// A match whose first deal is [hands] (for tests and puzzles); later
  /// deals come from [seed].
  factory TarneebState.withHands(
    List<List<PlayingCard>> hands, {
    TarneebOptions options = const TarneebOptions(),
    int dealer = 3,
    int seed = 0,
  }) {
    final s = TarneebState._empty(options, CardRng(seed), dealer);
    s.startDeal([for (final h in hands) List.of(h)]);
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
    bids: [
      for (final b in j['bids']! as List) TarneebBid((b as List)[0] as int, b[1] as int),
    ],
    highBid: j['highBid']! as int,
    highBidder: j['highBidder']! as int,
    consecutivePasses: j['consecutivePasses']! as int,
    trump: j['trump'] == null ? null : Suit.fromCode(j['trump']! as String),
    trick: j['trick'] == null ? null : Trick.fromJson((j['trick']! as Map).cast<String, Object?>()),
    tricks: [for (final t in j['tricks']! as List) Trick.fromJson((t as Map).cast<String, Object?>())],
    tricksWon: (j['tricksWon']! as List).cast<int>().toList(),
    teamScores: (j['teamScores']! as List).cast<int>().toList(),
    results: [
      for (final r in j['results']! as List) TarneebRoundResult.fromJson((r as Map).cast<String, Object?>()),
    ],
    winnerTeam: j['winnerTeam'] as int?,
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
  Suit? trump;
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
    startDeal([for (var i = 0; i < 4; i++) deck.sublist(i * 13, i * 13 + 13)..sort()]);
  }

  void startDeal(List<List<PlayingCard>> newHands) {
    hands = newHands;
    phase = TarneebPhase.bidding;
    turn = (dealer + 1) % 4;
    passed = List.filled(4, false);
    bids = [];
    highBid = 0;
    highBidder = -1;
    consecutivePasses = 0;
    trump = null;
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
    'trick': trick?.toJson(),
    'tricks': [for (final t in tricks) t.toJson()],
    'tricksWon': tricksWon,
    'teamScores': teamScores,
    'results': [for (final r in results) r.toJson()],
    'winnerTeam': winnerTeam,
  };
}
