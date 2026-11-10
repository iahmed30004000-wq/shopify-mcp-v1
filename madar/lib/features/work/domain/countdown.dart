import 'package:flutter/foundation.dart';

import 'work_days.dart';

enum CountdownKind { none, overdue, today, tomorrow, days }

/// Days left until a deadline or due date ("١٢ يوماً", "tomorrow",
/// "3 days overdue"). Pure calendar-day maths.
@immutable
class Countdown {
  const Countdown._(this.kind, this.days);

  static const Countdown none = Countdown._(CountdownKind.none, 0);

  /// [deadline] seen from [today] (both calendar days; times are ignored).
  factory Countdown.of(DateTime? deadline, DateTime today) {
    if (deadline == null) return none;
    final n = WorkDays.between(today, deadline);
    if (n < 0) return Countdown._(CountdownKind.overdue, -n);
    if (n == 0) return const Countdown._(CountdownKind.today, 0);
    if (n == 1) return const Countdown._(CountdownKind.tomorrow, 1);
    return Countdown._(CountdownKind.days, n);
  }

  final CountdownKind kind;

  /// Days left ([CountdownKind.days], [CountdownKind.tomorrow]) or days
  /// late ([CountdownKind.overdue]).
  final int days;

  bool get isOverdue => kind == CountdownKind.overdue;

  /// Due within [within] days (today included), not overdue.
  bool isSoon({int within = 7}) =>
      kind == CountdownKind.today || kind == CountdownKind.tomorrow || (kind == CountdownKind.days && days <= within);

  /// Share of the time from [start] to the deadline already gone (0..1;
  /// 1 once due). Null without a deadline or when it precedes [start].
  static double? elapsed(DateTime start, DateTime? deadline, DateTime today) {
    if (deadline == null) return null;
    final total = WorkDays.between(start, deadline);
    if (total <= 0) return WorkDays.between(today, deadline) <= 0 ? 1 : null;
    return (WorkDays.between(start, today) / total).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) => other is Countdown && other.kind == kind && other.days == days;

  @override
  int get hashCode => Object.hash(kind, days);

  @override
  String toString() => 'Countdown($kind, $days)';
}

/// How a card's or checklist item's due date reads today.
enum DueStatus { none, overdue, today, tomorrow, soon, later }

abstract final class DueRules {
  /// [due] against [today]; a finished item is never overdue ([done]).
  static DueStatus of(DateTime? due, DateTime today, {bool done = false}) {
    if (due == null || done) return DueStatus.none;
    final c = Countdown.of(due, today);
    return switch (c.kind) {
      CountdownKind.overdue => DueStatus.overdue,
      CountdownKind.today => DueStatus.today,
      CountdownKind.tomorrow => DueStatus.tomorrow,
      CountdownKind.days => c.days <= 7 ? DueStatus.soon : DueStatus.later,
      CountdownKind.none => DueStatus.none,
    };
  }
}
