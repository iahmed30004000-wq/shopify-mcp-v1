import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/home/domain/home_tasks.dart';
import 'package:madar/features/work/data/work_models.dart';
import 'package:madar/features/work/data/work_service.dart';
import 'package:madar/features/work/domain/board_columns.dart';
import 'package:madar/features/work/domain/top3.dart';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';

MadarDatabase testDatabase() =>
    MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late WorkService work;
  late HomeTasksService home;
  var now = DateTime(2026, 9, 29, 10);
  final today = DateTime(2026, 9, 29);

  setUp(() {
    now = DateTime(2026, 9, 29, 10);
    db = testDatabase();
    repos = Repositories(db);
    work = WorkService(repos, clock: () => now);
    home = HomeTasksService(repos, clock: () => now);
  });

  tearDown(() => db.close());

  Future<BoardCardRow> card(String id) async => (await repos.boardCards.byId(id))!;
  Future<List<TaskRow>> linked(String cardId) => repos.tasks.getAll(where: (t) => t.cardId.equals(cardId));
  Future<List<ActivityRow>> activity(String kind) => repos.activityLog.getAll(where: (a) => a.kind.equals(kind));
  Future<List<String>> column(String boardId, String col) async => [
    for (final c in await repos.boardCards.getAll(where: (c) => c.boardId.equals(boardId) & c.columnId.equals(col))) c.title,
  ];

  group('boards and columns', () {
    test('a new board has To-do / Doing / Done', () async {
      final b = await work.createBoard(name: ' Store A ', country: 'JO', color: 0xFF3366CC);
      final wb = (await work.board(b.id))!;
      expect(wb.name, 'Store A');
      expect(wb.columns, BoardColumns.defaults());
      expect(wb.doneColumnId, 'done');
    });

    test('marking another column done moves the cards along (and back on undo)', () async {
      final b = await work.createBoard(name: 'B');
      final a = await work.addCard(b.id, const CardDraft(title: 'a', columnId: 'doing'));
      final z = await work.addCard(b.id, const CardDraft(title: 'z', columnId: 'done'));
      final wb = (await work.board(b.id))!;
      final undo = await work.editColumns(b.id, BoardColumns.markDone(wb.columns, 'doing'));
      final after = (await work.board(b.id))!;
      expect(after.columns.map((c) => c.id), ['todo', 'done', 'c4']);
      expect((await card(a.id)).columnId, 'done');
      expect((await card(z.id)).columnId, 'c4');
      await undo();
      expect((await work.board(b.id))!.columns, BoardColumns.defaults());
      expect((await card(a.id)).columnId, 'doing');
      expect((await card(z.id)).columnId, 'done');
    });

    test('deleting a column sends its cards to the neighbour', () async {
      final b = await work.createBoard(name: 'B');
      final a = await work.addCard(b.id, const CardDraft(title: 'a', columnId: 'doing'));
      await work.editColumns(b.id, BoardColumns.remove(BoardColumns.defaults(), 'doing'));
      expect((await card(a.id)).columnId, 'todo');
    });

    test('archive is a flag in the key-value store; delete cascades with undo', () async {
      final b = await work.createBoard(name: 'B');
      final c = await work.addCard(b.id, const CardDraft(title: 'c', window: PrayerWindow.asr));
      final unarchive = await work.setArchived(b.id, true);
      expect(await work.archivedIds(), {b.id});
      await unarchive();
      expect(await work.archivedIds(), isEmpty);
      final undo = await work.deleteBoard(b.id);
      expect(await repos.boards.getAll(), isEmpty);
      expect(await repos.boardCards.getAll(), isEmpty);
      expect(await linked(c.id), isEmpty);
      await undo();
      expect((await repos.boards.getAll()).single.name, 'B');
      expect((await linked(c.id)).single.window, PrayerWindow.asr);
    });
  });

  group('column moves', () {
    test('reorder within a column and move between columns', () async {
      final b = await work.createBoard(name: 'B');
      final x = await work.addCard(b.id, const CardDraft(title: 'x'));
      final y = await work.addCard(b.id, const CardDraft(title: 'y'));
      final z = await work.addCard(b.id, const CardDraft(title: 'z'));
      await work.moveCard(z.id, 'todo', orderInColumn: [z.id, x.id, y.id]);
      expect(await column(b.id, 'todo'), ['z', 'x', 'y']);
      final (undo, r) = await work.moveCard(x.id, 'doing', orderInColumn: [x.id]);
      expect(r.completed, isFalse);
      expect(await column(b.id, 'todo'), ['z', 'y']);
      expect(await column(b.id, 'doing'), ['x']);
      await undo();
      expect(await column(b.id, 'todo'), ['z', 'x', 'y']);
    });

    test('entering the done column logs work activity; leaving or undo removes it', () async {
      final b = await work.createBoard(name: 'B');
      final x = await work.addCard(b.id, const CardDraft(title: 'x'));
      final (undo, r) = await work.moveCard(x.id, 'done');
      expect(r.completed, isTrue);
      final logged = await activity(WorkService.cardDoneKind);
      expect(logged.single.planetKey, 'work');
      expect(logged.single.refTable, 'board_cards');
      expect(logged.single.refId, x.id);
      await undo();
      expect(await activity(WorkService.cardDoneKind), isEmpty);
      await work.toggleCardDone(x.id);
      final (_, reopened) = await work.toggleCardDone(x.id);
      expect(reopened.reopened, isTrue);
      expect((await card(x.id)).columnId, 'todo');
      expect(await activity(WorkService.cardDoneKind), isEmpty);
    });

    test('move to another board keeps the column id when it exists', () async {
      final a = await work.createBoard(name: 'A');
      final b = await work.createBoard(name: 'B', columns: const [BoardColumn(id: 'todo', label: 'Inbox')]);
      final x = await work.addCard(a.id, const CardDraft(title: 'x', columnId: 'doing'));
      final undo = await work.moveCardToBoard(x.id, b.id);
      expect((await card(x.id)).boardId, b.id);
      expect((await card(x.id)).columnId, 'todo');
      await undo();
      expect((await card(x.id)).boardId, a.id);
      expect((await card(x.id)).columnId, 'doing');
    });

    test('duplicate and delete with undo', () async {
      final b = await work.createBoard(name: 'B');
      final x = await work.addCard(b.id, const CardDraft(title: 'x', isTop3: true));
      final (copy, undoCopy) = await work.duplicateCard(x.id);
      expect(copy.isTop3, isFalse);
      expect(await column(b.id, 'todo'), ['x', 'x']);
      await undoCopy();
      final undo = await work.deleteCard(x.id);
      expect(await repos.boardCards.getAll(), isEmpty);
      await undo();
      expect((await card(x.id)).isTop3, isTrue);
    });
  });

  group('card ⇄ task sync', () {
    late BoardRow b;
    late BoardCardRow c;
    setUp(() async {
      b = await work.createBoard(name: 'B');
      c = await work.addCard(b.id, const CardDraft(title: 'Call supplier'));
    });

    test('placing a card in a window creates the task the home panel lists', () async {
      await work.placeCard(c, PrayerWindow.dhuhr);
      final t = (await linked(c.id)).single;
      expect(t.window, PrayerWindow.dhuhr);
      expect(t.date, today);
      expect(t.planetKey, 'work');
      expect(t.title, 'Call supplier');
      expect((await card(c.id)).window, PrayerWindow.dhuhr);
      expect((await home.tasksIn(PrayerWindow.dhuhr, today)).map((t) => t.cardId), [c.id]);
    });

    test('moving the window moves the task; clearing it removes the open task', () async {
      await work.placeCard(c, PrayerWindow.dhuhr);
      final undo = await work.placeCard(await card(c.id), PrayerWindow.isha, day: DateTime(2026, 9, 30));
      final t = (await linked(c.id)).single;
      expect(t.window, PrayerWindow.isha);
      expect(t.date, DateTime(2026, 9, 30));
      await undo();
      expect((await linked(c.id)).single.window, PrayerWindow.dhuhr);
      await work.placeCard(await card(c.id), null);
      expect(await linked(c.id), isEmpty);
      expect((await card(c.id)).window, isNull);
    });

    test('completing the card completes the task (and reopening reopens it)', () async {
      await work.placeCard(c, PrayerWindow.asr);
      await work.moveCard(c.id, 'done');
      final t = (await linked(c.id)).single;
      expect(t.done, isTrue);
      expect(t.doneAt, now);
      await work.moveCard(c.id, 'doing');
      expect((await linked(c.id)).single.done, isFalse);
    });

    test('completing the task from home completes the card', () async {
      await work.placeCard(c, PrayerWindow.asr);
      final t = (await linked(c.id)).single;
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await home.toggleDone(t);
      expect(await work.syncAll(), 1);
      expect((await card(c.id)).columnId, 'done');
      expect(await work.syncAll(), 0, reason: 'settled');
      // Reopened at home: back to the first open column.
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await home.toggleDone((await linked(c.id)).single);
      await work.syncAll();
      expect((await card(c.id)).columnId, 'todo');
    });

    test('moving the task to another window at home moves the card', () async {
      await work.placeCard(c, PrayerWindow.asr);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await home.move((await linked(c.id)).single, PrayerWindow.maghrib);
      await work.syncAll();
      expect((await card(c.id)).window, PrayerWindow.maghrib);
    });

    test('deleting the task at home unplaces the card', () async {
      await work.placeCard(c, PrayerWindow.asr);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final undo = await home.delete((await linked(c.id)).single);
      await work.syncAll();
      expect((await card(c.id)).window, isNull);
      await undo();
      await work.syncAll();
      expect((await card(c.id)).window, PrayerWindow.asr);
    });

    test('editing the card renames the task and can move it', () async {
      await work.placeCard(c, PrayerWindow.asr);
      await work.editCard(
        await card(c.id),
        CardDraft.of(await card(c.id)).copyWith(title: 'Call the supplier', window: PrayerWindow.fajr, assignee: ' Sara '),
      );
      final t = (await linked(c.id)).single;
      expect(t.title, 'Call the supplier');
      expect(t.window, PrayerWindow.fajr);
      expect((await card(c.id)).assignee, 'Sara');
    });

    test('the runner reacts to table changes', () async {
      final runner = WorkSyncRunner(work)..start();
      addTearDown(runner.dispose);
      await work.placeCard(c, PrayerWindow.asr);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await home.toggleDone((await linked(c.id)).single);
      for (var i = 0; i < 20 && (await card(c.id)).columnId != 'done'; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect((await card(c.id)).columnId, 'done');
    });
  });

  group('Top 3', () {
    test('at most three across cards and tasks', () async {
      final b = await work.createBoard(name: 'B');
      final cards = [for (final t in ['a', 'b', 'c', 'd']) await work.addCard(b.id, CardDraft(title: t))];
      final task = await home.add(title: 'task', window: PrayerWindow.duha, date: today, planetKey: 'money');
      expect((await work.setCardTop3(cards[0].id, true)).$1, Top3AddResult.added);
      expect((await work.setTaskTop3(task.id, true)).$1, Top3AddResult.added);
      expect((await work.setCardTop3(cards[1].id, true)).$1, Top3AddResult.added);
      final (full, noUndo) = await work.setCardTop3(cards[2].id, true);
      expect(full, Top3AddResult.full);
      expect(noUndo, isNull);
      expect((await card(cards[2].id)).isTop3, isFalse);
      expect((await work.setCardTop3(cards[0].id, true)).$1, Top3AddResult.alreadyIn);
      final state = await work.top3State();
      expect(state.items.map((i) => i.title), ['a', 'b', 'task']);
      // Swap one out.
      final undo = await work.swapTop3(state.items[1], FocusItem(kind: FocusKind.card, id: cards[3].id, title: 'd'));
      expect((await work.top3State()).items.map((i) => i.title), ['a', 'd', 'task']);
      await undo();
      expect((await work.top3State()).items.map((i) => i.title), ['a', 'b', 'task']);
    });

    test('a placed card counts once and flags its task too', () async {
      final b = await work.createBoard(name: 'B');
      final x = await work.addCard(b.id, const CardDraft(title: 'x', window: PrayerWindow.asr));
      await work.setTaskTop3((await linked(x.id)).single.id, true);
      expect((await card(x.id)).isTop3, isTrue);
      expect((await linked(x.id)).single.isTop3, isTrue);
      final s = await work.top3State();
      expect(s.items.single.kind, FocusKind.card);
      expect(s.items.single.window, PrayerWindow.asr);
    });

    test('next morning: carry over keeps the unfinished, moves dated tasks to today', () async {
      final b = await work.createBoard(name: 'B');
      final x = await work.addCard(b.id, const CardDraft(title: 'x', window: PrayerWindow.asr));
      final y = await work.addCard(b.id, const CardDraft(title: 'y'));
      final t = await home.add(title: 't', window: PrayerWindow.isha, date: today, planetKey: 'work');
      expect((await linked(x.id)).single.date, today);
      await work.setCardTop3(x.id, true);
      await work.setCardTop3(y.id, true);
      await work.setTaskTop3(t.id, true);
      await work.toggleCardDone(y.id);
      expect((await work.top3State()).doneCount, 1);

      now = DateTime(2026, 9, 30, 6, 30);
      var s = await work.top3State();
      expect(s.needsCarryOver, isTrue);
      expect(s.leftovers.map((i) => i.title), ['x', 't']);
      final undo = await work.carryOverTop3();
      s = await work.top3State();
      expect(s.needsCarryOver, isFalse);
      expect(s.items.map((i) => i.title), ['x', 't']);
      expect((await repos.tasks.byId(t.id))!.date, DateTime(2026, 9, 30));
      // The carried card stays in its window, now on today's home list.
      expect((await linked(x.id)).single.date, DateTime(2026, 9, 30));
      expect((await card(x.id)).window, PrayerWindow.asr);
      expect((await card(y.id)).isTop3, isFalse);
      await undo();
      expect((await work.top3State()).needsCarryOver, isTrue);
      expect((await linked(x.id)).single.date, today);
      await work.startFreshTop3();
      s = await work.top3State();
      expect(s.items, isEmpty);
      expect(s.needsCarryOver, isFalse);
    });

    test('flagging on a new day without answering carries the leftovers over', () async {
      final b = await work.createBoard(name: 'B');
      final x = await work.addCard(b.id, const CardDraft(title: 'x'));
      final y = await work.addCard(b.id, const CardDraft(title: 'y'));
      await work.setCardTop3(x.id, true);
      now = DateTime(2026, 9, 30, 8);
      await work.setCardTop3(y.id, true);
      expect((await work.top3State()).items.map((i) => i.title), ['x', 'y']);
    });

    test('completing a focus task logs like the home panel', () async {
      final t = await home.add(title: 't', window: PrayerWindow.isha, date: today, planetKey: 'work');
      final (undo, done) = await work.toggleFocusDone(FocusItem(kind: FocusKind.task, id: t.id, title: 't'));
      expect(done, isTrue);
      expect((await activity(HomeTasksService.doneKind)).single.refId, t.id);
      await undo();
      expect(await activity(HomeTasksService.doneKind), isEmpty);
      expect((await repos.tasks.byId(t.id))!.done, isFalse);
    });
  });

  group('projects', () {
    test('checklist to 100 % reports completion and logs on the project planet', () async {
      final p = await work.createProject(const ProjectDraft(name: 'Launch', planetKey: 'growth'));
      expect(p.planetKey, 'growth');
      final a = await work.addItem(p.id, 'a');
      final b = await work.addItem(p.id, 'b', dueDate: DateTime(2026, 10, 1, 15));
      expect(b.dueDate, DateTime(2026, 10, 1));
      final (first, _) = await work.toggleItem(a);
      expect(first.completedProject, isFalse);
      expect(first.progress.done, 1);
      final (second, undo) = await work.toggleItem(b);
      expect(second.completedProject, isTrue);
      expect(second.progress.complete, isTrue);
      final logged = await activity(WorkService.itemDoneKind);
      expect(logged.map((e) => e.planetKey).toSet(), {'growth'});
      expect(logged.length, 2);
      await undo();
      expect((await repos.projectItems.byId(b.id))!.done, isFalse);
      expect((await activity(WorkService.itemDoneKind)).length, 1);
    });

    test('default planet is work; status done logs once; delete keeps tasks unlinked', () async {
      final p = await work.createProject(const ProjectDraft(name: 'P', planetKey: ''));
      expect(p.planetKey, 'work');
      final t = await work.addProjectTask(p, title: 'Brief the team', window: PrayerWindow.duha, date: today);
      expect(t.projectId, p.id);
      expect(t.planetKey, 'work');
      final undoStatus = await work.setProjectStatus(p.id, ProjectStatus.done);
      expect((await activity(WorkService.projectDoneKind)).single.planetKey, 'work');
      await undoStatus();
      expect(await activity(WorkService.projectDoneKind), isEmpty);
      await work.addItem(p.id, 'x');
      final undo = await work.deleteProject(p.id);
      expect(await repos.projects.getAll(), isEmpty);
      expect(await repos.projectItems.getAll(), isEmpty);
      expect((await repos.tasks.byId(t.id))!.projectId, isNull);
      await undo();
      expect((await repos.tasks.byId(t.id))!.projectId, p.id);
      expect((await repos.projectItems.getAll()).single.body, 'x');
    });

    test('duplicate copies the checklist unticked', () async {
      final p = await work.createProject(const ProjectDraft(name: 'P'));
      final a = await work.addItem(p.id, 'a');
      await work.toggleItem(a);
      final (copy, undo) = await work.duplicateProject(p.id);
      final items = await repos.projectItems.getAll(where: (i) => i.projectId.equals(copy.id));
      expect(items.single.body, 'a');
      expect(items.single.done, isFalse);
      await undo();
      expect(await repos.projects.getAll(), hasLength(1));
    });
  });
}
