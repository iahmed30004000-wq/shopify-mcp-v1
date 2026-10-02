import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import 'adhkar_models.dart';

/// One run of a set: a category and, for the after-prayer set, the prayer it
/// follows (the after-prayer adhkar are said five times a day).
@immutable
class AdhkarSetKey {
  const AdhkarSetKey(this.category, [this.prayer]);

  final AdhkarCategoryId category;
  final Prayer? prayer;

  /// `morning`, `afterPrayer.fajr` …
  String get storageKey => prayer == null ? category.name : '${category.name}.${prayer!.name}';

  static AdhkarSetKey? parse(String key) {
    final parts = key.split('.');
    final category = AdhkarCategoryId.tryParse(parts.first);
    if (category == null) return null;
    if (parts.length == 1) return AdhkarSetKey(category);
    final prayer = kObligatoryPrayers.where((p) => p.name == parts[1]).firstOrNull;
    return prayer == null ? null : AdhkarSetKey(category, prayer);
  }

  @override
  bool operator ==(Object other) => other is AdhkarSetKey && other.category == category && other.prayer == prayer;

  @override
  int get hashCode => Object.hash(category, prayer);

  @override
  String toString() => 'AdhkarSetKey($storageKey)';
}

/// What was counted in a set today – persisted so the reader resumes where
/// the user left off.
@immutable
class AdhkarProgress {
  const AdhkarProgress({
    this.index = 0,
    this.counts = const {},
    this.completedAt,
    this.markedDone = false,
    this.logged = false,
  });

  /// The page the reader was on.
  final int index;

  /// Taps per dhikr id.
  final Map<String, int> counts;

  /// When the whole set was finished (null = not yet).
  final DateTime? completedAt;

  /// Finished with "mark the set as done" rather than by counting.
  final bool markedDone;

  /// The completion was already written to the activity log today.
  final bool logged;

  bool get isComplete => completedAt != null;

  Map<String, Object?> toJson() => {
    'index': index,
    'counts': counts,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    if (markedDone) 'markedDone': true,
    if (logged) 'logged': true,
  };

  /// Tolerant of anything malformed (falls back to a fresh start).
  factory AdhkarProgress.fromJson(Object? json) {
    if (json is! Map) return const AdhkarProgress();
    final counts = <String, int>{};
    final raw = json['counts'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final v = e.value;
        if (e.key is String && v is num && v >= 0) counts[e.key as String] = v.toInt();
      }
    }
    final index = json['index'];
    final completed = json['completedAt'];
    return AdhkarProgress(
      index: index is num && index >= 0 ? index.toInt() : 0,
      counts: counts,
      completedAt: completed is String ? DateTime.tryParse(completed) : null,
      markedDone: json['markedDone'] == true,
      logged: json['logged'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdhkarProgress &&
      other.index == index &&
      mapEquals(other.counts, counts) &&
      other.completedAt == completedAt &&
      other.markedDone == markedDone &&
      other.logged == logged;

  @override
  int get hashCode => Object.hash(
    index,
    Object.hashAllUnordered(counts.entries.map((e) => '${e.key}=${e.value}')),
    completedAt,
    markedDone,
    logged,
  );
}

/// What a tap on the counter did.
enum AdhkarTapOutcome {
  /// One more repetition; the dhikr is not finished yet.
  counted,

  /// The current dhikr reached its count (the reader chimes and moves on).
  dhikrCompleted,

  /// The last open dhikr of the set reached its count.
  setCompleted,

  /// The current dhikr was already finished; nothing counted.
  alreadyDone,
}

/// The counter state machine of the reader (pure, immutable).
///
/// Counts are kept per dhikr id; [index] is the page on screen. A tap counts
/// on the current dhikr; the UI calls [advance] after the completion chime
/// to move to the next unfinished dhikr.
@immutable
class AdhkarSession {
  const AdhkarSession._({
    required this.key,
    required this.items,
    required this.index,
    required this.counts,
    required this.completedAt,
    required this.markedDone,
    required this.logged,
  });

  /// A session over [category]'s items (filtered for [AdhkarSetKey.prayer]),
  /// resumed from [resume] when given.
  factory AdhkarSession.start(AdhkarCategory category, {Prayer? prayer, AdhkarProgress? resume}) {
    final key = AdhkarSetKey(category.id, category.id == AdhkarCategoryId.afterPrayer ? prayer : null);
    final items = category.itemsFor(key.prayer);
    final r = resume ?? const AdhkarProgress();
    final counts = <String, int>{
      for (final d in items)
        if ((r.counts[d.id] ?? 0) > 0) d.id: math.min(r.counts[d.id]!, d.countFor(key.prayer)),
    };
    return AdhkarSession._(
      key: key,
      items: items,
      index: items.isEmpty ? 0 : r.index.clamp(0, items.length - 1),
      counts: counts,
      completedAt: r.completedAt,
      markedDone: r.markedDone,
      logged: r.logged,
    );
  }

  final AdhkarSetKey key;
  final List<Dhikr> items;
  final int index;
  final Map<String, int> counts;
  final DateTime? completedAt;
  final bool markedDone;
  final bool logged;

  Dhikr get current => items[index];

  int get length => items.length;

  /// Repetitions required for the dhikr at [i].
  int targetAt(int i) => items[i].countFor(key.prayer);

  /// Repetitions done for the dhikr at [i].
  int countAt(int i) => math.min(counts[items[i].id] ?? 0, targetAt(i));

  int remainingAt(int i) => targetAt(i) - countAt(i);

  bool isDoneAt(int i) => countAt(i) >= targetAt(i);

  /// 0…1 for the dhikr at [i].
  double progressAt(int i) => countAt(i) / targetAt(i);

  /// Finished dhikr in the set.
  int get doneCount => [for (var i = 0; i < items.length; i++) isDoneAt(i)].where((d) => d).length;

  /// 0…1 across the set (each dhikr weighs the same, partial counts count).
  double get progress {
    if (items.isEmpty) return 0;
    var sum = 0.0;
    for (var i = 0; i < items.length; i++) {
      sum += progressAt(i);
    }
    return sum / items.length;
  }

  bool get isComplete => completedAt != null;

  bool get isStarted => counts.values.any((c) => c > 0) || isComplete;

  /// The next unfinished dhikr after [from] (wrapping around), or null when
  /// everything is done.
  int? nextIncompleteAfter(int from) {
    for (var k = 1; k <= items.length; k++) {
      final i = (from + k) % items.length;
      if (!isDoneAt(i)) return i;
    }
    return null;
  }

  AdhkarSession _copy({
    int? index,
    Map<String, int>? counts,
    DateTime? completedAt,
    bool clearCompleted = false,
    bool? markedDone,
    bool? logged,
  }) => AdhkarSession._(
    key: key,
    items: items,
    index: index ?? this.index,
    counts: counts ?? this.counts,
    completedAt: clearCompleted ? null : (completedAt ?? this.completedAt),
    markedDone: markedDone ?? this.markedDone,
    logged: logged ?? this.logged,
  );

  /// Counts one repetition of the current dhikr.
  (AdhkarSession, AdhkarTapOutcome) tap(DateTime now) {
    if (items.isEmpty || isDoneAt(index)) return (this, AdhkarTapOutcome.alreadyDone);
    final next = Map<String, int>.of(counts)..[current.id] = countAt(index) + 1;
    var s = _copy(counts: next);
    if (!s.isDoneAt(index)) return (s, AdhkarTapOutcome.counted);
    if (s.nextIncompleteAfter(index) == null) {
      s = s._copy(completedAt: now);
      return (s, AdhkarTapOutcome.setCompleted);
    }
    return (s, AdhkarTapOutcome.dhikrCompleted);
  }

  /// Moves to the next unfinished dhikr (or stays when all are done).
  AdhkarSession advance() => goTo(nextIncompleteAfter(index) ?? index);

  AdhkarSession goTo(int i) => items.isEmpty ? this : _copy(index: i.clamp(0, items.length - 1));

  /// Clears the current dhikr's count (the set is no longer complete).
  AdhkarSession resetCurrent() {
    final next = Map<String, int>.of(counts)..remove(current.id);
    return _copy(counts: next, clearCompleted: true, markedDone: false);
  }

  /// Starts the whole set over (the activity-log flag stays, so finishing it
  /// again the same day does not log it twice).
  AdhkarSession resetAll() => _copy(index: 0, counts: const {}, clearCompleted: true, markedDone: false);

  /// Marks every dhikr as said.
  AdhkarSession markDone(DateTime now) => _copy(
    counts: {for (var i = 0; i < items.length; i++) items[i].id: targetAt(i)},
    completedAt: now,
    markedDone: true,
  );

  AdhkarSession markLogged() => _copy(logged: true);

  AdhkarProgress toProgress() =>
      AdhkarProgress(index: index, counts: counts, completedAt: completedAt, markedDone: markedDone, logged: logged);
}
