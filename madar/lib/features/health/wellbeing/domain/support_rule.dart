import 'package:flutter/foundation.dart';

/// When the gentle support banner appears.
///
/// **Rule:** look at the last [window] (5) check-ins that have a mood, taken
/// within the last [maxAge] (14 days). When at least [threshold] (3) of them
/// have a mood of [lowMood] (2) or less on the 1–5 scale, the banner shows –
/// unless the user dismissed it and [SupportState.dismissedUntil] (a week
/// after the dismissal, [snooze]) is still ahead. The banner never names a
/// condition and never interprets: it only offers the emergency number.
abstract final class SupportRule {
  static const int window = 5;
  static const int threshold = 3;
  static const int lowMood = 2;
  static const Duration maxAge = Duration(days: 14);
  static const Duration snooze = Duration(days: 7);

  /// [checkIns] as (time, mood) in any order; moods outside 1–5 and nulls
  /// are ignored.
  static SupportState evaluate(Iterable<(DateTime, int?)> checkIns, {required DateTime now, DateTime? dismissedUntil}) {
    final since = now.subtract(maxAge);
    final recent = [
      for (final (at, mood) in checkIns)
        if (mood != null && mood >= 1 && mood <= 5 && !at.isBefore(since) && !at.isAfter(now)) (at, mood),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    final considered = recent.take(window).toList();
    final low = considered.where((c) => c.$2 <= lowMood).length;
    final triggered = low >= threshold;
    final snoozed = dismissedUntil != null && dismissedUntil.isAfter(now);
    return SupportState(triggered: triggered, snoozed: snoozed, lowCount: low, considered: considered.length);
  }

  /// When a dismissal made at [now] expires.
  static DateTime dismissUntil(DateTime now) => now.add(snooze);
}

@immutable
class SupportState {
  const SupportState({
    required this.triggered,
    required this.snoozed,
    required this.lowCount,
    required this.considered,
  });

  static const none = SupportState(triggered: false, snoozed: false, lowCount: 0, considered: 0);

  /// The rule matched.
  final bool triggered;

  /// The user asked not to see it for a while.
  final bool snoozed;

  /// Low-mood check-ins among [considered].
  final int lowCount;

  /// Check-ins looked at (at most [SupportRule.window]).
  final int considered;

  bool get show => triggered && !snoozed;

  @override
  bool operator ==(Object other) =>
      other is SupportState &&
      other.triggered == triggered &&
      other.snoozed == snoozed &&
      other.lowCount == lowCount &&
      other.considered == considered;

  @override
  int get hashCode => Object.hash(triggered, snoozed, lowCount, considered);

  @override
  String toString() => 'SupportState(show: $show, low: $lowCount/$considered, snoozed: $snoozed)';
}
