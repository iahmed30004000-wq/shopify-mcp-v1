import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/money/budget/budget.dart';

import 'budget_fixtures.dart';

/// A pumped budget widget over an in-memory database.
class _Budget {
  _Budget(this.tester, this.db, this.fx);

  final WidgetTester tester;
  final MadarDatabase db;
  final ({SilentSoundService sound, BudgetHaptics haptics}) fx;

  Repositories get repos => Repositories(db);

  Future<BudgetItemRow?> item(String id) async =>
      await tester.runAsync<BudgetItemRow?>(() => repos.budgetItems.byId(id));
  Future<int> count() async => (await tester.runAsync(() => repos.budgetItems.count()))!;
  Future<Object?> kv(String key) async => await tester.runAsync<Object?>(() => repos.keyValues.getJson(key));

  /// Lets drift streams deliver and animations run.
  Future<void> settle([int frames = 24]) async {
    for (var i = 0; i < frames; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

Future<_Budget> _pump(
  WidgetTester tester, {
  Widget home = const BudgetScreen(),
  Locale locale = const Locale('en'),
  bool spending = false,
  List<BudgetNode>? nodes,
  bool reducedMotion = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(412, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final fx = installBudgetFx();
  final db = await openBudgetDatabase(tester);
  await tester.runAsync(() async {
    final repos = Repositories(db);
    await insertNodes(repos, nodes ?? specNodes());
    if (spending) await seedSpending(repos);
  });
  await tester.pumpWidget(
    budgetTestApp(
      home: home,
      overrides: budgetOverrides(db: db),
      locale: locale,
      reducedMotion: reducedMotion,
    ),
  );
  final b = _Budget(tester, db, fx);
  await b.settle(30);
  return b;
}

String _plain(String s) => BidiIsolate.strip(s);

Finder _textPlain(String s) => find.byWidgetPredicate((w) => w is Text && _plain(w.data ?? '') == s);

String _fieldText(WidgetTester tester, String key) =>
    _plain(tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text);

/// The tree row of [name] (not the legend entry of the same name).
Finder _row(String name) => find.ancestor(of: find.text(name), matching: find.byType(ActionableItem)).first;

/// Taps [finder] after scrolling it into view (sheets scroll).
Future<void> _tapVisible(_Budget b, Finder finder) async {
  await b.tester.ensureVisible(finder);
  await b.settle(4);
  await b.tester.tap(finder);
}

Future<void> _openItem(_Budget b, String name) async {
  await b.tester.ensureVisible(_row(name));
  await b.settle(4);
  await b.tester.tap(_row(name));
  await b.settle(20);
  expect(find.byType(BudgetItemSheet), findsOneWidget);
}

void main() {
  group('Plan tab', () {
    testWidgets('renders the tree, the total and a calm summary', (tester) async {
      final b = await _pump(tester);
      expect(_textPlain('350.000 JOD'), findsOneWidget);
      expect(find.text('Everything adds up'), findsOneWidget);
      for (final n in ['Home food', 'Proteins', 'Spices', 'Treats', 'Fruit & vegetables', 'Car fuel', 'Emergency']) {
        expect(find.text(n), findsWidgets, reason: n);
      }
      expect(find.byType(ReorderGrip), findsNWidgets(8));
      expect(b.fx.sound.played, isNot(contains(Sfx.error)));
    });

    testWidgets('typing an amount recalculates the percent live; save persists with undo', (tester) async {
      final b = await _pump(tester);
      await _openItem(b, 'Proteins');
      expect(_fieldText(tester, 'budget.sheet.amount'), '100');
      expect(_fieldText(tester, 'budget.sheet.percent'), '50');
      await tester.enterText(find.byKey(const ValueKey('budget.sheet.amount')), '80');
      await b.settle(6);
      expect(_fieldText(tester, 'budget.sheet.percent'), '40');
      // The preview warns about the parent at once.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && _plain(w.data ?? '') == 'Sub-items of Home food are 20.000 JOD short of it',
        ),
        findsOneWidget,
      );
      await _tapVisible(b, find.text('Save'));
      await b.settle();
      final row = await b.item('prot');
      expect((row!.mode, row.amountMilli), (BudgetMode.amount, 80000));
      expect(row.percent, closeTo(40, 1e-9));
      expect(find.text('Item saved'), findsOneWidget);
      expect(find.text('1 thing needs attention'), findsOneWidget);
      expect(b.fx.sound.played, contains(Sfx.complete));
      await tester.tap(find.text('Undo'));
      await b.settle();
      expect((await b.item('prot'))!.amountMilli, 100000);
      expect(find.text('Everything adds up'), findsOneWidget);
    });

    testWidgets('typing a percent recalculates the amount; switching mode keeps it', (tester) async {
      final b = await _pump(tester);
      await _openItem(b, 'Spices');
      await tester.enterText(find.byKey(const ValueKey('budget.sheet.percent')), '12.5');
      await b.settle(6);
      expect(_fieldText(tester, 'budget.sheet.amount'), '25');
      // Measured against the total instead: same amount, new percent.
      await _tapVisible(b, find.text('of the total'));
      await b.settle(6);
      expect(_fieldText(tester, 'budget.sheet.amount'), '25');
      expect(_fieldText(tester, 'budget.sheet.percent'), '7.14'); // 25 / 350 (Home food keeps its 200)
      await _tapVisible(b, find.text('Amount').first);
      await b.settle(6);
      expect(_fieldText(tester, 'budget.sheet.amount'), '25');
      await _tapVisible(b, find.text('Save'));
      await b.settle();
      final row = await b.item('spice');
      expect((row!.mode, row.amountMilli, row.percentOf), (BudgetMode.amount, 25000, PercentBase.total));
    });

    testWidgets('a new top-level item set as a share of the total', (tester) async {
      final b = await _pump(tester);
      await tester.tap(find.bySemanticsLabel('Add item'));
      await b.settle();
      expect(find.text('New item'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('budget.sheet.name')), 'Savings');
      await tester.enterText(find.byKey(const ValueKey('budget.sheet.percent')), '10');
      await b.settle(6);
      // T = 350 / 0.9; 10 % of it.
      expect(_fieldText(tester, 'budget.sheet.amount'), '38.889');
      await _tapVisible(b, find.text('Save'));
      await b.settle();
      expect(await b.count(), 9);
      final rows = await tester.runAsync(() => b.repos.budgetItems.getAll());
      final saved = rows!.firstWhere((r) => r.name == 'Savings');
      expect(
        (saved.mode, saved.percent, saved.percentOf, saved.parentId),
        (BudgetMode.percent, 10.0, PercentBase.total, null),
      );
      expect(_textPlain('388.889 JOD'), findsOneWidget);
    });

    testWidgets('an empty name cannot be saved', (tester) async {
      final b = await _pump(tester);
      await _openItem(b, 'Emergency');
      await tester.enterText(find.byKey(const ValueKey('budget.sheet.name')), '   ');
      await b.settle(4);
      await _tapVisible(b, find.text('Save'));
      await b.settle(6);
      expect(find.text('This field is required'), findsOneWidget);
      expect(b.fx.sound.played, contains(Sfx.error));
      expect((await b.item('emerg'))!.name, 'Emergency');
    });

    testWidgets('unsaved changes ask before the sheet closes', (tester) async {
      final b = await _pump(tester);
      await _openItem(b, 'Emergency');
      await tester.enterText(find.byKey(const ValueKey('budget.sheet.amount')), '45');
      await b.settle(4);
      await tester.binding.handlePopRoute();
      await b.settle(8);
      expect(find.text('Keep editing'), findsOneWidget);
      expect(b.fx.sound.played, contains(Sfx.notify));
      await tester.tap(find.text('Keep editing'));
      await b.settle(8);
      expect(find.byType(BudgetItemSheet), findsOneWidget);
      await tester.binding.handlePopRoute();
      await b.settle(8);
      await _tapVisible(b, find.text('Discard'));
      await b.settle();
      expect(find.byType(BudgetItemSheet), findsNothing);
      expect((await b.item('emerg'))!.amountMilli, 30000);
    });

    testWidgets('delete with its sub-items from the menu, then undo', (tester) async {
      final b = await _pump(tester);
      // delete() completes after its dissolve animation: pump meanwhile.
      unawaited(tester.state<ActionableItemState>(_row('Home food')).delete());
      await b.settle();
      expect(await b.count(), 3);
      expect(find.text('Deleted with 4 sub-items'), findsOneWidget);
      expect(_textPlain('150.000 JOD'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await b.settle();
      expect(await b.count(), 8);
      expect(_textPlain('350.000 JOD'), findsOneWidget);
    });

    testWidgets('delete from the item sheet', (tester) async {
      final b = await _pump(tester);
      await _openItem(b, 'Treats');
      await _tapVisible(b, find.text('Delete'));
      await b.settle();
      expect(await b.item('treat'), isNull);
      expect(find.text('Item deleted'), findsOneWidget);
      expect(find.text('1 thing needs attention'), findsOneWidget);
    });

    testWidgets('drag a grip to reorder within the group', (tester) async {
      final b = await _pump(tester);
      final grip = find.descendant(of: _row('Spices'), matching: find.byType(ReorderGrip));
      final gesture = await tester.startGesture(tester.getCenter(grip));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(0, -8));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await b.settle();
      final math = await tester.runAsync(() => BudgetRepository(b.repos).math());
      expect([for (final c in math!.childrenOf('food')) c.node.id], ['spice', 'prot', 'treat', 'fv']);
      expect(b.fx.sound.played, containsAll([Sfx.pickUp, Sfx.drop]));
    });

    testWidgets('move to another parent from the menu keeps the amount; undo', (tester) async {
      final b = await _pump(tester);
      unawaited(tester.state<ActionableItemState>(_row('Treats')).openMenu());
      await b.settle(12);
      await tester.tap(find.text('Move'));
      await b.settle(16);
      expect(find.byType(MoveSheet), findsOneWidget);
      await _tapVisible(b, find.descendant(of: find.byType(MoveSheet), matching: find.text('Car fuel')));
      await b.settle();
      final moved = await b.item('treat');
      expect((moved!.parentId, moved.mode, moved.amountMilli), ('fuel', BudgetMode.amount, 30000));
      expect(moved.percent, closeTo(30, 1e-9)); // 30 of Car fuel's 100
      expect(find.text('Moved'), findsOneWidget);
      // Home food is now 30 short, Car fuel 70 short; the total is unchanged.
      expect(find.text('2 things need attention'), findsOneWidget);
      expect(_textPlain('350.000\u00a0JOD'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await b.settle();
      expect((await b.item('treat'))!.parentId, 'food');
      expect(find.text('Everything adds up'), findsOneWidget);
    });

    testWidgets('add a sub-item as a percent of its parent from the menu', (tester) async {
      final b = await _pump(tester);
      unawaited(tester.state<ActionableItemState>(_row('Car fuel')).openMenu());
      await b.settle(12);
      await tester.tap(find.text('Add sub-item'));
      await b.settle(16);
      expect(find.byType(BudgetItemSheet), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('budget.sheet.name')), 'Commute');
      await tester.enterText(find.byKey(const ValueKey('budget.sheet.percent')), '60');
      await b.settle(6);
      expect(_fieldText(tester, 'budget.sheet.amount'), '60');
      await _tapVisible(b, find.text('Save'));
      await b.settle();
      final rows = await tester.runAsync(() => b.repos.budgetItems.getAll());
      final saved = rows!.firstWhere((r) => r.name == 'Commute');
      expect(
        (saved.parentId, saved.mode, saved.percent, saved.percentOf, saved.amountMilli),
        ('fuel', BudgetMode.percent, 60.0, PercentBase.parent, 60000),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && _plain(w.data ?? '') == 'Sub-items of Car fuel are 40.000\u00a0JOD short of it',
        ),
        findsOneWidget,
      );
      expect(_textPlain('350.000\u00a0JOD'), findsOneWidget);
    });

    testWidgets('add an item beside another lands right after it', (tester) async {
      final b = await _pump(tester);
      unawaited(tester.state<ActionableItemState>(_row('Spices')).openMenu());
      await b.settle(12);
      await tester.tap(find.text('Add item beside'));
      await b.settle(16);
      await tester.enterText(find.byKey(const ValueKey('budget.sheet.name')), 'Herbs');
      await tester.enterText(find.byKey(const ValueKey('budget.sheet.amount')), '5');
      await b.settle(6);
      expect(_fieldText(tester, 'budget.sheet.percent'), '2.5'); // 5 of Home food's 200
      await _tapVisible(b, find.text('Save'));
      await b.settle();
      final math = await tester.runAsync(() => BudgetRepository(b.repos).math());
      final names = [for (final c in math!.childrenOf('food')) c.node.name];
      expect(names, ['Proteins', 'Spices', 'Herbs', 'Treats', 'Fruit & vegetables']);
      expect(find.text('1 thing needs attention'), findsOneWidget);
    });

    testWidgets('weeks per month from the header chip', (tester) async {
      final b = await _pump(tester);
      await tester.tap(find.text('Weeks per month: 4'));
      await b.settle();
      expect(_textPlain('10.000\u00a0JOD a week = 40.000\u00a0JOD a month'), findsOneWidget);
      await tester.tap(find.text('4.345'));
      await b.settle(4);
      expect(_textPlain('10.000\u00a0JOD a week = 43.450\u00a0JOD a month'), findsOneWidget);
      await _tapVisible(b, find.text('Save'));
      await b.settle();
      expect(await b.kv(BudgetSettings.weeksPerMonthKey), 4.345);
      expect(_textPlain('351.725 JOD'), findsOneWidget);
      expect(find.text('Weeks per month: 4.345'), findsOneWidget);
    });

    testWidgets('warnings summary lists over-allocation and opens the item', (tester) async {
      final b = await _pump(
        tester,
        nodes: [for (final n in specNodes()) n.id == 'spice' ? n.copyWith(amountMilli: 40000) : n],
      );
      expect(find.text('1 thing needs attention'), findsOneWidget);
      final sentence = find.byWidgetPredicate(
        (w) => w is Text && _plain(w.data ?? '') == 'Sub-items of Home food exceed it by 20.000 JOD',
      );
      expect(sentence, findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Text && _plain(w.data ?? '') == 'Over by 20.000 JOD'), findsOneWidget);
      await tester.tap(sentence);
      await b.settle();
      expect(find.text('Edit item'), findsOneWidget);
      expect(_fieldText(tester, 'budget.sheet.amount'), '200');
    });
  });

  group('Spending tab', () {
    testWidgets('this month, the week, and back in time', (tester) async {
      final b = await _pump(tester, home: const BudgetScreen(initialTab: BudgetTab.spending), spending: true);
      expect(find.text('September 2026'), findsOneWidget);
      expect(_textPlain('243.650 JOD'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Text && _plain(w.data ?? '') == 'of 350.000 JOD'), findsOneWidget);
      expect(find.text('Day 29 of 30'), findsOneWidget);
      expect(find.text('Outside the budget'), findsOneWidget);
      expect(find.text('Over plan'), findsWidgets);
      await tester.tap(find.bySemanticsLabel('Previous period'));
      await b.settle();
      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('Finished period'), findsOneWidget);
      await tester.tap(find.text('Weekly'));
      await b.settle();
      expect(find.text('26 – Oct 2'), findsNothing);
      expect(find.text('Sep 26 – Oct 2'), findsOneWidget);
      expect(_textPlain('2.000 JOD'), findsWidgets);
      expect(find.text('Previous weeks'), findsOneWidget);
    });
  });

  group('Picker and card', () {
    testWidgets('BudgetPickerField picks an item and shows its path', (tester) async {
      String? picked = 'none';
      final b = await _pump(
        tester,
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => BudgetPickerField(
                value: picked == 'none' ? null : picked,
                onChanged: (id) => setState(() => picked = id),
              ),
            ),
          ),
        ),
        spending: true,
      );
      expect(find.text('Choose an item'), findsOneWidget);
      await tester.tap(find.byType(BudgetPickerField));
      await b.settle();
      expect(find.text('No budget item'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Text && _plain(w.data ?? '') == '12.500 JOD over'), findsOneWidget);
      await tester.tap(find.text('Spices'));
      await b.settle();
      expect(picked, 'spice');
      expect(find.text('Home food › Spices'), findsOneWidget);
      // Search keeps the path.
      await tester.tap(find.byType(BudgetPickerField));
      await b.settle();
      await tester.enterText(find.byType(TextField).last, 'fuel');
      await b.settle(6);
      expect(find.text('Car fuel'), findsOneWidget);
      expect(find.text('Proteins'), findsNothing);
      expect(find.text('No budget item'), findsNothing);
      await tester.tap(find.text('Car fuel'));
      await b.settle();
      expect(picked, 'fuel');
    });

    testWidgets('BudgetStatusCard: spent of plan, left and warnings', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        home: Scaffold(body: BudgetStatusCard(onTap: () => taps++)),
        spending: true,
      );
      expect(_textPlain('243.650 JOD'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Text && _plain(w.data ?? '') == '106.350 JOD left'), findsOneWidget);
      expect(find.text('1 warning'), findsOneWidget);
      expect(find.text("Wife's allowance"), findsOneWidget);
      await tester.tap(find.byType(BudgetStatusCard));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('BudgetStatusCard: empty budget invites planning (Arabic)', (tester) async {
      await _pump(
        tester,
        home: const Scaffold(body: BudgetStatusCard()),
        nodes: const [],
        locale: const Locale('ar'),
      );
      expect(find.text('خطّط ميزانيتك بالمبلغ أو بالنسبة'), findsOneWidget);
    });
  });

  // B1 (APK #15): the tab bodies used to pile up on each other.
  testWidgets('only the selected tab is in the tree', (tester) async {
    final b = await _pump(tester, spending: true);
    void only(String key) {
      for (final k in ['budget.plan', 'budget.spending']) {
        expect(find.byKey(ValueKey(k)), k == key ? findsOneWidget : findsNothing, reason: 'expected only $key');
      }
    }

    only('budget.plan');
    await tester.tap(find.bySemanticsLabel('Spending').first);
    await b.settle(30);
    only('budget.spending');
    await tester.tap(find.bySemanticsLabel('Plan').first);
    await b.settle(30);
    only('budget.plan');
  });

  testWidgets('reduced motion and Arabic render the plan', (tester) async {
    await _pump(tester, locale: const Locale('ar'), reducedMotion: true);
    expect(find.text('الخطة الشهرية'), findsOneWidget);
    expect(_textPlain('٣٥٠٫٠٠٠ د.أ'), findsOneWidget);
    expect(find.text('أسابيع الشهر: ٤'), findsOneWidget);
  });
}
