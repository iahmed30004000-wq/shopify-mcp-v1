// Visual critic pass for the design system: renders the design gallery with
// the real fonts and shaders and writes PNGs to madar/screenshots/.
//
//   flutter test --tags screenshot test/core/design/gallery_screenshot_test.dart
@Tags(['screenshot'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/features/gallery/design_gallery_screen.dart';

import '../../helpers/screenshot_harness.dart';

Widget _gallery(MadarThemeId theme, Locale locale) => madarScreenshotApp(
  theme: theme,
  locale: locale,
  home: DesignGalleryScreen(initialTheme: theme),
);

Future<void> Function(WidgetTester) _scrollTo(double offset) => (tester) async {
  final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
  scrollable.position.jumpTo(offset);
  await tester.pump();
};

void main() {
  const ar = Locale('ar');
  const en = Locale('en');

  testWidgets('gallery – Lapis, RTL', (tester) async {
    final file = await captureScreen(tester, _gallery(MadarThemeId.lapis, ar), 'gallery_lapis_rtl');
    expect(file.existsSync(), isTrue);
  });

  testWidgets('gallery – Pearl, RTL', (tester) async {
    final file = await captureScreen(tester, _gallery(MadarThemeId.pearl, ar), 'gallery_pearl_rtl');
    expect(file.existsSync(), isTrue);
  });

  testWidgets('gallery – Aurora, LTR', (tester) async {
    final file = await captureScreen(tester, _gallery(MadarThemeId.aurora, en), 'gallery_aurora_ltr');
    expect(file.existsSync(), isTrue);
  });

  // Scrolled pages so every section gets a critic pass.
  for (final (theme, locale, tag) in [
    (MadarThemeId.lapis, ar, 'lapis_rtl'),
    (MadarThemeId.pearl, ar, 'pearl_rtl'),
    (MadarThemeId.aurora, en, 'aurora_ltr'),
    (MadarThemeId.emerald, ar, 'emerald_rtl'),
    (MadarThemeId.desert, ar, 'desert_rtl'),
  ]) {
    for (var page = 1; page <= 5; page++) {
      testWidgets('gallery page $page – $tag', (tester) async {
        final file = await captureScreen(
          tester,
          _gallery(theme, locale),
          'gallery_${tag}_p$page',
          beforeCapture: _scrollTo(page * 780.0),
        );
        expect(file.existsSync(), isTrue);
      });
    }
  }
}
