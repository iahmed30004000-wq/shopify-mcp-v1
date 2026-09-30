/// Basra (باصرة): options, moves and the serialisable match state.
///
/// `const BasraOptions()` is the game as commonly played in Jordan (see
/// RULES.md): 52 cards, four players in two partnerships, four cards each
/// and four face up on the table, a basra worth **twice the capturing card**
/// (a 7 → 14, a queen or king → 20), a jack on a lone jack worth nothing,
/// the 7♦ sweeps the table, most cards 3, first side to 101. The Palestinian
/// 44-card game and the Egyptian scoring are named presets.
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

/// Which pack is used.
enum BasraDeck {
  /// All 52 cards (default).
  full52,

  /// Without queens and kings: 44 cards (the Palestinian game).
  short44,
}

/// What a basra is worth.
enum BasraValueRule {
  /// Twice the capturing card: A 2, 2 → 4 … 10 → 20, Q and K
  /// 2 × [BasraOptions.faceCardBasraBase] (20), the 7♦ 14 (Jordan default).
  twiceCard,

  /// A flat [BasraOptions.basraPoints] (10) for every basra (Egypt).
  flat,
}

/// What happens to the most-cards points on a tie.
enum BasraMajorityTie {
  /// Nobody scores them (default).
  none,

  /// They are added to the next deal's most-cards points, and keep adding up
  /// until a deal has a clear winner (Egypt).
  carryOver,
}

/// The named rule sets offered in the games menu.
enum BasraPreset {
  /// أردني – `BasraOptions.jordan()`, the default.
  jordan,

  /// فلسطيني ٤٤ – `BasraOptions.palestinian44()`.
  palestinian44,

  /// مصري – `BasraOptions.egyptian()`.
  egyptian,

  /// Anything else.
  custom,
}

class BasraOptions {
  /// The Jordanian game (every default below).
  const BasraOptions({
    this.players = 4,
    this.partnership = true,
    this.deck = BasraDeck.full52,
    this.handSize,
    this.targetScore = 101,
    this.basraValue = BasraValueRule.twiceCard,
    this.faceCardBasraBase = 10,
    this.basraPoints = 10,
    this.jackBasraPoints = 0,
    this.sevenDiamonds = BasraSevenDiamonds.sweep,
    this.sevenDiamondsBasraMaxSum = 10,
    this.basraOnLastCard = false,
    this.majorityPoints = 3,
    this.majorityTie = BasraMajorityTie.none,
  }) : assert(players >= 2 && players <= 4);

  /// Basra as commonly played in Jordan (the same as `BasraOptions()`).
  const BasraOptions.jordan({int players = 4, bool partnership = true, int targetScore = 101})
    : this(players: players, partnership: partnership, targetScore: targetScore);

  /// The Palestinian game, also common in Jordan: no queens or kings (44
  /// cards) and the 7♦ is an ordinary seven. Four players get five cards a
  /// round (two rounds); three players cannot play it.
  const BasraOptions.palestinian44({int players = 4, bool partnership = true, int targetScore = 101})
    : this(
        players: players,
        partnership: partnership,
        targetScore: targetScore,
        deck: BasraDeck.short44,
        sevenDiamonds: BasraSevenDiamonds.normal,
      );

  /// The Egyptian scoring used by most apps: every basra 10, a jack on a
  /// lone jack 20, most cards 30 (carried over on a tie).
  const BasraOptions.egyptian({int players = 4, bool partnership = true, int targetScore = 101})
    : this(
        players: players,
        partnership: partnership,
        targetScore: targetScore,
        basraValue: BasraValueRule.flat,
        jackBasraPoints: 20,
        majorityPoints: 30,
        majorityTie: BasraMajorityTie.carryOver,
      );

  /// Missing keys take the defaults, except that a save from before the
  /// Jordanian defaults (no `basraValue` key) keeps its flat basra value.
  factory BasraOptions.fromJson(Map<String, Object?> j) {
    const d = BasraOptions();
    T pick<T>(String key, T fallback) => (j[key] as T?) ?? fallback;
    final value = j['basraValue'] as String?;
    return BasraOptions(
      players: pick('players', d.players),
      partnership: pick('partnership', d.partnership),
      deck: j['deck'] == null ? d.deck : BasraDeck.values.byName(j['deck']! as String),
      handSize: j['handSize'] as int?,
      targetScore: pick('targetScore', d.targetScore),
      basraValue: value == null ? BasraValueRule.flat : BasraValueRule.values.byName(value),
      faceCardBasraBase: pick('faceCardBasraBase', d.faceCardBasraBase),
      basraPoints: pick('basraPoints', d.basraPoints),
      jackBasraPoints: pick('jackBasraPoints', d.jackBasraPoints),
      sevenDiamonds: j['sevenDiamonds'] == null
          ? d.sevenDiamonds
          : BasraSevenDiamonds.values.byName(j['sevenDiamonds']! as String),
      sevenDiamondsBasraMaxSum: pick('sevenDiamondsBasraMaxSum', d.sevenDiamondsBasraMaxSum),
      basraOnLastCard: pick('basraOnLastCard', d.basraOnLastCard),
      majorityPoints: pick('majorityPoints', d.majorityPoints),
      majorityTie: j['majorityTie'] == null
          ? d.majorityTie
          : BasraMajorityTie.values.byName(j['majorityTie']! as String),
    );
  }

  /// Targets offered in the games menu (any number is accepted).
  static const List<int> targetChoices = [101, 121, 151];

  /// 2, 3 or 4.
  final int players;

  /// With 4 players: partners sit opposite and share their captures.
  final bool partnership;
  final BasraDeck deck;

  /// Cards dealt to each player per round; null = automatic (4, or 5 for
  /// the 44-card pack with four players). See [cardsPerRound].
  final int? handSize;
  final int targetScore;
  final BasraValueRule basraValue;

  /// Value of a queen or king in the twice-the-card rule (a Q/K basra is
  /// twice this).
  final int faceCardBasraBase;

  /// Every basra under [BasraValueRule.flat].
  final int basraPoints;

  /// A jack taking a lone jack (0: a jack never makes a basra). Never
  /// doubled.
  final int jackBasraPoints;
  final BasraSevenDiamonds sevenDiamonds;
  final int sevenDiamondsBasraMaxSum;

  /// Whether a basra made with the very last card of the deal counts.
  final bool basraOnLastCard;

  /// For taking the most cards.
  final int majorityPoints;
  final BasraMajorityTie majorityTie;

  bool get teams => partnership && players == 4;
  int get sides => teams ? 2 : players;

  /// 52, or 44 without queens and kings.
  int get deckSize => deck == BasraDeck.short44 ? 44 : 52;

  int get cardsPerRound => handSize ?? (deck == BasraDeck.short44 && players == 4 ? 5 : 4);

  /// Rounds of dealing per deal (after the four table cards).
  int get roundsPerDeal => (deckSize - 4) ~/ (players * cardsPerRound);

  /// Null when the options can be played, else a stable id:
  /// `playerCount` (not 2–4), `shortDeckThreePlayers` (the 44-card pack
  /// cannot be shared by three), `handSize` (the pack does not split into
  /// whole rounds).
  String? get configError {
    if (players < 2 || players > 4) return 'playerCount';
    if (deck == BasraDeck.short44 && players == 3) return 'shortDeckThreePlayers';
    final n = cardsPerRound;
    if (n < 1 || (deckSize - 4) % (players * n) != 0) return 'handSize';
    return null;
  }

  /// Which named rule set these options are (ignoring the number of
  /// players, the partnership and the target).
  BasraPreset get preset {
    for (final (preset, o) in [
      (BasraPreset.jordan, BasraOptions.jordan(players: players, partnership: partnership, targetScore: targetScore)),
      (
        BasraPreset.palestinian44,
        BasraOptions.palestinian44(players: players, partnership: partnership, targetScore: targetScore),
      ),
      (
        BasraPreset.egyptian,
        BasraOptions.egyptian(players: players, partnership: partnership, targetScore: targetScore),
      ),
    ]) {
      if (o == this) return preset;
    }
    return BasraPreset.custom;
  }

  /// The unshuffled pack of these options.
  List<PlayingCard> buildPack() => deck == BasraDeck.short44
      ? buildDeck(ranks: Rank.values.where((r) => r != Rank.queen && r != Rank.king))
      : buildDeck();

  Map<String, Object?> toJson() => {
    'players': players,
    'partnership': partnership,
    'deck': deck.name,
    'handSize': handSize,
    'targetScore': targetScore,
    'basraValue': basraValue.name,
    'faceCardBasraBase': faceCardBasraBase,
    'basraPoints': basraPoints,
    'jackBasraPoints': jackBasraPoints,
    'sevenDiamonds': sevenDiamonds.name,
    'sevenDiamondsBasraMaxSum': sevenDiamondsBasraMaxSum,
    'basraOnLastCard': basraOnLastCard,
    'majorityPoints': majorityPoints,
    'majorityTie': majorityTie.name,
  };

  @override
  bool operator ==(Object other) {
    if (other is! BasraOptions) return false;
    final a = toJson();
    final b = other.toJson();
    return a.keys.every((k) => a[k] == b[k]);
  }

  @override
  int get hashCode => Object.hashAll(toJson().values);
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
  const BasraDealResult(
    this.points,
    this.cardCounts,
    this.basras, {
    this.majoritySide,
    this.majorityAwarded = 0,
    this.carry = 0,
  });

  factory BasraDealResult.fromJson(Map<String, Object?> j) => BasraDealResult(
    (j['points']! as List).cast<int>(),
    (j['cardCounts']! as List).cast<int>(),
    (j['basras']! as List).cast<int>(),
    majoritySide: j['majoritySide'] as int?,
    majorityAwarded: (j['majorityAwarded'] as int?) ?? 0,
    carry: (j['carry'] as int?) ?? 0,
  );

  /// Per side.
  final List<int> points;
  final List<int> cardCounts;

  /// Basra points per side.
  final List<int> basras;

  /// The side that took the most cards (null on a tie).
  final int? majoritySide;

  /// Most-cards points it scored (carried points included).
  final int majorityAwarded;

  /// Most-cards points carried over to the next deal (carry-over rule).
  final int carry;

  Map<String, Object?> toJson() => {
    'points': points,
    'cardCounts': cardCounts,
    'basras': basras,
    'majoritySide': majoritySide,
    'majorityAwarded': majorityAwarded,
    'carry': carry,
  };
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
    this.majorityCarry = 0,
  });

  /// Throws an [ArgumentError] (message: [BasraOptions.configError]) for
  /// options that cannot be dealt.
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
    int? dealer,
    int seed = 0,
  }) {
    final d = dealer ?? options.players - 1;
    final s = BasraState._empty(options, CardRng(seed))
      ..dealer = d
      ..hands = [for (final h in hands) List.of(h)]
      ..table = List.of(table)
      ..stock = List.of(stock)
      ..turn = (d + 1) % options.players
      ..dealNumber = 1;
    return s;
  }

  factory BasraState._empty(BasraOptions options, CardRng rng) {
    final error = options.configError;
    if (error != null) throw ArgumentError(error);
    return BasraState(
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
  }

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
    majorityCarry: (j['majorityCarry'] as int?) ?? 0,
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

  /// Most-cards points carried into this deal after earlier ties
  /// ([BasraMajorityTie.carryOver]); always 0 otherwise.
  int majorityCarry;

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
    return [
      for (var i = 0; i < playerCount; i++)
        if (sideScores[teamOf(i)] == best) i,
    ];
  }

  /// Cards that may not start on the table: jacks, and the 7♦ when it
  /// sweeps.
  static bool isSpecial(PlayingCard c, BasraOptions o) =>
      c.rank == Rank.jack ||
      (o.sevenDiamonds == BasraSevenDiamonds.sweep && c == PlayingCard(Suit.diamonds, Rank.seven));

  void dealFromRng() {
    final deck = options.buildPack();
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

  /// [BasraOptions.cardsPerRound] more cards to every player, one at a
  /// time from the dealer's right.
  void dealRound() {
    for (var n = 0; n < options.cardsPerRound; n++) {
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
  List<PlayingCard> fullDeck() => options.buildPack();

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
    majorityCarry: majorityCarry,
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
    'majorityCarry': majorityCarry,
  };
}
