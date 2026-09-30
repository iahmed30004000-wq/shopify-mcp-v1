@Tags(['screenshot'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/games/demo/demo_screen.dart';

import '../../../helpers/screenshot_harness.dart';

// Renders the engine demo through the real shaders (SkSL in flutter_tester)
// into screenshots/cinema/demo/*.png – look at them after every engine
// change: they show all four agents' pieces together in every era.
void main() {
  setUpAll(() async {
    await loadMadarFonts();
    await CinemaShaders.preload();
  });

  for (final era in Era.values) {
    testWidgets('demo attract mode – ${era.name}', (tester) async {
      await captureScreen(
        tester,
        ProviderScope(
          child: madarScreenshotApp(
            home: CinemaDemoScreen(initialEra: era, autoplay: true, showEraPicker: false),
          ),
        ),
        'cinema/demo/demo_${era.name}',
        settle: const Duration(milliseconds: 2150),
      );
    });
  }

  testWidgets('demo opening intertitle', (tester) async {
    await captureScreen(
      tester,
      ProviderScope(child: madarScreenshotApp(home: const CinemaDemoScreen(showEraPicker: false))),
      'cinema/demo/demo_opening_card',
      settle: const Duration(milliseconds: 900),
    );
  });

  testWidgets('demo iris-in', (tester) async {
    await captureScreen(
      tester,
      ProviderScope(child: madarScreenshotApp(home: const CinemaDemoScreen(showEraPicker: false))),
      'cinema/demo/demo_iris_in',
      settle: const Duration(milliseconds: 4750),
    );
  });
}
