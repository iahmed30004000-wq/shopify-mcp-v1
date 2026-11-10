/// Dominoes (دومينو) – double-six, the line game, 2–4 players, played in
/// rounds to a target score.
///
/// The defaults (`DominoConfig()` = [DominoConfig.jordan]) are the game as
/// commonly played in Jordan, «دومينو» with count scoring:
///
/// * 7 tiles each; with 2–3 players the rest form the stock («الكومة»). A
///   player who cannot play draws one tile at a time until able; with an
///   empty stock they pass («دق»). Four players play in partnerships
///   (0 + 2 against 1 + 3).
/// * Round 1 is opened by the holder of the highest double, who must play it
///   (no double dealt → the heaviest tile). Later rounds are opened by the
///   previous round's winner with any tile.
/// * The player who plays their last tile wins the round and scores the pips
///   left in every opponent's hand (partners' hands and the stock do not
///   count).
/// * The round is blocked when every player passes in turn, or at once when
///   the line is locked («قفلت»): both ends show the same number and all
///   seven tiles carrying it are in the line. The side with the lowest pip
///   total wins and scores the opponents' pips; a tie scores nothing.
/// * The first side to 101 wins the match.
///
/// Options: the block game (no drawing), «الخمسات» (All Fives on a line,
/// target 150), re-dealing when no double is dealt, a stock reserve,
/// rounding to fives, other blocked-round scorings and tie-breaks, and the
/// literal "draw the stock after a lock" rule ([DominoConfig.playOutLock]).
///
/// Hands are part of the state (the UI must hide the others); the AI only
/// reads its own hand plus public information.
library;

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';

/// A double-six tile with `low <= high`.
final class Domino {
  const Domino(this.low, this.high) : assert(low <= high);

  factory Domino.of(int a, int b) => a <= b ? Domino(a, b) : Domino(b, a);

  factory Domino.fromId(int id) => doubleSix[id];

  /// The 28 tiles in id order.
  static final List<Domino> doubleSix = List.unmodifiable([
    for (var h = 0; h <= 6; h++)
      for (var l = 0; l <= h; l++) Domino(l, h),
  ]);

  final int low;
  final int high;

  int get id => high * (high + 1) ~/ 2 + low;
  int get pips => low + high;
  bool get isDouble => low == high;
  bool matches(int n) => low == n || high == n;
  int other(int n) => n == low ? high : low;

  @override
  bool operator ==(Object other) => other is Domino && other.low == low && other.high == high;

  @override
  int get hashCode => id;

  @override
  String toString() => '[$low|$high]';
}

/// A tile in the line, oriented left → right.
final class PlacedDomino {
  const PlacedDomino(this.tile, this.left, this.right);
  final Domino tile;
  final int left;
  final int right;

  List<int> toJson() => [tile.id, left, right];
  factory PlacedDomino.fromJson(List<Object?> j) =>
      PlacedDomino(Domino.fromId((j[0]! as num).toInt()), (j[1]! as num).toInt(), (j[2]! as num).toInt());
}

enum DominoEnd { left, right }

enum DominoMoveKind { play, draw, pass, nextRound }

final class DominoMove extends GameMove {
  const DominoMove._(this.kind) : tile = null, end = null;

  const DominoMove.play(Domino this.tile, DominoEnd this.end) : kind = DominoMoveKind.play;

  static const DominoMove draw = DominoMove._(DominoMoveKind.draw);
  static const DominoMove pass = DominoMove._(DominoMoveKind.pass);
  static const DominoMove nextRound = DominoMove._(DominoMoveKind.nextRound);

  factory DominoMove.fromJson(Map<String, Object?> json) {
    final kind = DominoMoveKind.values.byName(json['kind']! as String);
    if (kind != DominoMoveKind.play) return DominoMove._(kind);
    return DominoMove.play(
      Domino.fromId((json['tile']! as num).toInt()),
      DominoEnd.values.byName(json['end']! as String),
    );
  }

  final DominoMoveKind kind;
  final Domino? tile;
  final DominoEnd? end;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (tile != null) 'tile': tile!.id,
    if (end != null) 'end': end!.name,
  };

  @override
  bool operator ==(Object other) => other is DominoMove && other.kind == kind && other.tile == tile && other.end == end;

  @override
  int get hashCode => Object.hash(kind, tile, end);

  @override
  String toString() => kind == DominoMoveKind.play ? '$tile@${end!.name}' : kind.name;
}

/// How points are made.
enum DominoScoring {
  /// «دومينو» count scoring: only the pips left in hands score (default).
  count,

  /// «الخمسات» on a line: every play that makes the two end numbers add up
  /// to a multiple of five scores that sum at once; hands are rounded to
  /// the nearest five.
  allFives,
}

/// Rounding of the pips scored from hands.
enum DominoRounding {
  /// Exact pips (default).
  none,

  /// To the nearest five, halves up: 2 → 0, 3 → 5, 7 → 5, 8 → 10.
  nearestFive,
}

/// Who opens round 1 when nobody was dealt a double.
enum DominoNoDoubleOpening {
  /// The heaviest tile leads (default); equal pips → the higher top number.
  heaviestTile,

  /// Shuffle and deal again (from the game RNG) until a double is dealt.
  reshuffle,
}

/// What the winning side of a blocked round scores.
enum DominoBlockedScoring {
  /// The pips of every other side (default).
  opponentsPips,

  /// The other sides' pips minus the winning side's own pips, never below 0
  /// (with [DominoBlockedCompare.lowestPlayer] the winning side may hold the
  /// larger total; it still wins the round and leads the next one).
  difference,

  /// Every hand's pips, the winners' own included.
  allHands,
}

/// A blocked round in which the lowest totals tie.
enum DominoBlockedTie {
  /// Nobody scores (default).
  noScore,

  /// When exactly two sides tie and one of them played the last tile, the
  /// other one wins and scores as an outright winner.
  lockerLoses,
}

/// How the lowest hand of a blocked round is found.
enum DominoBlockedCompare {
  /// Side totals, partners added together (default).
  sideTotal,

  /// The single lightest hand decides (only differs with partnerships).
  lowestPlayer,
}

final class DominoConfig {
  /// The game as commonly played in Jordan unless options say otherwise.
  ///
  /// [teams] defaults to `players == 4`.
  const DominoConfig({
    this.players = 2,
    bool? teams,
    this.drawFromBoneyard = true,
    this.handSize = 7,
    this.targetScore = 101,
    this.highestDoubleEveryRound = false,
    this.endWhenLocked = true,
    this.noDoubleOpening = DominoNoDoubleOpening.heaviestTile,
    this.stockReserve = 0,
    this.scoring = DominoScoring.count,
    this.rounding = DominoRounding.none,
    this.blockedScoring = DominoBlockedScoring.opponentsPips,
    this.blockedTie = DominoBlockedTie.noScore,
    this.blockedCompare = DominoBlockedCompare.sideTotal,
  }) : teams = teams ?? (players == 4),
       assert(players >= 2 && players <= 4),
       assert(teams != true || players == 4),
       assert(handSize >= 1 && handSize * players <= 28),
       assert(stockReserve >= 0);

  /// «دومينو» as commonly played in Jordan (= `DominoConfig(players: …)`):
  /// draw game, count scoring to 101, partners with four, a locked line ends
  /// the round at once.
  const DominoConfig.jordan({required int players, int targetScore = 101})
    : this(players: players, targetScore: targetScore);

  /// «الخمسات» – All Fives on a two-ended line, to 150.
  const DominoConfig.allFives({required int players, int targetScore = 150})
    : this(
        players: players,
        targetScore: targetScore,
        scoring: DominoScoring.allFives,
        rounding: DominoRounding.nearestFive,
      );

  /// The block game: nobody draws, a player who cannot play passes at once.
  const DominoConfig.block({required int players, int targetScore = 101})
    : this(players: players, targetScore: targetScore, drawFromBoneyard: false);

  /// A locked line is played out literally: the player to move draws the
  /// whole stock and then everyone passes (as several Arab-market apps do,
  /// and as this engine did before the Jordanian default).
  const DominoConfig.playOutLock({required int players, int targetScore = 101})
    : this(players: players, targetScore: targetScore, endWhenLocked: false);

  /// Reads a saved config. Keys added after the first release fall back to
  /// the behaviour the save was played under (`lockEnds` missing → false).
  factory DominoConfig.fromJson(Map<String, Object?> json) => DominoConfig(
    players: (json['players']! as num).toInt(),
    teams: json['teams']! as bool,
    drawFromBoneyard: json['draw']! as bool,
    handSize: (json['hand']! as num).toInt(),
    targetScore: (json['target']! as num).toInt(),
    highestDoubleEveryRound: json['doubleEveryRound']! as bool,
    endWhenLocked: json['lockEnds'] as bool? ?? false,
    noDoubleOpening: _byName(DominoNoDoubleOpening.values, json['noDouble'], DominoNoDoubleOpening.heaviestTile),
    stockReserve: (json['reserve'] as num?)?.toInt() ?? 0,
    scoring: _byName(DominoScoring.values, json['scoring'], DominoScoring.count),
    rounding: _byName(DominoRounding.values, json['round'], DominoRounding.none),
    blockedScoring: _byName(DominoBlockedScoring.values, json['blockedScore'], DominoBlockedScoring.opponentsPips),
    blockedTie: _byName(DominoBlockedTie.values, json['blockedTie'], DominoBlockedTie.noScore),
    blockedCompare: _byName(DominoBlockedCompare.values, json['blockedCompare'], DominoBlockedCompare.sideTotal),
  );

  static T _byName<T extends Enum>(List<T> values, Object? name, T missing) =>
      name == null ? missing : values.byName(name as String);

  final int players;

  /// Four players in partnerships 0+2 against 1+3.
  final bool teams;

  /// Draw game (سحب) when true, block game when false.
  final bool drawFromBoneyard;
  final int handSize;

  /// Match target; 0 = a single round.
  final int targetScore;

  /// Every round (not just the first) is opened with the highest double.
  final bool highestDoubleEveryRound;

  /// A locked line («قفلت»: equal ends, all seven tiles of that number in
  /// the line) ends the round at once as blocked, even with tiles left in
  /// the stock. False = the player to move draws the stock first.
  final bool endWhenLocked;
  final DominoNoDoubleOpening noDoubleOpening;

  /// The last [stockReserve] tiles of the stock are never drawn.
  final int stockReserve;
  final DominoScoring scoring;

  /// Rounding of hand pips in count scoring (All Fives always rounds).
  final DominoRounding rounding;
  final DominoBlockedScoring blockedScoring;
  final DominoBlockedTie blockedTie;
  final DominoBlockedCompare blockedCompare;

  int get sides => teams ? 2 : players;
  int sideOf(int player) => teams ? player % 2 : player;

  /// Whether hand pips are rounded to the nearest five.
  bool get roundsToFive => scoring == DominoScoring.allFives || rounding == DominoRounding.nearestFive;

  DominoConfig copyWith({
    int? players,
    bool? teams,
    bool? drawFromBoneyard,
    int? handSize,
    int? targetScore,
    bool? highestDoubleEveryRound,
    bool? endWhenLocked,
    DominoNoDoubleOpening? noDoubleOpening,
    int? stockReserve,
    DominoScoring? scoring,
    DominoRounding? rounding,
    DominoBlockedScoring? blockedScoring,
    DominoBlockedTie? blockedTie,
    DominoBlockedCompare? blockedCompare,
  }) => DominoConfig(
    players: players ?? this.players,
    teams: teams ?? (players == null ? this.teams : null),
    drawFromBoneyard: drawFromBoneyard ?? this.drawFromBoneyard,
    handSize: handSize ?? this.handSize,
    targetScore: targetScore ?? this.targetScore,
    highestDoubleEveryRound: highestDoubleEveryRound ?? this.highestDoubleEveryRound,
    endWhenLocked: endWhenLocked ?? this.endWhenLocked,
    noDoubleOpening: noDoubleOpening ?? this.noDoubleOpening,
    stockReserve: stockReserve ?? this.stockReserve,
    scoring: scoring ?? this.scoring,
    rounding: rounding ?? this.rounding,
    blockedScoring: blockedScoring ?? this.blockedScoring,
    blockedTie: blockedTie ?? this.blockedTie,
    blockedCompare: blockedCompare ?? this.blockedCompare,
  );

  Map<String, Object?> toJson() => {
    'players': players,
    'teams': teams,
    'draw': drawFromBoneyard,
    'hand': handSize,
    'target': targetScore,
    'doubleEveryRound': highestDoubleEveryRound,
    'lockEnds': endWhenLocked,
    'noDouble': noDoubleOpening.name,
    'reserve': stockReserve,
    'scoring': scoring.name,
    'round': rounding.name,
    'blockedScore': blockedScoring.name,
    'blockedTie': blockedTie.name,
    'blockedCompare': blockedCompare.name,
  };

  @override
  bool operator ==(Object other) =>
      other is DominoConfig &&
      other.players == players &&
      other.teams == teams &&
      other.drawFromBoneyard == drawFromBoneyard &&
      other.handSize == handSize &&
      other.targetScore == targetScore &&
      other.highestDoubleEveryRound == highestDoubleEveryRound &&
      other.endWhenLocked == endWhenLocked &&
      other.noDoubleOpening == noDoubleOpening &&
      other.stockReserve == stockReserve &&
      other.scoring == scoring &&
      other.rounding == rounding &&
      other.blockedScoring == blockedScoring &&
      other.blockedTie == blockedTie &&
      other.blockedCompare == blockedCompare;

  @override
  int get hashCode => Object.hash(
    players,
    teams,
    drawFromBoneyard,
    handSize,
    targetScore,
    highestDoubleEveryRound,
    endWhenLocked,
    noDoubleOpening,
    stockReserve,
    scoring,
    rounding,
    blockedScoring,
    blockedTie,
    blockedCompare,
  );

  @override
  String toString() => 'DominoConfig(${toJson()})';
}

enum DominoPhase { playing, roundOver }

enum DominoRoundEnd {
  /// A player went out («دومينو»).
  domino,

  /// Everyone passed in turn, or the line locked («قفلت», see
  /// [DominoRoundSummary.locked]).
  blocked,

  /// All Fives only: an end count took the mover's side to the target in
  /// mid-round, so the match ended at once.
  targetReached,
}

/// What happened in the last finished round (for the UI's score sheet).
final class DominoRoundSummary {
  const DominoRoundSummary({
    required this.round,
    required this.end,
    required this.winner,
    required this.points,
    required this.handPips,
    this.endPoints = const [],
    this.stockLeft = 0,
    this.locked = false,
  });

  factory DominoRoundSummary.fromJson(Map<String, Object?> json) => DominoRoundSummary(
    round: (json['round']! as num).toInt(),
    end: DominoRoundEnd.values.byName(json['end']! as String),
    winner: (json['winner'] as num?)?.toInt(),
    points: (json['points']! as num).toInt(),
    handPips: intList(json['pips']),
    endPoints: intList(json['endPts']),
    stockLeft: (json['stock'] as num?)?.toInt() ?? 0,
    locked: json['locked'] as bool? ?? false,
  );

  final int round;
  final DominoRoundEnd end;

  /// The player who went out / had the lowest count; null = tied block.
  final int? winner;

  /// Points from the hands awarded to the winner's side.
  final int points;

  /// Pips left in each player's hand.
  final List<int> handPips;

  /// All Fives: end-count points each side made during the round (empty in
  /// count scoring).
  final List<int> endPoints;

  /// Tiles left in the stock when the round ended.
  final int stockLeft;

  /// The round ended on a locked line («قفلت»).
  final bool locked;

  Map<String, Object?> toJson() => {
    'round': round,
    'end': end.name,
    'winner': winner,
    'points': points,
    'pips': handPips,
    if (endPoints.isNotEmpty) 'endPts': endPoints,
    if (stockLeft != 0) 'stock': stockLeft,
    if (locked) 'locked': true,
  };
}

final class DominoState extends GameState {
  DominoState({
    required this.config,
    required List<List<Domino>> hands,
    required List<Domino> boneyard,
    required List<PlacedDomino> line,
    required this.currentPlayer,
    required this.phase,
    required List<int> scores,
    required List<int> voids,
    required List<int> rng,
    this.round = 1,
    this.roundStarter = 0,
    this.consecutivePasses = 0,
    this.mustLead,
    this.lastRound,
    this.lastMover,
    List<int>? roundEndPoints,
    this.result,
  }) : hands = List.unmodifiable([for (final h in hands) List<Domino>.unmodifiable(h)]),
       boneyard = List.unmodifiable(boneyard),
       line = List.unmodifiable(line),
       scores = List.unmodifiable(scores),
       voids = List.unmodifiable(voids),
       rng = List.unmodifiable(rng),
       roundEndPoints = List.unmodifiable(roundEndPoints ?? List<int>.filled(config.sides, 0));

  /// Deals round 1 from [seed]; [config] defaults to the Jordanian game for
  /// two players.
  factory DominoState.initial({int seed = 0, DominoConfig config = const DominoConfig()}) =>
      _deal(config, BoardRng(seed), List.filled(config.sides, 0), 1, null, null);

  factory DominoState.fromJson(Map<String, Object?> json) {
    List<Domino> tiles(Object? j) => [for (final id in intList(j)) Domino.fromId(id)];
    final config = DominoConfig.fromJson(jsonMap(json['config']));
    final lead = json['mustLead'] as num?;
    final last = json['lastRound'];
    final r = json['result'];
    final endPts = json['endPts'];
    return DominoState(
      config: config,
      hands: [for (final h in json['hands']! as List) tiles(h)],
      boneyard: tiles(json['boneyard']),
      line: [for (final p in json['line']! as List) PlacedDomino.fromJson(p as List)],
      currentPlayer: (json['player']! as num).toInt(),
      phase: DominoPhase.values.byName(json['phase']! as String),
      scores: intList(json['scores']),
      voids: intList(json['voids']),
      rng: intList(json['rng']),
      round: (json['round']! as num).toInt(),
      roundStarter: (json['starter']! as num).toInt(),
      consecutivePasses: (json['passes']! as num).toInt(),
      mustLead: lead == null ? null : Domino.fromId(lead.toInt()),
      lastRound: last == null ? null : DominoRoundSummary.fromJson(jsonMap(last)),
      lastMover: (json['last'] as num?)?.toInt(),
      roundEndPoints: endPts == null ? null : intList(endPts),
      result: r == null ? null : GameResult.fromJson(jsonMap(r)),
    );
  }

  static bool _anyDouble(List<List<Domino>> hands) => hands.any((h) => h.any((t) => t.isDouble));

  static DominoState _deal(
    DominoConfig config,
    BoardRng rng,
    List<int> scores,
    int round,
    int? starter,
    DominoRoundSummary? lastRound,
  ) {
    final n = config.players;
    final byDouble = starter == null || config.highestDoubleEveryRound;
    late List<List<Domino>> hands;
    late List<Domino> boneyard;
    // With `reshuffle` a deal without any double is thrown in and dealt
    // again from the same generator (so it stays deterministic).
    for (var attempt = 0; ; attempt++) {
      final tiles = [...Domino.doubleSix];
      rng.shuffle(tiles);
      hands = [for (var p = 0; p < n; p++) tiles.sublist(p * config.handSize, (p + 1) * config.handSize)];
      boneyard = tiles.sublist(n * config.handSize);
      final redeal = byDouble && config.noDoubleOpening == DominoNoDoubleOpening.reshuffle && !_anyDouble(hands);
      if (!redeal || attempt >= 1000) break;
    }
    Domino? mustLead;
    int leader;
    if (byDouble) {
      // Highest double leads; otherwise the heaviest tile.
      Domino? best;
      int? holder;
      for (var p = 0; p < n; p++) {
        for (final t in hands[p]) {
          final better =
              best == null ||
              (t.isDouble && (!best.isDouble || t.high > best.high)) ||
              (!t.isDouble && !best.isDouble && (t.pips > best.pips || (t.pips == best.pips && t.high > best.high)));
          if (better) {
            best = t;
            holder = p;
          }
        }
      }
      leader = holder!;
      mustLead = best;
    } else {
      leader = starter;
    }
    return DominoState(
      config: config,
      hands: hands,
      boneyard: boneyard,
      line: const [],
      currentPlayer: leader,
      phase: DominoPhase.playing,
      scores: scores,
      voids: List.filled(n, 0),
      rng: rng.state,
      round: round,
      roundStarter: leader,
      mustLead: mustLead,
      lastRound: lastRound,
    );
  }

  final DominoConfig config;

  /// Every hand (hidden information – show only the viewer's).
  final List<List<Domino>> hands;
  final List<Domino> boneyard;
  final List<PlacedDomino> line;
  @override
  final int currentPlayer;
  final DominoPhase phase;

  /// Match points per side (per player, or per team with [DominoConfig.teams]).
  final List<int> scores;

  /// Public knowledge: bit `n` set when player p is known to hold no tile
  /// showing `n` (they passed or drew on it).
  final List<int> voids;
  final List<int> rng;
  final int round;
  final int roundStarter;
  final int consecutivePasses;

  /// The tile that must open the round, if any.
  final Domino? mustLead;
  final DominoRoundSummary? lastRound;

  /// The player who placed the last tile of this round (null before the
  /// first play); decides [DominoBlockedTie.lockerLoses].
  final int? lastMover;

  /// All Fives: end-count points per side made so far this round.
  final List<int> roundEndPoints;
  @override
  final GameResult? result;

  @override
  int get playerCount => config.players;

  int get leftEnd => line.isEmpty ? -1 : line.first.left;
  int get rightEnd => line.isEmpty ? -1 : line.last.right;

  int handPips(int player) => hands[player].fold(0, (s, t) => s + t.pips);

  /// Tiles the current player may still draw (the reserve is never drawn).
  int get drawableStock => boneyard.length > config.stockReserve ? boneyard.length - config.stockReserve : 0;

  /// Whether no tile outside the line can match either end («قفلت»).
  ///
  /// Every number is on 8 half-tiles; inside the line they pair up at the
  /// joints, so when all 7 tiles of `v` are placed, `v` shows at both ends
  /// or at neither. Hence the line is locked exactly when both ends show the
  /// same number and all seven tiles carrying it are in the line. Only the
  /// line is counted, so hand-built states cannot trigger it falsely.
  bool get lineLocked => isLocked(line);

  /// [lineLocked] for any line.
  static bool isLocked(List<PlacedDomino> line) {
    if (line.isEmpty) return false;
    final v = line.first.left;
    if (line.last.right != v) return false;
    var n = 0;
    for (final p in line) {
      if (p.tile.matches(v)) n++;
    }
    return n == 7;
  }

  /// The All Fives end count of the current line.
  int get endCount => endCountOf(line);

  /// The sum the ends show in All Fives: one tile → its pips; otherwise the
  /// two exposed numbers, a double at an end counting both halves.
  static int endCountOf(List<PlacedDomino> line) {
    if (line.isEmpty) return 0;
    if (line.length == 1) return line.first.tile.pips;
    final first = line.first, last = line.last;
    return (first.tile.isDouble ? 2 * first.left : first.left) + (last.tile.isDouble ? 2 * last.right : last.right);
  }

  DominoState copyWith({
    List<List<Domino>>? hands,
    List<Domino>? boneyard,
    List<PlacedDomino>? line,
    int? currentPlayer,
    DominoPhase? phase,
    List<int>? scores,
    List<int>? voids,
    int? consecutivePasses,
    bool clearMustLead = false,
    DominoRoundSummary? lastRound,
    int? lastMover,
    List<int>? roundEndPoints,
    GameResult? result,
  }) => DominoState(
    config: config,
    hands: hands ?? this.hands,
    boneyard: boneyard ?? this.boneyard,
    line: line ?? this.line,
    currentPlayer: currentPlayer ?? this.currentPlayer,
    phase: phase ?? this.phase,
    scores: scores ?? this.scores,
    voids: voids ?? this.voids,
    rng: rng,
    round: round,
    roundStarter: roundStarter,
    consecutivePasses: consecutivePasses ?? this.consecutivePasses,
    mustLead: clearMustLead ? null : mustLead,
    lastRound: lastRound ?? this.lastRound,
    lastMover: lastMover ?? this.lastMover,
    roundEndPoints: roundEndPoints ?? this.roundEndPoints,
    result: result ?? this.result,
  );

  @override
  Map<String, Object?> toJson() => {
    'config': config.toJson(),
    'hands': [
      for (final h in hands) [for (final t in h) t.id],
    ],
    'boneyard': [for (final t in boneyard) t.id],
    'line': [for (final p in line) p.toJson()],
    'player': currentPlayer,
    'phase': phase.name,
    'scores': scores,
    'voids': voids,
    'rng': rng,
    'round': round,
    'starter': roundStarter,
    'passes': consecutivePasses,
    if (mustLead != null) 'mustLead': mustLead!.id,
    if (lastRound != null) 'lastRound': lastRound!.toJson(),
    if (lastMover != null) 'last': lastMover,
    if (roundEndPoints.any((p) => p != 0)) 'endPts': roundEndPoints,
    if (result != null) 'result': result!.toJson(),
  };
}

/// Who won a finished round and what their side scores from the hands.
typedef DominoSettlement = ({int? winner, int points});

final class DominoRules extends GameRules<DominoState, DominoMove> {
  const DominoRules();

  @override
  BoardGameId get id => BoardGameId.dominoes;

  /// `round5(x)`: to the nearest five, halves up (2 → 0, 3 → 5, 8 → 10).
  static int round5(int x) => ((x + 2) ~/ 5) * 5;

  /// Settles a finished round from the pips left in each hand ([pips]).
  ///
  /// [outPlayer] went out (null = blocked). [lastMover] placed the last
  /// tile (for [DominoBlockedTie.lockerLoses]). The winner is the player who
  /// went out, or the lightest hand of the winning side (the first seat on
  /// equal pips); null = a tie that scores nothing. Shared with the AI.
  static DominoSettlement settle(DominoConfig cfg, List<int> pips, int? outPlayer, int? lastMover) {
    final n = cfg.players;
    final sidePips = List.filled(cfg.sides, 0);
    for (var p = 0; p < n; p++) {
      sidePips[cfg.sideOf(p)] += pips[p];
    }
    int? winSide;
    var blocked = false;
    if (outPlayer != null) {
      winSide = cfg.sideOf(outPlayer);
    } else {
      blocked = true;
      final tied = <int>[];
      if (cfg.blockedCompare == DominoBlockedCompare.lowestPlayer) {
        var min = 1 << 30;
        for (final v in pips) {
          if (v < min) min = v;
        }
        for (var p = 0; p < n; p++) {
          if (pips[p] == min && !tied.contains(cfg.sideOf(p))) tied.add(cfg.sideOf(p));
        }
      } else {
        var min = 1 << 30;
        for (final v in sidePips) {
          if (v < min) min = v;
        }
        for (var s = 0; s < cfg.sides; s++) {
          if (sidePips[s] == min) tied.add(s);
        }
      }
      if (tied.length == 1) {
        winSide = tied.single;
      } else if (cfg.blockedTie == DominoBlockedTie.lockerLoses && tied.length == 2 && lastMover != null) {
        final locker = cfg.sideOf(lastMover);
        if (tied.contains(locker)) winSide = tied.firstWhere((s) => s != locker);
      }
    }
    if (winSide == null) return (winner: null, points: 0);
    var others = 0;
    for (var s = 0; s < cfg.sides; s++) {
      if (s != winSide) others += sidePips[s];
    }
    var points = others;
    if (blocked) {
      points = switch (cfg.blockedScoring) {
        DominoBlockedScoring.opponentsPips => others,
        // Floored at 0: with [DominoBlockedCompare.lowestPlayer] the winning
        // side can hold the larger total, and scores never fall.
        DominoBlockedScoring.difference => others > sidePips[winSide] ? others - sidePips[winSide] : 0,
        DominoBlockedScoring.allHands => others + sidePips[winSide],
      };
    }
    if (cfg.roundsToFive) points = round5(points);
    int? winner = outPlayer;
    if (winner == null) {
      for (var p = 0; p < n; p++) {
        if (cfg.sideOf(p) != winSide) continue;
        if (winner == null || pips[p] < pips[winner]) winner = p;
      }
    }
    return (winner: winner, points: points);
  }

  /// Plays available to [hand] against the current ends.
  static List<DominoMove> plays(DominoState s, List<Domino> hand) {
    if (s.line.isEmpty) {
      if (s.mustLead != null) {
        return hand.contains(s.mustLead) ? [DominoMove.play(s.mustLead!, DominoEnd.left)] : const [];
      }
      return [for (final t in hand) DominoMove.play(t, DominoEnd.left)];
    }
    final l = s.leftEnd, r = s.rightEnd;
    return [
      for (final t in hand) ...[
        if (t.matches(l)) DominoMove.play(t, DominoEnd.left),
        if (t.matches(r)) DominoMove.play(t, DominoEnd.right),
      ],
    ];
  }

  @override
  List<DominoMove> legalMoves(DominoState state) {
    if (state.isOver) return const [];
    if (state.phase == DominoPhase.roundOver) return const [DominoMove.nextRound];
    final p = plays(state, state.hands[state.currentPlayer]);
    if (p.isNotEmpty) return p;
    if (state.config.drawFromBoneyard && state.drawableStock > 0) return const [DominoMove.draw];
    return const [DominoMove.pass];
  }

  int _endsMask(DominoState s) => s.line.isEmpty ? 0 : (1 << s.leftEnd) | (1 << s.rightEnd);

  @override
  DominoState apply(DominoState state, DominoMove move) {
    final p = state.currentPlayer;
    final cfg = state.config;
    final n = cfg.players;
    switch (move.kind) {
      case DominoMoveKind.nextRound:
        final starter = state.lastRound?.winner ?? (state.roundStarter + 1) % n;
        return DominoState._deal(
          cfg,
          BoardRng.fromState(state.rng),
          state.scores,
          state.round + 1,
          starter,
          state.lastRound,
        );
      case DominoMoveKind.draw:
        final boneyard = [...state.boneyard];
        final tile = boneyard.removeLast();
        final hands = [...state.hands];
        hands[p] = [...hands[p], tile];
        final voids = [...state.voids]..[p] = _endsMask(state);
        return state.copyWith(hands: hands, boneyard: boneyard, voids: voids);
      case DominoMoveKind.pass:
        final voids = [...state.voids]..[p] |= _endsMask(state);
        final passes = state.consecutivePasses + 1;
        final next = state.copyWith(voids: voids, consecutivePasses: passes, currentPlayer: (p + 1) % n);
        if (passes >= n) return _endRound(next, DominoRoundEnd.blocked, null);
        return next;
      case DominoMoveKind.play:
        final tile = move.tile!;
        final hands = [...state.hands];
        hands[p] = [...hands[p]]..remove(tile);
        final line = [...state.line];
        if (line.isEmpty) {
          line.add(PlacedDomino(tile, tile.low, tile.high));
        } else if (move.end == DominoEnd.left) {
          final l = state.leftEnd;
          line.insert(0, PlacedDomino(tile, tile.other(l), l));
        } else {
          final r = state.rightEnd;
          line.add(PlacedDomino(tile, r, tile.other(r)));
        }
        var next = state.copyWith(
          hands: hands,
          line: line,
          consecutivePasses: 0,
          currentPlayer: (p + 1) % n,
          clearMustLead: true,
          lastMover: p,
        );
        // 1. All Fives: the end count scores at once, and may end the match.
        if (cfg.scoring == DominoScoring.allFives) {
          final count = DominoState.endCountOf(line);
          if (count > 0 && count % 5 == 0) {
            final side = cfg.sideOf(p);
            final scores = [...next.scores]..[side] += count;
            final endPts = [...next.roundEndPoints]..[side] += count;
            next = next.copyWith(scores: scores, roundEndPoints: endPts);
            if (cfg.targetScore > 0 && scores[side] >= cfg.targetScore) return _endMatchMidRound(next, p);
          }
        }
        // 2. Going out wins, even when the last tile also locks the line.
        if (hands[p].isEmpty) return _endRound(next, DominoRoundEnd.domino, p);
        // 3. A locked line ends the round as blocked; nobody draws.
        if (cfg.endWhenLocked && next.lineLocked) return _endRound(next, DominoRoundEnd.blocked, null);
        return next;
    }
  }

  List<int> _winners(DominoConfig cfg, int winner) => [
    for (var p = 0; p < cfg.players; p++)
      if (cfg.sideOf(p) == cfg.sideOf(winner)) p,
  ];

  DominoState _endMatchMidRound(DominoState s, int mover) {
    final cfg = s.config;
    final n = cfg.players;
    final summary = DominoRoundSummary(
      round: s.round,
      end: DominoRoundEnd.targetReached,
      winner: mover,
      points: 0,
      handPips: [for (var p = 0; p < n; p++) s.handPips(p)],
      endPoints: s.roundEndPoints,
      stockLeft: s.boneyard.length,
    );
    return s.copyWith(
      phase: DominoPhase.roundOver,
      currentPlayer: mover,
      lastRound: summary,
      result: GameResult(
        winners: _winners(cfg, mover),
        reason: GameEndReason.targetScoreReached,
        scores: [for (var p = 0; p < n; p++) s.scores[cfg.sideOf(p)]],
      ),
    );
  }

  DominoState _endRound(DominoState s, DominoRoundEnd end, int? outPlayer) {
    final cfg = s.config;
    final n = cfg.players;
    final pips = [for (var p = 0; p < n; p++) s.handPips(p)];
    final (:winner, :points) = settle(cfg, pips, outPlayer, s.lastMover);
    final scores = [...s.scores];
    if (winner != null) scores[cfg.sideOf(winner)] += points;
    final summary = DominoRoundSummary(
      round: s.round,
      end: end,
      winner: winner,
      points: points,
      handPips: pips,
      endPoints: cfg.scoring == DominoScoring.allFives ? s.roundEndPoints : const [],
      stockLeft: s.boneyard.length,
      locked: end == DominoRoundEnd.blocked && s.lineLocked,
    );
    GameResult? result;
    final perPlayer = [for (var p = 0; p < n; p++) scores[cfg.sideOf(p)]];
    if (cfg.targetScore <= 0) {
      // A single round: its winner takes it (All Fives: the most points).
      int? top = winner == null ? null : cfg.sideOf(winner);
      if (cfg.scoring == DominoScoring.allFives) {
        top = null;
        var best = -1;
        var tie = false;
        for (var side = 0; side < cfg.sides; side++) {
          if (scores[side] > best) {
            best = scores[side];
            top = side;
            tie = false;
          } else if (scores[side] == best) {
            tie = true;
          }
        }
        if (tie) top = null;
      }
      result = top == null
          ? GameResult.draw(GameEndReason.targetScoreReached, scores: perPlayer)
          : GameResult(
              winners: [
                for (var p = 0; p < n; p++)
                  if (cfg.sideOf(p) == top) p,
              ],
              reason: GameEndReason.targetScoreReached,
              scores: perPlayer,
            );
    } else if (winner != null && scores[cfg.sideOf(winner)] >= cfg.targetScore) {
      result = GameResult(winners: _winners(cfg, winner), reason: GameEndReason.targetScoreReached, scores: perPlayer);
    }
    return s.copyWith(
      phase: DominoPhase.roundOver,
      scores: scores,
      currentPlayer: winner ?? (s.roundStarter + 1) % n,
      lastRound: summary,
      result: result,
    );
  }

  @override
  DominoState stateFromJson(Map<String, Object?> json) => DominoState.fromJson(json);

  @override
  DominoMove moveFromJson(Map<String, Object?> json) => DominoMove.fromJson(json);
}

const dominoRules = DominoRules();
