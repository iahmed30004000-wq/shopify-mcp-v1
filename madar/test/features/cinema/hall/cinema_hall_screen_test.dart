import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/games/catalog.dart';
import 'package:madar/features/cinema/hall/hall.dart';
import 'package:madar/features/cinema/hall/lobby/programme.dart';

import '../cinema_fakes.dart';
import '../../../helpers/screenshot_harness.dart';
import 'hall_fakes.dart';

class _Tiny extends CinemaGame {
  _Tiny({required super.context}) : super(skin: EraSkins.of(Era.rubberHose));

  @override
  String get gameId => 'demo';

  @override
  Future<void> onSceneLoad() async {}
}

void main() {
  final ar = lookupL10n(const Locale('ar'));

  setUpAll(() async => CinemaShaders.preload());

  Future<HallTestEnv> pumpHall(
    WidgetTester tester, {
    CinemaRecords records = CinemaRecords.empty,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(412, 5200) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final env = HallTestEnv(records: records);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...env.overrides, ...extra],
        child: madarScreenshotApp(home: const CinemaHallScreen()),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return env;
  }

  testWidgets('the lobby: marquee, now showing, the programme, ticket book and the Saved Games slot', (tester) async {
    await pumpHall(tester);
    expect(find.text(ar.cinemaTitle), findsOneWidget);
    expect(find.text(ar.cinemaHallNowShowing), findsOneWidget);
    expect(find.text(ar.cinemaHallProgramme), findsOneWidget);
    // The first feature's billing and a coming-soon ticket.
    final first = CinemaCatalog.ofTier(GameTier.feature).first;
    expect(find.text(first.tagline(ar)), findsOneWidget);
    expect(find.text(ar.cinemaComingSoon), findsOneWidget);
    // Shelves: features, five announced Tier 2 kinds, backstage (the demo).
    for (final s in [ar.cinemaFeatures, ar.cinemaHallGenreCards, ar.cinemaHallGenreWord, ar.cinemaHallBackstage]) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(find.byType(LockedSlot), findsNWidgets(15), reason: 'three coming attractions on each Tier 2 shelf');
    expect(find.text(ar.cinemaDemoTitle), findsWidgets);
    expect(find.text(ar.cinemaHallFirstTicket), findsOneWidget);
    expect(find.byType(SavedGamesShelf), findsOneWidget);
  });

  Future<void> tapChip(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(TicketChip, label);
    await tester.ensureVisible(chip);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('filters by era, by kind and to ready-to-play shows', (tester) async {
    await pumpHall(tester);
    await tapChip(tester, ar.cinemaEraTechnicolor);
    expect(find.byType(MiniPoster), findsOneWidget, reason: 'Caravan Dash is the only 1950s show');
    expect(find.byType(LockedSlot), findsNothing);
    await tapChip(tester, ar.cinemaHallAllEras);
    await tapChip(tester, ar.cinemaHallReadyOnly);
    expect(find.byType(MiniPoster), findsOneWidget, reason: 'only the rehearsal is playable today');
    expect(find.text(ar.cinemaHallBackstage), findsWidgets);
    await tapChip(tester, ar.cinemaHallReadyOnly);
    await tapChip(tester, ar.cinemaHallGenreCards);
    expect(find.byType(LockedSlot), findsNWidgets(3));
    expect(find.byType(MiniPoster), findsNothing);
  });

  testWidgets('a coming-soon show explains itself instead of opening', (tester) async {
    await pumpHall(tester);
    await tester.tap(find.text(ar.cinemaComingSoon));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(ar.cinemaHallLockedHint), findsOneWidget);
    expect(find.byType(CinemaGameScreen), findsNothing);
  });

  testWidgets('the ticket book shows plays, happy endings, time and the favourite', (tester) async {
    await pumpHall(
      tester,
      records: const CinemaRecords({
        'demo': GameRecord(gameId: 'demo', best: 1240, plays: 7, wins: 4, playTime: Duration(minutes: 38)),
      }),
    );
    expect(find.text('٧'), findsOneWidget);
    expect(find.text('٤'), findsOneWidget);
    expect(find.text(ar.cinemaHallStatFavourite), findsOneWidget);
    expect(
      find.text(ar.cinemaHallBestBadge('١٬٢٤٠')),
      findsNothing,
      reason: 'the demo is not a feature: no billing badge',
    );
  });

  testWidgets('a playable poster opens the show through the iris', (tester) async {
    final kit = TestKit();
    await pumpHall(tester, extra: [cinemaKitProvider.overrideWithValue(kit.kit)]);
    final demo = find.widgetWithText(MiniPoster, ar.cinemaDemoTitle);
    await tester.ensureVisible(demo);
    await tester.tap(demo);
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(CinemaGameScreen), findsOneWidget);
    expect(find.byType(CinemaGameView), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  test('programme shelves follow tiers and genres', () {
    final filter = ProgrammeFilter();
    final shelves = programmeShelves(CinemaCatalog.all, filter);
    expect(shelves.first.shelf, ProgrammeShelf.features);
    expect(shelves.first.entries, hasLength(5));
    expect(shelves.last.shelf, ProgrammeShelf.backstage);
    filter.readyOnly = true;
    expect(programmeShelves(CinemaCatalog.all, filter).map((s) => s.shelf), [ProgrammeShelf.backstage]);
    final short = GameCatalogEntry(
      id: 'tarneeb',
      title: (l) => 'x',
      tagline: (l) => 'y',
      era: Era.noir,
      tier: GameTier.short,
      genre: GameGenre.card,
      builder: (c) => _Tiny(context: c),
    );
    expect(shelfOf(short), ProgrammeShelf.cards);
    filter
      ..readyOnly = false
      ..shelf = ProgrammeShelf.cards;
    final cards = programmeShelves([...CinemaCatalog.all, short], filter).single;
    expect(cards.entries.single.id, 'tarneeb');
    expect(cards.locked, 2);
  });
}
