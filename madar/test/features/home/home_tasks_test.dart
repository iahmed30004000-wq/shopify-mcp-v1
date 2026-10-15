import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/home/domain/home_tasks.dart';
import 'package:madar/features/home/domain/prayer_day.dart';

import '../../helpers/test_app.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late HomeTasksService service;
  final now = DateTime(2026, 9, 27, 13, 10);
  final today = DateTime(2026, 9, 27);

  setUp(() async {
    db = testDatabase(seed: false);
    repos = Repositories(db);
    service = HomeTasksService(repos, clock: () => now);
  });

  tearDown(() => db.close());

  TaskRow task({String title = 'x', DateTime? date, bool done = false, DateTime? doneAt}) => TaskRow(
    id: 'id',
    createdAt: now,
    updatedAt: now,
    sortOrder: 0,
    title: title,
    window: PrayerWindow.dhuhr,
    date: date,
    done: done,
    doneAt: doneAt,
    priority: 0,
    isTop3: false,
  );

  group('TaskDayFilter', () {
    test('dated tasks show on their day only', () {
      expect(TaskDayFilter.includes(task(date: today), today), isTrue);
      expect(TaskDayFilter.includes(task(date: today.add(const Duration(days: 1))), today), isFalse);
    });

    test('undated tasks show while open, and on the day they were done', () {
      expect(TaskDayFilter.includes(task(), today), isTrue);
      expect(TaskDayFilter.includes(task(done: true, doneAt: now), today), isTrue);
      expect(TaskDayFilter.includes(task(done: true, doneAt: now.subtract(const Duration(days: 2))), today), isFalse);
    });

    test('a task done at 00:30 stays on the prayer day still on screen (after Isha)', () {
      final day = DateTime(2026, 9, 28);
      final at = DateTime(2026, 9, 29, 0, 30);
      final t = task(done: true, doneAt: at);
      expect(TaskDayFilter.includes(t, day, times: PrayerDayTimes.placeholder), isTrue);
      expect(TaskDayFilter.includes(t, DateTime(2026, 9, 29), times: PrayerDayTimes.placeholder), isFalse);
      // after Fajr it belongs to the new day
      final later = task(done: true, doneAt: DateTime(2026, 9, 29, 7));
      expect(TaskDayFilter.includes(later, DateTime(2026, 9, 29), times: PrayerDayTimes.placeholder), isTrue);
    });
  });

  test('add + watchWindow lists the window’s tasks of the day in order', () async {
    await service.add(title: ' Call Mum ', window: PrayerWindow.dhuhr, date: now, planetKey: 'family');
    await service.add(title: 'Read', window: PrayerWindow.dhuhr, date: today);
    await service.add(title: 'Other window', window: PrayerWindow.asr, date: today);
    await service.add(title: 'Tomorrow', window: PrayerWindow.dhuhr, date: today.add(const Duration(days: 1)));
    final rows = await service.watchWindow(PrayerWindow.dhuhr, today).first;
    expect(rows.map((r) => r.title), ['Call Mum', 'Read']);
    expect(rows.first.date, today);
    expect(rows.first.planetKey, 'family');
  });

  test('toggleDone completes with an activity entry and undoes both', () async {
    final t = await service.add(title: 'Walk', window: PrayerWindow.dhuhr, date: today, planetKey: 'body');
    final undo = await service.toggleDone(t);
    final done = (await repos.tasks.byId(t.id))!;
    expect(done.done, isTrue);
    expect(done.doneAt, now);
    final log = await repos.activity.since(today);
    expect(log.single.kind, HomeTasksService.doneKind);
    expect(log.single.planetKey, 'body');
    await undo();
    expect((await repos.tasks.byId(t.id))!.done, isFalse);
    expect(await repos.activity.since(today), isEmpty);
  });

  test('toggleDone on a done task reopens it (and undo completes it again)', () async {
    final t = await service.add(title: 'Walk', window: PrayerWindow.dhuhr, date: today, planetKey: 'body');
    await service.toggleDone(t);
    final done = (await repos.tasks.byId(t.id))!;
    final undo = await service.toggleDone(done);
    expect((await repos.tasks.byId(t.id))!.done, isFalse);
    expect(await repos.activity.since(today), isEmpty);
    await undo();
    expect((await repos.tasks.byId(t.id))!.done, isTrue);
    expect(await repos.activity.since(today), hasLength(1));
  });

  test('delete removes reminders too, undo restores everything in place', () async {
    final a = await service.add(title: 'A', window: PrayerWindow.dhuhr, date: today);
    final b = await service.add(title: 'B', window: PrayerWindow.dhuhr, date: today);
    await service.setReminder(b, const {'kind': 'daily', 'time': '09:00'});
    final undo = await service.delete(b);
    expect(await repos.tasks.byId(b.id), isNull);
    expect(await service.reminderOf(b.id), isNull);
    await undo();
    final rows = await service.tasksIn(PrayerWindow.dhuhr, today);
    expect(rows.map((r) => r.id), [a.id, b.id]);
    expect(await service.reminderOf(b.id), {'kind': 'daily', 'time': '09:00'});
  });

  test('duplicate lands right after the original, open; undo removes the copy', () async {
    final a = await service.add(title: 'A', window: PrayerWindow.dhuhr, date: today);
    await service.add(title: 'B', window: PrayerWindow.dhuhr, date: today);
    await repos.tasks.setColumns(a.id, {'done': true, 'doneAt': now});
    final (copy, undo) = await service.duplicate((await repos.tasks.byId(a.id))!);
    expect(copy.done, isFalse);
    expect((await service.tasksIn(PrayerWindow.dhuhr, today)).map((r) => r.title), ['A', 'A', 'B']);
    await undo();
    expect((await service.tasksIn(PrayerWindow.dhuhr, today)).map((r) => r.title), ['A', 'B']);
  });

  test('move changes the window and undo restores window and position', () async {
    final a = await service.add(title: 'A', window: PrayerWindow.dhuhr, date: today);
    await service.add(title: 'B', window: PrayerWindow.dhuhr, date: today);
    final undo = await service.move(a, PrayerWindow.maghrib);
    expect((await service.tasksIn(PrayerWindow.maghrib, today)).single.id, a.id);
    await undo();
    expect((await service.tasksIn(PrayerWindow.dhuhr, today)).map((r) => r.title), ['A', 'B']);
  });

  test('edit saves fields and undo restores them', () async {
    final a = await service.add(title: 'A', window: PrayerWindow.dhuhr, date: today, notes: 'n');
    final undo = await service.edit(
      a,
      title: 'A2',
      window: PrayerWindow.asr,
      date: today,
      notes: '  ',
      planetKey: 'work',
    );
    final edited = (await repos.tasks.byId(a.id))!;
    expect(edited.title, 'A2');
    expect(edited.window, PrayerWindow.asr);
    expect(edited.notes, isNull);
    expect(edited.planetKey, 'work');
    await undo();
    final back = (await repos.tasks.byId(a.id))!;
    expect(back.title, 'A');
    expect(back.window, PrayerWindow.dhuhr);
    expect(back.notes, 'n');
    expect(back.planetKey, isNull);
  });

  test('setReminder replaces, removes (empty rule) and undoes', () async {
    final a = await service.add(title: 'A', window: PrayerWindow.dhuhr, date: today);
    await service.setReminder(a, const {'kind': 'daily', 'time': '09:00'});
    final undo = await service.setReminder(a, const {'kind': 'prayer', 'window': 'asr', 'offsetMin': 10});
    expect((await service.reminderOf(a.id))!['kind'], 'prayer');
    expect(await repos.reminders.count(), 1);
    await undo();
    expect((await service.reminderOf(a.id))!['kind'], 'daily');
    final remove = await service.setReminder(a, const {});
    expect(await service.reminderOf(a.id), isNull);
    await remove();
    expect((await service.reminderOf(a.id))!['kind'], 'daily');
    final reminders = await service.watchReminders().first;
    expect(reminders[a.id]!['time'], '09:00');
  });

  test('reorder persists a drag within a window', () async {
    final a = await service.add(title: 'A', window: PrayerWindow.dhuhr, date: today);
    final b = await service.add(title: 'B', window: PrayerWindow.dhuhr, date: today);
    final c = await service.add(title: 'C', window: PrayerWindow.dhuhr, date: today);
    await service.reorder([c.id, a.id, b.id]);
    expect((await service.tasksIn(PrayerWindow.dhuhr, today)).map((r) => r.title), ['C', 'A', 'B']);
  });

  test('undated imported tasks appear in their window', () async {
    await repos.tasks.insert(TasksCompanion.insert(title: 'Imported', window: const Value(PrayerWindow.isha)));
    expect((await service.tasksIn(PrayerWindow.isha, today)).single.title, 'Imported');
  });
}
