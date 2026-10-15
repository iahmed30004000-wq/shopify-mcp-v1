import 'package:flutter/foundation.dart';

import 'countdown.dart';

/// Folds a name for matching: case, spacing, Arabic letter variants
/// (أ إ آ → ا, ة → ه, ى → ي), tatweel and harakat.
String foldName(String s) {
  var out = s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  out = out.replaceAll(RegExp('[ً-ْٰـ]'), '');
  out = out.replaceAll(RegExp('[أإآٱ]'), 'ا').replaceAll('ة', 'ه').replaceAll('ى', 'ي');
  return out;
}

/// A past assignee with how often and how lately cards went to them.
@immutable
class AssigneeUse {
  const AssigneeUse(this.name, this.at);

  final String name;
  final DateTime at;
}

abstract final class AssigneeSuggestions {
  /// Distinct past assignees ranked by use (each use weighs less the older
  /// it is), those matching [query] (prefix of any word first), the display
  /// spelling being the most recent one; at most [limit].
  static List<String> rank(Iterable<AssigneeUse> uses, {String query = '', DateTime? now, int limit = 8}) {
    final ref = now ?? DateTime.now();
    final score = <String, double>{};
    final spelling = <String, (String, DateTime)>{};
    for (final u in uses) {
      final name = u.name.trim();
      if (name.isEmpty) continue;
      final k = foldName(name);
      final ageDays = ref.difference(u.at).inHours / 24.0;
      score[k] = (score[k] ?? 0) + 1 / (1 + (ageDays < 0 ? 0 : ageDays) / 14);
      final prev = spelling[k];
      if (prev == null || u.at.isAfter(prev.$2)) spelling[k] = (name, u.at);
    }
    final q = foldName(query);
    int match(String k) {
      if (q.isEmpty) return 0;
      if (k.startsWith(q)) return 0;
      if (k.split(' ').any((w) => w.startsWith(q))) return 1;
      if (k.contains(q)) return 2;
      return -1;
    }

    final keys = [
      for (final k in score.keys)
        if (match(k) >= 0 && k != q) k,
    ];
    keys.sort((a, b) {
      final m = match(a).compareTo(match(b));
      if (m != 0) return m;
      final s = score[b]!.compareTo(score[a]!);
      return s != 0 ? s : a.compareTo(b);
    });
    return [for (final k in keys.take(limit)) spelling[k]!.$1];
  }
}

/// Due-date filter of a board.
enum DueFilter { any, overdue, today, week, noDate }

/// Board filter: by assignee (folded name; [unassigned] for cards without
/// one) and due date.
@immutable
class CardFilter {
  const CardFilter({this.assignee, this.due = DueFilter.any});

  static const CardFilter all = CardFilter();

  /// Sentinel for "cards without an assignee".
  static const String unassigned = '\u0000none';

  final String? assignee;
  final DueFilter due;

  bool get isActive => assignee != null || due != DueFilter.any;

  CardFilter withAssignee(String? a) => CardFilter(assignee: a, due: due);
  CardFilter withDue(DueFilter d) => CardFilter(assignee: assignee, due: d);

  /// Whether a card passes. [done] cards are never "overdue" or "due".
  bool matches({String? assignee, DateTime? dueDate, required bool done, required DateTime today}) {
    final a = this.assignee;
    if (a != null) {
      final name = assignee?.trim() ?? '';
      if (a == unassigned) {
        if (name.isNotEmpty) return false;
      } else if (foldName(name) != foldName(a)) {
        return false;
      }
    }
    switch (due) {
      case DueFilter.any:
        return true;
      case DueFilter.noDate:
        return dueDate == null;
      case DueFilter.overdue:
        return DueRules.of(dueDate, today, done: done) == DueStatus.overdue;
      case DueFilter.today:
        final s = DueRules.of(dueDate, today, done: done);
        return s == DueStatus.today || s == DueStatus.overdue;
      case DueFilter.week:
        final s = DueRules.of(dueDate, today, done: done);
        return s == DueStatus.overdue || s == DueStatus.today || s == DueStatus.tomorrow || s == DueStatus.soon;
    }
  }

  @override
  bool operator ==(Object other) => other is CardFilter && other.assignee == assignee && other.due == due;

  @override
  int get hashCode => Object.hash(assignee, due);
}
