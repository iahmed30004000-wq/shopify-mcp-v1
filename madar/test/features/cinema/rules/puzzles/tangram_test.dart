import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/puzzles/puzzles.dart';

import 'support.dart';

/// Stored coordinate for `a + b√2` tan units (a, b in quarters of a unit).
SPoint p(int ax, int bx, int ay, int by) => SPoint(Surd(ax, bx), Surd(ay, by));

void main() {
  group('exact arithmetic', () {
    test('Z[√2] signs match floating point', () {
      final rng = SeededRng(1);
      for (var i = 0; i < 5000; i++) {
        final s = Surd(rng.nextRange(-60, 60), rng.nextRange(-60, 60));
        final d = s.toDouble();
        expect(s.sign, d.abs() < 1e-9 ? 0 : (d > 0 ? 1 : -1), reason: '$s');
      }
      expect((const Surd(0, 1) * const Surd(0, 1)), const Surd(2));
    });

    test('rotations compose and every orientation keeps area and orientation', () {
      final q = p(4, 0, 8, 0);
      var r = q;
      for (var i = 0; i < 8; i++) {
        r = r.rotate(1);
      }
      expect(r, q);
      expect(q.rotate(2), q.rotate(1).rotate(1));
      for (final piece in TanPiece.values) {
        for (var k = 0; k < 8; k++) {
          for (final f in [false, true]) {
            final pl = TanPlacement(piece: piece, rotation: k, flipped: f, offset: p(8, 4, -4, 2));
            expect(area2(pl.outline), Surd(shapeArea2(piece.shape)), reason: '$pl');
          }
        }
      }
      final total = TanPiece.values.fold(0, (a, t) => a + shapeArea2(t.shape));
      expect(total, kTangramArea2);
    });

    test('overlap areas', () {
      final a = TanPlacement(piece: TanPiece.square, offset: SPoint.ints(0, 0));
      expect(overlapArea2(a.outline, a.outline), const Surd(32));
      final touching = a.copyWith(offset: SPoint.ints(4, 0));
      expect(overlapArea2(a.outline, touching.outline).sign, 0);
      final half = a.copyWith(offset: SPoint.ints(2, 0));
      expect(overlapArea2(a.outline, half.outline), const Surd(16));
      final diamond = TanPlacement(piece: TanPiece.square, rotation: 1, offset: SPoint.ints(2, 0));
      final o = overlapArea2(a.outline, diamond.outline);
      expect(o.sign, 1);
      expect(o.toDouble(), closeTo(_numericOverlap(a, diamond), 1e-6));
    });

    test('the classic square (irrational coordinates) is an exact cover', () {
      // Big square [0, 2√2]²; see the derivation in PUZZLES_ARCADE.md.
      final centre = p(0, 4, 0, 4);
      final p1 = p(0, 6, 0, 2);
      final placements = [
        TanPlacement(piece: TanPiece.largeA, rotation: 5, offset: centre),
        TanPlacement(piece: TanPiece.largeB, rotation: 3, offset: centre),
        TanPlacement(piece: TanPiece.medium, rotation: 4, offset: p(0, 8, 0, 8)),
        TanPlacement(piece: TanPiece.smallA, rotation: 7, offset: p1),
        TanPlacement(piece: TanPiece.smallB, rotation: 1, offset: centre),
        TanPlacement(piece: TanPiece.square, rotation: 1, offset: p1),
        TanPlacement(piece: TanPiece.parallelogram, rotation: 7, offset: p(0, 0, 0, 8)),
      ];
      final square = [p(0, 0, 0, 0), p(0, 8, 0, 0), p(0, 8, 0, 8), p(0, 0, 0, 8)];
      for (var i = 0; i < 7; i++) {
        expect(overlapArea2(placements[i].outline, square), Surd(shapeArea2(placements[i].piece.shape)));
        for (var j = i + 1; j < 7; j++) {
          expect(TangramRules.overlaps(placements[i], placements[j]), isFalse, reason: '$i $j');
        }
      }
      expect(area2(square), const Surd(kTangramArea2));
      expect(TangramRules.coversExactly(placements, placements), isTrue);
    });
  });

  group('silhouette library', () {
    test('every figure has area 8, is connected and has an exact cover', () {
      final ids = <String>{};
      for (final s in TangramLibrary.all) {
        expect(ids.add(s.id), isTrue, reason: 'unique id ${s.id}');
        expect(s.area, 8, reason: s.id);
        expect(s.isConnected, isTrue, reason: s.id);
        final sol = s.solution;
        expect(sol, isNotNull, reason: '${s.id} must be tileable');
        expect(sol!.map((t) => t.piece).toSet().length, 7);
        expect(TangramRules.coversExactly(sol, sol), isTrue, reason: s.id);
        // Every reference tan stays inside the art's bounding box.
        for (final t in sol) {
          for (final v in t.outlineDoubles) {
            expect(v.$1 >= 0 && v.$1 <= s.width && v.$2 >= 0 && v.$2 <= s.height, isTrue);
          }
        }
      }
      for (final d in PuzzleDifficulty.values) {
        expect(TangramLibrary.forDifficulty(d), isNotEmpty);
      }
    });

    test('abstract figures are valid for many seeds', () {
      for (var seed = 0; seed < 40; seed++) {
        final s = TangramSilhouette.random(seed);
        expect(s.area, 8);
        expect(s.isConnected, isTrue);
        expect(s.solution, isNotNull);
      }
    });

    test('the tiler rejects impossible shapes', () {
      expect(TangramSilhouette('line', PuzzleDifficulty.easy, ['########']).solution, isNull);
      expect(TangramSilhouette('small', PuzzleDifficulty.easy, ['##']).solution, isNull);
    });
  });

  group('game', () {
    test('placing the reference solves; equivalent arrangements also win', () {
      for (final s in TangramLibrary.all) {
        final g = TangramGame(TangramConfig.library(s.id));
        for (final r in g.reference) {
          expect(g.isSolved, isFalse);
          expect(g.apply(TangramAction.place(r)), isTrue);
        }
        expect(g.isSolved, isTrue, reason: s.id);
      }
      // Swapping the two large triangles is the same figure.
      final g = TangramGame(const TangramConfig.library('house'));
      for (final r in g.reference) {
        final swapped = switch (r.piece) {
          TanPiece.largeA => TanPiece.largeB,
          TanPiece.largeB => TanPiece.largeA,
          TanPiece.smallA => TanPiece.smallB,
          TanPiece.smallB => TanPiece.smallA,
          final other => other,
        };
        g.apply(TangramAction.place(r.copyWith(piece: swapped)));
      }
      expect(g.isSolved, isTrue);
    });

    test('a shifted piece or an overlap does not win', () {
      final g = TangramGame(const TangramConfig.library('rectangle'));
      for (final r in g.reference) {
        g.apply(TangramAction.place(r));
      }
      final sq = g.state.placements[TanPiece.square.index]!;
      g.apply(TangramAction.place(sq.copyWith(offset: sq.offset + SPoint.ints(-2, 0))));
      expect(g.isSolved, isFalse);
      expect(g.overlapping(), isNotEmpty);
      g.undo();
      expect(g.isSolved, isTrue);
      g.apply(const TangramAction.remove(TanPiece.medium));
      expect(g.isSolved, isFalse);
      expect(g.apply(const TangramAction.remove(TanPiece.medium)), isFalse);
      final odd = TanPlacement(piece: TanPiece.medium, offset: SPoint.ints(1, 0));
      expect(g.apply(TangramAction.place(odd)), isFalse, reason: 'off the snapping lattice');
    });

    test('snapping lands exactly on the reference', () {
      final g = TangramGame(const TangramConfig.library('arrow'));
      final rng = SeededRng(5);
      for (final r in g.reference) {
        final (x, y) = r.offset.toDouble();
        final snapped = g.snap(
          r.piece,
          rotation: r.rotation,
          flipped: r.flipped,
          x: x + rng.nextDoubleRange(-0.08, 0.08),
          y: y + rng.nextDoubleRange(-0.08, 0.08),
        );
        expect(snapped.sameRegion(r), isTrue, reason: '$r → $snapped');
        g.apply(TangramAction.place(snapped));
      }
      expect(g.isSolved, isTrue);
      // Far from any vertex: half-unit grid.
      final free = snapPlacement(TanPiece.square, rotation: 0, x: 10.3, y: 10.6);
      expect(free.offset, SPoint.ints(42, 42));
    });

    test('hints solve every figure, even from a messy start', () {
      final configs = [
        for (final s in TangramLibrary.all) TangramConfig.library(s.id),
        const TangramConfig.abstract(3),
        const TangramConfig.abstract(8),
      ];
      for (final c in configs) {
        final g = TangramGame(c);
        g.apply(TangramAction.place(TanPlacement(piece: TanPiece.square, offset: SPoint.ints(40, 40))));
        followHints(g, maxSteps: 30);
        expect(g.isSolved, isTrue, reason: c.toJson().toString());
      }
    });

    test('random play never throws; replay and JSON', () {
      final g = TangramGame(TangramConfig.forDifficulty(PuzzleDifficulty.hard, 2));
      final rng = SeededRng(9);
      final log = <Map<String, Object?>>[];
      for (var i = 0; i < 300; i++) {
        final piece = rng.pick(TanPiece.values);
        final TangramAction a = rng.nextInt(6) == 0
            ? TangramAction.remove(piece)
            : TangramAction.place(
                TanPlacement(
                  piece: piece,
                  rotation: rng.nextInt(8),
                  flipped: rng.nextBool(),
                  offset: SPoint(Surd(rng.nextRange(-4, 12) * 2, rng.nextRange(-2, 2) * 2), Surd(rng.nextRange(-4, 12) * 2)),
                ),
              );
        if (g.apply(a)) log.add(roundTripJson(a.toJson()));
        g.isSolved;
      }
      expect(replay(TangramGame(TangramConfig.forDifficulty(PuzzleDifficulty.hard, 2)), log), replay(g, const []));
      expectJsonRoundTrip(g);
      expectJsonRoundTrip(TangramGame(const TangramConfig.abstract(5)));
    });
  });
}

/// Monte-Carlo-free numeric overlap by polygon clipping in doubles.
double _numericOverlap(TanPlacement a, TanPlacement b) {
  var poly = [for (final v in a.outline) (v.x.toDouble(), v.y.toDouble())];
  final clip = [for (final v in b.outline) (v.x.toDouble(), v.y.toDouble())];
  for (var i = 0; i < clip.length; i++) {
    final (ax, ay) = clip[i];
    final (bx, by) = clip[(i + 1) % clip.length];
    double side((double, double) q) => (bx - ax) * (q.$2 - ay) - (by - ay) * (q.$1 - ax);
    final input = poly;
    poly = [];
    for (var j = 0; j < input.length; j++) {
      final cur = input[j], prev = input[(j - 1 + input.length) % input.length];
      final sc = side(cur), sp = side(prev);
      (double, double) cut() {
        final t = sp / (sp - sc);
        return (prev.$1 + (cur.$1 - prev.$1) * t, prev.$2 + (cur.$2 - prev.$2) * t);
      }

      if (sc >= 0) {
        if (sp < 0) poly.add(cut());
        poly.add(cur);
      } else if (sp >= 0) {
        poly.add(cut());
      }
    }
  }
  var s = 0.0;
  for (var i = 0; i < poly.length; i++) {
    final (x1, y1) = poly[i];
    final (x2, y2) = poly[(i + 1) % poly.length];
    s += x1 * y2 - x2 * y1;
  }
  return math.max(0, s);
}
