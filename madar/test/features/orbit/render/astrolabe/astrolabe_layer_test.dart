import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/ambient_motion.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe.dart';

import 'astrolabe_fixtures.dart';

class _Haptics implements HapticsService {
  final List<Haptic> fired = [];
  @override
  bool enabled = true;
  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

const _box = Size(400, 400);

Widget _app(Widget child, {bool reduced = false, String lang = 'ar', VoidCallback? onBackgroundTap}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildMadarTheme(MadarThemeId.lapis, arabic: lang == 'ar'),
    locale: Locale(lang),
    supportedLocales: L10n.supportedLocales,
    localizationsDelegates: L10n.localizationsDelegates,
    home: MotionScope(
      reduced: reduced,
      child: Align(
        alignment: Alignment.topLeft,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onBackgroundTap),
            ),
            SizedBox.fromSize(size: _box, child: child),
          ],
        ),
      ),
    ),
  );
}

Offset _pointer(AstrolabeState s, Prayer p) =>
    AstrolabeGeometry.pointerCenter(_box.center(Offset.zero), AstrolabeGeometry.radiusFor(_box), s.fractionOf(p));

void main() {
  late SilentSoundService sound;
  late _Haptics haptics;

  setUp(() {
    sound = SilentSoundService();
    haptics = _Haptics();
    Fx.install(FeedbackService(sound, haptics));
  });

  final now = AmmanDay.at(16, 2);
  AstrolabeState state(Set<Prayer> prayed) => AmmanDay.state(now, prayed: prayed);

  testWidgets('shaders load and warm up offscreen (splash-time pre-warm)', (tester) async {
    // First in this file: layers pumped later start loading inside the
    // fake-async zone, where the shared noise texture could never finish.
    await tester.runAsync(() async {
      await AstrolabePrograms.warmUp();
      final programs = AstrolabePrograms.instance;
      expect(programs, isNotNull);
      expect(identical(await AstrolabePrograms.load(), programs), isTrue, reason: 'loaded once');
      AstrolabeShaderSet(programs!).dispose();
    });
  });

  testWidgets('tapping a pointer opens that prayer, with feedback', (tester) async {
    final tapped = <Prayer>[];
    var background = 0;
    final s = state({Prayer.fajr});
    await tester.pumpWidget(
      _app(
        AstrolabeLayer(state: s, onPrayerTap: tapped.add),
        onBackgroundTap: () => background++,
      ),
    );
    await tester.pump();
    await tester.tapAt(_pointer(s, Prayer.asr));
    expect(tapped, [Prayer.asr]);
    expect(sound.played, contains(Sfx.tap));
    // Anywhere else the tap reaches the scene behind the astrolabe.
    await tester.tapAt(_box.center(Offset.zero) + const Offset(0, 40));
    expect(tapped, [Prayer.asr]);
    expect(background, 1);
  });

  testWidgets('without a tap handler the astrolabe never claims gestures', (tester) async {
    var background = 0;
    final s = state(const {});
    await tester.pumpWidget(_app(AstrolabeLayer(state: s), onBackgroundTap: () => background++));
    await tester.pump();
    await tester.tapAt(_pointer(s, Prayer.dhuhr));
    expect(background, 1);
  });

  testWidgets('screen readers get a summary and one node per prayer', (tester) async {
    final handle = tester.ensureSemantics();
    final tapped = <Prayer>[];
    final s = AmmanDay.state(now, lang: 'en', prayed: {Prayer.dhuhr});
    await tester.pumpWidget(
      _app(
        AstrolabeLayer(state: s, onPrayerTap: tapped.add),
        lang: 'en',
      ),
    );
    await tester.pump();
    // Spoken in words, rounded up to the minute (2:29:42 → 2 h 30 min).
    expect(
      find.bySemanticsLabel(
        RegExp("Your day's astrolabe\\. Now: Asr.*\\. Maghrib in [^.:]*2[^.:]*30[^.:]*\\. 1 of 5 prayers done"),
      ),
      findsOneWidget,
    );
    expect(find.semantics.byLabel('Dhuhr: prayed'), findsOne);
    expect(find.semantics.byLabel("Asr: it's time"), findsOne);
    expect(find.semantics.byLabel('Fajr: missed'), findsOne);
    expect(find.semantics.byLabel(RegExp(r'^Isha: at \d')), findsOne);
    final asr = find.semantics.byLabel("Asr: it's time").evaluate().single;
    expect(asr.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    expect(asr.rect.center, offsetMoreOrLessEquals(_pointer(s, Prayer.asr), epsilon: 1));
    tester.semantics.tap(find.semantics.byLabel("Asr: it's time"));
    expect(tapped, [Prayer.asr]);
    handle.dispose();
  });

  testWidgets('logging a prayer ignites its pointer and calls the hook with its tip', (tester) async {
    final lit = <(Prayer, Offset)>[];
    final notifier = ValueNotifier(state({Prayer.fajr, Prayer.dhuhr}));
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<AstrolabeState>(
          valueListenable: notifier,
          builder: (_, s, _) => AstrolabeLayer(state: s, onPrayerLit: (p, tip) => lit.add((p, tip))),
        ),
      ),
    );
    await tester.pump();
    expect(lit, isEmpty, reason: 'the first state is not celebrated');
    notifier.value = state({Prayer.fajr, Prayer.dhuhr, Prayer.asr});
    await tester.pump();
    expect(lit, hasLength(1));
    expect(lit.single.$1, Prayer.asr);
    final expected = AstrolabeGeometry.pointerTip(
      _box.center(Offset.zero),
      AstrolabeGeometry.radiusFor(_box),
      notifier.value.fractionOf(Prayer.asr),
    );
    expect((lit.single.$2 - expected).distance, lessThan(1));
  });

  testWidgets('the default ignition hook plays the prayer chime', (tester) async {
    final notifier = ValueNotifier(state(const {}));
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<AstrolabeState>(
          valueListenable: notifier,
          builder: (_, s, _) => AstrolabeLayer(state: s),
        ),
      ),
    );
    notifier.value = state({Prayer.asr});
    await tester.pump();
    expect(sound.played, [Sfx.prayerLit]);
    expect(haptics.fired, contains(Haptic.heavy));
  });

  testWidgets('driven by the scene ticker: repaints without rebuilding', (tester) async {
    final controller = AstrolabeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(AstrolabeLayer(state: state(const {}), controller: controller)));
    await tester.pump();
    final finder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is AstrolabePainter);
    final painter = tester.widget<CustomPaint>(finder).painter;
    final render = tester.renderObject<RenderCustomPaint>(finder);
    for (var i = 0; i < 10; i++) {
      controller.advance(const Duration(milliseconds: 16));
      expect(render.debugNeedsPaint, isTrue);
      await tester.pump(const Duration(milliseconds: 16));
      expect(render.debugNeedsPaint, isFalse);
    }
    expect(identical(tester.widget<CustomPaint>(finder).painter, painter), isTrue, reason: 'no rebuilds per frame');
    // Without its own ticker the layer schedules nothing by itself.
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a tilt passed to the layer reaches the controller', (tester) async {
    final controller = AstrolabeController();
    addTearDown(controller.dispose);
    const tilt = AstrolabeTilt(pitch: 0.3, yaw: -0.2);
    await tester.pumpWidget(_app(AstrolabeLayer(state: state(const {}), controller: controller, tilt: tilt)));
    expect(controller.tilt, tilt);
  });

  testWidgets('reduced motion reaches the controller', (tester) async {
    final controller = AstrolabeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(AstrolabeLayer(state: state(const {}), controller: controller), reduced: true));
    expect(controller.reducedMotion, isTrue);
    await tester.pumpWidget(_app(AstrolabeLayer(state: state(const {}), controller: controller)));
    expect(controller.reducedMotion, isFalse);
  });

  testWidgets('standalone: animates only while ambient motion is allowed', (tester) async {
    await tester.pumpWidget(_app(AstrolabeLayer(state: state(const {}))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'decorative loops stay off under flutter test');

    AmbientMotion.debugOverride = true;
    addTearDown(() => AmbientMotion.debugOverride = null);
    await tester.pumpWidget(_app(AstrolabeLayer(key: const ValueKey('live'), state: state(const {}))));
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.binding.hasScheduledFrame, isTrue);
    // hidden (TickerMode off) → no frames
    await tester.pumpWidget(
      TickerMode(
        enabled: false,
        child: _app(AstrolabeLayer(key: const ValueKey('live'), state: state(const {}))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unmounting leaves an external controller usable', (tester) async {
    final controller = AstrolabeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(AstrolabeLayer(state: state(const {}), controller: controller)));
    await tester.pumpWidget(const SizedBox());
    controller.advance(const Duration(milliseconds: 16));
    controller.update(state({Prayer.fajr}));
    expect(controller.ignition(Prayer.fajr), lessThan(0.1));
  });

  testWidgets('swapping controllers moves the state over', (tester) async {
    final a = AstrolabeController();
    final b = AstrolabeController();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final s = state({Prayer.dhuhr});
    await tester.pumpWidget(_app(AstrolabeLayer(state: s, controller: a)));
    await tester.pumpWidget(_app(AstrolabeLayer(state: s, controller: b)));
    expect(b.state, same(s));
    expect(b.ignition(Prayer.dhuhr), 1);
  });

  group('render cache', () {
    testWidgets('the countdown image is re-rendered only when its text changes', (tester) async {
      final cache = AstrolabeRenderCache();
      addTearDown(cache.dispose);
      final labels = AmmanDay.labels('ar');
      final palette = AstrolabePalette.fromTokens(MadarPalettes.tokensFor(MadarThemeId.lapis));
      cache.ensureStatic(
        bucket: AstrolabeRenderCache.bucketFor(180),
        lod: AstrolabeLod.full,
        palette: palette,
        labels: labels,
      );
      final a = cache.ensureCountdown('العصر بعد ١:٢٣:٠٥', labels, 2);
      final again = cache.ensureCountdown('العصر بعد ١:٢٣:٠٥', labels, 2);
      expect(identical(a, again), isTrue);
      expect(cache.countdownRenders, 1);
      final next = cache.ensureCountdown('العصر بعد ١:٢٣:٠٤', labels, 2);
      expect(identical(a, next), isFalse);
      expect(cache.countdownRenders, 2);
      expect(next.width, greaterThan(next.height));
    });

    testWidgets('a zoom inside one size bucket never re-renders the countdown', (tester) async {
      final controller = AstrolabeController();
      addTearDown(controller.dispose);
      final st = state(const {});
      final bucket = AstrolabeRenderCache.bucketFor(AstrolabeGeometry.radiusFor(const Size.square(300)));
      final sides = [
        for (var side = 300.0; side <= 400; side += 4)
          if (AstrolabeRenderCache.bucketFor(AstrolabeGeometry.radiusFor(Size.square(side))) == bucket) side,
      ];
      expect(sides.length, greaterThan(3), reason: 'the fixture must zoom within one bucket');
      Future<AstrolabePainter> pumpAt(double side) async {
        await tester.pumpWidget(
          _app(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox.square(
                dimension: side,
                child: AstrolabeLayer(state: st, controller: controller),
              ),
            ),
          ),
        );
        await tester.pump();
        final finder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is AstrolabePainter);
        return tester.widget<CustomPaint>(finder).painter! as AstrolabePainter;
      }

      final first = await pumpAt(sides.first);
      final renders = first.cache.countdownRenders;
      final builds = first.cache.staticBuilds;
      expect(renders, greaterThan(0));
      for (final side in sides.skip(1)) {
        controller.advance(const Duration(milliseconds: 16));
        final p = await pumpAt(side);
        expect(p.cache.countdownRenders, renders, reason: 'side $side');
        expect(p.cache.staticBuilds, builds, reason: 'side $side');
      }
    });

    testWidgets('the static layer is rebuilt only when the size bucket, palette or language changes', (tester) async {
      final cache = AstrolabeRenderCache();
      addTearDown(cache.dispose);
      final ar = AmmanDay.labels('ar');
      final palette = AstrolabePalette.fromTokens(MadarPalettes.tokensFor(MadarThemeId.lapis));
      final b = AstrolabeRenderCache.bucketFor(180);
      expect(cache.ensureStatic(bucket: b, lod: AstrolabeLod.full, palette: palette, labels: ar), isTrue);
      expect(
        cache.ensureStatic(bucket: b, lod: AstrolabeLod.full, palette: palette, labels: AmmanDay.labels('ar')),
        isFalse,
      );
      expect(
        cache.ensureStatic(
          bucket: AstrolabeRenderCache.bucketFor(400),
          lod: AstrolabeLod.ultra,
          palette: palette,
          labels: ar,
        ),
        isTrue,
      );
      expect(cache.reteLabels.length, greaterThan(12), reason: 'zodiac and star names on large dials');
      expect(
        cache.ensureStatic(bucket: b, lod: AstrolabeLod.full, palette: palette, labels: AmmanDay.labels('en')),
        isTrue,
      );
      // The full detail level engraves star names where they fit, never
      // the zodiac.
      expect(cache.reteLabels.length, lessThan(12));
      expect(cache.staticBuilds, 3);
      cache.dispose();
      expect(cache.isDisposed, isTrue);
    });

    testWidgets('pointers and names follow the prayer statuses', (tester) async {
      final cache = AstrolabeRenderCache();
      addTearDown(cache.dispose);
      final labels = AmmanDay.labels('en');
      final palette = AstrolabePalette.fromTokens(MadarPalettes.tokensFor(MadarThemeId.pearl));
      cache.ensureStatic(
        bucket: AstrolabeRenderCache.bucketFor(180),
        lod: AstrolabeLod.full,
        palette: palette,
        labels: labels,
      );
      final s = AmmanDay.state(now, lang: 'en', prayed: {Prayer.dhuhr});
      cache
        ..ensurePrayers(state: s, palette: palette)
        ..ensureWindow(s);
      expect(cache.statuses[Prayer.dhuhr], AstrolabePrayerStatus.prayed);
      expect(cache.statuses[Prayer.asr], AstrolabePrayerStatus.due);
      expect(cache.pointerPaths, hasLength(5));
      expect(cache.labelCenters, hasLength(5));
      expect(cache.labels, isNotNull);
      expect(cache.arcSweep, greaterThan(0));
      expect(cache.arcDone, inExclusiveRange(0, cache.arcSweep));
    });
  });
}
