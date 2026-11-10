// The Faith planet in Ramadan: the month turns itself on at its first day and
// off at the Eid with no action from him - the atmosphere (a still crescent
// and lanterns strip and a warm tint), the Ramadan card with the day, the live
// countdown, tonight's Taraweeh, today's khatmah portion and the last ten
// nights - and none of it outside the month. The home clock is frozen inside
// and outside Ramadan, at the Hijri shift -1, 0 and +1, in Arabic and English.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/islamic_geometry/islamic_geometry.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/presentation/planet/faith_hub.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/ramadan/ramadan.dart';

import '../../helpers/screenshot_harness.dart';
import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';
import '../orbit/presentation/orbit_scene_fixtures.dart';

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first,
  );
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 200));
}

Future<TestApp> _pumpFaith(
  WidgetTester tester, {
  required DateTime now,
  String lang = 'ar',
  int offset = 0,
  RamadanConfig? config,
  Future<void> Function(MadarDatabase db)? seed,
}) async {
  final app = await pumpMadarApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang),
    initialLocation: AppRoutes.planetOf('faith'),
    now: now,
    beforePump: (db) async {
      final repos = Repositories(db);
      await OrbitRepository(repos).setPrayerSettings(hostPrayerSettings().copyWith(hijriOffsetDays: offset));
      if (config != null) await RamadanRepository(repos.keyValues).saveConfig(config);
      await seed?.call(db);
    },
    overrides: LockFixture.empty().overrides,
    settle: false,
  );
  await _frames(tester, 60);
  await settleApp(tester);
  return app;
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
}

final _card = find.byKey(const ValueKey('ramadan.card'));
final _coming = find.byKey(const ValueKey('ramadan.coming'));
final _band = find.byType(RamadanAtmosphereBand);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  for (final lang in ['ar', 'en']) {
    final l = lookupL10n(Locale(lang));
    final texts = RamadanTexts.forLanguage(lang);

    group(lang, () {
      testWidgets('inside Ramadan (day 13): the atmosphere and the card with the day, the iftar countdown, tonight\'s Taraweeh and the portion', (tester) async {
        await _pumpFaith(tester, now: DateTime(2027, 2, 20, 12), lang: lang);
        expect(_band, findsOneWidget, reason: 'the atmosphere is on');
        await _reveal(tester, _card);
        expect(_card, findsOneWidget);
        expect(find.descendant(of: _card, matching: find.text(l.ramadanDayOf(texts.number(13)))), findsOneWidget);
        // By day: counting down to iftar, with a ticking h:mm:ss.
        expect(find.byKey(const ValueKey('ramadan.countdown.iftar')), findsOneWidget);
        expect(find.byKey(const ValueKey('ramadan.countdown.suhoorEnd')), findsNothing);
        expect(find.text(l.ramadanIftarIn), findsOneWidget);
        expect(find.byKey(const ValueKey('ramadan.countdown.time')), findsOneWidget);
        // Tonight is night 14.
        expect(find.descendant(of: _card, matching: find.text(l.ramadanTaraweehTonight(texts.number(14)))), findsOneWidget);
        // Today's portion with the way into the Quran.
        expect(find.byKey(const ValueKey('ramadan.card.portion')), findsOneWidget);
        expect(find.byKey(const ValueKey('ramadan.card.openQuran')), findsOneWidget);
        expect(find.text(l.ramadanKhatmahOpenQuran), findsOneWidget);
        // Day 13 is before the last ten: no strip.
        expect(find.byKey(const ValueKey('ramadan.card.lastTen')), findsNothing);
        expect(tester.takeException(), isNull);
        await _leave(tester);
      });

      testWidgets('after Maghrib the countdown is to the end of suhoor', (tester) async {
        await _pumpFaith(tester, now: DateTime(2027, 2, 20, 22), lang: lang);
        await _reveal(tester, _card);
        expect(find.byKey(const ValueKey('ramadan.countdown.suhoorEnd')), findsOneWidget);
        expect(find.byKey(const ValueKey('ramadan.countdown.iftar')), findsNothing);
        expect(find.text(l.ramadanSuhoorEndsIn), findsOneWidget);
        await _leave(tester);
      });

      testWidgets('tonight\'s Taraweeh: one tap logs night 14, a second un-logs it, each with an undo', (tester) async {
        final app = await _pumpFaith(tester, now: DateTime(2027, 2, 20, 12), lang: lang);
        final tonight = find.byKey(const ValueKey('ramadan.card.tonight'));
        await _reveal(tester, tonight);
        Future<bool> logged() async =>
            (await tester.runAsync(() => RamadanRepository(app.repos.keyValues).logBook()))!.of(1448)?.taraweeh.isDone(14) ?? false;
        expect(await logged(), isFalse);
        expect(tester.getSize(tonight).height, greaterThanOrEqualTo(48));
        await tester.tap(tonight);
        await _frames(tester, 20);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await _frames(tester, 10);
        expect(await logged(), isTrue);
        expect(find.text(l.ramadanTaraweehLoggedToast), findsOneWidget);
        // The undo toast takes it back.
        await tester.tap(find.text(l.actionUndo));
        await _frames(tester, 20);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await _frames(tester, 10);
        expect(await logged(), isFalse);
        await _leave(tester);
      });

      testWidgets('the Quran button opens the reader at today\'s first page', (tester) async {
        final app = await _pumpFaith(tester, now: DateTime(2027, 2, 20, 12), lang: lang);
        final open = find.byKey(const ValueKey('ramadan.card.openQuran'));
        await _reveal(tester, open);
        expect(tester.getSize(open).height, greaterThanOrEqualTo(40));
        await tester.tap(open);
        await _frames(tester, 20);
        // Day 13 of 29: 604 pages in 29 days, 12 days done at 21 and 20: page 12×(20 or 21)+1.
        final today = app.container.read(ramadanKhatmahTodayProvider);
        expect(app.router.state.uri.path, AppRoutes.quranReader);
        expect(app.router.state.uri.queryParameters['page'], '${today.portion.fromPage}');
        await _leave(tester);
      });

      testWidgets('the last ten nights: on day 22 tonight is night 23, an odd night, and the card says so', (tester) async {
        await _pumpFaith(tester, now: DateTime(2027, 3, 1, 12), lang: lang); // day 22
        await _reveal(tester, _card);
        final strip = find.byKey(const ValueKey('ramadan.card.lastTen'));
        expect(strip, findsOneWidget);
        expect(find.descendant(of: strip, matching: find.textContaining(l.ramadanLastTenOdd)), findsOneWidget);
        await _leave(tester);
      });

      testWidgets('before Ramadan (19 days): no atmosphere; a countdown to Ramadan instead of the month\'s card', (tester) async {
        await _pumpFaith(tester, now: DateTime(2027, 1, 20, 12), lang: lang);
        expect(_band, findsNothing);
        expect(_card, findsNothing);
        await _reveal(tester, _coming);
        expect(find.text(l.ramadanComingTitle(texts.days(19))), findsOneWidget);
        await _leave(tester);
      });

      testWidgets('the day before: «رمضان بكرة»; that evening, after Maghrib, night 1 already shows the month\'s card', (tester) async {
        await _pumpFaith(tester, now: DateTime(2027, 2, 7, 12), lang: lang);
        await _reveal(tester, _coming);
        expect(find.text(l.ramadanComingTomorrow), findsOneWidget);
        expect(_band, findsNothing, reason: 'the atmosphere starts with the first day');
        await _leave(tester);
        await _pumpFaith(tester, now: DateTime(2027, 2, 7, 20), lang: lang);
        await _reveal(tester, _card);
        expect(find.descendant(of: _card, matching: find.text(l.ramadanNightOf(texts.number(1)))), findsOneWidget);
        expect(find.byKey(const ValueKey('ramadan.countdown.suhoorEnd')), findsOneWidget);
        expect(_band, findsNothing);
        await _leave(tester);
      });

      testWidgets('a far-off day (November): nothing of Ramadan on the planet, but its tile is there', (tester) async {
        await _pumpFaith(tester, now: DateTime(2026, 11, 10, 12), lang: lang);
        expect(_band, findsNothing);
        expect(_card, findsNothing);
        expect(_coming, findsNothing);
        expect(find.byType(FaithTools), findsOneWidget);
        await _leave(tester);
      });

      testWidgets('the first day turns the atmosphere on by itself, the last day still has it, 1 Shawwal takes it away', (tester) async {
        await _pumpFaith(tester, now: DateTime(2027, 2, 8, 9), lang: lang);
        expect(_band, findsOneWidget, reason: 'first day of Ramadan');
        await _reveal(tester, _card);
        expect(find.descendant(of: _card, matching: find.text(l.ramadanDayOf(texts.number(1)))), findsOneWidget);
        await _leave(tester);

        await _pumpFaith(tester, now: DateTime(2027, 3, 8, 9), lang: lang);
        expect(_band, findsOneWidget, reason: 'the last day, 29 Ramadan');
        await _leave(tester);

        await _pumpFaith(tester, now: DateTime(2027, 3, 9, 9), lang: lang);
        expect(_band, findsNothing, reason: '1 Shawwal: the Eid is not Ramadan');
        expect(_card, findsNothing);
        expect(_coming, findsNothing);
        await _leave(tester);
      });

      testWidgets('he can switch «أجواء رمضان» off: the strip goes, the card stays', (tester) async {
        await _pumpFaith(tester, now: DateTime(2027, 2, 20, 12), lang: lang, config: const RamadanConfig(atmosphere: false));
        expect(_band, findsNothing);
        await _reveal(tester, _card);
        expect(_card, findsOneWidget);
        await _leave(tester);
      });

      testWidgets('his khatmah switch off: the portion leaves the card, the rest stays', (tester) async {
        await _pumpFaith(tester, now: DateTime(2027, 2, 20, 12), lang: lang, config: const RamadanConfig(hubKhatmah: false));
        await _reveal(tester, _card);
        expect(find.byKey(const ValueKey('ramadan.card.portion')), findsNothing);
        expect(find.byKey(const ValueKey('ramadan.card.tonight')), findsOneWidget);
        await _leave(tester);
      });
    });
  }

  group('the Hijri shift moves the month: the same civil day, three answers', () {
    // 8 February 2027 at noon is the first day under 0, the day before under -1 and the second day under +1.
    for (final (offset, day) in [(-1, null), (0, 1), (1, 2)]) {
      testWidgets('offset $offset on 8 February: ${day == null ? 'the day before Ramadan' : 'day $day of Ramadan'}', (tester) async {
        final l = lookupL10n(const Locale('ar'));
        final texts = RamadanTexts.forLanguage('ar');
        await _pumpFaith(tester, now: DateTime(2027, 2, 8, 12), offset: offset);
        if (day == null) {
          expect(_band, findsNothing);
          expect(_card, findsNothing);
          await _reveal(tester, _coming);
          expect(find.text(l.ramadanComingTomorrow), findsOneWidget);
        } else {
          expect(_band, findsOneWidget);
          await _reveal(tester, _card);
          expect(find.descendant(of: _card, matching: find.text(l.ramadanDayOf(texts.number(day)))), findsOneWidget);
        }
        await _leave(tester);
      });
    }

    testWidgets('+1 on 7 February: Ramadan has already begun (the local month started a day earlier)', (tester) async {
      await _pumpFaith(tester, now: DateTime(2027, 2, 7, 12), offset: 1);
      expect(_band, findsOneWidget);
      await _leave(tester);
    });

    testWidgets('-1 on 9 March (the Eid by the calculation) is still the last day of Ramadan', (tester) async {
      await _pumpFaith(tester, now: DateTime(2027, 3, 9, 12), offset: -1);
      expect(_band, findsOneWidget, reason: 'the local month ends a day later');
      await _leave(tester);
    });
  });

  group('the atmosphere itself', () {
    for (final theme in [MadarThemeId.lapis, MadarThemeId.pearl]) {
      testWidgets('${theme.name}: the strip is drawn once into a cached picture and never animates', (tester) async {
        tester.view.physicalSize = const Size(640, 900);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        PatternPictureCache.debugReset();
        await tester.pumpWidget(
          madarScreenshotApp(
            theme: theme,
            home: const Scaffold(body: Stack(children: [Positioned.fill(child: RamadanTint()), RamadanAtmosphereBand()])),
          ),
        );
        await tester.pump();
        final built = PatternPictureCache.builds;
        expect(built, greaterThan(0));
        expect(tester.hasRunningAnimations, isFalse, reason: 'a still image: nothing for reduced motion to switch off');
        // Frames later the picture is reused, nothing is re-recorded.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(PatternPictureCache.builds, built);
        expect(tester.takeException(), isNull);
      });
    }

    test('the painter repaints only when its colours change', () {
      final a = RamadanSkyPainter(metal: Colors.amber, glow: Colors.amber, thread: Colors.brown, dark: true);
      expect(a.shouldRepaint(RamadanSkyPainter(metal: Colors.amber, glow: Colors.amber, thread: Colors.brown, dark: true)), isFalse);
      expect(a.shouldRepaint(RamadanSkyPainter(metal: Colors.amber, glow: Colors.amber, thread: Colors.brown, dark: false)), isTrue);
    });
  });
}
