// Import check (quality gate): the spec's example budget goes through the
// real importer into BudgetItems rows, and every total and percentage the
// budget shows is asserted – in the display model, in the formatted text
// (Arabic and English) and on the rendered Plan tab.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations_ar.dart';
import 'package:madar/core/i18n/gen/app_localizations_en.dart';
import 'package:madar/core/import/import.dart';
import 'package:madar/features/money/budget/budget.dart';

import 'budget_fixtures.dart';

/// The example exactly as the spec words it (Arabic keys the prototype
/// uses are covered by the importer's own tests).
const specJson = '''
{
  "money": {
    "budget": {
      "Home food": {
        "amount": 200,
        "children": {"Proteins": 100, "Spices": 20, "Treats": 30, "Fruit & vegetables": 50}
      },
      "Car fuel": 100,
      "Emergency": 30,
      "Wife's allowance": {"amount": 5, "period": "weekly"}
    }
  }
}
''';

final _importer = PrototypeImporter(labels: ImportLabels.forLanguage('en'));

Future<List<BudgetItemRow>> importSpec(MadarDatabase db) async {
  final plan = _importer.analyze(specJson, now: DateTime(2026, 9, 29));
  await _importer.commit(db, plan);
  return db.select(db.budgetItems).get();
}

void main() {
  group('the spec example through the importer', () {
    late MadarDatabase db;
    late BudgetPlan plan;
    late Map<String, BudgetLine> byName;

    setUp(() async {
      db = MadarDatabase(NativeDatabase.memory(), seed: const SeedOptions());
      final rows = await importSpec(db);
      expect(rows, hasLength(8));
      final math = await BudgetRepository(Repositories(db)).math();
      plan = BudgetPlan(math);
      byName = {for (final l in plan.lines) l.name: l};
    });
    tearDown(() => db.close());

    test('maps the complete nested tree', () {
      expect(byName.keys, [
        'Home food',
        'Proteins',
        'Spices',
        'Treats',
        'Fruit & vegetables',
        'Car fuel',
        'Emergency',
        "Wife's allowance",
      ]);
      for (final child in ['Proteins', 'Spices', 'Treats', 'Fruit & vegetables']) {
        expect(byName[child]!.parentId, byName['Home food']!.id, reason: child);
        expect(byName[child]!.depth, 1);
      }
      for (final root in ['Home food', 'Car fuel', 'Emergency', "Wife's allowance"]) {
        expect(byName[root]!.depth, 0, reason: root);
      }
      expect(byName["Wife's allowance"]!.period, BudgetPeriod.weekly);
      expect(plan.issues, isEmpty, reason: 'children sum exactly to Home food');
    });

    test('every total and percentage (exact)', () {
      expect(plan.totalMonthlyMilli, 350000);
      expect(plan.totalWeeklyMilli, 87500);
      final expected = <String, (int, int, double, double?)>{
        // name: (shown amount, monthly, % of base, % of parent)
        'Home food': (200000, 200000, 400 / 7, null),
        'Proteins': (100000, 100000, 50, 50),
        'Spices': (20000, 20000, 10, 10),
        'Treats': (30000, 30000, 15, 15),
        'Fruit & vegetables': (50000, 50000, 25, 25),
        'Car fuel': (100000, 100000, 200 / 7, null),
        'Emergency': (30000, 30000, 60 / 7, null),
        "Wife's allowance": (5000, 20000, 40 / 7, null),
      };
      expected.forEach((name, e) {
        final l = byName[name]!;
        expect(l.plannedMilli, e.$1, reason: name);
        expect(l.monthlyMilli, e.$2, reason: name);
        expect(l.percentOfBase, closeTo(e.$3, 1e-9), reason: name);
        if (e.$4 != null) expect(l.percentOfParent, closeTo(e.$4!, 1e-9), reason: name);
      });
      expect(byName['Proteins']!.percentOfTotal, closeTo(200 / 7, 1e-9));
      expect(byName['Home food']!.childrenSumMilli, 200000);
    });

    test('the displayed text in English', () {
      final f = BudgetFormat(const MadarFormatter(languageCode: 'en'), currencies: const BudgetCurrencies(base: 'JOD'));
      final l = L10nEn();
      String strip(String s) => BidiIsolate.strip(s);
      expect(strip(f.money(plan.totalMonthlyMilli)), '350.000 JOD');
      expect(strip(l.budgetWeeklyEquivalent(f.money(plan.totalWeeklyMilli))), '≈ 87.500 JOD a week');
      final shares = {for (final line in plan.lines) line.name: strip(BudgetLabels.share(l, f, plan, line))};
      expect(shares, {
        'Home food': '57.14% of the total',
        'Proteins': '50% of Home food',
        'Spices': '10% of Home food',
        'Treats': '15% of Home food',
        'Fruit & vegetables': '25% of Home food',
        'Car fuel': '28.57% of the total',
        'Emergency': '8.57% of the total',
        "Wife's allowance": '5.71% of the total',
      });
      final amounts = {for (final line in plan.lines) line.name: strip(f.money(line.plannedMilli, line.currency))};
      expect(amounts['Home food'], '200.000 JOD');
      expect(amounts['Spices'], '20.000 JOD');
      expect(amounts["Wife's allowance"], '5.000 JOD');
      final wife = byName["Wife's allowance"]!;
      expect(strip(l.budgetApproxMonthly(f.money(wife.monthlyMilli))), '≈ 20.000 JOD a month');
    });

    test('the displayed text in Arabic (Arabic-Indic digits, isolated amounts)', () {
      final f = BudgetFormat(const MadarFormatter(), currencies: const BudgetCurrencies(base: 'JOD'));
      final l = L10nAr();
      final total = f.money(plan.totalMonthlyMilli);
      expect(total, startsWith(BidiIsolate.rli));
      expect(total, endsWith(BidiIsolate.pdi));
      expect(BidiIsolate.strip(total), '٣٥٠٫٠٠٠ د.أ');
      expect(f.percent(byName['Home food']!.percentOfBase), contains('٥٧٫١٤٪'));
      expect(f.percent(byName['Proteins']!.percentOfBase), contains('٥٠٪'));
      expect(f.percent(byName['Fruit & vegetables']!.percentOfTotal), contains('١٤٫٢٩٪'));
      final share = BidiIsolate.strip(BudgetLabels.share(l, f, plan, byName['Spices']!));
      expect(share, '١٠٪ من «Home food»');
      expect(BidiIsolate.strip(f.money(-12500)), '؜-١٢٫٥٠٠ د.أ');
    });
  });

  testWidgets('the Plan tab shows the imported totals and shares', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    installBudgetFx();
    final db = await openBudgetDatabase(tester);
    await tester.runAsync(() => importSpec(db));
    await tester.pumpWidget(
      budgetTestApp(home: const BudgetScreen(), overrides: budgetOverrides(db: db), locale: const Locale('en')),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    String text(Widget w) => w is Text ? BidiIsolate.strip(w.data ?? w.textSpan?.toPlainText() ?? '') : '';
    final shown = tester.widgetList(find.byType(Text)).map(text).toSet();
    for (final s in [
      '350.000 JOD',
      '≈ 87.500 JOD a week',
      'Weeks per month: 4',
      '57.14% of the total',
      '50% of Home food',
      '10% of Home food',
      '15% of Home food',
      '25% of Home food',
      '28.57% of the total',
      '8.57% of the total',
      '200.000 JOD',
      '100.000 JOD',
      '50.000 JOD',
      '30.000 JOD',
      '20.000 JOD',
      '5.000 JOD',
      '5.71% of the total · ≈ 20.000 JOD a month',
      'Everything adds up',
    ]) {
      expect(shown, contains(s), reason: s);
    }
  });
}
