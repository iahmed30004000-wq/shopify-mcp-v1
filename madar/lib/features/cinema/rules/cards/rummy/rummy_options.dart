/// Options of the rummy games (Hand هاند, Konkan كونكان).
///
/// `const RummyOptions()` and `const RummyOptions.hand()` are Hand as
/// commonly played in Jordan; `const RummyOptions.konkan()` is Konkan. Every
/// other rule a Jordanian table may use is an option below (see RULES.md,
/// sections Hand and Konkan).
library;

/// Which game the rummy engine plays.
enum RummyVariant { hand, konkan }

/// How a match ends.
enum RummyMatchEnd {
  /// After a fixed number of scored rounds ([RummyOptions.rounds]).
  rounds,

  /// In the round where a total reaches [RummyOptions.targetScore]; the lowest
  /// total wins.
  targetScore,

  /// A player whose total goes over [RummyOptions.eliminationScore] is out;
  /// the last one left wins (Konkan default).
  elimination,
}

/// What the top discard may be taken for.
enum RummyDiscardUse {
  /// Only to be put at once into a new meld with at least two cards from the
  /// hand (Jordan default).
  newMeldOnly,

  /// After opening it may also be laid off or used in a wild swap.
  any,
}

/// How the wild of a set of two natural cards and a wild is freed.
enum RummySetWildSwap {
  /// Only by laying down both missing suits at once (the set becomes four
  /// natural cards). A single natural may be added only when its owner is
  /// about to go out or another player holds one card (Jordan default).
  bothMissing,

  /// Either missing suit frees it, and a single natural may always be added.
  anyMissingSuit,
}

/// Who deals the next round.
enum RummyDealerRule {
  /// The seat with the most points in the round just scored (Jordan default).
  loserDeals,

  /// The next seat.
  rotate,
}

/// What happens when the stock runs out.
enum RummyStockEnd {
  /// The discards except the top card are shuffled into a new stock, at most
  /// [RummyOptions.maxStockRecycles] times; then the round is void.
  reshuffle,

  /// The round is void as soon as the stock, at the end of a turn, holds no
  /// more cards than there are players.
  voidAtPlayers,

  /// The discards except the top card are turned over without shuffling, as
  /// often as needed (the engine voids the round after
  /// [RummyOptions.flipSafetyCap] turns, a safety net only).
  flipNoShuffle,
}

/// What happens when players tie for the lowest total at the end.
enum RummyTieBreak {
  /// Extra rounds until one player (team) is alone lowest, at most
  /// [RummyOptions.maxTieBreakRounds], then a shared win.
  extraRounds,

  /// A shared win.
  shared,
}

class RummyOptions {
  /// Hand as commonly played in Jordan (every default below); pass
  /// `variant: RummyVariant.konkan` and the Konkan values, or use
  /// [RummyOptions.konkan], for Konkan.
  const RummyOptions({
    this.variant = RummyVariant.hand,
    this.players = 4,
    this.decks = 2,
    this.jokers = 2,
    this.handSize = 14,
    this.starterFirstTurnDiscardOnly = true,
    this.noGoOutOnFirstTurn = true,
    this.maxWildsPerMeld = 1,
    this.wildIndicator = false,
    this.openingThreshold = 51,
    this.aceLowOpeningValue = 11,
    this.aceHighOpeningValue = 11,
    this.openingRequiresRun = false,
    this.openingMustBeatPrevious = false,
    this.openingMustUseDiscard = false,
    this.oneTurnFinishWaivesThreshold = true,
    this.discardUse = RummyDiscardUse.newMeldOnly,
    this.jokerSwap = true,
    this.setWildSwap = RummySetWildSwap.bothMissing,
    this.swappedWildMustBeUsed = false,
    this.fullHandOwnMeldsOnly = true,
    this.winnerScore = -30,
    this.handWinnerScore = -60,
    this.handMultiplier = 2,
    this.notOpenedPenalty = 100,
    this.acePenalty = 11,
    this.jokerPenalty = 15,
    this.bonusWildLastDiscard = false,
    this.bonusOneColour = false,
    this.bonusOneSuit = false,
    this.partnership = false,
    this.partnerOfWinnerPays = false,
    this.matchEnd = RummyMatchEnd.rounds,
    this.rounds = 5,
    this.targetScore = 500,
    this.eliminationScore = 301,
    this.voidRoundsCount = false,
    this.tieBreak = RummyTieBreak.extraRounds,
    this.maxTieBreakRounds = 3,
    this.dealerRule = RummyDealerRule.loserDeals,
    this.stockEnd = RummyStockEnd.reshuffle,
    this.maxStockRecycles = 2,
    this.pairsRedeal = true,
  }) : assert(players >= 2 && players <= 4);

  /// Hand (هاند) as commonly played in Jordan: two packs and two jokers (106
  /// cards), 14 cards and 15 for the starter, whose first turn is a discard,
  /// 51 to open (ace 11, also in A-2-3), one wild per meld, the top discard
  /// only into a new meld, −30 for going out, −60 and everyone else doubled
  /// for a full hand, 5 rounds.
  const RummyOptions.hand({
    int players = 4,
    int rounds = 5,
    int openingThreshold = 51,
    int jokerPenalty = 15,
    bool partnership = false,
  }) : this(
         players: players,
         rounds: rounds,
         openingThreshold: openingThreshold,
         jokerPenalty: jokerPenalty,
         partnership: partnership,
       );

  /// Partnership Hand: four players, partners opposite (seats 0 & 2, 1 & 3);
  /// the winner's partner is not counted and the other team pays both hands.
  const RummyOptions.handPartnership({int rounds = 5, int openingThreshold = 51})
    : this(players: 4, rounds: rounds, openingThreshold: openingThreshold, partnership: true);

  /// Hand with the turned-up indicator card (ورقة الكشف), the Levantine home
  /// table: the two aces of the indicator's suit are wild (the jokers become
  /// natural aces of that suit), 7 rounds, and the round is void when the
  /// stock runs down to the number of players.
  const RummyOptions.handIndicator({int players = 4, int rounds = 7})
    : this(players: players, rounds: rounds, wildIndicator: true, stockEnd: RummyStockEnd.voidAtPlayers);

  /// Konkan (كونكان) as commonly played in Jordan (low confidence, see
  /// RULES.md): the Hand core, nothing for going out, a one-turn finish
  /// doubles everyone else, a joker left in hand costs 25, and a player whose
  /// total goes over 301 is out; the last one left wins.
  const RummyOptions.konkan({
    int players = 4,
    RummyMatchEnd matchEnd = RummyMatchEnd.elimination,
    int eliminationScore = 301,
    int targetScore = 500,
    int rounds = 5,
    int openingThreshold = 51,
    bool openingMustUseDiscard = false,
  }) : this(
         variant: RummyVariant.konkan,
         players: players,
         winnerScore: 0,
         handWinnerScore: 0,
         handMultiplier: 2,
         jokerPenalty: 25,
         matchEnd: matchEnd,
         eliminationScore: eliminationScore,
         targetScore: targetScore,
         rounds: rounds,
         openingThreshold: openingThreshold,
         openingMustUseDiscard: openingMustUseDiscard,
       );

  /// The rules of saves written before the Jordanian defaults: options they
  /// did not store take these values, so a match in progress keeps its rules.
  const RummyOptions._legacy({required RummyVariant variant})
    : this(
        variant: variant,
        jokers: 4,
        starterFirstTurnDiscardOnly: false,
        noGoOutOnFirstTurn: false,
        maxWildsPerMeld: 4,
        aceLowOpeningValue: 1,
        oneTurnFinishWaivesThreshold: false,
        discardUse: RummyDiscardUse.any,
        setWildSwap: RummySetWildSwap.anyMissingSuit,
        fullHandOwnMeldsOnly: false,
        jokerPenalty: 25,
        voidRoundsCount: true,
        tieBreak: RummyTieBreak.shared,
        dealerRule: RummyDealerRule.rotate,
        pairsRedeal: false,
      );

  /// Reads [toJson]. Keys missing from a save made before the Jordanian
  /// defaults (no `v` key) take the old engine's values.
  factory RummyOptions.fromJson(Map<String, Object?> j) {
    final variant = RummyVariant.values.byName(j['variant']! as String);
    final d = j['v'] == null ? RummyOptions._legacy(variant: variant) : RummyOptions(variant: variant);
    T pick<T>(String key, T fallback) => (j[key] as T?) ?? fallback;
    E pickEnum<E extends Enum>(List<E> values, String key, E fallback) =>
        j[key] == null ? fallback : values.byName(j[key]! as String);
    return RummyOptions(
      variant: variant,
      players: pick('players', d.players),
      decks: pick('decks', d.decks),
      jokers: pick('jokers', d.jokers),
      handSize: pick('handSize', d.handSize),
      starterFirstTurnDiscardOnly: pick('starterFirstTurnDiscardOnly', d.starterFirstTurnDiscardOnly),
      noGoOutOnFirstTurn: pick('noGoOutOnFirstTurn', d.noGoOutOnFirstTurn),
      maxWildsPerMeld: pick('maxWildsPerMeld', d.maxWildsPerMeld),
      wildIndicator: pick('wildIndicator', d.wildIndicator),
      openingThreshold: pick('openingThreshold', d.openingThreshold),
      aceLowOpeningValue: pick('aceLowOpeningValue', d.aceLowOpeningValue),
      aceHighOpeningValue: pick('aceHighOpeningValue', d.aceHighOpeningValue),
      openingRequiresRun: pick('openingRequiresRun', d.openingRequiresRun),
      openingMustBeatPrevious: pick('openingMustBeatPrevious', d.openingMustBeatPrevious),
      openingMustUseDiscard: pick('openingMustUseDiscard', d.openingMustUseDiscard),
      oneTurnFinishWaivesThreshold: pick('oneTurnFinishWaivesThreshold', d.oneTurnFinishWaivesThreshold),
      discardUse: pickEnum(RummyDiscardUse.values, 'discardUse', d.discardUse),
      jokerSwap: pick('jokerSwap', d.jokerSwap),
      setWildSwap: pickEnum(RummySetWildSwap.values, 'setWildSwap', d.setWildSwap),
      swappedWildMustBeUsed: pick('swappedWildMustBeUsed', d.swappedWildMustBeUsed),
      fullHandOwnMeldsOnly: pick('fullHandOwnMeldsOnly', d.fullHandOwnMeldsOnly),
      winnerScore: pick('winnerScore', d.winnerScore),
      handWinnerScore: pick('handWinnerScore', d.handWinnerScore),
      handMultiplier: pick('handMultiplier', d.handMultiplier),
      notOpenedPenalty: pick('notOpenedPenalty', d.notOpenedPenalty),
      acePenalty: pick('acePenalty', d.acePenalty),
      jokerPenalty: pick('jokerPenalty', d.jokerPenalty),
      bonusWildLastDiscard: pick('bonusWildLastDiscard', d.bonusWildLastDiscard),
      bonusOneColour: pick('bonusOneColour', d.bonusOneColour),
      bonusOneSuit: pick('bonusOneSuit', d.bonusOneSuit),
      partnership: pick('partnership', d.partnership),
      partnerOfWinnerPays: pick('partnerOfWinnerPays', d.partnerOfWinnerPays),
      matchEnd: pickEnum(RummyMatchEnd.values, 'matchEnd', d.matchEnd),
      rounds: pick('rounds', d.rounds),
      targetScore: pick('targetScore', d.targetScore),
      eliminationScore: pick('eliminationScore', d.eliminationScore),
      voidRoundsCount: pick('voidRoundsCount', d.voidRoundsCount),
      tieBreak: pickEnum(RummyTieBreak.values, 'tieBreak', d.tieBreak),
      maxTieBreakRounds: pick('maxTieBreakRounds', d.maxTieBreakRounds),
      dealerRule: pickEnum(RummyDealerRule.values, 'dealerRule', d.dealerRule),
      stockEnd: pickEnum(RummyStockEnd.values, 'stockEnd', d.stockEnd),
      maxStockRecycles: pick('maxStockRecycles', d.maxStockRecycles),
      pairsRedeal: pick('pairsRedeal', d.pairsRedeal),
    );
  }

  /// Match lengths offered for Hand (5 is the Jordanian default).
  static const List<int> roundChoices = [5, 7];

  /// Opening minimums offered (51 is the default).
  static const List<int> openingThresholdChoices = [51, 61, 71, 91];

  /// Joker penalties offered (15 Hand, 25 Konkan).
  static const List<int> jokerPenaltyChoices = [15, 25, 50];

  /// Konkan elimination scores offered (over 301 is the default).
  static const List<int> eliminationChoices = [301, 101];

  /// A round number that is void this many times in a row is skipped with
  /// no points and counts as played (a safety net).
  static const int maxVoidRepeats = 3;

  /// With [RummyStockEnd.flipNoShuffle] the round is void after this many
  /// turn-overs (a safety net; a real table never gets there).
  static const int flipSafetyCap = 10;

  final RummyVariant variant;

  /// 2–4 players.
  final int players;
  final int decks;

  /// Printed jokers in the deck (2).
  final int jokers;

  /// Cards per player (14); the starter (the seat after the dealer) gets one
  /// more.
  final int handSize;

  /// The starter's first turn is only a discard (no draw, no lay-down).
  final bool starterFirstTurnDiscardOnly;

  /// Nobody may go out on their first turn: a lay-down on a seat's first
  /// turn must leave at least two cards in hand.
  final bool noGoOutOnFirstTurn;

  /// Wild cards allowed in one meld (1). A meld also always has more natural
  /// cards than wilds.
  final int maxWildsPerMeld;

  /// A card turned up after the deal (ورقة الكشف) makes the two aces of its
  /// suit wild and the two jokers natural aces of that suit; an ace turned up
  /// leaves the jokers wild.
  final bool wildIndicator;

  /// Minimum total of a player's first lay-down (51).
  final int openingThreshold;

  /// Opening value of an ace in A-2-3 (11; 1 as a variant).
  final int aceLowOpeningValue;

  /// Opening value of an ace in Q-K-A (11; 10 as a variant). An ace in a set
  /// always counts 11.
  final int aceHighOpeningValue;

  /// The opening must contain a run.
  final bool openingRequiresRun;

  /// Each later opening in a round must total more than the highest opening
  /// so far.
  final bool openingMustBeatPrevious;

  /// A closed player may open only in a turn where they took the top discard
  /// (it is then part of the opening); a one-turn finish is exempt.
  final bool openingMustUseDiscard;

  /// A closed player who lays down every card in one turn needs no opening
  /// minimum (a `finish` move).
  final bool oneTurnFinishWaivesThreshold;
  final RummyDiscardUse discardUse;

  /// An opened player may take a table wild by putting the natural card it
  /// stands for in its place.
  final bool jokerSwap;
  final RummySetWildSwap setWildSwap;

  /// A wild freed by a swap must be laid down again before the discard.
  final bool swappedWildMustBeUsed;

  /// A one-turn finish that lays off on (or swaps from) a meld already on
  /// the table when the turn began is a normal finish (ضمون), not a hand.
  final bool fullHandOwnMeldsOnly;

  /// Score of the player who goes out (negative is good).
  final int winnerScore;

  /// … after a full hand (هاند / كونكان): gone out in one turn from a closed
  /// hand.
  final int handWinnerScore;

  /// Everyone else's points are multiplied by this after a full hand.
  final int handMultiplier;

  /// Penalty of a player who never opened (whatever their cards).
  final int notOpenedPenalty;
  final int acePenalty;

  /// A wild card left in hand.
  final int jokerPenalty;

  /// A full hand whose last discard is a wild is worth double (Gulf /
  /// Egyptian tables).
  final bool bonusWildLastDiscard;

  /// A full hand in one colour (wilds excepted) is worth double.
  final bool bonusOneColour;

  /// A full hand in one suit (wilds excepted) is worth four times.
  final bool bonusOneSuit;

  /// Four players in two partnerships (seats 0 & 2 against 1 & 3).
  final bool partnership;

  /// Partnership: the winner's partner's own cards are added to the winning
  /// team (not doubled).
  final bool partnerOfWinnerPays;
  final RummyMatchEnd matchEnd;

  /// Scored rounds of a [RummyMatchEnd.rounds] match (5; 7 as a variant).
  final int rounds;
  final int targetScore;

  /// A total over this is eliminated ([RummyMatchEnd.elimination]).
  final int eliminationScore;

  /// A void round (stock exhausted) counts toward [rounds].
  final bool voidRoundsCount;
  final RummyTieBreak tieBreak;
  final int maxTieBreakRounds;
  final RummyDealerRule dealerRule;
  final RummyStockEnd stockEnd;

  /// Reshuffles allowed per round with [RummyStockEnd.reshuffle].
  final int maxStockRecycles;

  /// A player dealt four identical pairs (or three and a joker, or two and
  /// both jokers) may cancel the deal before the first discard.
  final bool pairsRedeal;

  bool get isKonkan => variant == RummyVariant.konkan;

  /// Null when the combination is supported, else an error id.
  String? get invalidReason {
    if (players < 2 || players > 4) return 'players';
    if (maxWildsPerMeld < 1) return 'maxWildsPerMeld';
    if (partnership && players != 4) return 'partnershipNeedsFourPlayers';
    if (partnership && matchEnd == RummyMatchEnd.elimination) return 'partnershipWithElimination';
    if (maxWildsPerMeld > 1 && setWildSwap == RummySetWildSwap.bothMissing) return 'bothMissingNeedsOneWild';
    if (wildIndicator && jokers != 2) return 'indicatorNeedsTwoJokers';
    if (jokers < 0 || jokers > 4 || decks < 1) return 'deck';
    final left = decks * 52 + jokers - handSize * players - 1 - (wildIndicator ? 1 : 0);
    if (handSize < 3 || left <= players) return 'handSize';
    return null;
  }

  RummyOptions copyWith({
    RummyVariant? variant,
    int? players,
    int? decks,
    int? jokers,
    int? handSize,
    bool? starterFirstTurnDiscardOnly,
    bool? noGoOutOnFirstTurn,
    int? maxWildsPerMeld,
    bool? wildIndicator,
    int? openingThreshold,
    int? aceLowOpeningValue,
    int? aceHighOpeningValue,
    bool? openingRequiresRun,
    bool? openingMustBeatPrevious,
    bool? openingMustUseDiscard,
    bool? oneTurnFinishWaivesThreshold,
    RummyDiscardUse? discardUse,
    bool? jokerSwap,
    RummySetWildSwap? setWildSwap,
    bool? swappedWildMustBeUsed,
    bool? fullHandOwnMeldsOnly,
    int? winnerScore,
    int? handWinnerScore,
    int? handMultiplier,
    int? notOpenedPenalty,
    int? acePenalty,
    int? jokerPenalty,
    bool? bonusWildLastDiscard,
    bool? bonusOneColour,
    bool? bonusOneSuit,
    bool? partnership,
    bool? partnerOfWinnerPays,
    RummyMatchEnd? matchEnd,
    int? rounds,
    int? targetScore,
    int? eliminationScore,
    bool? voidRoundsCount,
    RummyTieBreak? tieBreak,
    int? maxTieBreakRounds,
    RummyDealerRule? dealerRule,
    RummyStockEnd? stockEnd,
    int? maxStockRecycles,
    bool? pairsRedeal,
  }) => RummyOptions(
    variant: variant ?? this.variant,
    players: players ?? this.players,
    decks: decks ?? this.decks,
    jokers: jokers ?? this.jokers,
    handSize: handSize ?? this.handSize,
    starterFirstTurnDiscardOnly: starterFirstTurnDiscardOnly ?? this.starterFirstTurnDiscardOnly,
    noGoOutOnFirstTurn: noGoOutOnFirstTurn ?? this.noGoOutOnFirstTurn,
    maxWildsPerMeld: maxWildsPerMeld ?? this.maxWildsPerMeld,
    wildIndicator: wildIndicator ?? this.wildIndicator,
    openingThreshold: openingThreshold ?? this.openingThreshold,
    aceLowOpeningValue: aceLowOpeningValue ?? this.aceLowOpeningValue,
    aceHighOpeningValue: aceHighOpeningValue ?? this.aceHighOpeningValue,
    openingRequiresRun: openingRequiresRun ?? this.openingRequiresRun,
    openingMustBeatPrevious: openingMustBeatPrevious ?? this.openingMustBeatPrevious,
    openingMustUseDiscard: openingMustUseDiscard ?? this.openingMustUseDiscard,
    oneTurnFinishWaivesThreshold: oneTurnFinishWaivesThreshold ?? this.oneTurnFinishWaivesThreshold,
    discardUse: discardUse ?? this.discardUse,
    jokerSwap: jokerSwap ?? this.jokerSwap,
    setWildSwap: setWildSwap ?? this.setWildSwap,
    swappedWildMustBeUsed: swappedWildMustBeUsed ?? this.swappedWildMustBeUsed,
    fullHandOwnMeldsOnly: fullHandOwnMeldsOnly ?? this.fullHandOwnMeldsOnly,
    winnerScore: winnerScore ?? this.winnerScore,
    handWinnerScore: handWinnerScore ?? this.handWinnerScore,
    handMultiplier: handMultiplier ?? this.handMultiplier,
    notOpenedPenalty: notOpenedPenalty ?? this.notOpenedPenalty,
    acePenalty: acePenalty ?? this.acePenalty,
    jokerPenalty: jokerPenalty ?? this.jokerPenalty,
    bonusWildLastDiscard: bonusWildLastDiscard ?? this.bonusWildLastDiscard,
    bonusOneColour: bonusOneColour ?? this.bonusOneColour,
    bonusOneSuit: bonusOneSuit ?? this.bonusOneSuit,
    partnership: partnership ?? this.partnership,
    partnerOfWinnerPays: partnerOfWinnerPays ?? this.partnerOfWinnerPays,
    matchEnd: matchEnd ?? this.matchEnd,
    rounds: rounds ?? this.rounds,
    targetScore: targetScore ?? this.targetScore,
    eliminationScore: eliminationScore ?? this.eliminationScore,
    voidRoundsCount: voidRoundsCount ?? this.voidRoundsCount,
    tieBreak: tieBreak ?? this.tieBreak,
    maxTieBreakRounds: maxTieBreakRounds ?? this.maxTieBreakRounds,
    dealerRule: dealerRule ?? this.dealerRule,
    stockEnd: stockEnd ?? this.stockEnd,
    maxStockRecycles: maxStockRecycles ?? this.maxStockRecycles,
    pairsRedeal: pairsRedeal ?? this.pairsRedeal,
  );

  Map<String, Object?> toJson() => {
    'v': 2,
    'variant': variant.name,
    'players': players,
    'decks': decks,
    'jokers': jokers,
    'handSize': handSize,
    'starterFirstTurnDiscardOnly': starterFirstTurnDiscardOnly,
    'noGoOutOnFirstTurn': noGoOutOnFirstTurn,
    'maxWildsPerMeld': maxWildsPerMeld,
    'wildIndicator': wildIndicator,
    'openingThreshold': openingThreshold,
    'aceLowOpeningValue': aceLowOpeningValue,
    'aceHighOpeningValue': aceHighOpeningValue,
    'openingRequiresRun': openingRequiresRun,
    'openingMustBeatPrevious': openingMustBeatPrevious,
    'openingMustUseDiscard': openingMustUseDiscard,
    'oneTurnFinishWaivesThreshold': oneTurnFinishWaivesThreshold,
    'discardUse': discardUse.name,
    'jokerSwap': jokerSwap,
    'setWildSwap': setWildSwap.name,
    'swappedWildMustBeUsed': swappedWildMustBeUsed,
    'fullHandOwnMeldsOnly': fullHandOwnMeldsOnly,
    'winnerScore': winnerScore,
    'handWinnerScore': handWinnerScore,
    'handMultiplier': handMultiplier,
    'notOpenedPenalty': notOpenedPenalty,
    'acePenalty': acePenalty,
    'jokerPenalty': jokerPenalty,
    'bonusWildLastDiscard': bonusWildLastDiscard,
    'bonusOneColour': bonusOneColour,
    'bonusOneSuit': bonusOneSuit,
    'partnership': partnership,
    'partnerOfWinnerPays': partnerOfWinnerPays,
    'matchEnd': matchEnd.name,
    'rounds': rounds,
    'targetScore': targetScore,
    'eliminationScore': eliminationScore,
    'voidRoundsCount': voidRoundsCount,
    'tieBreak': tieBreak.name,
    'maxTieBreakRounds': maxTieBreakRounds,
    'dealerRule': dealerRule.name,
    'stockEnd': stockEnd.name,
    'maxStockRecycles': maxStockRecycles,
    'pairsRedeal': pairsRedeal,
  };

  @override
  bool operator ==(Object other) {
    if (other is! RummyOptions) return false;
    final a = toJson();
    final b = other.toJson();
    return a.keys.every((k) => a[k] == b[k]);
  }

  @override
  int get hashCode => Object.hashAll(toJson().values);

  @override
  String toString() => 'RummyOptions(${toJson()})';
}
