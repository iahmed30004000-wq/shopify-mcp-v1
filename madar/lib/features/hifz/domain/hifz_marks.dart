/// «الحفظ» · the stretches he marked himself (Part 14).
///
/// Pure Dart. Two marks, and both of them are his decision, never the
/// engine's:
///
/// * **«مش عليّ»** ([HifzMarkKind.skipReview]) – this stretch is not his to
///   review. It is left out of the review tracks and out of the page map's
///   numbers, and no strength is ever claimed for it.
/// * **«صفّر القوة»** ([HifzMarkKind.resetStrength]) – start again from a
///   day. Every result **before** that day is ignored when the strength is
///   computed; nothing is deleted from the log, so the history stays
///   readable and the export still carries it.
library;

import 'package:meta/meta.dart';

import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import '../../wird/domain/calendar_days.dart';

/// One mark on one stretch of the mushaf.
@immutable
final class HifzMark {
  const HifzMark({
    required this.id,
    required this.kind,
    required this.range,
    required this.createdAt,
    this.since,
    this.note,
  });

  final String id;
  final HifzMarkKind kind;
  final AyahRange range;
  final DateTime createdAt;

  /// For [HifzMarkKind.resetStrength]: the day it starts again from.
  /// Falling back to the day the mark was made, so a reset never silently
  /// means "no reset".
  final DateTime? since;
  final String? note;

  /// The day this mark takes effect from (what a screen and the export
  /// show).
  DateTime get day => since ?? CalendarDays.dateOnly(createdAt);

  /// The exact moment it takes effect from.
  ///
  /// «صفّر القوة» pressed now means *now*: a recitation from earlier the
  /// same morning is behind the line, and one he does straight afterwards
  /// is in front of it. When he picked an earlier day himself, the line is
  /// that day's start.
  DateTime get effectiveFrom {
    final chosen = since;
    if (chosen == null) return createdAt;
    return CalendarDays.same(chosen, createdAt) ? createdAt : DateTime(chosen.year, chosen.month, chosen.day);
  }

  bool covers(AyahRef ref) => range.contains(ref);

  @override
  String toString() => 'HifzMark(${kind.name} $range${kind == HifzMarkKind.resetStrength ? ' since ${CalendarDays.key(day)}' : ''})';
}

/// His marks, ready to ask questions of.
@immutable
final class HifzMarks {
  const HifzMarks._(this.marks);

  static const HifzMarks empty = HifzMarks._([]);

  factory HifzMarks.of(Iterable<HifzMark> marks) =>
      HifzMarks._(List.unmodifiable(marks.toList()..sort((a, b) => a.range.first.compareTo(b.range.first))));

  final List<HifzMark> marks;

  bool get isEmpty => marks.isEmpty;

  /// Whether he said this ayah is not his to review.
  bool skipped(AyahRef ref) {
    for (final m in marks) {
      if (m.kind == HifzMarkKind.skipReview && m.covers(ref)) return true;
    }
    return false;
  }

  /// The day this ayah's strength starts again from (the latest reset
  /// covering it), or null when he never reset it.
  DateTime? resetDay(AyahRef ref) {
    final at = resetAt(ref);
    return at == null ? null : CalendarDays.dateOnly(at);
  }

  /// The exact moment this ayah's strength starts again from.
  DateTime? resetAt(AyahRef ref) {
    DateTime? best;
    for (final m in marks) {
      if (m.kind != HifzMarkKind.resetStrength || !m.covers(ref)) continue;
      final at = m.effectiveFrom;
      if (best == null || at.isAfter(best)) best = at;
    }
    return best;
  }

  /// Every stretch he said is not his to review.
  List<AyahRange> get skippedRanges => [
    for (final m in marks)
      if (m.kind == HifzMarkKind.skipReview) m.range,
  ];

  /// Whether a result recited at [at] still counts for [ref] – false for
  /// everything behind a reset he made.
  bool counts(AyahRef ref, DateTime at) {
    final reset = resetAt(ref);
    return reset == null || at.isAfter(reset);
  }

  @override
  String toString() => 'HifzMarks(${marks.length})';
}
