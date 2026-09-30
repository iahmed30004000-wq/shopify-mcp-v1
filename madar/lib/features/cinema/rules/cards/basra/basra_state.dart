/// Basra (باصرة): options, moves and the serialisable match state.
library;

import '../core/card_game.dart';
import '../core/card_rng.dart';
import '../core/deck.dart';
import '../core/playing_card.dart';

/// How the seven of diamonds (سبعة الديناري / الكومي) plays.
enum BasraSevenDiamonds {
  /// It sweeps the whole table like a jack; the sweep is a basra when every
  /// table card is a numeral and they add up to at most
  /// [BasraOptions.sevenDiamondsBasraMaxSum] (default).
  sweep,

  /// An ordinary seven.
  normal,
}

class BasraOptions {
  const BasraOptions({
    this.players = 4,
    this.partnership = true,
    this.targetScore = 101,
    this.basraPoints = 10,
    this.jackBasraPoints = 20,
    this.sevenDiamonds = BasraSevenDiamonds.sweep,
    this.sevenDiamondsBasraMaxSum = 10,
    this.basraOnLastCard = false,
    this.majorityPoints = 3,
  }) : assert(players == 2 || players == 4);

  factory BasraOptions.fromJson(Map<String, Object?> j) => BasraOptions(
    players: j['players']! as int,
    partnership: j['partnership']! as bool,
    targetScore: j['targetScore']! as int,
    basraPoints: j['basraPoints']! as int,
    jackBasraPoints: j['jackBasraPoints']! as int,
    sevenDiamonds: BasraSevenDiamonds.values.byName(j['sevenDiamonds']! as String),
    sevenDiamondsBasraMaxSum: j['sevenDiamondsBasraMaxSum']! as int,
    basraOnLastCard: j['basraOnLastCard']! as bool,
    majorityPoints: j['majorityPoints']! as int,
  );

  /// 2 or 4.
  final int players;

  /// With 4 players: partners sit opposite and share their captures.
  final bool partnership;
  final int targetScore;
  final int basraPoints;

  /// A jack taking a lone jack (0: a jack never makes a basra).
  final int jackBasraPoints;
  final BasraSevenDiamonds sevenDiamonds;
  final int sevenDiamondsBasraMaxSum;

  /// Whether a basra made with the very last card of the deal counts.
  final bool basraOnLastCard;

  /// For taking the most cards (none on a tie).
  final int majorityPoints;

  bool get teams => partnership && players == 4;
  int get sides => teams ? 2 : players;

  Map<String, Object?> toJson() => {
    'players': players,
    'partnership': partnership,
    'targetScore': targetScore,
    'basraPoints': basraPoints,
    'jackBasraPoints': jackBasraPoints,
    'sevenDiamonds': sevenDiamonds.name,
    'sevenDiamondsBasraMaxSum': sevenDiamondsBasraMaxSum,
    'basraOnLastCard': basraOnLastCard,
    'majorityPoints': majorityPoints,
  };
}

final class BasraMove extends CardMove {
  const BasraMove(this.card);

  factory BasraMove.fromJson(Map<String, Object?> j) => BasraMove(PlayingCard.parse(j['c']! as String));

  final PlayingCard card;

  @override
  Map<String, Object?> toJson() => {'c': card.id};

  @override
  bool operator ==(Object other) => other is BasraMove && other.card == card;

  @override
  int get hashCode => card.hashCode;

  @override
  String toString() => 'Basra($card)';
}

class BasraDealResult {
  const BasraDealResult(this.points, this.cardCounts, this.basras);

  factory BasraDealResult.fromJson(Map<String, Object?> j) => BasraDealResult(
    (j['points']! as List).cast<int>(),
    (j['cardCounts']! as List).cast<int>(),
    (j['basras']! as List).cast<int>(),
  );

  /// Per side.
  final List<int> points;
  final List<int> cardCounts;

  /// Basra points per side.
  final List<int> basras;

  Map<String, Object?> toJson() => {'points': points, 'cardCounts': cardCounts, 'basras': basras};
}

class BasraState extends CardGameState {
  BasraState({
    required this.options,
    required this.rng,
    required this.dealer,
    required this.dealNumber,
    required this.stock,
    required this.table,
    required this.hands,
    required this.turn,
    required this.piles,
    required this.basraScore,
    required this.lastCapturer,
    required this.sideScores,
    required this.results,
    required this.over,
  });

  factory BasraState.newMatch({BasraOptions options = const BasraOptions(), required int seed}) {
    final s = BasraState._empty(options, CardRng(seed));
    s.dealFromRng();
    return s;
  }

  /// A position built by hand (tests / puzzles): [stock] is drawn from the
  /// end; later deals come from [seed].
  factory BasraState.custom({
    required List<List<PlayingCard>> hands,
    required List<PlayingCard> table,
    List<PlayingCard> stock = const [],
    BasraOptions options = const BasraOptions(),
    int dealer = 3,
    int seed = 0,
  }) {
    final s = BasraState._empty(options, CardRng(seed))
      ..dealer = dealer
      ..hands = [for (final h in hands) List.of(h)]
      ..table = List.of(table)
      ..stock = List.of(stock)
      ..turn = (dealer + 1) % options.players
      ..dealNumber = 1;
    return s;
  }

  factory BasraState._empty(BasraOptions options, CardRng rng) => BasraState(
    options: options,
    rng: rng,
    dealer: options.players - 1,
    dealNumber: 0,
    stock: [],
    table: [],
    hands: [for (var i = 0; i < options.players; i++) <PlayingCard>[]],
    turn: 0,
    piles: [for (var i = 0; i < options.sides; i++) <PlayingCard>[]],
    basraScore: List.filled(options.sides, 0),
    lastCapturer: null,
    sideScores: List.filled(options.sides, 0),
    results: [],
    over: false,
  );

  factory BasraState.fromJson(Map<String, Object?> j) => BasraState(
    options: BasraOptions.fromJson((j['options']! as Map).cast<String, Object?>()),
    rng: CardRng.fromJson(j['rng']),
    dealer: j['dealer']! as int,
    dealNumber: j['dealNumber']! as int,
    stock: cardsFromJson(j['stock']),
    table: cardsFromJson(j['table']),
    hands: handsFromJson(j['hands']),
    turn: j['turn']! as int,
    piles: handsFromJson(j['piles']),
    basraScore: (j['basraScore']! as List).cast<int>().toList(),
    lastCapturer: j['lastCapturer'] as int?,
    sideScores: (j['sideScores']! as List).cast<int>().toList(),
    results: [for (final r in j['results']! as List) BasraDealResult.fromJson((r as Map).cast<String, Object?>())],
    over: j['over']! as bool,
  );

  final BasraOptions options;
  CardRng rng;
  int dealer;
  @override
  int dealNumber;

  /// Undealt cards; the next card is the last one.
  List<PlayingCard> stock;
  List<PlayingCard> table;
  List<List<PlayingCard>> hands;
  int turn;

  /// Captured cards per side.
  List<List<PlayingCard>> piles;

  /// Basra points per side in the current deal.
  List<int> basraScore;
  int? lastCapturer;
  List<int> sideScores;
  List<BasraDealResult> results;
  bool over;

  @override
  CardGameId get gameId => CardGameId.basra;

  @override
  int get playerCount => options.players;

  @override
  int teamOf(int seat) => options.teams ? seat % 2 : seat;

  @override
  int? get currentPlayer => over ? null : turn;

  @override
  bool get isOver => over;

  @override
  List<int> get scores => [for (var i = 0; i < playerCount; i++) sideScores[teamOf(i)]];

  @override
  List<int> get winners {
    if (!over) return const [];
    final best = sideScores.reduce((a, b) => a > b ? a : b);
    return [for (var i = 0; i < playerCount; i++) if (sideScores[teamOf(i)] == best) i];
  }

  static bool isSpecial(PlayingCard c, BasraOptions o) =>
      c.rank == Rank.jack ||
      (o.sevenDiamonds == BasraSevenDiamonds.sweep && c == PlayingCard(Suit.diamonds, Rank.seven));

  void dealFromRng() {
    final deck = buildDeck();
    rng.shuffle(deck);
    stock = deck;
    table = [];
    // Jacks (and the sweeping 7♦) may not start on the table: they go back
    // into the lower half of the pack and another card is turned.
    while (table.length < 4) {
      final c = stock.removeLast();
      if (isSpecial(c, options)) {
        stock.insert(rng.nextInt(stock.length ~/ 2), c);
      } else {
        table.add(c);
      }
    }
    piles = [for (var i = 0; i < options.sides; i++) <PlayingCard>[]];
    basraScore = List.filled(options.sides, 0);
    lastCapturer = null;
    hands = [for (var i = 0; i < playerCount; i++) <PlayingCard>[]];
    dealRound();
    turn = (dealer + 1) % playerCount;
    dealNumber++;
  }

  /// Four more cards to every player.
  void dealRound() {
    for (var n = 0; n < 4; n++) {
      for (var i = 1; i <= playerCount; i++) {
        hands[(dealer + i) % playerCount].add(stock.removeLast());
      }
    }
    for (final h in hands) {
      h.sort();
    }
  }

  @override
  List<PlayingCard> cardsInPlay() => [...stock, ...table, for (final h in hands) ...h, for (final p in piles) ...p];

  @override
  List<PlayingCard> fullDeck() => buildDeck();

  @override
  BasraState copy() => BasraState(
    options: options,
    rng: rng.copy(),
    dealer: dealer,
    dealNumber: dealNumber,
    stock: List.of(stock),
    table: List.of(table),
    hands: [for (final h in hands) List.of(h)],
    turn: turn,
    piles: [for (final p in piles) List.of(p)],
    basraScore: List.of(basraScore),
    lastCapturer: lastCapturer,
    sideScores: List.of(sideScores),
    results: List.of(results),
    over: over,
  );

  @override
  Map<String, Object?> toJson() => {
    'game': gameId.name,
    'options': options.toJson(),
    'rng': rng.toJson(),
    'dealer': dealer,
    'dealNumber': dealNumber,
    'stock': cardsToJson(stock),
    'table': cardsToJson(table),
    'hands': handsToJson(hands),
    'turn': turn,
    'piles': handsToJson(piles),
    'basraScore': basraScore,
    'lastCapturer': lastCapturer,
    'sideScores': sideScores,
    'results': [for (final r in results) r.toJson()],
    'over': over,
  };
}
