import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/ambient_motion.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion.dart';
import 'package:madar/features/orbit/render/sky/sky.dart';

import 'sky_fixtures.dart';

Widget _app(
  Widget child, {
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  bool reduced = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildMadarTheme(theme, arabic: locale.languageCode == 'ar'),
  locale: locale,
  supportedLocales: L10n.supportedLocales,
  localizationsDelegates: L10n.localizationsDelegates,
  home: MotionScope(reduced: reduced, child: child),
);

/// Renders [child] at [size] and returns RGBA bytes.
Future<(ByteData, int, int)> _render(WidgetTester tester, Widget child, {Size size = const Size(206, 458)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(_app(RepaintBoundary(key: key, child: child)));
  await tester.pump();
  late ByteData data;
  late int w, h;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    w = image.width;
    h = image.height;
    data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
  });
  return (data, w, h);
}

(double, double, double) _px(ByteData d, int w, int x, int y) {
  final o = (y * w + x) * 4;
  return (d.getUint8(o) / 255, d.getUint8(o + 1) / 255, d.getUint8(o + 2) / 255);
}

void main() {
  setUp(() async {
    AmbientMotion.debugOverride = null;
  });
  tearDown(() => AmbientMotion.debugOverride = null);

  Future<void> load(WidgetTester tester) => tester.runAsync(SkyPrograms.load);

  testWidgets('standalone: paints a still, never ticks under test, describes the sky', (tester) async {
    await load(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(SkyLayer(time: SkyShot.night.time)));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.bySemanticsLabel(RegExp('السماء الآن: ليل')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('بدر|أحدب')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('standalone ticker runs only with ambient motion and without reduced motion', (tester) async {
    await load(tester);
    AmbientMotion.debugOverride = true;
    await tester.pumpWidget(_app(SkyLayer(time: SkyShot.night.time)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(_app(SkyLayer(time: SkyShot.night.time), reduced: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('scene mode: follows the theme and language, never ticks, never disposes the controller', (tester) async {
    await load(tester);
    AmbientMotion.debugOverride = true;
    final c = SkyController(time: SkyShot.newMoon.time);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      _app(
        SkyLayer(controller: c),
        theme: MadarThemeId.emerald,
        locale: const Locale('en'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
    expect(c.tone, SkyTone.fromTokens(MadarPalettes.tokensFor(MadarThemeId.emerald)));
    expect(c.arabicNames, isFalse);
    await tester.pumpWidget(_app(SkyLayer(controller: c), theme: MadarThemeId.pearl));
    await tester.pump(const Duration(milliseconds: 400)); // theme cross-fade
    expect(c.tone!.dark, isFalse);
    expect(c.arabicNames, isTrue);
    await tester.pumpWidget(const SizedBox());
    // Still usable after the layer is gone.
    c.advanceSeconds(0.1);
    expect(c.seconds, closeTo(0.1, 1e-9));
  });

  testWidgets('flare layer paints over the scene without taking taps', (tester) async {
    await load(tester);
    final c = SkyController(time: SkyShot.golden.time)..coreStar = const Offset(100, 100);
    addTearDown(c.dispose);
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => taps++,
                child: SkyLayer(controller: c),
              ),
            ),
            Positioned.fill(child: SkyFlareLayer(controller: c)),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(SkyFlareLayer));
    expect(taps, 1);
    expect(c.coreFlareIntensity, greaterThan(0));
  });

  group('rendered pixels', () {
    testWidgets('noon: a deep blue sky', (tester) async {
      await load(tester);
      final (d, w, h) = await _render(tester, SkyLayer(time: SkyShot.noon.time));
      final (r, g, b) = _px(d, w, w ~/ 5, 12);
      expect(b, greaterThan(r + 0.15));
      expect(b, greaterThan(0.35));
    });

    testWidgets('golden hour: warm near the horizon, blue above', (tester) async {
      await load(tester);
      final (d, w, h) = await _render(tester, SkyLayer(time: SkyShot.golden.time));
      final top = _px(d, w, w ~/ 5, 8);
      final low = _px(d, w, w ~/ 5, (h * 0.53).round());
      expect(top.$3, greaterThan(top.$1));
      expect(low.$1, greaterThan(low.$3 + 0.15));
    });

    testWidgets('night: dark sky with stars and the moon', (tester) async {
      await load(tester);
      final (d, w, h) = await _render(tester, SkyLayer(time: SkyShot.night.time));
      var dark = 0, bright = 0;
      for (var y = 0; y < h ~/ 2; y++) {
        for (var x = 0; x < w; x++) {
          final (r, g, b) = _px(d, w, x, y);
          final l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
          if (l < 0.12) dark++;
          if (l > 0.55) bright++;
        }
      }
      expect(dark, greaterThan(w * h ~/ 2 * 0.8));
      expect(bright, greaterThan(20)); // moon + stars
      // The moon near its anchor (upper left).
      var moonHit = false;
      for (var y = (h * 0.1).round(); y < (h * 0.25).round(); y++) {
        for (var x = (w * 0.15).round(); x < (w * 0.4).round(); x++) {
          if (_px(d, w, x, y).$1 > 0.8) moonHit = true;
        }
      }
      expect(moonHit, isTrue);
    });

    testWidgets('Pearl reads as night at night: an indigo-slate, not black and not lavender', (tester) async {
      await load(tester);
      tester.view.physicalSize = const Size(206, 458);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        _app(
          RepaintBoundary(
            key: key,
            child: SkyLayer(time: SkyShot.newMoon.time),
          ),
          theme: MadarThemeId.pearl,
        ),
      );
      await tester.pump();
      late (double, double, double) mid;
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
        final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        mid = _px(data, image.width, image.width ~/ 2, (image.height * 0.45).round());
        image.dispose();
      });
      final luma = 0.2126 * mid.$1 + 0.7152 * mid.$2 + 0.0722 * mid.$3;
      expect(luma, inInclusiveRange(0.1, 0.4), reason: 'a night, lighter than deep space');
      expect(mid.$3, greaterThan(mid.$1 + 0.08), reason: 'blue (indigo-slate), not grey or lavender');
    });
  });

  test('descriptions are localised for every mood and phase', () async {
    final ar = await L10n.delegate.load(const Locale('ar'));
    final en = await L10n.delegate.load(const Locale('en'));
    for (final m in SkyMood.values) {
      expect(SkyDescriptions.mood(ar, m), isNotEmpty);
      expect(SkyDescriptions.mood(en, m), isNot(SkyDescriptions.mood(ar, m)));
    }
    final names = {for (final p in MoonPhaseName.values) SkyDescriptions.moonPhase(ar, p)};
    expect(names.length, MoonPhaseName.values.length);
  });
}
