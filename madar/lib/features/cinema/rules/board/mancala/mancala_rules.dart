/// Mancala (منقلة) – Kalah(6,4) by default, Oware (Abapa) as an option.
///
/// Pits are numbered 0..2n-1 counter-clockwise: player 0 owns 0..n-1 (left
/// to right on their side), player 1 owns n..2n-1. Each player has a store
/// (Kalah) / captured pile (Oware) in `stores`. A move is the absolute index
/// of one of the mover's pits.
library;

import '../core/engine.dart';
import '../core/game_types.dart';

enum MancalaVariant { kalah, oware }

final class MancalaConfig {
  const MancalaConfig({
    this.variant = MancalaVariant.kalah,
    this.pitsPerSide = 6,
    this.seedsPerPit = 4,
    this.captureEmptyOpposite = false,
    this.grandSlamCaptures = false,
    this.moveLimit = 200,
  });

  factory MancalaConfig.fromJson(Map<String, Object?> json) => MancalaConfig(
    variant: MancalaVariant.values.byName(json['variant']! as String),
    pitsPerSide: (json['pits']! as num).toInt(),
    seedsPerPit: (json['seeds']! as num).toInt(),
    captureEmptyOpposite: json['captureEmpty']! as bool,
    grandSlamCaptures: json['grandSlam']! as bool,
    moveLimit: (json['moveLimit']! as num).toInt(),
  );

  static const MancalaConfig kalah = MancalaConfig();
  static const MancalaConfig oware = MancalaConfig(variant: MancalaVariant.oware);

  final MancalaVariant variant;
  final int pitsPerSide;
  final int seedsPerPit;

  /// Kalah: a last seed in an own empty pit captures even when the opposite
  /// pit is empty (off by default: nothing is captured then).
  final bool captureEmptyOpposite;

  /// Oware: a move that would capture all the opponent's seeds captures
  /// them anyway (off by default: the "grand slam" captures nothing).
  final bool grandSlamCaptures;

  /// Plies without a capture / store gain after which the game ends and each
  /// player keeps the seeds on their own side (prevents endless cycles).
  final int moveLimit;

  int get totalSeeds => 2 * pitsPerSide * seedsPerPit;

  Map<String, Object?> toJson() => {
    'variant': variant.name,
    'pits': pitsPerSide,
    'seeds': seedsPerPit,
    'captureEmpty': captureEmptyOpposite,
    'grandSlam': grandSlamCaptures,
    'moveLimit': moveLimit,
  };
}

/// Fast mutable position shared by the rules and the AI.
final class MancalaPosition {
  MancalaPosition(this.config, this.pits, this.stores, this.player, this.quiet);

  final MancalaConfig config;
  final List<int> pits;
  final List<int> stores;
  int player;
  int quiet;
  bool over = false;
  GameEndReason? endReason;

  int get n => config.pitsPerSide;

  MancalaPosition copy() => MancalaPosition(config, List.of(pits), List.of(stores), player, quiet);

  int sideSeeds(int p) {
    var s = 0;
    for (var i = p * n; i < (p + 1) * n; i++) {
      s += pits[i];
    }
    return s;
  }

  bool _owns(int p, int pit) => pit >= p * n && pit < (p + 1) * n;

  /// Legal pits for the player to move.
  List<int> legalPits() {
    if (over) return const [];
    final p = player;
    final out = <int>[];
    for (var i = p * n; i < (p + 1) * n; i++) {
      if (pits[i] > 0) out.add(i);
    }
    if (config.variant == MancalaVariant.oware && sideSeeds(1 - p) == 0) {
      // Must feed the opponent when possible.
      return [
        for (final i in out)
          if (_feeds(i)) i,
      ];
    }
    return out;
  }

  bool _feeds(int pit) {
    // Seeds reach the opponent when they pass the end of the mover's row.
    final end = (player + 1) * n - 1;
    return pits[pit] > end - pit;
  }

  /// Plays [pit] (must be legal) and settles end-of-game conditions.
  void play(int pit) {
    if (config.variant == MancalaVariant.kalah) {
      _playKalah(pit);
    } else {
      _playOware(pit);
    }
    _checkEnd();
  }

  void _playKalah(int pit) {
    final p = player;
    final total = 2 * n + 2;
    final storeBefore = stores[p];
    // Ring: pits 0..n-1, store0 (n), pits n..2n-1 at n+1..2n, store1 (2n+1).
    final ownStore = p == 0 ? n : 2 * n + 1;
    final oppStore = p == 0 ? 2 * n + 1 : n;
    var seeds = pits[pit];
    pits[pit] = 0;
    var pos = pit < n ? pit : pit + 1;
    while (seeds > 0) {
      pos = (pos + 1) % total;
      if (pos == oppStore) continue;
      if (pos == ownStore) {
        stores[p]++;
      } else {
        pits[pos < n + 1 ? pos : pos - 1]++;
      }
      seeds--;
    }
    if (pos != ownStore) {
      final last = pos < n + 1 ? pos : pos - 1;
      if (_owns(p, last) && pits[last] == 1) {
        final opposite = 2 * n - 1 - last;
        if (pits[opposite] > 0 || config.captureEmptyOpposite) {
          stores[p] += pits[opposite] + 1;
          pits[opposite] = 0;
          pits[last] = 0;
        }
      }
      player = 1 - p; // otherwise: last seed in own store, move again
    }
    quiet = stores[p] > storeBefore ? 0 : quiet + 1;
  }

  void _playOware(int pit) {
    final p = player;
    final total = 2 * n;
    var seeds = pits[pit];
    pits[pit] = 0;
    var pos = pit;
    while (seeds > 0) {
      pos = (pos + 1) % total;
      if (pos == pit) continue; // never sow into the emptied pit
      pits[pos]++;
      seeds--;
    }
    // Capture backwards from the last pit while on the opponent's side.
    var captured = 0;
    final taken = <int>[];
    var q = pos;
    while (!_owns(p, q) && (pits[q] == 2 || pits[q] == 3)) {
      captured += pits[q];
      taken.add(q);
      q = (q - 1 + total) % total;
    }
    if (captured > 0) {
      final grandSlam = sideSeeds(1 - p) == captured;
      if (!grandSlam || config.grandSlamCaptures) {
        for (final t in taken) {
          pits[t] = 0;
        }
        stores[p] += captured;
        quiet = 0;
      } else {
        quiet++;
      }
    } else {
      quiet++;
    }
    player = 1 - p;
  }

  void _checkEnd() {
    final half = config.totalSeeds ~/ 2;
    if (config.variant == MancalaVariant.kalah) {
      if (sideSeeds(0) == 0 || sideSeeds(1) == 0) {
        _collectOwnSides();
        _finish(GameEndReason.sideEmpty);
        return;
      }
    } else {
      if (stores[0] > half || stores[1] > half) {
        _finish(GameEndReason.majorityCaptured);
        return;
      }
      final p = player;
      if (sideSeeds(p) == 0) {
        // The opponent could not (or did not need to) feed: they keep theirs.
        _collectOwnSides();
        _finish(GameEndReason.cannotFeed);
        return;
      }
      if (sideSeeds(1 - p) == 0 && legalPits().isEmpty) {
        _collectOwnSides();
        _finish(GameEndReason.cannotFeed);
        return;
      }
    }
    if (quiet >= config.moveLimit) {
      _collectOwnSides();
      _finish(GameEndReason.moveLimit);
    }
  }

  void _collectOwnSides() {
    for (var p = 0; p < 2; p++) {
      for (var i = p * n; i < (p + 1) * n; i++) {
        stores[p] += pits[i];
        pits[i] = 0;
      }
    }
  }

  void _finish(GameEndReason reason) {
    over = true;
    endReason = reason;
  }

  GameResult? get result {
    if (!over) return null;
    final scores = List<int>.of(stores);
    if (stores[0] == stores[1]) return GameResult.draw(endReason!, scores: scores);
    return GameResult(winners: [stores[0] > stores[1] ? 0 : 1], reason: endReason!, scores: scores);
  }
}

final class MancalaMove extends GameMove {
  const MancalaMove(this.pit);
  factory MancalaMove.fromJson(Map<String, Object?> json) => MancalaMove((json['pit']! as num).toInt());

  final int pit;

  @override
  Map<String, Object?> toJson() => {'pit': pit};

  @override
  bool operator ==(Object other) => other is MancalaMove && other.pit == pit;

  @override
  int get hashCode => pit.hashCode;

  @override
  String toString() => 'pit$pit';
}

final class MancalaState extends GameState {
  MancalaState({
    required this.config,
    required List<int> pits,
    required List<int> stores,
    required this.currentPlayer,
    this.pliesWithoutCapture = 0,
    this.lastMove,
    this.result,
  }) : pits = List.unmodifiable(pits),
       stores = List.unmodifiable(stores);

  factory MancalaState.initial([MancalaConfig config = MancalaConfig.kalah]) => MancalaState(
    config: config,
    pits: List.filled(2 * config.pitsPerSide, config.seedsPerPit),
    stores: const [0, 0],
    currentPlayer: 0,
  );

  factory MancalaState.fromJson(Map<String, Object?> json) {
    final r = json['result'];
    final last = json['last'] as num?;
    return MancalaState(
      config: MancalaConfig.fromJson(jsonMap(json['config'])),
      pits: intList(json['pits']),
      stores: intList(json['stores']),
      currentPlayer: (json['player']! as num).toInt(),
      pliesWithoutCapture: (json['quiet']! as num).toInt(),
      lastMove: last?.toInt(),
      result: r == null ? null : GameResult.fromJson(jsonMap(r)),
    );
  }

  final MancalaConfig config;
  final List<int> pits;
  final List<int> stores;
  @override
  final int currentPlayer;
  final int pliesWithoutCapture;
  final int? lastMove;
  @override
  final GameResult? result;

  @override
  int get playerCount => 2;

  MancalaPosition toPosition() =>
      MancalaPosition(config, List.of(pits), List.of(stores), currentPlayer, pliesWithoutCapture);

  @override
  Map<String, Object?> toJson() => {
    'config': config.toJson(),
    'pits': pits,
    'stores': stores,
    'player': currentPlayer,
    'quiet': pliesWithoutCapture,
    'last': lastMove,
    if (result != null) 'result': result!.toJson(),
  };
}

final class MancalaRules extends GameRules<MancalaState, MancalaMove> {
  const MancalaRules();

  @override
  BoardGameId get id => BoardGameId.mancala;

  @override
  List<MancalaMove> legalMoves(MancalaState state) {
    if (state.isOver) return const [];
    return [for (final p in state.toPosition().legalPits()) MancalaMove(p)];
  }

  @override
  MancalaState apply(MancalaState state, MancalaMove move) {
    final pos = state.toPosition()..play(move.pit);
    return MancalaState(
      config: state.config,
      pits: pos.pits,
      stores: pos.stores,
      currentPlayer: pos.over ? state.currentPlayer : pos.player,
      pliesWithoutCapture: pos.quiet,
      lastMove: move.pit,
      result: pos.result,
    );
  }

  @override
  MancalaState stateFromJson(Map<String, Object?> json) => MancalaState.fromJson(json);

  @override
  MancalaMove moveFromJson(Map<String, Object?> json) => MancalaMove.fromJson(json);
}

const mancalaRules = MancalaRules();
