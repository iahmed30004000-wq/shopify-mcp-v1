// Visual critic pass for «الألعاب» – the games' own world: its planet page
// inside the real app, with the real fonts and shaders, in Arabic and
// English across Lapis, Pearl and Aurora, at text scale 1, at 1.3, with a
// lived-in ticket book and shelf and on a fresh install. PNGs land in
// madar/screenshots/games/. FAILS on a layout overflow and prints every
// painted string below WCAG AA. LOOK at them.
//
//   scratchpad/ft --tags screenshot test/features/games/games_world_screenshot_test.dart
@Tags(['screenshot'])
@Timeout(Duration(minutes: 40))
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/cinema/games/catalog.dart';
import 'package:madar/features/cinema/hall/hall.dart'
    show CinemaRecords, GameRecord, MemoryCinemaRecordsStore, cinemaRecordsStoreProvider;
import 'package:madar/features/orbit/presentation/planet/cinema_entry_card.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/saved_games/saved_games.dart'
    show MemorySavedWebGamesStore, SavedGamesShelf, SavedGamesState, savedWebGamesStoreProvider;

import '../../core/design/rendered_contrast.dart';
import '../../helpers/screenshot_harness.dart';
import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';
import '../orbit/presentation/orbit_scene_fixtures.dart' show preloadOrbitShaders;
import '../saved_games/saved_games_fakes.dart' show sampleGames, savedGamesTestNow;

const _dir = 'games';

/// An evening, when he would actually open the hall.
final DateTime _now = DateTime(2026, 10, 14, 20, 30);

final String _playableId = CinemaCatalog.all.firstWhere((e) => e.isPlayable).id;

/// A lived-in ticket book: one long-played show, one small one, one played
/// but never scored.
CinemaRecords _records() => CinemaRecords({
  _playableId: GameRecord(
    gameId: _playableId,
    best: 1240,
    plays: 9,
    wins: 4,
    playTime: const Duration(minutes: 52),
    lastScore: 980,
    lastPlayed: savedGamesTestNow,
  ),
  'metropolis_machine': const GameRecord(gameId: 'metropolis_machine', best: 310, plays: 2, wins: 1),
  'demo': const GameRecord(gameId: 'demo', best: 70, plays: 3),
  // Opened once and left without a score: never in the list of bests.
  'old_show': const GameRecord(gameId: 'old_show', plays: 1),
});

List<Override> _stores({required bool seeded}) => [
  cinemaRecordsStoreProvider.overrideWithValue(MemoryCinemaRecordsStore(seeded ? _records() : CinemaRecords.empty)),
  savedWebGamesStoreProvider.overrideWithValue(
    MemorySavedWebGamesStore(SavedGamesState(games: seeded ? sampleGames(now: _now) : const [])),
  ),
];

Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder _planetSheet() => find.descendant(
  of: find.byType(PlanetModulePage),
  matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
);

/// Scrolls the planet sheet so [target]'s top sits [below] px under the
/// sheet's own top edge.
Future<void> _sheetTo(WidgetTester tester, Finder target, {double below = 16}) async {
  final scrollable = _planetSheet().first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var i = 0; i < 14 && target.evaluate().isEmpty; i++) {
    position.jumpTo((position.pixels + 300).clamp(position.minScrollExtent, position.maxScrollExtent));
    await _frames(tester, 2);
  }
  if (target.evaluate().isEmpty) return;
  for (var pass = 0; pass < 3; pass++) {
    await _frames(tester, 4);
    final dy = tester.getTopLeft(target.first).dy - tester.getTopLeft(scrollable).dy - below;
    if (dy.abs() < 2) break;
    position.jumpTo((position.pixels + dy).clamp(position.minScrollExtent, position.maxScrollExtent));
  }
  await _frames(tester, 12);
}

/// Text scrolled up past the sheet's top edge is clipped under the planet:
/// it is not on screen and is not measured.
List<Rect> _clippedUnderPlanet(WidgetTester tester) {
  final sheet = _planetSheet();
  if (sheet.evaluate().isEmpty) return const [];
  final top = tester.getTopLeft(sheet.first).dy;
  return [
    for (final e in find.descendant(of: sheet.first, matching: find.byType(RichText)).evaluate())
      if (e.renderObject case final RenderBox box when box.attached && box.hasSize)
        if ((box.localToGlobal(Offset.zero) & box.size) case final rect when rect.top < top - 0.5) rect,
  ];
}

final RegExp _readable = RegExp(r'[\p{L}\p{N}]', unicode: true);

Future<void> _save(WidgetTester tester, GlobalKey boundary, String name) async {
  await tester.runAsync(() async {
    final box = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await box.toImage(pixelRatio: 2.625);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('screenshots/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

/// The games world's page, captured at the top (the hall's door and the
/// scores) and again at the shelf.
Future<void> _shot(
  WidgetTester tester, {
  required String lang,
  required MadarThemeId theme,
  required bool seeded,
  double textScale = 1,
  bool shelf = true,
}) async {
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await preloadOrbitShaders(tester);
  final setup = await buildMadarTestApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
    initialLocation: AppRoutes.planetOf('games'),
    now: _now,
    overrides: [
      ...LockFixture.empty().overrides,
      ..._stores(seeded: seeded),
    ],
  );
  final suffix = textScale == 1 ? '' : '_x${(textScale * 10).round()}';
  final name = '$_dir/${seeded ? 'played' : 'fresh'}_${lang}_${theme.name}$suffix';
  final boundary = GlobalKey();
  final misses = <String>[];
  final overflows = <String>[];
  Future<void> measure(String where) async {
    final clipped = _clippedUnderPlanet(tester);
    for (final r in await measureRenderedContrast(tester, boundary)) {
      if (r.passes || r.icon || !_readable.hasMatch(r.text)) continue;
      if (clipped.any((c) => c.inflate(1).contains(r.rect.center))) continue;
      misses.add('$where $r');
    }
    final e = tester.takeException();
    if (e != null) overflows.add('$where $e');
  }

  await captureScreen(
    tester,
    RepaintBoundary(key: boundary, child: setup.app),
    name,
    settle: const Duration(milliseconds: 1400),
    beforeCapture: (tester) async {
      // (The top of this page – the ring, the state and «لا يُحتسب في
      // توازنك» – is captured by cinema_entry_card_screenshot_test.)
      await _sheetTo(tester, find.byType(CinemaEntryCard));
      // The marquee's one chase, then the bulbs rest lit.
      await _frames(tester, 36);
      await measure('cards');
    },
    trailingFrames: 2,
  );
  if (shelf) {
    await _sheetTo(tester, find.byType(SavedGamesShelf));
    await _frames(tester, 10);
    await measure('shelf');
    await _save(tester, boundary, '${name}_shelf');
  }
  await tester.pumpWidget(const SizedBox());
  await _frames(tester, 4);
  if (misses.isNotEmpty || overflows.isNotEmpty) {
    // ignore: avoid_print
    print('REPORT $name:\n  ${[...overflows, ...misses].join('\n  ')}');
  }
  expect(overflows, isEmpty, reason: '$name: a layout overflow');
}

void main() {
  testWidgets('played ar lapis', (tester) => _shot(tester, lang: 'ar', theme: MadarThemeId.lapis, seeded: true));
  testWidgets('played en pearl', (tester) => _shot(tester, lang: 'en', theme: MadarThemeId.pearl, seeded: true));
  testWidgets('played ar aurora', (tester) => _shot(tester, lang: 'ar', theme: MadarThemeId.aurora, seeded: true));
  testWidgets(
    'played ar pearl at text scale 1.3',
    (tester) => _shot(tester, lang: 'ar', theme: MadarThemeId.pearl, seeded: true, textScale: 1.3),
  );
  testWidgets('fresh ar lapis', (tester) => _shot(tester, lang: 'ar', theme: MadarThemeId.lapis, seeded: false));
  testWidgets('fresh en aurora', (tester) => _shot(tester, lang: 'en', theme: MadarThemeId.aurora, seeded: false));
  testWidgets(
    'fresh ar lapis at text scale 1.3',
    (tester) => _shot(tester, lang: 'ar', theme: MadarThemeId.lapis, seeded: false, textScale: 1.3),
  );
}
