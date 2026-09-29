// Visual critic pass for the budget: renders the real screens with the real
// fonts and shaders and writes PNGs to madar/screenshots/phase5/budget/.
//
//   flutter test --tags screenshot test/features/money/budget/budget_screenshot_test.dart
@Tags(['screenshot'])
@Timeout(Duration(minutes: 20))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/money/budget/budget.dart';

import '../../../helpers/screenshot_harness.dart';
import 'budget_fixtures.dart';

const _dir = 'phase5/budget';

/// The spec budget with mixed modes: Proteins 50 % of Home food, Treats
/// 15 % of it, Emergency as a share of the total – same totals as the spec.
List<BudgetNode> mixedNodes() => [
  for (final n in specNodes())
    switch (n.id) {
      'prot' => n.copyWith(mode: BudgetMode.percent, percent: 50),
      'treat' => n.copyWith(mode: BudgetMode.percent, percent: 15),
      _ => n,
    },
];

/// Warning states: Spices raised to 40 (sub-items over Home food by 20),
/// Car fuel split into sub-items that leave 25 unallocated, a percent over
/// 100 % and a foreign-currency item.
List<BudgetNode> warningNodes() => [
  for (final n in mixedNodes()) n.id == 'spice' ? n.copyWith(amountMilli: 40000) : n,
  const BudgetNode(id: 'fuelA', parentId: 'fuel', name: 'Commute', amountMilli: 60000, sortOrder: 20),
  const BudgetNode(id: 'fuelB', parentId: 'fuel', name: 'Trips', amountMilli: 15000, sortOrder: 21),
  const BudgetNode(id: 'subs', name: 'Subscriptions', amountMilli: 20000, currency: 'USD', sortOrder: 22),
];

const _warningNamesAr = {...specNamesAr, 'fuelA': 'مشاوير العمل', 'fuelB': 'رحلات', 'subs': 'اشتراكات'};

Future<MadarDatabase> _db(
  WidgetTester tester, {
  List<BudgetNode>? nodes,
  bool arabic = true,
  bool spending = true,
  Map<String, String>? names,
}) async {
  final db = await openBudgetDatabase(tester);
  await tester.runAsync(() async {
    final repos = Repositories(db);
    await insertNodes(repos, nodes ?? mixedNodes(), names: arabic ? (names ?? specNamesAr) : null);
    if (spending) {
      await seedSpending(repos);
    } else {
      await insertWallets(repos);
    }
  });
  return db;
}

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _scrollBy(WidgetTester tester, double dy) async {
  final list = find.byType(Scrollable).hitTestable().first;
  final state = tester.state<ScrollableState>(list);
  state.position.jumpTo((state.position.pixels + dy).clamp(0, state.position.maxScrollExtent));
  await _frames(tester, 16);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).hitTestable().first);
  await _frames(tester, 24);
}

void main() {
  const en = Locale('en');

  testWidgets('plan – Arabic, Lapis, mixed amount / percent', (tester) async {
    final db = await _db(tester);
    await captureScreen(
      tester,
      budgetTestApp(home: const BudgetScreen(), overrides: budgetOverrides(db: db)),
      '$_dir/plan_ar_lapis',
    );
  });

  testWidgets('plan – English, Pearl, mixed amount / percent', (tester) async {
    final db = await _db(tester, arabic: false);
    await captureScreen(
      tester,
      budgetTestApp(
        home: const BudgetScreen(),
        overrides: budgetOverrides(db: db),
        theme: MadarThemeId.pearl,
        locale: en,
      ),
      '$_dir/plan_en_pearl',
    );
  });

  testWidgets('plan – Arabic, Emerald, warnings', (tester) async {
    final db = await _db(tester, nodes: warningNodes(), names: _warningNamesAr);
    await captureScreen(
      tester,
      budgetTestApp(home: const BudgetScreen(), overrides: budgetOverrides(db: db), theme: MadarThemeId.emerald),
      '$_dir/plan_warnings_ar_emerald',
    );
  });

  testWidgets('plan – English, Lapis, warnings scrolled to the tree', (tester) async {
    final db = await _db(tester, nodes: warningNodes(), arabic: false);
    await captureScreen(
      tester,
      budgetTestApp(home: const BudgetScreen(), overrides: budgetOverrides(db: db), locale: en),
      '$_dir/plan_warnings_en_lapis_tree',
      beforeCapture: (tester) => _scrollBy(tester, 420),
    );
  });

  testWidgets('plan – Arabic, Pearl, warnings scrolled to the tree', (tester) async {
    final db = await _db(tester, nodes: warningNodes(), names: _warningNamesAr);
    await captureScreen(
      tester,
      budgetTestApp(home: const BudgetScreen(), overrides: budgetOverrides(db: db), theme: MadarThemeId.pearl),
      '$_dir/plan_warnings_ar_pearl_tree',
      beforeCapture: (tester) => _scrollBy(tester, 820),
    );
  });

  testWidgets('spending – English, Lapis, this month', (tester) async {
    final db = await _db(tester, arabic: false);
    await captureScreen(
      tester,
      budgetTestApp(
        home: const BudgetScreen(initialTab: BudgetTab.spending),
        overrides: budgetOverrides(db: db),
        locale: en,
      ),
      '$_dir/spending_en_lapis',
    );
  });

  testWidgets('spending – Arabic, Pearl, bars', (tester) async {
    final db = await _db(tester);
    await captureScreen(
      tester,
      budgetTestApp(
        home: const BudgetScreen(initialTab: BudgetTab.spending),
        overrides: budgetOverrides(db: db),
        theme: MadarThemeId.pearl,
      ),
      '$_dir/spending_ar_pearl_bars',
      beforeCapture: (tester) => _scrollBy(tester, 520),
    );
  });

  testWidgets('item sheet – Arabic, Pearl, a new share of the total', (tester) async {
    final db = await _db(tester);
    await captureScreen(
      tester,
      budgetTestApp(home: const BudgetScreen(), overrides: budgetOverrides(db: db), theme: MadarThemeId.pearl),
      '$_dir/item_sheet_new_ar_pearl',
      beforeCapture: (tester) async {
        await tester.tap(find.bySemanticsLabel('إضافة بند'));
        await _frames(tester, 24);
        await tester.enterText(find.byKey(const ValueKey('budget.sheet.name')), 'ادخار');
        await tester.enterText(find.byKey(const ValueKey('budget.sheet.percent')), '١٠');
        await _frames(tester, 6);
        FocusManager.instance.primaryFocus?.unfocus();
      },
      trailingFrames: 30,
    );
  });

  testWidgets('spending – Arabic, Lapis, this month', (tester) async {
    final db = await _db(tester);
    await captureScreen(
      tester,
      budgetTestApp(
        home: const BudgetScreen(initialTab: BudgetTab.spending),
        overrides: budgetOverrides(db: db),
      ),
      '$_dir/spending_ar_lapis',
    );
  });

  testWidgets('spending – English, Pearl, bars and history', (tester) async {
    final db = await _db(tester, arabic: false);
    await captureScreen(
      tester,
      budgetTestApp(
        home: const BudgetScreen(initialTab: BudgetTab.spending),
        overrides: budgetOverrides(db: db),
        theme: MadarThemeId.pearl,
        locale: en,
      ),
      '$_dir/spending_en_pearl_history',
      beforeCapture: (tester) => _scrollBy(tester, 700),
    );
  });

  testWidgets('spending – Arabic, Aurora, this week', (tester) async {
    final db = await _db(tester);
    await captureScreen(
      tester,
      budgetTestApp(
        home: const BudgetScreen(initialTab: BudgetTab.spending),
        overrides: budgetOverrides(db: db),
        theme: MadarThemeId.aurora,
      ),
      '$_dir/spending_week_ar_aurora',
      beforeCapture: (tester) => _tapText(tester, 'أسبوعي'),
    );
  });

  testWidgets('item sheet – Arabic, Lapis, percent item', (tester) async {
    final db = await _db(tester);
    await captureScreen(
      tester,
      budgetTestApp(home: const BudgetScreen(), overrides: budgetOverrides(db: db)),
      '$_dir/item_sheet_ar_lapis',
      beforeCapture: (tester) => _tapText(tester, 'بروتينات'),
      trailingFrames: 30,
    );
  });

  testWidgets('item sheet – English, Pearl, weekly item', (tester) async {
    final db = await _db(tester, arabic: false);
    await captureScreen(
      tester,
      budgetTestApp(
        home: const BudgetScreen(),
        overrides: budgetOverrides(db: db),
        theme: MadarThemeId.pearl,
        locale: en,
      ),
      '$_dir/item_sheet_en_pearl',
      beforeCapture: (tester) async {
        await _scrollBy(tester, 500);
        await _tapText(tester, "Wife's allowance");
      },
      trailingFrames: 30,
    );
  });

  testWidgets('picker – Arabic, Desert', (tester) async {
    final db = await _db(tester);
    await captureScreen(
      tester,
      budgetTestApp(
        home: Builder(
          builder: (context) => MadarScaffold(
            title: 'مصروف جديد',
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.gutter),
                child: BudgetPickerField(value: 'spice', onChanged: (_) {}),
              ),
            ),
          ),
        ),
        overrides: budgetOverrides(db: db),
        theme: MadarThemeId.desert,
      ),
      '$_dir/picker_ar_desert',
      beforeCapture: (tester) async {
        await tester.tap(find.byType(BudgetPickerField));
        await _frames(tester, 30);
      },
    );
  });

  testWidgets('status card – Arabic, Lapis and English, Pearl', (tester) async {
    final db = await _db(tester);
    Widget card() => MadarScaffold(
      title: 'المال',
      body: const Padding(
        padding: EdgeInsets.all(Space.gutter),
        child: Column(children: [BudgetStatusCard()]),
      ),
    );
    await captureScreen(tester, budgetTestApp(home: card(), overrides: budgetOverrides(db: db)), '$_dir/card_ar_lapis');
  });

  testWidgets('status card – English, Pearl', (tester) async {
    final db = await _db(tester, arabic: false);
    await captureScreen(
      tester,
      budgetTestApp(
        home: const MadarScaffold(
          title: 'Money',
          body: Padding(
            padding: EdgeInsets.all(Space.gutter),
            child: Column(children: [BudgetStatusCard()]),
          ),
        ),
        overrides: budgetOverrides(db: db),
        theme: MadarThemeId.pearl,
        locale: en,
      ),
      '$_dir/card_en_pearl',
    );
  });

  testWidgets('empty – Arabic, Lapis', (tester) async {
    final db = await openBudgetDatabase(tester);
    await captureScreen(
      tester,
      budgetTestApp(home: const BudgetScreen(), overrides: budgetOverrides(db: db)),
      '$_dir/empty_ar_lapis',
    );
  });

  testWidgets('weeks sheet – English, Emerald', (tester) async {
    final db = await _db(tester, arabic: false);
    await captureScreen(
      tester,
      budgetTestApp(
        home: const BudgetScreen(),
        overrides: budgetOverrides(db: db),
        theme: MadarThemeId.emerald,
        locale: en,
      ),
      '$_dir/weeks_sheet_en_emerald',
      beforeCapture: (tester) async {
        await tester.tap(find.textContaining('Weeks per month').hitTestable().first);
        await _frames(tester, 30);
      },
    );
  });
}
