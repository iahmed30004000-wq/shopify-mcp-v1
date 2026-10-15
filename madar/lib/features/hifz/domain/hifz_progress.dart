/// «التقدّم» · streaks and the heatmap, read off the log (Part 14).
///
/// Pure Dart, and nothing new is measured: the days and the streak are
/// Part 13's own [TasmeeStats], and the heat is [HifzStrengths]. This file
/// only puts them in the shape the progress screen of step 2 draws – a day
/// grid, a count per band, and the weakest places first.
library;

import 'package:meta/meta.dart';

import '../../tasmee/tasmee.dart';
import '../../wird/domain/calendar_days.dart';
import 'hifz_page_map.dart';
import 'hifz_strength.dart';

/// One day of the heatmap.
@immutable
final class HifzDay {
  const HifzDay({
    required this.day,
    required this.ayat,
    required this.words,
    required this.right,
    required this.mistakes,
    required this.hints,
    required this.seconds,
    required this.sessions,
  });

  final DateTime day;

  /// Ayah attempts that day (an ayah done twice counts twice).
  final int ayat;
  final int words;
  final int right;
  final int mistakes;
  final int hints;
  final int seconds;
  final int sessions;

  double? get accuracy => words == 0 ? null : right / words;

  bool get isClean => mistakes == 0 && ayat > 0;

  @override
  String toString() => 'HifzDay(${CalendarDays.key(day)}, $ayat ayat)';
}

/// Everything «التقدّم» shows.
@immutable
final class HifzProgress {
  const HifzProgress._({
    required this.days,
    required this.streakDays,
    required this.bestStreak,
    required this.bands,
    required this.testedAyat,
    required this.memorisedAyat,
    required this.pageMap,
    required this.totalSeconds,
    required this.sessions,
    this.firstDay,
    this.lastDay,
  });

  /// Reads it all off the log and the strengths.
  factory HifzProgress.of({
    required TasmeeStats stats,
    required HifzStrengths strengths,
    required HifzPageMap pageMap,
  }) {
    final days = [
      for (final d in stats.days)
        HifzDay(
          day: d.day,
          ayat: d.ayat,
          words: d.words,
          right: d.right,
          mistakes: d.mistakes,
          hints: d.hints,
          seconds: d.seconds,
          sessions: d.sessions,
        ),
    ];
    final bands = <StrengthBand, int>{for (final b in StrengthBand.values) b: 0};
    for (final s in strengths.byRef.values) {
      bands[s.band] = (bands[s.band] ?? 0) + 1;
    }
    var best = 0, run = 0;
    DateTime? previous;
    for (final d in days) {
      if (previous != null && CalendarDays.between(previous, d.day) == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      previous = d.day;
    }
    return HifzProgress._(
      days: List.unmodifiable(days),
      streakDays: stats.streakDays,
      bestStreak: best,
      bands: Map.unmodifiable(bands),
      testedAyat: strengths.byRef.length,
      memorisedAyat: pageMap.memorisedAyat,
      pageMap: pageMap,
      totalSeconds: stats.seconds,
      sessions: stats.sessions,
      firstDay: days.isEmpty ? null : days.first.day,
      lastDay: days.isEmpty ? null : days.last.day,
    );
  }

  /// Every day he did something, oldest first.
  final List<HifzDay> days;

  /// Days in a row up to today (or up to yesterday while today is still
  /// empty, so a streak is not broken before the day is over).
  final int streakDays;

  /// The longest run he ever had.
  final int bestStreak;

  /// How many ayat sit in each band.
  final Map<StrengthBand, int> bands;

  /// Ayat with a real result behind them.
  final int testedAyat;

  /// Ayat in his Hifz list.
  final int memorisedAyat;

  /// The same page and surah heat the map screen draws.
  final HifzPageMap pageMap;

  final int totalSeconds;
  final int sessions;
  final DateTime? firstDay;
  final DateTime? lastDay;

  /// Ayat of his list he has never been tested on.
  int get untestedAyat => memorisedAyat > testedAyat ? memorisedAyat - testedAyat : 0;

  /// The surahs with the weakest results first (tested ones only).
  List<SurahStrength> weakestSurahs({int limit = 10}) {
    final known = [for (final s in pageMap.surahs) if (s.strength != null) s]
      ..sort((a, b) {
        final c = a.strength!.compareTo(b.strength!);
        return c != 0 ? c : a.surah.compareTo(b.surah);
      });
    return known.take(limit).toList();
  }

  bool get isEmpty => days.isEmpty && testedAyat == 0;

  @override
  String toString() => 'HifzProgress(${days.length} days, streak $streakDays, $testedAyat ayat tested)';
}
