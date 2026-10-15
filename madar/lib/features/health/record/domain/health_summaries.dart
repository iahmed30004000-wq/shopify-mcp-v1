import '../../../../core/db/database.dart';

/// Neutral statistics of the user's own pain / mood entries for the doctor
/// report – counts, averages and most frequent tags. No interpretation.
class PainSummary {
  const PainSummary({
    required this.entries,
    required this.days,
    required this.average,
    required this.highest,
    required this.topLocations,
    required this.topTriggers,
  });

  final int entries;

  /// Distinct days with an entry.
  final int days;
  final double average;
  final int highest;
  final List<({String label, int count})> topLocations;
  final List<({String label, int count})> topTriggers;

  /// Null without entries.
  static PainSummary? of(Iterable<PainEntryRow> rows, {Map<String, String> labels = const {}, int top = 3}) {
    final list = rows.toList();
    if (list.isEmpty) return null;
    final scores = [for (final p in list) p.score.clamp(0, 10)];
    return PainSummary(
      entries: list.length,
      days: {for (final p in list) DateTime(p.at.year, p.at.month, p.at.day)}.length,
      average: scores.fold<int>(0, (a, b) => a + b) / scores.length,
      highest: scores.reduce((a, b) => a > b ? a : b),
      topLocations: TagCounts.top([for (final p in list) ...p.locations], labels: labels, top: top),
      topTriggers: TagCounts.top([for (final p in list) ...p.triggers], labels: labels, top: top),
    );
  }
}

class MoodSummary {
  const MoodSummary({
    required this.entries,
    this.mood,
    this.stress,
    this.anxiety,
    this.energy,
    this.sleepHours,
    this.caffeineCups,
    this.topFactors = const [],
  });

  final int entries;

  /// Averages over the entries that recorded each value (null = none did).
  final double? mood;
  final double? stress;
  final double? anxiety;
  final double? energy;
  final double? sleepHours;
  final double? caffeineCups;
  final List<({String label, int count})> topFactors;

  static MoodSummary? of(Iterable<MoodEntryRow> rows, {Map<String, String> labels = const {}, int top = 3}) {
    final list = rows.toList();
    if (list.isEmpty) return null;
    double? avg(Iterable<num?> values) {
      final v = values.whereType<num>().toList();
      return v.isEmpty ? null : v.fold<double>(0, (a, b) => a + b) / v.length;
    }

    return MoodSummary(
      entries: list.length,
      mood: avg(list.map((m) => m.mood)),
      stress: avg(list.map((m) => m.stress)),
      anxiety: avg(list.map((m) => m.anxiety)),
      energy: avg(list.map((m) => m.energy)),
      sleepHours: avg(list.map((m) => m.sleepHours)),
      caffeineCups: avg(list.map((m) => m.caffeineCups)),
      topFactors: TagCounts.top([for (final m in list) ...m.factors], labels: labels, top: top),
    );
  }
}

abstract final class TagCounts {
  /// Most frequent tags (ties: alphabetical), tag ids resolved to labels.
  static List<({String label, int count})> top(
    Iterable<String> tags, {
    Map<String, String> labels = const {},
    int top = 3,
  }) {
    final counts = <String, int>{};
    for (final raw in tags) {
      final t = (labels[raw] ?? raw).trim();
      if (t.isEmpty) continue;
      counts[t] = (counts[t] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return [for (final e in sorted.take(top)) (label: e.key, count: e.value)];
  }
}
