import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/motion/motion.dart';
import 'package:madar/features/gallery/design_gallery_screen.dart';

import 'design_test_utils.dart';

MadarTokens _tokensIn(WidgetTester tester) => tester.element(find.byType(MadarScaffold)).tokens;

/// Scrolls every ancestor so [finder] sits mid-viewport (never under the
/// app bar that the gallery's content scrolls beneath).
Future<void> _center(WidgetTester tester, Finder finder) async {
  Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
}

void main() {
  setUp(installRecordingFx);

  Future<void> pumpGallery(WidgetTester tester, {Locale locale = const Locale('ar')}) async {
    tester.view.physicalSize = const Size(412, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpMadar(tester, const DesignGalleryScreen(), locale: locale, scaffold: false);
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('renders every section without errors (ar, RTL)', (tester) async {
    await pumpGallery(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('معرض التصميم'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(MadarScaffold))), TextDirection.rtl);
    expect(find.byType(GlassPanel), findsWidgets);
    expect(find.byType(GlassCard), findsWidgets);
    expect(find.byType(MadarSwitch), findsNWidgets(3));
  });

  testWidgets('English defaults to LTR', (tester) async {
    await pumpGallery(tester, locale: const Locale('en'));
    expect(find.text('Design gallery'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(MadarScaffold))), TextDirection.ltr);
  });

  testWidgets('theme switcher cross-fades to every theme', (tester) async {
    await pumpGallery(tester);
    expect(_tokensIn(tester).isDark, isTrue);
    final names = {
      MadarThemeId.emerald: 'زُمُرُّد',
      MadarThemeId.desert: 'صحراء',
      MadarThemeId.aurora: 'شَفَق',
      MadarThemeId.pearl: 'لؤلؤ',
      MadarThemeId.lapis: 'لازَوَرد',
    };
    for (final entry in names.entries) {
      await _center(tester, find.text(entry.value));
      await tester.tap(find.text(entry.value));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_tokensIn(tester).accent, MadarPalettes.tokensFor(entry.key).accent, reason: entry.key.name);
    }
  });

  testWidgets('direction toggle flips the whole page', (tester) async {
    await pumpGallery(tester);
    await tester.tap(find.text('من اليسار'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(Directionality.of(tester.element(find.byType(MadarScaffold))), TextDirection.ltr);
    await tester.tap(find.text('من اليمين'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(Directionality.of(tester.element(find.byType(MadarScaffold))), TextDirection.rtl);
  });

  testWidgets('reduce-motion switch drives the local MotionScope', (tester) async {
    await pumpGallery(tester);
    final motionSwitch = find.byType(MadarSwitch).last;
    await _center(tester, motionSwitch);
    expect(tester.element(find.byType(MadarScaffold)).reducedMotion, isFalse);
    await tester.tap(motionSwitch);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.element(find.byType(MadarScaffold)).reducedMotion, isTrue);
  });

  testWidgets('loading demo button shows the loader, then settles', (tester) async {
    await pumpGallery(tester);
    final save = find.widgetWithText(MadarButton, 'حفظ');
    await _center(tester, save);
    final loadersBefore = find.descendant(of: save, matching: find.byType(OrbitLoader)).evaluate().length;
    expect(loadersBefore, 0);
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.descendant(of: find.byType(MadarButton), matching: find.byType(OrbitLoader)), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.descendant(of: find.byType(MadarButton), matching: find.byType(OrbitLoader)), findsOneWidget);
  });
}
