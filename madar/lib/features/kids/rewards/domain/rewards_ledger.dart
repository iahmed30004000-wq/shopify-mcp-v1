import 'package:flutter/foundation.dart';

/// One star the child earned: why, on which local day, and when.
@immutable
class StarEntry {
  const StarEntry({required this.reason, required this.day, required this.atMs});

  /// A stable id of what was done ('game.pairs', 'story.little_star' ...).
  final String reason;

  /// Local calendar day, `yyyy-mm-dd`.
  final String day;

  /// Milliseconds since epoch, for the record only.
  final int atMs;

  String get key => '$reason|$day';

  List<Object> toJson() => [reason, day, atMs];

  static StarEntry? fromJson(Object? json) {
    if (json is! List || json.length < 2) return null;
    final reason = json[0], day = json[1];
    if (reason is! String || day is! String || reason.isEmpty) return null;
    final at = json.length > 2 && json[2] is num ? (json[2] as num).toInt() : 0;
    return StarEntry(reason: reason, day: day, atMs: at);
  }
}

/// Everything the child has collected. Stars are only a collection: this type
/// has no way to remove or lower anything, and nothing ever reads it to lock
/// content.
@immutable
class RewardsLedger {
  const RewardsLedger(this.entries);

  static const RewardsLedger empty = RewardsLedger(<StarEntry>[]);

  final List<StarEntry> entries;

  int get count => entries.length;

  static const int maxReasonLength = 64;

  /// `yyyy-mm-dd` of the local day of [t].
  static String dayKey(DateTime t) {
    final l = t.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  static String normaliseReason(String reason) {
    final r = reason.trim();
    if (r.isEmpty) return 'star';
    return r.length > maxReasonLength ? r.substring(0, maxReasonLength) : r;
  }

  bool has(String reason, String day) {
    final key = '${normaliseReason(reason)}|$day';
    return entries.any((e) => e.key == key);
  }

  /// This ledger plus one star for [reason] at [now], or null when the same
  /// reason already earned a star today (one tap cannot be farmed).
  RewardsLedger? award(String reason, DateTime now) {
    final r = normaliseReason(reason);
    final day = dayKey(now);
    if (has(r, day)) return null;
    return RewardsLedger([...entries, StarEntry(reason: r, day: day, atMs: now.millisecondsSinceEpoch)]);
  }

  /// Both ledgers' stars, each (reason, day) once: used to recover a write
  /// that was interrupted half way. The result never has fewer stars than
  /// either side.
  RewardsLedger union(RewardsLedger other) {
    final seen = {for (final e in entries) e.key};
    final extra = [
      for (final e in other.entries)
        if (seen.add(e.key)) e,
    ];
    return extra.isEmpty ? this : RewardsLedger([...entries, ...extra]);
  }

  List<Object> toJson() => [for (final e in entries) e.toJson()];

  /// Tolerant: anything that is not a well-formed entry is skipped, a broken
  /// document is an empty ledger (a child's stars are never a crash).
  static RewardsLedger fromJson(Object? json) {
    if (json is! List) return empty;
    final seen = <String>{};
    final out = <StarEntry>[];
    for (final j in json) {
      final e = StarEntry.fromJson(j);
      if (e != null && seen.add(e.key)) out.add(e);
    }
    return RewardsLedger(out);
  }
}
