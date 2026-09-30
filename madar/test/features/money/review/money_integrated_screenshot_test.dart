// Art-direction matrix of the integrated Money world inside the real app
// (router, AppGate, app lock, real fonts and shaders): the Money hub, the
// ledger, a wallet, the transaction sheet, the currencies, the budget plan
// and spending, the three goals tabs and a jar – in Arabic and English,
// across Lapis, Pearl and Aurora – plus every screen at text scale 1.3
// (a layout overflow fails the test), each checked for WCAG AA on the
// pixels actually painted. Writes PNGs to
// madar/screenshots/phase5/integrated/.
//
//   TZ=Asia/Amman flutter test --tags screenshot test/features/money/review/money_integrated_screenshot_test.dart
@Tags(['screenshot'])
@Timeout(Duration(minutes: 60))
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/money/budget/budget.dart';
import 'package:madar/features/money/goals/goals.dart';
import 'package:madar/features/money/hub/money_hub.dart';
import 'package:madar/features/money/ledger/ledger.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';

import '../../../core/design/rendered_contrast.dart';
import '../../../helpers/screenshot_harness.dart';
import '../../../helpers/test_app.dart';
import '../../lock/lock_test_utils.dart';
import '../../orbit/presentation/orbit_scene_fixtures.dart' show preloadOrbitShaders;
import '../hub/money_hub_seed.dart';

const _dir = 'phase5/integrated';

/// Ids of the lived-in example (set by [_seed]).
late MoneyHubIds _ids;
late String _transferId;

/// The hub's example plus the spec's nested budget, a cross-currency
/// transfer and a USD debt, so every screen has something real to show.
Future<void> _seed(MadarDatabase db, {required bool arabic}) async {
  String tr(String ar, String en) => arabic ? ar : en;
  final n = moneyHubNow;
  final repos = Repositories(db);
  _ids = await seedMoneyHub(db, arabic: arabic);
  final budget = BudgetRepository(repos, clock: () => n);
  final ledger = LedgerService(repos, clock: () => n);
  final goals = GoalsService(repos, clock: () => n);
  var order = 10;
  for (final (id, ar, en, milli) in [
    ('b.prot', 'بروتينات', 'Proteins', 100000),
    ('b.spice', 'بهارات', 'Spices', 20000),
    ('b.treat', 'حلويات', 'Treats', 30000),
    ('b.fv', 'خضار وفواكه', 'Fruit & vegetables', 50000),
  ]) {
    await budget.add(BudgetNode(id: id, name: tr(ar, en), parentId: _ids.food, amountMilli: milli, sortOrder: order++));
  }
  await budget.add(BudgetNode(id: 'b.emerg', name: tr('طوارئ', 'Emergency'), amountMilli: 30000, sortOrder: order++));
  await budget.add(
    BudgetNode(
      id: 'b.wife',
      name: tr('مصروف الزوجة', "Wife's allowance"),
      amountMilli: 5000,
      period: BudgetPeriod.weekly,
      sortOrder: order++,
    ),
  );
  for (final (item, milli, day) in [('b.prot', 62500, 12), ('b.fv', 18750, 22), ('b.wife', 5000, 26)]) {
    await ledger.add(
      TxWrite(
        walletId: _ids.cash,
        kind: TxKind.expense,
        amountMilli: milli,
        date: DateTime(n.year, n.month, day),
        budgetItemId: item,
      ),
    );
  }
  final transfer = await ledger.add(
    TxWrite(
      walletId: _ids.bank,
      kind: TxKind.transfer,
      amountMilli: 100000,
      toWalletId: _ids.egypt,
      toAmountMilli: 6896550,
      date: DateTime(n.year, n.month, 27),
      note: tr('تمويل إعلانات مصر', 'Egypt ads budget'),
    ),
  );
  _transferId = transfer.id;
  await goals.addDebt(
    DebtDraft(
      direction: DebtDirection.owedToMe,
      person: tr('مورّد ليبيا', 'Libya supplier'),
      amountMilli: 250000,
      currency: 'USD',
      dueDate: DateTime(n.year, n.month + 1, 15),
    ),
  );
}

Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _shot(
  WidgetTester tester,
  _Screen screen, {
  required String lang,
  required MadarThemeId theme,
  double textScale = 1,
}) async {
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await preloadOrbitShaders(tester);
  final setup = await buildMadarTestApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
    initialLocation: screen.start,
    now: moneyHubNow,
    beforePump: (db) => _seed(db, arabic: lang == 'ar'),
    overrides: LockFixture.empty().overrides,
  );
  final suffix = textScale == 1 ? '' : '_x${(textScale * 10).round()}';
  final boundary = GlobalKey();
  final misses = <TextContrast>[];
  await captureScreen(
    tester,
    RepaintBoundary(key: boundary, child: setup.app),
    '$_dir/${screen.name}_${lang}_${theme.name}$suffix',
    settle: const Duration(milliseconds: 1000),
    beforeCapture: (tester) async {
      // Wallet and jar ids exist only once the database is seeded.
      final go = screen.go;
      if (go != null) {
        GoRouter.of(tester.element(find.byType(Scaffold).first)).push(go());
        await _frames(tester, 16);
      }
      await screen.before?.call(tester);
      await _frames(tester, 10);
      // WCAG AA on the pixels actually painted (text only; icons are
      // decorative beside their labels).
      misses.addAll([
        for (final r in await measureRenderedContrast(tester, boundary))
          if (!r.passes && !r.icon) r,
      ]);
    },
    trailingFrames: 4,
  );
  expect(misses, isEmpty, reason: '${screen.name} $lang ${theme.name}: ${misses.join('\n')}');
}

/// Scrolls the planet sheet so [target] sits [below] its top edge.
Future<void> _sheetTo(WidgetTester tester, Finder target, {double below = 60}) async {
  final scrollable = find
      .descendant(
        of: find.byType(PlanetModulePage),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var pass = 0; pass < 3; pass++) {
    await _frames(tester, 4);
    final dy = tester.getTopLeft(target).dy - tester.getTopLeft(scrollable).dy - below;
    if (dy.abs() < 2) break;
    position.jumpTo((position.pixels + dy).clamp(position.minScrollExtent, position.maxScrollExtent));
  }
  await _frames(tester, 12);
}

typedef _Screen = ({
  String name,
  String start,
  String Function()? go,
  Future<void> Function(WidgetTester tester)? before,
});

final List<_Screen> _screens = [
  (
    name: 'hub',
    start: AppRoutes.planetOf('money'),
    go: null,
    before: (tester) => _sheetTo(tester, find.byType(MoneyNetWorthCard), below: 130),
  ),
  (name: 'ledger', start: AppRoutes.ledger, go: null, before: null),
  (name: 'wallet', start: AppRoutes.ledger, go: () => AppRoutes.walletOf(_ids.bank), before: null),
  (
    name: 'tx_sheet',
    start: AppRoutes.ledger,
    go: null,
    before: (tester) async {
      final context = tester.element(find.byType(MoneyLedgerScreen));
      unawaited(showTransactionSheet(context, transactionId: _transferId));
      await _frames(tester, 24);
    },
  ),
  (name: 'currencies', start: AppRoutes.currencies, go: null, before: null),
  (name: 'budget_plan', start: AppRoutes.budgetOf(tab: 'plan'), go: null, before: null),
  (name: 'budget_spending', start: AppRoutes.budgetOf(tab: 'spending'), go: null, before: null),
  (name: 'goals_jars', start: AppRoutes.goalsOf(tab: 'jars'), go: null, before: null),
  (name: 'goals_debts', start: AppRoutes.goalsOf(tab: 'debts'), go: null, before: null),
  (name: 'goals_obligations', start: AppRoutes.goalsOf(tab: 'obligations'), go: null, before: null),
  (name: 'jar', start: AppRoutes.goals, go: () => AppRoutes.jarOf(_ids.jar), before: null),
];

void main() {
  const themes = [MadarThemeId.lapis, MadarThemeId.pearl, MadarThemeId.aurora];
  for (final s in _screens) {
    for (final lang in ['ar', 'en']) {
      for (final theme in themes) {
        testWidgets('${s.name} $lang ${theme.name}', (tester) async {
          await _shot(tester, s, lang: lang, theme: theme);
        });
      }
      testWidgets('${s.name} $lang text x1.3', (tester) async {
        await _shot(
          tester,
          s,
          lang: lang,
          theme: lang == 'ar' ? MadarThemeId.lapis : MadarThemeId.pearl,
          textScale: 1.3,
        );
      });
    }
  }
}
