import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/hifz/hifz.dart';

import '../wird/wird_harness.dart';
import 'hifz_seed.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('Arabic: counts, forecast and tabs', (tester) async {
    await pumpFaithApp(tester, home: const HifzScreen(), beforePump: seedHifz);
    expect(find.text(_ar.hifzTitle), findsOneWidget);
    // Three due (two Al-Mulk chunks and a hadith) and three new today.
    expect(find.text('٣ مقاطع للمراجعة'), findsOneWidget);
    expect(find.text('٣ مقاطع جديدة'), findsOneWidget);
    expect(find.text(_ar.hifzForecastTitle), findsOneWidget);
    expect(find.text('الملك\u00A0١–٥'), findsOneWidget);
    expect(find.text(_ar.hifzOverdue(2).replaceAll('2', '٢')), findsOneWidget);
    await tester.tap(find.text(_ar.hifzTabNew));
    await settleFaith(tester);
    expect(find.text('إنّما الأعمال بالنيّات'), findsOneWidget);
    expect(find.text('دعاء الخروج من المنزل'), findsOneWidget);
    await tester.tap(find.text(_ar.hifzTabLearned));
    await settleFaith(tester);
    await tester.scrollUntilVisible(find.text('الإخلاص\u00A0١–٤'), 300, scrollable: find.byType(Scrollable).first);
    await settleFaith(tester);
    expect(find.text('الإخلاص\u00A0١–٤'), findsOneWidget);
    expect(find.text(_ar.hifzSuspendedBadge), findsOneWidget);
  });

  testWidgets('review: reveal, listen, grade (saved), undo, finish with a summary', (tester) async {
    final env = await pumpFaithApp(tester, home: const HifzReviewScreen(), beforePump: seedHifz);
    expect(find.text('الملك\u00A0١–٥'), findsOneWidget);
    expect(find.text(_ar.hifzReviewProgress('١', '٦')), findsOneWidget);
    // Reveal step by step.
    await tester.tap(find.text(_ar.hifzRevealFirstLetters));
    await _frames(tester, 4);
    expect(find.text(_ar.hifzRevealNextWord), findsOneWidget);
    await tester.tap(find.text(_ar.hifzRevealAll));
    await _frames(tester, 4);
    expect(find.text(_ar.hifzRevealHide), findsOneWidget);
    // Listen: the ayat, each repeated three times.
    await tester.tap(find.textContaining(_ar.hifzListen));
    await _frames(tester, 4);
    expect(env.audio.played.single, (const AyahRange(AyahRef(67, 1), AyahRef(67, 5)), 3, 1));
    expect(find.text(_ar.hifzListenStop), findsOneWidget);
    // Grade "good": the chunk moves on (interval 6 × 2.36 → 14 days).
    env.haptics.fired.clear();
    await tester.tap(find.text(_ar.hifzGrade4));
    await _frames(tester);
    expect(env.haptics.fired, contains(Haptic.success));
    expect(env.audio.stops, greaterThan(0));
    var mulk = (await tester.runAsync(() => HifzService(env.repos, clock: () => faithTestNow).cards()))!.firstWhere(
      (c) => c.ayahFrom == 1 && c.surah == 67,
    );
    expect(mulk.due, DateTime(2026, 10, 12));
    expect(find.text(_ar.hifzReviewProgress('٢', '٦')), findsOneWidget);
    // Undo the grade.
    await tester.tap(find.bySemanticsLabel(_ar.hifzUndoGrade));
    await _frames(tester);
    mulk = (await tester.runAsync(() => HifzService(env.repos, clock: () => faithTestNow).cards()))!.firstWhere(
      (c) => c.ayahFrom == 1 && c.surah == 67,
    );
    expect(mulk.due, DateTime(2026, 9, 26));
    expect(find.text(_ar.hifzReviewProgress('١', '٦')), findsOneWidget);
    // Grade everything; the one graded "almost" comes back once more.
    for (final g in [_ar.hifzGrade2, _ar.hifzGrade5, _ar.hifzGrade5, _ar.hifzGrade4, _ar.hifzGrade4, _ar.hifzGrade4, _ar.hifzGrade4]) {
      if (find.text(g).evaluate().isEmpty) break;
      await tester.tap(find.text(g));
      await _frames(tester, 12);
    }
    expect(find.text(_ar.hifzSummaryTitle), findsOneWidget);
    final logged = await tester.runAsync(() => env.repos.activity.since(DateTime(2026, 9, 28), kind: 'quran.hifz'));
    expect(logged!.single.value, 6);
    final reviews = await tester.runAsync(() => env.repos.hifzReviews.getAll());
    expect(reviews!.where((r) => r.at.isAfter(DateTime(2026, 9, 28))).length, 6);
  });

  testWidgets('English: add a hadith from the picker', (tester) async {
    final env = await pumpFaithApp(tester, home: const HifzScreen(), locale: const Locale('en'));
    expect(find.text(_en.hifzEmptyTitle), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(_en.hifzAdd).first);
    await settleFaith(tester);
    await tester.tap(find.text(_en.hifzAddHadith));
    await settleFaith(tester);
    await tester.tap(find.text('Religion is sincere counsel'));
    await _frames(tester, 6);
    await tester.tap(find.textContaining(_en.hifzAddButton));
    await _frames(tester);
    final cards = await tester.runAsync(() => HifzService(env.repos, clock: () => faithTestNow).cards());
    expect(cards!.single.kind, HifzKind.hadith);
    expect(cards.single.source, 'nawawi40:7');
    expect(find.text('1 item added to Hifz'), findsOneWidget);
  });

  testWidgets('English: add ayat in chunks from the sheet', (tester) async {
    final env = await pumpFaithApp(tester, home: const HifzScreen(), locale: const Locale('en'));
    await tester.tap(find.bySemanticsLabel(_en.hifzAdd).first);
    await settleFaith(tester);
    await tester.tap(find.text(_en.hifzAddAyat));
    await settleFaith(tester);
    // Al-Mulk 1–10 by default, chunks of five.
    expect(find.text('2 chunks: 1–5 · 6–10'), findsOneWidget);
    await tester.tap(find.text(_en.hifzAddButton));
    await _frames(tester);
    final cards = await tester.runAsync(() => HifzService(env.repos, clock: () => faithTestNow).cards());
    expect(cards!.map((c) => c.range), const [
      AyahRange(AyahRef(67, 1), AyahRef(67, 5)),
      AyahRange(AyahRef(67, 6), AyahRef(67, 10)),
    ]);
  });

  testWidgets('today card: start review opens the session', (tester) async {
    await pumpFaithApp(tester, home: const Scaffold(body: HifzTodayCard()), beforePump: seedHifz);
    expect(find.text('٣ مقاطع للمراجعة'), findsOneWidget);
    await tester.tap(find.text(_ar.hifzStartReview));
    await settleFaith(tester);
    expect(find.text(_ar.hifzGradePrompt), findsOneWidget);
  });
}
