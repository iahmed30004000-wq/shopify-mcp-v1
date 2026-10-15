/// The playable Tangram puzzle.
library;

import '../core/puzzle_game.dart';
import 'tangram.dart';
import 'tangram_library.dart';

export 'tangram.dart';
export 'tangram_library.dart';

final class TangramConfig {
  /// A library figure.
  const TangramConfig.library(String this.silhouetteId) : abstractSeed = null;

  /// A generated abstract figure.
  const TangramConfig.abstract(int this.abstractSeed) : silhouetteId = null;

  /// Picks a library figure of [d] from [seed]; expert alternates between
  /// the expert figures and generated abstract ones.
  factory TangramConfig.forDifficulty(PuzzleDifficulty d, int seed) {
    final pool = TangramLibrary.forDifficulty(d);
    if (d == PuzzleDifficulty.expert && seed.isOdd) return TangramConfig.abstract(seed);
    return TangramConfig.library(pool[seed.abs() % pool.length].id);
  }

  final String? silhouetteId;
  final int? abstractSeed;

  TangramSilhouette resolve() =>
      silhouetteId != null ? TangramLibrary.byId(silhouetteId!) : TangramSilhouette.random(abstractSeed!);

  Map<String, Object?> toJson() => {'id': silhouetteId, 'abstract': abstractSeed};

  factory TangramConfig.fromJson(Map<String, Object?> j) => j['id'] != null
      ? TangramConfig.library(j['id']! as String)
      : TangramConfig.abstract((j['abstract']! as num).toInt());
}

final class TangramState extends PuzzleState {
  const TangramState({required this.placements, this.moves = 0});

  /// Per piece id: its placement, or null while it waits in the tray.
  final List<TanPlacement?> placements;
  final int moves;

  List<TanPlacement> get placed => [for (final p in placements) ?p];

  @override
  Map<String, Object?> toJson() => {
    'placements': [for (final p in placements) p?.toJson()],
    'moves': moves,
  };

  factory TangramState.fromJson(Map<String, Object?> j) => TangramState(
    placements: List.unmodifiable([
      for (final p in j['placements']! as List) p == null ? null : TanPlacement.fromJson(jsonObject(p)),
    ]),
    moves: jsonInt(j, 'moves'),
  );
}

enum TangramActionType { place, remove }

final class TangramAction extends PuzzleAction {
  /// Puts `placement.piece` at [placement] (moving it when already placed).
  const TangramAction.place(TanPlacement this.placement) : type = TangramActionType.place, piece = null;

  /// Returns [piece] to the tray.
  const TangramAction.remove(TanPiece this.piece) : type = TangramActionType.remove, placement = null;

  final TangramActionType type;
  final TanPlacement? placement;
  final TanPiece? piece;

  TanPiece get target => placement?.piece ?? piece!;

  @override
  Map<String, Object?> toJson() => {
    't': type.name,
    if (placement != null) 'p': placement!.toJson(),
    if (piece != null) 'piece': piece!.index,
  };

  factory TangramAction.fromJson(Map<String, Object?> j) => j['t'] == TangramActionType.remove.name
      ? TangramAction.remove(TanPiece.values[jsonInt(j, 'piece')])
      : TangramAction.place(TanPlacement.fromJson(jsonObject(j['p'])));

  @override
  bool operator ==(Object other) =>
      other is TangramAction && other.type == type && other.placement == placement && other.piece == piece;

  @override
  int get hashCode => Object.hash(type, placement, piece);

  @override
  String toString() => 'TangramAction(${type.name}, ${placement ?? piece})';
}

/// A Tangram game. The silhouette occupies `[0, width] × [0, height]` tan
/// units; pieces may overlap while being arranged, the win test forbids it.
final class TangramGame extends PuzzleBase<TangramState, TangramAction> {
  TangramGame(this.config, {TangramState? state, super.history})
    : silhouette = config.resolve(),
      super(state ?? TangramState(placements: List.unmodifiable(List<TanPlacement?>.filled(7, null))));

  factory TangramGame.fromJson(Map<String, Object?> json) {
    checkKind(json, PuzzleKind.tangram);
    return TangramGame(
      TangramConfig.fromJson(jsonObject(json['config'])),
      state: TangramState.fromJson(jsonObject(json['state'])),
      history: jsonHistory(json, TangramState.fromJson),
    );
  }

  final TangramConfig config;
  final TangramSilhouette silhouette;

  @override
  PuzzleKind get kind => PuzzleKind.tangram;

  List<TanPlacement> get reference => silhouette.solution!;

  static bool _even(Surd s) => s.a.isEven && s.b.isEven;

  @override
  TangramState? transition(TangramState s, TangramAction a) {
    final i = a.target.index;
    switch (a.type) {
      case TangramActionType.place:
        final p = a.placement!;
        if (p.rotation < 0 || p.rotation > 7) return null;
        if (!_even(p.offset.x) || !_even(p.offset.y)) return null;
        if (s.placements[i] == p) return null;
        return TangramState(
          placements: List.unmodifiable(List<TanPlacement?>.from(s.placements)..[i] = p),
          moves: s.moves + 1,
        );
      case TangramActionType.remove:
        if (s.placements[i] == null) return null;
        return TangramState(
          placements: List.unmodifiable(List<TanPlacement?>.from(s.placements)..[i] = null),
          moves: s.moves + 1,
        );
    }
  }

  /// Snapping anchors: silhouette vertices plus the vertices of every placed
  /// piece except [moving].
  List<SPoint> anchors({TanPiece? moving}) => {
    ...silhouette.anchors,
    for (final p in state.placed)
      if (p.piece != moving) ...p.outline,
  }.toList();

  /// Converts a drag position (tan units) into an exact placement.
  TanPlacement snap(TanPiece piece, {required int rotation, bool flipped = false, required double x, required double y}) =>
      snapPlacement(piece, rotation: rotation, flipped: flipped, x: x, y: y, anchors: anchors(moving: piece));

  /// Pieces overlapping another placed piece (for feedback).
  Set<TanPiece> overlapping() {
    final placed = state.placed;
    final out = <TanPiece>{};
    for (var i = 0; i < placed.length; i++) {
      for (var j = i + 1; j < placed.length; j++) {
        if (TangramRules.overlaps(placed[i], placed[j])) out.addAll([placed[i].piece, placed[j].piece]);
      }
    }
    return out;
  }

  @override
  bool get isSolved {
    final placed = state.placed;
    return placed.length == 7 && TangramRules.coversExactly(placed, reference);
  }

  @override
  bool get isOver => isSolved;

  /// Places the next reference tan that no piece of its shape occupies yet.
  @override
  PuzzleHint<TangramAction>? hint() {
    if (isSolved) return null;
    final placed = state.placed;
    final correct = <TanPiece>{};
    final missing = <TanPlacement>[];
    for (final r in reference) {
      final match = placed.where((p) => p.piece.shape == r.piece.shape && !correct.contains(p.piece) && p.sameRegion(r));
      if (match.isNotEmpty) {
        correct.add(match.first.piece);
      } else {
        missing.add(r);
      }
    }
    if (missing.isEmpty) return null;
    final r = missing.first;
    final piece = TanPiece.values.firstWhere((p) => p.shape == r.piece.shape && !correct.contains(p));
    return PuzzleHint(TangramAction.place(r.copyWith(piece: piece)), technique: 'referenceTan', focus: [piece.index]);
  }

  @override
  Map<String, Object?> configJson() => config.toJson();
}
