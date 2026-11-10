import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/orbit/render/planets/planets.dart';

void main() {
  const viewport = Size(400, 800);
  const label = Size(60, 20);
  const c = Offset(200, 300);

  bool clearOfDisc(Rect r, Offset center, double radius) => !LabelPlacer.rectHitsDisc(r, center, radius);

  test('prefers the spot centred below the world', () {
    final r = LabelPlacer.place(
      center: c,
      clearance: 30,
      size: label,
      direction: TextDirection.rtl,
      viewport: viewport,
    )!;
    expect(r.center.dx, 200);
    expect(r.top, greaterThan(c.dy + 30));
    expect(clearOfDisc(r, c, 30), isTrue);
  });

  test('goes above when another world sits below', () {
    final r = LabelPlacer.place(
      center: c,
      clearance: 30,
      size: label,
      direction: TextDirection.rtl,
      viewport: viewport,
      obstacles: [(center: c + const Offset(0, 50), radius: 20)],
    )!;
    expect(r.bottom, lessThan(c.dy - 30));
  });

  test('then beside it, on the reading-end side first (RTL: left, LTR: right)', () {
    final blocked = <LabelObstacle>[
      (center: c + const Offset(0, 50), radius: 20),
      (center: c - const Offset(0, 50), radius: 20),
    ];
    final rtl = LabelPlacer.place(
      center: c,
      clearance: 30,
      size: label,
      direction: TextDirection.rtl,
      viewport: viewport,
      obstacles: blocked,
    )!;
    expect(rtl.right, lessThan(c.dx - 30));
    final ltr = LabelPlacer.place(
      center: c,
      clearance: 30,
      size: label,
      direction: TextDirection.ltr,
      viewport: viewport,
      obstacles: blocked,
    )!;
    expect(ltr.left, greaterThan(c.dx + 30));
    expect(clearOfDisc(rtl, c, 30) && clearOfDisc(ltr, c, 30), isTrue);
  });

  test('the own disc is skipped with ignore; other labels are avoided', () {
    final own = (center: c, radius: 30.0);
    final r = LabelPlacer.place(
      center: c,
      clearance: 30,
      size: label,
      direction: TextDirection.rtl,
      viewport: viewport,
      obstacles: [own],
      ignore: c,
    );
    expect(r, isNotNull);
    final taken = [Rect.fromLTWH(170, 330, 60, 20)];
    final r2 = LabelPlacer.place(
      center: c,
      clearance: 30,
      size: label,
      direction: TextDirection.rtl,
      viewport: viewport,
      taken: taken,
    )!;
    expect(r2.overlaps(taken.single), isFalse);
  });

  test('slides sideways to stay on screen near an edge', () {
    final r = LabelPlacer.place(
      center: const Offset(10, 300),
      clearance: 8,
      size: label,
      direction: TextDirection.rtl,
      viewport: viewport,
    )!;
    expect(r.left, greaterThanOrEqualTo(4 - 0.01));
    expect(clearOfDisc(r, const Offset(10, 300), 8), isTrue);
  });

  test('no room anywhere → null (the label fades out)', () {
    final r = LabelPlacer.place(
      center: c,
      clearance: 30,
      size: label,
      direction: TextDirection.ltr,
      viewport: viewport,
      obstacles: [(center: c, radius: 200)],
    );
    expect(r, isNull);
    expect(
      LabelPlacer.place(
        center: c,
        clearance: 3,
        size: const Size(500, 20),
        direction: TextDirection.ltr,
        viewport: viewport,
      ),
      isNull,
    );
  });

  test('never overlaps the world across sizes and positions', () {
    for (var x = 20.0; x < 400; x += 45) {
      for (var y = 20.0; y < 800; y += 90) {
        for (final radius in [4.0, 20.0, 60.0]) {
          final center = Offset(x, y);
          final r = LabelPlacer.place(
            center: center,
            clearance: radius,
            size: label,
            direction: TextDirection.rtl,
            viewport: viewport,
          );
          if (r == null) continue;
          expect(clearOfDisc(r, center, radius), isTrue, reason: '$center r$radius');
          expect(
            Offset.zero & viewport,
            predicate<Rect>((v) => v.inflate(0.1).contains(r.topLeft) && v.inflate(0.1).contains(r.bottomRight)),
          );
        }
      }
    }
  });

  test('the ellipsis width grows with the world in coarse steps', () {
    final a = LabelPlacer.maxWidthFor(30, viewport);
    final b = LabelPlacer.maxWidthFor(31, viewport);
    expect(a, 120);
    expect(LabelPlacer.maxWidthFor(10, viewport), 96, reason: 'small worlds still fit a short name');
    expect(b, a, reason: 'no re-layout for a small zoom');
    expect(LabelPlacer.maxWidthFor(40, viewport) % 24, 0);
    expect(LabelPlacer.maxWidthFor(400, viewport), lessThanOrEqualTo(viewport.width * 0.42));
  });

  group('placeBest', () {
    LabelSpot best({
      Offset center = c,
      Iterable<LabelObstacle> obstacles = const [],
      Iterable<Rect> taken = const [],
      Iterable<Rect> keepOut = const [],
      Rect? area,
      int? previousSlot,
      bool leaders = true,
    }) => LabelPlacer.placeBest(
      center: center,
      clearance: 30,
      size: label,
      direction: TextDirection.rtl,
      viewport: viewport,
      obstacles: obstacles,
      taken: taken,
      keepOut: keepOut,
      area: area,
      previousSlot: previousSlot,
      leaders: leaders,
    );

    test('matches place() when the inner ring has room', () {
      final spot = best();
      expect(
        spot.rect,
        LabelPlacer.place(center: c, clearance: 30, size: label, direction: TextDirection.rtl, viewport: viewport),
      );
      expect((spot.slot, spot.leader, spot.clean), (0, false, true));
    });

    test('keeps a still-clean inner slot (no hopping as the camera drifts)', () {
      final spot = best(previousSlot: 1);
      expect(spot.slot, 1, reason: 'above stays above although below is free');
      expect(spot.rect.bottom, lessThan(c.dy - 30));
    });

    test('goes out on a leader line when the whole inner ring is blocked', () {
      // A ring of keep-outs hugging the world blocks every inner slot.
      final keepOut = [Rect.fromCircle(center: c, radius: 30 + 5 + 40)];
      final spot = best(
        keepOut: [
          for (final r in keepOut) ...[
            Rect.fromLTRB(r.left, r.top, r.right, c.dy - 30),
            Rect.fromLTRB(r.left, c.dy + 30, r.right, r.bottom),
            Rect.fromLTRB(r.left, r.top, c.dx - 30, r.bottom),
            Rect.fromLTRB(c.dx + 30, r.top, r.right, r.bottom),
          ],
        ],
      );
      expect(spot.leader, isTrue);
      expect(spot.clean, isTrue);
      expect(spot.slot, greaterThanOrEqualTo(LabelPlacer.leaderSlot));
      expect(clearOfDisc(spot.rect, c, 30), isTrue);
      final (from, to) = LabelPlacer.leaderLine(spot.rect, c, 30);
      expect((to - c).distance, closeTo(30, 1e-6), reason: 'the line ends on the rim');
      expect(spot.rect.inflate(0.01).contains(from), isTrue, reason: 'and starts on the label');
    });

    test('a leader label comes back in as soon as an inner spot frees up', () {
      final spot = best(previousSlot: LabelPlacer.leaderSlot + 2);
      expect(spot.leader, isFalse);
      expect(spot.slot, 0);
    });

    test('without leaders it stays on the inner ring', () {
      final spot = best(obstacles: [(center: c, radius: 200)], leaders: false);
      expect(spot.slot, lessThan(LabelPlacer.slotsPerRing));
      expect(spot.clean, isFalse);
    });

    test('never null: the least-bad spot when nothing is clean', () {
      final spot = best(obstacles: [(center: c, radius: 400)]);
      expect(spot.clean, isFalse);
      expect(spot.rect.size, label);
    });

    test('respects keep-out rects and the label area', () {
      final below = best().rect;
      final spot = best(keepOut: [below.inflate(1)]);
      expect(spot.rect.overlaps(below.inflate(1)), isFalse);
      final area = Rect.fromLTRB(0, 0, 400, c.dy + 30);
      final inArea = best(area: area);
      expect(inArea.clean, isTrue);
      expect(inArea.rect.bottom, lessThanOrEqualTo(area.bottom + 0.01), reason: 'the panel below is out of bounds');
    });

    test('other labels are never overlapped while a clean spot exists', () {
      final taken = <Rect>[];
      for (var i = 0; i < 6; i++) {
        final spot = best(taken: taken);
        expect(spot.clean, isTrue);
        for (final t in taken) {
          expect(spot.rect.overlaps(t), isFalse);
        }
        taken.add(spot.rect);
      }
    });
  });
}
