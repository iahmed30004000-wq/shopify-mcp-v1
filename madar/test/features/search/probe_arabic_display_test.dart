// Adversarial probes: how a result of the other script is laid out (an
// English record in the Arabic UI, an Arabic record in the English UI).
// Each test FAILS while the problem it names exists.
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/search/search.dart';

import 'search_harness.dart';

/// The laid-out paragraph of the tile text that reads [plain].
RenderParagraph paragraphOf(WidgetTester tester, String plain) {
  final finder = find.descendant(
    of: find.byType(SearchResultTile),
    matching: find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == plain),
  );
  return tester.renderObject<RenderParagraph>(finder);
}

/// Left edge of the code unit at [offset] in [p].
double leftOf(RenderParagraph p, int offset) =>
    p.getBoxesForSelection(TextSelection(baseOffset: offset, extentOffset: offset + 1)).first.left;

Future<void> pumpTile(WidgetTester tester, SearchHit hit, Locale locale) => pumpSearchApp(
  tester,
  locale: locale,
  seed: false,
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(20), child: SearchResultTile(hit: hit, now: searchTestNow)),
  ),
);

/// A real hit on [title] / [body] for [query] (the index cuts the snippet).
SearchHit hitFor(String title, String body, String query) {
  final index = SearchIndex()
    ..upsert(SearchDoc(id: 'x', refTable: 'tasks', refId: 'x', title: title, body: body, planetKey: 'work', sourceId: 'tasks'));
  return index.search(SearchIndexQuery(query)).hits.single;
}

const String englishBody =
    'Last month we agreed on the new contract with the landlord and the agent, then we paid the deposit. '
    'Remember to bring the signed lease and the receipts from the bank for the rent of October.';

const String arabicBody =
    'اتفقنا الشهر الماضي على العقد الجديد مع صاحب البيت والوكيل ثم دفعنا التأمين كاملا في البنك. '
    'تذكر إحضار عقد الإيجار الموقع وإيصالات البنك عن أجرة شهر تشرين الأول قبل نهاية الأسبوع.';

void main() {
  testWidgets('Arabic UI, English title: the closing «!» is drawn after the last word, not before the first', (
    tester,
  ) async {
    const title = 'Call Omar!';
    await pumpTile(tester, hitFor(title, '', 'omar'), const Locale('ar'));
    final t = paragraphOf(tester, title);
    expect(leftOf(t, title.length - 1), greaterThan(leftOf(t, title.length - 2)), reason: 'title drawn as «!Call Omar»');
    await tearDownApp(tester);
  });

  testWidgets('Arabic UI, English snippet cut before the match: «…» is drawn before the first word (left)', (
    tester,
  ) async {
    final hit = hitFor('Rent', englishBody, 'receipts');
    expect(hit.snippet, startsWith('…'));
    await pumpTile(tester, hit, const Locale('ar'));
    final s = paragraphOf(tester, hit.snippet);
    expect(leftOf(s, 0), lessThan(leftOf(s, 1)), reason: 'the leading «…» is drawn after the English text, as if it were cut at the end');
    await tearDownApp(tester);
  });

  testWidgets('English UI, Arabic snippet cut before the match: «…» is drawn before the first word (right)', (
    tester,
  ) async {
    final hit = hitFor('الإيجار', arabicBody, 'نهاية');
    expect(hit.snippet, startsWith('…'));
    await pumpTile(tester, hit, const Locale('en'));
    final s = paragraphOf(tester, hit.snippet);
    expect(leftOf(s, 0), greaterThan(leftOf(s, 1)), reason: 'the leading «…» lands at the reading end of the Arabic line');
    await tearDownApp(tester);
  });
}
