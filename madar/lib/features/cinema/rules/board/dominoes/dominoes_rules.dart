/// Dominoes (دومينو) – double-six, the line ("block" / "draw") game as
/// played in Jordanian homes and coffee houses, 2–4 players, optional
/// partnerships for four, played in rounds to a target score (101).
///
/// * Each player gets 7 tiles; with fewer than 4 players the rest form the
///   boneyard. In the draw game a player who cannot play draws until able
///   (or the boneyard is empty) and then passes; in the block game (or with
///   no boneyard, as always with 4 players) they pass at once.
/// * Round 1 is opened by the holder of the highest double, who must play
///   it (no double dealt → the heaviest tile). Later rounds are opened by
///   the previous round's winner with any tile.
/// * The player who plays their last tile wins the round and scores the pips
///   left in every opponent's hand (partners' hands are not counted).
/// * If every player passes in turn the round is blocked: the side with the
///   lowest pip total wins and scores the opponents' pips; a tie scores
///   nothing.
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

final class DominoConfig {
  const DominoConfig({
    this.players = 2,
    this.teams = false,
    this.drawFromBoneyard = true,
    this.handSize = 7,
    this.targetScore = 101,
    this.highestDoubleEveryRound = false,
  }) : assert(players >= 2 && players <= 4),
       assert(!teams || players == 4);

  factory DominoConfig.fromJson(Map<String, Object?> json) => DominoConfig(
    players: (json['players']! as num).toInt(),
    teams: json['teams']! as bool,
    drawFromBoneyard: json['draw']! as bool,
    handSize: (json['hand']! as num).toInt(),
    targetScore: (json['target']! as num).toInt(),
    highestDoubleEveryRound: json['doubleEveryRound']! as bool,
  );

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

  int get sides => teams ? 2 : players;
  int sideOf(int player) => teams ? player % 2 : player;

  Map<String, Object?> toJson() => {
    'players': players,
    'teams': teams,
    'draw': drawFromBoneyard,
    'hand': handSize,
    'target': targetScore,
    'doubleEveryRound': highestDoubleEveryRound,
  };
}

enum DominoPhase { playing, roundOver }

enum DominoRoundEnd { domino, blocked }

/// What happened in the last finished round (for the UI's score sheet).
final class DominoRoundSummary {
  const DominoRoundSummary({
    required this.round,
    required this.end,
    required this.winner,
    required this.points,
    required this.handPips,
  });

  factory DominoRoundSummary.fromJson(Map<String, Object?> json) => DominoRoundSummary(
    round: (json['round']! as num).toInt(),
    end: DominoRoundEnd.values.byName(json['end']! as String),
    winner: (json['winner'] as num?)?.toInt(),
    points: (json['points']! as num).toInt(),
    handPips: intList(json['pips']),
  );

  final int round;
  final DominoRoundEnd end;

  /// The player who went out / had the lowest count; null = tied block.
  final int? winner;

  /// Points awarded to the winner's side.
  final int points;

  /// Pips left in each player's hand.
  final List<int> handPips;

  Map<String, Object?> toJson() => {
    'round': round,
    'end': end.name,
    'winner': winner,
    'points': points,
    'pips': handPips,
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
    this.result,
  }) : hands = List.unmodifiable([for (final h in hands) List<Domino>.unmodifiable(h)]),
       boneyard = List.unmodifiable(boneyard),
       line = List.unmodifiable(line),
       scores = List.unmodifiable(scores),
       voids = List.unmodifiable(voids),
       rng = List.unmodifiable(rng);

  /// Deals round 1 from [seed].
  factory DominoState.initial({int seed = 0, DominoConfig config = const DominoConfig()}) =>
      _deal(config, BoardRng(seed), List.filled(config.sides, 0), 1, null, null);

  factory DominoState.fromJson(Map<String, Object?> json) {
    List<Domino> tiles(Object? j) => [for (final id in intList(j)) Domino.fromId(id)];
    final lead = json['mustLead'] as num?;
    final last = json['lastRound'];
    final r = json['result'];
    return DominoState(
      config: DominoConfig.fromJson(jsonMap(json['config'])),
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
      result: r == null ? null : GameResult.fromJson(jsonMap(r)),
    );
  }

  static DominoState _deal(
    DominoConfig config,
    BoardRng rng,
    List<int> scores,
    int round,
    int? starter,
    DominoRoundSummary? lastRound,
  ) {
    final tiles = [...Domino.doubleSix];
    rng.shuffle(tiles);
    final n = config.players;
    final hands = [for (var p = 0; p < n; p++) tiles.sublist(p * config.handSize, (p + 1) * config.handSize)];
    final boneyard = tiles.sublist(n * config.handSize);
    Domino? mustLead;
    if (starter == null || config.highestDoubleEveryRound) {
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
      starter = holder!;
      mustLead = best;
    }
    return DominoState(
      config: config,
      hands: hands,
      boneyard: boneyard,
      line: const [],
      currentPlayer: starter,
      phase: DominoPhase.playing,
      scores: scores,
      voids: List.filled(n, 0),
      rng: rng.state,
      round: round,
      roundStarter: starter,
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
  @override
  final GameResult? result;

  @override
  int get playerCount => config.players;

  int get leftEnd => line.isEmpty ? -1 : line.first.left;
  int get rightEnd => line.isEmpty ? -1 : line.last.right;

  int handPips(int player) => hands[player].fold(0, (s, t) => s + t.pips);

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
    if (result != null) 'result': result!.toJson(),
  };
}

final class DominoRules extends GameRules<DominoState, DominoMove> {
  const DominoRules();

  @override
  BoardGameId get id => BoardGameId.dominoes;

  /// Plays available to [player]'s hand against the current ends.
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
    if (state.config.drawFromBoneyard && state.boneyard.isNotEmpty) return const [DominoMove.draw];
    return const [DominoMove.pass];
  }

  int _endsMask(DominoState s) => s.line.isEmpty ? 0 : (1 << s.leftEnd) | (1 << s.rightEnd);

  @override
  DominoState apply(DominoState state, DominoMove move) {
    final p = state.currentPlayer;
    final n = state.config.players;
    switch (move.kind) {
      case DominoMoveKind.nextRound:
        final starter = state.lastRound?.winner ?? (state.roundStarter + 1) % n;
        return DominoState._deal(
          state.config,
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
        final next = state.copyWith(
          hands: hands,
          line: line,
          consecutivePasses: 0,
          currentPlayer: (p + 1) % n,
          clearMustLead: true,
        );
        if (hands[p].isEmpty) return _endRound(next, DominoRoundEnd.domino, p);
        return next;
    }
  }

  DominoState _endRound(DominoState s, DominoRoundEnd end, int? outPlayer) {
    final cfg = s.config;
    final n = cfg.players;
    final pips = [for (var p = 0; p < n; p++) s.handPips(p)];
    final sidePips = List.filled(cfg.sides, 0);
    for (var p = 0; p < n; p++) {
      sidePips[cfg.sideOf(p)] += pips[p];
    }
    int? winner = outPlayer;
    if (winner == null) {
      // Blocked: lowest side total wins; tie → nobody.
      var best = 1 << 30;
      int? bestSide;
      var tie = false;
      for (var side = 0; side < cfg.sides; side++) {
        if (sidePips[side] < best) {
          best = sidePips[side];
          bestSide = side;
          tie = false;
        } else if (sidePips[side] == best) {
          tie = true;
        }
      }
      if (!tie) {
        // The winner is that side's player with the fewest pips.
        for (var p = 0; p < n; p++) {
          if (cfg.sideOf(p) != bestSide) continue;
          if (winner == null || pips[p] < pips[winner]) winner = p;
        }
      }
    }
    var points = 0;
    final scores = [...s.scores];
    if (winner != null) {
      final ws = cfg.sideOf(winner);
      for (var side = 0; side < cfg.sides; side++) {
        if (side != ws) points += sidePips[side];
      }
      scores[ws] += points;
    }
    final summary = DominoRoundSummary(round: s.round, end: end, winner: winner, points: points, handPips: pips);
    GameResult? result;
    final perPlayer = [for (var p = 0; p < n; p++) scores[cfg.sideOf(p)]];
    if (cfg.targetScore <= 0) {
      result = winner == null
          ? GameResult.draw(GameEndReason.targetScoreReached, scores: perPlayer)
          : GameResult(
              winners: [
                for (var p = 0; p < n; p++)
                  if (cfg.sideOf(p) == cfg.sideOf(winner)) p,
              ],
              reason: GameEndReason.targetScoreReached,
              scores: perPlayer,
            );
    } else if (winner != null && scores[cfg.sideOf(winner)] >= cfg.targetScore) {
      result = GameResult(
        winners: [
          for (var p = 0; p < n; p++)
            if (cfg.sideOf(p) == cfg.sideOf(winner)) p,
        ],
        reason: GameEndReason.targetScoreReached,
        scores: perPlayer,
      );
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
