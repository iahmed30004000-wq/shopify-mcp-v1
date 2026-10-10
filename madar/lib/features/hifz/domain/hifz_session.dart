import 'package:flutter/foundation.dart';

import '../../wird/domain/calendar_days.dart';
import 'hifz_models.dart';
import 'sm2.dart';

/// A card in the session queue.
@immutable
class HifzSessionItem {
  const HifzSessionItem(this.card, {this.redrill = false});

  final HifzCard card;

  /// A same-day repeat of a card graded below 4 (SM-2 step 7): drilled
  /// again, but its schedule is not changed.
  final bool redrill;
}

/// What one grade did.
@immutable
class HifzGradeOutcome {
  const HifzGradeOutcome({
    required this.item,
    required this.grade,
    required this.before,
    this.after,
    this.queuedRedrill = false,
  });

  final HifzSessionItem item;
  final int grade;

  /// The card before the grade.
  final HifzCard before;

  /// The rescheduled card (null for a re-drill: nothing changes).
  final HifzCard? after;

  /// The card was put back at the end of the session.
  final bool queuedRedrill;

  bool get scheduled => after != null;
}

/// The review session (pure): due and new cards in order, SM-2 grading,
/// same-day re-drills of cards graded below 4, and undo of the last grade.
class HifzSession {
  HifzSession(Iterable<HifzCard> queue) : _queue = [for (final c in queue) HifzSessionItem(c)];

  final List<HifzSessionItem> _queue;
  final List<HifzGradeOutcome> _history = [];
  int _index = 0;

  /// Re-drills per card, at most (so a stubborn card cannot trap the user).
  static const int maxRedrills = 3;

  HifzSessionItem? get current => _index < _queue.length ? _queue[_index] : null;

  /// Cards shown so far (0-based position of [current]).
  int get position => _index;

  /// Cards in the session, re-drills included.
  int get length => _queue.length;
  bool get isComplete => _index >= _queue.length;
  bool get canUndo => _history.isNotEmpty;
  List<HifzGradeOutcome> get history => List.unmodifiable(_history);

  /// Grades [current] with SM-2 quality [grade] at [now] and moves on.
  HifzGradeOutcome grade(int grade, DateTime now) {
    final item = current;
    if (item == null) throw StateError('HifzSession: nothing to grade');
    if (grade < 0 || grade > 5) throw RangeError.range(grade, 0, 5, 'grade');
    final before = item.card;
    HifzCard? after;
    if (!item.redrill) {
      final s = Sm2.review(before.sm2, grade);
      after = before.withSm2(s, due: Sm2.dueDate(now, s.intervalDays), reviewedAt: now);
    }
    final drills = _queue.where((q) => q.redrill && q.card.id == before.id).length;
    final again = grade < Sm2.redrillBelow && drills < maxRedrills;
    if (again) _queue.add(HifzSessionItem(after ?? before, redrill: true));
    final outcome = HifzGradeOutcome(item: item, grade: grade, before: before, after: after, queuedRedrill: again);
    _history.add(outcome);
    _index++;
    return outcome;
  }

  /// Takes back the last grade (and the re-drill it queued); returns it.
  HifzGradeOutcome? undo() {
    if (_history.isEmpty) return null;
    final last = _history.removeLast();
    if (last.queuedRedrill) {
      final i = _queue.lastIndexWhere((q) => q.redrill && q.card.id == last.before.id);
      if (i >= 0) _queue.removeAt(i);
    }
    _index--;
    return last;
  }

  /// The session so far.
  HifzSessionSummary get summary {
    final first = _history.where((h) => !h.item.redrill).toList();
    final grades = [for (final h in first) h.grade];
    return HifzSessionSummary(
      reviewed: first.length,
      learnedNew: first.where((h) => h.before.isNew).length,
      redrills: _history.length - first.length,
      averageGrade: grades.isEmpty ? null : grades.reduce((a, b) => a + b) / grades.length,
      recalled: grades.isEmpty ? null : grades.where((g) => g >= Sm2.passGrade).length / grades.length,
    );
  }
}

/// The end-of-session numbers.
@immutable
class HifzSessionSummary {
  const HifzSessionSummary({
    this.reviewed = 0,
    this.learnedNew = 0,
    this.redrills = 0,
    this.averageGrade,
    this.recalled,
  });

  /// Cards graded (first time today).
  final int reviewed;

  /// Of which were new.
  final int learnedNew;
  final int redrills;
  final double? averageGrade;

  /// Share graded ≥ 3.
  final double? recalled;
}

/// Due counts per day after [today] (for "tomorrow: N" in the summary).
int hifzDueOn(Iterable<HifzCard> cards, DateTime day) =>
    cards.where((c) => !c.isNew && !c.suspended && CalendarDays.between(c.due!, day) >= 0).length;
