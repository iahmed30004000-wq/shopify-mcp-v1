import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';

/// What the sync needs of a kanban card.
@immutable
class CardState {
  const CardState({
    required this.id,
    required this.title,
    required this.columnId,
    required this.updatedAt,
    this.window,
    this.isTop3 = false,
    this.doneColumnId,
    required this.openColumnId,
  });

  final String id;
  final String title;
  final String columnId;
  final PrayerWindow? window;
  final bool isTop3;
  final DateTime updatedAt;

  /// The board's done column (null when it has none).
  final String? doneColumnId;

  /// Where a reopened card goes.
  final String openColumnId;

  bool get done => doneColumnId != null && columnId == doneColumnId;
}

/// What the sync needs of the task placed in a prayer window for a card.
@immutable
class LinkedTaskState {
  const LinkedTaskState({
    required this.id,
    required this.title,
    required this.window,
    required this.done,
    required this.updatedAt,
    this.isTop3 = false,
    this.date,
  });

  final String id;
  final String title;
  final PrayerWindow window;
  final bool done;
  final bool isTop3;
  final DateTime updatedAt;
  final DateTime? date;
}

/// The writes that bring a card and its task back in step.
@immutable
class SyncPlan {
  const SyncPlan({this.card = const {}, this.task = const {}, this.cardCompleted = false, this.cardReopened = false});

  static const SyncPlan none = SyncPlan();

  /// Column values for `board_cards` (`columnId`, `window`, `title`, `isTop3`).
  final Map<String, Object?> card;

  /// Column values for `tasks` (`done`, `window`, `title`, `isTop3`, `cardId`).
  /// `doneAt` is left to the writer (it stamps "now").
  final Map<String, Object?> task;

  /// The card moved into its done column / back out of it because of the task.
  final bool cardCompleted, cardReopened;

  bool get isEmpty => card.isEmpty && task.isEmpty;

  @override
  String toString() => 'SyncPlan(card: $card, task: $task)';
}

/// Keeps a kanban card and the task that places it in a prayer window in
/// step. Pure.
///
/// The Work screens change both sides together; the home panel only knows
/// the task (swiping it done, moving it to another window, renaming it,
/// deleting it). Whenever they disagree the side changed last wins (the
/// task on a tie) – the home panel's change reaches the card, a card change
/// reaches the task.
///
/// * done ⇄ the card is in its board's done column;
/// * window ⇄ the card's `window`;
/// * title and Top 3 flag are mirrored;
/// * a card placed in a window whose task is gone (deleted from home) is
///   no longer placed; a task pointing at an unplaced card (the delete
///   undone, an import) places it again.
abstract final class CardTaskSync {
  static SyncPlan reconcile(CardState card, LinkedTaskState? task) {
    if (task == null) {
      return card.window == null ? SyncPlan.none : const SyncPlan(card: {'window': null});
    }
    // Only the task is ever changed on its own (the Work screens write both
    // sides together), so a tie goes to the task.
    final taskWins = !card.updatedAt.isAfter(task.updatedAt);
    final cardOut = <String, Object?>{};
    final taskOut = <String, Object?>{};
    var completed = false, reopened = false;

    if (card.window == null) {
      // Taking a card out of its window removes / unlinks the task in the
      // same write, so a linked task here was restored (an undone delete)
      // or imported: it places the card again.
      cardOut['window'] = task.window;
    } else if (card.window != task.window) {
      if (taskWins) {
        cardOut['window'] = task.window;
      } else {
        taskOut['window'] = card.window;
      }
    }

    if (card.done != task.done) {
      if (taskWins) {
        if (task.done) {
          if (card.doneColumnId != null) {
            cardOut['columnId'] = card.doneColumnId;
            completed = true;
          }
        } else {
          cardOut['columnId'] = card.openColumnId;
          reopened = true;
        }
      } else if (card.doneColumnId != null || !task.done) {
        taskOut['done'] = card.done;
      }
    }

    if (card.title != task.title && task.title.trim().isNotEmpty) {
      if (taskWins) {
        cardOut['title'] = task.title;
      } else {
        taskOut['title'] = card.title;
      }
    }

    if (card.isTop3 != task.isTop3) {
      if (taskWins) {
        cardOut['isTop3'] = task.isTop3;
      } else {
        taskOut['isTop3'] = card.isTop3;
      }
    }
    return SyncPlan(card: cardOut, task: taskOut, cardCompleted: completed, cardReopened: reopened);
  }

  /// The task that represents a card when several point at it (imports,
  /// an undone delete): an open one first, then the latest day, then the
  /// most recently changed.
  static T? primary<T extends LinkedTaskState>(Iterable<T> tasks) {
    T? best;
    for (final t in tasks) {
      if (best == null || _better(t, best)) best = t;
    }
    return best;
  }

  static bool _better(LinkedTaskState a, LinkedTaskState b) {
    if (a.done != b.done) return !a.done;
    final ad = a.date, bd = b.date;
    if (ad != null && bd != null && ad != bd) return ad.isAfter(bd);
    if ((ad == null) != (bd == null)) return ad != null;
    return a.updatedAt.isAfter(b.updatedAt);
  }
}
