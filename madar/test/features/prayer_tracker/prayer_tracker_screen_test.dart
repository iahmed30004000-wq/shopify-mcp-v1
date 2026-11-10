import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/i18n/gen/app_localizations_ar.dart';
import 'package:madar/core/i18n/gen/app_localizations_en.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/prayer_tracker/prayer_tracker.dart';
import 'package:madar/features/prayer_tracker/presentation/tracker_labels.dart';

import '../../helpers/test_app.dart' show RecordingHaptics, openTestDatabase, settleApp, usePhoneSurface;
import 'tracker_fixtures.dart';

final L10n _ar = L10nAr();
final L10n _en = L10nEn();
const _fmtAr = MadarFormatter(languageCode: 'ar');

/// A pumped tracker widget over an in-memory database.
class _Tracker {
  _Tracker(this.tester, this.db, this.sound, this.haptics);

  final WidgetTester tester;
  final MadarDatabase db;
  final SilentSoundService sound;
  final RecordingHaptics haptics;

  Repositories get repos => Repositories(db);

  Future<List<PrayerLogRow>> logs() async => (await tester.runAsync(() => repos.prayerLogs.getAll()))!;

  Future<PrayerLogRow?> log(Prayer p, [DateTime? day]) async {
    final key = TrackerDays.key(day ?? trackerDay);
    return (await logs()).where((l) => l.prayer == p && l.day == key).firstOrNull;
  }

  Future<List<ActivityRow>> activity() async =>
      (await tester.runAsync(() => repos.activity.since(DateTime(2026), planetKey: 'faith')))!;
}

Future<_Tracker> _pump(
  WidgetTester tester, {
  required DateTime now,
  Widget home = const PrayerTrackerScreen(),
  Locale locale = const Locale('ar'),
  bool reducedMotion = false,
  Future<void> Function(Repositories repos)? seed,
}) async {
  usePhoneSurface(tester);
  final db = await openTestDatabase(tester, seed: false);
  if (seed != null) await tester.runAsync(() => seed(Repositories(db)));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  await tester.pumpWidget(
    trackerTestApp(
      home: home,
      overrides: trackerOverrides(db: db, now: now),
      locale: locale,
      reducedMotion: reducedMotion,
    ),
  );
  await settleApp(tester);
  return _Tracker(tester, db, sound, haptics);
}

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Lets a write reach the database and the stream come back.
Future<void> _write(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await _frames(tester, 6);
}

Finder _visible(String text) => find.text(text).hitTestable();

void main() {
  group('Today (Arabic)', () {
    testWidgets('shows the five prayers right-to-left: done, due and not yet due', (tester) async {
      await _pump(
        tester,
        now: afterAsr(),
        seed: (r) async {
          await addLog(r, trackerDay, Prayer.fajr, PrayerStatus.prayed, jamaah: true);
          await addLog(r, trackerDay, Prayer.dhuhr, PrayerStatus.late);
        },
      );
      expect(find.text(_ar.trackerTitle), findsOneWidget);
      for (final p in TrackerPrayers.obligatory) {
        expect(_visible(_ar.trackerPrayerName(p)), findsOneWidget, reason: '$p');
      }
      expect(_visible(_ar.trackerStatusPrayed), findsWidgets);
      expect(_visible(_ar.trackerStatusLate), findsWidgets);
      expect(find.textContaining(_ar.trackerStatusDue), findsOneWidget);
      // Arabic-Indic digits and right-to-left layout.
      expect(find.text('٢'), findsOneWidget, reason: 'two of five prayed, in the ring');
      final fajr = tester.getCenter(find.text(_ar.prayerFajr));
      final jamaah = tester.getCenter(find.text(_ar.trackerJamaah).first);
      expect(fajr.dx, greaterThan(jamaah.dx), reason: 'the name starts at the right, the marks sit at the left');
      expect(Directionality.of(tester.element(find.text(_ar.prayerFajr))), TextDirection.rtl);
    });

    testWidgets('a tap cycles prayed → late, with its sound, a Faith completion and an undo toast', (tester) async {
      final t = await _pump(tester, now: afterAsr());
      await tester.tap(_visible(_ar.prayerAsr));
      await _write(tester);
      expect((await t.log(Prayer.asr))?.status, PrayerStatus.prayed);
      expect(t.sound.played, contains(Sfx.prayerLit));
      expect(t.haptics.fired, contains(Haptic.heavy));
      expect((await t.activity()).single.kind, PrayerTrackerRepository.obligatoryKind);
      expect(find.text(_ar.trackerUndoStatus(_ar.prayerAsr, _ar.trackerStatusPrayed)), findsOneWidget);

      await tester.tap(_visible(_ar.prayerAsr));
      await _write(tester);
      expect((await t.log(Prayer.asr))?.status, PrayerStatus.late);
      expect(find.text(_ar.trackerUndoStatus(_ar.prayerAsr, _ar.trackerStatusLate)), findsOneWidget);

      await tester.tap(find.text(_ar.actionUndo).last);
      await _write(tester);
      expect((await t.log(Prayer.asr))?.status, PrayerStatus.prayed, reason: 'undo restores the step before');
      await settleApp(tester);
    });

    testWidgets('a prayer whose time has not come cannot be logged', (tester) async {
      final t = await _pump(tester, now: afterAsr());
      await tester.tap(_visible(_ar.prayerMaghrib));
      await _write(tester);
      expect(await t.logs(), isEmpty);
      expect(t.sound.played, contains(Sfx.error));
      expect(find.textContaining(_ar.trackerUpcomingIn('').trim()), findsWidgets);
      await settleApp(tester);
    });

    testWidgets('the jamaah mark logs an unlogged prayer as prayed in jamaah; mosque toggles on its own', (
      tester,
    ) async {
      final t = await _pump(tester, now: afterAsr());
      // The Asr row is the third; its jamaah toggle is the third visible one.
      await tester.tap(_visible(_ar.trackerJamaah).at(2));
      await _write(tester);
      final asr = (await t.log(Prayer.asr))!;
      expect((asr.status, asr.inJamaah, asr.atMosque), (PrayerStatus.prayed, true, false));
      expect(t.sound.played, contains(Sfx.toggleOn));
      await tester.tap(_visible(_ar.trackerMosque).at(2));
      await _write(tester);
      final again = (await t.log(Prayer.asr))!;
      expect((again.inJamaah, again.atMosque), (true, true));
      expect(await t.activity(), hasLength(1), reason: 'marks never add completions');
      await settleApp(tester);
    });

    testWidgets('the sunnah row under its fard toggles the rawatib', (tester) async {
      final t = await _pump(tester, now: afterAsr());
      await tester.tap(find.textContaining(_ar.trackerSunnahDhuhr, findRichText: true).hitTestable());
      await _write(tester);
      expect((await t.log(Prayer.sunnahDhuhr))?.status, PrayerStatus.prayed);
      expect((await t.activity()).single.kind, PrayerTrackerRepository.voluntaryKind);
      // The Maghrib sunnah is not due yet.
      await tester.tap(find.textContaining(_ar.trackerSunnahMaghrib, findRichText: true).hitTestable());
      await _write(tester);
      expect(await t.log(Prayer.sunnahMaghrib), isNull);
      await settleApp(tester);
    });

    testWidgets('swipe right logs the prayer on time', (tester) async {
      final t = await _pump(tester, now: afterAsr());
      await tester.drag(_visible(_ar.prayerFajr), const Offset(300, 0));
      await _write(tester);
      await _frames(tester, 20);
      expect((await t.log(Prayer.fajr))?.status, PrayerStatus.prayed);
      expect(t.sound.played, contains(Sfx.complete));
      await settleApp(tester);
    });

    testWidgets('long-press menu: missed, then made up', (tester) async {
      final t = await _pump(tester, now: afterAsr());
      await tester.longPress(_visible(_ar.prayerDhuhr));
      await settleApp(tester);
      await tester.tap(find.text(_ar.trackerActionMissed));
      await _write(tester);
      await settleApp(tester);
      expect((await t.log(Prayer.dhuhr))?.status, PrayerStatus.missed);
      await tester.longPress(_visible(_ar.prayerDhuhr));
      await settleApp(tester);
      await tester.tap(find.text(_ar.trackerActionMadeUp));
      await _write(tester);
      await settleApp(tester);
      final dhuhr = (await t.log(Prayer.dhuhr))!;
      expect((dhuhr.status, dhuhr.day), (PrayerStatus.qada, TrackerDays.key(trackerDay)));
    });

    testWidgets('the fifth prayer completes the day: the chime and the blessing', (tester) async {
      final times = trackerTimes();
      final t = await _pump(
        tester,
        now: times.isha.add(const Duration(minutes: 30)),
        seed: (r) async {
          for (final p in TrackerPrayers.obligatory.take(4)) {
            await addLog(r, trackerDay, p, PrayerStatus.prayed);
          }
        },
      );
      expect(find.text(_ar.trackerAllDone), findsNothing);
      expect(t.sound.played, isNot(contains(Sfx.levelUp)), reason: 'never on first build');
      await tester.tap(_visible(_ar.prayerIsha));
      await _write(tester);
      await _frames(tester, 10);
      expect(t.sound.played, contains(Sfx.levelUp));
      expect(find.text(_ar.trackerAllDone), findsOneWidget);
      await settleApp(tester);
    });

    testWidgets('nawafil tiles toggle Duha, Witr and the night prayer', (tester) async {
      final times = trackerTimes();
      final t = await _pump(tester, now: times.isha.add(const Duration(hours: 1)));
      await tester.scrollUntilVisible(
        find.text(_ar.trackerWitr),
        300,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await settleApp(tester);
      await tester.tap(_visible(_ar.trackerWitr));
      await _write(tester);
      expect((await t.log(Prayer.witr))?.status, PrayerStatus.prayed);
      await tester.tap(_visible(_ar.trackerWitr));
      await _write(tester);
      expect(await t.log(Prayer.witr), isNull, reason: 'a second tap removes it');
      await settleApp(tester);
    });
  });

  group('History (Arabic)', () {
    testWidgets('streaks, the week strip and the heatmap follow the logs; a day opens its sheet', (tester) async {
      await _pump(
        tester,
        now: afterAsr(),
        seed: (r) async {
          for (var i = 1; i <= 3; i++) {
            for (final p in TrackerPrayers.obligatory) {
              await addLog(r, TrackerDays.add(trackerDay, -i), p, PrayerStatus.prayed, jamaah: p == Prayer.fajr);
            }
          }
        },
      );
      await tester.tap(_visible(_ar.trackerTabHistory));
      await settleApp(tester);
      expect(_visible(_ar.trackerStreakCurrent), findsOneWidget);
      expect(_visible(_ar.trackerStreakBest), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          _ar.trackerValueOf(_ar.trackerStreakCurrent, _fmtAr.localizeDigits(_ar.trackerStreakDays(3))),
        ),
        findsOneWidget,
        reason: 'a three-day streak, in Arabic-Indic digits',
      );
      // The week strip: tap yesterday → its day sheet.
      final yesterday = TrackerDays.add(trackerDay, -1);
      final label = _ar.trackerDaySemantics(
        _fmtAr.formatDate(yesterday, style: MadarDateStyle.weekdayDayMonth),
        '٥',
        '٥',
        '١',
      );
      expect(find.bySemanticsLabel(label), findsWidgets);
      await tester.tap(find.bySemanticsLabel(label).first);
      await settleApp(tester);
      expect(find.byType(TrackerDaySheet), findsOneWidget);
      expect(find.text(_ar.trackerProgress('٥', '٥')), findsOneWidget);
    });

    testWidgets('the qada ledger lists missed prayers, filters by prayer and makes them up', (tester) async {
      final t = await _pump(
        tester,
        now: afterAsr(),
        seed: (r) async {
          await addLog(r, DateTime(2026, 9, 20), Prayer.fajr, PrayerStatus.missed);
          await addLog(r, DateTime(2026, 9, 21), Prayer.isha, PrayerStatus.missed);
          await addLog(r, DateTime(2026, 9, 22), Prayer.asr, PrayerStatus.qada);
        },
      );
      await tester.tap(_visible(_ar.trackerTabHistory));
      await settleApp(tester);
      final list = find.byType(Scrollable).hitTestable().first;
      await tester.scrollUntilVisible(find.text(_ar.trackerQadaTitle), 400, scrollable: list);
      await tester.scrollUntilVisible(find.text(_ar.trackerQadaMadeUpSoFar('١')), 300, scrollable: list);
      await settleApp(tester);
      expect(find.text('${_ar.trackerFilterAll} ٢'), findsOneWidget);
      expect(_visible(_ar.trackerActionMadeUp), findsNWidgets(2));

      await tester.ensureVisible(find.text('${_ar.prayerIsha} ١'));
      await settleApp(tester);
      await tester.tap(find.text('${_ar.prayerIsha} ١'));
      await settleApp(tester);
      expect(_visible(_ar.trackerActionMadeUp), findsOneWidget);

      await tester.tap(_visible(_ar.trackerActionMadeUp));
      await _write(tester);
      final isha = (await t.logs()).firstWhere((l) => l.prayer == Prayer.isha);
      expect((isha.status, isha.day), (PrayerStatus.qada, '2026-09-21'));
      expect(t.sound.played, contains(Sfx.complete));
      // The row has left the ledger, yet its undo toast still appears.
      final date = _fmtAr.formatDate(DateTime(2026, 9, 21), style: MadarDateStyle.dayMonth);
      expect(find.text(_ar.trackerUndoMadeUp(_ar.prayerIsha, date)), findsOneWidget);
      await settleApp(tester);
      expect(find.text(_ar.trackerQadaEmptyFiltered(_ar.prayerIsha)), findsOneWidget);
    });
  });

  group('English', () {
    testWidgets('left-to-right with English labels and Western digits', (tester) async {
      final t = await _pump(
        tester,
        now: afterAsr(),
        locale: const Locale('en'),
        seed: (r) => addLog(r, trackerDay, Prayer.fajr, PrayerStatus.prayed),
      );
      expect(find.text('Prayer tracker'), findsOneWidget);
      expect(_visible('Fajr'), findsOneWidget);
      expect(_visible(_en.trackerStatusPrayed), findsWidgets);
      expect(find.text('1'), findsOneWidget);
      expect(find.text(_en.trackerOfTotal('5')), findsOneWidget);
      final fajr = tester.getCenter(find.text('Fajr'));
      final jamaah = tester.getCenter(find.text(_en.trackerJamaah).first);
      expect(fajr.dx, lessThan(jamaah.dx));
      await tester.tap(_visible('Dhuhr'));
      await _write(tester);
      expect((await t.log(Prayer.dhuhr))?.status, PrayerStatus.prayed);
      expect(find.text(_en.trackerUndoStatus('Dhuhr', 'On time')), findsOneWidget);
      await settleApp(tester);

      await tester.tap(_visible(_en.trackerTabHistory));
      await settleApp(tester);
      expect(_visible(_en.trackerStreakCurrent), findsOneWidget);
      expect(_visible('September 2026'), findsOneWidget);
    });
  });

  group('PrayerTodayCard', () {
    testWidgets('the compact card cycles a prayer and opens the tracker', (tester) async {
      var opened = 0;
      final t = await _pump(
        tester,
        now: afterAsr(),
        home: MadarScaffold(
          body: ListView(children: [PrayerTodayCard(onOpen: () => opened++)]),
        ),
      );
      expect(find.text(_ar.trackerTodayPrayed), findsOneWidget);
      await tester.tap(find.text(_ar.prayerFajr));
      await _write(tester);
      expect((await t.log(Prayer.fajr))?.status, PrayerStatus.prayed);
      await tester.tap(find.text(_ar.trackerTodayPrayed));
      await tester.pump();
      expect(opened, 1);
      expect(t.sound.played, contains(Sfx.navigate));
      // Not yet due: nothing logged.
      await tester.tap(find.text(_ar.prayerIsha));
      await _write(tester);
      expect(await t.log(Prayer.isha), isNull);
      await settleApp(tester);
    });
  });

  // B1 (APK #15): the tab bodies used to pile up on each other.
  testWidgets('only the selected tab is in the tree', (tester) async {
    await _pump(tester, now: afterAsr());
    void only(String key) {
      for (final k in ['tracker.today', 'tracker.history']) {
        expect(find.byKey(ValueKey(k)), k == key ? findsOneWidget : findsNothing, reason: 'expected only $key');
      }
    }

    only('tracker.today');
    await tester.tap(find.bySemanticsLabel(_ar.trackerTabHistory).first);
    await settleApp(tester);
    only('tracker.history');
    await tester.tap(find.bySemanticsLabel(_ar.trackerTabToday).first);
    await settleApp(tester);
    only('tracker.today');
  });

  testWidgets('reduced motion still logs and shows no shake', (tester) async {
    final t = await _pump(tester, now: afterAsr(), reducedMotion: true);
    await tester.tap(_visible(_ar.prayerMaghrib));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byWidgetPredicate((w) => w is Transform && w.transform.getTranslation().x != 0), findsNothing);
    await tester.tap(_visible(_ar.prayerFajr));
    await _write(tester);
    expect((await t.log(Prayer.fajr))?.status, PrayerStatus.prayed);
    await settleApp(tester);
  });
}
