// Madar Cinema's door on the Growth world's page: the marquee card sits in
// the Growth hub, reads as one button ("Madar Cinema. <line>. <shows>"),
// counts the programme's playable shows, chases its bulbs once (lit at once
// under reduced motion) and opens the hall as a route; back returns to the
// Growth page. In both languages.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/games/catalog.dart';
import 'package:madar/features/cinema/hall/hall.dart' show CinemaHallScreen;
import 'package:madar/features/growth/growth.dart' show GrowthTodayCard;
import 'package:madar/features/orbit/presentation/planet/cinema_entry_card.dart';
import 'package:madar/features/orbit/presentation/planet/life_hubs.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';

import '../../../helpers/screenshot_harness.dart' show madarScreenshotApp;
import '../../../helpers/test_app.dart';
import '../../lock/lock_test_utils.dart';

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final Finder _sheet = find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first;

void main() {
  test('the count is the programme\'s playable shows', () {
    expect(CinemaEntryCard.playableShows, CinemaCatalog.all.where((e) => e.isPlayable).length);
    expect(CinemaEntryCard.playableShows, greaterThanOrEqualTo(1), reason: 'the demo always plays');
  });

  for (final lang in ['ar', 'en']) {
    testWidgets('$lang: the Growth page\'s cinema card opens the hall; back returns to Growth', (tester) async {
      final l = lookupL10n(Locale(lang));
      final app = await pumpMadarApp(
        tester,
        settings: AppSettings(onboarded: true, languageCode: lang),
        initialLocation: AppRoutes.planetOf('growth'),
        overrides: LockFixture.empty().overrides,
        settle: false,
      );
      await _frames(tester, 60);
      await settleApp(tester);
      final card = find.byType(CinemaEntryCard);
      expect(find.descendant(of: find.byType(GrowthHub), matching: card), findsOneWidget);
      await tester.scrollUntilVisible(card, 250, scrollable: _sheet);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      // Right below today's learning card, above the tools.
      expect(tester.getTopLeft(card).dy, greaterThan(tester.getTopLeft(find.byType(GrowthTodayCard)).dy));
      expect(Directionality.of(tester.element(card)), lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      final count = CinemaEntryCard.playableShows;
      final shows = l.cinemaWiringShowsReady(count);
      // Arabic shows its digits in Arabic-Indic, like the rest of the page.
      final digits = lang == 'ar' ? '٠١٢٣٤٥٦٧٨٩'[count % 10] : '${count % 10}';
      expect(shows.contains('${count % 10}') || count <= 2, isTrue);
      expect(find.text(l.cinemaTitle), findsOneWidget);
      expect(find.text(l.cinemaWiringEnterHall), findsOneWidget);
      final shown = tester
          .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
          .map((t) => t.data ?? '')
          .where((s) => s.contains(lang == 'ar' ? 'جاهز' : 'ready'))
          .single;
      if (count > 2) expect(shown, contains(digits));
      if (lang == 'ar') expect(shown, isNot(contains(RegExp('[0-9]'))));
      // One button for screen readers, never the parts read again.
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('${l.cinemaTitle}. ${l.cinemaHallSubtitle}. $shown'), findsOneWidget);
      expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
      handle.dispose();

      app.sound.played.clear();
      await tester.tap(card);
      await _frames(tester, 30);
      expect(app.router.state.uri.toString(), AppRoutes.cinema);
      expect(find.byType(CinemaHallScreen), findsOneWidget);
      expect(app.sound.played, contains(Sfx.navigate));
      expect(tester.takeException(), isNull);

      await tester.binding.handlePopRoute();
      await _frames(tester, 30);
      expect(find.byType(CinemaHallScreen), findsNothing);
      expect(app.router.state.uri.toString(), AppRoutes.planetOf('growth'));
      expect(find.byType(GrowthHub), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  testWidgets('the bulbs chase once and rest lit; under reduced motion they are lit at once', (tester) async {
    var opened = 0;
    Widget card({required bool reduced}) => madarScreenshotApp(
      locale: const Locale('en'),
      home: MotionScope(
        reduced: reduced,
        child: Scaffold(
          body: Center(child: CinemaEntryCard(readyShows: 2, onOpen: (_) => opened++)),
        ),
      ),
    );

    await tester.pumpWidget(card(reduced: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue, reason: 'the bulbs chase');
    await tester.pump(const Duration(milliseconds: 1600));
    expect(tester.hasRunningAnimations, isFalse, reason: 'one run, then the bulbs rest (the page can settle)');
    expect(find.text('2 shows ready to play'), findsOneWidget);
    await tester.tap(find.byType(CinemaEntryCard));
    expect(opened, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(card(reduced: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse, reason: 'lit at once, nothing moves');
  });
}
