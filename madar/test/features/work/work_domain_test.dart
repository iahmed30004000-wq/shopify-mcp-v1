import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/work/domain/board_columns.dart';
import 'package:madar/features/work/domain/card_filter.dart';
import 'package:madar/features/work/domain/card_task_sync.dart';
import 'package:madar/features/work/domain/countdown.dart';
import 'package:madar/features/work/domain/kanban.dart';
import 'package:madar/features/work/domain/project_math.dart';
import 'package:madar/features/work/domain/top3.dart';
import 'package:madar/features/work/domain/work_days.dart';

void main() {
  final today = DateTime(2026, 9, 29);

  group('BoardColumns', () {
    test('parse is tolerant and falls back to the defaults', () {
      expect(BoardColumns.parse(null), BoardColumns.defaults());
      expect(BoardColumns.parse(const ['x', 3]), BoardColumns.defaults());
      final cols = BoardColumns.parse(const [
        {'id': 'a', 'label': 'Inbox'},
        {'id': 'a', 'label': 'dup'},
        {'id': '', 'label': 'blank'},
        {'id': 'done'},
      ]);
      expect(cols.map((c) => c.id), ['a', 'done']);
      expect(cols.last.label, '');
      expect(BoardColumns.encode(cols), [
        {'id': 'a', 'label': 'Inbox'},
        {'id': 'done', 'label': ''},
      ]);
    });

    test('default labels are recognised by label, renamed ones are not', () {
      final d = BoardColumns.defaults();
      expect(d.map(BoardColumns.defaultKindOf), [
        DefaultColumnKind.todo,
        DefaultColumnKind.doing,
        DefaultColumnKind.done,
      ]);
      expect(BoardColumns.defaultKindOf(const BoardColumn(id: 'c9', label: 'done')), DefaultColumnKind.done);
      expect(BoardColumns.defaultKindOf(const BoardColumn(id: 'todo', label: 'Backlog')), isNull);
      expect(BoardColumns.defaultKindOf(const BoardColumn(id: 'doing', label: '')), DefaultColumnKind.doing);
    });

    test('neighbours, first open column and resolve', () {
      final d = BoardColumns.defaults();
      expect(BoardColumns.nextId(d, 'todo'), 'doing');
      expect(BoardColumns.nextId(d, 'done'), isNull);
      expect(BoardColumns.previousId(d, 'todo'), isNull);
      expect(BoardColumns.previousId(d, 'done'), 'doing');
      expect(BoardColumns.firstOpenId(d), 'todo');
      expect(BoardColumns.resolve(d, 'gone'), 'todo');
      const onlyDone = [BoardColumn(id: 'done', label: 'Done')];
      expect(BoardColumns.firstOpenId(onlyDone), 'done');
    });

    test('add goes before a trailing done column, respects the cap', () {
      final e = BoardColumns.add(BoardColumns.defaults(), '  Review  ');
      expect(e.columns.map((c) => c.label), ['To-do', 'Doing', 'Review', 'Done']);
      expect(e.columns[2].id, 'c4');
      expect(e.remap, isEmpty);
      expect(BoardColumns.add(BoardColumns.defaults(), '   ').columns.length, 3);
      var cols = BoardColumns.defaults();
      for (var i = 0; i < 20; i++) {
        cols = BoardColumns.add(cols, 'x$i').columns;
      }
      expect(cols.length, BoardColumns.maxColumns);
      expect(cols.map((c) => c.id).toSet().length, cols.length, reason: 'ids stay unique');
    });

    test('rename, reorder', () {
      final r = BoardColumns.rename(BoardColumns.defaults(), 'doing', 'In progress');
      expect(r.columns[1], const BoardColumn(id: 'doing', label: 'In progress'));
      final o = BoardColumns.reorder(BoardColumns.defaults(), ['done', 'nope', 'todo']);
      expect(o.columns.map((c) => c.id), ['done', 'todo', 'doing']);
    });

    test('remove sends the cards to the neighbour, never removes the last', () {
      final e = BoardColumns.remove(BoardColumns.defaults(), 'doing');
      expect(e.columns.map((c) => c.id), ['todo', 'done']);
      expect(e.remap, {'doing': 'todo'});
      expect(BoardColumns.remove(BoardColumns.defaults(), 'todo').remap, {'todo': 'doing'});
      expect(BoardColumns.remove(BoardColumns.defaults(), 'todo', moveCardsTo: 'done').remap, {'todo': 'done'});
      const one = [BoardColumn(id: 'todo', label: 'x')];
      expect(BoardColumns.remove(one, 'todo').columns, one);
    });

    test('markDone re-keys the column and moves both columns\' cards along', () {
      final e = BoardColumns.markDone(BoardColumns.defaults(), 'doing');
      expect(e.columns.map((c) => c.id), ['todo', 'done', 'c4']);
      expect(e.columns.map((c) => c.label), ['To-do', 'Doing', 'Done']);
      expect(e.remap, {'done': 'c4', 'doing': 'done'});
      // Applied simultaneously: a card in the old done column does not end up in 'done' again.
      expect(BoardColumns.remapped(e.remap, 'done'), 'c4');
      expect(BoardColumns.remapped(e.remap, 'doing'), 'done');
      expect(BoardColumns.remapped(e.remap, 'todo'), 'todo');

      final none = BoardColumns.markDone(BoardColumns.defaults(), null);
      expect(BoardColumns.hasDone(none.columns), isFalse);
      expect(none.remap, {'done': 'c4'});
      expect(BoardColumns.markDone(BoardColumns.defaults(), 'done').remap, isEmpty);
    });
  });

  group('KanbanMath', () {
    test('insertion index by midpoints', () {
      expect(KanbanMath.insertionIndex(5, [10, 50, 90]), 0);
      expect(KanbanMath.insertionIndex(49, [10, 50, 90]), 1);
      expect(KanbanMath.insertionIndex(200, [10, 50, 90]), 3);
      expect(KanbanMath.insertionIndex(0, []), 0);
    });

    test('apply moves within and between columns', () {
      final orders = {
        'todo': ['a', 'b', 'c'],
        'doing': ['d'],
      };
      expect(KanbanMath.apply(orders, const CardMove(cardId: 'a', columnId: 'todo', index: 2))['todo'], ['b', 'c', 'a']);
      final between = KanbanMath.apply(orders, const CardMove(cardId: 'b', columnId: 'doing', index: 0));
      expect(between['todo'], ['a', 'c']);
      expect(between['doing'], ['b', 'd']);
      final newCol = KanbanMath.apply(orders, const CardMove(cardId: 'c', columnId: 'done', index: 9));
      expect(newCol['done'], ['c']);
      expect(orders['todo'], ['a', 'b', 'c'], reason: 'input untouched');
      expect(KanbanMath.isNoop('todo', 1, const CardMove(cardId: 'b', columnId: 'todo', index: 1)), isTrue);
    });

    test('RTL drag order: the first column is under the right edge', () {
      // Viewport 400 wide, columns 300 wide, 16 leading padding, not scrolled.
      int at(double dx, {required bool rtl, double scroll = 0}) => KanbanMath.columnAt(
        dx,
        viewportWidth: 400,
        extent: 300,
        scrollOffset: scroll,
        count: 3,
        rtl: rtl,
        leading: 16,
      );
      expect(at(390, rtl: true), 0);
      expect(at(60, rtl: true), 1);
      expect(at(10, rtl: false), 0);
      expect(at(390, rtl: false), 1);
      // Scrolled to the end: in RTL the last column is on the left.
      expect(at(20, rtl: true, scroll: 532), 2);
      expect(at(380, rtl: false, scroll: 532), 2);
      expect(KanbanMath.visualOrder(['todo', 'doing', 'done'], rtl: true), ['done', 'doing', 'todo']);
      expect(KanbanMath.visualOrder(['todo', 'doing', 'done'], rtl: false), ['todo', 'doing', 'done']);
    });

    test('swipe towards the next column moves forward in either direction', () {
      final cols = BoardColumns.defaults();
      expect(KanbanMath.swipeTarget(cols, 'doing', SwipeSide.left, rtl: true), 'done');
      expect(KanbanMath.swipeTarget(cols, 'doing', SwipeSide.right, rtl: true), 'todo');
      expect(KanbanMath.swipeTarget(cols, 'doing', SwipeSide.right, rtl: false), 'done');
      expect(KanbanMath.swipeTarget(cols, 'todo', SwipeSide.left, rtl: false), isNull);
      expect(KanbanMath.isForward(SwipeSide.left, rtl: true), isTrue);
    });

    test('auto-scroll ramps up at the edges only', () {
      expect(KanbanMath.autoScrollSpeed(200, start: 0, end: 400), 0);
      expect(KanbanMath.autoScrollSpeed(0, start: 0, end: 400), -900);
      expect(KanbanMath.autoScrollSpeed(400, start: 0, end: 400), 900);
      final mid = KanbanMath.autoScrollSpeed(372, start: 0, end: 400);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(900));
      expect(KanbanMath.autoScrollSpeed(5, start: 0, end: 80), 0);
    });
  });

  group('CardTaskSync', () {
    final t0 = DateTime(2026, 9, 29, 9);
    final later = t0.add(const Duration(minutes: 5));
    CardState card({String column = 'todo', PrayerWindow? window = PrayerWindow.dhuhr, DateTime? at, String title = 'Call supplier', bool top3 = false, String? doneCol = 'done'}) =>
        CardState(
          id: 'c',
          title: title,
          columnId: column,
          window: window,
          isTop3: top3,
          updatedAt: at ?? t0,
          doneColumnId: doneCol,
          openColumnId: 'todo',
        );
    LinkedTaskState task({bool done = false, PrayerWindow window = PrayerWindow.dhuhr, DateTime? at, String title = 'Call supplier', bool top3 = false}) =>
        LinkedTaskState(id: 't', title: title, window: window, done: done, isTop3: top3, updatedAt: at ?? t0);

    test('in step: nothing to do', () {
      expect(CardTaskSync.reconcile(card(), task()).isEmpty, isTrue);
      expect(CardTaskSync.reconcile(card(window: null), null).isEmpty, isTrue);
    });

    test('completing the task (home) completes the card', () {
      final p = CardTaskSync.reconcile(card(), task(done: true, at: later));
      expect(p.card, {'columnId': 'done'});
      expect(p.task, isEmpty);
      expect(p.cardCompleted, isTrue);
    });

    test('completing the card completes the task', () {
      final p = CardTaskSync.reconcile(card(column: 'done', at: later), task());
      expect(p.task, {'done': true});
      expect(p.card, isEmpty);
    });

    test('reopening the task reopens the card into the first open column', () {
      final p = CardTaskSync.reconcile(card(column: 'done'), task(at: later));
      expect(p.card, {'columnId': 'todo'});
      expect(p.cardReopened, isTrue);
    });

    test('moving the task to another window moves the card', () {
      final p = CardTaskSync.reconcile(card(), task(window: PrayerWindow.maghrib, at: later));
      expect(p.card, {'window': PrayerWindow.maghrib});
    });

    test('a newer card wins on window, title and Top 3', () {
      final p = CardTaskSync.reconcile(card(window: PrayerWindow.isha, title: 'New', top3: true, at: later), task());
      expect(p.task, {'window': PrayerWindow.isha, 'title': 'New', 'isTop3': true});
    });

    test('ties go to the task', () {
      final p = CardTaskSync.reconcile(card(), task(done: true));
      expect(p.card['columnId'], 'done');
    });

    test('a deleted task takes the card out of its window', () {
      expect(CardTaskSync.reconcile(card(), null).card, {'window': null});
    });

    test('a task pointing at an unplaced card (undone delete, import) places it again', () {
      expect(CardTaskSync.reconcile(card(window: null, at: later), task()).card, {'window': PrayerWindow.dhuhr});
      expect(CardTaskSync.reconcile(card(window: null), task(at: later)).card, {'window': PrayerWindow.dhuhr});
    });

    test('a board without a done column never reopens a finished task', () {
      expect(CardTaskSync.reconcile(card(doneCol: null, at: later), task(done: true)).task, isEmpty);
      expect(CardTaskSync.reconcile(card(doneCol: null), task(done: true, at: later)).card, isEmpty);
    });

    test('primary: open first, then the latest day', () {
      final a = LinkedTaskState(id: 'a', title: 'x', window: PrayerWindow.fajr, done: true, updatedAt: later, date: DateTime(2026, 9, 30));
      final b = LinkedTaskState(id: 'b', title: 'x', window: PrayerWindow.fajr, done: false, updatedAt: t0, date: DateTime(2026, 9, 28));
      final c = LinkedTaskState(id: 'c', title: 'x', window: PrayerWindow.fajr, done: false, updatedAt: t0, date: DateTime(2026, 9, 29));
      expect(CardTaskSync.primary([a, b, c])!.id, 'c');
      expect(CardTaskSync.primary(<LinkedTaskState>[]), isNull);
    });
  });

  group('Top3Rules', () {
    FocusItem item(String id, {bool done = false, bool flagged = true, FocusKind kind = FocusKind.card, DateTime? date, int sort = 0}) =>
        FocusItem(kind: kind, id: id, title: id, done: done, flagged: flagged, date: date, sortKey: sort);

    test('today: flagged items in order, at most three', () {
      final s = Top3Rules.evaluate(
        flagged: [item('b', sort: 2), item('a', sort: 1), item('c', sort: 3), item('d', sort: 4)],
        storedDay: today,
        today: today,
      );
      expect(s.items.map((i) => i.id), ['a', 'b', 'c']);
      expect(s.isFull, isTrue);
      expect(s.needsCarryOver, isFalse);
      expect(s.openSlots, 0);
    });

    test('limit: a fourth is refused, an existing one is already in', () {
      final s = Top3Rules.evaluate(flagged: [item('a'), item('b'), item('c')], storedDay: today, today: today);
      expect(Top3Rules.canAdd(s, item('d', flagged: false)), Top3AddResult.full);
      expect(Top3Rules.canAdd(s, item('a')), Top3AddResult.alreadyIn);
      final two = Top3Rules.evaluate(flagged: [item('a'), item('b', done: true)], storedDay: today, today: today);
      expect(Top3Rules.canAdd(two, item('d', flagged: false)), Top3AddResult.added);
      expect(two.doneCount, 1);
      expect(two.allDone, isFalse);
    });

    test('next morning: unfinished items ask to be carried over', () {
      final yesterday = WorkDays.add(today, -1);
      final s = Top3Rules.evaluate(
        flagged: [
          item('a', done: true),
          item('t', kind: FocusKind.task, date: yesterday),
          item('b'),
        ],
        storedDay: yesterday,
        today: today,
      );
      expect(s.items, isEmpty);
      expect(s.needsCarryOver, isTrue);
      expect(s.leftovers.map((i) => i.id), ['b', 't']);
      expect(s.staleDone.map((i) => i.id), ['a']);

      final carry = Top3Rules.carryOver(s);
      expect(carry.unflag.map((i) => i.id), ['a']);
      expect(carry.redate.map((i) => i.id), ['t']);

      final fresh = Top3Rules.startFresh(s);
      expect(fresh.unflag.map((i) => i.id).toSet(), {'a', 'b', 't'});
      expect(fresh.redate, isEmpty);
    });

    test('all finished yesterday: settled silently', () {
      final s = Top3Rules.evaluate(flagged: [item('a', done: true)], storedDay: WorkDays.add(today, -3), today: today);
      expect(s.needsCarryOver, isFalse);
      expect(s.needsRollover, isTrue);
      expect(Top3Rules.silent(s).unflag.map((i) => i.id), ['a']);
    });

    test('flags without a stored day count as today\'s', () {
      final s = Top3Rules.evaluate(flagged: [item('a')], storedDay: null, today: today);
      expect(s.items.single.id, 'a');
      expect(s.needsRollover, isFalse);
    });

    test('candidates: open, unflagged, relevant today, urgent first', () {
      final all = [
        FocusItem(kind: FocusKind.card, id: 'later', title: 'x', dueDate: WorkDays.add(today, 5)),
        FocusItem(kind: FocusKind.card, id: 'late', title: 'x', dueDate: WorkDays.add(today, -2)),
        FocusItem(kind: FocusKind.task, id: 'tomorrowTask', title: 'x', date: WorkDays.add(today, 1)),
        FocusItem(kind: FocusKind.task, id: 'todayTask', title: 'x', date: today),
        const FocusItem(kind: FocusKind.card, id: 'done', title: 'x', done: true),
        const FocusItem(kind: FocusKind.card, id: 'in', title: 'x', flagged: true),
        const FocusItem(kind: FocusKind.card, id: 'placed', title: 'x', window: PrayerWindow.asr),
      ];
      expect(Top3Rules.candidates(all, today).map((i) => i.id), ['late', 'todayTask', 'placed', 'later']);
    });
  });

  group('Countdown', () {
    test('calendar-day maths', () {
      expect(Countdown.of(null, today), Countdown.none);
      expect(Countdown.of(DateTime(2026, 10, 11), today).days, 12);
      expect(Countdown.of(DateTime(2026, 10, 11), today).kind, CountdownKind.days);
      expect(Countdown.of(DateTime(2026, 9, 29, 23, 59), today).kind, CountdownKind.today);
      expect(Countdown.of(DateTime(2026, 9, 30), today).kind, CountdownKind.tomorrow);
      final late = Countdown.of(DateTime(2026, 9, 26), today);
      expect(late.kind, CountdownKind.overdue);
      expect(late.days, 3);
      expect(late.isOverdue, isTrue);
      expect(Countdown.of(DateTime(2026, 10, 3), today).isSoon(), isTrue);
      expect(Countdown.of(DateTime(2026, 10, 30), today).isSoon(), isFalse);
    });

    test('across a month and a DST change', () {
      // Jordan / Europe DST changes happen in late October / late March.
      expect(Countdown.of(DateTime(2026, 11, 1), DateTime(2026, 10, 20)).days, 12);
      expect(Countdown.of(DateTime(2027, 4, 1), DateTime(2027, 3, 20)).days, 12);
      expect(Countdown.of(DateTime(2027, 1, 2), DateTime(2026, 12, 31)).days, 2);
    });

    test('elapsed share of the time to the deadline', () {
      expect(Countdown.elapsed(DateTime(2026, 9, 19), DateTime(2026, 10, 9), today), closeTo(0.5, 1e-9));
      expect(Countdown.elapsed(DateTime(2026, 9, 19), null, today), isNull);
      expect(Countdown.elapsed(DateTime(2026, 9, 19), DateTime(2026, 9, 20), today), 1);
    });

    test('due status', () {
      expect(DueRules.of(DateTime(2026, 9, 28), today), DueStatus.overdue);
      expect(DueRules.of(DateTime(2026, 9, 28), today, done: true), DueStatus.none);
      expect(DueRules.of(today, today), DueStatus.today);
      expect(DueRules.of(DateTime(2026, 9, 30), today), DueStatus.tomorrow);
      expect(DueRules.of(DateTime(2026, 10, 4), today), DueStatus.soon);
      expect(DueRules.of(DateTime(2026, 11, 4), today), DueStatus.later);
    });
  });

  group('assignees and filters', () {
    test('suggestions: folded duplicates, frequency and recency, prefix first', () {
      final now = DateTime(2026, 9, 29, 12);
      final uses = [
        AssigneeUse('أحمد', now.subtract(const Duration(days: 40))),
        AssigneeUse('احمد ', now.subtract(const Duration(days: 30))),
        AssigneeUse('Sara', now.subtract(const Duration(days: 1))),
        AssigneeUse('sara', now),
        AssigneeUse('Omar Ali', now.subtract(const Duration(days: 2))),
        AssigneeUse('  ', now),
      ];
      final all = AssigneeSuggestions.rank(uses, now: now);
      expect(all, ['sara', 'Omar Ali', 'احمد']);
      expect(AssigneeSuggestions.rank(uses, query: 'ali', now: now), ['Omar Ali']);
      expect(AssigneeSuggestions.rank(uses, query: 'أح', now: now), ['احمد']);
      expect(AssigneeSuggestions.rank(uses, query: 'sara', now: now), isEmpty, reason: 'exact match hides itself');
    });

    test('filter by assignee and due', () {
      const f = CardFilter(assignee: 'Sara');
      expect(f.matches(assignee: 'sara ', done: false, today: today), isTrue);
      expect(f.matches(assignee: 'Omar', done: false, today: today), isFalse);
      const none = CardFilter(assignee: CardFilter.unassigned);
      expect(none.matches(assignee: null, done: false, today: today), isTrue);
      expect(none.matches(assignee: 'x', done: false, today: today), isFalse);
      final overdue = CardFilter.all.withDue(DueFilter.overdue);
      expect(overdue.matches(dueDate: DateTime(2026, 9, 1), done: false, today: today), isTrue);
      expect(overdue.matches(dueDate: DateTime(2026, 9, 1), done: true, today: today), isFalse);
      final todayF = CardFilter.all.withDue(DueFilter.today);
      expect(todayF.matches(dueDate: today, done: false, today: today), isTrue);
      expect(todayF.matches(dueDate: DateTime(2026, 9, 30), done: false, today: today), isFalse);
      final week = CardFilter.all.withDue(DueFilter.week);
      expect(week.matches(dueDate: DateTime(2026, 10, 5), done: false, today: today), isTrue);
      expect(CardFilter.all.withDue(DueFilter.noDate).matches(done: false, today: today), isTrue);
      expect(CardFilter.all.isActive, isFalse);
    });
  });

  group('ProjectProgress', () {
    test('fraction and reaching 100 %', () {
      final p = ProjectProgress.of([true, false, true]);
      expect(p.done, 2);
      expect(p.fraction, closeTo(2 / 3, 1e-9));
      expect(p.complete, isFalse);
      final full = ProjectProgress.of([true, true, true]);
      expect(full.reachedFullFrom(p), isTrue);
      expect(full.reachedFullFrom(full), isFalse);
      expect(ProjectProgress.empty.fraction, 0);
      expect(ProjectProgress.empty.complete, isFalse);
      expect(ProjectRules.planetOf(null), 'work');
      expect(ProjectRules.planetOf(' family '), 'family');
    });
  });
}
