@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe_shaders.dart';
import 'package:madar/features/qibla/qibla.dart';

import '../../helpers/screenshot_harness.dart';
import 'qibla_test_app.dart';

const _dir = 'phase3/qibla';

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    required FakeHeadingSource source,
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    DateTime? now,
    Future<void> Function(WidgetTester tester)? beforeCapture,
  }) async {
    await tester.runAsync(() async {
      try {
        await AstrolabePrograms.load();
      } catch (_) {
        // Gradient fallback.
      }
    });
    final setup = await buildQiblaTestApp(tester, home: home, source: source, theme: theme, locale: locale, now: now);
    await captureScreen(tester, setup.app, '$_dir/$name', beforeCapture: beforeCapture);
  }

  /// Feeds [n] readings 20 ms apart (for the accuracy / calibration logic).
  Future<void> feed(
    WidgetTester tester,
    FakeHeadingSource source,
    HeadingReading Function(int ms) at, {
    int n = 80,
  }) async {
    for (var i = 0; i < n; i++) {
      source.emit(at(i * 20 + 20));
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  group('compass', () {
    testWidgets('aligned, Arabic, Lapis', (tester) async {
      final source = FakeHeadingSource(initial: readingAt(ammanQibla - 1.2, pitch: 6, roll: -4));
      await shot(tester, 'aligned_ar_lapis', const QiblaScreen(), source: source);
    });

    testWidgets('aligned, English, Pearl', (tester) async {
      final source = FakeHeadingSource(initial: readingAt(ammanQibla + 0.8));
      await shot(
        tester,
        'aligned_en_pearl',
        const QiblaScreen(),
        source: source,
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });

    testWidgets('off by 90°, English, Pearl', (tester) async {
      final source = FakeHeadingSource(initial: readingAt(ammanQibla - 90));
      await shot(
        tester,
        'off90_en_pearl',
        const QiblaScreen(),
        source: source,
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });

    testWidgets('off by 90°, Arabic, Emerald', (tester) async {
      final source = FakeHeadingSource(initial: readingAt(ammanQibla + 90));
      await shot(tester, 'off90_ar_emerald', const QiblaScreen(), source: source, theme: MadarThemeId.emerald);
    });

    testWidgets('calibrating, Arabic, Emerald', (tester) async {
      final source = FakeHeadingSource();
      await shot(
        tester,
        'calibrating_ar_emerald',
        const QiblaScreen(),
        source: source,
        theme: MadarThemeId.emerald,
        beforeCapture: (t) => feed(t, source, (ms) => disturbedAt(40, ms: ms)),
      );
    });

    testWidgets('calibrating, English, Lapis', (tester) async {
      final source = FakeHeadingSource();
      await shot(
        tester,
        'calibrating_en_lapis',
        const QiblaScreen(),
        source: source,
        locale: const Locale('en'),
        beforeCapture: (t) => feed(t, source, (ms) => disturbedAt(300, ms: ms)),
      );
    });
  });

  group('fallbacks', () {
    testWidgets('sun mode, Arabic, Desert', (tester) async {
      final source = FakeHeadingSource(error: const HeadingUnavailable(HeadingUnavailableReason.noSensor));
      await shot(tester, 'sun_ar_desert', const QiblaScreen(), source: source, theme: MadarThemeId.desert);
    });

    testWidgets('sun mode, English, Pearl', (tester) async {
      final source = FakeHeadingSource(error: const HeadingUnavailable(HeadingUnavailableReason.noReadings));
      await shot(
        tester,
        'sun_en_pearl',
        const QiblaScreen(),
        source: source,
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });

    testWidgets('diagram at night, Arabic, Lapis', (tester) async {
      final source = FakeHeadingSource(error: const HeadingUnavailable(HeadingUnavailableReason.noSensor));
      await shot(tester, 'diagram_ar_lapis', const QiblaScreen(), source: source, now: qiblaNight);
    });
  });

  group('card', () {
    Widget host(Widget child) => Builder(
      builder: (context) => Scaffold(
        backgroundColor: context.tokens.space0,
        body: CosmosBackdrop(
          animate: false,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Space.gutter),
              child: Column(children: [child]),
            ),
          ),
        ),
      ),
    );

    testWidgets('card, Arabic, Lapis', (tester) async {
      await shot(tester, 'card_ar_lapis', host(QiblaCard(onOpen: () {})), source: FakeHeadingSource());
    });

    testWidgets('card, English, Pearl', (tester) async {
      await shot(
        tester,
        'card_en_pearl',
        host(QiblaCard(onOpen: () {})),
        source: FakeHeadingSource(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });
  });
}
