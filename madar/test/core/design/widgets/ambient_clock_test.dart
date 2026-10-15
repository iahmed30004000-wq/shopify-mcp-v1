import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/widgets.dart';

import '../design_test_utils.dart';

/// Counts the frames requested while an idle screen sits still for [steps]
/// vsyncs of [vsync] (e.g. 120 × 8.33 ms = one second at 120 Hz).
Future<int> framesRequested(WidgetTester tester, {int steps = 120, Duration vsync = const Duration(microseconds: 8333)}) async {
  var frames = 0;
  for (var i = 0; i < steps; i++) {
    await tester.binding.delayed(vsync);
    if (tester.binding.hasScheduledFrame) frames++;
    await tester.pump();
  }
  return frames;
}

Widget _screen({bool ambient = true}) => AmbientMotionScope(
  enabled: ambient,
  child: const CosmosBackdrop(
    child: Center(child: GlassPanel(child: SizedBox(width: 120, height: 80))),
  ),
);

void main() {
  setUp(() => AmbientMotion.debugOverride = true);
  tearDown(() => AmbientMotion.debugOverride = null);

  testWidgets('the cosmos and a glass sheen request ~30 frames a second at 120 Hz, not 120', (tester) async {
    await pumpMadar(tester, _screen(), scaffold: false);
    await tester.pump();
    expect(AmbientClock.instance.debugListeners, 2);
    expect(AmbientClock.instance.debugRunning, isTrue);
    final frames = await framesRequested(tester);
    expect(frames, inInclusiveRange(28, 32));
  });

  testWidgets('the drift advances with the clock', (tester) async {
    await pumpMadar(tester, _screen(), scaffold: false);
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<CosmosBackdropPainter>()
        .single;
    final t0 = painter.time.value;
    await tester.pump(const Duration(seconds: 1));
    expect(painter.time.value - t0, closeTo(1, 0.05));
  });

  testWidgets('battery saver (AmbientMotionScope off) requests no frames at all', (tester) async {
    await pumpMadar(tester, _screen(ambient: false), scaffold: false);
    await tester.pumpAndSettle();
    expect(AmbientClock.instance.debugListeners, 0);
    expect(await framesRequested(tester, steps: 60), 0);
  });

  testWidgets('reduced motion requests no frames either', (tester) async {
    await pumpMadar(tester, _screen(), scaffold: false, reducedMotion: true);
    await tester.pumpAndSettle();
    expect(AmbientClock.instance.debugListeners, 0);
    expect(await framesRequested(tester, steps: 60), 0);
  });

  testWidgets('switching battery saver on stops the clock; off resumes it', (tester) async {
    await pumpMadar(tester, _screen(), scaffold: false);
    expect(AmbientClock.instance.debugRunning, isTrue);
    await pumpMadar(tester, _screen(ambient: false), scaffold: false);
    expect(AmbientClock.instance.debugListeners, 0);
    expect(AmbientClock.instance.debugRunning, isFalse);
    await pumpMadar(tester, _screen(), scaffold: false);
    expect(AmbientClock.instance.debugListeners, 2);
  });

  testWidgets('TickerMode off (a covered route) unsubscribes', (tester) async {
    await pumpMadar(tester, TickerMode(enabled: false, child: _screen()), scaffold: false);
    expect(AmbientClock.instance.debugListeners, 0);
  });

  testWidgets('disposing every ambient widget stops the timer', (tester) async {
    await pumpMadar(tester, _screen(), scaffold: false);
    expect(AmbientClock.instance.debugRunning, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(AmbientClock.instance.debugRunning, isFalse);
    expect(MadarThemeId.values, isNotEmpty);
  });
}
