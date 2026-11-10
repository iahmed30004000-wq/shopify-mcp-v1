@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/typography.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/quran/data/quran_providers.dart';
import 'package:madar/features/quran/presentation/widgets/ayah_spans.dart';

import '../../helpers/screenshot_harness.dart';
import 'quran_test_data.dart';

/// Proof that tajweed colour runs keep Arabic letters joined and marks in
/// place: each ayah is drawn plain (top) and coloured (bottom) at a large
/// size; the glyphs must sit in exactly the same places.
class _Proof extends StatelessWidget {
  const _Proof(this.refs, {this.size = 40});

  final List<AyahRef> refs;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final meta = QuranTestData.meta;
    final content = QuranContent(meta: meta, text: QuranTestData.text, tajweed: QuranTestData.tajweed);
    final base = MadarTypography.quran(t, size: size).copyWith(height: 1.9);
    return Scaffold(
      backgroundColor: t.space1,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final r in refs) ...[
              for (final tajweed in [false, true])
                Text.rich(
                  TextSpan(
                    children: AyahSpans.ayah(content.ayah(meta.indexOf(r)), base, t, paint: AyahPaint(tajweed: tajweed)),
                  ),
                  textDirection: TextDirection.rtl,
                ),
              Divider(color: t.glassBorder),
            ],
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('tajweed runs keep letters joined – large', (tester) async {
    await captureScreen(
      tester,
      madarScreenshotApp(home: const _Proof([AyahRef(2, 5), AyahRef(2, 3), AyahRef(2, 2)]), theme: MadarThemeId.lapis),
      'phase3/quran/tajweed_joining_proof_lapis',
      logicalSize: const Size(412, 1400),
    );
  });

  testWidgets('tajweed runs keep letters joined – larger, pearl', (tester) async {
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: const _Proof([AyahRef(18, 10), AyahRef(2, 7), AyahRef(97, 1)], size: 46),
        theme: MadarThemeId.pearl,
      ),
      'phase3/quran/tajweed_joining_proof_pearl',
      logicalSize: const Size(412, 1900),
    );
  });
}
