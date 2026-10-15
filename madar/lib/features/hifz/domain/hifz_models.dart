import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import '../../wird/domain/calendar_days.dart';
import 'sm2.dart';

/// A Hifz item as the screens and the scheduler see it (`hifz_items`).
@immutable
class HifzCard {
  const HifzCard({
    required this.id,
    required this.kind,
    this.title,
    this.surah,
    this.ayahFrom,
    this.ayahTo,
    this.body,
    this.source,
    this.sm2 = Sm2State.initial,
    this.due,
    this.lastReviewedAt,
    this.suspended = false,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory HifzCard.fromRow(HifzItemRow r) => HifzCard(
    id: r.id,
    kind: r.kind,
    title: r.title,
    surah: r.surah,
    ayahFrom: r.ayahFrom,
    ayahTo: r.ayahTo,
    body: r.body,
    source: r.source,
    sm2: Sm2State(easeFactor: r.easeFactor, intervalDays: r.intervalDays, repetitions: r.repetitions, lapses: r.lapses),
    due: r.due,
    lastReviewedAt: r.lastReviewedAt,
    suspended: r.suspended,
    sortOrder: r.sortOrder,
    createdAt: r.createdAt,
  );

  final String id;
  final HifzKind kind;
  final String? title;
  final int? surah;
  final int? ayahFrom;
  final int? ayahTo;
  final String? body;

  /// Where a hadith comes from (`nawawi40:12`), or a custom item's source.
  final String? source;
  final Sm2State sm2;

  /// Next review day (null = new).
  final DateTime? due;
  final DateTime? lastReviewedAt;
  final bool suspended;
  final int sortOrder;
  final DateTime createdAt;

  /// Never studied.
  bool get isNew => due == null;

  /// The ayat of an [HifzKind.ayat] item.
  AyahRange? get range {
    final s = surah, a = ayahFrom;
    if (kind != HifzKind.ayat || s == null || a == null || s < 1 || s > 114 || a < 1) return null;
    final b = math.max(a, ayahTo ?? a);
    return AyahRange(AyahRef(s, a), AyahRef(s, b));
  }

  int get ayahCount => range == null ? 0 : ayahTo! - ayahFrom! + 1;

  bool isDue(DateTime today) => !isNew && !suspended && CalendarDays.between(due!, today) >= 0;

  /// Days past due (0 when due today or later).
  int overdueDays(DateTime today) => isNew ? 0 : math.max(0, CalendarDays.between(due!, today));

  /// Days until due (negative when overdue; null when new).
  int? dueInDays(DateTime today) => isNew ? null : CalendarDays.between(today, due!);

  HifzCard withSm2(Sm2State s, {required DateTime due, required DateTime reviewedAt}) => HifzCard(
    id: id,
    kind: kind,
    title: title,
    surah: surah,
    ayahFrom: ayahFrom,
    ayahTo: ayahTo,
    body: body,
    source: source,
    sm2: s,
    due: due,
    lastReviewedAt: reviewedAt,
    suspended: suspended,
    sortOrder: sortOrder,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is HifzCard &&
      other.id == id &&
      other.kind == kind &&
      other.title == title &&
      other.surah == surah &&
      other.ayahFrom == ayahFrom &&
      other.ayahTo == ayahTo &&
      other.body == body &&
      other.source == source &&
      other.sm2 == sm2 &&
      other.due == due &&
      other.lastReviewedAt == lastReviewedAt &&
      other.suspended == suspended &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    title,
    surah,
    ayahFrom,
    ayahTo,
    body,
    source,
    sm2,
    due,
    lastReviewedAt,
    suspended,
    sortOrder,
  );
}

/// One logged review (`hifz_reviews`).
@immutable
class HifzReviewLog {
  const HifzReviewLog({
    required this.itemId,
    required this.at,
    required this.grade,
    required this.intervalBefore,
    required this.intervalAfter,
    this.easeAfter = Sm2.initialEase,
  });

  factory HifzReviewLog.fromRow(HifzReviewRow r) => HifzReviewLog(
    itemId: r.itemId,
    at: r.at,
    grade: r.grade,
    intervalBefore: r.intervalBefore,
    intervalAfter: r.intervalAfter,
    easeAfter: r.easeAfter,
  );

  final String itemId;
  final DateTime at;
  final int grade;
  final int intervalBefore;
  final int intervalAfter;
  final double easeAfter;

  DateTime get day => CalendarDays.dateOnly(at);

  /// A review of something already studied (not its first learning).
  bool get isRecall => intervalBefore > 0;
}

/// Today's review order (pure).
abstract final class HifzQueue {
  /// Items introduced (first reviewed) on [today].
  static int newStartedToday(Iterable<HifzReviewLog> reviews, DateTime today) {
    final first = <String, DateTime>{};
    for (final r in reviews) {
      final f = first[r.itemId];
      if (f == null || r.at.isBefore(f)) first[r.itemId] = r.at;
    }
    return first.values.where((t) => CalendarDays.same(t, today)).length;
  }

  /// Due items first (most overdue, then hardest), then new items in their
  /// order up to what is left of [newPerDay] today.
  static List<HifzCard> build({
    required Iterable<HifzCard> cards,
    required Iterable<HifzReviewLog> reviews,
    required DateTime today,
    required int newPerDay,
  }) {
    final due = cards.where((c) => c.isDue(today)).toList()
      ..sort((a, b) {
        final d = a.due!.compareTo(b.due!);
        if (d != 0) return d;
        final e = a.sm2.easeFactor.compareTo(b.sm2.easeFactor);
        return e != 0 ? e : a.sortOrder.compareTo(b.sortOrder);
      });
    final left = math.max(0, newPerDay - newStartedToday(reviews, today));
    final fresh = cards.where((c) => c.isNew && !c.suspended).toList()
      ..sort((a, b) {
        final o = a.sortOrder.compareTo(b.sortOrder);
        return o != 0 ? o : a.createdAt.compareTo(b.createdAt);
      });
    return [...due, ...fresh.take(left)];
  }
}

/// Numbers for the Hifz screen and card (pure).
@immutable
class HifzStats {
  const HifzStats({
    this.dueToday = 0,
    this.newWaiting = 0,
    this.newLeftToday = 0,
    this.learned = 0,
    this.mature = 0,
    this.suspended = 0,
    this.total = 0,
    this.retention,
    this.streak = 0,
    this.reviewedToday = 0,
    this.forecast = const [0, 0, 0, 0, 0, 0, 0],
  });

  /// Studied items due today or overdue.
  final int dueToday;

  /// New items not yet studied.
  final int newWaiting;

  /// New items today's session will introduce.
  final int newLeftToday;

  /// Studied items (suspended ones included: they stay memorised).
  final int learned;

  /// Studied items with an interval of three weeks or more.
  final int mature;
  final int suspended;
  final int total;

  /// Share of recall reviews graded ≥ 3 over [retentionDays] (null when
  /// there were none).
  final double? retention;

  /// Days in a row with at least one review (ending today, or yesterday
  /// when nothing has been reviewed yet today).
  final int streak;
  final int reviewedToday;

  /// Reviews due on each of the next seven days (today includes overdue).
  final List<int> forecast;

  /// What today's session holds.
  int get sessionSize => dueToday + newLeftToday;

  static const int retentionDays = 30;
  static const int matureDays = 21;

  static HifzStats compute({
    required List<HifzCard> cards,
    required List<HifzReviewLog> reviews,
    required DateTime today,
    required int newPerDay,
  }) {
    today = CalendarDays.dateOnly(today);
    final active = cards.where((c) => !c.suspended).toList();
    final studied = active.where((c) => !c.isNew).toList();
    final forecast = List<int>.filled(7, 0);
    for (final c in studied) {
      final d = CalendarDays.between(today, c.due!);
      if (d <= 0) {
        forecast[0]++;
      } else if (d < 7) {
        forecast[d]++;
      }
    }
    final since = CalendarDays.add(today, -(retentionDays - 1));
    final recalls = reviews.where((r) => r.isRecall && CalendarDays.between(since, r.day) >= 0).toList();
    final passed = recalls.where((r) => r.grade >= Sm2.passGrade).length;
    final days = {for (final r in reviews) CalendarDays.key(r.day)};
    var streak = 0;
    var day = days.contains(CalendarDays.key(today)) ? today : CalendarDays.add(today, -1);
    while (days.contains(CalendarDays.key(day))) {
      streak++;
      day = CalendarDays.add(day, -1);
    }
    final newWaiting = active.where((c) => c.isNew).length;
    return HifzStats(
      dueToday: forecast[0],
      newWaiting: newWaiting,
      newLeftToday: math.min(newWaiting, math.max(0, newPerDay - HifzQueue.newStartedToday(reviews, today))),
      learned: cards.where((c) => !c.isNew).length,
      mature: studied.where((c) => c.sm2.intervalDays >= matureDays).length,
      suspended: cards.length - active.length,
      total: cards.length,
      retention: recalls.isEmpty ? null : passed / recalls.length,
      streak: streak,
      reviewedToday: reviews.where((r) => CalendarDays.same(r.day, today)).length,
      forecast: List.unmodifiable(forecast),
    );
  }
}

/// Splits ayah ranges into short memorisation chunks (pure).
abstract final class HifzChunker {
  /// `[from, to]` in chunks of at most [size] ayat, as even as possible
  /// (13 ayat by 5 → 5, 4, 4 rather than 5, 5, 3).
  static List<(int, int)> split(int from, int to, int size) {
    if (to < from) (from, to) = (to, from);
    final len = to - from + 1;
    final n = (len / math.max(1, size)).ceil();
    final base = len ~/ n, extra = len % n;
    final out = <(int, int)>[];
    var a = from;
    for (var i = 0; i < n; i++) {
      final l = base + (i < extra ? 1 : 0);
      out.add((a, a + l - 1));
      a += l;
    }
    return out;
  }

  /// [range] (possibly across surahs) split per surah, then into chunks.
  static List<AyahRange> chunks(AyahRange range, int Function(int surah) ayahCount, int size) {
    final out = <AyahRange>[];
    for (var s = range.first.surah; s <= range.last.surah; s++) {
      final from = s == range.first.surah ? range.first.ayah : 1;
      final to = s == range.last.surah ? math.min(range.last.ayah, ayahCount(s)) : ayahCount(s);
      if (to < from) continue;
      for (final (a, b) in split(from, to, size)) {
        out.add(AyahRange(AyahRef(s, a), AyahRef(s, b)));
      }
    }
    return out;
  }
}
