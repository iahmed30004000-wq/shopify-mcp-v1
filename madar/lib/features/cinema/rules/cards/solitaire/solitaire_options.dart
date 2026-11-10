/// Solitaire (سوليتير, Klondike / كلوندايك): options and presets.
///
/// `const SolitaireOptions()` is the Madar default (`SolitaireOptions.jordan()`):
/// Klondike as people in Jordan meet it on phones: draw one, unlimited passes,
/// standard scoring without the clock, safe cards go home by themselves. No
/// money scoring is offered (the old "Vegas" mode is a buy-in). See RULES.md.
library;

import '../core/card_game.dart' show AiLevel;

/// Score shown to the player (S-50).
enum SolitaireScoring {
  /// The classic point values (S-40).
  standard,

  /// No score: time, moves and cards home only.
  none,
}

/// Cards sent to the foundations without a tap (S-33).
enum SolitaireAutoMove {
  off,

  /// Only cards that can never be needed in the tableau: aces, twos, and a
  /// card whose two other-colour foundations have reached rank − 1
  /// (default).
  safeOnly,

  /// Every card that can go home. It can spoil a deal.
  always,
}

class SolitaireOptions {
  const SolitaireOptions({
    this.drawCount = 1,
    this.passLimit,
    this.scoring = SolitaireScoring.standard,
    this.draw3PenaltyFromRecycle = 3,
    this.timedScoring = false,
    this.allowFoundationToTableau = true,
    this.autoFlip = true,
    this.autoMoveToFoundation = SolitaireAutoMove.safeOnly,
    this.autoCompleteWithStock = false,
    this.winnableOnly = false,
    this.solverHints = false,
    this.undoPenalty = 0,
    this.hintLevel = AiLevel.hard,
  }) : assert(drawCount == 1 || drawCount == 3),
       assert(passLimit == null || passLimit >= 1),
       assert(draw3PenaltyFromRecycle >= 1),
       assert(undoPenalty >= 0);

  /// The Madar default ("Medium"), identical to `const SolitaireOptions()`.
  const SolitaireOptions.jordan() : this();

  /// Easy: only deals a solver has proved winnable, and auto-complete also
  /// with cards left in the stock.
  const SolitaireOptions.easy() : this(winnableOnly: true, autoCompleteWithStock: true);

  /// Hard: draw three.
  const SolitaireOptions.hard() : this(drawCount: 3);

  /// Expert: draw three, three passes through the stock.
  const SolitaireOptions.expert() : this(drawCount: 3, passLimit: 3);

  /// The old desktop defaults: draw three, standard scoring with the clock,
  /// every card moved by hand.
  const SolitaireOptions.windowsClassic()
    : this(drawCount: 3, timedScoring: true, autoMoveToFoundation: SolitaireAutoMove.off);

  factory SolitaireOptions.fromJson(Map<String, Object?> j) => SolitaireOptions(
    drawCount: j['drawCount']! as int,
    passLimit: j['passLimit'] as int?,
    scoring: SolitaireScoring.values.byName(j['scoring']! as String),
    draw3PenaltyFromRecycle: j['draw3PenaltyFromRecycle']! as int,
    timedScoring: j['timedScoring']! as bool,
    allowFoundationToTableau: j['allowFoundationToTableau']! as bool,
    autoFlip: j['autoFlip']! as bool,
    autoMoveToFoundation: SolitaireAutoMove.values.byName(j['autoMoveToFoundation']! as String),
    autoCompleteWithStock: j['autoCompleteWithStock']! as bool,
    winnableOnly: j['winnableOnly']! as bool,
    solverHints: j['solverHints']! as bool,
    undoPenalty: j['undoPenalty']! as int,
    hintLevel: AiLevel.values.byName(j['hintLevel']! as String),
  );

  /// Cards turned per tap on the stock: 1 or 3 (S-20, S-21).
  final int drawCount;

  /// Trips through the stock: null (unlimited), 3 or 1. A limit of n allows
  /// n − 1 recycles (S-23).
  final int? passLimit;
  final SolitaireScoring scoring;

  /// Draw three: the first recycle that costs −20 (1 = every recycle,
  /// 3 = the Windows desktop reading, 4 = Windows CE) (S-40g).
  final int draw3PenaltyFromRecycle;

  /// −2 every 10 s and a time bonus at the win (S-46, S-47).
  final bool timedScoring;

  /// The top card of a foundation may come back to a column (S-16).
  final bool allowFoundationToTableau;

  /// A face-down card left at the end of a column turns up by itself (S-14);
  /// off, the player turns it with the `flip` action.
  final bool autoFlip;
  final SolitaireAutoMove autoMoveToFoundation;

  /// Draw one with unlimited passes: offer auto-complete while the stock or
  /// waste still has cards (S-32).
  final bool autoCompleteWithStock;

  /// Only deals proved winnable under these options (S-61).
  final bool winnableOnly;

  /// In winnable-deal mode, hints may follow the solver's plan (S-37).
  final bool solverHints;

  /// Points taken off per undo (0, 2 or 5) (S-35).
  final int undoPenalty;

  /// Strength of the hint (S-36, S-75).
  final AiLevel hintLevel;

  /// Recycles allowed in one deal (null = unlimited).
  int? get maxRecycles => passLimit == null ? null : passLimit! - 1;

  SolitaireOptions copyWith({
    int? drawCount,
    int? passLimit,
    bool unlimitedPasses = false,
    SolitaireScoring? scoring,
    int? draw3PenaltyFromRecycle,
    bool? timedScoring,
    bool? allowFoundationToTableau,
    bool? autoFlip,
    SolitaireAutoMove? autoMoveToFoundation,
    bool? autoCompleteWithStock,
    bool? winnableOnly,
    bool? solverHints,
    int? undoPenalty,
    AiLevel? hintLevel,
  }) => SolitaireOptions(
    drawCount: drawCount ?? this.drawCount,
    passLimit: unlimitedPasses ? null : (passLimit ?? this.passLimit),
    scoring: scoring ?? this.scoring,
    draw3PenaltyFromRecycle: draw3PenaltyFromRecycle ?? this.draw3PenaltyFromRecycle,
    timedScoring: timedScoring ?? this.timedScoring,
    allowFoundationToTableau: allowFoundationToTableau ?? this.allowFoundationToTableau,
    autoFlip: autoFlip ?? this.autoFlip,
    autoMoveToFoundation: autoMoveToFoundation ?? this.autoMoveToFoundation,
    autoCompleteWithStock: autoCompleteWithStock ?? this.autoCompleteWithStock,
    winnableOnly: winnableOnly ?? this.winnableOnly,
    solverHints: solverHints ?? this.solverHints,
    undoPenalty: undoPenalty ?? this.undoPenalty,
    hintLevel: hintLevel ?? this.hintLevel,
  );

  Map<String, Object?> toJson() => {
    'drawCount': drawCount,
    'passLimit': passLimit,
    'scoring': scoring.name,
    'draw3PenaltyFromRecycle': draw3PenaltyFromRecycle,
    'timedScoring': timedScoring,
    'allowFoundationToTableau': allowFoundationToTableau,
    'autoFlip': autoFlip,
    'autoMoveToFoundation': autoMoveToFoundation.name,
    'autoCompleteWithStock': autoCompleteWithStock,
    'winnableOnly': winnableOnly,
    'solverHints': solverHints,
    'undoPenalty': undoPenalty,
    'hintLevel': hintLevel.name,
  };

  @override
  bool operator ==(Object other) {
    if (other is! SolitaireOptions) return false;
    final a = toJson();
    final b = other.toJson();
    return a.keys.every((k) => a[k] == b[k]);
  }

  @override
  int get hashCode => Object.hashAll(toJson().values);
}
