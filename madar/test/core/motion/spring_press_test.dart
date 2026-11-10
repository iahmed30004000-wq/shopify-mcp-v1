import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/motion/motion.dart';
import 'package:madar/core/motion/spring_press.dart';
import 'package:madar/core/sound/sound_api.dart';

import 'motion_test_utils.dart';

double _scale(WidgetTester tester) {
  final t = tester.widget<ScaleTransition>(
    find.descendant(of: find.byType(SpringPress), matching: find.byType(ScaleTransition)),
  );
  return t.scale.value;
}

void main() {
  testWidgets('springs down on touch, bounces back on release, fires Fx on tap', (tester) async {
    final fx = installMotionFx();
    var taps = 0;
    await tester.pumpWidget(
      motionApp(
        Scaffold(
          body: Center(
            child: SpringPress(
              onTap: () => taps++,
              child: const SizedBox(width: 120, height: 60, child: Text('press')),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.text('press')));
    await pumpFrames(tester, 20);
    expect(_scale(tester), closeTo(MadarMotion.pressScale, 0.01));

    await gesture.up();
    await pumpFrames(tester, 3);
    expect(_scale(tester), lessThan(1));
    await tester.pumpAndSettle();
    expect(_scale(tester), 1);
    expect(taps, 1);
    expect(fx.sound.played, [Sfx.tap]);
    expect(fx.haptics.fired, [Haptic.selection]);
  });

  testWidgets('bouncy release overshoots past 1', (tester) async {
    await tester.pumpWidget(
      motionApp(
        Scaffold(
          body: Center(
            child: SpringPress(onTap: () {}, child: const SizedBox(width: 80, height: 80)),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SpringPress)));
    await pumpFrames(tester, 20);
    await gesture.up();
    var peak = 0.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 8));
      peak = peak > _scale(tester) ? peak : _scale(tester);
    }
    expect(peak, greaterThan(1.0));
    await tester.pumpAndSettle();
  });

  testWidgets('scroll-away releases the press without tapping', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      motionApp(
        Scaffold(
          body: ListView(
            children: [
              SpringPress(
                onTap: () => taps++,
                child: const SizedBox(height: 80, child: Text('row')),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.text('row')));
    await pumpFrames(tester, 10);
    expect(_scale(tester), lessThan(1));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(_scale(tester), 1);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 0);
  });

  testWidgets('reduced motion: no scale, feedback still fires', (tester) async {
    final fx = installMotionFx();
    await tester.pumpWidget(
      motionApp(
        reduced: true,
        Scaffold(
          body: Center(
            child: SpringPress(sfx: Sfx.toggleOn, onTap: () {}, child: const SizedBox(width: 60, height: 60)),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SpringPress)));
    await pumpFrames(tester, 10);
    expect(_scale(tester), 1);
    await gesture.up();
    await tester.pump();
    expect(fx.sound.played, [Sfx.toggleOn]);
  });

  testWidgets('visual-only mode decorates a child with its own gestures', (tester) async {
    var inner = 0;
    await tester.pumpWidget(
      motionApp(
        Scaffold(
          body: Center(
            child: SpringPress(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => inner++,
                child: const SizedBox(width: 60, height: 60),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SpringPress)));
    await pumpFrames(tester, 10);
    expect(_scale(tester), lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(inner, 1);
    expect(_scale(tester), 1);
  });

  testWidgets('disabled: no press, no tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      motionApp(
        Scaffold(
          body: Center(
            child: SpringPress(enabled: false, onTap: () => taps++, child: const SizedBox(width: 60, height: 60)),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(SpringPress));
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(_scale(tester), 1);
  });

  testWidgets('long press fires its own sound', (tester) async {
    final fx = installMotionFx();
    var long = 0;
    await tester.pumpWidget(
      motionApp(
        Scaffold(
          body: Center(
            child: SpringPress(onLongPress: () => long++, child: const SizedBox(width: 60, height: 60)),
          ),
        ),
      ),
    );
    await tester.longPress(find.byType(SpringPress));
    await tester.pumpAndSettle();
    expect(long, 1);
    expect(fx.sound.played, [Sfx.pickUp]);
  });
}
