/// The food log: one entry per thing eaten, plus the statistics the quick
/// entry box needs ("most used", "most recent").
///
/// Pure Dart. Nothing is classified by us: an entry carries the user's own
/// name, his own tags and his own portion.
library;

import 'package:meta/meta.dart';

import '../../body/domain/body_clock.dart';
import '../../search/domain/search_text.dart';
import 'food_library.dart';

/// One logged entry (a plain copy of a `food_logs` row).
@immutable
class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.name,
    required this.at,
    this.foodId,
    this.portion,
    this.unit,
    this.tags = const [],
    this.note,
    this.slotId,
  });

  final String id;

  /// The library food, or null for a free-text entry.
  final String? foodId;

  /// What was eaten, as the log should read it.
  final String name;
  final DateTime at;
  final double? portion;
  final String? unit;

  /// Extra tags for this entry only (the food's own tags are added by
  /// [tagsFor]).
  final List<String> tags;
  final String? note;

  /// The meal-plan slot the user tied this entry to, if any.
  final String? slotId;

  /// Minutes after local midnight of [at] – the "when in the day" a rule or
  /// an insight looks at.
  int get minuteOfDay => at.hour * 60 + at.minute;

  /// Identity for "the same thing eaten again": the food id, else the folded
  /// name.
  String get repeatKey => foodId ?? 'text:${SearchText.fold(name)}';

  @override
  String toString() => 'FoodEntry($id, $name @$at)';
}

/// How often one food (or one free text) was logged.
@immutable
class FoodUsage {
  const FoodUsage({required this.key, required this.name, required this.foodId, required this.count, required this.lastAt});

  /// [FoodEntry.repeatKey].
  final String key;
  final String name;
  final String? foodId;
  final int count;
  final DateTime lastAt;

  @override
  String toString() => 'FoodUsage($name ×$count, last $lastAt)';
}

/// Statistics over the log. All pure; the window is always the caller's.
abstract final class FoodLogStats {
  /// Default window for "most used" (days back from today).
  static const int frequentWindowDays = 30;

  /// The entries of local calendar [day], earliest first.
  static List<FoodEntry> onDay(
    Iterable<FoodEntry> entries,
    DateTime day, {
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    final out = [
      for (final e in entries)
        if (BodyDays.same(clock.dayOf(e.at), day)) e,
    ]..sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  /// The entries between [from] and [to] (both local calendar days,
  /// inclusive), earliest first.
  static List<FoodEntry> between(
    Iterable<FoodEntry> entries,
    DateTime from,
    DateTime to, {
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    final out = [
      for (final e in entries)
        if (!clock.dayOf(e.at).isBefore(BodyDays.of(from)) && !clock.dayOf(e.at).isAfter(BodyDays.of(to))) e,
    ]..sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  /// "Repeat a frequent meal": the most logged entries of the last
  /// [windowDays] days before [today], most logged first (ties: the most
  /// recent). Free-text entries that fold to the same words count as one.
  static List<FoodUsage> mostUsed(
    Iterable<FoodEntry> entries, {
    required DateTime today,
    int windowDays = frequentWindowDays,
    int limit = 10,
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    final from = BodyDays.add(BodyDays.of(today), -(windowDays - 1));
    final counts = <String, ({String name, String? foodId, int count, DateTime lastAt})>{};
    for (final e in between(entries, from, today, clock: clock)) {
      final k = e.repeatKey;
      final prev = counts[k];
      counts[k] = (
        name: e.at.isBefore(prev?.lastAt ?? e.at) ? prev!.name : e.name,
        foodId: e.foodId ?? prev?.foodId,
        count: (prev?.count ?? 0) + 1,
        lastAt: prev == null || e.at.isAfter(prev.lastAt) ? e.at : prev.lastAt,
      );
    }
    final out = [
      for (final MapEntry(:key, :value) in counts.entries)
        FoodUsage(key: key, name: value.name, foodId: value.foodId, count: value.count, lastAt: value.lastAt),
    ]..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : b.lastAt.compareTo(a.lastAt);
    });
    return out.length <= limit ? out : out.sublist(0, limit);
  }

  /// "Log it again": the distinct things eaten most recently, newest first.
  static List<FoodUsage> mostRecent(Iterable<FoodEntry> entries, {int limit = 10}) {
    final sorted = entries.toList()..sort((a, b) => b.at.compareTo(a.at));
    final seen = <String>{};
    final out = <FoodUsage>[];
    for (final e in sorted) {
      if (!seen.add(e.repeatKey)) continue;
      out.add(FoodUsage(key: e.repeatKey, name: e.name, foodId: e.foodId, count: 1, lastAt: e.at));
      if (out.length >= limit) break;
    }
    return out;
  }

  /// How often each library food was logged (ties are broken with it in
  /// [FoodLookup.search]).
  static Map<String, int> useCountById(Iterable<FoodEntry> entries) {
    final out = <String, int>{};
    for (final e in entries) {
      final id = e.foodId;
      if (id != null) out[id] = (out[id] ?? 0) + 1;
    }
    return out;
  }

  /// How many entries each local day holds (`BodyDays.key` → count).
  static Map<String, int> countByDay(Iterable<FoodEntry> entries, {BodyWallClock clock = const LocalBodyWallClock()}) {
    final out = <String, int>{};
    for (final e in entries) {
      final k = BodyDays.key(clock.dayOf(e.at));
      out[k] = (out[k] ?? 0) + 1;
    }
    return out;
  }

  /// Days with at least one entry in the last [windowDays] days before
  /// [today] (inclusive) – the number the insights need before they say
  /// anything.
  static int daysLogged(
    Iterable<FoodEntry> entries, {
    required DateTime today,
    int windowDays = 90,
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    final from = BodyDays.add(BodyDays.of(today), -(windowDays - 1));
    final days = <String>{};
    for (final e in between(entries, from, today, clock: clock)) {
      days.add(BodyDays.key(clock.dayOf(e.at)));
    }
    return days.length;
  }

  /// Days in a row up to [today] with at least one entry (0 when today has
  /// none).
  static int streak(
    Iterable<FoodEntry> entries, {
    required DateTime today,
    BodyWallClock clock = const LocalBodyWallClock(),
  }) {
    final days = <String>{};
    for (final e in entries) {
      days.add(BodyDays.key(clock.dayOf(e.at)));
    }
    var n = 0;
    var day = BodyDays.of(today);
    while (days.contains(BodyDays.key(day))) {
      n++;
      day = BodyDays.add(day, -1);
    }
    return n;
  }

  /// Every tag that applies to [entry]: the food's tags plus the entry's own
  /// (folded-deduplicated, the food's spelling first).
  static List<String> tagsFor(FoodEntry entry, {Food? food}) {
    final out = <String>[];
    final seen = <String>{};
    for (final tag in [...?food?.tags, ...entry.tags]) {
      final key = SearchText.fold(tag);
      if (key.isEmpty || !seen.add(key)) continue;
      out.add(tag.trim());
    }
    return out;
  }
}
