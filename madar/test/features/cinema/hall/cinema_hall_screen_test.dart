import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/games/catalog.dart';
import 'package:madar/features/cinema/hall/cinema_hall_screen.dart' show TicketButton;
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

/// A feature that is announced but has no builder: the not-open path stays
/// tested even once every real show is playable.
final GameCatalogEntry _announced = GameCatalogEntry(
  id: 'announced_feature',
  title: (l) => l.cinemaNoirTitle,
  tagline: (l) => l.cinemaNoirTagline,
  era: Era.noir,
  tier: GameTier.feature,
  genre: GameGenre.platformer,
);

void main() {
  final ar = lookupL10n(const Locale('ar'));
  final playable = [
    for (final e in CinemaCatalog.all)
      if (e.isPlayable) e,
  ];
  final announced = [
    for (final e in CinemaCatalog.all)
      if (!e.isPlayable) e,
  ];

  setUpAll(() async => CinemaShaders.preload());

  Future<HallTestEnv> pumpHall(
    WidgetTester tester, {
    CinemaRecords records = CinemaRecords.empty,
    List<Override> extra = const [],
    List<GameCatalogEntry>? catalog,
  }) async {
    tester.view.physicalSize = const Size(412, 5200) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final env = HallTestEnv(records: records);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...env.overrides, ...extra],
        child: madarScreenshotApp(home: CinemaHallScreen(catalog: catalog)),
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
    // The first feature's billing, with a ticket to play – or a coming-soon
    // plate when it has no builder yet.
    final first = CinemaCatalog.ofTier(GameTier.feature).first;
    expect(find.text(first.tagline(ar)), findsOneWidget);
    expect(find.widgetWithText(TicketButton, first.isPlayable ? ar.cinemaPlay : ar.cinemaComingSoon), findsOneWidget);
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
    final fifties = [
      for (final e in CinemaCatalog.all)
        if (e.era == Era.technicolor) e,
    ];
    expect(fifties, isNotEmpty, reason: 'Caravan Dash is a 1950s show');
    expect(find.byType(MiniPoster), findsNWidgets(fifties.length), reason: 'only the 1950s shows');
    for (final e in fifties) {
      expect(find.widgetWithText(MiniPoster, e.title(ar)), findsOneWidget, reason: e.id);
    }
    expect(find.byType(LockedSlot), findsNothing);
    await tapChip(tester, ar.cinemaHallAllEras);
    await tapChip(tester, ar.cinemaHallReadyOnly);
    // Exactly the shows with a builder (the rehearsal always is one).
    expect(find.byType(MiniPoster), findsNWidgets(playable.length), reason: 'only playable shows');
    for (final e in playable) {
      expect(find.widgetWithText(MiniPoster, e.title(ar)), findsOneWidget, reason: '${e.id} is playable');
    }
    for (final e in announced) {
      expect(find.widgetWithText(MiniPoster, e.title(ar)), findsNothing, reason: '${e.id} is not playable yet');
    }
    expect(find.byType(LockedSlot), findsNothing);
    await tapChip(tester, ar.cinemaHallReadyOnly);
    await tapChip(tester, ar.cinemaHallGenreCards);
    expect(find.byType(LockedSlot), findsNWidgets(3));
    expect(find.byType(MiniPoster), findsNothing);
  });

  testWidgets('a coming-soon show explains itself instead of opening', (tester) async {
    await pumpHall(tester, catalog: [_announced, CinemaCatalog.byId('demo')!]);
    // Its billing: a coming-soon plate, not a ticket to play.
    expect(find.widgetWithText(TicketButton, ar.cinemaPlay), findsNothing);
    await tester.tap(find.widgetWithText(TicketButton, ar.cinemaComingSoon));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(ar.cinemaHallLockedHint), findsOneWidget);
    expect(find.byType(CinemaGameScreen), findsNothing);
  });

  testWidgets('a poster of a show without a builder does not open either', (tester) async {
    await pumpHall(tester, catalog: [_announced, CinemaCatalog.byId('demo')!]);
    final poster = find.widgetWithText(MiniPoster, _announced.title(ar));
    await tester.ensureVisible(poster);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(poster);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(ar.cinemaHallLockedHint), findsOneWidget);
    expect(find.byType(CinemaGameScreen), findsNothing);
  });

  testWidgets('every show in the real catalog without a builder is marked "soon" and opens nothing', (tester) async {
    await pumpHall(tester);
    expect(announced, isNotEmpty, reason: 'derived from the catalog (builder == null), never from names');
    for (final e in announced) {
      final poster = find.widgetWithText(MiniPoster, e.title(ar));
      await tester.ensureVisible(poster);
      await tester.pump(const Duration(milliseconds: 100));
      // The poster says "soon" to TalkBack too (the plate itself is painted).
      expect(
        tester.widget<MiniPoster>(poster).entry.isPlayable,
        isFalse,
        reason: '${e.id} has no builder',
      );
      await tester.tap(poster);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CinemaGameScreen), findsNothing, reason: '${e.id} never opens an empty show');
      expect(find.text(ar.cinemaHallLockedHint), findsOneWidget, reason: '${e.id} explains itself');
    }
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
    // Ready to play: exactly the entries with a builder, on their shelves, no
    // locked slots.
    final ready = programmeShelves(CinemaCatalog.all, filter);
    expect(ready.map((s) => s.shelf), [
      for (final s in ProgrammeShelf.values)
        if (playable.any((e) => shelfOf(e) == s)) s,
    ]);
    expect(ready.map((s) => s.shelf), contains(ProgrammeShelf.backstage), reason: 'the rehearsal is always playable');
    expect([for (final s in ready) ...s.entries.map((e) => e.id)], unorderedEquals(playable.map((e) => e.id)));
    expect(ready.every((s) => s.locked == 0), isTrue);
    // A show without a builder never passes the filter.
    expect(programmeShelves([_announced, CinemaCatalog.byId('demo')!], filter).map((s) => s.shelf), [
      ProgrammeShelf.backstage,
    ]);
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
