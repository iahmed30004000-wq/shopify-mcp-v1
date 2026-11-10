import 'dart:math' as math;

import '../../../core/domain/enums.dart';
import 'rhythm.dart';

/// One logged contact, as the statistics see it.
typedef ContactPoint = ({DateTime at, ContactChannel channel});

/// A person's contact statistics (average interval vs rhythm …).
class ContactStats {
  const ContactStats({
    required this.total,
    required this.recent,
    required this.intervals,
    required this.byChannel,
    this.averageInterval,
    this.longestGap,
    this.onRhythmShare,
    this.first,
    this.last,
  });

  static const ContactStats empty = ContactStats(total: 0, recent: 0, intervals: [], byChannel: {});

  /// Contacts logged (up to now).
  final int total;

  /// Contacts in the last [ContactStatsMath.recentDays] days.
  final int recent;

  /// Gaps in days between consecutive contact days, oldest first.
  final List<int> intervals;

  /// Mean of [intervals] (null with fewer than two contact days).
  final double? averageInterval;

  /// The largest of [intervals].
  final int? longestGap;

  /// Share of [intervals] within the rhythm (null without a rhythm or
  /// intervals).
  final double? onRhythmShare;

  final Map<ContactChannel, int> byChannel;
  final DateTime? first;
  final DateTime? last;

  bool get hasIntervals => intervals.isNotEmpty;

  /// The channel used most (ties: the most recent kind order), or null.
  ContactChannel? get favouriteChannel {
    ContactChannel? best;
    var n = 0;
    for (final e in byChannel.entries) {
      if (e.value > n) {
        best = e.key;
        n = e.value;
      }
    }
    return best;
  }
}

/// Builds [ContactStats] (pure).
abstract final class ContactStatsMath {
  static const int recentDays = 90;

  /// The chart shows at most this many recent intervals.
  static const int chartIntervals = 12;

  /// Statistics of [contacts] at [now] (future contacts ignored). Several
  /// contacts on one day count once for the intervals.
  static ContactStats of(Iterable<ContactPoint> contacts, {int? rhythmDays, required DateTime now}) {
    final past = contacts.where((c) => !c.at.isAfter(now)).toList()..sort((a, b) => a.at.compareTo(b.at));
    if (past.isEmpty) return ContactStats.empty;
    final byChannel = <ContactChannel, int>{};
    for (final c in past) {
      byChannel[c.channel] = (byChannel[c.channel] ?? 0) + 1;
    }
    final recentFrom = CalendarDays.add(now, -recentDays);
    final recent = past.where((c) => !c.at.isBefore(recentFrom)).length;
    final days = <DateTime>[];
    for (final c in past) {
      final d = CalendarDays.dayOf(c.at);
      if (days.isEmpty || !days.last.isAtSameMomentAs(d)) days.add(d);
    }
    final intervals = [for (var i = 1; i < days.length; i++) CalendarDays.between(days[i - 1], days[i])];
    final rhythm = RhythmEngine.normalizeRhythm(rhythmDays);
    return ContactStats(
      total: past.length,
      recent: recent,
      intervals: intervals,
      byChannel: byChannel,
      averageInterval: intervals.isEmpty ? null : intervals.reduce((a, b) => a + b) / intervals.length,
      longestGap: intervals.isEmpty ? null : intervals.reduce(math.max),
      onRhythmShare: rhythm == null || intervals.isEmpty
          ? null
          : intervals.where((g) => g <= rhythm).length / intervals.length,
      first: past.first.at,
      last: past.last.at,
    );
  }

  /// The last [chartIntervals] intervals, oldest first.
  static List<int> chart(ContactStats stats) {
    final all = stats.intervals;
    return all.length <= chartIntervals ? all : all.sublist(all.length - chartIntervals);
  }
}
