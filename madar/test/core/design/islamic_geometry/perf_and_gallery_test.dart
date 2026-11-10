import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/islamic_geometry/islamic_geometry.dart';

/// Performance numbers are measured on the shared 4-core test VM (debug-mode
/// Dart, software raster not involved: only recording is timed). Measured
/// 2026-11-10: building the 4 families = 0.37 ms best of 5 (first cold run
/// 2 to 8 ms); recording a 412x915 full-screen tile (repeat 6) = 0.34 to
/// 0.45 ms per family; a cached repaint (one drawPicture) = 7 to 9 us.
/// The asserted limits are the brief's (50 ms / 8 ms); real phones are faster.
void main() {
  setUp(() {
    PatternPictureCache.debugReset();
    PatternGeometry.debugClearCache();
  });

  test('building the four families takes < 50 ms in total', () {
    final times = <int>[];
    for (var run = 0; run < 5; run++) {
      final sw = Stopwatch()..start();
      for (final f in PatternFamily.values) {
        PatternGeometry.build(PatternSpec(family: f));
      }
      times.add(sw.elapsedMicroseconds);
    }
    times.sort();
    // ignore: avoid_print
    print('perf: build 4 families, best of 5 = ${times.first} us (all: $times)');
    expect(times.first, lessThan(50000));
  });

  test('recording a full-screen tile takes < 8 ms; a cached repaint is a single draw', () {
    const size = Size(412, 915);
    for (final f in PatternFamily.values) {
      PatternGeometry.cached(PatternSpec(family: f)); // geometry cost is measured above
    }
    var worstCold = 0;
    var worstHot = 0;
    for (final f in PatternFamily.values) {
      final spec = PatternSpec(family: f, repeat: 6);
      final colds = <int>[];
      for (var run = 0; run < 3; run++) {
        PatternPictureCache.debugReset();
        final painter = GeometryPatternPainter(spec: spec, color: Colors.amber);
        final sw = Stopwatch()..start();
        final rec = ui.PictureRecorder();
        painter.paint(Canvas(rec), size);
        colds.add(sw.elapsedMicroseconds);
        rec.endRecording().dispose();
      }
      colds.sort();

      // Hot path: 200 repaints of the same painter.
      final painter = GeometryPatternPainter(spec: spec, color: Colors.amber);
      painter.paint(Canvas(ui.PictureRecorder()), size);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        final rec = ui.PictureRecorder();
        painter.paint(Canvas(rec), size);
        rec.endRecording().dispose();
      }
      final hot = sw.elapsedMicroseconds ~/ 200;
      // ignore: avoid_print
      print('perf: ${f.name} full-screen cold record = ${colds.first} us, cached repaint = $hot us');
      if (colds.first > worstCold) worstCold = colds.first;
      if (hot > worstHot) worstHot = hot;
    }
    expect(worstCold, lessThan(8000));
    expect(worstHot, lessThan(8000));
    expect(PatternPictureCache.builds, 1, reason: 'the hot loop recorded nothing');
  });

  // Set MADAR_GALLERY_PNG=/some/file.png to also save the render (off by default).
  testWidgets('gallery page draws something: the picture is not just the background', (tester) async {
    const size = Size(440, 2150);
    const background = Color(0xFF0B1020);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: const MediaQueryData(size: size),
          child: RepaintBoundary(key: key, child: const PatternGalleryPage(background: background)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    final png = Platform.environment['MADAR_GALLERY_PNG'];
    final bytes = await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
      if (png != null) {
        File(png).writeAsBytesSync((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      }
      return (await image.toByteData())!.buffer.asUint8List();
    });
    var opaque = 0, notBackground = 0;
    final colours = <int>{};
    for (var i = 0; i < bytes!.length; i += 4) {
      if (bytes[i + 3] != 0) opaque++;
      final argb = (bytes[i + 3] << 24) | (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
      if (argb != background.toARGB32()) notBackground++;
      if (colours.length < 5000) colours.add(argb);
    }
    expect(opaque, greaterThan(0), reason: 'non-transparent pixels exist');
    expect(notBackground, greaterThan(20000), reason: 'ornaments cover a real share of the page');
    expect(colours.length, greaterThan(50), reason: 'several colours, anti-aliased lines');

  });
}
