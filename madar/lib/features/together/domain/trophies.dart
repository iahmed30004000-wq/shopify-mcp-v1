/// "Our Hall of Fame" (قاعة مجدنا): trophies the couple earns from records,
/// streaks and milestones.
library;

import 'dart:math' as math;

import 'head_to_head.dart';
import 'match_record.dart';
import 'player_profile.dart';
import 'together_bounds.dart';

/// Medal metal of a trophy.
enum TrophyTier { bronze, silver, gold, legendary }

/// Who holds a trophy.
enum TrophyScope {
  /// Earned by the couple together.
  shared,

  /// Earned by one player.
  player,

  /// Earned by one player in one game.
  playerGame,
}

/// Every trophy. [target] is the number the rule counts towards.
enum TrophyId {
  firstMatch(TrophyTier.bronze, TrophyScope.shared, 1),
  matches10(TrophyTier.bronze, TrophyScope.shared, 10),
  matches50(TrophyTier.silver, TrophyScope.shared, 50),
  matches100(TrophyTier.gold, TrophyScope.shared, 100),
  matches250(TrophyTier.legendary, TrophyScope.shared, 250),
  dayStreak3(TrophyTier.bronze, TrophyScope.shared, 3),
  dayStreak7(TrophyTier.silver, TrophyScope.shared, 7),
  dayStreak30(TrophyTier.legendary, TrophyScope.shared, 30),
  winStreak3(TrophyTier.bronze, TrophyScope.player, 3),
  winStreak5(TrophyTier.silver, TrophyScope.player, 5),
  winStreak10(TrophyTier.gold, TrophyScope.player, 10),
  explorer5(TrophyTier.silver, TrophyScope.shared, 5),
  explorer10(TrophyTier.gold, TrophyScope.shared, 10),
  coopWins5(TrophyTier.silver, TrophyScope.shared, 5),
  coopWins25(TrophyTier.gold, TrophyScope.shared, 25),
  marathon(TrophyTier.silver, TrophyScope.shared, 5),
  photoFinish(TrophyTier.bronze, TrophyScope.shared, 1),
  nailBiter(TrophyTier.bronze, TrophyScope.player, 1),
  perfectBalance(TrophyTier.gold, TrophyScope.shared, 20),
  gameMaster(TrophyTier.gold, TrophyScope.playerGame, 10);

  const TrophyId(this.tier, this.scope, this.target);

  final TrophyTier tier;
  final TrophyScope scope;
  final int target;
}

/// Identity of an earned trophy: the rule, its holder (player trophies) and
/// the game (per-game trophies).
final class TrophyKey {
  const TrophyKey(this.id, {this.holder, this.gameId});

  final TrophyId id;
  final PlayerSlot? holder;
  final String? gameId;

  String get storageKey => '${id.name}|${holder?.name ?? ''}|${gameId ?? ''}';

  @override
  bool operator ==(Object other) =>
      other is TrophyKey && other.id == id && other.holder == holder && other.gameId == gameId;

  @override
  int get hashCode => Object.hash(id, holder, gameId);

  @override
  String toString() => 'TrophyKey($storageKey)';
}

/// A trophy on the shelf.
final class EarnedTrophy {
  const EarnedTrophy({required this.key, required this.earnedAt, this.matchId});

  final TrophyKey key;
  final DateTime earnedAt;

  /// The match that earned it.
  final String? matchId;

  TrophyId get id => key.id;

  Map<String, Object?> toJson() => {
    'id': key.id.name,
    'h': ?key.holder?.name,
    'g': ?key.gameId,
    't': earnedAt.millisecondsSinceEpoch,
    'm': ?matchId,
  };

  static EarnedTrophy? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = TrophyId.values.where((t) => t.name == json['id']).firstOrNull;
    final t = TogetherBounds.time(json['t']);
    if (id == null || t == null) return null;
    final holder = PlayerSlot.tryParse(json['h']);
    final game = json['g'];
    final match = json['m'];
    if (id.scope != TrophyScope.shared && holder == null) return null;
    if (id.scope == TrophyScope.playerGame && game is! String) return null;
    return EarnedTrophy(
      key: TrophyKey(
        id,
        holder: id.scope == TrophyScope.shared ? null : holder,
        gameId: id.scope == TrophyScope.playerGame ? game as String : null,
      ),
      earnedAt: t,
      matchId: match is String && match.length <= 64 ? match : null,
    );
  }
}

/// Progress towards a trophy that is not on the shelf yet.
final class TrophyProgress {
  const TrophyProgress(this.current, this.target);

  final int current;
  final int target;

  double get fraction => target <= 0 ? 1 : (current / target).clamp(0.0, 1.0);
}

/// The trophy rules: pure functions of the ledger (and the match that just
/// ended). Every rule is monotonic, so re-evaluating never takes a trophy
/// away; the repository only adds keys that are not on the shelf yet.
abstract final class TrophyRules {
  /// Every trophy whose condition holds after [record] was applied, giving
  /// [ledger]. Includes trophies earned earlier (the caller filters them).
  static List<TrophyKey> satisfied(TogetherLedger ledger, MatchRecord record) {
    final all = ledger.overall;
    final keys = <TrophyKey>[];
    void shared(TrophyId id, bool when) {
      if (when) keys.add(TrophyKey(id));
    }

    shared(TrophyId.firstMatch, all.matches >= TrophyId.firstMatch.target);
    shared(TrophyId.matches10, all.matches >= TrophyId.matches10.target);
    shared(TrophyId.matches50, all.matches >= TrophyId.matches50.target);
    shared(TrophyId.matches100, all.matches >= TrophyId.matches100.target);
    shared(TrophyId.matches250, all.matches >= TrophyId.matches250.target);
    shared(TrophyId.dayStreak3, ledger.dayStreak >= TrophyId.dayStreak3.target);
    shared(TrophyId.dayStreak7, ledger.dayStreak >= TrophyId.dayStreak7.target);
    shared(TrophyId.dayStreak30, ledger.dayStreak >= TrophyId.dayStreak30.target);
    shared(TrophyId.explorer5, ledger.games.length >= TrophyId.explorer5.target);
    shared(TrophyId.explorer10, ledger.games.length >= TrophyId.explorer10.target);
    shared(TrophyId.coopWins5, all.coopWins >= TrophyId.coopWins5.target);
    shared(TrophyId.coopWins25, all.coopWins >= TrophyId.coopWins25.target);
    shared(TrophyId.marathon, ledger.matchesOnLastDay >= TrophyId.marathon.target);
    shared(TrophyId.photoFinish, record.outcome == MatchOutcome.draw);
    shared(
      TrophyId.perfectBalance,
      all.versusMatches >= TrophyId.perfectBalance.target && all.winsOne == all.winsTwo && all.winsOne > 0,
    );

    final holder = all.streakHolder;
    if (holder != null) {
      for (final id in const [TrophyId.winStreak3, TrophyId.winStreak5, TrophyId.winStreak10]) {
        if (all.streakLength >= id.target) keys.add(TrophyKey(id, holder: holder));
      }
    }

    final winner = record.outcome.winner;
    if (winner != null) {
      if (record.margin == 1) keys.add(TrophyKey(TrophyId.nailBiter, holder: winner));
      if (ledger.tallyOf(record.gameId).winsOf(winner) >= TrophyId.gameMaster.target) {
        keys.add(TrophyKey(TrophyId.gameMaster, holder: winner, gameId: record.gameId));
      }
    }
    return keys;
  }

  /// How close the couple is to [id] (the better player for player trophies).
  static TrophyProgress progress(TrophyId id, TogetherLedger ledger) {
    final all = ledger.overall;
    final current = switch (id) {
      TrophyId.firstMatch ||
      TrophyId.matches10 ||
      TrophyId.matches50 ||
      TrophyId.matches100 ||
      TrophyId.matches250 => all.matches,
      TrophyId.dayStreak3 || TrophyId.dayStreak7 || TrophyId.dayStreak30 => ledger.bestDayStreak,
      TrophyId.winStreak3 ||
      TrophyId.winStreak5 ||
      TrophyId.winStreak10 => math.max(all.bestStreakOne, all.bestStreakTwo),
      TrophyId.explorer5 || TrophyId.explorer10 => ledger.games.length,
      TrophyId.coopWins5 || TrophyId.coopWins25 => all.coopWins,
      TrophyId.marathon => ledger.bestMatchesInDay,
      TrophyId.photoFinish => all.draws > 0 ? 1 : 0,
      TrophyId.nailBiter => 0,
      TrophyId.perfectBalance => all.versusMatches,
      TrophyId.gameMaster => ledger.games.values.fold(0, (m, t) => math.max(m, math.max(t.winsOne, t.winsTwo))),
    };
    return TrophyProgress(math.min(current, id.target), id.target);
  }
}

/// The shelf: earned trophies (bounded, newest last) with look-ups.
final class TrophyShelf {
  const TrophyShelf(this.trophies);

  static const TrophyShelf empty = TrophyShelf([]);

  final List<EarnedTrophy> trophies;

  bool has(TrophyKey key) => trophies.any((t) => t.key == key);

  /// Whether any trophy of [id] is on the shelf (any holder / game).
  bool hasAny(TrophyId id) => trophies.any((t) => t.id == id);

  /// Newest first.
  List<EarnedTrophy> get newestFirst => trophies.reversed.toList();

  List<Map<String, Object?>> toJson() => [for (final t in trophies) t.toJson()];

  static TrophyShelf fromJson(Object? json, {int max = 256}) {
    if (json is! List) return empty;
    final seen = <TrophyKey>{};
    final list = <EarnedTrophy>[];
    for (final item in json) {
      final t = EarnedTrophy.fromJson(item);
      if (t != null && seen.add(t.key)) list.add(t);
    }
    return TrophyShelf(list.length > max ? list.sublist(list.length - max) : list);
  }
}

/// What recording a finished match did.
final class RecordedMatch {
  const RecordedMatch({required this.record, required this.duplicate, this.newTrophies = const []});

  final MatchRecord record;

  /// The match id was already in the history: nothing changed.
  final bool duplicate;

  /// Trophies this match put on the shelf (celebrate them).
  final List<EarnedTrophy> newTrophies;
}
