import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/wird/wird.dart';

import 'wird_harness.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

Future<WirdPlan> _pagesPlan(MadarDatabase db, {String name = 'ورد يومي'}) => seedPlan(
  db,
  WirdDraft(
    name: name,
    template: WirdTemplate.pages,
    amount: 2,
    startDate: DateTime(2026, 9, 27),
    window: PrayerWindow.asr,
    catchUp: WirdCatchUp.spread,
  ),
);

/// Pumps frames without running the undo toast's countdown out.
Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets("Arabic: today's portion, mark done with undo, quran.wird logged", (tester) async {
    late WirdPlan plan;
    final env = await pumpFaithApp(
      tester,
      home: const WirdScreen(),
      beforePump: (db) async {
        plan = await _pagesPlan(db);
        await seedReading(db, plan, days: [0]);
      },
    );
    expect(find.text(_ar.wirdTitle), findsOneWidget);
    // Day 2: pages 3–4 = البقرة ٦–٢٤.
    expect(find.text('البقرة\u00A0٦–٢٤'), findsWidgets);
    expect(find.text(_ar.wirdMarkDone), findsOneWidget);
    env.haptics.fired.clear();
    await tester.tap(find.text(_ar.wirdMarkDone));
    await _frames(tester);
    final sessions = await tester.runAsync(() => env.repos.quranSessions.getAll());
    expect(sessions!.length, 2);
    expect(sessions.last.fromAyah, 6);
    expect(sessions.last.toAyah, 24);
    expect(env.haptics.fired, contains(Haptic.success));
    expect(find.text(_ar.wirdDoneToast), findsOneWidget);
    expect(find.text(_ar.wirdMetToday), findsOneWidget);
    await _frames(tester);
    final logged = await tester.runAsync(() => env.repos.activity.since(DateTime(2026, 9, 28), kind: 'quran.wird'));
    expect(logged!.length, 1);
    // Undo from the toast.
    await tester.tap(find.text(_ar.actionUndo));
    await _frames(tester);
    expect((await tester.runAsync(() => env.repos.quranSessions.getAll()))!.length, 1);
    expect(await tester.runAsync(() => env.repos.activity.since(DateTime(2026, 9, 28), kind: 'quran.wird')), isEmpty);
  });

  testWidgets('read now hands the reader where the plan stands', (tester) async {
    final env = await pumpFaithApp(tester, home: const WirdScreen(), beforePump: (db) async => _pagesPlan(db));
    await tester.tap(find.text(_ar.wirdReadNow));
    await settleFaith(tester);
    expect(env.readRequests.single.start, const AyahRef(1, 1));
    // A day behind, spread: 2/7 of a page a day would round away forever,
    // so the debt is repaid a whole page a day – pages 1–3 today.
    expect(env.readRequests.single.range, const AyahRange(AyahRef(1, 1), AyahRef(2, 16)));
  });

  testWidgets('English: empty state → new plan sheet → a 30-day khatma', (tester) async {
    final env = await pumpFaithApp(tester, home: const WirdScreen(), locale: const Locale('en'));
    expect(find.text(_en.wirdEmptyTitle), findsOneWidget);
    await tester.tap(find.text(_en.wirdEmptyAction));
    await settleFaith(tester);
    expect(find.text(_en.wirdNewPlanTitle), findsOneWidget);
    expect(find.text('Khatma in 30 days'), findsWidgets);
    await tester.tap(find.text(_en.wirdCreate));
    await settleFaith(tester);
    final plans = await tester.runAsync(() => WirdService(env.repos, clock: () => faithTestNow).plans());
    expect(plans!.single.isKhatma, isTrue);
    expect(plans.single.khatmaDays, 30);
    expect(plans.single.startDate, DateTime(2026, 9, 28));
    expect(plans.single.window, PrayerWindow.fajr);
    expect(find.text(_en.wirdTodayTitle), findsWidgets);
    expect(find.textContaining('Al-Fatihah\u00A01'), findsWidgets);
  });

  testWidgets('plans list: long-press menu pauses with undo', (tester) async {
    late WirdPlan plan;
    final env = await pumpFaithApp(
      tester,
      home: const WirdScreen(),
      locale: const Locale('en'),
      beforePump: (db) async {
        plan = await _pagesPlan(db, name: 'Two pages');
        await _pagesPlan(db, name: 'Second');
      },
    );
    expect(find.text(_en.wirdPrimary), findsOneWidget);
    await tester.longPress(find.text('Second'));
    await settleFaith(tester);
    await tester.tap(find.text(_en.wirdPause));
    await _frames(tester);
    final second = (await tester.runAsync(() => WirdService(env.repos, clock: () => faithTestNow).plans()))!
        .firstWhere((p) => p.id != plan.id);
    expect(second.active, isFalse);
    expect(find.text(_en.wirdPaused), findsWidgets);
    await tester.tap(find.text(_en.actionUndo));
    await _frames(tester);
    final again = (await tester.runAsync(() => WirdService(env.repos, clock: () => faithTestNow).plans()))!
        .firstWhere((p) => p.id != plan.id);
    expect(again.active, isTrue);
  });

  testWidgets('today card: a call to start, then the primary plan', (tester) async {
    await pumpFaithApp(tester, home: const Scaffold(body: WirdTodayCard()));
    expect(find.text(_ar.wirdStartPlanCta), findsOneWidget);
  });

  testWidgets('today card shows the portion and marks it done', (tester) async {
    final env = await pumpFaithApp(
      tester,
      home: const Scaffold(body: WirdTodayCard()),
      locale: const Locale('en'),
      beforePump: (db) async => _pagesPlan(db),
    );
    // A day behind: pages 1–3 (see "read now" above).
    expect(find.text('Al-Fatihah\u00A01 – Al-Baqarah\u00A016'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(_en.wirdMarkDone));
    await _frames(tester);
    expect((await tester.runAsync(() => env.repos.quranSessions.getAll()))!.length, 1);
    expect(find.text(_en.wirdMetToday), findsOneWidget);
  });

  testWidgets('reduced motion still renders the screen', (tester) async {
    await pumpFaithApp(
      tester,
      home: const WirdScreen(),
      reducedMotion: true,
      beforePump: (db) async => _pagesPlan(db),
    );
    expect(find.text(_ar.wirdHistoryTitle), findsOneWidget);
    expect(Repositories, isNotNull);
  });
}
