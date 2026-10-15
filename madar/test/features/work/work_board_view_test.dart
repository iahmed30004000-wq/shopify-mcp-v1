// The Work world's board: it is the world's own main view (the switcher,
// the overview behind one button), a card carries his own label, the move
// between columns is reachable without a drag (what TalkBack offers), and
// a column and a card can be added from the board itself.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/interaction/sheets/field_inputs.dart' show SwatchPicker;
import 'package:madar/features/work/work.dart';

import '../../helpers/screenshot_harness.dart' show loadMadarFonts;
import 'work_harness.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

Future<BoardCardRow> _card(WorkTestEnv env, String id) async => (await env.repos.boardCards.byId(id))!;

/// `ensureVisible` can park a control under the frosted app bar, where the
/// tap lands on the header instead: nudge the sheet until it is pressable.
Future<Finder> _pressable(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await workFrames(tester, 4);
  for (var i = 0; i < 8 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 60));
    await workFrames(tester, 4);
  }
  expect(target.hitTestable(), findsOneWidget, reason: 'the control never cleared the header');
  return target.hitTestable();
}

/// The card node that carries the menu's actions.
Finder _cardItem(Finder title) => find.ancestor(of: title, matching: find.byType(ActionableItem)).first;

/// Does what a screen reader does: fires the custom action labelled
/// [label] on the node of [finder]. It fails when no such action is
/// offered, which is the point – a drag is out of TalkBack's reach, so
/// this is the only way a card changes column there.
void _performCustomAction(WidgetTester tester, Finder finder, String label) {
  final node = tester.getSemantics(finder);
  final ids = node.getSemanticsData().customSemanticsActionIds ?? const <int>[];
  final labels = {
    for (final id in ids)
      if (CustomSemanticsAction.getAction(id)?.label case final String name) name: id,
  };
  expect(labels.keys, contains(label), reason: 'TalkBack is offered: ${labels.keys}');
  // ignore: deprecated_member_use – the tree the test's semantics live in.
  tester.binding.pipelineOwner.semanticsOwner!.performAction(node.id, SemanticsAction.customAction, labels[label]!);
}

void main() {
  group('the board is the Work world', () {
    testWidgets('AR: the world opens on his board, and the switcher changes it', (tester) async {
      late WorkSeed s;
      await pumpWorkApp(tester, home: const WorkScreen(), beforePump: (env) async => s = await seedWork(env));
      // The kanban itself, not a list of boards.
      expect(find.text(_ar.workColTodo), findsWidgets);
      expect(find.text('تأكيد طلبات الدفع عند الاستلام'), findsOneWidget);
      // The switcher names every board he has, the first one selected.
      expect(find.text(s.store.name), findsWidgets);
      expect(find.text(s.team.name), findsWidgets);
      // The strip scrolls: his later boards sit off the left edge in Arabic.
      final chip = find.text(s.team.name).first;
      await tester.ensureVisible(chip);
      await settleWork(tester, rounds: 2);
      await tester.tap(chip);
      await settleWork(tester);
      expect(find.text('جدولة جولات الغد'), findsOneWidget);
      expect(find.text('تأكيد طلبات الدفع عند الاستلام'), findsNothing);
    });

    testWidgets('AR: the overview holds the Top 3, the boards and the projects; a tile opens its board', (tester) async {
      late WorkSeed s;
      await pumpWorkApp(tester, home: const WorkScreen(), beforePump: (env) async => s = await seedWork(env));
      await tester.tap(find.byIcon(Icons.space_dashboard_rounded));
      await settleWork(tester);
      expect(find.text(_ar.workTop3Title), findsWidgets);
      expect(find.text(_ar.workBoards), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
      await settleWork(tester);
      expect(find.text(_ar.workProjects), findsOneWidget);
      // Back to a board from its own tile, in place.
      await tester.tap(await _pressable(tester, find.text(s.team.name).first));
      await settleWork(tester);
      expect(find.text('جدولة جولات الغد'), findsOneWidget);
      expect(find.text(_ar.workBoards), findsNothing);
    });

    testWidgets('fresh install: no board, so the world opens on its warm empty state', (tester) async {
      await pumpWorkApp(tester, home: const WorkScreen());
      expect(find.text(_ar.workBoardsEmptyTitle), findsOneWidget);
      expect(find.text(_ar.workTop3Empty), findsOneWidget);
      expect(find.byIcon(Icons.space_dashboard_rounded), findsNothing);
    });

    testWidgets('an empty board says so in every column and offers a card', (tester) async {
      late BoardRow b;
      await pumpWorkApp(
        tester,
        home: const WorkScreen(),
        beforePump: (env) async => b = await env.service.createBoard(name: 'لوحة فاضية'),
      );
      expect(find.text(b.name), findsWidgets);
      expect(find.text(_ar.workColumnEmpty), findsWidgets);
      expect(find.text(_ar.workAddCard), findsWidgets);
    });
  });

  group('a card between columns, without a drag', () {
    testWidgets('AR: the move TalkBack offers moves the card, and it undoes', (tester) async {
      late WorkSeed s;
      final handle = tester.ensureSemantics();
      final env = await pumpWorkApp(
        tester,
        home: Builder(builder: (_) => BoardScreen(boardId: s.store.id)),
        beforePump: (env) async => s = await seedWork(env),
      );
      _performCustomAction(tester, _cardItem(find.text('تصوير المنتجات الجديدة')), _ar.workMoveToColumn);
      await workFrames(tester, 16);
      await tester.tap(find.text(_ar.workColDoing).last);
      await workFrames(tester, 16);
      expect((await tester.runAsync(() => _card(env, s.cards[2].id)))!.columnId, 'doing');
      // And it undoes, like every other write in the app.
      expect(find.text(_ar.actionUndo), findsWidgets);
      await tester.tap(find.text(_ar.actionUndo).first);
      await settleWork(tester);
      expect((await tester.runAsync(() => _card(env, s.cards[2].id)))!.columnId, 'todo');
      handle.dispose();
    });

    testWidgets('EN: the same path in English finishes the card in the done column', (tester) async {
      late WorkSeed s;
      final handle = tester.ensureSemantics();
      final env = await pumpWorkApp(
        tester,
        locale: const Locale('en'),
        home: Builder(builder: (_) => BoardScreen(boardId: s.store.id)),
        beforePump: (env) async => s = await seedWork(env, lang: 'en'),
      );
      _performCustomAction(tester, _cardItem(find.text('Shoot the new products')), _en.workMoveToColumn);
      await workFrames(tester, 16);
      await tester.tap(find.text('Done').last);
      await workFrames(tester, 16);
      expect((await tester.runAsync(() => _card(env, s.cards[2].id)))!.columnId, 'done');
      handle.dispose();
    });
  });

  group('a card carries his own label', () {
    testWidgets('AR: a label with a colour is saved and shown on the card', (tester) async {
      late WorkSeed s;
      final env = await pumpWorkApp(
        tester,
        home: Builder(builder: (_) => BoardScreen(boardId: s.store.id)),
        beforePump: (env) async => s = await seedWork(env),
      );
      await tester.tap(find.text('تصوير المنتجات الجديدة'));
      await workFrames(tester, 16);
      final field = find.ancestor(of: find.text(_ar.kanbanCardTagHint), matching: find.byType(TextField)).first;
      await tester.enterText(await _pressable(tester, field), 'مرتجعات');
      await workFrames(tester, 8);
      // The colour belongs to the label: the swatches appear with one.
      final swatches = find.descendant(of: find.byType(SwatchPicker), matching: find.byType(AnimatedContainer));
      await tester.tap(await _pressable(tester, swatches.at(1)));
      await workFrames(tester, 8);
      await tester.tap(await _pressable(tester, find.text(_ar.workSave)));
      await workFrames(tester, 20);
      final saved = await tester.runAsync(() => _card(env, s.cards[2].id));
      expect(saved!.tag, 'مرتجعات');
      expect(saved.tagColor, CuratedPalette.colors[1].toARGB32());
      expect(find.text('مرتجعات'), findsOneWidget, reason: 'the label shows on the card');
      // Clearing it (and undoing that) is in the service's own tests.
    });

    testWidgets('EN: a new card is created with its label, its due date and its prayer window', (tester) async {
      late WorkSeed s;
      final env = await pumpWorkApp(
        tester,
        locale: const Locale('en'),
        home: Builder(builder: (_) => BoardScreen(boardId: s.store.id)),
        beforePump: (env) async => s = await seedWork(env, lang: 'en'),
      );
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await workFrames(tester, 16);
      await tester.enterText(
        find.ancestor(of: find.text(_en.workCardTitleHint), matching: find.byType(TextField)).first,
        'Chase the Libya courier',
      );
      await workFrames(tester, 8);
      await tester.enterText(
        await _pressable(tester, find.ancestor(of: find.text(_en.kanbanCardTagHint), matching: find.byType(TextField)).first),
        'Returns',
      );
      await workFrames(tester, 8);
      // Due tomorrow, and placed in the Dhuhr window of today.
      await tester.tap(await _pressable(tester, find.text(_en.workTomorrow).last));
      await workFrames(tester, 8);
      await tester.tap(await _pressable(tester, find.text(_en.windowDhuhr).last));
      await workFrames(tester, 8);
      await tester.tap(await _pressable(tester, find.text(_en.workCreate)));
      await workFrames(tester, 20);
      final rows = await tester.runAsync(() => env.repos.boardCards.getAll());
      final made = rows!.firstWhere((c) => c.title == 'Chase the Libya courier');
      expect(made.tag, 'Returns');
      expect(made.tagColor, isNotNull);
      expect(made.dueDate, workTestToday.add(const Duration(days: 1)));
      expect(made.window, PrayerWindow.dhuhr);
      expect(find.text('Returns'), findsOneWidget);
      // Placed means the home panel's own task exists for that window.
      final tasks = await tester.runAsync(() => env.repos.tasks.getAll(where: (t) => t.cardId.equals(made.id)));
      expect(tasks!.single.window, PrayerWindow.dhuhr);
      expect(tasks.single.date, workTestToday);
    });
  });

  testWidgets('a column added from the board keeps the done column last', (tester) async {
    late WorkSeed s;
    final env = await pumpWorkApp(
      tester,
      home: Builder(builder: (_) => BoardScreen(boardId: s.store.id)),
      beforePump: (env) async => s = await seedWork(env),
    );
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await workFrames(tester, 16);
    await tester.tap(find.text(_ar.workEditColumns).last);
    await workFrames(tester, 16);
    await tester.enterText(
      await _pressable(tester, find.ancestor(of: find.text(_ar.workColumnName), matching: find.byType(TextField)).first),
      'للمراجعة',
    );
    await workFrames(tester, 8);
    await tester.tap(await _pressable(tester, find.bySemanticsLabel(_ar.workAddColumn)));
    await workFrames(tester, 20);
    final board = await tester.runAsync(() => env.service.board(s.store.id));
    expect(board!.columns.map((c) => c.label), contains('للمراجعة'));
    expect(board.columns.last.isDone, isTrue);
  });

  // Last: the real fonts (the test font's square glyphs say nothing about
  // what fits), which then stay loaded in this isolate.
  group('text scale 1.3', () {
    setUpAll(loadMadarFonts);

    testWidgets('the board, its cards and his label are shown whole', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      late WorkSeed s;
      await pumpWorkApp(
        tester,
        locale: const Locale('en'),
        home: const WorkScreen(),
        beforePump: (env) async {
          s = await seedWork(env, lang: 'en');
          final c = (await env.repos.boardCards.byId(s.cards[1].id))!;
          await env.service.editCard(c, CardDraft.of(c).copyWith(tag: 'Returns', tagColor: 0xFF4F7BD9));
        },
      );
      final cut = [
        for (final e in find.byType(RichText).evaluate())
          if (e.renderObject case final RenderParagraph p
              when p.didExceedMaxLines || p.size.height + 0.5 < p.getMinIntrinsicHeight(p.size.width))
            p.text.toPlainText(),
      ];
      expect(cut, isEmpty);
    });
  });
}
