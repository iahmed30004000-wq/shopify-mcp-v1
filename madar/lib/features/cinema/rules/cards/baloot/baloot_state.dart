/// Baloot (بلوت): options, moves, projects and the serialisable match state.
///
/// `const BalootOptions()` is the game as commonly played in Jordan, which is
/// the Saudi game (tournament rules): Ashkal for the 3rd and 4th speakers,
/// Sun priority for earlier speakers, the Hokom taker may switch to Sun, the
/// doubler chooses locked or open play, the Saudi trumping rules with Ekka,
/// one counting team with the rounding tie-break, belote to the winners of a
/// lost or doubled deal, projects doubled at most, 152 with a tie played
/// off. See RULES.md.
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

/// Who leads the first trick.
enum BalootFirstLead {
  /// The dealer's right (the first speaker), whoever bought (default).
  dealerRight,

  /// The taker (reported app behaviour).
  taker,
}

/// When a Sun contract may be doubled.
enum BalootSunDoubleRule {
  /// Only when, before this deal, the takers have more than 100 and the
  /// defenders less than 100 (default).
  takersOver100DoublersUnder100,

  /// When one team has more than 100 and the other less than 100, either way.
  oneOver100OneUnder,
  always,
  never,
}

/// Trump led and you hold trumps: when must you beat the best trump?
enum BalootTrumpLedOvertrump {
  /// Only when an opponent is winning the trick (default).
  againstOpponent,

  /// Always, even over the partner.
  always,
}

/// You cannot follow a side suit, you hold trumps and your partner is
/// winning the trick.
enum BalootPartnerWinningVoid {
  /// Saudi rule (default): the 4th player may play any card; the 3rd player
  /// may play any card after an Ace or an Ekka lead, otherwise must trump.
  saudi,

  /// Must trump (and over-trump a trump) even when the partner is winning.
  alwaysTrump,

  /// Any card.
  free,
}

/// Belote held by a team that loses the deal (or in any doubled deal).
enum BalootBeloteOnLoss {
  /// The winners score every belote (default).
  toWinner,

  /// Each belote stays with its holder's team.
  keptByHolder,

  /// A loser's belote is simply lost (the rule the spec calls `void`).
  voided,
}

/// How projects are declared.
enum BalootDeclareProjects {
  /// Every player's best set, automatically, when play starts (default).
  auto,

  /// Each player with a project chooses, before their first card, to
  /// declare all of them or none.
  manual,
}

class BalootOptions {
  /// The Jordanian (Saudi) game: every default below.
  ///
  /// [mustTrumpWhenPartnerWinning] and [sunDoubleOnlyWhenBehind] are the
  /// names used before the Jordanian defaults; when given they override
  /// [partnerWinningVoid] (true → `alwaysTrump`, false → `free`) and
  /// [sunDoubleRule] (true → `takersOver100DoublersUnder100`, false →
  /// `always`).
  const BalootOptions({
    this.targetScore = 152,
    this.firstDealer = 3,
    this.firstLead = BalootFirstLead.dealerRight,
    this.sunPriority = true,
    this.ashkal = true,
    this.ashkalOnAce = false,
    this.ashkalInRound2 = false,
    this.takerMaySwitchToSun = true,
    this.kawesh = false,
    this.aceThirdRound = false,
    this.doubling = true,
    BalootSunDoubleRule sunDoubleRule = BalootSunDoubleRule.takersOver100DoublersUnder100,
    this.voidMustTrump = true,
    this.mustOvertrump = true,
    this.trumpLedOvertrump = BalootTrumpLedOvertrump.againstOpponent,
    BalootPartnerWinningVoid partnerWinningVoid = BalootPartnerWinningVoid.saudi,
    this.declareProjects = BalootDeclareProjects.auto,
    this.sequenceBeatsCarre = false,
    this.trumpSequencePriority = false,
    this.beloteOnLoss = BalootBeloteOnLoss.toWinner,
    this.projectMultiplierCap = 2,
    bool? mustTrumpWhenPartnerWinning,
    bool? sunDoubleOnlyWhenBehind,
  }) : partnerWinningVoid = mustTrumpWhenPartnerWinning == null
           ? partnerWinningVoid
           : (mustTrumpWhenPartnerWinning == true
                 ? BalootPartnerWinningVoid.alwaysTrump
                 : BalootPartnerWinningVoid.free),
       sunDoubleRule = sunDoubleOnlyWhenBehind == null
           ? sunDoubleRule
           : (sunDoubleOnlyWhenBehind == true
                 ? BalootSunDoubleRule.takersOver100DoublersUnder100
                 : BalootSunDoubleRule.always);

  /// Baloot as commonly played in Jordan (the same as `BalootOptions()`).
  const BalootOptions.jordan({int targetScore = 152}) : this(targetScore: targetScore);

  /// Missing keys take the defaults; the keys of saves made before the
  /// Jordanian defaults (`mustTrumpWhenPartnerWinning`,
  /// `sunDoubleOnlyWhenBehind`) are mapped, `buyerWinsTies` is ignored.
  factory BalootOptions.fromJson(Map<String, Object?> j) {
    const d = BalootOptions();
    T pick<T>(String key, T fallback) => (j[key] as T?) ?? fallback;
    E pickEnum<E extends Enum>(String key, List<E> values, E fallback) =>
        j[key] == null ? fallback : values.byName(j[key]! as String);
    return BalootOptions(
      targetScore: pick('targetScore', d.targetScore),
      firstDealer: pick('firstDealer', d.firstDealer),
      firstLead: pickEnum('firstLead', BalootFirstLead.values, d.firstLead),
      sunPriority: pick('sunPriority', d.sunPriority),
      ashkal: pick('ashkal', d.ashkal),
      ashkalOnAce: pick('ashkalOnAce', d.ashkalOnAce),
      ashkalInRound2: pick('ashkalInRound2', d.ashkalInRound2),
      takerMaySwitchToSun: pick('takerMaySwitchToSun', d.takerMaySwitchToSun),
      kawesh: pick('kawesh', d.kawesh),
      aceThirdRound: pick('aceThirdRound', d.aceThirdRound),
      doubling: pick('doubling', d.doubling),
      sunDoubleRule: pickEnum('sunDoubleRule', BalootSunDoubleRule.values, d.sunDoubleRule),
      voidMustTrump: pick('voidMustTrump', d.voidMustTrump),
      mustOvertrump: pick('mustOvertrump', d.mustOvertrump),
      trumpLedOvertrump: pickEnum('trumpLedOvertrump', BalootTrumpLedOvertrump.values, d.trumpLedOvertrump),
      partnerWinningVoid: pickEnum('partnerWinningVoid', BalootPartnerWinningVoid.values, d.partnerWinningVoid),
      declareProjects: pickEnum('declareProjects', BalootDeclareProjects.values, d.declareProjects),
      sequenceBeatsCarre: pick('sequenceBeatsCarre', d.sequenceBeatsCarre),
      trumpSequencePriority: pick('trumpSequencePriority', d.trumpSequencePriority),
      beloteOnLoss: pickEnum('beloteOnLoss', BalootBeloteOnLoss.values, d.beloteOnLoss),
      projectMultiplierCap: j.containsKey('projectMultiplierCap')
          ? j['projectMultiplierCap'] as int?
          : d.projectMultiplierCap,
      mustTrumpWhenPartnerWinning: j['partnerWinningVoid'] == null ? j['mustTrumpWhenPartnerWinning'] as bool? : null,
      sunDoubleOnlyWhenBehind: j['sunDoubleRule'] == null ? j['sunDoubleOnlyWhenBehind'] as bool? : null,
    );
  }

  /// 152 (الصكة).
  final int targetScore;
  final int firstDealer;
  final BalootFirstLead firstLead;

  /// Round 1: after a Sun (or Ashkal), every earlier speaker may still take
  /// it as their own Sun, the earliest first. Off: the first Sun wins.
  final bool sunPriority;

  /// Ashkal (أشكل): the 3rd or 4th speaker, when everybody before has
  /// passed, bids Sun for the partner, who takes the up card.
  final bool ashkal;

  /// Ashkal allowed when the up card is an Ace.
  final bool ashkalOnAce;

  /// Ashkal allowed in round 2 too (Riyadh).
  final bool ashkalInRound2;

  /// A Hokom that nobody overcalls may be turned into Sun by its bidder.
  final bool takerMaySwitchToSun;

  /// Kawesh (كوش): a player whose first five cards are all 7s, 8s and 9s may
  /// annul the deal in round 1; the next dealer deals.
  final bool kawesh;

  /// When everybody passes twice and the up card is an Ace, the first
  /// speaker alone may still bid (a third round).
  final bool aceThirdRound;

  /// Double → triple → four → gahwa (Hokom); double only (Sun).
  final bool doubling;
  final BalootSunDoubleRule sunDoubleRule;

  /// Hokom: a player who cannot follow a side suit must trump (subject to
  /// [partnerWinningVoid]). Off: any card.
  final bool voidMustTrump;

  /// Hokom: must beat the best trump in the trick when able (as limited by
  /// [trumpLedOvertrump]). Off: any trump will do.
  final bool mustOvertrump;
  final BalootTrumpLedOvertrump trumpLedOvertrump;
  final BalootPartnerWinningVoid partnerWinningVoid;
  final BalootDeclareProjects declareProjects;

  /// Among hundreds, a five-card sequence beats four of a kind (default: four
  /// of a kind wins).
  final bool sequenceBeatsCarre;

  /// Hokom: of two sequences equal but for the suit, the trump one wins.
  final bool trumpSequencePriority;
  final BalootBeloteOnLoss beloteOnLoss;

  /// Doubled deals multiply projects by min(level, cap); null = by the level.
  final int? projectMultiplierCap;

  /// The legacy boolean for [partnerWinningVoid].
  bool get mustTrumpWhenPartnerWinning => partnerWinningVoid == BalootPartnerWinningVoid.alwaysTrump;

  Map<String, Object?> toJson() => {
    'targetScore': targetScore,
    'firstDealer': firstDealer,
    'firstLead': firstLead.name,
    'sunPriority': sunPriority,
    'ashkal': ashkal,
    'ashkalOnAce': ashkalOnAce,
    'ashkalInRound2': ashkalInRound2,
    'takerMaySwitchToSun': takerMaySwitchToSun,
    'kawesh': kawesh,
    'aceThirdRound': aceThirdRound,
    'doubling': doubling,
    'sunDoubleRule': sunDoubleRule.name,
    'voidMustTrump': voidMustTrump,
    'mustOvertrump': mustOvertrump,
    'trumpLedOvertrump': trumpLedOvertrump.name,
    'partnerWinningVoid': partnerWinningVoid.name,
    'declareProjects': declareProjects.name,
    'sequenceBeatsCarre': sequenceBeatsCarre,
    'trumpSequencePriority': trumpSequencePriority,
    'beloteOnLoss': beloteOnLoss.name,
    'projectMultiplierCap': projectMultiplierCap,
  };

  @override
  bool operator ==(Object other) {
    if (other is! BalootOptions) return false;
    final a = toJson();
    final b = other.toJson();
    return a.keys.every((k) => a[k] == b[k]);
  }

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

enum BalootPhase { bidding, doubling, playing, over }

/// Steps of one bidding round.
enum BalootBidStage {
  /// Each speaker in turn, once.
  open,

  /// Round 1: earlier speakers may still say Sun (Sun priority, or a Sun
  /// over a Hokom), the earliest first.
  priority,

  /// The Hokom bidder confirms the Hokom or switches to Sun.
  confirm,
}

enum BalootMoveKind {
  /// Bidding: pass (بس). Doubling: decline.
  pass,
  hokom,
  sun,

  /// Sun for the partner (أشكل).
  ashkal,

  /// Keep the Hokom (confirmation step).
  confirm,

  /// Annul a hand of 7s, 8s and 9s (كوش).
  kawesh,

  /// Doubling: double / triple / four / gahwa, by the current level.
  raise,

  /// Before the first card: declare all your projects.
  declareProjects,

  /// Before the first card: declare none.
  skipProjects,
  play,
}

final class BalootMove extends CardMove {
  const BalootMove._(this.kind, {this.suit, this.card, this.locked = false});

  const BalootMove.pass() : this._(BalootMoveKind.pass);

  const BalootMove.hokom(Suit suit) : this._(BalootMoveKind.hokom, suit: suit);

  const BalootMove.sun() : this._(BalootMoveKind.sun);

  const BalootMove.ashkal() : this._(BalootMoveKind.ashkal);

  const BalootMove.confirm() : this._(BalootMoveKind.confirm);

  const BalootMove.kawesh() : this._(BalootMoveKind.kawesh);

  /// Double / triple / four / gahwa. [locked] (مقفول) only for a Hokom
  /// double or four: nobody may lead a trump unless holding only trumps.
  const BalootMove.raise({bool locked = false}) : this._(BalootMoveKind.raise, locked: locked);

  const BalootMove.declareProjects() : this._(BalootMoveKind.declareProjects);

  const BalootMove.skipProjects() : this._(BalootMoveKind.skipProjects);

  const BalootMove.play(PlayingCard card) : this._(BalootMoveKind.play, card: card);

  factory BalootMove.fromJson(Map<String, Object?> j) => BalootMove._(
    BalootMoveKind.values.byName(j['k']! as String),
    suit: j['s'] == null ? null : Suit.fromCode(j['s']! as String),
    card: j['c'] == null ? null : PlayingCard.parse(j['c']! as String),
    locked: (j['l'] as bool?) ?? false,
  );

  final BalootMoveKind kind;
  final Suit? suit;
  final PlayingCard? card;
  final bool locked;

  @override
  Map<String, Object?> toJson() => {
    'k': kind.name,
    if (suit != null) 's': suit!.code,
    if (card != null) 'c': card!.id,
    if (locked) 'l': true,
  };

  @override
  bool operator ==(Object other) =>
      other is BalootMove && other.kind == kind && other.suit == suit && other.card == card && other.locked == locked;

  @override
  int get hashCode => Object.hash(kind, suit, card, locked);

  @override
  String toString() => 'Baloot(${kind.name} ${suit?.code ?? card ?? ''}${locked ? ' locked' : ''})';
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

  /// Four of a kind (كاريه) rather than a sequence.
  bool get isCarre => cards.length == 4 && cards.every((c) => c.rank == cards.first.rank);

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
    this.bidder = -1,
    this.ashkal = false,
    this.locked = false,
    this.countingTeam,
    this.gamePoints = const [0, 0],
    this.projectPoints = const [0, 0],
    this.belotePoints = const [0, 0],
    this.kabootTeam,
    this.winner = -1,
  });

  factory BalootRoundResult.fromJson(Map<String, Object?> j) {
    List<int> ints(String key) => ((j[key] as List?) ?? const [0, 0]).cast<int>();
    final buyer = j['buyer']! as int;
    final made = j['made']! as bool;
    return BalootRoundResult(
      buyer: buyer,
      mode: BalootMode.values.byName(j['mode']! as String),
      trump: j['trump'] == null ? null : Suit.fromCode(j['trump']! as String),
      raw: (j['raw']! as List).cast<int>(),
      points: (j['points']! as List).cast<int>(),
      level: j['level']! as int,
      made: made,
      bidder: (j['bidder'] as int?) ?? buyer,
      ashkal: (j['ashkal'] as bool?) ?? false,
      locked: (j['locked'] as bool?) ?? false,
      countingTeam: j['countingTeam'] as int?,
      gamePoints: ints('gamePoints'),
      projectPoints: ints('projectPoints'),
      belotePoints: ints('belotePoints'),
      kabootTeam: j['kabootTeam'] as int?,
      winner: (j['winner'] as int?) ?? (made ? buyer % 2 : 1 - buyer % 2),
    );
  }

  /// The taker (took the up card).
  final int buyer;

  /// Who made the winning bid (for Ashkal, the taker's partner).
  final int bidder;
  final bool ashkal;
  final BalootMode mode;
  final Suit? trump;

  /// Card points (incl. last trick) per team.
  final List<int> raw;

  /// Game points per team scored for this deal.
  final List<int> points;

  /// 1 plain, 2 double, 3 triple, 4 four; 5 gahwa.
  final int level;
  final bool locked;

  /// The taker's team won the deal.
  final bool made;

  /// The team whose card points were converted (null for a kaboot).
  final int? countingTeam;

  /// Card points converted to game points (before doubling), per team.
  final List<int> gamePoints;

  /// Counted projects per team (before doubling).
  final List<int> projectPoints;

  /// Counted belote per team (who held it).
  final List<int> belotePoints;

  /// The team that took all eight tricks (كبوت), if any.
  final int? kabootTeam;

  /// The team that won the deal.
  final int winner;

  Map<String, Object?> toJson() => {
    'buyer': buyer,
    'bidder': bidder,
    'ashkal': ashkal,
    'mode': mode.name,
    'trump': trump?.code,
    'raw': raw,
    'points': points,
    'level': level,
    'locked': locked,
    'made': made,
    'countingTeam': countingTeam,
    'gamePoints': gamePoints,
    'projectPoints': projectPoints,
    'belotePoints': belotePoints,
    'kabootTeam': kabootTeam,
    'winner': winner,
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
    this.bidStage = BalootBidStage.open,
    this.bidder = -1,
    this.ashkal = false,
    this.locked = false,
    List<bool>? projectsDecided,
  }) : projectsDecided = projectsDecided ?? List.filled(4, false);

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
    bidStage: j['bidStage'] == null ? BalootBidStage.open : BalootBidStage.values.byName(j['bidStage']! as String),
    bidder: (j['bidder'] as int?) ?? (j['buyer']! as int),
    ashkal: (j['ashkal'] as bool?) ?? false,
    locked: (j['locked'] as bool?) ?? false,
    projectsDecided: (j['projectsDecided'] as List?)?.cast<bool>().toList(),
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

  /// The turned-up card (الورقة المكشوفة) until the taker takes it.
  PlayingCard? upCard;

  /// The card turned up this deal (public; stays known after the taker
  /// takes it).
  PlayingCard? turnedUp;
  int turn;

  /// 1, 2, or 3 (the Ace third round, option `aceThirdRound`).
  int bidRound;
  BalootBidStage bidStage;

  /// Seats still to speak in this bidding stage, in order.
  List<int> bidQueue;
  BalootMode? mode;
  Suit? trump;

  /// The seat whose bid stands (for Ashkal, the caller); -1 while nobody bid.
  int bidder;

  /// The standing bid is an Ashkal.
  bool ashkal;

  /// The taker (المشتري): takes the up card; -1 while nobody bid.
  int buyer;

  /// 1 plain, 2 double, 3 triple, 4 four.
  int level;
  bool gahwa;

  /// Locked play (مقفول): nobody may lead a trump unless holding only trumps.
  bool locked;

  /// The defender who doubled (-1 if none).
  int doubler;
  List<int> doublingQueue;
  Trick? trick;
  List<Trick> tricks;

  /// Declared projects of the deal (only the best team's count).
  List<BalootProject> projects;

  /// Manual declaration: the seats that have declared or skipped.
  List<bool> projectsDecided;

  /// Seat that held K+Q of trumps when play started (belote), or -1.
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

  /// The first speaker (the dealer's right).
  int get firstPlayer => (dealer + 1) % 4;

  /// 0 for the first speaker (dealer's right) … 3 for the dealer.
  int speakerIndex(int seat) => (seat - dealer + 3) % 4;

  /// The team that made the last double / triple / four / gahwa, or null.
  int? get lastRaiserTeam {
    if (gahwa || level == 3) return buyer % 2;
    if (level == 2 || level == 4) return 1 - buyer % 2;
    return null;
  }

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
    bidStage = BalootBidStage.open;
    bidQueue = [for (var i = 0; i < 4; i++) (firstPlayer + i) % 4];
    turn = bidQueue.first;
    mode = null;
    trump = null;
    bidder = -1;
    ashkal = false;
    buyer = -1;
    level = 1;
    gahwa = false;
    locked = false;
    doubler = -1;
    doublingQueue = [];
    trick = null;
    tricks = [];
    projects = [];
    projectsDecided = List.filled(4, false);
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
    bidStage: bidStage,
    bidder: bidder,
    ashkal: ashkal,
    locked: locked,
    projectsDecided: List.of(projectsDecided),
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
    'bidStage': bidStage.name,
    'bidQueue': bidQueue,
    'mode': mode?.name,
    'trump': trump?.code,
    'bidder': bidder,
    'ashkal': ashkal,
    'buyer': buyer,
    'level': level,
    'gahwa': gahwa,
    'locked': locked,
    'doubler': doubler,
    'doublingQueue': doublingQueue,
    'trick': trick?.toJson(),
    'tricks': [for (final t in tricks) t.toJson()],
    'projects': [for (final p in projects) p.toJson()],
    'projectsDecided': projectsDecided,
    'belote': belote,
    'teamScores': teamScores,
    'results': [for (final r in results) r.toJson()],
    'winnerTeam': winnerTeam,
  };
}
