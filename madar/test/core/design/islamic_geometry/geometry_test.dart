import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/islamic_geometry/hankin.dart';
import 'package:madar/core/design/islamic_geometry/pattern_geometry.dart';
import 'package:madar/core/design/islamic_geometry/pattern_spec.dart';
import 'package:madar/core/design/islamic_geometry/vec2.dart';

PatternGeometry buildFor(PatternFamily f, [double? angle]) =>
    PatternGeometry.build(PatternSpec(family: f, contactAngle: angle));

String key(Vec2 p) => '${(p.x * 1e6).round()},${(p.y * 1e6).round()}';

void main() {
  group('every family', () {
    for (final family in PatternFamily.values) {
      group(family.name, () {
        final g = buildFor(family);

        test('lines are finite, closed outlines with a pair of points per tile edge', () {
          expect(g.lines, hasLength(g.tiles.length));
          for (final line in g.lines) {
            expect(line.closed, isTrue);
            expect(line.points.length, g.tiles[line.tile].length * 2);
            for (final p in line.points) {
              expect(p.isFinite, isTrue);
            }
          }
        });

        test('medallion has the promised rotational symmetry, read back from the data', () {
          expect(g.symmetryOrder, family.medallionSymmetry);
          expect(g.measuredSymmetryOrder(), family.medallionSymmetry);
          expect(g.medallionBoundary, hasLength(family.medallionSymmetry));
          expect(g.medallionLines, isNotEmpty);
        });

        test('all points lie inside the cell bounds, which stay near one cell', () {
          for (final l in g.lines) {
            for (final p in l.points) {
              expect(p.x, inInclusiveRange(g.minX, g.maxX));
              expect(p.y, inInclusiveRange(g.minY, g.maxY));
            }
          }
          expect(g.translation1.length, closeTo(1, 1e-12));
          expect(g.width, lessThan(2.0));
          expect(g.height, lessThan(2.0));
          expect(g.width, greaterThan(0.3));
        });

        test('tiles exactly fill the lattice cell (no gap, no overlap)', () {
          final area = g.tiles.fold<double>(0, (s, t) => s + signedArea(t));
          expect(area, closeTo(g.cellArea, 1e-9));
          for (final t in g.tiles) {
            expect(signedArea(t), greaterThan(0), reason: 'tiles are counter-clockwise');
          }
        });

        test('decoration stays inside its own tile', () {
          for (final angle in [PatternFamily.minContactAngle, family.defaultContactAngle, family.maxContactAngle]) {
            final h = buildFor(family, angle);
            for (final l in h.lines) {
              final tile = h.tiles[l.tile];
              for (var i = 1; i < l.points.length; i += 2) {
                expect(pointInPolygon(l.points[i], tile), isTrue, reason: '${family.name} @ $angle tile ${l.tile} point $i');
              }
            }
          }
        });

        test('translated copies join seamlessly: lines continue straight through every shared edge', () {
          // Every tile instance in a 5x5 patch of lattice translations.
          final byMid = <String, List<({Vec2 prev, Vec2 next, Vec2 mid})>>{};
          for (var i = -2; i <= 2; i++) {
            for (var j = -2; j <= 2; j++) {
              final shift = g.translation1 * i.toDouble() + g.translation2 * j.toDouble();
              for (final l in g.lines) {
                final pts = [for (final p in l.points) p + shift];
                for (var e = 0; e < pts.length; e += 2) {
                  byMid.putIfAbsent(key(pts[e]), () => []).add((
                    prev: pts[(e - 1 + pts.length) % pts.length],
                    next: pts[e + 1],
                    mid: pts[e],
                  ));
                }
              }
            }
          }
          for (final line in g.lines) {
            for (var e = 0; e < line.points.length; e += 2) {
              final entries = byMid[key(line.points[e])]!;
              expect(entries, hasLength(2), reason: 'each edge midpoint is shared by exactly two tiles');
              final a = entries[0], b = entries[1];
              Vec2 dir(Vec2 from, Vec2 to) => (to - from).normalized();
              final n = dir(a.mid, a.next) + dir(b.mid, b.next);
              final p = dir(a.mid, a.prev) + dir(b.mid, b.prev);
              expect(n.length, lessThan(1e-6), reason: 'forward rays are opposite');
              expect(p.length, lessThan(1e-6), reason: 'backward rays are opposite');
            }
          }
        });

        test('deterministic: two builds are identical, point for point', () {
          final a = buildFor(family), b = buildFor(family);
          expect(a.lines.length, b.lines.length);
          for (var i = 0; i < a.lines.length; i++) {
            expect(a.lines[i].points, b.lines[i].points);
          }
          expect(a.contactAngle, b.contactAngle);
        });

        test('degenerate angles are clamped: never NaN, never infinite, never throws', () {
          final angles = <double?>[
            null,
            0,
            -1,
            -1e9,
            3.3,
            math.pi,
            1e12,
            double.nan,
            double.infinity,
            double.negativeInfinity,
            double.minPositive,
          ];
          for (final a in angles) {
            final h = buildFor(family, a);
            expect(h.contactAngle, inInclusiveRange(PatternFamily.minContactAngle, family.maxContactAngle));
            for (final l in h.lines) {
              for (final p in l.points) {
                expect(p.isFinite, isTrue, reason: 'angle $a');
              }
            }
          }
        });

        test('the angle changes the drawing', () {
          final lo = buildFor(family, 0.3), hi = buildFor(family, 0.5);
          expect(lo.lines.first.points, isNot(equals(hi.lines.first.points)));
        });
      });
    }
  });

  test('cached() returns one instance per spec and counts one build', () {
    PatternGeometry.debugClearCache();
    final before = PatternGeometry.debugBuildCount;
    const spec = PatternSpec(family: PatternFamily.girih10, contactAngle: 0.4);
    final a = PatternGeometry.cached(spec);
    final b = PatternGeometry.cached(const PatternSpec(family: PatternFamily.girih10, contactAngle: 0.4, repeat: 6));
    expect(identical(a, b), isTrue);
    expect(PatternGeometry.debugBuildCount, before + 1);
  });

  test('specs with NaN / out-of-range values are equal to their resolved form', () {
    const a = PatternSpec(family: PatternFamily.hex6, contactAngle: double.nan, lineWidth: double.nan, repeat: 0);
    const b = PatternSpec(family: PatternFamily.hex6);
    expect(a.resolvedRepeat, 1);
    expect(a.resolvedLineWidth, 1.2);
    expect(a.resolvedContactAngle, PatternFamily.hex6.defaultContactAngle);
    expect(a.resolvedRepeat, isNot(b.resolvedRepeat));
    expect(const PatternSpec(family: PatternFamily.hex6, repeat: 500).resolvedRepeat, 40);
  });
}
