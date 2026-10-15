import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import 'prayer_day.dart';

/// Reverts a change made by [HomeTasksService].
typedef TaskUndo = Future<void> Function();

/// Records a completion for a planet (the orbit's completion hook: logs the
/// activity and pulses the planet).
typedef CompletionRecorder = Future<void> Function(
  String planetKey,
  String kind,
  String? refTable,
  String? refId,
  DateTime at,
);

/// Which tasks belong to a prayer window's list on a given day. Pure.
abstract final class TaskDayFilter {
  /// A task shows on [day] when it is dated that day, or when it is undated
  /// (inbox / imported without a day) and either still open or completed
  /// on [day] – the prayer-anchored day when [times] are given (a task
  /// swiped done at 00:30 belongs to the "after Isha" list still on screen,
  /// not to tomorrow).
  static bool includes(TaskRow task, DateTime day, {PrayerDayTimes? times}) {
    final d = PrayerDayTimes.dateOnly(day);
    final date = task.date;
    if (date != null) return _sameDay(date, d);
    if (!task.done) return true;
    final doneAt = task.doneAt;
    if (doneAt == null) return false;
    if (times != null) return _sameDay(times.prayerDayOf(doneAt.toLocal()), d);
    return _sameDay(doneAt, d);
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final l = a.toLocal();
    return l.year == b.year && l.month == b.month && l.day == b.day;
  }
}

/// Task operations of the home screen – completion, duplication, moving
/// between windows, reminders, deletion – each returning a [TaskUndo] that
/// restores the exact previous state (row, position and side effects such as
/// activity entries and reminders). No Flutter dependencies; the widgets
/// turn undos into undo toasts.
class HomeTasksService {
  HomeTasksService(this.repos, {DateTime Function()? clock, CompletionRecorder? recordCompletion})
    : _clock = clock ?? DateTime.now,
      _record = recordCompletion;

  final Repositories repos;
  final DateTime Function() _clock;
  final CompletionRecorder? _record;

  static const String table = 'tasks';

  /// Activity kind written when a task is completed.
  static const String doneKind = 'task.done';

  EntityRepository<$TasksTable, TaskRow> get _tasks => repos.tasks;
  EntityRepository<$RemindersTable, ReminderRow> get _reminders => repos.reminders;

  // ------------------------------------------------------------------ reads

  /// Live, ordered tasks of [window] on [day] (see [TaskDayFilter]).
  /// One world's tasks on [day] (its planet page's module), in the order of
  /// the day's windows, then the user's order within a window.
  Stream<List<TaskRow>> watchPlanet(String planetKey, DateTime day, {PrayerDayTimes? times}) =>
      _tasks.watchAll(where: (t) => t.planetKey.equals(planetKey)).map((rows) {
        final out = [
          for (final r in rows)
            if (TaskDayFilter.includes(r, day, times: times)) r,
        ];
        int rank(PrayerWindow w) {
          final i = PrayerDayTimes.windows.indexOf(w);
          return i < 0 ? PrayerDayTimes.windows.length : i;
        }

        out.sort((a, b) {
          final c = rank(a.window).compareTo(rank(b.window));
          return c != 0 ? c : a.sortOrder.compareTo(b.sortOrder);
        });
        return out;
      });

  Stream<List<TaskRow>> watchWindow(PrayerWindow window, DateTime day, {PrayerDayTimes? times}) => _tasks
      .watchAll(where: (t) => t.window.equalsValue(window))
      .map(
        (rows) => [
          for (final r in rows)
            if (TaskDayFilter.includes(r, day, times: times)) r,
        ],
      );

  /// Tasks of [window] on [day], once.
  Future<List<TaskRow>> tasksIn(PrayerWindow window, DateTime day, {PrayerDayTimes? times}) async {
    final rows = await _tasks.getAll(where: (t) => t.window.equalsValue(window));
    return [
      for (final r in rows)
        if (TaskDayFilter.includes(r, day, times: times)) r,
    ];
  }

  /// Live map task id → reminder rule for every task reminder.
  Stream<Map<String, Map<String, Object?>>> watchReminders() => _reminders
      .watchAll(where: (r) => r.ownerTable.equals(table))
      .map(
        (rows) => {
          for (final r in rows)
            if (r.enabled) r.ownerId: r.rule,
        },
      );

  // ----------------------------------------------------------------- writes

  /// Creates a task at the end of its window's list.
  Future<TaskRow> add({
    required String title,
    required PrayerWindow window,
    DateTime? date,
    String? notes,
    String? planetKey,
  }) {
    return _tasks.insert(
      TasksCompanion.insert(
        title: title.trim(),
        window: Value(window),
        date: Value(date == null ? null : PrayerDayTimes.dateOnly(date)),
        notes: Value(_blankToNull(notes)),
        planetKey: Value(_blankToNull(planetKey)),
      ),
    );
  }

  /// Applies edited fields. Changing the window moves the task to the end of
  /// the new window's list.
  Future<TaskUndo> edit(
    TaskRow task, {
    required String title,
    required PrayerWindow window,
    DateTime? date,
    String? notes,
    String? planetKey,
  }) async {
    await _tasks.setColumns(task.id, {
      'title': title.trim(),
      'window': window,
      'date': date == null ? null : PrayerDayTimes.dateOnly(date),
      'notes': _blankToNull(notes),
      'planetKey': _blankToNull(planetKey),
    }, moveToEnd: window != task.window);
    return () => _restoreFields(task);
  }

  /// Marks [task] done (or open again when it is already done) and records
  /// the completion for the planet balance / Neglect Radar.
  Future<TaskUndo> toggleDone(TaskRow task) async {
    if (task.done) {
      final removed = await repos.activity.removeFor(refTable: table, refId: task.id, kind: doneKind);
      await _tasks.setColumns(task.id, {'done': false, 'doneAt': null});
      return () async {
        await _tasks.setColumns(task.id, {'done': true, 'doneAt': task.doneAt});
        await repos.activityLog.restoreAll(removed);
      };
    }
    final now = _clock();
    await _tasks.setColumns(task.id, {'done': true, 'doneAt': now});
    final planet = task.planetKey;
    if (planet != null) {
      final record = _record;
      if (record != null) {
        await record(planet, doneKind, table, task.id, now);
      } else {
        await repos.activity.log(planetKey: planet, kind: doneKind, refTable: table, refId: task.id, at: now);
      }
    }
    return () async {
      await _tasks.setColumns(task.id, {'done': false, 'doneAt': null});
      await repos.activity.removeFor(refTable: table, refId: task.id, kind: doneKind);
    };
  }

  /// Copies [task] (open, right after the original).
  Future<(TaskRow, TaskUndo)> duplicate(TaskRow task) async {
    final copy = await _tasks.duplicate(task.id, overrides: const {'done': false, 'doneAt': null});
    return (copy, () async => _tasks.delete(copy.id).then((_) {}));
  }

  /// Moves [task] to [window] (same day), at the end of that list.
  Future<TaskUndo> move(TaskRow task, PrayerWindow window) async {
    await _tasks.setColumn(task.id, 'window', window, moveToEnd: true);
    return () => _tasks.setColumns(task.id, {'window': task.window, 'sortOrder': task.sortOrder});
  }

  /// Persists a drag-and-drop order of one list.
  Future<void> reorder(List<String> idsInOrder) => _tasks.reorder(idsInOrder);

  /// Deletes [task] together with its reminders and completion activity.
  Future<TaskUndo> delete(TaskRow task) async {
    final reminders = await _reminders.deleteWhere((r) => r.ownerTable.equals(table) & r.ownerId.equals(task.id));
    final activity = await repos.activity.removeFor(refTable: table, refId: task.id);
    final row = await _tasks.delete(task.id);
    return () async {
      if (row != null) await _tasks.restore(row);
      await _reminders.restoreAll(reminders);
      await repos.activityLog.restoreAll(activity);
    };
  }

  /// The reminder rule of [taskId], if any.
  Future<Map<String, Object?>?> reminderOf(String taskId) async {
    final rows = await _reminders.getAll(where: (r) => r.ownerTable.equals(table) & r.ownerId.equals(taskId));
    return rows.isEmpty ? null : rows.first.rule;
  }

  /// Sets (or, with an empty/null [rule], removes) the reminder of [task].
  Future<TaskUndo> setReminder(TaskRow task, Map<String, Object?>? rule) async {
    final previous = await _reminders.deleteWhere((r) => r.ownerTable.equals(table) & r.ownerId.equals(task.id));
    ReminderRow? created;
    if (rule != null && rule.isNotEmpty) {
      created = await _reminders.insert(
        RemindersCompanion.insert(ownerTable: table, ownerId: task.id, title: Value(task.title), rule: rule),
      );
    }
    return () async {
      if (created != null) await _reminders.delete(created.id);
      await _reminders.restoreAll(previous);
    };
  }

  Future<void> _restoreFields(TaskRow task) => _tasks.setColumns(task.id, {
    'title': task.title,
    'window': task.window,
    'date': task.date,
    'notes': task.notes,
    'planetKey': task.planetKey,
    'sortOrder': task.sortOrder,
  });

  static String? _blankToNull(String? s) {
    final v = s?.trim();
    return v == null || v.isEmpty ? null : v;
  }
}
