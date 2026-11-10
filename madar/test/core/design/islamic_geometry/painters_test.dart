import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/islamic_geometry/islamic_geometry.dart';
import 'package:madar/core/design/themes.dart';

const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);

/// Paints [painter] into a real picture (sizes include degenerate ones).
void paintAll(CustomPainter painter, {List<Size>? sizes}) {
  for (final size in sizes ?? const [Size.zero, Size(1, 1), Size(24, 24), Size(160, 90), Size(412, 64), Size(390, 844)]) {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    recorder.endRecording().dispose();
  }
}

/// Rasterises [widget] at [size] and returns RGBA bytes.
Future<Uint8List> render(WidgetTester tester, Widget widget, Size size, {TextDirection dir = TextDirection.ltr}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: dir,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: RepaintBoundary(key: boundary, child: widget),
      ),
    ),
  );
  final bytes = await tester.runAsync(() async {
    final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
    final data = await image.toByteData();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

/// Pixels of [rgba] (width [w]) that are mostly [c], within the region.
int countColour(Uint8List rgba, int w, int h, Color c, {int x0 = 0, int x1 = -1}) {
  final end = x1 < 0 ? w : x1;
  var n = 0;
  final r = (c.r * 255).round(), b = (c.b * 255).round();
  for (var y = 0; y < h; y++) {
    for (var x = x0; x < end; x++) {
      final i = (y * w + x) * 4;
      if (rgba[i + 3] > 128 && (rgba[i] - r).abs() < 90 && (rgba[i + 2] - b).abs() < 90 && (rgba[i + 1]) < 90) n++;
    }
  }
  return n;
}

int litPixels(Uint8List rgba) {
  var n = 0;
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] > 0) n++;
  }
  return n;
}

void main() {
  setUp(() {
    PatternPictureCache.debugReset();
    PatternGeometry.debugClearCache();
  });

  group('GeometryPatternPainter', () {
    test('paints every family at several sizes without throwing', () {
      for (final f in PatternFamily.values) {
        for (final glow in [null, const Color(0x88FFD54F)]) {
          paintAll(
            GeometryPatternPainter(
              spec: PatternSpec(family: f, repeat: 5),
              color: _red,
              opacity: 0.7,
              fillColor: const Color(0x22FFFFFF),
              glowColor: glow,
            ),
          );
        }
      }
    });

    test('odd inputs (NaN angle, huge repeat, tall thin box) stay total', () {
      paintAll(
        GeometryPatternPainter(
          spec: const PatternSpec(family: PatternFamily.girih10, contactAngle: double.nan, lineWidth: -5, repeat: 99999),
          color: _red,
          opacity: 5,
        ),
        sizes: const [Size(20, 4000), Size(4000, 20), Size(0.5, 0.5)],
      );
    });

    test('the second paint comes from the cache: one geometry build, one picture build', () {
      const spec = PatternSpec(family: PatternFamily.square4);
      final geometryBefore = PatternGeometry.debugBuildCount;
      final painter = GeometryPatternPainter(spec: spec, color: _red);
      paintAll(painter, sizes: const [Size(300, 500)]);
      expect(PatternPictureCache.builds, 1);
      expect(PatternPictureCache.hits, 0);

      paintAll(painter, sizes: const [Size(300, 500)]);
      // A fresh but equal painter (as a rebuilt widget would create) hits too.
      paintAll(GeometryPatternPainter(spec: spec, color: _red), sizes: const [Size(300, 500)]);
      expect(PatternPictureCache.builds, 1, reason: 'nothing recorded again');
      expect(PatternPictureCache.hits, 2);
      expect(PatternGeometry.debugBuildCount - geometryBefore, 1);

      // A different colour or size is a different picture, same geometry.
      paintAll(GeometryPatternPainter(spec: spec, color: _blue), sizes: const [Size(300, 500)]);
      paintAll(painter, sizes: const [Size(300, 501)]);
      expect(PatternPictureCache.builds, 3);
      expect(PatternGeometry.debugBuildCount - geometryBefore, 1);
    });

    test('shouldRepaint only when something that shows changed', () {
      const spec = PatternSpec(family: PatternFamily.hex6);
      final a = GeometryPatternPainter(spec: spec, color: _red);
      expect(a.shouldRepaint(GeometryPatternPainter(spec: spec, color: _red)), isFalse);
      expect(a.shouldRepaint(GeometryPatternPainter(spec: spec, color: _blue)), isTrue);
      expect(a.shouldRepaint(GeometryPatternPainter(spec: spec.copyWith(contactAngle: 0.5), color: _red)), isTrue);
    });

    testWidgets('draws visible lines', (tester) async {
      final bytes = await render(
        tester,
        CustomPaint(painter: GeometryPatternPainter(spec: const PatternSpec(family: PatternFamily.rosette12, repeat: 3), color: _red), size: const Size(200, 200)),
        const Size(200, 200),
      );
      expect(litPixels(bytes), greaterThan(800));
    });
  });

  group('ornament widgets', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('divider, frame, ring, bloom and lattice build at text scale $scale', (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQueryData(size: const Size(360, 700), textScaler: TextScaler.linear(scale)),
              child: Material(
                child: ListView(
                  children: [
                    const PatternDivider(spec: PatternSpec(family: PatternFamily.square4), color: _red),
                    SizedBox(
                      height: 160,
                      child: PatternFrame(
                        spec: const PatternSpec(family: PatternFamily.girih10),
                        color: _red,
                        child: Text('نص', style: TextStyle(fontSize: 16 * scale)),
                      ),
                    ),
                    const StarProgressRing(value: 0.4, progressColor: _red, trackColor: _blue, child: Text('40')),
                    const StarProgressRing(value: 0.9, points: 12, progressColor: _red, trackColor: _blue),
                    const SizedBox(
                      height: 120,
                      child: PatternBloomReveal(progress: 0.5, spec: PatternSpec(family: PatternFamily.hex6), color: _red),
                    ),
                    const SizedBox(
                      height: 120,
                      child: MashrabiyaLattice(barColor: _red, lightColor: _blue, cellSize: 30),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      });
    }

    test('divider, frame and lattice painters survive degenerate sizes', () {
      const spec = PatternSpec(family: PatternFamily.rosette12);
      paintAll(PatternDividerPainter(spec: spec, color: _red));
      paintAll(PatternFramePainter(spec: spec, color: _red, thickness: 14));
      paintAll(PatternFramePainter(spec: spec, color: _red, thickness: 500));
      paintAll(MashrabiyaPainter(barColor: _red, lightColor: _blue));
      for (final f in PatternFamily.values) {
        paintAll(MashrabiyaPainter(barColor: _red, lightColor: _blue, family: f, cellSize: 0));
      }
    });

    test('repeat paints of divider / frame / lattice are cache hits', () {
      const spec = PatternSpec(family: PatternFamily.square4);
      for (final make in <CustomPainter Function()>[
        () => PatternDividerPainter(spec: spec, color: _red),
        () => PatternFramePainter(spec: spec, color: _red, thickness: 12),
        () => MashrabiyaPainter(barColor: _red, lightColor: _blue),
      ]) {
        PatternPictureCache.debugReset();
        paintAll(make(), sizes: const [Size(300, 120)]);
        paintAll(make(), sizes: const [Size(300, 120)]);
        expect(PatternPictureCache.builds, 1);
        expect(PatternPictureCache.hits, 1);
      }
    });

    testWidgets('frame leaves its inside to the child and draws only a band', (tester) async {
      final bytes = await render(
        tester,
        const SizedBox(
          width: 200,
          height: 200,
          child: PatternFrame(spec: PatternSpec(family: PatternFamily.square4), color: _red, thickness: 20, child: SizedBox.expand()),
        ),
        const Size(200, 200),
      );
      // Pixels strictly inside the child box (30px in) are untouched.
      var inner = 0;
      for (var y = 30; y < 170; y++) {
        for (var x = 30; x < 170; x++) {
          if (bytes[(y * 200 + x) * 4 + 3] > 0) inner++;
        }
      }
      expect(inner, 0);
      expect(litPixels(bytes), greaterThan(500));
    });
  });

  group('PatternBloomReveal', () {
    test('radius fraction is monotonic, starts at 0, ends at 1, and tolerates junk', () {
      var last = -1.0;
      for (var i = 0; i <= 200; i++) {
        final f = PatternBloom.radiusFraction(i / 200);
        expect(f, greaterThanOrEqualTo(last));
        last = f;
      }
      expect(PatternBloom.radiusFraction(0), 0);
      expect(PatternBloom.radiusFraction(1), 1);
      expect(PatternBloom.radiusFraction(-3), 0);
      expect(PatternBloom.radiusFraction(7), 1);
      expect(PatternBloom.radiusFraction(double.nan), 0);
    });

    test('reduced motion jumps to the end state, normal motion passes through', () {
      expect(PatternBloom.effectiveProgress(0, reducedMotion: true), 0);
      expect(PatternBloom.effectiveProgress(0.01, reducedMotion: true), 1);
      expect(PatternBloom.effectiveProgress(0.4, reducedMotion: false), 0.4);
      expect(PatternBloom.effectiveProgress(double.nan, reducedMotion: false), 0);
    });

    testWidgets('widget under disableAnimations paints the finished bloom at once', (tester) async {
      PatternBloomPainter? painterOf() {
        final paint = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere((c) => c.foregroundPainter != null || c.painter != null);
        return paint.foregroundPainter as PatternBloomPainter?;
      }

      Future<void> pump(double progress, bool reduced) => tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(size: const Size(200, 200), disableAnimations: reduced),
            child: PatternBloomReveal(progress: progress, spec: const PatternSpec(family: PatternFamily.hex6), color: _red),
          ),
        ),
      );

      await pump(0.05, true);
      expect(painterOf()!.progress, 1.0);
      await pump(0.05, false);
      expect(painterOf()!.progress, 0.05);
    });

    testWidgets('the revealed area only ever grows with progress', (tester) async {
      final counts = <int>[];
      for (final p in [0.1, 0.25, 0.4, 0.6, 0.8, 1.0]) {
        final bytes = await render(
          tester,
          CustomPaint(
            size: const Size(240, 240),
            painter: PatternBloomPainter(
              progress: p,
              spec: const PatternSpec(family: PatternFamily.square4, repeat: 8),
              color: _red,
              waveColor: const Color(0x00000000),
            ),
          ),
          const Size(240, 240),
        );
        counts.add(litPixels(bytes));
      }
      for (var i = 1; i < counts.length; i++) {
        expect(counts[i], greaterThanOrEqualTo(counts[i - 1]), reason: 'coverage per step: $counts');
      }
      expect(counts.last, greaterThan(counts.first * 2));
    });

    test('painter total for odd origins and sizes', () {
      for (final origin in [Alignment.topLeft, Alignment.bottomRight, const Alignment(3, -3)]) {
        for (final p in [0.0, 0.3, 1.0]) {
          paintAll(PatternBloomPainter(progress: p, spec: const PatternSpec(family: PatternFamily.girih10), color: _red, origin: origin));
        }
      }
    });
  });

  group('StarProgressRing', () {
    test('geometry: starts at the top tip, runs clockwise, closes on itself', () {
      for (final points in [8, 12]) {
        final cw = StarRingGeometry(points);
        expect(cw.pointAt(0).x, closeTo(0, 1e-12));
        expect(cw.pointAt(0).y, closeTo(-1, 1e-12));
        expect(cw.pointAt(1).distanceTo(cw.pointAt(0)), lessThan(1e-9));
        expect(cw.pointAt(0.25).x, greaterThan(0.3), reason: 'a quarter turn is on the right');
        expect(cw.pointAt(0.5).y, greaterThan(0.9), reason: 'half way is the bottom tip');
        final ccw = StarRingGeometry(points, clockwise: false);
        expect(ccw.pointAt(0.25).x, lessThan(-0.3));
        expect(ccw.pointAt(0.25).y, closeTo(cw.pointAt(0.25).y, 1e-12));
        for (var k = 1; k <= cw.vertexCount; k++) {
          expect(cw.cum[k], greaterThan(cw.cum[k - 1]));
        }
        expect(cw.cum.last, 1);
        expect(cw.pointAt(double.nan).isFinite, isTrue);
      }
    });

    test('direction follows the reading direction unless forced', () {
      expect(StarProgressRing.resolveClockwise(StarRingDirection.auto, TextDirection.ltr), isTrue);
      expect(StarProgressRing.resolveClockwise(StarRingDirection.auto, TextDirection.rtl), isFalse);
      expect(StarProgressRing.resolveClockwise(StarRingDirection.clockwise, TextDirection.rtl), isTrue);
      expect(StarProgressRing.resolveClockwise(StarRingDirection.anticlockwise, TextDirection.ltr), isFalse);
    });

    test('painter is total for junk values and tiny sizes', () {
      for (final v in [double.nan, -1.0, 0.0, 0.5, 1.0, 7.0, double.infinity]) {
        paintAll(StarProgressRingPainter(value: v, trackColor: _blue, progressColor: _red, glowColor: _red));
      }
    });

    Future<Uint8List> ring(WidgetTester tester, double value, {TextDirection dir = TextDirection.ltr, int points = 8}) => render(
      tester,
      StarProgressRing(
        value: value,
        points: points,
        size: 200,
        strokeWidth: 8,
        progressColor: _red,
        trackColor: _blue,
        animationDuration: Duration.zero,
      ),
      const Size(200, 200),
      dir: dir,
    );

    for (final points in [8, 12]) {
      testWidgets('$points points: value 0 shows only the track, 1 covers it, 0.5 fills the right half (LTR)', (tester) async {
        final empty = await ring(tester, 0, points: points);
        expect(countColour(empty, 200, 200, _red), 0);
        expect(countColour(empty, 200, 200, _blue), greaterThan(500));

        final half = await ring(tester, 0.5, points: points);
        final redRight = countColour(half, 200, 200, _red, x0: 106);
        final redLeft = countColour(half, 200, 200, _red, x1: 94);
        expect(redRight, greaterThan(300));
        expect(redLeft, 0, reason: 'nothing filled on the left yet');
        expect(countColour(half, 200, 200, _blue, x1: 94), greaterThan(300), reason: 'left still shows the track');

        final full = await ring(tester, 1, points: points);
        expect(countColour(full, 200, 200, _red, x0: 106), greaterThan(300));
        expect(countColour(full, 200, 200, _red, x1: 94), greaterThan(300));
        expect(countColour(full, 200, 200, _blue), lessThan(countColour(empty, 200, 200, _blue) ~/ 10), reason: 'track fully covered');
      });
    }

    testWidgets('in RTL the same 0.5 fills the left half', (tester) async {
      final half = await ring(tester, 0.5, dir: TextDirection.rtl);
      expect(countColour(half, 200, 200, _red, x1: 94), greaterThan(300));
      expect(countColour(half, 200, 200, _red, x0: 106), 0);
    });

    testWidgets('semantics come from the caller and reduced motion snaps to the value', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: StarProgressRing(value: 0.2, progressColor: _red, trackColor: _blue, semanticLabel: 'label', semanticValue: 'value'),
          ),
        ),
      );
      expect(find.bySemanticsLabel('label'), findsOneWidget);
      final painter = tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter! as StarProgressRingPainter;
      expect(painter.value, 0.2, reason: 'no tween under reduced motion');
    });
  });

  group('PatternPalette', () {
    test('every planet key gets a distinct (family, angle) and the planet colours', () {
      final keys = ['faith', 'health', 'family', 'work', 'money', 'growth', 'body', 'travel', 'sufra', 'games'];
      expect(PatternPalette.planetKeys.toSet(), keys.toSet());
      final seen = <String>{};
      for (final k in keys) {
        final p = PatternPalette.forPlanet(k);
        expect(seen.add('${p.spec.family.name}@${p.spec.resolvedContactAngle}'), isTrue, reason: k);
        expect(p.color, PlanetPalettes.byKey[k]!.surface);
        expect(p.accent, PlanetPalettes.byKey[k]!.glow);
        // The geometry builds with the exact angle, not a clamped one.
        expect(PatternGeometry.build(p.spec).contactAngle, p.spec.contactAngle);
      }
      expect(keys.map((k) => PatternPalette.forPlanet(k).spec.family).toSet(), hasLength(4), reason: 'all four families are used');
    });

    test('an unknown key is stable and valid; a colour override wins', () {
      final a = PatternPalette.forPlanet('my-garden'), b = PatternPalette.forPlanet('my-garden');
      expect(a.spec, b.spec);
      expect(a.color, b.color);
      expect(PatternGeometry.build(a.spec).lines, isNotEmpty);
      expect(PatternPalette.forPlanet('my-garden', fallbackColor: _red).color, _red);
      expect(PatternPalette.forPlanet('faith', fallbackColor: _red).color, _red);
      expect(PatternPalette.forPlanet('').spec.family, isA<PatternFamily>());
    });
  });
}
