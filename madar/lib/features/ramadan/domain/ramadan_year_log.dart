import 'package:flutter/foundation.dart';

import 'taraweeh_log.dart';

/// Everything kept about one Ramadan, keyed by its Hijri year.
@immutable
class RamadanYearLog {
  RamadanYearLog({required this.hijriYear, TaraweehLog? taraweeh, this.pagesRead = 0, Iterable<int>? fastingDays})
    : taraweeh = taraweeh ?? TaraweehLog(),
      fastingDays = fastingDays == null
          ? null
          : Set.unmodifiable({
              for (final d in fastingDays)
                if (d >= 1 && d <= TaraweehLog.maxNights) d,
            });

  factory RamadanYearLog.fromJson(Map<String, dynamic> json) {
    final fasting = json['fastingDays'];
    final pages = json['pagesRead'];
    return RamadanYearLog(
      hijriYear: json['hijriYear'] is int ? json['hijriYear'] as int : 0,
      taraweeh: TaraweehLog.fromJson(json['taraweeh']),
      pagesRead: pages is int && pages > 0 ? pages : 0,
      fastingDays: fasting is List ? fasting.whereType<int>() : null,
    );
  }

  final int hijriYear;
  final TaraweehLog taraweeh;

  /// Quran pages read in the month (from the khatmah frontier or by hand).
  final int pagesRead;

  /// Days of Ramadan he fasted; null when fasting was not tracked this year.
  final Set<int>? fastingDays;

  RamadanYearLog copyWith({TaraweehLog? taraweeh, int? pagesRead, Iterable<int>? fastingDays}) => RamadanYearLog(
    hijriYear: hijriYear,
    taraweeh: taraweeh ?? this.taraweeh,
    pagesRead: pagesRead ?? this.pagesRead,
    fastingDays: fastingDays ?? this.fastingDays,
  );

  Map<String, dynamic> toJson() => {
    'hijriYear': hijriYear,
    'taraweeh': taraweeh.toJson(),
    'pagesRead': pagesRead,
    if (fastingDays != null) 'fastingDays': (fastingDays!.toList()..sort()),
  };

  @override
  bool operator ==(Object other) =>
      other is RamadanYearLog &&
      other.hijriYear == hijriYear &&
      other.taraweeh == taraweeh &&
      other.pagesRead == pagesRead &&
      setEquals(other.fastingDays, fastingDays);

  @override
  int get hashCode => Object.hash(
    hijriYear,
    taraweeh,
    pagesRead,
    fastingDays == null ? null : Object.hashAll((fastingDays!.toList()..sort())),
  );
}

/// All the years side by side (keyed by Hijri year).
@immutable
class RamadanLogBook {
  RamadanLogBook([Iterable<RamadanYearLog> years = const []])
    : _years = Map.unmodifiable({for (final y in years) y.hijriYear: y});

  factory RamadanLogBook.fromJson(Object? json) {
    final list = json is Map ? json['years'] : json;
    if (list is! List) return RamadanLogBook();
    return RamadanLogBook([
      for (final y in list)
        if (y is Map<String, dynamic> && y['hijriYear'] is int && (y['hijriYear'] as int) > 0)
          RamadanYearLog.fromJson(y),
    ]);
  }

  final Map<int, RamadanYearLog> _years;

  /// Hijri years with a log, newest first.
  List<int> get years => _years.keys.toList()..sort((a, b) => b.compareTo(a));

  RamadanYearLog? of(int hijriYear) => _years[hijriYear];

  /// The log of [hijriYear] or a fresh empty one (does not store it).
  RamadanYearLog ofOrEmpty(int hijriYear) => _years[hijriYear] ?? RamadanYearLog(hijriYear: hijriYear);

  /// The newest log before [hijriYear] (last year's, or the one before it if
  /// he skipped a year in the app).
  RamadanYearLog? previousOf(int hijriYear) {
    for (final y in years) {
      if (y < hijriYear) return _years[y];
    }
    return null;
  }

  RamadanLogBook withYear(RamadanYearLog log) =>
      RamadanLogBook([..._years.values.where((y) => y.hijriYear != log.hijriYear), log]);

  Map<String, dynamic> toJson() => {
    'years': [for (final y in years.reversed) _years[y]!.toJson()],
  };

  @override
  bool operator ==(Object other) => other is RamadanLogBook && mapEquals(other._years, _years);

  @override
  int get hashCode => Object.hashAll([for (final y in years) _years[y]]);
}

/// How the two years differ on one night.
enum NightDifference { both, onlyThisYear, onlyLastYear, neither }

@immutable
class NightComparison {
  const NightComparison({required this.night, required this.thisYear, required this.lastYear});

  final int night;
  final TaraweehEntry? thisYear;
  final TaraweehEntry? lastYear;

  bool get thisDone => thisYear?.done ?? false;
  bool get lastDone => lastYear?.done ?? false;

  NightDifference get difference => switch ((thisDone, lastDone)) {
    (true, true) => NightDifference.both,
    (true, false) => NightDifference.onlyThisYear,
    (false, true) => NightDifference.onlyLastYear,
    (false, false) => NightDifference.neither,
  };
}

/// One year's totals.
@immutable
class RamadanTotals {
  const RamadanTotals({
    required this.nightsPrayed,
    required this.rakaat,
    required this.pagesRead,
    required this.fastingDays,
  });

  factory RamadanTotals.of(RamadanYearLog log) => RamadanTotals(
    nightsPrayed: log.taraweeh.nightsPrayed,
    rakaat: log.taraweeh.totalRakaat,
    pagesRead: log.pagesRead,
    fastingDays: log.fastingDays?.length,
  );

  final int nightsPrayed;
  final int rakaat;
  final int pagesRead;

  /// Null when fasting was not tracked.
  final int? fastingDays;
}

/// This year beside last year: per night, totals, and the differences
/// (positive = more this year; the fasting difference is null unless both
/// years tracked fasting).
@immutable
class RamadanComparison {
  const RamadanComparison._({required this.thisYear, required this.lastYear, required this.nights});

  /// Pure: the same two logs always give the same comparison. [nightCount] is
  /// how many nights to list (30; a 29-day month simply has an empty 30th).
  factory RamadanComparison.compare(
    RamadanYearLog thisYear,
    RamadanYearLog lastYear, {
    int nightCount = TaraweehLog.maxNights,
  }) {
    final count = nightCount.clamp(1, TaraweehLog.maxNights);
    return RamadanComparison._(
      thisYear: RamadanTotals.of(thisYear),
      lastYear: RamadanTotals.of(lastYear),
      nights: List.unmodifiable([
        for (var n = 1; n <= count; n++)
          NightComparison(night: n, thisYear: thisYear.taraweeh.entryOf(n), lastYear: lastYear.taraweeh.entryOf(n)),
      ]),
    );
  }

  final RamadanTotals thisYear;
  final RamadanTotals lastYear;
  final List<NightComparison> nights;

  int get nightsPrayedDelta => thisYear.nightsPrayed - lastYear.nightsPrayed;
  int get rakaatDelta => thisYear.rakaat - lastYear.rakaat;
  int get pagesReadDelta => thisYear.pagesRead - lastYear.pagesRead;
  int? get fastingDaysDelta => thisYear.fastingDays == null || lastYear.fastingDays == null
      ? null
      : thisYear.fastingDays! - lastYear.fastingDays!;
}
