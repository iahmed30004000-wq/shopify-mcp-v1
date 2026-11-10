// Regression tests from the adversarial review of the prayer tracker: RTL
// affordances, contrast of the "not yet due" rows in every theme, the
// user's 12/24-hour prayer clock and the location's wall clock, per-frame
// repaints of the breathing "due" orb, month-to-date totals, the qada
// ledger with a long backlog, the jamaah / mosque marks on a missed prayer
// and the Arabic copy.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/contrast.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/i18n/gen/app_localizations_ar.dart';
import 'package:madar/core/i18n/gen/app_localizations_en.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer/domain/prayer_clock.dart';
import 'package:madar/features/prayer_tracker/prayer_tracker.dart';
import 'package:madar/features/prayer_tracker/presentation/history_view.dart' show QadaLedgerView;
import 'package:madar/features/prayer_tracker/presentation/tracker_labels.dart';
import 'package:madar/features/prayer_tracker/presentation/widgets/nafl_tiles.dart' show NaflTile;
import 'package:madar/features/prayer_tracker/presentation/widgets/status_orb.dart';

import '../../helpers/test_app.dart' show RecordingHaptics, openTestDatabase, settleApp, usePhoneSurface;
import 'tracker_fixtures.dart';

final L10n _ar = L10nAr();
final L10n _en = L10nEn();
const _fmtAr = MadarFormatter(languageCode: 'ar');

Future<MadarDatabase> _pump(
  WidgetTester tester, {
  required DateTime now,
  required Widget home,
  PrayerSchedule? schedule,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  Future<void> Function(Repositories repos)? seed,
  bool settle = true,
}) async {
  usePhoneSurface(tester);
  final db = await openTestDatabase(tester, seed: false);
  if (seed != null) await tester.runAsync(() => seed(Repositories(db)));
  Fx.install(FeedbackService(SilentSoundService(), RecordingHaptics()));
  await tester.pumpWidget(
    trackerTestApp(
      home: home,
      overrides: trackerOverrides(db: db, now: now, schedule: schedule),
      theme: theme,
      locale: locale,
    ),
  );
  if (settle) {
    await settleApp(tester);
  } else {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
  return db;
}

/// The colour [text] is actually painted in: its own colour times every
/// opacity above it.
Color _painted(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final color = paragraph.text.style!.color!;
  var opacity = 1.0;
  RenderObject? node = paragraph;
  while (node != null) {
    if (node is RenderOpacity) opacity *= node.opacity;
    if (node is RenderAnimatedOpacityMixin) opacity *= node.opacity.value;
    node = node.parent;
  }
  return color.withValues(alpha: color.a * opacity);
}

double _worstContrast(Color fg, MadarThemeId theme) {
  final t = MadarPalettes.tokensFor(theme);
  return [for (final bg in MadarPalettes.textSurfaces(t)) MadarContrast.ratio(MadarContrast.over(fg, bg), bg)]
      .reduce((a, b) => a < b ? a : b);
}

void main() {
  group('RTL', () {
    testWidgets('the compact card\'s "open" chevron points forward in Arabic and English', (tester) async {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        await _pump(
          tester,
          now: afterAsr(),
          locale: locale,
          home: MadarScaffold(
            body: ListView(children: [PrayerTodayCard(onOpen: () {})]),
          ),
        );
        // chevron_right follows the reading direction (matchTextDirection):
        // it points left in Arabic. chevron_left would point backwards.
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget, reason: '$locale');
        expect(find.byIcon(Icons.chevron_left_rounded), findsNothing, reason: '$locale');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('contrast', () {
    for (final theme in [MadarThemeId.pearl, MadarThemeId.lapis, MadarThemeId.desert]) {
      testWidgets('${theme.name}: rows and tiles not yet due stay legible (AA)', (tester) async {
        await _pump(
          tester,
          now: afterAsr(),
          theme: theme,
          home: const Scaffold(body: TrackerTodayView()),
        );
        final times = trackerTimes();
        final countdown = _ar.trackerUpcomingIn(_fmtAr.formatDurationWords(_ar, times.maghrib.difference(afterAsr())));
        final texts = {
          'name': find.text(_ar.prayerMaghrib),
          'countdown': find.text(countdown),
          'sunnah': find.textContaining(_ar.trackerSunnahMaghrib),
          'witr': find.descendant(of: find.byType(NaflTile), matching: find.text(_ar.trackerWitr)),
          'witr hint': find.descendant(
            of: find.byType(NaflTile),
            matching: find.text(
              _ar.trackerUpcomingIn(_fmtAr.formatDurationWords(_ar, times.isha.difference(afterAsr()))),
            ),
          ),
        };
        for (final e in texts.entries) {
          if (e.value.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              find.descendant(of: find.byType(NaflTile), matching: find.text(_ar.trackerWitr)),
              200,
              scrollable: find.byType(Scrollable).first,
            );
          }
          expect(e.value, findsWidgets, reason: e.key);
          final worst = _worstContrast(_painted(tester, e.value.first), theme);
          expect(worst, greaterThanOrEqualTo(MadarContrast.text), reason: '${theme.name} ${e.key}: $worst');
        }
      });
    }

    testWidgets('pearl: the "prayed" hint of a lit voluntary tile stays AA', (tester) async {
      await _pump(
        tester,
        now: trackerTimes().isha.add(const Duration(hours: 1)),
        theme: MadarThemeId.pearl,
        home: const Scaffold(body: TrackerTodayView()),
        seed: (r) => addLog(r, trackerDay, Prayer.witr, PrayerStatus.prayed),
      );
      final hint = find.text(_ar.trackerStatusVoluntaryDone);
      await tester.scrollUntilVisible(hint, 300, scrollable: find.byType(Scrollable).first);
      final worst = _worstContrast(_painted(tester, hint.first), MadarThemeId.pearl);
      expect(worst, greaterThanOrEqualTo(MadarContrast.text), reason: '$worst');
    });
  });

  group('prayer clock', () {
    testWidgets('times follow the 24-hour prayer clock and the location\'s wall clock', (tester) async {
      // Amman on a device whose clock runs in another zone (the test host
      // is UTC): the tracker must read like the prayer-times screen.
      final settings = const PrayerSettings().copyWith(clock24h: true, timeZone: 'Asia/Amman');
      final schedule = PrayerSchedule(settings);
      final times = schedule.timesFor(trackerDay);
      final now = times.asr.add(const Duration(minutes: 25));
      await _pump(
        tester,
        now: now,
        schedule: schedule,
        home: const Scaffold(body: TrackerTodayView()),
      );
      final clock = PrayerClockFormat(_fmtAr, h24: true, am: _ar.ptAm, pm: _ar.ptPm);
      final asr = clock.format(schedule.wallClock(times.asr)).joined;
      expect(asr, startsWith('١٥:'), reason: 'Asr in Amman is mid-afternoon');
      expect(find.text(asr), findsOneWidget);
      expect(find.text(_fmtAr.formatTime(times.asr)), findsNothing, reason: 'not the device zone / 12-hour clock');
    });
  });

  group('frames', () {
    testWidgets('the breathing "due" orb repaints only itself, never its whole card', (tester) async {
      AmbientMotion.debugOverride = true;
      addTearDown(() => AmbientMotion.debugOverride = null);
      await _pump(
        tester,
        now: afterAsr(),
        home: const Scaffold(body: TrackerTodayView()),
        settle: false,
      );
      // The repaint boundary that holds the Asr row (its name and its card).
      final name = tester.renderObject(find.text(_ar.prayerAsr));
      RenderObject? node = name.parent;
      while (node != null && node is! RenderRepaintBoundary) {
        node = node.parent;
      }
      final boundary = node! as RenderRepaintBoundary;
      expect(find.descendant(of: find.byType(StatusOrb), matching: find.byType(RepaintBoundary)), findsWidgets);
      boundary.debugResetMetrics();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        boundary.debugSymmetricPaintCount + boundary.debugAsymmetricPaintCount,
        0,
        reason: 'the breathing glow must not repaint the whole prayer card every frame',
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('history', () {
    test('the current month\'s totals run to today (future days are not "unlogged")', () {
      final today = DateTime(2026, 9, 28);
      final h = TrackerHistory.of(const [], today: today);
      expect(h.monthToDate(2026, 9).days, 28);
      expect(h.monthToDate(2026, 8).days, 31);
      expect(h.monthToDate(2026, 10).days, 0, reason: 'a future month has no days yet');
    });

    testWidgets('a long qada backlog is shown a page at a time', (tester) async {
      await _pump(
        tester,
        now: afterAsr(),
        home: const Scaffold(body: TrackerHistoryView()),
        seed: (r) async {
          for (var i = 1; i <= 40; i++) {
            await addLog(r, TrackerDays.add(trackerDay, -i), Prayer.fajr, PrayerStatus.missed);
          }
        },
      );
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text(_ar.trackerQadaTitle), 400, scrollable: list);
      await settleApp(tester);
      final rows = find.text(_ar.trackerActionMadeUp);
      expect(rows.evaluate().length, lessThanOrEqualTo(QadaLedgerView.pageSize));
      // The button offers the next page ("show 12 more").
      final more = find.text(_fmtAr.localizeDigits(_ar.trackerQadaShowMore(QadaLedgerView.pageSize)));
      await tester.scrollUntilVisible(more, 300, scrollable: list);
      await settleApp(tester);
      await tester.tap(more);
      await settleApp(tester);
      expect(rows.evaluate().length, lessThanOrEqualTo(QadaLedgerView.pageSize * 2));
      expect(rows.evaluate().length, greaterThan(QadaLedgerView.pageSize));
      // "Made them all up" still covers the whole (filtered) backlog.
      expect(find.text(_ar.trackerActionMakeUpAll(40)), findsOneWidget);
    });
  });

  group('marks on a missed prayer', () {
    late MadarDatabase db;
    setUp(() async => db = await openInMemoryMadarDatabase());
    tearDown(() => db.close());

    test('un-marking jamaah or mosque never turns a missed or unlogged prayer into prayed', () async {
      final repo = PrayerTrackerRepository(Repositories(db), clock: () => DateTime(2026, 9, 28, 17));
      await repo.setStatus(trackerDay, Prayer.asr, PrayerStatus.missed);
      await repo.setJamaah(trackerDay, Prayer.asr, false);
      await repo.setMosque(trackerDay, Prayer.asr, false);
      expect((await repo.logOf(trackerDay, Prayer.asr))?.status, PrayerStatus.missed);
      final c = await repo.setMosque(trackerDay, Prayer.maghrib, false);
      expect(c.changed, isFalse);
      expect(await repo.logOf(trackerDay, Prayer.maghrib), isNull);
      // Marking it (true) still logs it as prayed, as before.
      await repo.setJamaah(trackerDay, Prayer.asr, true);
      final asr = await repo.logOf(trackerDay, Prayer.asr);
      expect((asr?.status, asr?.inJamaah), (PrayerStatus.prayed, true));
    });
  });

  group('copy', () {
    testWidgets('after Isha with prayers unlogged, the header never claims they are complete', (tester) async {
      final t = trackerTimes();
      await _pump(
        tester,
        now: t.isha.add(const Duration(hours: 1)),
        home: const Scaffold(body: TrackerTodayView()),
        seed: (r) => addLog(r, trackerDay, Prayer.fajr, PrayerStatus.prayed),
      );
      expect(find.text(_ar.trackerNightLeft), findsOneWidget);
      // "اكتملت" = "are complete": only the real completion banner says so.
      expect(_ar.trackerNightLeft, isNot(contains('اكتمل')));
      expect(_en.trackerNightLeft.toLowerCase(), isNot(contains('complete')));
    });

    test('Arabic undo toasts agree with every prayer name (no feminine verb on الوتر / قيام الليل)', () {
      for (final p in TrackerPrayers.voluntary) {
        final name = _ar.trackerPrayerName(p);
        expect(_ar.trackerUndoVoluntaryOn(name), isNot(startsWith('سُجّلت')), reason: name);
        expect(_ar.trackerUndoVoluntaryOff(name), isNot(startsWith('أُلغيت')), reason: name);
      }
      expect(_ar.trackerUndoMadeUp(_ar.prayerFajr, 'x'), contains('صلاة ${_ar.prayerFajr}'));
    });

    testWidgets('the jamaah / mosque marks name their prayer for screen readers', (tester) async {
      await _pump(
        tester,
        now: afterAsr(),
        home: const Scaffold(body: TrackerTodayView()),
      );
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel(_ar.trackerValueOf(_ar.prayerAsr, _ar.trackerJamaah)), findsOneWidget);
      expect(find.bySemanticsLabel(_ar.trackerValueOf(_ar.prayerAsr, _ar.trackerMosque)), findsOneWidget);
      semantics.dispose();
    });
  });

  group('large text on a small phone (360 dp)', () {
    for (final scale in const [1.6, 2.0]) {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        testWidgets('x$scale $locale: both tabs and the compact card lay out without overflow', (tester) async {
          tester.view.physicalSize = const Size(360 * 3, 760 * 3);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          final db = await openTestDatabase(tester, seed: false);
          await tester.runAsync(() async {
            final r = Repositories(db);
            await seedHistory(r, trackerDay);
            await addLog(r, trackerDay, Prayer.asr, PrayerStatus.missed);
          });
          Widget scaled(Widget child) => Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child,
            ),
          );
          for (final home in [
            const PrayerTrackerScreen(),
            const PrayerTrackerScreen(initialTab: TrackerTab.history),
            MadarScaffold(
              body: ListView(children: [PrayerTodayCard(onOpen: () {})]),
            ),
          ]) {
            await tester.pumpWidget(
              trackerTestApp(
                home: scaled(home),
                overrides: trackerOverrides(db: db, now: afterAsr()),
                locale: locale,
              ),
            );
            await settleApp(tester);
            final list = find.byType(Scrollable).hitTestable().first;
            for (var i = 0; i < 10; i++) {
              await tester.drag(list, const Offset(0, -600));
              await settleApp(tester);
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        });
      }
    }
  });

  group('accessibility guidelines', () {
    final homes = <String, Widget Function()>{
      'today': () => const PrayerTrackerScreen(),
      'history': () => const PrayerTrackerScreen(initialTab: TrackerTab.history),
      'compact card': () => MadarScaffold(
        body: ListView(children: [PrayerTodayCard(onOpen: () {})]),
      ),
    };
    for (final e in homes.entries) {
      testWidgets('${e.key}: 48 dp tap targets, every one labelled', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pump(tester, now: afterAsr(), home: e.value(), seed: (r) => seedHistory(r, trackerDay));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }
  });
}
