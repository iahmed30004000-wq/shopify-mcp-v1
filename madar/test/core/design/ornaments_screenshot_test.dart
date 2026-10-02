// Close-up critic pass for the decorative painters and illustrations.
//
//   flutter test --tags screenshot test/core/design/ornaments_screenshot_test.dart
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/widgets.dart';

import '../../helpers/screenshot_harness.dart';

class _Ornaments extends StatelessWidget {
  const _Ornaments();

  @override
  Widget build(BuildContext context) {
    return const MadarScaffold(
      body: Padding(
        padding: EdgeInsetsDirectional.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [GirihRosette(size: 190), AstrolabeRing(size: 190)],
            ),
            SizedBox(height: 16),
            ArabesqueBorder(height: 56),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OrbitLoader(size: 120),
                SizedBox(
                  width: 180,
                  height: 180,
                  child: AnimatedEmptyState(
                    kind: EmptyStateKind.noResults,
                    illustrationSize: 170,
                    padding: EdgeInsets.zero,
                    title: '',
                    body: '',
                  ),
                ),
              ],
            ),
            MadarDivider(),
          ],
        ),
      ),
    );
  }
}

void main() {
  for (final (theme, locale) in [
    (MadarThemeId.lapis, const Locale('ar')),
    (MadarThemeId.pearl, const Locale('ar')),
    (MadarThemeId.emerald, const Locale('en')),
  ]) {
    testWidgets('ornaments – ${theme.name} ${locale.languageCode}', (tester) async {
      final file = await captureScreen(
        tester,
        madarScreenshotApp(theme: theme, locale: locale, home: const _Ornaments()),
        'ornaments_${theme.name}_${locale.languageCode}',
        logicalSize: const Size(420, 620),
        dpr: 2.5,
      );
      expect(file.existsSync(), isTrue);
    });
  }
}
