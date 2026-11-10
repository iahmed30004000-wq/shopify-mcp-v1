// Renders the kids letters and maths screens at phone size with the real fonts
// to madar/screenshots/kids_learn_*.png, to compare with docs/kids/png/07a, 07b.
//
//   flutter test --tags screenshot test/features/kids/learn/learn_screenshot_test.dart
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/kids/learn/data/arabic_letters.dart';
import 'package:madar/features/kids/learn/letters/letter_picture.dart';
import 'package:madar/features/kids/learn/letters/letters_screen.dart';
import 'package:madar/features/kids/learn/maths/maths_screen.dart';
import 'package:madar/features/kids/learn/voice/kids_voice.dart';

import '../../../helpers/screenshot_harness.dart';

Widget _shot(Widget child, {double scale = 1}) => ProviderScope(
  overrides: [kidsVoiceProvider.overrideWithValue(const SilentKidsVoice())],
  child: madarScreenshotApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale), size: const Size(360, 780)),
      child: Scaffold(body: SafeArea(child: child)),
    ),
  ),
);

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
}

void main() {
  const size = Size(360, 780);
  testWidgets('letters: card', (t) async {
    await captureScreen(t, _shot(const LettersScreen(initialIndex: 17)), 'kids_learn_letters', logicalSize: size, dpr: 2);
  });
  testWidgets('letters: card at 1.3x, 320 wide', (t) async {
    await captureScreen(t, _shot(const LettersScreen(initialIndex: 17), scale: 1.3), 'kids_learn_letters_320_13', logicalSize: const Size(320, 640), dpr: 2);
  });
  testWidgets('letters: pictures sheet', (t) async {
    await captureScreen(
      t,
      _shot(
        Builder(
          builder: (context) => GridView.count(
            crossAxisCount: 7,
            children: [
              for (var i = 0; i < 28; i++) Padding(padding: const EdgeInsets.all(4), child: LetterPictureView(picture: LetterPicture.values[i])),
            ],
          ),
        ),
      ),
      'kids_learn_pictures',
      logicalSize: const Size(420, 420),
      dpr: 2,
    );
  });
  testWidgets('letters: trace', (t) async {
    await captureScreen(t, _shot(const LettersScreen(initialIndex: 17)), 'kids_learn_trace', logicalSize: size, dpr: 2,
        beforeCapture: (t) async {
      await _tap(t, find.text('اكتب الحرف بإصبعك'));
      await t.pump();
      final g = await t.startGesture(t.getCenter(find.byType(AspectRatio).first) - const Offset(60, 80));
      for (var i = 0; i < 25; i++) {
        await g.moveBy(Offset(i < 12 ? 2 : -1, 7));
      }
      await g.up();
    });
  });
  testWidgets('letters: quiz after a miss', (t) async {
    await captureScreen(t, _shot(const LettersScreen(quizSeed: 5)), 'kids_learn_quiz', logicalSize: size, dpr: 2,
        beforeCapture: (t) async {
      await _tap(t, find.text('أي حرف هاد؟'));
      await t.pump();
      // pick choices until one is amber (a miss)
      final tiles = find.byWidgetPredicate((w) => w is Semantics && w.properties.button == true && w.properties.label != null && w.properties.label!.length <= 4 && w.properties.label != 'اسمع');
      await t.tap(tiles.first);
      await t.pump();
    });
  });
  testWidgets('maths: multiplication', (t) async {
    await captureScreen(t, _shot(const MathsScreen(seed: 3)), 'kids_learn_maths', logicalSize: size, dpr: 2);
  });
  testWidgets('maths: division and fractions at 1.3x 320', (t) async {
    await captureScreen(t, _shot(const MathsScreen(seed: 3, initialTab: 1), scale: 1.3), 'kids_learn_maths_div_320', logicalSize: const Size(320, 640), dpr: 2);
    await captureScreen(t, _shot(const MathsScreen(seed: 9, initialTab: 2)), 'kids_learn_maths_frac', logicalSize: size, dpr: 2);
  });
}
