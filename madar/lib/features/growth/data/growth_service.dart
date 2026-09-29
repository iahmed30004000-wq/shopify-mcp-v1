import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../domain/growth_days.dart';

/// Undoes one Growth change exactly.
typedef GrowthUndo = Future<void> Function();

/// Writes one activity entry (the app's goes through the orbit pulse hub so
/// the Growth planet pulses at once).
typedef GrowthActivityRecorder = Future<void> Function({
  required String kind,
  required String refTable,
  required String refId,
  required DateTime at,
  double? value,
  Map<String, Object?> payload,
});

/// How progress shows up in the activity stream (the orbit's freshness and
/// Neglect Radar read it).
abstract final class GrowthActivity {
  static const String planetKey = 'growth';

  /// One entry per log: refTable [logTable], refId the log's id, value its
  /// amount, payload `{goalId}`.
  static const String logKind = 'growth.log';
  static const String logTable = 'goal_logs';
}

/// What the goal editor produces.
@immutable
class GoalDraft {
  const GoalDraft({
    required this.name,
    required this.target,
    this.unit = '',
    this.initial = 0,
    this.deadline,
    this.color,
    this.active = true,
  });

  factory GoalDraft.of(LearningGoalRow row) => GoalDraft(
    name: row.name,
    unit: row.unit,
    target: row.target,
    initial: row.initial,
    deadline: row.deadline,
    color: row.color,
    active: row.active,
  );

  final String name;

  /// Stored unit (see `GrowthUnit.stored`).
  final String unit;
  final double target;
  final double initial;
  final DateTime? deadline;
  final int? color;
  final bool active;

  GoalDraft copyWith({
    String? name,
    String? unit,
    double? target,
    double? initial,
    DateTime? deadline,
    bool clearDeadline = false,
    int? color,
    bool? active,
  }) => GoalDraft(
    name: name ?? this.name,
    unit: unit ?? this.unit,
    target: target ?? this.target,
    initial: initial ?? this.initial,
    deadline: clearDeadline ? null : (deadline ?? this.deadline),
    color: color ?? this.color,
    active: active ?? this.active,
  );

  @override
  bool operator ==(Object other) =>
      other is GoalDraft &&
      other.name == name &&
      other.unit == unit &&
      other.target == target &&
      other.initial == initial &&
      other.deadline == deadline &&
      other.color == color &&
      other.active == active;

  @override
  int get hashCode => Object.hash(name, unit, target, initial, deadline, color, active);
}

/// What the log sheet produces.
@immutable
class GoalLogDraft {
  const GoalLogDraft({required this.amount, required this.at, this.note});

  final double amount;
  final DateTime at;
  final String? note;
}

/// Reads and writes learning goals and their progress logs. Every write
/// returns an undo that restores the exact prior state, and every log is
/// mirrored in the activity stream (planet `growth`).
class GrowthService {
  GrowthService(this.repos, {DateTime Function()? clock, this.recorder}) : clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() clock;

  /// Where activity goes (null: straight into the activity log).
  final GrowthActivityRecorder? recorder;

  // ------------------------------------------------------------- reads ----

  Stream<List<LearningGoalRow>> watchGoals() => repos.learningGoals.watchAll();

  Stream<List<GoalLogRow>> watchLogs() => repos.goalLogs.watchAll();

  Future<List<GoalLogRow>> logsOf(String goalId) => repos.goalLogs.getAll(where: (l) => l.goalId.equals(goalId));

  // ------------------------------------------------------------- goals ----

  static String _clean(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  Future<(LearningGoalRow, GrowthUndo)> createGoal(GoalDraft d) async {
    final now = clock();
    final row = await repos.learningGoals.insert(
      LearningGoalsCompanion.insert(
        name: _clean(d.name),
        unit: Value(d.unit.trim()),
        target: d.target,
        initial: Value(d.initial),
        deadline: Value(d.deadline == null ? null : GrowthDays.dateOnly(d.deadline!)),
        color: Value(d.color),
        active: Value(d.active),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return (row, () async => _deleteCascade(row.id));
  }

  Future<GrowthUndo> updateGoal(LearningGoalRow goal, GoalDraft d) async {
    final before = await repos.learningGoals.byId(goal.id) ?? goal;
    await repos.learningGoals.setColumns(goal.id, {
      'name': _clean(d.name),
      'unit': d.unit.trim(),
      'target': d.target,
      'initial': d.initial,
      'deadline': d.deadline == null ? null : GrowthDays.dateOnly(d.deadline!),
      'color': d.color,
      'active': d.active,
    });
    return () => repos.learningGoals.update(before);
  }

  /// A fresh copy of [goal] (no logs) right after it.
  Future<(LearningGoalRow, GrowthUndo)> duplicateGoal(LearningGoalRow goal, {String? name}) async {
    final now = clock();
    final copy = await repos.learningGoals.duplicate(
      goal.id,
      overrides: {'name': ?name, 'active': true, 'createdAt': now, 'updatedAt': now},
    );
    return (copy, () async => _deleteCascade(copy.id));
  }

  Future<GrowthUndo> setActive(LearningGoalRow goal, bool active) async {
    final before = await repos.learningGoals.byId(goal.id) ?? goal;
    await repos.learningGoals.setColumn(goal.id, 'active', active);
    return () => repos.learningGoals.update(before);
  }

  /// Deletes [goal] with its logs and their activity entries.
  Future<GrowthUndo> deleteGoal(LearningGoalRow goal) async {
    final removed = await _deleteCascade(goal.id);
    return () async {
      await repos.db.transaction(() async {
        if (removed.goal != null) await repos.learningGoals.restore(removed.goal!);
        await repos.goalLogs.restoreAll(removed.logs);
        await repos.activityLog.restoreAll(removed.activity);
      });
    };
  }

  Future<({LearningGoalRow? goal, List<GoalLogRow> logs, List<ActivityRow> activity})> _deleteCascade(String goalId) {
    return repos.db.transaction(() async {
      final logs = await repos.goalLogs.deleteWhere((l) => l.goalId.equals(goalId));
      final ids = [for (final l in logs) l.id];
      final activity = ids.isEmpty
          ? const <ActivityRow>[]
          : await repos.activityLog.deleteWhere((a) => a.refTable.equals(GrowthActivity.logTable) & a.refId.isIn(ids));
      final goal = await repos.learningGoals.delete(goalId);
      return (goal: goal, logs: logs, activity: activity);
    });
  }

  /// Persists a drag-and-drop order of goal ids.
  Future<GrowthUndo> reorder(List<String> idsInOrder) async {
    final before = [for (final g in await repos.learningGoals.getAll()) g.id];
    await repos.learningGoals.reorder(idsInOrder);
    return () => repos.learningGoals.reorder(before);
  }

  // -------------------------------------------------------------- logs ----

  /// Logs [amount] of progress on [goalId] at [at] (default now).
  Future<(GoalLogRow, GrowthUndo)> addLog(String goalId, double amount, {DateTime? at, String? note}) async {
    final now = clock();
    final when = at ?? now;
    final text = note?.trim();
    final row = await repos.goalLogs.insert(
      GoalLogsCompanion.insert(
        goalId: goalId,
        amount: amount,
        at: when,
        note: Value(text == null || text.isEmpty ? null : text),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await _record(row);
    return (
      row,
      () async {
        await repos.goalLogs.delete(row.id);
        await repos.activity.removeFor(refTable: GrowthActivity.logTable, refId: row.id);
      },
    );
  }

  /// Changes a log's amount, time or note (its activity entry follows).
  Future<GrowthUndo> updateLog(GoalLogRow log, {required double amount, required DateTime at, String? note}) async {
    final before = await repos.goalLogs.byId(log.id) ?? log;
    final text = note?.trim();
    await repos.goalLogs.setColumns(log.id, {
      'amount': amount,
      'at': at,
      'note': text == null || text.isEmpty ? null : text,
    });
    final activity = await _activityOf(log.id);
    for (final a in activity) {
      await repos.activityLog.setColumns(a.id, {'at': at, 'value': amount});
    }
    return () async {
      await repos.goalLogs.update(before);
      for (final a in activity) {
        await repos.activityLog.update(a);
      }
    };
  }

  Future<GrowthUndo> deleteLog(GoalLogRow log) async {
    final row = await repos.goalLogs.delete(log.id);
    final activity = await repos.activity.removeFor(refTable: GrowthActivity.logTable, refId: log.id);
    return () async {
      if (row != null) await repos.goalLogs.restore(row);
      if (activity.isNotEmpty) await repos.activityLog.restoreAll(activity);
    };
  }

  Future<List<ActivityRow>> _activityOf(String logId) =>
      repos.activityLog.getAll(where: (a) => a.refTable.equals(GrowthActivity.logTable) & a.refId.equals(logId));

  Future<void> _record(GoalLogRow row) async {
    final payload = <String, Object?>{'goalId': row.goalId};
    final record = recorder;
    if (record != null) {
      await record(
        kind: GrowthActivity.logKind,
        refTable: GrowthActivity.logTable,
        refId: row.id,
        at: row.at,
        value: row.amount,
        payload: payload,
      );
    } else {
      await repos.activity.log(
        planetKey: GrowthActivity.planetKey,
        kind: GrowthActivity.logKind,
        refTable: GrowthActivity.logTable,
        refId: row.id,
        at: row.at,
        value: row.amount,
        payload: payload,
      );
    }
  }
}
