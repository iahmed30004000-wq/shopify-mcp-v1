/// One sitting with a book, and the per-day totals the daily goal reads.
library;

import 'package:meta/meta.dart';

import '../../wird/domain/calendar_days.dart';

@immutable
final class ReadingSession {
  ReadingSession({
    required this.id,
    required this.bookId,
    required this.startedAt,
    required this.endedAt,
    required this.pagesRead,
    required this.activeSeconds,
  }) : assert(!endedAt.isBefore(startedAt)),
       assert(pagesRead >= 0 && activeSeconds >= 0);

  final String id;
  final String bookId;
  final DateTime startedAt;
  final DateTime endedAt;

  /// New pages he turned to (counted by the reader, not by page-turn taps).
  final int pagesRead;

  /// Seconds the book was actually open and awake (idle time excluded), so a
  /// phone left on a table does not count as reading.
  final int activeSeconds;

  Map<String, Object?> toJson() => {
    'id': id,
    'bookId': bookId,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'pagesRead': pagesRead,
    'activeSeconds': activeSeconds,
  };

  factory ReadingSession.fromJson(Map<String, Object?> json) => ReadingSession(
    id: json['id'] as String,
    bookId: json['bookId'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String),
    endedAt: DateTime.parse(json['endedAt'] as String),
    pagesRead: (json['pagesRead'] as num).toInt(),
    activeSeconds: (json['activeSeconds'] as num).toInt(),
  );
}

@immutable
final class DailyTotals {
  const DailyTotals({this.pages = 0, this.seconds = 0});

  static const DailyTotals zero = DailyTotals();

  final int pages;
  final int seconds;

  int get minutes => seconds ~/ 60;

  DailyTotals operator +(DailyTotals o) => DailyTotals(pages: pages + o.pages, seconds: seconds + o.seconds);

  @override
  bool operator ==(Object other) => other is DailyTotals && other.pages == pages && other.seconds == seconds;

  @override
  int get hashCode => Object.hash(pages, seconds);

  @override
  String toString() => 'DailyTotals(pages: $pages, seconds: $seconds)';
}

abstract final class ReadingAggregator {
  /// Totals per local calendar day, keyed `yyyy-mm-dd` ([CalendarDays.key]).
  ///
  /// A session that runs past midnight is split: its active seconds go to
  /// each day in proportion to the wall-clock time spent in it (the rounding
  /// remainder to the last day), and its pages go to the day it ended on,
  /// because that is when the last of them was turned to.
  static Map<String, DailyTotals> byDay(Iterable<ReadingSession> sessions, {String? bookId}) {
    final out = <String, DailyTotals>{};
    void add(DateTime day, DailyTotals t) {
      final k = CalendarDays.key(day);
      out[k] = (out[k] ?? DailyTotals.zero) + t;
    }

    for (final s in sessions) {
      if (bookId != null && s.bookId != bookId) continue;
      final first = CalendarDays.dateOnly(s.startedAt);
      final last = CalendarDays.dateOnly(s.endedAt);
      final wall = s.endedAt.difference(s.startedAt).inMicroseconds;
      if (first == last || wall == 0) {
        add(last, DailyTotals(pages: s.pagesRead, seconds: s.activeSeconds));
        continue;
      }
      var assigned = 0;
      for (var day = first; !day.isAfter(last); day = CalendarDays.add(day, 1)) {
        final from = day.isAfter(s.startedAt) ? day : s.startedAt;
        final nextMidnight = CalendarDays.add(day, 1);
        final to = nextMidnight.isBefore(s.endedAt) ? nextMidnight : s.endedAt;
        final isLast = day == last;
        final secs = isLast ? s.activeSeconds - assigned : s.activeSeconds * to.difference(from).inMicroseconds ~/ wall;
        assigned += secs;
        add(day, DailyTotals(pages: isLast ? s.pagesRead : 0, seconds: secs));
      }
    }
    return out;
  }

  /// All-time totals of one book.
  static DailyTotals forBook(Iterable<ReadingSession> sessions, String bookId) =>
      byDay(sessions, bookId: bookId).values.fold(DailyTotals.zero, (a, b) => a + b);
}
