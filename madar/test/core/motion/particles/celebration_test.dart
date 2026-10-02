import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/motion/motion.dart';
import 'package:madar/core/motion/particles/celebration.dart';
import 'package:madar/core/sound/sound_api.dart';

import '../motion_test_utils.dart';

Widget _app({bool reduced = false, MadarThemeId theme = MadarThemeId.lapis, Widget? home}) => motionApp(
  reduced: reduced,
  theme: theme,
  builder: (context, child) => CelebrationOverlay(child: child!),
  home ??
      const Scaffold(
        body: Center(child: SizedBox(width: 80, height: 80, child: Text('target'))),
      ),
);

CelebrationOverlayState _overlay(WidgetTester tester) =>
    tester.state<CelebrationOverlayState>(find.byType(CelebrationOverlay));

void main() {
  for (final kind in CelebrationKind.values) {
    testWidgets('burst ${kind.name}: particles live, then the ticker sleeps', (tester) async {
      await tester.pumpWidget(_app());
      final context = tester.element(find.text('target'));
      Celebrate.burst(context, const Offset(200, 300), kind: kind);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      final overlay = _overlay(tester);
      expect(overlay.system.pool.count, greaterThan(0));
      expect(overlay.isTicking, isTrue);
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(overlay.system.pool.count, lessThanOrEqualTo(overlay.system.capacity));
      }
      expect(overlay.system.isIdle, isTrue);
      expect(overlay.isTicking, isFalse);
    });
  }

  testWidgets('burstFrom rings the widget and fires feedback', (tester) async {
    final fx = installMotionFx();
    await tester.pumpWidget(_app());
    Celebrate.burstFrom(tester.element(find.text('target')), kind: CelebrationKind.orbitalRing, sfx: Sfx.prayerLit);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_overlay(tester).system.pool.count, greaterThan(0));
    expect(fx.sound.played, [Sfx.prayerLit]);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('reduced motion: no particles, a single soft flash', (tester) async {
    await tester.pumpWidget(_app(reduced: true));
    final context = tester.element(find.text('target'));
    Celebrate.burst(context, const Offset(100, 100));
    await tester.pump(const Duration(milliseconds: 16));
    final overlay = _overlay(tester);
    expect(overlay.system.pool.count, 0);
    expect(overlay.system.flashCount, 1);

    final handle = Celebrate.ambient(context, kind: CelebrationKind.lightRain);
    expect(handle.isActive, isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    expect(overlay.system.pool.count, 0);
    expect(overlay.system.emitterCount, 0);
    await tester.pumpAndSettle();
    expect(overlay.isTicking, isFalse);
  });

  testWidgets('ambient effects run for their duration and can be stopped', (tester) async {
    await tester.pumpWidget(_app());
    final context = tester.element(find.text('target'));
    final lanterns = Celebrate.ambient(context, kind: CelebrationKind.lanternSparks, duration: null);
    final rain = Celebrate.ambient(context, kind: CelebrationKind.lightRain, duration: const Duration(seconds: 1));
    final ring = Celebrate.ambient(context, kind: CelebrationKind.orbitalRing, duration: const Duration(seconds: 1));
    final drift = Celebrate.ambient(context, kind: CelebrationKind.stardust, duration: const Duration(seconds: 1));
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final overlay = _overlay(tester);
    expect(overlay.system.pool.count, greaterThan(10));
    expect(rain.isActive, isFalse);
    expect(ring.isActive, isFalse);
    expect(drift.isActive, isFalse);
    expect(lanterns.isActive, isTrue);
    lanterns.stop();
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(overlay.system.isIdle, isTrue);
    expect(overlay.isTicking, isFalse);
  });

  testWidgets('light theme composites normally; no overlay is a no-op', (tester) async {
    await tester.pumpWidget(_app(theme: MadarThemeId.pearl));
    Celebrate.burst(tester.element(find.text('target')), const Offset(50, 50));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_overlay(tester).system.pool.count, greaterThan(0));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(motionApp(const Scaffold(body: Text('bare'))));
    final handle = Celebrate.ambient(tester.element(find.text('bare')), kind: CelebrationKind.stardust);
    Celebrate.burst(tester.element(find.text('bare')), Offset.zero);
    expect(handle.isActive, isFalse);
  });

  testWidgets('the overlay never takes pointers', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: Center(
            child: TextButton(onPressed: () => taps++, child: const Text('target')),
          ),
        ),
      ),
    );
    Celebrate.burst(tester.element(find.text('target')), tester.getCenter(find.text('target')));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.text('target'));
    expect(taps, 1);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('switching reduced motion on clears effects in flight', (tester) async {
    Widget app(bool reduced) => MaterialApp(
      theme: buildMadarTheme(MadarThemeId.lapis, arabic: true),
      builder: (context, child) => MotionScope(
        reduced: reduced,
        child: CelebrationOverlay(child: child!),
      ),
      home: const Scaffold(body: Text('target')),
    );
    await tester.pumpWidget(app(false));
    Celebrate.ambient(tester.element(find.text('target')), kind: CelebrationKind.lanternSparks, duration: null);
    await pumpFrames(tester, 20);
    final overlay = _overlay(tester);
    expect(overlay.system.pool.count, greaterThan(0));
    await tester.pumpWidget(app(true));
    expect(overlay.system.isIdle, isTrue);
    await tester.pump(const Duration(milliseconds: 50));
    expect(overlay.isTicking, isFalse);
  });
}
