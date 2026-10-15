// «الحفظ» step 2: the screens, inside the real app, in Arabic and in
// English.
//
// Every drill here is run against the app's **own verified Uthmani text**
// (`quranStoreProvider` over the bundled files) and every result is read
// back out of the database afterwards, so a passing test means the
// strength really moved – not that a widget drew the right word.
@Timeout(Duration(minutes: 8))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/hifz/hifz_plan.dart';
import 'package:madar/features/orbit/data/orbit_providers.dart' show prayerScheduleProvider;
import 'package:madar/features/tasmee/tasmee.dart';

import '../tasmee/tasmee_fixtures.dart';
import '../wird/wird_harness.dart';
import 'hifz_plan_harness.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

/// Al-Ikhlas – four short ayat of the real text, so a whole drill can be
/// typed out in a test.
const AyahRange _ikhlas = AyahRange(AyahRef(112, 1), AyahRef(112, 4));

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 40));
  }
}

/// `ensureVisible` can park a control under the frosted app bar, where a
/// tap lands on the header instead. Nudge the list until it is pressable.
Future<Finder> _pressable(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target.first);
  await _frames(tester, 6);
  for (var i = 0; i < 8 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 80));
    await _frames(tester, 4);
  }
  expect(target.hitTestable(), findsAtLeastNWidgets(1), reason: 'the control never cleared the header');
  return target.hitTestable().first;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.tap(await _pressable(tester, target));
  await _frames(tester, 10);
}

/// The log as the database holds it, after a drill was saved.
Future<List<TasmeeSession>> _log(WidgetTester tester, FaithTestEnv env) async =>
    (await tester.runAsync(() => TasmeeService(env.repos, clock: () => hifzNow).log()))!;

/// Every verified word of [range], as the text writes them.
List<String> _words(AyahRange range) => verifiedWords(targetOf(range));

void main() {
  // ------------------------------------------------------ the morning ----

  testWidgets('[ar] the morning screen: the three tracks, the methods, and no voice yet', (tester) async {
    await pumpHifzUi(
      tester,
      home: const HifzPlanScreen(animateBackdrop: false),
      beforePump: (db) async {
        await seedHifzPlan(db, surah: 2, from: 1, to: 150, lastActiveDaysAgo: 1);
        await seedHifzSettings(db, const HifzPlanSettings(newFrom: AyahRef(2, 200), newAyatPerDay: 5));
      },
    );
    expect(find.text(_ar.hifzPlanTitle), findsOneWidget);
    // All three tracks are there, each under its own heading (the far
    // one is below the fold on a phone, so scroll to it).
    expect(find.text(_ar.hifzTrackFresh), findsOneWidget);
    expect(find.text(_ar.hifzTrackNear), findsOneWidget);
    // Every portion says which method the plan suggests, and offers to
    // start it: a brand-new stretch is listened to and repeated, one he
    // was never tested on is hidden stage by stage.
    expect(find.textContaining(_ar.hifzMethodListenRepeat), findsWidgets);
    expect(find.textContaining(_ar.hifzMethodHiding), findsWidgets);
    expect(find.text(_ar.hifzPlanStart), findsWidgets);
    // The microphone does not exist in this build, and the screen says so
    // rather than offering a dead «سمّع بصوتك».
    expect(find.text(_ar.hifzMethodNoRecogniser), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(_ar.hifzTrackFar),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await _frames(tester, 6);
    expect(find.text(_ar.hifzTrackFar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('[en] nothing memorised yet: the empty state invites, it does not invent a plan', (tester) async {
    await pumpHifzUi(tester, home: const HifzPlanScreen(animateBackdrop: false), locale: const Locale('en'));
    expect(find.text(_en.hifzPlanNothingTitle), findsOneWidget);
    expect(find.text(_en.hifzPlanEmpty), findsWidgets);
    expect(find.text(_en.hifzPlanStart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('[ar] after a week away: the backlog line, and the stretches it names', (tester) async {
    await pumpHifzUi(
      tester,
      home: const HifzPlanScreen(animateBackdrop: false),
      beforePump: (db) => seedHifzPlan(db, surah: 2, from: 1, to: 150, lastActiveDaysAgo: 8),
    );
    expect(find.text(_ar.hifzBacklogTitle), findsOneWidget);
    final line = tester.widget<Text>(find.byKey(const ValueKey('hifz.plan.backlog.line'))).data!;
    // «غبت ٧ أيام…» – seven days away, in Arabic-Indic digits, and the
    // ayat that went back into the rotation are counted, not swallowed.
    expect(line, contains('٧'));
    expect(line.contains('0') || line.contains('7'), isFalse);
    expect(find.byKey(const ValueKey('hifz.plan.backlog.ranges')), findsOneWidget);
    final ranges = tester.widget<Text>(find.byKey(const ValueKey('hifz.plan.backlog.ranges'))).data!;
    expect(ranges, contains('البقرة'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('[ar] the plan settings sheet asks where the new portion starts', (tester) async {
    await pumpHifzUi(
      tester,
      home: const HifzPlanScreen(animateBackdrop: false),
      beforePump: (db) => seedHifzPlan(db, surah: 2, from: 1, to: 20, lastActiveDaysAgo: 1),
    );
    // With no cursor the plan says so instead of inventing a new portion.
    expect(find.text(_ar.hifzPlanNoNewPortion), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('hifz.plan.settings')));
    expect(find.text(_ar.hifzPlanSettings), findsWidgets);
    expect(find.text(_ar.hifzSettingsNewPerDay), findsOneWidget);
    expect(find.text(_ar.hifzSettingsStartFrom), findsOneWidget);
    expect(find.text(_ar.hifzSettingsCap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------------- the drills ----

  testWidgets('[ar] «اكتب من حفظك»: typing it right writes a result and the strength becomes known', (tester) async {
    final env = await pumpHifzUi(
      tester,
      home: const HifzDrillScreen(
        request: HifzDrillRequest(range: _ikhlas, method: HifzMethod.writing),
        animateBackdrop: false,
      ),
      beforePump: (db) => seedHifzPlan(db, surah: 112, from: 1, to: 4),
    );
    expect(find.text(_ar.hifzMethodWriting), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('hifz.drill.writing.field')), _words(_ikhlas).join(' '));
    await _frames(tester, 6);
    await _tap(tester, find.byKey(const ValueKey('hifz.drill.check')));
    expect(find.byKey(const ValueKey('hifz.drill.result')), findsOneWidget);
    // What he typed is shown as his own writing, labelled, never as Quran.
    expect(find.text(_ar.hifzDrillTypedBadge), findsWidgets);

    await _tap(tester, find.byKey(const ValueKey('hifz.drill.save')));
    final log = await _log(tester, env);
    expect(log, hasLength(1));
    expect(log.single.mode, TasmeeMode.write);
    expect(log.single.recogniserId, 'typed');
    expect(log.single.counts.wrong, 0);
    expect(log.single.ayat, hasLength(4));

    // The strength is recomputed from that row – it was unknown before.
    final strengths = HifzStrengths.of(log, today: hifzToday);
    expect(strengths.of(const AyahRef(112, 1)).isKnown, isTrue);
    expect(strengths.of(const AyahRef(112, 1)).band, isNot(StrengthBand.unknown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('[ar] «املأ الفراغ»: only the blanks are typed, and the drill is logged as blanks', (tester) async {
    final env = await pumpHifzUi(
      tester,
      home: const HifzDrillScreen(
        request: HifzDrillRequest(range: _ikhlas, method: HifzMethod.blanks, seed: 7),
        animateBackdrop: false,
      ),
      beforePump: (db) => seedHifzPlan(db, surah: 112, from: 1, to: 4),
    );
    final plan = Blanks.plan(targetOf(_ikhlas), seed: 7);
    expect(plan.blanks, isNotEmpty);
    final words = _words(_ikhlas);
    for (var i = 0; i < plan.blanks.length; i++) {
      await tester.enterText(
        await _pressable(tester, find.byKey(ValueKey('hifz.drill.blank.$i'))),
        words[plan.blanks[i]],
      );
      await _frames(tester, 4);
    }
    await _tap(tester, find.byKey(const ValueKey('hifz.drill.check')));
    await _tap(tester, find.byKey(const ValueKey('hifz.drill.save')));

    final log = await _log(tester, env);
    expect(log, hasLength(1));
    expect(log.single.mode, TasmeeMode.blanks);
    expect(log.single.counts.wrong, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('[ar] «الإخفاء التدريجي»: the ladder, a peek counted as a hint, and a hidden result', (tester) async {
    final env = await pumpHifzUi(
      tester,
      home: const HifzDrillScreen(
        request: HifzDrillRequest(range: _ikhlas, method: HifzMethod.progressiveHiding, stage: HidingStage.full),
        animateBackdrop: false,
      ),
      beforePump: (db) => seedHifzPlan(db, surah: 112, from: 1, to: 4),
    );
    // Stage 1: the whole text. Stage 2: the first letters only.
    expect(find.byKey(const ValueKey('hifz.drill.hiding.full')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('hifz.drill.hiding.harder')));
    expect(find.byKey(const ValueKey('hifz.drill.hiding.letters')), findsOneWidget);
    // Stage 3: hidden, with the keyboard instead of the voice.
    await _tap(tester, find.byKey(const ValueKey('hifz.drill.hiding.harder')));
    expect(find.byKey(const ValueKey('hifz.drill.hiding.hidden')), findsOneWidget);
    expect(find.text(_ar.tasmeePeekCountsAsHint), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('hifz.drill.hiding.peek')));

    await tester.enterText(
      await _pressable(tester, find.byKey(const ValueKey('hifz.drill.hiding.field'))),
      _words(_ikhlas).join(' '),
    );
    await _frames(tester, 6);
    await _tap(tester, find.byKey(const ValueKey('hifz.drill.check')));
    await _tap(tester, find.byKey(const ValueKey('hifz.drill.save')));

    final log = await _log(tester, env);
    expect(log, hasLength(1));
    expect(log.single.mode, TasmeeMode.hidden);
    // The peek is on the record: he produced that word, but not from memory.
    expect(log.single.counts.hints, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('[ar] «الربط»: the joins are typed, scored and logged as links', (tester) async {
    final env = await pumpHifzUi(
      tester,
      home: const HifzDrillScreen(
        request: HifzDrillRequest(range: _ikhlas, method: HifzMethod.linking),
        animateBackdrop: false,
      ),
      beforePump: (db) => seedHifzPlan(db, surah: 112, from: 1, to: 4),
    );
    final target = targetOf(_ikhlas);
    final links = Linking.of(target);
    expect(links, hasLength(3));
    for (var i = 0; i < links.length; i++) {
      await tester.enterText(
        await _pressable(tester, find.byKey(ValueKey('hifz.drill.link.field.$i'))),
        links[i].head.map((w) => w.text).join(' '),
      );
      await _frames(tester, 4);
    }
    await _tap(tester, find.byKey(const ValueKey('hifz.drill.check')));
    expect(find.byKey(const ValueKey('hifz.drill.linking.score')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('hifz.drill.save')));

    final log = await _log(tester, env);
    expect(log, hasLength(1));
    expect(log.single.mode, TasmeeMode.link);
    expect(tester.takeException(), isNull);
  });

  testWidgets('[ar] «التقطيع» runs and says plainly that it scores nothing', (tester) async {
    final env = await pumpHifzUi(
      tester,
      home: const HifzDrillScreen(
        request: HifzDrillRequest(range: _ikhlas, method: HifzMethod.chunking),
        animateBackdrop: false,
      ),
      beforePump: (db) => seedHifzPlan(db, surah: 112, from: 1, to: 4),
    );
    expect(find.text(_ar.hifzChunkLevelAyah), findsOneWidget);
    expect(find.text(_ar.hifzChunkLevelGroup), findsOneWidget);
    expect(find.text(_ar.hifzChunkLevelPage), findsOneWidget);
    expect(find.text(_ar.hifzDrillNoResultMode), findsWidgets);
    expect(find.byKey(const ValueKey('hifz.drill.save')), findsNothing);
    expect(await _log(tester, env), isEmpty);
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------- the one that needs a mic ----

  testWidgets('[ar] «سمّع بصوتك» is not a dead button: it says it is not ready, and offers the others', (tester) async {
    await pumpHifzUi(
      tester,
      home: const HifzDrillScreen(
        request: HifzDrillRequest(range: _ikhlas, method: HifzMethod.reciting),
        animateBackdrop: false,
      ),
      beforePump: (db) => seedHifzPlan(db, surah: 112, from: 1, to: 4),
    );
    expect(find.text(_ar.hifzMicSoonTitle), findsOneWidget);
    expect(find.text(_ar.hifzMicSoonNoTyping), findsOneWidget);
    expect(find.byKey(const ValueKey('hifz.drill.check')), findsNothing);
    expect(find.byKey(const ValueKey('hifz.drill.save')), findsNothing);

    // The method sheet shows it, greyed, with the reason – never hidden.
    await _tap(tester, find.byKey(const ValueKey('hifz.notReady.another')));
    expect(find.byKey(const ValueKey('hifz.method.reciting')), findsOneWidget);
    expect(find.text(_ar.hifzMethodNoRecogniser), findsWidgets);
    // The typed ones are offered and really switch the drill.
    await tester.tap(find.byKey(const ValueKey('hifz.method.writing')));
    await _frames(tester, 12);
    expect(find.byKey(const ValueKey('hifz.drill.writing.field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('[en] every mode says what it can do right now', (tester) async {
    await pumpHifzUi(
      tester,
      locale: const Locale('en'),
      home: const HifzDrillScreen(
        request: HifzDrillRequest(range: _ikhlas, method: HifzMethod.writing),
        animateBackdrop: false,
      ),
      beforePump: (db) => seedHifzPlan(db, surah: 112, from: 1, to: 4),
    );
    await _tap(tester, find.byKey(const ValueKey('hifz.drill.methods')));
    // The four typed ones are enabled, «سمّع» is not.
    for (final m in [HifzMethod.writing, HifzMethod.blanks, HifzMethod.progressiveHiding, HifzMethod.linking]) {
      expect(find.byKey(ValueKey('hifz.method.${m.name}')), findsOneWidget);
    }
    expect(find.text(_en.hifzMethodNoRecogniser), findsWidgets);
    expect(find.text(_en.hifzMethodTypedOnly), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------------- the page map ----

  testWidgets('[ar] the page map: a legend that reads it, and colours that match the strengths', (tester) async {
    final env = await pumpHifzUi(
      tester,
      home: const HifzMapScreen(animateBackdrop: false),
      beforePump: (db) => seedHifzPlan(db, surah: 112, from: 1, to: 4),
    );
    // Every band is named, so a colour is never the only information.
    for (final band in HifzPlanTexts.legendBands) {
      final name = switch (band) {
        StrengthBand.unknown => _ar.hifzBandUnknown,
        StrengthBand.weak => _ar.hifzBandWeak,
        StrengthBand.shaky => _ar.hifzBandShaky,
        StrengthBand.firm => _ar.hifzBandFirm,
        StrengthBand.solid => _ar.hifzBandSolid,
        StrengthBand.skipped => _ar.hifzBandSkipped,
      };
      expect(find.text(name), findsWidgets, reason: band.name);
    }
    expect(find.byKey(const ValueKey('hifz.map.grid')), findsOneWidget);
    // Al-Ikhlas sits on page 604 of the Madani mushaf; nothing has been
    // tested, so it is «ما انختبرت» – not weak, which is the whole point.
    final map = env.container.read(hifzPageMapProvider).value!;
    final page = map.touchedPages.single;
    expect(page.band, StrengthBand.unknown);
    final cell = find.byKey(ValueKey('hifz.map.page.${page.page}'));
    expect(cell, findsOneWidget);
    expect(
      tester.getSemantics(cell).label,
      contains(_ar.hifzBandUnknown),
    );
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------- the goals ----

  testWidgets('[ar] a goal in his own words, and its reminder planned off the prayer times', (tester) async {
    final scheduler = FakeHifzGoalScheduler();
    final env = await pumpHifzUi(
      tester,
      home: const HifzGoalsScreen(animateBackdrop: false),
      overrides: [
        hifzGoalSchedulerProvider.overrideWithValue(scheduler),
        prayerScheduleProvider.overrideWith((ref) => FixedPrayerSchedule()),
      ],
      beforePump: (db) async {
        await seedHifzPlan(db, surah: 18, from: 1, to: 10);
        await seedHifzGoal(
          db,
          title: 'الكهف كل جمعة',
          kind: HifzGoalKind.rangeOnWeekday,
          range: const AyahRange(AyahRef(18, 1), AyahRef(18, 10)),
          weekday: DateTime.friday,
          window: PrayerWindow.fajr,
          offsetMinutes: 15,
        );
      },
    );
    // His own words, verbatim.
    expect(find.text('الكهف كل جمعة'), findsOneWidget);
    expect(find.text(_ar.hifzGoalReminderExplain), findsOneWidget);
    expect(find.byKey(const ValueKey('hifz.goals.list')), findsOneWidget);

    // The reminders are planned against the prayer times, not the clock.
    await tester.runAsync(() => env.container.read(hifzGoalReminderSyncProvider.notifier).syncNow());
    await _frames(tester, 6);
    expect(scheduler.last, isNotEmpty);
    final friday = scheduler.last.first;
    expect(friday.reminder.window, PrayerWindow.fajr);
    expect(friday.at.weekday, DateTime.friday);
    // Fajr (04:40) + fifteen minutes.
    expect(friday.at.hour, 4);
    expect(friday.at.minute, 55);
    expect(friday.body, contains('الكهف كل جمعة'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('[ar] switching a goal off cancels its reminder', (tester) async {
    final scheduler = FakeHifzGoalScheduler();
    final env = await pumpHifzUi(
      tester,
      home: const HifzGoalsScreen(animateBackdrop: false),
      overrides: [
        hifzGoalSchedulerProvider.overrideWithValue(scheduler),
        prayerScheduleProvider.overrideWith((ref) => FixedPrayerSchedule()),
      ],
      beforePump: (db) => seedHifzGoal(
        db,
        title: 'جزء عمّ كل يوم',
        kind: HifzGoalKind.amountPerDay,
        amount: 2,
        window: PrayerWindow.maghrib,
      ),
    );
    final goals = env.container.read(hifzGoalsProvider).value!;
    await _tap(tester, find.byKey(ValueKey('hifz.goal.active.${goals.single.id}')));
    await tester.runAsync(() => env.container.read(hifzGoalReminderSyncProvider.notifier).syncNow());
    await _frames(tester, 6);
    expect(scheduler.last, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('[ar] the goal sheet asks for his own words and a prayer, never a clock', (tester) async {
    await pumpHifzUi(tester, home: const HifzGoalsScreen(animateBackdrop: false));
    expect(find.text(_ar.hifzGoalsEmpty), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('hifz.goals.add')));
    expect(find.text(_ar.hifzGoalFieldTitle), findsOneWidget);
    expect(find.text(_ar.hifzGoalFieldWindow), findsOneWidget);
    expect(find.text(_ar.hifzGoalFieldOffset), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------- bigger letters ----

  for (final lang in ['ar', 'en']) {
    testWidgets('[$lang] the morning screen and a drill hold at text scale 1.3', (tester) async {
      await pumpHifzUi(
        tester,
        locale: Locale(lang),
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.3,
          maxScaleFactor: 1.3,
          child: const HifzPlanScreen(animateBackdrop: false),
        ),
        beforePump: (db) async {
          await seedHifzPlan(db, surah: 2, from: 1, to: 150, lastActiveDaysAgo: 8);
          await seedHifzSettings(db, const HifzPlanSettings(newFrom: AyahRef(2, 200), newAyatPerDay: 5));
        },
      );
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await _frames(tester, 6);
      expect(tester.takeException(), isNull);
    });

    testWidgets('[$lang] «اكتب من حفظك» holds at text scale 1.3', (tester) async {
      await pumpHifzUi(
        tester,
        locale: Locale(lang),
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.3,
          maxScaleFactor: 1.3,
          child: const HifzDrillScreen(
            request: HifzDrillRequest(range: _ikhlas, method: HifzMethod.writing),
            animateBackdrop: false,
          ),
        ),
        beforePump: (db) => seedHifzPlan(db, surah: 112, from: 1, to: 4),
      );
      await tester.enterText(find.byKey(const ValueKey('hifz.drill.writing.field')), _words(_ikhlas).join(' '));
      await _frames(tester, 6);
      await _tap(tester, find.byKey(const ValueKey('hifz.drill.check')));
      expect(tester.takeException(), isNull);
    });
  }

  // ------------------------------------------- «شازام القرآن», typed ----

  testWidgets('[ar] typed «شازام»: one ayah, several, none, and too short', (tester) async {
    await pumpHifzUi(tester, home: const HifzFindScreen(animateBackdrop: false));
    expect(find.text(_ar.hifzFindTypedTitle), findsWidgets);

    Future<void> search(String phrase) async {
      await tester.enterText(await _pressable(tester, find.byKey(const ValueKey('hifz.find.field'))), phrase);
      await _frames(tester, 4);
      await _tap(tester, find.byKey(const ValueKey('hifz.find.search')));
      await _frames(tester, 14);
    }

    // One place, and it is named.
    await search('قل هو الله أحد');
    expect(find.byKey(const ValueKey('hifz.find.place.112:1')), findsOneWidget);
    expect(find.byKey(const ValueKey('hifz.find.verdict.sure')), findsOneWidget);
    // What he typed is his own, labelled, never styled as Quran.
    expect(find.text(_ar.hifzDrillTypedBadge), findsWidgets);

    // Thirty-one places in ar-Rahman: the honest answer is a list.
    await search('فبأي آلاء ربكما تكذبان');
    expect(find.byKey(const ValueKey('hifz.find.verdict.several')), findsOneWidget);
    expect(find.text(_ar.tasmeeFindSeveral), findsOneWidget);
    expect(find.byKey(const ValueKey('hifz.find.count')), findsOneWidget);

    // Nothing of his own invention when there is no match.
    await search('سيارة الكهرباء السريعة جدا');
    expect(find.byKey(const ValueKey('hifz.find.verdict.none')), findsOneWidget);
    expect(find.text(_ar.tasmeeFindNone), findsOneWidget);

    // Two words are everywhere, and it refuses to guess.
    await search('قل هو');
    expect(find.byKey(const ValueKey('hifz.find.verdict.tooShort')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('[en] typed «شازام» finds the place and offers the mushaf', (tester) async {
    await pumpHifzUi(tester, home: const HifzFindScreen(animateBackdrop: false), locale: const Locale('en'));
    await tester.enterText(find.byKey(const ValueKey('hifz.find.field')), 'قل هو الله أحد');
    await _frames(tester, 4);
    await _tap(tester, find.byKey(const ValueKey('hifz.find.search')));
    await _frames(tester, 14);
    expect(find.text(_en.tasmeeFindSure), findsOneWidget);
    expect(find.text(_en.hifzFindOpenInMushaf), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
