/// Lifetime head-to-head tallies and streaks, updated one match at a time.
///
/// The ledger is independent of the bounded match history: trimming old
/// matches never changes a win count, a best streak or a milestone.
library;

import 'dart:math' as math;

import 'match_record.dart';
import 'player_profile.dart';
import 'together_bounds.dart';

/// Tally of one game (or of all games together).
final class GameTally {
  const GameTally({
    this.winsOne = 0,
    this.winsTwo = 0,
    this.draws = 0,
    this.coopWins = 0,
    this.coopLosses = 0,
    this.streakHolder,
    this.streakLength = 0,
    this.bestStreakOne = 0,
    this.bestStreakTwo = 0,
    this.coopStreak = 0,
    this.bestCoopStreak = 0,
    this.highScoreOne,
    this.highScoreTwo,
    this.lastPlayed,
  });

  static const GameTally empty = GameTally();

  final int winsOne;
  final int winsTwo;
  final int draws;
  final int coopWins;
  final int coopLosses;

  /// Who is on a head-to-head winning run (null after a draw / at start).
  final PlayerSlot? streakHolder;
  final int streakLength;
  final int bestStreakOne;
  final int bestStreakTwo;

  /// Co-op victories in a row.
  final int coopStreak;
  final int bestCoopStreak;

  /// Best score each player has recorded (display only).
  final int? highScoreOne;
  final int? highScoreTwo;
  final DateTime? lastPlayed;

  int get matches => winsOne + winsTwo + draws + coopWins + coopLosses;

  int get versusMatches => winsOne + winsTwo + draws;

  int winsOf(PlayerSlot s) => s == PlayerSlot.one ? winsOne : winsTwo;

  int bestStreakOf(PlayerSlot s) => s == PlayerSlot.one ? bestStreakOne : bestStreakTwo;

  int? highScoreOf(PlayerSlot s) => s == PlayerSlot.one ? highScoreOne : highScoreTwo;

  /// The player ahead on wins (null when level).
  PlayerSlot? get leader => winsOne == winsTwo ? null : (winsOne > winsTwo ? PlayerSlot.one : PlayerSlot.two);

  /// The tally after [r].
  GameTally apply(MatchRecord r) {
    var w1 = winsOne, w2 = winsTwo, d = draws, cw = coopWins, cl = coopLosses;
    var holder = streakHolder;
    var len = streakLength;
    var b1 = bestStreakOne, b2 = bestStreakTwo;
    var cs = coopStreak, bcs = bestCoopStreak;
    switch (r.outcome) {
      case MatchOutcome.oneWon || MatchOutcome.twoWon:
        final winner = r.outcome.winner!;
        if (winner == PlayerSlot.one) {
          w1++;
        } else {
          w2++;
        }
        len = holder == winner ? len + 1 : 1;
        holder = winner;
        if (winner == PlayerSlot.one) {
          b1 = math.max(b1, len);
        } else {
          b2 = math.max(b2, len);
        }
      case MatchOutcome.draw:
        d++;
        holder = null;
        len = 0;
      case MatchOutcome.teamWon:
        cw++;
        cs++;
        bcs = math.max(bcs, cs);
      case MatchOutcome.teamLost:
        cl++;
        cs = 0;
    }
    int? high(int? current, int? score) => score == null ? current : (current == null ? score : math.max(current, score));
    final last = lastPlayed;
    return GameTally(
      winsOne: w1,
      winsTwo: w2,
      draws: d,
      coopWins: cw,
      coopLosses: cl,
      streakHolder: holder,
      streakLength: len,
      bestStreakOne: b1,
      bestStreakTwo: b2,
      coopStreak: cs,
      bestCoopStreak: bcs,
      highScoreOne: high(highScoreOne, r.scoreOne),
      highScoreTwo: high(highScoreTwo, r.scoreTwo),
      lastPlayed: last == null || r.endedAt.isAfter(last) ? r.endedAt : last,
    );
  }

  Map<String, Object?> toJson() => {
    if (winsOne > 0) 'w1': winsOne,
    if (winsTwo > 0) 'w2': winsTwo,
    if (draws > 0) 'd': draws,
    if (coopWins > 0) 'cw': coopWins,
    if (coopLosses > 0) 'cl': coopLosses,
    if (streakHolder != null) 'sh': streakHolder!.name,
    if (streakLength > 0) 'sl': streakLength,
    if (bestStreakOne > 0) 'b1': bestStreakOne,
    if (bestStreakTwo > 0) 'b2': bestStreakTwo,
    if (coopStreak > 0) 'cs': coopStreak,
    if (bestCoopStreak > 0) 'bc': bestCoopStreak,
    'h1': ?highScoreOne,
    'h2': ?highScoreTwo,
    't': ?lastPlayed?.millisecondsSinceEpoch,
  };

  static GameTally fromJson(Object? json) {
    if (json is! Map) return empty;
    int c(String k) => TogetherBounds.count(json[k]);
    final t = json['t'];
    final holder = PlayerSlot.tryParse(json['sh']);
    final len = c('sl');
    return GameTally(
      winsOne: c('w1'),
      winsTwo: c('w2'),
      draws: c('d'),
      coopWins: c('cw'),
      coopLosses: c('cl'),
      streakHolder: len > 0 ? holder : null,
      streakLength: holder == null ? 0 : len,
      bestStreakOne: c('b1'),
      bestStreakTwo: c('b2'),
      coopStreak: c('cs'),
      bestCoopStreak: c('bc'),
      highScoreOne: TogetherBounds.score(json['h1']),
      highScoreTwo: TogetherBounds.score(json['h2']),
      lastPlayed: TogetherBounds.time(t),
    );
  }
}

/// Everything the couple has played: the overall tally, one tally per game,
/// and the "days in a row we played" streak.
final class TogetherLedger {
  const TogetherLedger({
    this.overall = GameTally.empty,
    this.games = const {},
    this.lastDay,
    this.dayStreak = 0,
    this.bestDayStreak = 0,
    this.matchesOnLastDay = 0,
    this.bestMatchesInDay = 0,
    this.firstPlayed,
  });

  static const TogetherLedger empty = TogetherLedger();

  final GameTally overall;

  /// Per game id (at most [TogetherBounds.maxGames]).
  final Map<String, GameTally> games;

  /// Local calendar day ([TogetherDays.indexOf]) of the latest match.
  final int? lastDay;

  /// Consecutive days with at least one match, ending at [lastDay].
  final int dayStreak;
  final int bestDayStreak;
  final int matchesOnLastDay;
  final int bestMatchesInDay;
  final DateTime? firstPlayed;

  bool get isEmpty => overall.matches == 0;

  /// The playing streak as of [now]: alive when the last match was today or
  /// yesterday, else 0.
  int currentDayStreak(DateTime now) {
    final last = lastDay;
    if (last == null) return 0;
    final today = TogetherDays.indexOf(now);
    return last == today || last == today - 1 ? dayStreak : 0;
  }

  /// Whether the couple already played today.
  bool playedToday(DateTime now) => lastDay == TogetherDays.indexOf(now);

  GameTally tallyOf(String gameId) => games[gameId] ?? GameTally.empty;

  /// Games, most recently played first.
  List<MapEntry<String, GameTally>> get gamesByRecency {
    final list = games.entries.toList()
      ..sort((a, b) {
        final ta = a.value.lastPlayed?.millisecondsSinceEpoch ?? 0;
        final tb = b.value.lastPlayed?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
    return list;
  }

  /// The ledger after [r].
  TogetherLedger apply(MatchRecord r) {
    final nextGames = Map<String, GameTally>.of(games);
    nextGames[r.gameId] = tallyOf(r.gameId).apply(r);
    while (nextGames.length > TogetherBounds.maxGames) {
      // Drop the least recently played game (never the one just played).
      final oldest = nextGames.entries.where((e) => e.key != r.gameId).reduce((a, b) {
        final ta = a.value.lastPlayed?.millisecondsSinceEpoch ?? 0;
        final tb = b.value.lastPlayed?.millisecondsSinceEpoch ?? 0;
        return tb < ta ? b : a;
      });
      nextGames.remove(oldest.key);
    }

    final day = TogetherDays.indexOf(r.endedAt);
    var last = lastDay;
    var streak = dayStreak;
    var onDay = matchesOnLastDay;
    if (last == null) {
      last = day;
      streak = 1;
      onDay = 1;
    } else if (day == last) {
      onDay++;
    } else if (day == last + 1) {
      last = day;
      streak++;
      onDay = 1;
    } else if (day > last + 1) {
      last = day;
      streak = 1;
      onDay = 1;
    }
    // A late record (day < last) counts in the tallies but never rewinds the
    // day streak.
    final first = firstPlayed;
    return TogetherLedger(
      overall: overall.apply(r),
      games: nextGames,
      lastDay: last,
      dayStreak: streak,
      bestDayStreak: math.max(bestDayStreak, streak),
      matchesOnLastDay: onDay,
      bestMatchesInDay: math.max(bestMatchesInDay, onDay),
      firstPlayed: first == null || r.endedAt.isBefore(first) ? r.endedAt : first,
    );
  }

  Map<String, Object?> toJson() => {
    'v': 1,
    'all': overall.toJson(),
    'games': {for (final e in games.entries) e.key: e.value.toJson()},
    'ld': ?lastDay,
    'ds': dayStreak,
    'bds': bestDayStreak,
    'dc': matchesOnLastDay,
    'bdc': bestMatchesInDay,
    'f': ?firstPlayed?.millisecondsSinceEpoch,
  };

  static TogetherLedger fromJson(Object? json) {
    if (json is! Map) return empty;
    final gamesJson = json['games'];
    final games = <String, GameTally>{};
    if (gamesJson is Map) {
      for (final e in gamesJson.entries) {
        final k = e.key;
        if (k is String && TogetherBounds.isValidId(k) && games.length < TogetherBounds.maxGames) {
          games[k] = GameTally.fromJson(e.value);
        }
      }
    }
    final ld = json['ld'];
    final f = json['f'];
    return TogetherLedger(
      overall: GameTally.fromJson(json['all']),
      games: games,
      lastDay: ld is int ? ld : null,
      dayStreak: TogetherBounds.count(json['ds']),
      bestDayStreak: TogetherBounds.count(json['bds']),
      matchesOnLastDay: TogetherBounds.count(json['dc']),
      bestMatchesInDay: TogetherBounds.count(json['bdc']),
      firstPlayed: TogetherBounds.time(f),
    );
  }
}
