import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/painters/painters.dart';

void main() {
  group('IslamicGeometry', () {
    test('star polygon inner ratios match the classical constructions', () {
      expect(IslamicGeometry.starPolygonInnerRatio(8, 3), closeTo(0.5412, 1e-4));
      expect(IslamicGeometry.starPolygonInnerRatio(8, 2), closeTo(0.7654, 1e-4));
      expect(IslamicGeometry.starPolygonInnerRatio(5, 2), closeTo(0.3820, 1e-4));
      expect(IslamicGeometry.starPolygonInnerRatio(6, 2), closeTo(0.5774, 1e-4));
    });

    test('default inner ratio is a sharp star for every point count', () {
      for (var n = 3; n <= 16; n++) {
        final r = IslamicGeometry.defaultInnerRatio(n);
        expect(r, inExclusiveRange(0, 1), reason: '$n points');
      }
      expect(IslamicGeometry.defaultInnerRatio(8), closeTo(0.5412, 1e-4));
    });

    test('star vertices alternate outer and inner radius, first tip up', () {
      const c = Offset(50, 50);
      final v = IslamicGeometry.starVertices(center: c, radius: 40, points: 8, innerRatio: 0.5);
      expect(v, hasLength(16));
      for (var i = 0; i < v.length; i++) {
        expect((v[i] - c).distance, closeTo(i.isEven ? 40 : 20, 1e-9));
      }
      expect(v.first.dx, closeTo(50, 1e-9));
      expect(v.first.dy, closeTo(10, 1e-9));
    });

    test('rotation turns the star clockwise', () {
      final v = IslamicGeometry.starVertices(center: Offset.zero, radius: 1, points: 4, rotation: math.pi / 2);
      expect(v.first.dx, closeTo(1, 1e-9));
      expect(v.first.dy, closeTo(0, 1e-9));
    });

    test('Rub el Hizb is two squares, the second turned 45°', () {
      final squares = IslamicGeometry.rubElHizbSquares(center: Offset.zero, radius: 10);
      expect(squares, hasLength(2));
      expect(squares[0], hasLength(4));
      final a0 = math.atan2(squares[0][0].dy, squares[0][0].dx);
      final a1 = math.atan2(squares[1][0].dy, squares[1][0].dx);
      expect(a1 - a0, closeTo(math.pi / 4, 1e-9));
      final outline = IslamicGeometry.rubElHizbOutline(center: Offset.zero, radius: 10);
      expect(outline.getBounds().width, closeTo(20, 0.01));
    });
  });

  group('GirihRosetteGeometry', () {
    test('8-fold rosette: two squares plus one {8/3} star', () {
      final g = GirihRosetteGeometry.of(8);
      expect(g.strands, hasLength(3));
      expect(g.strands[0], hasLength(4));
      expect(g.strands[1], hasLength(4));
      expect(g.strands[2], hasLength(8));
      expect(identical(g, GirihRosetteGeometry.of(8)), isTrue, reason: 'memoised');
    });

    for (final n in [6, 8, 10, 12]) {
      test('$n-fold crossings are symmetric and well formed', () {
        final g = GirihRosetteGeometry.of(n);
        expect(g.crossings, isNotEmpty);
        expect(g.crossings.length % n, 0, reason: 'n-fold symmetry');
        for (final x in g.crossings) {
          expect(x.overDirection.distance, closeTo(1, 1e-9));
          expect(x.point.distance, lessThan(GirihRosetteGeometry.outerRadius + 1e-9));
          expect(x.overStrand, inInclusiveRange(0, g.strands.length - 1));
          expect(x.underStrand, inInclusiveRange(0, g.strands.length - 1));
        }
      });
    }

    test('weave alternates: both over and under occur on each strand', () {
      final g = GirihRosetteGeometry.of(8);
      for (var s = 0; s < g.strands.length; s++) {
        final over = g.crossings.where((x) => x.overStrand == s).length;
        final under = g.crossings.where((x) => x.underStrand == s).length;
        expect(over, greaterThan(0), reason: 'strand $s never passes over');
        expect(under, greaterThan(0), reason: 'strand $s never passes under');
      }
    });
  });

  group('AstrolabeScale', () {
    test('tick layout nests major / mid / minor', () {
      final ticks = AstrolabeScale.ticks();
      expect(ticks, hasLength(180));
      expect(ticks.where((t) => t.kind == AstrolabeTickKind.major), hasLength(12));
      expect(ticks.where((t) => t.kind == AstrolabeTickKind.mid), hasLength(24));
      expect(ticks.first, const AstrolabeTick(0, AstrolabeTickKind.major));
      expect(ticks[5], const AstrolabeTick(10, AstrolabeTickKind.mid));
      expect(ticks[1], const AstrolabeTick(2, AstrolabeTickKind.minor));
    });

    test('custom steps', () {
      final ticks = AstrolabeScale.ticks(minorStep: 5, midStep: 15, majorStep: 45);
      expect(ticks, hasLength(72));
      expect(ticks.where((t) => t.kind == AstrolabeTickKind.major), hasLength(8));
    });

    test('Arabic-Indic numerals', () {
      expect(AstrolabeScale.toArabicIndic('0123456789'), '٠١٢٣٤٥٦٧٨٩');
      expect(AstrolabeScale.numeral(330), '٣٣٠');
      expect(AstrolabeScale.numeral(330, arabicIndic: false), '330');
      expect(AstrolabeScale.toArabicIndic('+12% of 3.5'), '+١٢% of ٣.٥');
      expect(AstrolabeScale.toArabicIndic('8,420 · 3.5 · 12%', separators: true), '٨٬٤٢٠ · ٣٫٥ · ١٢٪');
    });

    test('0° points up and angles run clockwise', () {
      expect(AstrolabeScale.radiansFor(0), closeTo(-math.pi / 2, 1e-12));
      expect(AstrolabeScale.radiansFor(90), closeTo(0, 1e-12));
      expect(AstrolabeScale.radiansFor(90, rotation: 0.5), closeTo(0.5, 1e-12));
    });
  });

  group('ArabesqueLayout', () {
    test('tile count is even, at least two and fits exactly', () {
      for (final w in [40.0, 120.0, 333.0, 412.0, 1000.0]) {
        final n = ArabesqueLayout.tileCount(w, 24);
        expect(n, greaterThanOrEqualTo(2));
        expect(n.isEven, isTrue);
        expect(ArabesqueLayout.tileWidth(w, 24) * n, closeTo(w, 1e-9));
      }
    });

    test('degenerate sizes produce no tiles', () {
      expect(ArabesqueLayout.tileCount(0, 24), 0);
      expect(ArabesqueLayout.tileCount(100, 0), 0);
      expect(ArabesqueLayout.tileWidth(0, 24), 0);
    });
  });
}
