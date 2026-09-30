/// One finished match between the two players.
library;

import 'play_modes.dart';
import 'player_profile.dart';
import 'together_bounds.dart';

/// How a match ended, from the couple's point of view.
enum MatchOutcome {
  oneWon,
  twoWon,
  draw,

  /// Both players on the winning side (co-op, or partners in Tarneeb).
  teamWon,

  /// Both players on the losing side (co-op loss, or an AI won).
  teamLost;

  /// The winning player of a head-to-head match.
  PlayerSlot? get winner => switch (this) {
    oneWon => PlayerSlot.one,
    twoWon => PlayerSlot.two,
    _ => null,
  };

  /// A head-to-head result (counts towards win streaks).
  bool get isVersus => this == oneWon || this == twoWon || this == draw;

  bool get isCoop => this == teamWon || this == teamLost;

  static MatchOutcome win(PlayerSlot slot) => slot == PlayerSlot.one ? oneWon : twoWon;

  static MatchOutcome? tryParse(Object? v) => values.where((o) => o.name == v).firstOrNull;
}

/// A recorded match. Compact JSON: history keeps hundreds of these.
final class MatchRecord {
  const MatchRecord({
    required this.id,
    required this.gameId,
    required this.endedAt,
    required this.outcome,
    this.scoreOne,
    this.scoreTwo,
    this.mode = PlayMode.passAndPlay,
    this.durationSeconds,
  });

  /// Unique per match (the session id); recording the same id twice is a
  /// no-op, so both phones of a two-phone game can record safely.
  final String id;
  final String gameId;
  final DateTime endedAt;
  final MatchOutcome outcome;
  final int? scoreOne;
  final int? scoreTwo;
  final PlayMode mode;
  final int? durationSeconds;

  int? scoreOf(PlayerSlot slot) => slot == PlayerSlot.one ? scoreOne : scoreTwo;

  bool get hasScores => scoreOne != null && scoreTwo != null;

  /// Score difference of a head-to-head match with both scores.
  int? get margin => hasScores ? (scoreOne! - scoreTwo!).abs() : null;

  /// Whether the record can be stored (valid ids).
  bool get isValid => TogetherBounds.isValidId(id) && TogetherGames.isValidId(gameId);

  Map<String, Object?> toJson() => {
    'i': id,
    'g': gameId,
    't': endedAt.millisecondsSinceEpoch,
    'o': outcome.name,
    'a': ?scoreOne,
    'b': ?scoreTwo,
    'm': mode.name,
    'd': ?durationSeconds,
  };

  /// A stored record, or null when it is unusable (it is then dropped).
  static MatchRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['i'];
    final game = json['g'];
    final t = json['t'];
    final outcome = MatchOutcome.tryParse(json['o']);
    if (id is! String || !TogetherBounds.isValidId(id)) return null;
    if (game is! String || !TogetherGames.isValidId(game)) return null;
    if (t is! int || outcome == null) return null;
    final d = json['d'];
    return MatchRecord(
      id: id,
      gameId: game,
      endedAt: DateTime.fromMillisecondsSinceEpoch(t),
      outcome: outcome,
      scoreOne: TogetherBounds.score(json['a']),
      scoreTwo: TogetherBounds.score(json['b']),
      mode: PlayMode.tryParse(json['m']) ?? PlayMode.passAndPlay,
      durationSeconds: d == null ? null : TogetherBounds.count(d, max: TogetherBounds.maxDurationSeconds),
    );
  }

  /// This record with every field clamped to the storage bounds.
  MatchRecord bounded() => MatchRecord(
    id: id,
    gameId: gameId,
    endedAt: endedAt,
    outcome: outcome,
    scoreOne: TogetherBounds.score(scoreOne),
    scoreTwo: TogetherBounds.score(scoreTwo),
    mode: mode,
    durationSeconds: durationSeconds == null
        ? null
        : TogetherBounds.count(durationSeconds, max: TogetherBounds.maxDurationSeconds),
  );

  @override
  bool operator ==(Object other) =>
      other is MatchRecord &&
      other.id == id &&
      other.gameId == gameId &&
      other.endedAt == endedAt &&
      other.outcome == outcome &&
      other.scoreOne == scoreOne &&
      other.scoreTwo == scoreTwo &&
      other.mode == mode &&
      other.durationSeconds == durationSeconds;

  @override
  int get hashCode => Object.hash(id, gameId, endedAt, outcome, scoreOne, scoreTwo, mode, durationSeconds);

  @override
  String toString() => 'MatchRecord($id, $gameId, ${outcome.name}, $scoreOne–$scoreTwo)';
}
