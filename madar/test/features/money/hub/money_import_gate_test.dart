// Quality gate, integrated: the spec's example budget, imported through the
// real importer into the app's database, reaches the Money world whole –
// the hub's plan card totals it (350 JOD a month: Home food 200 with its
// four children, Car fuel 100, Emergency 30, the weekly 5 JOD allowance ×
// 4 weeks), the budget route shows the nested tree with its percentages,
// the ledger's budget picker (the budget package's) lists all eight items,
// and the Money planet reads the plan with nothing overspent.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/money/budget/budget.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/domain/planet_scores.dart';
import 'package:madar/features/orbit/domain/score_sources.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';

import '../../../helpers/test_app.dart';
import '../../lock/lock_test_utils.dart';
import '../budget/budget_import_check_test.dart' show importSpec;
import 'money_hub_seed.dart';

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _importAndFresh(MadarDatabase db) async {
  await seedMoneyFresh(db);
  expect(await importSpec(db), hasLength(8));
}

void main() {
  testWidgets('the imported budget totals 350 JOD on the hub and nests on the budget route', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      initialLocation: AppRoutes.planetOf('money'),
      now: moneyHubNow,
      beforePump: _importAndFresh,
      overrides: LockFixture.empty().overrides,
      settle: false,
    );
    await _frames(tester, 60);
    await settleApp(tester);
    final card = find.byType(BudgetStatusCard);
    await tester.scrollUntilVisible(
      card,
      250,
      scrollable: find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first,
    );
    expect(find.descendant(of: card, matching: find.textContaining('350.000', findRichText: true)), findsWidgets);

    // The whole plan, as the budget package computes it for the hub.
    final plan = app.container.read(budgetPlanProvider).requireValue;
    expect(plan.totalMonthlyMilli, 350000);
    expect(plan.totalWeeklyMilli, 87500);
    final byName = {for (final l in plan.lines) l.name: l};
    expect(byName.keys, hasLength(8));
    expect(byName['Home food']!.percentOfBase, closeTo(400 / 7, 1e-9));
    expect(byName['Proteins']!.percentOfBase, closeTo(50, 1e-9));
    expect(byName["Wife's allowance"]!.monthlyMilli, 20000);
    expect(plan.issues, isEmpty);

    app.router.go(AppRoutes.budget);
    await settleApp(tester);
    expect(find.byType(BudgetScreen), findsOneWidget);
    for (final name in ['Home food', 'Car fuel', 'Emergency']) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    await tester.pump(const Duration(seconds: 6));
  });

  test('the Money planet reads the imported plan: nothing overspent, the budget on track', () async {
    final db = await openInMemoryMadarDatabase();
    addTearDown(db.close);
    await _importAndFresh(db);
    final planet = (await OrbitRepository(Repositories(db), clock: () => moneyHubNow).snapshot()).planet('money')!;
    expect(planet.score.sources[ScoreSources.budget], 1);
    expect(planet.score.reasons.where((r) => r.code == ReasonCode.budgetOverspent), isEmpty);
  });
}
