/// Word Guess statistics (immutable; persist with toJson / fromJson).
///
/// Daily streaks: a streak continues when the previous recorded daily game
/// was won on the day before; recording the same day twice is ignored, and
/// a missed day or a loss resets the current streak.
library;

/// Statistics for one mode and word length.
final class WordGuessStats {
  /// Creates statistics.
  const WordGuessStats({
    this.played = 0,
    this.won = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.distribution = const [0, 0, 0, 0, 0, 0],
    this.lastDay,
    this.lastWon = false,
  });

  /// Restores from JSON.
  factory WordGuessStats.fromJson(Map<String, Object?> j) => WordGuessStats(
    played: j['played']! as int,
    won: j['won']! as int,
    currentStreak: j['currentStreak']! as int,
    maxStreak: j['maxStreak']! as int,
    distribution: [for (final v in j['distribution']! as List<Object?>) v! as int],
    lastDay: j['lastDay'] as int?,
    lastWon: j['lastWon']! as bool,
  );

  /// Games finished.
  final int played;

  /// Games won.
  final int won;

  /// Consecutive wins (daily: consecutive days).
  final int currentStreak;

  /// Best streak.
  final int maxStreak;

  /// Wins by number of attempts (index 0 = solved in one).
  final List<int> distribution;

  /// Day number of the last recorded daily game.
  final int? lastDay;

  /// Whether the last recorded game was won.
  final bool lastWon;

  /// Win percentage 0–100.
  double get winRate => played == 0 ? 0 : 100.0 * won / played;

  List<int> _withWin(int attempts) {
    final d = [...distribution];
    while (d.length < attempts) {
      d.add(0);
    }
    d[attempts - 1]++;
    return d;
  }

  /// Records a daily game of [day]; ignored when that day was already
  /// recorded.
  WordGuessStats recordDaily(int day, {required bool won, required int attempts}) {
    if (lastDay != null && day <= lastDay!) return this;
    final continues = lastDay != null && day == lastDay! + 1 && lastWon;
    final streak = won ? (continues ? currentStreak + 1 : 1) : 0;
    return WordGuessStats(
      played: played + 1,
      won: this.won + (won ? 1 : 0),
      currentStreak: streak,
      maxStreak: streak > maxStreak ? streak : maxStreak,
      distribution: won ? _withWin(attempts) : distribution,
      lastDay: day,
      lastWon: won,
    );
  }

  /// Records an endless game (streak = consecutive wins).
  WordGuessStats recordEndless({required bool won, required int attempts}) {
    final streak = won ? currentStreak + 1 : 0;
    return WordGuessStats(
      played: played + 1,
      won: this.won + (won ? 1 : 0),
      currentStreak: streak,
      maxStreak: streak > maxStreak ? streak : maxStreak,
      distribution: won ? _withWin(attempts) : distribution,
      lastDay: lastDay,
      lastWon: won,
    );
  }

  /// Serialises.
  Map<String, Object?> toJson() => {
    'played': played,
    'won': won,
    'currentStreak': currentStreak,
    'maxStreak': maxStreak,
    'distribution': distribution,
    'lastDay': lastDay,
    'lastWon': lastWon,
  };
}
