@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/cinema/games/catalog.dart';
import 'package:madar/features/cinema/hall/hall.dart';
import 'package:madar/features/cinema/hall/posters/poster_painter.dart';

import '../../../helpers/screenshot_harness.dart';
import 'hall_fakes.dart';

// The Madar Cinema lobby – screenshots/cinema/hall/*.png. LOOK at them.
void main() {
  setUpAll(() async {
    await loadMadarFonts();
    await CinemaShaders.preload();
  });

  final played = CinemaRecords({
    'demo': GameRecord(gameId: 'demo', best: 1240, plays: 7, wins: 4, playTime: const Duration(minutes: 38)),
    'noir_rooftops': GameRecord(gameId: 'noir_rooftops', best: 560, plays: 2, playTime: const Duration(minutes: 9)),
  });

  testWidgets('hall – marquee and now showing', (tester) async {
    final env = HallTestEnv(records: played);
    await captureScreen(
      tester,
      env.app(const CinemaHallScreen()),
      'cinema/hall/hall_top',
      settle: const Duration(milliseconds: 900),
    );
  });

  testWidgets('hall – programme shelves', (tester) async {
    final env = HallTestEnv(records: played);
    await captureScreen(
      tester,
      env.app(const CinemaHallScreen()),
      'cinema/hall/hall_programme',
      settle: const Duration(milliseconds: 600),
      beforeCapture: (tester) async {
        await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      },
    );
  });

  testWidgets('hall – ticket book and saved games', (tester) async {
    final env = HallTestEnv(records: played);
    await captureScreen(
      tester,
      env.app(const CinemaHallScreen()),
      'cinema/hall/hall_bottom',
      settle: const Duration(milliseconds: 600),
      beforeCapture: (tester) async {
        await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      },
    );
  });

  testWidgets('hall – English (left to right)', (tester) async {
    final env = HallTestEnv(records: played);
    await captureScreen(
      tester,
      env.app(const CinemaHallScreen(), locale: const Locale('en')),
      'cinema/hall/hall_top_en',
      settle: const Duration(milliseconds: 900),
    );
  });

  testWidgets('a show that has not opened yet – noir', (tester) async {
    final env = HallTestEnv();
    await captureScreen(
      tester,
      env.app(const CinemaGameScreen(gameId: 'noir_rooftops')),
      'cinema/hall/not_open_noir',
      settle: const Duration(milliseconds: 900),
    );
  });

  testWidgets('posters – every one-sheet in the programme', (tester) async {
    final entries = CinemaCatalog.all;
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: Builder(
          builder: (context) {
            final l10n = L10n.of(context);
            return ColoredBox(
              color: const Color(0xFF2B0E14),
              child: Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in entries)
                      SizedBox(
                        width: 132,
                        height: 198,
                        child: CustomPaint(
                          painter: PosterPainter(entry: e, l10n: l10n, best: e.id == 'demo' ? '١٢٤٠' : null),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      'cinema/hall/posters',
      logicalSize: const Size(430, 430),
      settle: const Duration(milliseconds: 200),
    );
  });
}
