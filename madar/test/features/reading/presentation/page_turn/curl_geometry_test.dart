import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/reading/presentation/page_turn/book_direction.dart';
import 'package:madar/features/reading/presentation/page_turn/curl_geometry.dart';
import 'package:madar/features/reading/presentation/page_turn/turn_logic.dart';

const _leaf = Rect.fromLTWH(0, 0, 300, 400);

Matcher _near(Offset o, [double eps = 1e-6]) => predicate<Offset>(
  (p) => (p - o).distance < eps,
  'is within $eps of $o',
);

Offset _apply(Matrix4 m, Offset p) {
  final v = MatrixUtils.transformPoint(m, p);
  return v;
}

void main() {
  group('edge grab, spine on the left (English book)', () {
    final g = CurlGeometry(leaf: _leaf, spine: SpineSide.left, grab: const Offset(300, 200), touch: const Offset(200, 200));

    test('fold line is the bisector of grab-touch', () {
      expect(g.foldPoint, _near(const Offset(250, 200)));
      expect(g.foldNormal, _near(const Offset(-1, 0)));
      final seg = g.foldSegment!;
      expect(seg.$1.dx, closeTo(250, 1e-9));
      expect(seg.$2.dx, closeTo(250, 1e-9));
      expect({seg.$1.dy, seg.$2.dy}, {0.0, 400.0});
    });

    test('flat part is the spine side, revealed part is the lifted side', () {
      expect(CurlGeometry.boundsOf(g.flatPolygon), const Rect.fromLTRB(0, 0, 250, 400));
      expect(CurlGeometry.boundsOf(g.revealedPolygon), const Rect.fromLTRB(250, 0, 300, 400));
      expect(CurlGeometry.polygonArea(g.flatPolygon) + CurlGeometry.polygonArea(g.revealedPolygon), closeTo(300 * 400, 1e-6));
    });

    test('back face is the lifted part mirrored over the fold', () {
      expect(CurlGeometry.boundsOf(g.backPolygon), const Rect.fromLTRB(200, 0, 250, 400));
      expect(g.reflect(g.grab), _near(g.touch));
    });

    test('back transform maps the grab point onto the finger and keeps the fold fixed', () {
      final m = g.backTransform();
      expect(_apply(m, g.grab), _near(g.touch));
      expect(_apply(m, const Offset(250, 77)), _near(const Offset(250, 77)));
      // A mirror: orientation flips.
      expect(m.determinant(), closeTo(-1, 1e-9));
    });

    test('shadow rects: a band along the fold on the revealed side; one beyond the folded edge', () {
      final e = g.shadowExtent; // 7% of the leaf width
      expect(e, closeTo(21, 1e-9));
      expect(g.revealedShadowRect, Rect.fromLTRB(250, 0, 250 + e, 400));
      expect(g.edgeShadowDirection, _near(const Offset(-1, 0)));
      expect(g.edgeShadowRect, Rect.fromLTRB(200 - e, 0, 200, 400));
    });
  });

  group('edge grab, spine on the right (Arabic book)', () {
    final g = CurlGeometry(leaf: _leaf, spine: SpineSide.right, grab: const Offset(0, 200), touch: const Offset(100, 200));

    test('mirror image of the English case', () {
      expect(g.foldPoint, _near(const Offset(50, 200)));
      expect(g.foldNormal, _near(const Offset(1, 0)));
      expect(CurlGeometry.boundsOf(g.flatPolygon), const Rect.fromLTRB(50, 0, 300, 400));
      expect(CurlGeometry.boundsOf(g.revealedPolygon), const Rect.fromLTRB(0, 0, 50, 400));
      expect(CurlGeometry.boundsOf(g.backPolygon), const Rect.fromLTRB(50, 0, 100, 400));
      expect(_apply(g.backTransform(), g.grab), _near(g.touch));
      expect(g.edgeShadowDirection, _near(const Offset(1, 0)));
      expect(g.edgeShadowRect, Rect.fromLTRB(100, 0, 100 + g.shadowExtent, 400));
    });
  });

  group('corner grab', () {
    final g = CurlGeometry(leaf: _leaf, spine: SpineSide.left, grab: const Offset(300, 400), touch: const Offset(200, 300));

    test('diagonal fold cuts a triangle off the corner', () {
      final inv = 1 / 1.4142135623730951;
      expect(g.foldNormal, _near(Offset(-inv, -inv)));
      expect(g.foldPoint, _near(const Offset(250, 350)));
      final seg = g.foldSegment!;
      final pts = [seg.$1, seg.$2]..sort((a, b) => a.dx.compareTo(b.dx));
      expect(pts[0], _near(const Offset(200, 400)));
      expect(pts[1], _near(const Offset(300, 300)));
      expect(CurlGeometry.polygonArea(g.revealedPolygon), closeTo(5000, 1e-6));
      expect(CurlGeometry.polygonArea(g.flatPolygon), closeTo(300 * 400 - 5000, 1e-6));
    });

    test('back face is the same triangle folded over, its tip on the finger', () {
      expect(CurlGeometry.polygonArea(g.backPolygon), closeTo(5000, 1e-6));
      expect(g.backPolygon.any((p) => (p - g.touch).distance < 1e-6), isTrue);
      expect(_apply(g.backTransform(), g.grab), _near(g.touch));
    });
  });

  group('limits and states', () {
    test('flat while the touch has not moved', () {
      final g = CurlGeometry(leaf: _leaf, spine: SpineSide.left, grab: const Offset(300, 200), touch: const Offset(300, 200));
      expect(g.isFlat, isTrue);
      expect(g.revealedPolygon, isEmpty);
      expect(g.backPolygon, isEmpty);
      expect(g.foldSegment, isNull);
      expect(CurlGeometry.polygonArea(g.flatPolygon), 300 * 400);
    });

    test('the leaf never stretches: touch stays within reach of both spine corners', () {
      for (final spine in SpineSide.values) {
        final sx = spine == SpineSide.left ? 0.0 : 300.0;
        final grab = spine == SpineSide.left ? const Offset(300, 380) : const Offset(0, 380);
        for (final raw in const [Offset(-900, 100), Offset(1200, -300), Offset(150, 900), Offset(-50, 380)]) {
          final g = CurlGeometry(leaf: _leaf, spine: spine, grab: grab, touch: raw);
          for (final s in [Offset(sx, 0), Offset(sx, 400)]) {
            expect((g.touch - s).distance, lessThanOrEqualTo((grab - s).distance + 1e-6));
          }
        }
      }
    });

    test('fully turned: nothing flat is left and the back covers the leaf mirrored over the spine', () {
      const grab = Offset(300, 200);
      final rest = restTouch(_leaf, SpineSide.left, grab);
      expect(rest, const Offset(-300, 200));
      final g = CurlGeometry(leaf: _leaf, spine: SpineSide.left, grab: grab, touch: rest, backBounds: const Rect.fromLTWH(-300, 0, 600, 400));
      expect(g.isFullyTurned, isTrue);
      expect(CurlGeometry.boundsOf(g.backPolygon).left, closeTo(-300, 1e-6));
      expect(CurlGeometry.boundsOf(g.backPolygon).right, closeTo(0, 1e-6));
    });

    test('progress runs 0..1 along the path to the rest position', () {
      const grab = Offset(300, 200);
      expect(turnProgress(_leaf, SpineSide.left, grab, grab), 0);
      expect(turnProgress(_leaf, SpineSide.left, grab, const Offset(0, 200)), closeTo(0.5, 1e-9));
      expect(turnProgress(_leaf, SpineSide.left, grab, const Offset(-300, 200)), 1);
      expect(turnProgress(_leaf, SpineSide.right, const Offset(0, 200), const Offset(300, 200)), closeTo(0.5, 1e-9));
    });
  });

  group('facing pages: the back is the real page, upright', () {
    // Right half turned; spine at the centre (x = 150).
    const right = Rect.fromLTWH(150, 0, 150, 400);
    const bounds = Rect.fromLTWH(0, 0, 300, 400);

    test('content of the facing half goes mirrored over the spine, then over the fold', () {
      final g = CurlGeometry(leaf: right, spine: SpineSide.left, grab: const Offset(300, 200), touch: const Offset(200, 200), backBounds: bounds);
      final m = g.backTransform(throughSpine: true);
      // (100,50) -> spine mirror -> (200,50) -> fold at x=250 -> (300,50).
      expect(_apply(m, const Offset(100, 50)), _near(const Offset(300, 50)));
      // Upright, not mirrored: orientation preserved.
      expect(m.determinant(), closeTo(1, 1e-9));
      // The float buffer version used by the painter agrees.
      final buf = Float64List(16);
      g.writeBackTransform(buf, throughSpine: true);
      expect(Matrix4.fromFloat64List(buf).storage, m.storage);
    });

    test('Arabic spread: leaf is the left half, same maths mirrored', () {
      const left = Rect.fromLTWH(0, 0, 150, 400);
      final g = CurlGeometry(leaf: left, spine: SpineSide.right, grab: const Offset(0, 200), touch: const Offset(100, 200), backBounds: bounds);
      final m = g.backTransform(throughSpine: true);
      // (200,50) -> spine mirror over x=150 -> (100,50) -> fold at x=50 -> (0,50).
      expect(_apply(m, const Offset(200, 50)), _near(const Offset(0, 50)));
    });

    test('back polygon may cross the spine into the facing half', () {
      final g = CurlGeometry(leaf: right, spine: SpineSide.left, grab: const Offset(300, 200), touch: const Offset(100, 200), backBounds: bounds);
      final b = CurlGeometry.boundsOf(g.backPolygon);
      expect(b.left, closeTo(100, 1e-6));
      expect(b.left, lessThan(right.left));
    });
  });

  group('clipHalfPlane', () {
    test('keeps the requested side', () {
      final square = CurlGeometry.rectPolygon(const Rect.fromLTWH(0, 0, 10, 10));
      final left = CurlGeometry.clipHalfPlane(square, const Offset(4, 0), const Offset(1, 0), keepPositive: false);
      expect(CurlGeometry.boundsOf(left), const Rect.fromLTRB(0, 0, 4, 10));
      final none = CurlGeometry.clipHalfPlane(square, const Offset(40, 0), const Offset(1, 0), keepPositive: true);
      expect(none, isEmpty);
    });
  });
}
