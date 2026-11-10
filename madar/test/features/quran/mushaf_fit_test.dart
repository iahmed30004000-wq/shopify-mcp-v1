// A mushaf page is fitted to its frame: the page must fit without scrolling
// whatever the system text size (review finding – the fit was measured
// without the text scaler the page is then drawn with, so at 1.3× every page
// overflowed its frame and scrolled).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/quran/data/quran_providers.dart';
import 'package:madar/features/quran/presentation/widgets/mushaf_page.dart';

import '../../helpers/screenshot_harness.dart';
import 'quran_test_data.dart';

void main() {
  final content = QuranContent(meta: QuranTestData.meta, text: QuranTestData.text);
  // Real metrics: the test font's square glyphs are far wider than Amiri's.
  setUpAll(loadMadarFonts);

  for (final scale in [1.0, 1.3, 2.0]) {
    for (final page in [1, 50, 440, 582, 604]) {
      testWidgets('page $page fits its frame at text scale $scale', (tester) async {
        tester.view.physicalSize = const Size(412, 915) * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        MushafFit.clearCache();
        await tester.pumpWidget(
          madarScreenshotApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: MushafPage(page: page, content: content, scale: 1, tajweed: false),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: find.byType(MushafPage), matching: find.byType(Scrollable)),
        );
        // Very large text may hit the smallest size and scroll instead.
        if (scale <= 1.3) expect(scrollable.position.maxScrollExtent, lessThan(1), reason: 'page $page overflows at $scale');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
