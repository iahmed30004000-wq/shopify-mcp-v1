import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/health/wellbeing/presentation/tabs/habits_tab.dart';
import 'package:madar/features/health/wellbeing/presentation/tabs/insights_tab.dart';
import 'package:madar/features/health/wellbeing/presentation/tabs/pain_tab.dart';
import 'package:madar/features/health/wellbeing/presentation/tabs/worries_tab.dart';
import 'package:madar/features/health/wellbeing/presentation/widgets/scale_inputs.dart';
import 'package:madar/features/health/wellbeing/wellbeing.dart';

import 'wellbeing_harness.dart';
import 'wellbeing_seed.dart';

final L10n ar = lookupL10n(const Locale('ar'));

Future<T> db<T>(WidgetTester tester, Future<T> Function() work) async => (await tester.runAsync(work)) as T;

Future<void> frames(WidgetTester tester, {int n = 20, Duration step = const Duration(milliseconds: 50)}) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(step);
  }
}

void main() {
  group('check-in', () {
    testWidgets('a face on the today card opens the sheet; saving writes the entry and a completion', (tester) async {
      final env = await pumpWellbeingApp(tester, home: const WellbeingScreen(), seed: WellbeingSeed.empty);
      expect(find.text(ar.wbMoodQuestion), findsOneWidget);
      await tester.tap(find.byType(MoodFace).at(3));
      await frames(tester);
      expect(find.text(ar.wbCheckInTitle), findsOneWidget);
      // Mood 4 comes preselected; set stress on the middle bead.
      final beads = find.descendant(of: find.byType(ScaleBeads).first, matching: find.byType(GestureDetector)).first;
      await tester.tap(beads);
      await frames(tester, n: 4);
      await tester.tap(find.widgetWithText(SheetButton, ar.wbSave));
      await frames(tester);
      final rows = await db(tester, () => env.repos.moodEntries.getAll());
      expect(rows, hasLength(1));
      expect(rows.single.mood, 4);
      expect(rows.single.stress, 5);
      final activity = await db(tester, () => env.repos.activityLog.getAll());
      expect(activity.single.kind, 'health.mood');
      expect(activity.single.planetKey, 'health');
      expect(env.haptics.fired, contains(Haptic.success));
      await settleWellbeing(tester);
      expect(find.text(ar.wbTodayCheckIn), findsOneWidget);
    });

    testWidgets('an empty check-in cannot be saved', (tester) async {
      final env = await pumpWellbeingApp(
        tester,
        home: Builder(
          builder: (context) => TextButton(onPressed: () => showMoodCheckInSheet(context), child: const Text('open')),
        ),
        seed: WellbeingSeed.empty,
      );
      await tester.tap(find.text('open'));
      await frames(tester);
      await tester.tap(find.widgetWithText(SheetButton, ar.wbSave));
      await frames(tester, n: 4);
      expect(await db(tester, () => env.repos.moodEntries.count()), 0);
      expect(env.haptics.fired, contains(Haptic.error));
    });
  });

  group('pain', () {
    testWidgets('quick log writes a score-only entry with an undo toast', (tester) async {
      final env = await pumpWellbeingApp(
        tester,
        home: const WellbeingScreen(initialTab: WellbeingTab.pain),
        seed: WellbeingSeed.empty,
      );
      await tester.tap(find.text(ar.wbQuickLog));
      await frames(tester);
      final rows = await db(tester, () => env.repos.painEntries.getAll());
      expect(rows.single.score, 3);
      expect(rows.single.at, wellbeingTestNow);
      expect(find.text(ar.wbPainLogged('٣')), findsOneWidget);
      await tester.tap(find.text(ar.actionUndo).last);
      await frames(tester, n: 30);
      expect(await db(tester, () => env.repos.painEntries.count()), 0);
    });

    testWidgets('tapping the body map drops a point and suggests the area', (tester) async {
      final env = await pumpWellbeingApp(
        tester,
        home: const WellbeingScreen(initialTab: WellbeingTab.pain),
        seed: WellbeingSeed.empty,
      );
      await tester.tap(find.text(ar.wbWithDetails));
      await frames(tester);
      final front = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BodyMapPainter && (w.painter! as BodyMapPainter).side == BodySide.front,
      );
      final rect = tester.getRect(front.last);
      await tester.tapAt(rect.topLeft + BodyMapPainter.toCanvas(rect.size, 0.5, 0.06));
      await frames(tester, n: 6);
      // Outside the silhouette: nothing added.
      await tester.tapAt(rect.topLeft + BodyMapPainter.toCanvas(rect.size, 0.05, 0.3));
      await frames(tester, n: 6);
      await tester.tap(find.widgetWithText(SheetButton, ar.wbSave));
      await frames(tester);
      final row = (await db(tester, () => env.repos.painEntries.getAll())).single;
      final points = BodyPoint.listFrom(row.bodyPoints);
      expect(points, hasLength(1));
      expect(points.single.side, BodySide.front);
      expect(points.single.y, closeTo(0.06, 0.02));
      expect(row.locations, [ar.dbSeedPainHead]);
      expect(row.score, 3);
    });

    testWidgets('history rows edit and delete with undo', (tester) async {
      final env = await pumpWellbeingApp(
        tester,
        home: const WellbeingScreen(initialTab: WellbeingTab.pain),
        seed: WellbeingSeed.empty,
        beforePump: (db) => WellbeingService(
          Repositories(db),
          clock: () => wellbeingTestNow,
        ).logPain(PainDraft(at: wellbeingTestNow, score: 7, triggers: const ['X'])),
      );
      final tile = find.byType(PainTile);
      await tester.scrollUntilVisible(tile, 300, scrollable: find.byType(Scrollable).first);
      await frames(tester, n: 4);
      final state = tester.state<ActionableItemState>(find.descendant(of: tile, matching: find.byType(ActionableItem)));
      state.delete();
      await frames(tester, n: 20);
      expect(await db(tester, () => env.repos.painEntries.count()), 0);
      await tester.tap(find.text(ar.actionUndo).last);
      await frames(tester, n: 20);
      expect(await db(tester, () => env.repos.painEntries.count()), 1);
    });
  });

  group('habits', () {
    testWidgets('tap ticks today and logs a Health completion', (tester) async {
      final env = await pumpWellbeingApp(
        tester,
        home: const WellbeingScreen(initialTab: WellbeingTab.habits),
        seed: WellbeingSeed.empty,
      );
      final first = tester.widget<HabitTile>(find.byType(HabitTile).first);
      expect(first.progress.doneToday, isFalse);
      await tester.tap(find.text(first.habit.name));
      await frames(tester, n: 30);
      final logs = await db(tester, () => env.repos.habitLogs.getAll());
      expect(logs.single.habitId, first.habit.id);
      expect(logs.single.day, '2026-09-29');
      final activity = await db(tester, () => env.repos.activityLog.getAll());
      expect(activity.single.kind, 'health.habit');
      expect(tester.widget<HabitTile>(find.byType(HabitTile).first).progress.doneToday, isTrue);
    });
  });

  group('worries', () {
    testWidgets('park, then review: resolve one and keep the other', (tester) async {
      final env = await pumpWellbeingApp(
        tester,
        home: const WellbeingScreen(initialTab: WellbeingTab.worries),
        seed: WellbeingSeed.empty,
      );
      await tester.enterText(find.byType(TextField).first, 'الإيجار');
      await frames(tester, n: 4);
      await tester.tap(find.text(ar.wbWorryPark));
      await frames(tester);
      await tester.enterText(find.byType(TextField).first, 'الامتحان');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await frames(tester);
      expect(find.byType(WorryTile), findsNWidgets(2));
      await db(
        tester,
        () => env.container
            .read(wellbeingServiceProvider)
            .updateSettings((s) => s.copyWith(worry: const WorryWindowSettings(enabled: true, minuteOfDay: 20 * 60))),
      );
      await frames(tester);
      await tester.tap(find.byIcon(Icons.playlist_add_check_rounded));
      await frames(tester);
      expect(find.text(ar.wbWorryReviewTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(SheetButton, ar.wbWorryResolved));
      await frames(tester);
      await tester.tap(find.widgetWithText(SheetButton, ar.wbWorryKeep));
      await frames(tester);
      expect(find.text(ar.wbWorryReviewDoneTitle), findsOneWidget);
      final rows = await db(tester, () => env.repos.worries.getAll());
      expect([for (final r in rows) r.resolved], [true, false]);
      final activity = await db(tester, () => env.repos.activityLog.getAll());
      expect(activity.single.kind, 'health.worry');
      expect(activity.single.value, 2);
    });

    testWidgets('an enabled window plans seven gentle notifications in its own id block', (tester) async {
      final env = await pumpWellbeingApp(
        tester,
        home: const WellbeingScreen(initialTab: WellbeingTab.worries),
        seed: const WellbeingSeed(checkIns: false, pain: false, habits: false),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await frames(tester, n: 4);
      final notices = env.reminders.current;
      expect(notices, hasLength(7));
      expect(notices.first.id, 150900);
      expect(notices.first.at, DateTime(2026, 9, 30, 20));
      expect(notices.first.title, ar.wbWorryNotifyTitle);
      expect(notices.first.body, contains('٣'));
      expect(notices.every((n) => WorryReminderIds.owns(n.id)), isTrue);
    });
  });

  group('support banner', () {
    testWidgets('shows after repeated low moods; calls the configured number; hides for a week', (tester) async {
      final env = await pumpWellbeingApp(tester, home: const WellbeingScreen(), seed: WellbeingSeed.lowMoodWeek);
      expect(find.text(ar.wbSupportTitle), findsOneWidget);
      await tester.tap(find.byIcon(Icons.call_rounded));
      await frames(tester, n: 4);
      expect(env.dialer.dialed, ['911']);
      await tester.tap(find.text(ar.wbSupportHideWeek).last);
      await frames(tester);
      await settleWellbeing(tester);
      expect(find.text(ar.wbSupportTitle), findsNothing);
      final s = await db(tester, () => env.container.read(wellbeingServiceProvider).settings());
      expect(s.supportDismissedUntil, wellbeingTestNow.add(const Duration(days: 7)));
    });

    testWidgets('never shows without the pattern', (tester) async {
      await pumpWellbeingApp(tester, home: const WellbeingScreen(), seed: WellbeingSeed.full);
      expect(find.text(ar.wbSupportTitle), findsNothing);
    });

    testWidgets('a custom number is dialled as entered', (tester) async {
      final env = await pumpWellbeingApp(
        tester,
        home: const Scaffold(body: SupportBanner()),
        seed: WellbeingSeed.lowMoodWeek,
        beforePump: (d) =>
            WellbeingService(Repositories(d)).updateSettings((s) => s.copyWith(supportNumber: '+44 999')),
      );
      await tester.tap(find.byIcon(Icons.call_rounded));
      await frames(tester, n: 4);
      expect(env.dialer.dialed, ['+44999']);
    });
  });

  group('breathing', () {
    testWidgets('phase cues fire haptics; a finished session is logged', (tester) async {
      final env = await pumpWellbeingApp(
        tester,
        home: const BreathingScreen(pattern: 'box', cycles: 1),
        seed: WellbeingSeed.empty,
      );
      env.haptics.fired.clear();
      await tester.tap(find.text(ar.wbBreathStart));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(ar.wbBreathIn), findsOneWidget);
      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(ar.wbBreathHold), findsOneWidget);
      expect(env.haptics.fired.where((h) => h == Haptic.medium).length, greaterThanOrEqualTo(1));
      expect(env.haptics.fired, contains(Haptic.light));
      for (var i = 0; i < 130; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(ar.wbBreathDone), findsOneWidget);
      await frames(tester, n: 10);
      final activity = await db(tester, () => env.repos.activityLog.getAll());
      expect(activity.single.kind, 'health.breathing');
      expect(activity.single.value, 1);
      await frames(tester, n: 60);
    });

    testWidgets('reduced motion keeps the ring still', (tester) async {
      await pumpWellbeingApp(tester, home: const BreathingScreen(), seed: WellbeingSeed.empty, reducedMotion: true);
      await tester.tap(find.text(ar.wbBreathStart));
      await tester.pump();
      final sizes = <double>{};
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        sizes.add(tester.widget<BreathRing>(find.byType(BreathRing)).expansion);
      }
      expect(sizes, {0.6});
      await tester.tap(find.text(ar.wbBreathStop));
      await tester.pump();
    });
  });

  group('insights', () {
    testWidgets('not enough data shows progress instead of observations', (tester) async {
      await pumpWellbeingApp(
        tester,
        home: const WellbeingScreen(initialTab: WellbeingTab.insights),
        seed: const WellbeingSeed(days: 3, pain: false),
      );
      expect(find.text(ar.wbInsightsNotYetTitle), findsOneWidget);
      expect(find.byType(InsightCard), findsNothing);
    });

    testWidgets('seeded months show neutral observation cards', (tester) async {
      await pumpWellbeingApp(
        tester,
        home: const WellbeingScreen(initialTab: WellbeingTab.insights),
        seed: WellbeingSeed.full,
      );
      expect(find.byType(InsightCard), findsWidgets);
    });
  });

  group('texts', () {
    const split = SplitInsight(
      condition: SplitCondition.shortSleep,
      outcome: WellMetric.stress,
      meanIn: 6.2,
      meanOut: 4.2,
      daysIn: 8,
      daysOut: 20,
      effect: 1.4,
    );
    const corr = CorrelationInsight(a: WellMetric.stress, b: WellMetric.pain, r: -0.45, days: 18);
    const banned = [
      'ينبغي',
      'يجب',
      'حاول',
      'ننصح',
      'علاج',
      'تشخيص',
      'should',
      'try ',
      'recommend',
      'treat',
      'because',
      'causes',
    ];

    test('Arabic split sentence carries its numbers, no advice', () {
      final s = WbTexts(ar, const MadarFormatter()).insight(split);
      expect(s, contains('في الأيام التي نمت فيها أقل من ٦ ساعات'));
      expect(s, contains('بدرجتين'));
      expect(s, contains('٦٫٢'));
      expect(s, contains('٤٫٢'));
      for (final b in banned) {
        expect(s.contains(b), isFalse, reason: b);
      }
    });

    test('English correlation is neutral and signed', () {
      final en = lookupL10n(const Locale('en'));
      final s = WbTexts(en, const MadarFormatter(languageCode: 'en')).insight(corr);
      expect(s, startsWith('On days your stress was higher, your pain tended to be milder'));
      expect(s, contains('-0.45'));
      expect(s, contains('18 days'));
      for (final b in banned) {
        expect(s.toLowerCase().contains(b), isFalse, reason: b);
      }
    });

    test('fractional differences and hours', () {
      const sleep = SplitInsight(
        condition: SplitCondition.muchCaffeine,
        outcome: WellMetric.sleep,
        meanIn: 5.5,
        meanOut: 7,
        daysIn: 5,
        daysOut: 9,
        effect: -2,
      );
      final en = lookupL10n(const Locale('en'));
      final s = WbTexts(en, const MadarFormatter(languageCode: 'en')).insight(sleep);
      expect(s, contains('your sleep averaged 1.5 hours lower'));
      expect(s, contains('3 or more cups'));
    });
  });
}
