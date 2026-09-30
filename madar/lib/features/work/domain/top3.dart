import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import 'work_days.dart';

enum FocusKind { card, task }

/// A Top 3 item: a kanban card or a task (a task placed for a card is
/// represented by its card).
@immutable
class FocusItem {
  const FocusItem({
    required this.kind,
    required this.id,
    required this.title,
    this.done = false,
    this.flagged = false,
    this.boardId,
    this.boardName,
    this.projectId,
    this.color,
    this.window,
    this.date,
    this.dueDate,
    this.assignee,
    this.cardId,
    this.sortKey = 0,
  });

  final FocusKind kind;
  final String id;
  final String title;
  final bool done;

  /// Currently one of the Top 3.
  final bool flagged;
  final String? boardId, boardName, projectId, assignee;

  /// For a task: the card it places in a window (then [kind] is a task only
  /// when the card itself is missing).
  final String? cardId;
  final int? color;
  final PrayerWindow? window;

  /// A task's day.
  final DateTime? date;

  /// A card's due date.
  final DateTime? dueDate;

  /// Stable order among the flagged (row order; lower first).
  final int sortKey;

  String get key => '${kind.name}:$id';

  FocusItem copyWith({bool? done, bool? flagged, DateTime? date}) => FocusItem(
    kind: kind,
    id: id,
    title: title,
    done: done ?? this.done,
    flagged: flagged ?? this.flagged,
    boardId: boardId,
    boardName: boardName,
    projectId: projectId,
    color: color,
    window: window,
    date: date ?? this.date,
    dueDate: dueDate,
    assignee: assignee,
    cardId: cardId,
    sortKey: sortKey,
  );

  @override
  bool operator ==(Object other) =>
      other is FocusItem &&
      other.kind == kind &&
      other.id == id &&
      other.title == title &&
      other.done == done &&
      other.flagged == flagged &&
      other.date == date &&
      other.window == window;

  @override
  int get hashCode => Object.hash(kind, id, title, done, flagged, date, window);

  @override
  String toString() => 'FocusItem($key, "$title"${done ? ', done' : ''}${flagged ? ', top3' : ''})';
}

/// Where today's Top 3 stands.
@immutable
class Top3State {
  const Top3State({
    required this.today,
    this.items = const [],
    this.leftovers = const [],
    this.staleDone = const [],
    this.storedDay,
  });

  final DateTime today;

  /// Today's focus, in order (at most [Top3Rules.max] shown).
  final List<FocusItem> items;

  /// Unfinished items still flagged from an earlier day: the morning
  /// carry-over prompt offers to keep them for today.
  final List<FocusItem> leftovers;

  /// Items finished on an earlier day that are still flagged (cleared
  /// silently at the rollover).
  final List<FocusItem> staleDone;

  /// The day the flags were set for (null: never).
  final DateTime? storedDay;

  bool get needsCarryOver => leftovers.isNotEmpty;

  /// Flags from an earlier day that have to be settled (prompt or silently).
  bool get needsRollover => storedDay != null && WorkDays.between(storedDay!, today) > 0 && (leftovers.isNotEmpty || staleDone.isNotEmpty);

  int get doneCount => items.where((i) => i.done).length;
  bool get isEmpty => items.isEmpty;
  bool get isFull => items.length >= Top3Rules.max;
  bool get allDone => items.isNotEmpty && items.every((i) => i.done);
  int get openSlots => (Top3Rules.max - items.length).clamp(0, Top3Rules.max);
}

/// Outcome of asking to flag an item.
enum Top3AddResult { added, alreadyIn, full }

/// What the rollover writes: flags to clear and tasks to move to today.
@immutable
class Top3Rollover {
  const Top3Rollover({this.unflag = const [], this.redate = const []});

  final List<FocusItem> unflag;

  /// Items carried over whose day was before today: a task moves to
  /// today, a card placed in a window has its open window task moved to
  /// today (so it shows in today's home panel again).
  final List<FocusItem> redate;

  bool get isEmpty => unflag.isEmpty && redate.isEmpty;
}

/// Pure Top 3 rules: at most three focus items for today across boards and
/// tasks, the day they were chosen for, and the next morning's carry-over.
abstract final class Top3Rules {
  static const int max = 3;

  /// Today's Top 3 from every flagged item, the day the flags were set for
  /// ([storedDay], null when unknown – then they count as today's) and
  /// [today].
  static Top3State evaluate({required List<FocusItem> flagged, required DateTime? storedDay, required DateTime today}) {
    final day = WorkDays.dateOnly(today);
    final sorted = [...flagged]..sort(_order);
    final stale = storedDay != null && WorkDays.between(storedDay, day) > 0;
    if (!stale) {
      return Top3State(today: day, items: sorted.take(max).toList(), storedDay: storedDay);
    }
    return Top3State(
      today: day,
      leftovers: [for (final i in sorted) if (!i.done) i],
      staleDone: [for (final i in sorted) if (i.done) i],
      storedDay: storedDay,
    );
  }

  static int _order(FocusItem a, FocusItem b) {
    final c = a.sortKey.compareTo(b.sortKey);
    return c != 0 ? c : a.key.compareTo(b.key);
  }

  /// Whether [item] can join [state]'s Top 3.
  static Top3AddResult canAdd(Top3State state, FocusItem item) {
    if (state.items.any((i) => i.key == item.key)) return Top3AddResult.alreadyIn;
    if (state.items.length >= max) return Top3AddResult.full;
    return Top3AddResult.added;
  }

  /// Keep yesterday's unfinished focus for today: finished ones are
  /// cleared, dated tasks (and the window tasks of placed cards) move to
  /// today.
  static Top3Rollover carryOver(Top3State state) {
    final keep = state.leftovers.take(max).toList();
    return Top3Rollover(
      unflag: [...state.staleDone, ...state.leftovers.skip(max)],
      redate: [
        for (final i in keep)
          if (i.date != null && WorkDays.between(i.date!, state.today) > 0) i,
      ],
    );
  }

  /// Start today with an empty Top 3.
  static Top3Rollover startFresh(Top3State state) =>
      Top3Rollover(unflag: [...state.leftovers, ...state.staleDone, ...state.items]);

  /// Rollover with nothing to ask (only finished items are stale).
  static Top3Rollover silent(Top3State state) =>
      state.leftovers.isEmpty ? Top3Rollover(unflag: state.staleDone) : const Top3Rollover();

  /// Candidates to pick from: open items not already flagged, the ones
  /// that matter today first (overdue / due today / placed today), then the
  /// rest in their order.
  static List<FocusItem> candidates(List<FocusItem> all, DateTime today) {
    final day = WorkDays.dateOnly(today);
    int urgency(FocusItem i) {
      final d = i.kind == FocusKind.task ? i.date : i.dueDate;
      if (d == null) return i.window != null ? 2 : 3;
      final n = WorkDays.between(day, d);
      if (n < 0) return 0;
      if (n == 0) return 1;
      return 3 + n;
    }

    final out = [
      for (final i in all)
        if (!i.done && !i.flagged && _relevant(i, day)) i,
    ];
    out.sort((a, b) {
      final c = urgency(a).compareTo(urgency(b));
      return c != 0 ? c : _order(a, b);
    });
    return out;
  }

  /// A task belongs to today's choices when it is undated or dated today
  /// or earlier; a card always does.
  static bool _relevant(FocusItem i, DateTime day) {
    if (i.kind == FocusKind.card) return true;
    final d = i.date;
    return d == null || WorkDays.between(d, day) >= 0;
  }
}
