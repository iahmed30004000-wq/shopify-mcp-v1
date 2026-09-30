// THE QUALITY GATE (Phase 5): a prototype-style export ({data, logs}) with
// the spec's example budget – Home food 200 → proteins 100, spices 20,
// treats 30, fruit & vegetables 50; car fuel 100; emergency 30; allowance
// 5/week – goes through the real importer into the app's database, and
// the real budget route shows every total and percentage on the row it
// belongs to, in English and in Arabic (the Arabic export uses Arabic keys
// and nested maps, as the prototype may). The Spending tab then shows the
// imported expenses against the plan.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/interaction/actionable_item.dart' show ActionableItem;
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/import/import.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/money/budget/budget.dart';

import '../../../helpers/test_app.dart';
import '../../lock/lock_test_utils.dart';

final DateTime _now = DateTime(2026, 9, 29, 13, 10);

/// The prototype's export, English keys (as its JavaScript wrote them).
const _exportEn = '''
{
  "version": 3,
  "exportedAt": "2026-09-28T20:15:00Z",
  "data": {
    "money": {
      "wallets": [{"id": "w1", "name": "Cash", "currency": "JOD", "opening": 500}],
      "budget": {
        "weeksPerMonth": 4,
        "items": [
          {"name": "Home food", "amount": 200, "children": [
            {"name": "Proteins", "amount": 100},
            {"name": "Spices", "amount": 20},
            {"name": "Treats", "amount": 30},
            {"name": "Fruit & vegetables", "amount": 50}
          ]},
          {"name": "Car fuel", "amount": 100},
          {"name": "Emergency", "amount": "30 JOD"},
          {"name": "Wife's allowance", "amount": 5, "period": "weekly"}
        ]
      },
      "transactions": [
        {"date": "2026-09-03", "type": "expense", "amount": 45, "wallet": "w1", "category": "Proteins"},
        {"date": "2026-09-17", "type": "expense", "amount": 30, "wallet": "w1", "category": "Proteins"},
        {"date": "2026-09-08", "type": "expense", "amount": 110, "wallet": "w1", "category": "Car fuel"},
        {"date": "2026-09-26", "type": "expense", "amount": 5, "wallet": "w1", "category": "Wife's allowance"},
        {"date": "2026-08-30", "type": "expense", "amount": 99, "wallet": "w1", "category": "Car fuel"}
      ]
    }
  },
  "logs": {}
}
''';

/// The same example as the prototype's Arabic export: Arabic keys, nested
/// maps, amounts as text ("5 أسبوعيًا").
const _exportAr = '''
{
  "data": {
    "مالية": {
      "محافظ": [{"id": "w1", "name": "الصندوق", "currency": "JOD", "opening": 500}],
      "الميزانية": {
        "طعام البيت": {"المبلغ": 200, "بروتينات": 100, "بهارات": 20, "حلويات": 30, "خضار وفواكه": 50},
        "بنزين السيارة": 100,
        "طوارئ": "30",
        "مصروف الزوجة": "5 أسبوعيًا"
      },
      "معاملات": [
        {"date": "2026-09-03", "type": "مصروف", "amount": 45, "wallet": "w1", "category": "بروتينات"},
        {"date": "2026-09-17", "type": "مصروف", "amount": 30, "wallet": "w1", "category": "بروتينات"},
        {"date": "2026-09-08", "type": "مصروف", "amount": 110, "wallet": "w1", "category": "بنزين السيارة"},
        {"date": "2026-09-26", "type": "مصروف", "amount": 5, "wallet": "w1", "category": "مصروف الزوجة"},
        {"date": "2026-08-30", "type": "مصروف", "amount": 99, "wallet": "w1", "category": "بنزين السيارة"}
      ]
    }
  },
  "logs": []
}
''';

Future<void> _import(MadarDatabase db, String json, String lang) async {
  final importer = PrototypeImporter(labels: ImportLabels.forLanguage(lang));
  final plan = importer.analyze(json, now: _now);
  expect(plan.canCommit, isTrue, reason: '${plan.report.issues}');
  await importer.commit(db, plan);
  final items = await db.select(db.budgetItems).get();
  expect(items, hasLength(8), reason: '${[for (final i in items) i.name]}');
}

String _plain(String s) {
  final out = StringBuffer();
  for (final r in BidiIsolate.strip(s).runes) {
    if (r == 0x061C || r == 0x200E || r == 0x200F) continue;
    out.writeCharCode(r == 0x00A0 || r == 0x202F ? 0x20 : r);
  }
  return out.toString();
}

/// Every text shown in the budget row of [name] (its own row only, not its
/// sub-items').
Set<String> _rowTexts(WidgetTester tester, String name) {
  final title = find.descendant(of: find.byType(ActionableItem), matching: find.text(name, findRichText: true));
  expect(title, findsWidgets, reason: name);
  final row = find.ancestor(of: title.first, matching: find.byType(ActionableItem)).first;
  return {
    for (final w in tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))))
      _plain(w.data ?? w.textSpan?.toPlainText() ?? ''),
  };
}

Set<String> _allTexts(WidgetTester tester) => {
  for (final w in tester.widgetList<Text>(find.byType(Text))) _plain(w.data ?? w.textSpan?.toPlainText() ?? ''),
};

Future<void> _pumpBudget(WidgetTester tester, String lang, String json, {String? tab}) async {
  tester.view.physicalSize = const Size(412, 2600) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await pumpMadarApp(
    tester,
    phone: false,
    settings: AppSettings(onboarded: true, languageCode: lang),
    initialLocation: AppRoutes.budgetOf(tab: tab),
    now: _now,
    beforePump: (db) => _import(db, json, lang),
    overrides: LockFixture.empty().overrides,
    settle: false,
  );
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(find.byType(BudgetScreen), findsOneWidget);
}

Future<void> _drain(WidgetTester tester) => tester.pump(const Duration(seconds: 6));

void main() {
  testWidgets('English: every total and percentage on the Plan tab, row by row', (tester) async {
    await _pumpBudget(tester, 'en', _exportEn);
    final all = _allTexts(tester);
    for (final s in [
      '350.000 JOD',
      '≈ 87.500 JOD a week',
      'Weeks per month: 4',
      // The plan itself adds up; only September's fuel is over.
      '1 thing needs attention',
      'Car fuel is 10.000 JOD over plan this month',
    ]) {
      expect(all, contains(s), reason: s);
    }
    // The allocation legend adds up to exactly 100 %.
    for (final s in ['57.1%', '28.6%', '8.6%', '5.7%']) {
      expect(all, contains(s), reason: 'legend $s');
    }
    final rows = <String, List<String>>{
      'Home food': ['200.000 JOD', '57.14% of the total'],
      'Proteins': ['100.000 JOD', '50% of Home food'],
      'Spices': ['20.000 JOD', '10% of Home food'],
      'Treats': ['30.000 JOD', '15% of Home food'],
      'Fruit & vegetables': ['50.000 JOD', '25% of Home food'],
      'Car fuel': ['100.000 JOD', '28.57% of the total'],
      'Emergency': ['30.000 JOD', '8.57% of the total'],
      "Wife's allowance": ['5.000 JOD', 'Weekly', '5.71% of the total · ≈ 20.000 JOD a month'],
    };
    rows.forEach((name, expected) {
      final shown = _rowTexts(tester, name);
      for (final s in expected) {
        expect(shown, contains(s), reason: '$name: $s (shown: $shown)');
      }
    });
    await _drain(tester);
  });

  testWidgets('Arabic export, Arabic UI: every total and percentage, row by row', (tester) async {
    await _pumpBudget(tester, 'ar', _exportAr);
    final all = _allTexts(tester);
    for (final s in ['٣٥٠٫٠٠٠ د.أ', '≈ ٨٧٫٥٠٠ د.أ في الأسبوع']) {
      expect(all, contains(s), reason: s);
    }
    for (final s in ['٥٧٫١٪', '٢٨٫٦٪', '٨٫٦٪', '٥٫٧٪']) {
      expect(all, contains(s), reason: 'legend $s');
    }
    final rows = <String, List<String>>{
      'طعام البيت': ['٢٠٠٫٠٠٠ د.أ', '٥٧٫١٤٪ من الإجمالي'],
      'بروتينات': ['١٠٠٫٠٠٠ د.أ', '٥٠٪ من «طعام البيت»'],
      'بهارات': ['٢٠٫٠٠٠ د.أ', '١٠٪ من «طعام البيت»'],
      'حلويات': ['٣٠٫٠٠٠ د.أ', '١٥٪ من «طعام البيت»'],
      'خضار وفواكه': ['٥٠٫٠٠٠ د.أ', '٢٥٪ من «طعام البيت»'],
      'بنزين السيارة': ['١٠٠٫٠٠٠ د.أ', '٢٨٫٥٧٪ من الإجمالي'],
      'طوارئ': ['٣٠٫٠٠٠ د.أ', '٨٫٥٧٪ من الإجمالي'],
      'مصروف الزوجة': ['٥٫٠٠٠ د.أ'],
    };
    rows.forEach((name, expected) {
      final shown = _rowTexts(tester, name);
      for (final s in expected) {
        expect(shown, contains(s), reason: '$name: $s (shown: $shown)');
      }
    });
    final wife = _rowTexts(tester, 'مصروف الزوجة').join(' | ');
    expect(wife, contains('٥٫٧١٪ من الإجمالي'));
    expect(wife, contains('≈ ٢٠٫٠٠٠ د.أ شهريًا'));
    await _drain(tester);
  });

  testWidgets('English: the Spending tab shows the imported month against the plan', (tester) async {
    await _pumpBudget(tester, 'en', _exportEn, tab: 'spending');
    final all = _allTexts(tester);
    // September: proteins 45 + 30, fuel 110, allowance 5 = 190 of 350
    // (August's 99 is left out).
    expect(all, contains('190.000 JOD'));
    expect(all, contains('of 350.000 JOD'));
    expect(all, contains('160.000 JOD'), reason: 'remaining');
    expect(all, contains('54%'), reason: 'spent ratio');
    expect(all, contains('10.000 JOD over'), reason: 'Car fuel is overspent by 10');
    expect(all, contains('75.000 JOD of 200.000 JOD'), reason: 'Home food rolls up Proteins');
    expect(all, contains('75.000 JOD of 100.000 JOD'), reason: 'Proteins');
    expect(all, contains('110.000 JOD of 100.000 JOD'), reason: 'Car fuel');
    expect(all, contains('5.000 JOD of 20.000 JOD'), reason: 'the weekly allowance, monthly');
    await _drain(tester);
  });
}
