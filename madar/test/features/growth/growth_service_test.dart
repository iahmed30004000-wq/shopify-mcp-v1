import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/growth/growth.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  var now = DateTime(2026, 9, 28, 17, 10);
  late GrowthService service;

  setUp(() {
    db = MadarDatabase(NativeDatabase.memory());
    repos = Repositories(db);
    now = DateTime(2026, 9, 28, 17, 10);
    service = GrowthService(repos, clock: () => now);
  });

  tearDown(() => db.close());

  Future<List<ActivityRow>> activity() => repos.activityLog.getAll();

  group('goals', () {
    test('create stores a clean goal and undo removes it', () async {
      final (row, undo) = await service.createGoal(
        GoalDraft(
          name: '  Read   a book ',
          unit: ' pages ',
          target: 300,
          initial: 20,
          deadline: DateTime(2026, 11, 1, 15),
        ),
      );
      expect(row.name, 'Read a book');
      expect(row.unit, 'pages');
      expect(row.initial, 20);
      expect(row.deadline, DateTime(2026, 11, 1));
      expect(row.createdAt, now);
      expect(row.active, isTrue);
      await undo();
      expect(await repos.learningGoals.getAll(), isEmpty);
    });

    test('update and undo restore the exact row', () async {
      final (row, _) = await service.createGoal(const GoalDraft(name: 'A', target: 10));
      final undo = await service.updateGoal(row, const GoalDraft(name: 'B', unit: 'hours', target: 20, color: 7));
      final changed = (await repos.learningGoals.byId(row.id))!;
      expect([changed.name, changed.unit, changed.target, changed.color], ['B', 'hours', 20, 7]);
      await undo();
      final back = (await repos.learningGoals.byId(row.id))!;
      expect([back.name, back.unit, back.target, back.color], ['A', '', 10, null]);
    });

    test('pause / resume with undo', () async {
      final (row, _) = await service.createGoal(const GoalDraft(name: 'A', target: 10));
      final undo = await service.setActive(row, false);
      expect((await repos.learningGoals.byId(row.id))!.active, isFalse);
      await undo();
      expect((await repos.learningGoals.byId(row.id))!.active, isTrue);
    });

    test('duplicate copies the goal (not its logs) right after it', () async {
      final (a, _) = await service.createGoal(const GoalDraft(name: 'A', target: 10, unit: 'pages'));
      final (b, _) = await service.createGoal(const GoalDraft(name: 'B', target: 10));
      await service.addLog(a.id, 4);
      now = now.add(const Duration(days: 2));
      final (copy, undo) = await service.duplicateGoal(a, name: 'A (copy)');
      expect(copy.name, 'A (copy)');
      expect(copy.unit, 'pages');
      expect(copy.createdAt, now);
      expect([for (final g in await repos.learningGoals.getAll()) g.id], [a.id, copy.id, b.id]);
      expect(await service.logsOf(copy.id), isEmpty);
      await undo();
      expect(await repos.learningGoals.count(), 2);
    });

    test('reorder with undo', () async {
      final (a, _) = await service.createGoal(const GoalDraft(name: 'A', target: 1));
      final (b, _) = await service.createGoal(const GoalDraft(name: 'B', target: 1));
      final (c, _) = await service.createGoal(const GoalDraft(name: 'C', target: 1));
      final undo = await service.reorder([c.id, a.id, b.id]);
      expect([for (final g in await repos.learningGoals.getAll()) g.name], ['C', 'A', 'B']);
      await undo();
      expect([for (final g in await repos.learningGoals.getAll()) g.name], ['A', 'B', 'C']);
    });

    test('delete cascades logs and their activity; undo brings everything back', () async {
      final (goal, _) = await service.createGoal(const GoalDraft(name: 'A', target: 10));
      final (other, _) = await service.createGoal(const GoalDraft(name: 'B', target: 10));
      await service.addLog(goal.id, 2);
      await service.addLog(goal.id, 3);
      await service.addLog(other.id, 1);
      expect(await activity(), hasLength(3));
      final undo = await service.deleteGoal(goal);
      expect(await repos.learningGoals.count(), 1);
      expect(await repos.goalLogs.count(), 1);
      expect(await activity(), hasLength(1));
      await undo();
      expect(await repos.learningGoals.count(), 2);
      expect(await service.logsOf(goal.id), hasLength(2));
      expect(await activity(), hasLength(3));
    });
  });

  group('logs', () {
    test('each log is mirrored in the activity stream of the growth planet', () async {
      final (goal, _) = await service.createGoal(const GoalDraft(name: 'A', target: 10));
      final at = DateTime(2026, 9, 28, 9, 30);
      final (log, undo) = await service.addLog(goal.id, 2.5, at: at, note: '  chapter two ');
      expect(log.note, 'chapter two');
      expect(log.at, at);
      final a = (await activity()).single;
      expect(a.planetKey, 'growth');
      expect(a.kind, GrowthActivity.logKind);
      expect(a.refTable, GrowthActivity.logTable);
      expect(a.refTable, repos.goalLogs.tableName);
      expect(a.refId, log.id);
      expect(a.value, 2.5);
      expect(a.at, at);
      expect(a.payload['goalId'], goal.id);
      await undo();
      expect(await repos.goalLogs.count(), 0);
      expect(await activity(), isEmpty);
    });

    test('an empty note is stored as null; time defaults to now', () async {
      final (goal, _) = await service.createGoal(const GoalDraft(name: 'A', target: 10));
      final (log, _) = await service.addLog(goal.id, 1, note: '  ');
      expect(log.note, isNull);
      expect(log.at, now);
    });

    test('a recorder, when given, receives the activity instead', () async {
      final calls = <(String, String, String, double?)>[];
      final recorded = GrowthService(
        repos,
        clock: () => now,
        recorder: ({required kind, required refTable, required refId, required at, value, payload = const {}}) async {
          calls.add((kind, refTable, refId, value));
        },
      );
      final (goal, _) = await recorded.createGoal(const GoalDraft(name: 'A', target: 10));
      final (log, _) = await recorded.addLog(goal.id, 3);
      expect(calls, [(GrowthActivity.logKind, GrowthActivity.logTable, log.id, 3.0)]);
      expect(await activity(), isEmpty);
    });

    test('update moves the activity entry with it; undo restores both', () async {
      final (goal, _) = await service.createGoal(const GoalDraft(name: 'A', target: 10));
      final (log, _) = await service.addLog(goal.id, 2, at: DateTime(2026, 9, 27, 8));
      final undo = await service.updateLog(log, amount: 5, at: DateTime(2026, 9, 26, 20), note: 'fixed');
      final changed = (await repos.goalLogs.byId(log.id))!;
      expect([changed.amount, changed.at, changed.note], [5, DateTime(2026, 9, 26, 20), 'fixed']);
      final a = (await activity()).single;
      expect([a.value, a.at], [5, DateTime(2026, 9, 26, 20)]);
      await undo();
      final back = (await repos.goalLogs.byId(log.id))!;
      expect([back.amount, back.at, back.note], [2, DateTime(2026, 9, 27, 8), null]);
      final b = (await activity()).single;
      expect([b.value, b.at], [2, DateTime(2026, 9, 27, 8)]);
    });

    test('delete removes the activity entry; undo restores both', () async {
      final (goal, _) = await service.createGoal(const GoalDraft(name: 'A', target: 10));
      final (log, _) = await service.addLog(goal.id, 2);
      final undo = await service.deleteLog(log);
      expect(await repos.goalLogs.count(), 0);
      expect(await activity(), isEmpty);
      await undo();
      expect((await repos.goalLogs.byId(log.id))!.amount, 2);
      expect(await activity(), hasLength(1));
    });
  });

  group('overview', () {
    LearningGoalRow goalRow(
      String id, {
      double target = 100,
      double initial = 0,
      DateTime? deadline,
      bool active = true,
      String unit = '',
      DateTime? created,
    }) => LearningGoalRow(
      id: id,
      createdAt: created ?? DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      sortOrder: 0,
      name: id,
      unit: unit,
      target: target,
      initial: initial,
      deadline: deadline,
      active: active,
    );

    var logSeq = 0;
    GoalLogRow logRow(String goalId, double amount, DateTime at) =>
        GoalLogRow(id: 'l${logSeq++}', createdAt: at, updatedAt: at, goalId: goalId, amount: amount, at: at);

    final today = DateTime(2026, 9, 28);
    DateTime day(int offset) => DateTime(2026, 9, 28 + offset, 20);

    test('sections, focus order, average progress and the shared streak', () {
      final rows = [
        goalRow('ahead', deadline: DateTime(2026, 10, 27)),
        goalRow('open'),
        goalRow('fresh', deadline: DateTime(2026, 10, 27), created: DateTime(2026, 9, 28)),
        goalRow('behind', deadline: DateTime(2026, 10, 27)),
        goalRow('late', deadline: DateTime(2026, 9, 20)),
        goalRow('done', target: 10),
        goalRow('paused', active: false),
      ];
      final logs = [
        for (var i = -13; i <= 0; i++) logRow('ahead', 5, day(i)),
        logRow('open', 10, day(-1)),
        logRow('behind', 1, day(-2)),
        logRow('late', 20, day(-10)),
        logRow('done', 12, day(-3)),
        logRow('paused', 50, day(-4)),
        logRow('gone', 1, day(-20)), // a log of a deleted goal
      ];
      final o = GrowthOverview.of(rows, logs, today: today);
      expect([for (final g in o.active) g.id], ['ahead', 'open', 'fresh', 'behind', 'late']);
      expect([for (final g in o.completed) g.id], ['done']);
      expect([for (final g in o.paused) g.id], ['paused']);
      expect([for (final g in o.focus()) g.id], ['late', 'behind', 'fresh', 'open', 'ahead']);
      expect([for (final g in o.focus(limit: 2)) g.id], ['late', 'behind']);
      // Paused goals are left out of the average (like the orbit's score).
      final expected = [0.7, 0.1, 0.0, 0.01, 0.2, 1.0];
      expect(o.averageProgress, closeTo(expected.reduce((a, b) => a + b) / expected.length, 1e-9));
      expect(o.loggedTodayCount, 1);
      expect(o.streak.current, 14);
      expect(o.streak.days.contains(20260908), isFalse, reason: "the deleted goal's log does not count");
      expect(o.byId('open')!.stats.pace, GoalPace.noDeadline);
    });

    test('usual amount, running totals and a day total', () {
      final row = goalRow('g', initial: 10, unit: 'pages');
      final g = GrowthGoal.of(row, [
        logRow('g', 5, day(-2)),
        logRow('g', 7, day(-1)),
        logRow('g', 3, DateTime(2026, 9, 27, 21)),
      ], today: today);
      expect(g.usualAmount, 3, reason: 'the amount entered last');
      expect(g.logs.first.amount, 3, reason: 'newest first');
      expect(g.runningTotals().values.toList()..sort(), [15, 22, 25]);
      expect(g.loggedOn(day(-1)), 10);
      final fresh = GrowthGoal.of(goalRow('h', unit: 'hours'), const [], today: today);
      expect(fresh.usualAmount, 0.5, reason: 'the first quick chip');
    });
  });
}
