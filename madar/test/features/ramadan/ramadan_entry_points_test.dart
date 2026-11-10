// Where «رمضان» is reached from: its tile in the Faith world's tool grid, its
// entry in Settings (next to the fasting one) and its route `/faith/ramadan`
// (the one a tap on the reminder opens) - in Arabic and in English, with back
// returning where it came from.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/ramadan/ramadan.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/presentation/planet/faith_hub.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';
import '../orbit/presentation/orbit_scene_fixtures.dart';

Future<void> _location(MadarDatabase db) => OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings());

/// A tool tile of the grid, by its semantics ("title. hint").
Finder _tool(String title) => find.bySemanticsLabel(RegExp('^${RegExp.escape(title)}\\. '));

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _revealOnPlanet(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _revealInList(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.runAsync(() async {});
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.5);
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['ar', 'en']) {
    final l = lookupL10n(Locale(lang));
    final settings = AppSettings(onboarded: true, languageCode: lang);

    testWidgets('$lang: a «رمضان» tile in the Faith tools opens the screen as a route, with the navigation sound', (tester) async {
      final app = await pumpMadarApp(
        tester,
        settings: settings,
        initialLocation: AppRoutes.planetOf('faith'),
        beforePump: _location,
        overrides: LockFixture.empty().overrides,
        settle: false,
      );
      await _frames(tester, 60);
      await settleApp(tester);
      expect(find.byType(FaithTools), findsOneWidget);

      final tile = _tool(l.ramadanTitle);
      await _revealOnPlanet(tester, tile);
      expect(tile, findsOneWidget);
      // Beside the other tools (the fasting one included), not instead of one.
      for (final title in [l.quranModeMushaf, l.hifzTitle, l.recitationTitle, l.adhkarTasbeehTitle, l.faithHubHistory, l.faithHubAdhanTool, l.fastRemTitle]) {
        await _revealOnPlanet(tester, _tool(title));
      }
      await _revealOnPlanet(tester, tile);
      // A 48 dp target at least.
      final size = tester.getSize(tile);
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));

      app.sound.played.clear();
      await tester.tap(tile);
      await settleApp(tester);
      expect(find.byType(RamadanScreen), findsOneWidget);
      expect(app.router.state.uri.toString(), AppRoutes.ramadan);
      expect(app.sound.played, contains(Sfx.navigate));
      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(find.byType(FaithHub), findsOneWidget, reason: 'back returns to the Faith page');
      expect(app.location, startsWith('/planet/faith'));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('$lang: the grid stays tidy with eight tools: rows of three, three and two, every tile the same size and in its column', (tester) async {
      await pumpMadarApp(
        tester,
        settings: settings,
        initialLocation: AppRoutes.planetOf('faith'),
        beforePump: _location,
        overrides: LockFixture.empty().overrides,
        settle: false,
      );
      await _frames(tester, 60);
      await settleApp(tester);
      final titles = [
        l.quranModeMushaf,
        l.hifzTitle,
        l.recitationTitle,
        l.adhkarTasbeehTitle,
        l.faithHubHistory,
        l.faithHubAdhanTool,
        l.fastRemTitle,
        l.ramadanTitle,
      ];
      await _revealOnPlanet(tester, _tool(l.ramadanTitle));
      final rects = [for (final t in titles) tester.getRect(_tool(t))];
      final rows = <double, List<Rect>>{};
      for (final r in rects) {
        rows.putIfAbsent(double.parse(r.top.toStringAsFixed(0)), () => []).add(r);
      }
      expect([for (final k in rows.keys.toList()..sort()) rows[k]!.length], [3, 3, 2]);
      final width = rects.first.width;
      for (final r in rects) {
        expect(r.width, closeTo(width, 0.5), reason: 'every tile is one size');
        expect(r.height, greaterThanOrEqualTo(48));
      }
      // The last row's tiles sit in the grid's own columns (at the start side).
      final firstRow = rows[rows.keys.reduce((a, b) => a < b ? a : b)]!;
      final lastRow = rows[rows.keys.reduce((a, b) => a > b ? a : b)]!;
      for (final r in lastRow) {
        expect(firstRow.any((f) => (f.left - r.left).abs() < 0.5), isTrue, reason: 'a column of its own');
      }
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('$lang: Settings holds a «رمضان» entry among the Faith ones', (tester) async {
      final app = await pumpMadarApp(
        tester,
        settings: settings,
        initialLocation: AppRoutes.settings,
        overrides: LockFixture.empty().overrides,
      );
      final entry = find.text(l.ramadanTitle);
      await _revealInList(tester, entry);
      expect(entry, findsOneWidget);
      expect(find.text(l.ramadanSubtitle), findsOneWidget);
      await tester.tap(entry);
      await settleApp(tester);
      expect(find.byType(RamadanScreen), findsOneWidget);
      expect(app.location, AppRoutes.ramadan);
      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(app.location, AppRoutes.home, reason: 'settings pages are entered with go, so back reaches home');
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('$lang: the route /faith/ramadan opens on its own (a notification tap) with home underneath', (tester) async {
      final app = await pumpMadarApp(
        tester,
        settings: settings,
        initialLocation: AppRoutes.ramadan,
        overrides: LockFixture.empty().overrides,
      );
      expect(find.byType(RamadanScreen), findsOneWidget);
      expect(app.location, '/faith/ramadan');
      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(app.location, AppRoutes.home);
      await tester.pump(const Duration(seconds: 6));
    });
  }
}
