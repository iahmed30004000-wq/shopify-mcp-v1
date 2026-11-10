/// "41" (طلب فردي, the individual-bid game of the Tarneeb family): options,
/// moves and the serialisable match state.
///
/// Four players, partners opposite, but every player bids and scores for
/// themselves; a team wins when one partner reaches 41 while the other is
/// above zero. `const FortyOneOptions()` is the game called "41" as commonly
/// played around Jordan: hearts always trumps, one bid each from 2 to 13
/// with no pass, the deal is thrown in when the bids add up to less than 11,
/// bids of 1–6 are worth their face value and 7+ double. Presets: the
/// Lebanese "400" and the Syrian exposed-card game. See RULES.md.
library;

import '../core/card_game.dart';
import '../core/card_rng.dart';
import '../core/deck.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';
import '../tarneeb/tarneeb_state.dart' show sisterSuit;

/// The registry id of this game ([CardGameId.fortyOne]; its name is the
/// JSON `game` key, [FortyOneState.gameKey]).
const CardGameId fortyOneGameId = CardGameId.fortyOne;

/// How trumps are decided.
enum FortyOneTrumpMode {
  /// Hearts are always trumps (default, and the 400 game).
  heartsFixed,

  /// Syrian 41: the dealer's last card is shown to everyone (it stays in the
  /// dealer's hand); trumps are the other suit of the same colour.
  exposedCardSisterSuit,
}

/// What a bid is worth (won when made, lost when failed).
enum FortyOneValueTable {
  /// 1–6 face value, 7 and more double: 7 = 14 … 13 = 26 (default).
  doubleFrom7,

  /// The Lebanese 400 table, read with the bidder's own score at the start
  /// of the deal: below 30, 2 3 4 10 12 14 16 27 40 40 40 40; from 30 on,
  /// 2 3 4 5 6 14 16 27 40 40 40 40 (bids 2 to 13).
  levant400,

  /// Face value: a bid of n is worth n.
  faceValue,
}

/// Bids of 10–13 in the 400 table.
enum FortyOneTenPlus {
  /// All worth 40 (default).
  flat40,

  /// Four times the bid: 40, 44, 48, 52.
  times4,
}

/// What the partner of a player at the target needs for the team to win.
enum FortyOnePartnerRule {
  /// More than zero (default).
  positive,

  /// Zero or more.
  nonNegative,
}

/// Both teams qualify after the same deal.
enum FortyOneBothQualify {
  /// The higher team total, then the higher single score (default).
  higherTeamTotal,

  /// The higher single score, then the higher team total.
  higherIndividual,
}

/// Who deals after a throw-in (bids adding up to less than the minimum).
enum FortyOneThrowIn {
  /// The next dealer (default).
  nextDealer,

  /// The same dealer again.
  sameDealer,
}

/// Who leads the first trick.
enum FortyOneFirstLead {
  /// The player on the dealer's right, the first to bid (default).
  dealerRight,

  /// The highest bidder (the earliest of them on a tie).
  highestBidder,
}

class FortyOneOptions {
  /// "41" as commonly played around Jordan (every default below).
  const FortyOneOptions({
    this.trumpMode = FortyOneTrumpMode.heartsFixed,
    this.minBid = 2,
    this.minTotal = 11,
    this.risingMinimums = false,
    this.valueTable = FortyOneValueTable.doubleFrom7,
    this.levantTenPlus = FortyOneTenPlus.flat40,
    this.target = 41,
    this.partnerRule = FortyOnePartnerRule.positive,
    this.bothQualify = FortyOneBothQualify.higherTeamTotal,
    this.throwInRedeal = FortyOneThrowIn.nextDealer,
    this.firstLead = FortyOneFirstLead.dealerRight,
    this.bid13WinsMatch = false,
    this.firstDealer = 3,
  });

  /// The same as `FortyOneOptions()`.
  const FortyOneOptions.jordan() : this();

  /// "400" (لبناني): the 400 value table and minimums that rise with the
  /// scores.
  const FortyOneOptions.lebanese400() : this(risingMinimums: true, valueTable: FortyOneValueTable.levant400);

  /// "Syrian 41" (سوري 41): trumps from the dealer's exposed card.
  const FortyOneOptions.syrian() : this(trumpMode: FortyOneTrumpMode.exposedCardSisterSuit);

  /// Missing keys take the defaults.
  factory FortyOneOptions.fromJson(Map<String, Object?> j) {
    const d = FortyOneOptions();
    T pick<T>(String key, T fallback) => (j[key] as T?) ?? fallback;
    E byName<E extends Enum>(List<E> values, String key, E fallback) =>
        j[key] == null ? fallback : values.byName(j[key]! as String);
    return FortyOneOptions(
      trumpMode: byName(FortyOneTrumpMode.values, 'trumpMode', d.trumpMode),
      minBid: pick('minBid', d.minBid),
      minTotal: pick('minTotal', d.minTotal),
      risingMinimums: pick('risingMinimums', d.risingMinimums),
      valueTable: byName(FortyOneValueTable.values, 'valueTable', d.valueTable),
      levantTenPlus: byName(FortyOneTenPlus.values, 'levantTenPlus', d.levantTenPlus),
      target: pick('target', d.target),
      partnerRule: byName(FortyOnePartnerRule.values, 'partnerRule', d.partnerRule),
      bothQualify: byName(FortyOneBothQualify.values, 'bothQualify', d.bothQualify),
      throwInRedeal: byName(FortyOneThrowIn.values, 'throwInRedeal', d.throwInRedeal),
      firstLead: byName(FortyOneFirstLead.values, 'firstLead', d.firstLead),
      bid13WinsMatch: pick('bid13WinsMatch', d.bid13WinsMatch),
      firstDealer: pick('firstDealer', d.firstDealer),
    );
  }

  final FortyOneTrumpMode trumpMode;

  /// The lowest bid (2; 1 is a house rule).
  final int minBid;

  /// Bids adding up to less than this throw the deal in.
  final int minTotal;

  /// 400: a player's lowest bid rises with their own score (30+ → +1, 40+ →
  /// +2, 50+ → +3) and the minimum total with the highest score at the
  /// table (the same steps).
  final bool risingMinimums;
  final FortyOneValueTable valueTable;
  final FortyOneTenPlus levantTenPlus;

  /// 41.
  final int target;
  final FortyOnePartnerRule partnerRule;
  final FortyOneBothQualify bothQualify;
  final FortyOneThrowIn throwInRedeal;
  final FortyOneFirstLead firstLead;

  /// Bidding 13 and making it wins the match at once.
  final bool bid13WinsMatch;

  /// Dealer of the first deal; the first bidder is the next seat.
  final int firstDealer;

  /// The 400 table switches columns at this own score.
  static const int levantHighScore = 30;

  /// Rising-minimum step (0–3) for a score: < 30, 30–39, 40–49, 50+.
  static int risingStep(int score) => score < 30 ? 0 : (score < 40 ? 1 : (score < 50 ? 2 : 3));

  /// What a bid of [bid] (1–13) is worth to a player whose score at the
  /// start of the deal is [ownScore].
  int value(int bid, int ownScore) {
    switch (valueTable) {
      case FortyOneValueTable.faceValue:
        return bid;
      case FortyOneValueTable.doubleFrom7:
        return bid >= 7 ? 2 * bid : bid;
      case FortyOneValueTable.levant400:
        if (bid >= 10) return levantTenPlus == FortyOneTenPlus.flat40 ? 40 : 4 * bid;
        const low = [1, 2, 3, 4, 10, 12, 14, 16, 27];
        const high = [1, 2, 3, 4, 5, 6, 14, 16, 27];
        return (ownScore < levantHighScore ? low : high)[bid - 1];
    }
  }

  FortyOneOptions copyWith({
    FortyOneTrumpMode? trumpMode,
    int? minBid,
    int? minTotal,
    bool? risingMinimums,
    FortyOneValueTable? valueTable,
    FortyOneTenPlus? levantTenPlus,
    int? target,
    FortyOnePartnerRule? partnerRule,
    FortyOneBothQualify? bothQualify,
    FortyOneThrowIn? throwInRedeal,
    FortyOneFirstLead? firstLead,
    bool? bid13WinsMatch,
    int? firstDealer,
  }) => FortyOneOptions(
    trumpMode: trumpMode ?? this.trumpMode,
    minBid: minBid ?? this.minBid,
    minTotal: minTotal ?? this.minTotal,
    risingMinimums: risingMinimums ?? this.risingMinimums,
    valueTable: valueTable ?? this.valueTable,
    levantTenPlus: levantTenPlus ?? this.levantTenPlus,
    target: target ?? this.target,
    partnerRule: partnerRule ?? this.partnerRule,
    bothQualify: bothQualify ?? this.bothQualify,
    throwInRedeal: throwInRedeal ?? this.throwInRedeal,
    firstLead: firstLead ?? this.firstLead,
    bid13WinsMatch: bid13WinsMatch ?? this.bid13WinsMatch,
    firstDealer: firstDealer ?? this.firstDealer,
  );

  Map<String, Object?> toJson() => {
    'trumpMode': trumpMode.name,
    'minBid': minBid,
    'minTotal': minTotal,
    'risingMinimums': risingMinimums,
    'valueTable': valueTable.name,
    'levantTenPlus': levantTenPlus.name,
    'target': target,
    'partnerRule': partnerRule.name,
    'bothQualify': bothQualify.name,
    'throwInRedeal': throwInRedeal.name,
    'firstLead': firstLead.name,
    'bid13WinsMatch': bid13WinsMatch,
    'firstDealer': firstDealer,
  };

  @override
  bool operator ==(Object other) {
    if (other is! FortyOneOptions) return false;
    final a = toJson();
    final b = other.toJson();
    return a.keys.every((k) => a[k] == b[k]);
  }

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

enum FortyOnePhase { bidding, playing, over }

enum FortyOneMoveKind { bid, play }

final class FortyOneMove extends CardMove {
  const FortyOneMove._(this.kind, {this.amount, this.card});

  const FortyOneMove.bid(int amount) : this._(FortyOneMoveKind.bid, amount: amount);

  const FortyOneMove.play(PlayingCard card) : this._(FortyOneMoveKind.play, card: card);

  factory FortyOneMove.fromJson(Map<String, Object?> j) => FortyOneMove._(
    FortyOneMoveKind.values.byName(j['k']! as String),
    amount: j['n'] as int?,
    card: j['c'] == null ? null : PlayingCard.parse(j['c']! as String),
  );

  final FortyOneMoveKind kind;
  final int? amount;
  final PlayingCard? card;

  @override
  Map<String, Object?> toJson() => {'k': kind.name, if (amount != null) 'n': amount, if (card != null) 'c': card!.id};

  @override
  bool operator ==(Object other) =>
      other is FortyOneMove && other.kind == kind && other.amount == amount && other.card == card;

  @override
  int get hashCode => Object.hash(kind, amount, card);

  @override
  String toString() => 'FortyOne(${kind.name} ${amount ?? card ?? ''})';
}

/// The outcome of one played deal (per seat).
class FortyOneRoundResult {
  const FortyOneRoundResult({
    required this.dealer,
    required this.trump,
    required this.bids,
    required this.tricks,
    required this.points,
  });

  factory FortyOneRoundResult.fromJson(Map<String, Object?> j) => FortyOneRoundResult(
    dealer: j['dealer']! as int,
    trump: Suit.fromCode(j['trump']! as String),
    bids: (j['bids']! as List).cast<int>(),
    tricks: (j['tricks']! as List).cast<int>(),
    points: (j['points']! as List).cast<int>(),
  );

  final int dealer;
  final Suit trump;
  final List<int> bids;
  final List<int> tricks;

  /// Points per seat for this deal.
  final List<int> points;

  bool made(int seat) => tricks[seat] >= bids[seat];

  Map<String, Object?> toJson() => {
    'dealer': dealer,
    'trump': trump.code,
    'bids': bids,
    'tricks': tricks,
    'points': points,
  };
}

class FortyOneState extends CardGameState {
  FortyOneState({
    required this.options,
    required this.rng,
    required this.phase,
    required this.dealer,
    required this.dealNumber,
    required this.roundNumber,
    required this.hands,
    required this.turn,
    required this.bids,
    required this.trump,
    required this.exposedCard,
    required this.trick,
    required this.tricks,
    required this.tricksWon,
    required this.playerScores,
    required this.results,
    required this.winnerTeam,
  });

  /// A new match; the first deal is dealt from [seed].
  factory FortyOneState.newMatch({FortyOneOptions options = const FortyOneOptions(), required int seed}) {
    final s = FortyOneState._empty(options, CardRng(seed), options.firstDealer);
    s.dealFromRng();
    return s;
  }

  /// A match whose first deal is [hands] (tests); later deals come from
  /// [seed]. In the Syrian game [exposedCard] (default: the last card of the
  /// dealer's list) must be in the dealer's hand.
  factory FortyOneState.withHands(
    List<List<PlayingCard>> hands, {
    FortyOneOptions options = const FortyOneOptions(),
    int dealer = 3,
    int seed = 0,
    List<int>? scores,
    PlayingCard? exposedCard,
  }) {
    final s = FortyOneState._empty(options, CardRng(seed), dealer);
    if (scores != null) s.playerScores = List.of(scores);
    final exposed = options.trumpMode == FortyOneTrumpMode.exposedCardSisterSuit
        ? exposedCard ?? hands[dealer].last
        : null;
    if (exposed != null && !hands[dealer].contains(exposed)) {
      throw ArgumentError.value(exposed, 'exposedCard', 'must be in the dealer\'s hand');
    }
    s.startDeal([for (final h in hands) List.of(h)], exposed: exposed);
    return s;
  }

  factory FortyOneState._empty(FortyOneOptions options, CardRng rng, int dealer) => FortyOneState(
    options: options,
    rng: rng,
    phase: FortyOnePhase.bidding,
    dealer: dealer,
    dealNumber: 0,
    roundNumber: 0,
    hands: [for (var i = 0; i < 4; i++) <PlayingCard>[]],
    turn: (dealer + 1) % 4,
    bids: List.filled(4, null),
    trump: Suit.hearts,
    exposedCard: null,
    trick: null,
    tricks: [],
    tricksWon: List.filled(4, 0),
    playerScores: List.filled(4, 0),
    results: [],
    winnerTeam: null,
  );

  factory FortyOneState.fromJson(Map<String, Object?> j) => FortyOneState(
    options: FortyOneOptions.fromJson((j['options']! as Map).cast<String, Object?>()),
    rng: CardRng.fromJson(j['rng']),
    phase: FortyOnePhase.values.byName(j['phase']! as String),
    dealer: j['dealer']! as int,
    dealNumber: j['dealNumber']! as int,
    roundNumber: j['roundNumber']! as int,
    hands: handsFromJson(j['hands']),
    turn: j['turn']! as int,
    bids: (j['bids']! as List).cast<int?>().toList(),
    trump: Suit.fromCode(j['trump']! as String),
    exposedCard: j['exposedCard'] == null ? null : PlayingCard.parse(j['exposedCard']! as String),
    trick: j['trick'] == null ? null : Trick.fromJson((j['trick']! as Map).cast<String, Object?>()),
    tricks: [for (final t in j['tricks']! as List) Trick.fromJson((t as Map).cast<String, Object?>())],
    tricksWon: (j['tricksWon']! as List).cast<int>().toList(),
    playerScores: (j['scores']! as List).cast<int>().toList(),
    results: [for (final r in j['results']! as List) FortyOneRoundResult.fromJson((r as Map).cast<String, Object?>())],
    winnerTeam: j['winnerTeam'] as int?,
  );

  /// The `game` key of the JSON (the name of the `CardGameId`).
  static const String gameKey = 'fortyOne';

  final FortyOneOptions options;
  CardRng rng;
  FortyOnePhase phase;
  int dealer;
  @override
  int dealNumber;

  /// Deals played to the end (throw-ins excluded).
  int roundNumber;
  List<List<PlayingCard>> hands;
  int turn;

  /// Each seat's bid in the current deal (null = not yet).
  List<int?> bids;

  /// Trumps of the current deal (hearts, or from the exposed card).
  Suit trump;

  /// Syrian 41: the dealer's card everybody has seen (it stays in the
  /// dealer's hand until played). Null otherwise.
  PlayingCard? exposedCard;
  Trick? trick;

  /// Completed tricks of the current deal.
  List<Trick> tricks;

  /// Tricks per seat in the current deal.
  List<int> tricksWon;

  /// Individual match scores.
  List<int> playerScores;
  List<FortyOneRoundResult> results;
  int? winnerTeam;

  @override
  CardGameId get gameId => fortyOneGameId;

  @override
  int get playerCount => 4;

  @override
  int? get currentPlayer => phase == FortyOnePhase.over ? null : turn;

  @override
  bool get isOver => phase == FortyOnePhase.over;

  /// Individual scores (partners do not share a total in this game).
  @override
  List<int> get scores => List.unmodifiable(playerScores);

  @override
  List<int> get winners => winnerTeam == null ? const [] : [winnerTeam!, winnerTeam! + 2];

  /// Partners (0 & 2, 1 & 3) win together.
  @override
  int teamOf(int seat) => seat % 2;

  FortyOneRoundResult? get lastResult => results.isEmpty ? null : results.last;

  /// Sum of the bids made so far in this deal.
  int get bidTotal => bids.fold(0, (a, b) => a + (b ?? 0));

  /// The lowest bid [seat] may make now.
  int minBidFor(int seat) =>
      options.minBid + (options.risingMinimums ? FortyOneOptions.risingStep(playerScores[seat]) : 0);

  /// Bids must add up to at least this, or the deal is thrown in.
  int get minTotalNow {
    if (!options.risingMinimums) return options.minTotal;
    final top = playerScores.reduce((a, b) => a > b ? a : b);
    return options.minTotal + FortyOneOptions.risingStep(top);
  }

  /// Every card played in the current deal, in order.
  Iterable<PlayingCard> get playedCards sync* {
    for (final t in tricks) {
      yield* t.cards;
    }
    if (trick != null) yield* trick!.cards;
  }

  void dealFromRng() {
    final deck = buildDeck();
    rng.shuffle(deck);
    final last = deck[dealer * 13 + 12];
    startDeal([
      for (var i = 0; i < 4; i++) deck.sublist(i * 13, i * 13 + 13)..sort(),
    ], exposed: options.trumpMode == FortyOneTrumpMode.exposedCardSisterSuit ? last : null);
  }

  void startDeal(List<List<PlayingCard>> newHands, {PlayingCard? exposed}) {
    hands = newHands;
    phase = FortyOnePhase.bidding;
    turn = (dealer + 1) % 4;
    bids = List.filled(4, null);
    exposedCard = exposed;
    trump = exposed == null ? Suit.hearts : sisterSuit(exposed.suit);
    trick = null;
    tricks = [];
    tricksWon = List.filled(4, 0);
    dealNumber++;
  }

  @override
  List<PlayingCard> cardsInPlay() => [for (final h in hands) ...h, ...playedCards];

  @override
  List<PlayingCard> fullDeck() => buildDeck();

  @override
  FortyOneState copy() => FortyOneState(
    options: options,
    rng: rng.copy(),
    phase: phase,
    dealer: dealer,
    dealNumber: dealNumber,
    roundNumber: roundNumber,
    hands: [for (final h in hands) List.of(h)],
    turn: turn,
    bids: List.of(bids),
    trump: trump,
    exposedCard: exposedCard,
    trick: trick?.copy(),
    tricks: [for (final t in tricks) t.copy()],
    tricksWon: List.of(tricksWon),
    playerScores: List.of(playerScores),
    results: List.of(results),
    winnerTeam: winnerTeam,
  );

  @override
  Map<String, Object?> toJson() => {
    'game': gameKey,
    'options': options.toJson(),
    'rng': rng.toJson(),
    'phase': phase.name,
    'dealer': dealer,
    'dealNumber': dealNumber,
    'roundNumber': roundNumber,
    'hands': handsToJson(hands),
    'turn': turn,
    'bids': bids,
    'trump': trump.code,
    'exposedCard': exposedCard?.id,
    'trick': trick?.toJson(),
    'tricks': [for (final t in tricks) t.toJson()],
    'tricksWon': tricksWon,
    'scores': playerScores,
    'results': [for (final r in results) r.toJson()],
    'winnerTeam': winnerTeam,
  };
}
