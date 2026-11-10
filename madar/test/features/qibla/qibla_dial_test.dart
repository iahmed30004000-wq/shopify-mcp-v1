// The dial widget: springs (with and without reduced motion), the cached
// engraving, the needle geometry and painting at degenerate sizes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/features/qibla/qibla.dart';

import '../../helpers/screenshot_harness.dart' show madarScreenshotApp;

void main() {
  QiblaDialStyle style(BuildContext context) => QiblaDialStyle.of(
    Theme.of(context).extension()!,
    cardinals: const ['N', 'E', 'S', 'W'],
    arabicDigits: false,
    degreeLabel: (d) => '${d.round()}°',
  );

  Future<ValueNotifier<double?>> pumpDial(WidgetTester tester, {bool reduced = false, double? facing, Size size = const Size(360, 370)}) async {
    final notifier = ValueNotifier<double?>(facing);
    addTearDown(notifier.dispose);
    await tester.pumpWidget(
      madarScreenshotApp(
        theme: MadarThemeId.lapis,
        locale: const Locale('en'),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
            child: SizedBox.fromSize(
              size: size,
              child: Builder(
                builder: (context) => QiblaDial(facing: notifier, qiblaBearing: 160.7, style: style(context), semanticLabel: 'dial'),
              ),
            ),
          ),
        ),
      ),
    );
    return notifier;
  }

  QiblaDialPainter painterOf(WidgetTester tester) =>
      tester.widget<CustomPaint>(find.descendant(of: find.byType(QiblaDial), matching: find.byType(CustomPaint))).painter!
          as QiblaDialPainter;

  testWidgets('dial and needle spring to −facing and (qibla − facing), the short way round', (tester) async {
    final facing = await pumpDial(tester);
    final p = painterOf(tester);
    expect(p.dial.value, closeTo(0, 1e-9));
    expect(p.needle.value, closeTo(160.7, 1e-9));
    facing.value = 350; // −350 ≡ +10: the dial turns 10° clockwise, not 350° back
    await tester.pumpAndSettle();
    expect(p.dial.value, closeTo(10, 0.05));
    expect(p.needle.value, closeTo(170.7, 0.05));
    facing.value = 5; // through north again
    await tester.pumpAndSettle();
    expect(p.dial.value, closeTo(-5, 0.05));
  });

  testWidgets('the needle overshoots a little by default (a real needle)', (tester) async {
    final facing = await pumpDial(tester, facing: 160.7);
    final p = painterOf(tester);
    facing.value = 100.7; // needle 0 → 60
    var max = 0.0;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (p.needle.value > max) max = p.needle.value;
    }
    expect(max, greaterThan(60.5));
  });

  testWidgets('reduced motion: no spring overshoot', (tester) async {
    final facing = await pumpDial(tester, reduced: true, facing: 160.7);
    final p = painterOf(tester);
    facing.value = 100.7;
    var maxNeedle = 0.0;
    var maxDial = -360.0;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (p.needle.value > maxNeedle) maxNeedle = p.needle.value;
      if (p.dial.value > maxDial) maxDial = p.dial.value;
    }
    expect(maxNeedle, lessThanOrEqualTo(60.0 + 1e-6));
    expect(maxNeedle, closeTo(60, 0.05));
    // The dial climbs from −160.7° to −100.7° and never past it.
    expect(maxDial, lessThanOrEqualTo(-100.7 + 1e-6));
    expect(maxDial, closeTo(-100.7, 0.05));
  });

  testWidgets('the engraving is rasterised once while the dial turns', (tester) async {
    final facing = await pumpDial(tester);
    for (var h = 0; h < 360; h += 30) {
      facing.value = h.toDouble();
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pumpAndSettle();
    expect(painterOf(tester).engraving.renders, 1);
  });

  testWidgets('semantics label and degenerate sizes paint without errors', (tester) async {
    await pumpDial(tester, size: const Size(4, 4));
    expect(tester.takeException(), isNull);
    await pumpDial(tester, size: const Size(60, 400));
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('dial'), findsOneWidget);
  });

  test('geometry: the dial fits its box with room for the kursi', () {
    const size = Size(372, 380);
    final r = QiblaDialGeometry.radiusFor(size);
    final c = QiblaDialGeometry.centerFor(size);
    expect(c.dy - r * 1.22, greaterThanOrEqualTo(0)); // kursi ring
    expect(c.dy + r * 1.03, lessThanOrEqualTo(size.height));
    expect(c.dx - r * 1.12, greaterThanOrEqualTo(0)); // turn arrow
  });
}
