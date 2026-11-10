// «الألعاب» – the games' own world (the tenth planet).
//
// What is proven here:
//  * the seeded world: its key, its two names, its own colour and style,
//    its place in orbit, and the two guards that keep it out of the
//    balance (`weight: 0`) and out of every score (each source at 0);
//  * **the rule that must not break**: against a fixture where every other
//    world is neglected, and with a task, a habit, a tracker and an
//    activity row all attached to the games world, it is still absent from
//    the Neglect Radar and still moves the balance by nothing at all;
//  * an existing install gains the world without losing what the user
//    changed on another world;
//  * a `game` / `savedGame` link lands in the hall (one source of truth
//    with the search and the radar: `LifeRecordLinks`);
//  * its hub inside the real app, in Arabic and English: the hall's door,
//    his best scores, the games he saved from a link, its empty state on a
//    fresh install – and the Growth world no longer carrying any of it.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/db/seed/defaults.dart';
import 'package:madar/core/db/seed/seeder.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/life_route_pages.dart' show LifeRecordLinks;
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/routing/system_route_pages.dart' show searchTargetOf;
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/games/catalog.dart';
import 'package:madar/features/cinema/hall/hall.dart'
    show CinemaHallScreen, CinemaRecords, GameRecord, MemoryCinemaRecordsStore, cinemaRecordsStoreProvider;
import 'package:madar/features/custom_modules/custom_modules.dart';
import 'package:madar/features/growth/growth.dart' show GrowthTodayCard;
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/domain/planet_scores.dart' show PlanetState;
import 'package:madar/features/orbit/domain/neglect_text.dart' show planetStateLabel;
import 'package:madar/features/orbit/domain/scene_snapshot.dart';
import 'package:madar/features/orbit/presentation/planet/cinema_entry_card.dart';
import 'package:madar/features/orbit/presentation/planet/games_scores_card.dart';
import 'package:madar/features/orbit/presentation/planet/life_hubs.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/saved_games/saved_games.dart'
    show MemorySavedWebGamesStore, SavedGamesShelf, SavedGamesState, SavedWebGame, savedWebGamesStoreProvider;
import 'package:madar/features/search/search.dart' show SearchDoc;

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';
import '../orbit/data/orbit_fixtures.dart' show fixtureNow, seedLivedIn;
import '../saved_games/saved_games_fakes.dart' show sampleGames, savedGamesTestNow;

/// The id of a programme entry that really plays (its records are the ones
/// the hub can name).
final String _playableId = CinemaCatalog.all.firstWhere((e) => e.isPlayable).id;

CinemaRecords _records() => CinemaRecords({
  _playableId: GameRecord(
    gameId: _playableId,
    best: 1240,
    plays: 9,
    wins: 4,
    playTime: const Duration(minutes: 52),
    lastScore: 980,
    lastPlayed: savedGamesTestNow.subtract(const Duration(hours: 5)),
  ),
  'metropolis_machine': const GameRecord(gameId: 'metropolis_machine', best: 310, plays: 2, wins: 1),
  'demo': const GameRecord(gameId: 'demo', best: 70, plays: 3),
  // Opened once and left without a score: counted among his plays, never
  // among his best scores.
  'old_show': const GameRecord(gameId: 'old_show', plays: 1),
});

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final Finder _sheet = find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first;

/// Scrolls the planet page's lazy sheet until [finder] is built and visible.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final position = tester.state<ScrollableState>(_sheet).position;
  if (finder.evaluate().isEmpty && position.pixels > 0) {
    position.jumpTo(0);
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(finder, 250, scrollable: _sheet);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// The games world's page in the real app, with [records] in the ticket
/// book and [games] on the shelf.
Future<TestApp> _page(
  WidgetTester tester, {
  String lang = 'ar',
  String planetKey = 'games',
  CinemaRecords records = CinemaRecords.empty,
  List<SavedWebGame> games = const [],
}) async {
  final app = await pumpMadarApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang),
    initialLocation: AppRoutes.planetOf(planetKey),
    overrides: [
      cinemaRecordsStoreProvider.overrideWithValue(MemoryCinemaRecordsStore(records)),
      savedWebGamesStoreProvider.overrideWithValue(MemorySavedWebGamesStore(SavedGamesState(games: games))),
      ...LockFixture.empty().overrides,
    ],
    settle: false,
  );
  await _frames(tester, 60);
  await settleApp(tester);
  return app;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  // ------------------------------------------------------------- the world

  group('the seeded world', () {
    late MadarDatabase db;

    setUp(() async => db = await openInMemoryMadarDatabase());
    tearDown(() => db.close());

    test('the tenth world: its names, its own colour and style, weight 0', () async {
      final rows = await (db.select(db.planets)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
      final games = rows.last;
      expect(games.key, 'games', reason: 'last in orbit order, after «السفرة»');
      expect(games.sortOrder, rows.length - 1);
      expect(games.nameAr, 'الألعاب');
      expect(games.nameEn, 'Games');
      expect(games.icon, 'games');
      expect(games.hidden, isFalse);
      expect(games.archetype, PlanetArchetype.ice);
      expect(games.color, PlanetPalettes.games.surface.toARGB32());
      // Nobody else wears this colour or this style.
      expect(rows.where((p) => p.color == games.color), hasLength(1));
      expect(rows.where((p) => p.archetype == games.archetype), hasLength(1));
      // The two guards.
      expect(games.weight, 0.0);
      expect(games.sources, {'tasks': 0.0, 'habits': 0.0, 'projects': 0.0, 'activity': 0.0});
    });

    test('the defaults say so too (one source of truth for the seeder)', () {
      final games = MadarDefaults.planets.last;
      expect(games.key, 'games');
      expect(games.weight, 0.0);
      expect(games.sources.values, everyElement(0.0));
      expect(games.nameIn(lookupL10n(const Locale('ar'))), 'الألعاب');
      expect(games.nameIn(lookupL10n(const Locale('en'))), 'Games');
      // Every other built-in world still counts, in full.
      for (final p in MadarDefaults.planets.where((p) => p.key != 'games')) {
        expect(p.weight, 1.0, reason: p.key);
        expect(p.sources.values.fold<double>(0, (s, v) => s + v), closeTo(1.0, 1e-9), reason: p.key);
      }
    });

    // The upgrade path Part 5 built: a world a later release adds reaches an
    // install that is already seeded, and nothing else is touched.
    test('an existing install gains it without losing the user\'s own edits', () async {
      await (db.delete(db.planets)..where((t) => t.key.equals('games'))).go();
      // He had already renamed, recoloured, reordered and hidden other
      // worlds, and deleted habits he did not want.
      await (db.update(db.planets)..where((t) => t.key.equals('sufra'))).write(
        const PlanetsCompanion(
          nameAr: Value('المطبخ'),
          color: Value(0xFF123456),
          sortOrder: Value(0),
          hidden: Value(true),
          weight: Value(0.5),
        ),
      );
      await (db.update(db.planets)..where((t) => t.key.equals('growth'))).write(
        const PlanetsCompanion(nameEn: Value('Learning'), sources: Value({'goals': 1.0})),
      );
      await db.delete(db.habits).go();

      expect(await MadarSeeder(db).seedIfNeeded(), isTrue, reason: 'the missing world is added');

      final rows = await db.select(db.planets).get();
      expect(rows.map((p) => p.key), contains('games'));
      expect(rows, hasLength(MadarDefaults.planets.length));
      final games = rows.firstWhere((p) => p.key == 'games');
      expect(games.weight, 0.0, reason: 'an upgrade must not seed it as a counted world');
      expect(games.sources.values, everyElement(0.0));
      expect(games.hidden, isFalse);

      final sufra = rows.firstWhere((p) => p.key == 'sufra');
      expect(sufra.nameAr, 'المطبخ');
      expect(sufra.color, 0xFF123456);
      expect(sufra.sortOrder, 0);
      expect(sufra.hidden, isTrue);
      expect(sufra.weight, 0.5);
      final growth = rows.firstWhere((p) => p.key == 'growth');
      expect(growth.nameEn, 'Learning');
      expect(growth.sources, {'goals': 1.0});
      expect(await db.select(db.habits).get(), isEmpty, reason: 'only the worlds are re-added');

      // And it is done: a second pass changes nothing.
      expect(await MadarSeeder(db).seedIfNeeded(), isFalse);
    });
  });

  // ------------------------------------- never in the balance or the radar

  group('the games never count', () {
    late MadarDatabase db;
    late Repositories repos;
    late OrbitRepository repo;

    setUp(() async {
      db = await openInMemoryMadarDatabase();
      repos = Repositories(db);
      repo = OrbitRepository(repos, clock: () => fixtureNow);
    });
    tearDown(() => db.close());

    test('a fresh install: it is dormant, calm, and raises nothing', () async {
      final snap = await repo.snapshot();
      final games = snap.planet('games')!;
      expect(games.name, 'الألعاب');
      expect(games.state, PlanetState.dormant);
      expect(games.weight, 0);
      expect(games.score.reasons, isEmpty);
      expect(games.score.sources, isEmpty);
      expect(snap.radar, isEmpty);
    });

    // THE test. Everything else is neglected; everything that could wake a
    // world is attached to this one; and it still must not appear.
    test('every other world neglected, this one loaded: no radar entry, no change to the balance', () async {
      await seedLivedIn(repos, thriving: false);
      // A task he filed here and let slip, a habit, a project and an
      // activity row – each of them would score and shame another world.
      await repos.tasks.insert(
        TasksCompanion.insert(
          title: 'Fix the controller',
          planetKey: const Value('games'),
          date: Value(fixtureNow.subtract(const Duration(days: 9))),
        ),
      );
      await repos.habits.insert(HabitsCompanion.insert(name: 'Play with the kids', planetKey: const Value('games')));
      await repos.projects.insert(ProjectsCompanion.insert(name: 'Build a card game', planetKey: const Value('games')));
      await repos.activity.log(
        planetKey: 'games',
        kind: 'games.played',
        at: fixtureNow.subtract(const Duration(days: 40)),
      );

      final data = await repo.load(now: fixtureNow);
      // radarCount: every world that could possibly be listed, so the
      // games cannot hide behind the three slots the home panel shows.
      final snap = SceneSnapshotBuilder.build(
        data,
        l10n: lookupL10n(const Locale('ar')),
        formatter: const MadarFormatter(),
        schedule: repo.scheduleFor(data.prayerSettings),
        radarCount: 99,
      );

      expect(snap.planet('games'), isNotNull, reason: 'the world is there, in the sky');
      expect(snap.radar, isNotEmpty, reason: 'the fixture really is neglected');
      expect(snap.radar.map((r) => r.planetKey), isNot(contains('games')));
      expect(snap.planet('games')!.score.reasons, isEmpty, reason: 'nothing on it is owed');
      expect(snap.planet('games')!.state, PlanetState.dormant);

      // The balance is exactly the weighted average of the *other* worlds:
      // the games world adds no term to it, neither weight nor score.
      var sum = 0.0, wsum = 0.0;
      for (final p in snap.planets) {
        if (p.key == 'games' || p.score.dormant || p.weight <= 0) continue;
        sum += p.score.score * p.weight;
        wsum += p.weight;
      }
      expect(wsum, greaterThan(0));
      expect(snap.balance, closeTo(sum / wsum, 1e-12));
      expect(snap.balanceDormant, isFalse);
    });

    // Even a tracker of his own on this world (the one thing the seeded
    // sources cannot switch off in advance, because its id is unknown)
    // cannot put the world on the radar: `weight: 0` is the guarantee.
    test('a stale tracker of his own on this world still never reaches the radar', () async {
      await seedLivedIn(repos, thriving: false);
      final tracker = await CustomModulesService(repos, clock: () => fixtureNow).createModule(
        ModuleTemplates.build(
          ModuleTemplateKey.readingLog,
          (t) => t.name,
        ).copyWith(name: 'Chess puzzles', planetKey: 'games'),
      );
      // Created a month before the fixture's "now" and never filled in:
      // on any other world this is «صار ٣٠ يوم ما سجّلت فيه».
      await (db.update(db.customModules)..where((t) => t.id.equals(tracker.id))).write(
        CustomModulesCompanion(createdAt: Value(fixtureNow.subtract(const Duration(days: 30)))),
      );
      final data = await repo.load(now: fixtureNow);
      final snap = SceneSnapshotBuilder.build(
        data,
        l10n: lookupL10n(const Locale('ar')),
        formatter: const MadarFormatter(),
        schedule: repo.scheduleFor(data.prayerSettings),
        radarCount: 99,
      );
      final games = snap.planet('games')!;
      // The tracker does score the world (it is his own tracker, and the
      // world's page shows it) …
      expect(games.score.sources, isNotEmpty);
      expect(games.score.reasons, isNotEmpty);
      // … and none of it ever leaves this world's own page.
      expect(snap.radar.map((r) => r.planetKey), isNot(contains('games')));
      for (final r in snap.radar) {
        expect(r.reason.planetKey, isNot('games'));
      }
      var wsum = 0.0;
      for (final p in snap.planets) {
        if (p.score.dormant || p.weight <= 0) continue;
        wsum += p.weight;
      }
      expect(snap.planets.length - 1, greaterThan(0));
      expect(wsum, snap.planets.where((p) => p.key != 'games' && !p.score.dormant).length.toDouble());
    });
  });

  // ------------------------------------------------------------- the links

  group('a game link lands in the hall', () {
    test('LifeRecordLinks is the one source of truth', () {
      expect(LifeRecordLinks.locationOf('game', _playableId), AppRoutes.cinemaGameOf(_playableId));
      expect(LifeRecordLinks.locationOf('game', null), AppRoutes.cinema);
      expect(LifeRecordLinks.locationOf('game', ''), AppRoutes.cinema, reason: 'an empty id is no id');
      expect(LifeRecordLinks.locationOf('savedGame', 'g1'), AppRoutes.savedGames);
      expect(LifeRecordLinks.locationOf('savedGame', null), AppRoutes.savedGames);
      expect(LifeRecordLinks.tables, containsAll(['game', 'savedGame']));
    });

    test('a search hit opens the same place', () {
      SearchDoc doc(String openKey, {String refId = ''}) =>
          SearchDoc(id: 'x', refTable: openKey, refId: refId, title: 'x', planetKey: 'games');
      expect(searchTargetOf(doc('game', refId: _playableId)), AppRoutes.cinemaGameOf(_playableId));
      expect(searchTargetOf(doc('game')), AppRoutes.cinema);
      expect(searchTargetOf(doc('savedGame', refId: 'g1')), AppRoutes.savedGames);
    });
  });

  // --------------------------------------------------------------- the hub

  group('its hub in the app', () {
    for (final lang in ['ar', 'en']) {
      testWidgets('$lang: the hall, his best scores and his saved games', (tester) async {
        final l = lookupL10n(Locale(lang));
        final f = MadarFormatter(languageCode: lang);
        final app = await _page(tester, lang: lang, records: _records(), games: sampleGames());
        expect(find.byType(GamesHub), findsOneWidget);
        expect(find.text(lang == 'ar' ? 'الألعاب' : 'Games'), findsWidgets);
        expect(
          Directionality.of(tester.element(find.byType(GamesHub))),
          lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );

        // 1. the hall's door, first on the page – and the only door to it
        // on this page (one screen, one door, named once).
        await _reveal(tester, find.byType(CinemaEntryCard));
        expect(find.text(l.cinemaTitle), findsOneWidget);
        expect(find.text(l.cinemaWiringEnterHall), findsOneWidget);
        expect(find.text(l.lifeHubToolsTitle, skipOffstage: false), findsNothing);

        // 2. his best scores, best first, with the plays and the count.
        await _reveal(tester, find.byType(GamesScoresCard));
        final card = find.byType(GamesScoresCard);
        expect(find.descendant(of: card, matching: find.text(l.gamesWorldBestTitle)), findsOneWidget);
        final best = l.cinemaHallBestBadge(f.formatInt(1240));
        expect(find.descendant(of: card, matching: find.text(best)), findsOneWidget);
        expect(
          find.descendant(of: card, matching: find.text(f.localizeDigits(l.savedGamesPlayCount(9)))),
          findsOneWidget,
        );
        // Three games have a score; the one that was only played has none –
        // and the count is in his own digits.
        expect(
          find.descendant(of: card, matching: find.text(f.localizeDigits(l.gamesWorldPlayedGames(3)))),
          findsOneWidget,
        );
        if (lang == 'ar') {
          expect(f.localizeDigits(l.gamesWorldPlayedGames(3)), contains('٣'));
        }
        expect(find.descendant(of: card, matching: find.text(l.gamesWorldBestEmpty)), findsNothing);
        if (lang == 'ar') {
          for (final text in tester.widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))) {
            expect(text.data ?? '', isNot(contains(RegExp('[0-9]'))), reason: 'Arabic-Indic digits only');
          }
        }
        // 48 dp, one button, and a forward chevron that points forward.
        expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
        final handle = tester.ensureSemantics();
        expect(find.bySemanticsLabel(RegExp(RegExp.escape(l.gamesWorldBestTitle))), findsWidgets);
        handle.dispose();
        expect(
          tester
              .widgetList<Icon>(find.descendant(of: card, matching: find.byType(Icon)))
              .map((i) => i.icon)
              .contains(Icons.chevron_right_rounded),
          isTrue,
        );

        // It opens the ticket book in the hall, and back returns here.
        app.sound.played.clear();
        await tester.tap(card);
        await _frames(tester, 30);
        expect(app.router.state.uri.toString(), AppRoutes.cinema);
        expect(find.byType(CinemaHallScreen), findsOneWidget);
        expect(app.sound.played, contains(Sfx.navigate));
        await tester.binding.handlePopRoute();
        await _frames(tester, 30);
        expect(app.router.state.uri.toString(), AppRoutes.planetOf('games'));

        // 3. the games he saved from a link.
        await _reveal(tester, find.byType(SavedGamesShelf));
        expect(
          find.descendant(of: find.byType(SavedGamesShelf), matching: find.text('Double Feature')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 6));
      }, timeout: const Timeout(Duration(minutes: 4)));
    }

    testWidgets('a fresh install: an empty hall, no invented score', (tester) async {
      final l = lookupL10n(const Locale('ar'));
      await _page(tester);
      // The world says so itself, at the top of its own page, where the
      // other worlds show their balance: «لا يُحتسب في توازنك».
      expect(find.text(l.orbitUiPlanetNotCounted), findsOneWidget);
      // The header and the ring both read «هادئ، لا بيانات بعد».
      expect(find.text(planetStateLabel(l, PlanetState.dormant)), findsWidgets);
      expect(find.text(l.orbitUiPlanetWeight(const MadarFormatter().formatNumber(0, maxDecimals: 1))), findsNothing);
      await _reveal(tester, find.byType(GamesScoresCard));
      final card = find.byType(GamesScoresCard);
      expect(find.descendant(of: card, matching: find.text(l.gamesWorldBestEmpty)), findsOneWidget);
      // No score, no badge, no count of games.
      expect(find.descendant(of: card, matching: find.textContaining(l.cinemaStageBest)), findsNothing);
      expect(find.descendant(of: card, matching: find.text(l.gamesWorldBestSeeAll)), findsNothing);
      expect(GamesScoresCard.ranked(CinemaRecords.empty), isEmpty);
      // The shelf invites him to save one instead of showing games.
      await _reveal(tester, find.byType(SavedGamesShelf));
      expect(find.descendant(of: find.byType(SavedGamesShelf), matching: find.text(l.savedGamesAdd)), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    }, timeout: const Timeout(Duration(minutes: 4)));

    testWidgets('the Growth world no longer carries the games', (tester) async {
      await _page(tester, planetKey: 'growth', records: _records(), games: sampleGames());
      expect(find.byType(GrowthHub), findsOneWidget);
      expect(find.byType(GamesHub), findsNothing);
      // Nothing of the games on this world, built or not.
      for (final type in [CinemaEntryCard, GamesScoresCard, SavedGamesShelf]) {
        expect(find.byType(type, skipOffstage: false), findsNothing, reason: '$type on Growth');
      }
      // What is actually growth is still there.
      await _reveal(tester, find.byType(GrowthTodayCard));
      expect(find.byType(GrowthTodayCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    }, timeout: const Timeout(Duration(minutes: 4)));
  });

  // --------------------------------------------------------- the card pure

  group('the scores card ranks honestly', () {
    test('best first, then plays, then the id; nothing unscored', () {
      final ranked = GamesScoresCard.ranked(_records());
      expect(ranked.map((r) => r.$1.gameId), [_playableId, 'metropolis_machine', 'demo']);
      expect(ranked.first.$2, isNotNull, reason: 'a programme entry is named');
      expect(ranked.map((r) => r.$1.best), [1240, 310, 70]);
    });

    test('a game no longer on the programme keeps its line, by its id', () {
      final ranked = GamesScoresCard.ranked(
        const CinemaRecords({'old_show': GameRecord(gameId: 'old_show', best: 5, plays: 1)}),
      );
      expect(ranked.single.$2, isNull);
      expect(ranked.single.$1.gameId, 'old_show');
    });
  });
}
