/// Trix (تركس): options, moves and the serialisable match state.
library;

import '../core/card_game.dart';
import '../core/card_rng.dart';
import '../core/deck.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';

/// The contracts ("games") of a kingdom.
enum TrixContract {
  /// King of hearts: شيخ الكبة (colloquially الختيار).
  king,

  /// Queens (البنات).
  queens,

  /// Diamonds (الديناري).
  diamonds,

  /// Collections / tricks (اللطوش).
  ltoush,

  /// The layout game (التركس).
  trix,

  /// Complex (الكومبلكس): king, queens, diamonds and ltoush in one deal.
  complex,
}

enum TrixMode {
  /// Five contracts per kingdom: king, queens, diamonds, ltoush, trix
  /// (menu entry «تركس», 20 deals).
  classic,

  /// Two contracts per kingdom: complex and trix (menu entry
  /// «تركس كومبلكس», 8 deals).
  complex,
}

/// Who owns the first kingdom.
enum TrixFirstOwner {
  /// The holder of the 7♥ (سبعة الكبة) in the first deal of the match: the
  /// Jordanian default.
  sevenOfHearts,

  /// Always [TrixOptions.firstOwner].
  fixedSeat,
}

/// How the doubling answers become public.
enum TrixDoublingReveal {
  /// Every seat answers in turn, but nobody sees another seat's answer until
  /// all four have answered; then every doubled card is shown at once (the
  /// Jordanian default).
  simultaneous,

  /// Each double is public the moment it is made, so later seats see the
  /// earlier doubles before answering.
  sequential,
}

/// Individual game: the doubler himself takes his own doubled card.
///
/// "Forced" means somebody else led the trick and the doubler followed with
/// the doubled card, which won; "self-led" means the doubler led that trick
/// (so he led the doubled card) and it won.
enum TrixSelfCapture {
  /// Forced: the doubler pays double and the trick's leader gains the
  /// normal value. Self-led: the doubler pays the normal value (default).
  leaderGains,

  /// Forced: as [leaderGains]. Self-led: the doubler pays double, nobody
  /// gains.
  leaderGainsStrict,

  /// Always the normal value, nobody gains.
  normalValue,

  /// Always double, nobody gains (the engine's earlier rule).
  doubleNoBonus,
}

/// Partnership game: the doubler or his partner takes the doubled card.
enum TrixPartnerCapture {
  /// The taker pays double and nobody gains (default).
  noBonus,

  /// The taker pays double and the other team gains the normal value (the
  /// trick's leader when he is an opponent, else the seat after him); a
  /// doubler who led his own doubled card and won it pays the normal value
  /// only, and nobody gains.
  opponentsGain,

  /// The taker pays the normal value, nobody gains.
  normalValue,
}

/// Stable [CardEvent.detail] ids of the Trix doubling events.
abstract final class TrixEventDetail {
  /// Simultaneous doubling: a seat answered (a [CardEventType.doubled] event
  /// without cards; it does not say whether the seat doubled).
  static const String doublingAnswered = 'doublingAnswered';

  /// Simultaneous doubling: the reveal after the fourth answer (one
  /// [CardEventType.doubled] event with cards per doubling seat, in seat
  /// order from the owner).
  static const String doublingRevealed = 'doublingRevealed';
}

/// Trix options. `const TrixOptions()` is Trix as commonly played in Jordan
/// ([TrixOptions.jordan]); see RULES.md §2.
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
    this.kingOnAceOfHearts = false,
    this.kingRulesInComplex = true,
    this.firstOwnerRule = TrixFirstOwner.sevenOfHearts,
    this.firstOwner = 0,
    this.doublingReveal = TrixDoublingReveal.simultaneous,
    this.selfCaptureRule = TrixSelfCapture.leaderGains,
    this.partnerCaptureRule = TrixPartnerCapture.noBonus,
  });

  /// The Jordanian preset (identical to `const TrixOptions()`): the four
  /// menu entries are «تركس», «تركس شراكة» (`partnership: true`),
  /// «تركس كومبلكس» (`mode: complex`) and «كومبلكس شراكة» (both).
  const TrixOptions.jordan({bool partnership = false, TrixMode mode = TrixMode.classic})
    : this(partnership: partnership, mode: mode);

  /// The engine's earlier defaults, kept as a named house-rule set: seat 0
  /// always owns the first kingdom, each double is public as soon as it is
  /// made, and a doubler who takes his own doubled card pays double with no
  /// bonus to anyone (the open-doubling scorekeeper rule).
  const TrixOptions.openDoubling({bool partnership = false, TrixMode mode = TrixMode.classic})
    : this(
        partnership: partnership,
        mode: mode,
        firstOwnerRule: TrixFirstOwner.fixedSeat,
        doublingReveal: TrixDoublingReveal.sequential,
        selfCaptureRule: TrixSelfCapture.doubleNoBonus,
      );

  /// Reads [toJson]. Every key may be missing (older saves): it then takes
  /// its Jordanian default.
  factory TrixOptions.fromJson(Map<String, Object?> j) {
    const d = TrixOptions();
    T read<T>(String key, T fallback) => j[key] == null ? fallback : j[key]! as T;
    E readEnum<E extends Enum>(String key, List<E> values, E fallback) =>
        j[key] == null ? fallback : values.byName(j[key]! as String);
    return TrixOptions(
      partnership: read('partnership', d.partnership),
      mode: readEnum('mode', TrixMode.values, d.mode),
      doubling: read('doubling', d.doubling),
      kingPenalty: read('kingPenalty', d.kingPenalty),
      queenPenalty: read('queenPenalty', d.queenPenalty),
      diamondPenalty: read('diamondPenalty', d.diamondPenalty),
      trickPenalty: read('trickPenalty', d.trickPenalty),
      trixScores: j['trixScores'] == null ? d.trixScores : List<int>.unmodifiable((j['trixScores']! as List).cast<int>()),
      noHeartLeadInKing: read('noHeartLeadInKing', d.noHeartLeadInKing),
      kingMustBeDiscarded: read('kingMustBeDiscarded', d.kingMustBeDiscarded),
      kingOnAceOfHearts: read('kingOnAceOfHearts', d.kingOnAceOfHearts),
      kingRulesInComplex: read('kingRulesInComplex', d.kingRulesInComplex),
      firstOwnerRule: readEnum('firstOwnerRule', TrixFirstOwner.values, d.firstOwnerRule),
      firstOwner: read('firstOwner', d.firstOwner),
      doublingReveal: readEnum('doublingReveal', TrixDoublingReveal.values, d.doublingReveal),
      selfCaptureRule: readEnum('selfCaptureRule', TrixSelfCapture.values, d.selfCaptureRule),
      partnerCaptureRule: readEnum('partnerCaptureRule', TrixPartnerCapture.values, d.partnerCaptureRule),
    );
  }

  /// Partners sit opposite (seats 0 & 2, 1 & 3) and add their scores
  /// (شراكة).
  final bool partnership;
  final TrixMode mode;

  /// The holder of the king of hearts / a queen may double it (دبل).
  final bool doubling;
  final int kingPenalty;
  final int queenPenalty;
  final int diamondPenalty;
  final int trickPenalty;

  /// Trix scores by finishing place.
  final List<int> trixScores;

  /// King rules: hearts may not be led while the leader holds another suit.
  final bool noHeartLeadInKing;

  /// King rules: a player who cannot follow the led suit and holds K♥ must
  /// throw it.
  final bool kingMustBeDiscarded;

  /// King rules (off by default): on a heart trick where A♥ is already
  /// played, the holder of K♥ must play it.
  final bool kingOnAceOfHearts;

  /// The three king rules also apply in the complex contract.
  final bool kingRulesInComplex;

  /// Who owns the first kingdom (then the next seat, and so on).
  final TrixFirstOwner firstOwnerRule;

  /// Owner of the first kingdom when [firstOwnerRule] is
  /// [TrixFirstOwner.fixedSeat].
  final int firstOwner;

  final TrixDoublingReveal doublingReveal;

  /// Individual game: scoring when the doubler takes his own doubled card.
  final TrixSelfCapture selfCaptureRule;

  /// Partnership game: scoring when the doubler's own team takes it.
  final TrixPartnerCapture partnerCaptureRule;

  /// A copy with the given options changed (the UI's house-rule toggles).
  TrixOptions copyWith({
    bool? partnership,
    TrixMode? mode,
    bool? doubling,
    int? kingPenalty,
    int? queenPenalty,
    int? diamondPenalty,
    int? trickPenalty,
    List<int>? trixScores,
    bool? noHeartLeadInKing,
    bool? kingMustBeDiscarded,
    bool? kingOnAceOfHearts,
    bool? kingRulesInComplex,
    TrixFirstOwner? firstOwnerRule,
    int? firstOwner,
    TrixDoublingReveal? doublingReveal,
    TrixSelfCapture? selfCaptureRule,
    TrixPartnerCapture? partnerCaptureRule,
  }) => TrixOptions(
    partnership: partnership ?? this.partnership,
    mode: mode ?? this.mode,
    doubling: doubling ?? this.doubling,
    kingPenalty: kingPenalty ?? this.kingPenalty,
    queenPenalty: queenPenalty ?? this.queenPenalty,
    diamondPenalty: diamondPenalty ?? this.diamondPenalty,
    trickPenalty: trickPenalty ?? this.trickPenalty,
    trixScores: trixScores ?? this.trixScores,
    noHeartLeadInKing: noHeartLeadInKing ?? this.noHeartLeadInKing,
    kingMustBeDiscarded: kingMustBeDiscarded ?? this.kingMustBeDiscarded,
    kingOnAceOfHearts: kingOnAceOfHearts ?? this.kingOnAceOfHearts,
    kingRulesInComplex: kingRulesInComplex ?? this.kingRulesInComplex,
    firstOwnerRule: firstOwnerRule ?? this.firstOwnerRule,
    firstOwner: firstOwner ?? this.firstOwner,
    doublingReveal: doublingReveal ?? this.doublingReveal,
    selfCaptureRule: selfCaptureRule ?? this.selfCaptureRule,
    partnerCaptureRule: partnerCaptureRule ?? this.partnerCaptureRule,
  );

  List<TrixContract> get contracts => mode == TrixMode.classic
      ? const [TrixContract.king, TrixContract.queens, TrixContract.diamonds, TrixContract.ltoush, TrixContract.trix]
      : const [TrixContract.complex, TrixContract.trix];

  /// Sum of every seat's points in an undoubled deal of [contract]
  /// (−75, −100, −130, −195, −500 or +500 with the default values).
  int undoubledTotal(TrixContract contract) => switch (contract) {
    TrixContract.king => -kingPenalty,
    TrixContract.queens => -4 * queenPenalty,
    TrixContract.diamonds => -13 * diamondPenalty,
    TrixContract.ltoush => -13 * trickPenalty,
    TrixContract.trix => trixScores.fold(0, (a, b) => a + b),
    TrixContract.complex => -kingPenalty - 4 * queenPenalty - 13 * diamondPenalty - 13 * trickPenalty,
  };

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
    'kingOnAceOfHearts': kingOnAceOfHearts,
    'kingRulesInComplex': kingRulesInComplex,
    'firstOwnerRule': firstOwnerRule.name,
    'firstOwner': firstOwner,
    'doublingReveal': doublingReveal.name,
    'selfCaptureRule': selfCaptureRule.name,
    'partnerCaptureRule': partnerCaptureRule.name,
  };

  @override
  bool operator ==(Object other) =>
      other is TrixOptions &&
      other.partnership == partnership &&
      other.mode == mode &&
      other.doubling == doubling &&
      other.kingPenalty == kingPenalty &&
      other.queenPenalty == queenPenalty &&
      other.diamondPenalty == diamondPenalty &&
      other.trickPenalty == trickPenalty &&
      other.trixScores.length == trixScores.length &&
      Iterable<int>.generate(trixScores.length).every((i) => other.trixScores[i] == trixScores[i]) &&
      other.noHeartLeadInKing == noHeartLeadInKing &&
      other.kingMustBeDiscarded == kingMustBeDiscarded &&
      other.kingOnAceOfHearts == kingOnAceOfHearts &&
      other.kingRulesInComplex == kingRulesInComplex &&
      other.firstOwnerRule == firstOwnerRule &&
      other.firstOwner == firstOwner &&
      other.doublingReveal == doublingReveal &&
      other.selfCaptureRule == selfCaptureRule &&
      other.partnerCaptureRule == partnerCaptureRule;

  @override
  int get hashCode => Object.hash(
    partnership,
    mode,
    doubling,
    kingPenalty,
    queenPenalty,
    diamondPenalty,
    trickPenalty,
    Object.hashAll(trixScores),
    noHeartLeadInKing,
    kingMustBeDiscarded,
    kingOnAceOfHearts,
    kingRulesInComplex,
    firstOwnerRule,
    firstOwner,
    doublingReveal,
    selfCaptureRule,
    partnerCaptureRule,
  );
}

/// The four games-menu entries, all with the Jordanian rules (RULES.md §2).
enum TrixPreset {
  /// «تركس»: classic, each for himself.
  trix(TrixOptions.jordan()),

  /// «تركس شراكة»: classic, seats 0 & 2 against 1 & 3.
  trixPartnership(TrixOptions.jordan(partnership: true)),

  /// «تركس كومبلكس»: Complex, each for himself.
  complex(TrixOptions.jordan(mode: TrixMode.complex)),

  /// «كومبلكس شراكة»: Complex in partnership.
  complexPartnership(TrixOptions.jordan(mode: TrixMode.complex, partnership: true));

  const TrixPreset(this.options);

  final TrixOptions options;
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

/// The 7♥: its holder in the first deal owns the first kingdom.
final PlayingCard sevenOfHearts = PlayingCard(Suit.hearts, Rank.seven);

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
    required this.pendingDoubles,
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
    pendingDoubles: {},
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
    doubled: _doublesFromJson(j['doubled']),
    pendingDoubles: _doublesFromJson(j['pendingDoubles']),
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

  /// Publicly doubled card → the seat that doubled it.
  Map<PlayingCard, int> doubled;

  /// Simultaneous doubling: answers not revealed yet (card → doubler). Only
  /// the doubling seat itself may look at its own entries; everything moves
  /// to [doubled] once all four seats have answered.
  Map<PlayingCard, int> pendingDoubles;

  /// How many seats answered in this doubling phase (public): the owner
  /// first, then the next seats in turn.
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

  /// The doubles [seat] can see: the public ones plus its own answer while
  /// the simultaneous reveal is pending.
  Map<PlayingCard, int> doublesVisibleTo(int seat) => {
    ...doubled,
    for (final e in pendingDoubles.entries)
      if (e.value == seat) e.key: e.value,
  };

  /// Seats that already answered in the current doubling phase.
  List<int> get doublingAnswered => [for (var i = 0; i < doublingAnswers; i++) (owner + i) % 4];

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
    if (dealNumber == 0 && options.firstOwnerRule == TrixFirstOwner.sevenOfHearts) {
      // The holder of the 7♥ in the first deal owns the first kingdom.
      final holder = hands.indexWhere((h) => h.contains(sevenOfHearts));
      if (holder >= 0) owner = holder;
    }
    phase = TrixPhase.contract;
    contract = null;
    turn = owner;
    doubled = {};
    pendingDoubles = {};
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
    pendingDoubles: Map.of(pendingDoubles),
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
    'doubled': _doublesToJson(doubled),
    'pendingDoubles': _doublesToJson(pendingDoubles),
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

List<List<Object>> _doublesToJson(Map<PlayingCard, int> doubles) => [
  for (final c in sortedCards(doubles.keys)) [c.id, doubles[c]!],
];

Map<PlayingCard, int> _doublesFromJson(Object? json) => {
  if (json != null)
    for (final d in json as List) PlayingCard.parse((d as List)[0] as String): d[1] as int,
};
