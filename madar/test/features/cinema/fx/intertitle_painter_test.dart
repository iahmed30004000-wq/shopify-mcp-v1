import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/fx/fx.dart';

void main() {
  setUpAll(() async {
    await CinemaShaders.preload();
  });

  const bounds = Rect.fromLTWH(0, 0, 412, 915);

  test('every era frame paints every card kind, bilingual and not, both directions', () {
    for (final era in Era.values) {
      for (final dir in TextDirection.values) {
        final painter = IntertitlePainter(skin: EraSkins.of(era), direction: dir);
        final clock = FilmClock();
        for (final kind in IntertitleKind.values) {
          for (final sub in [null, 'The End']) {
            clock.advance(1 / 60);
            final card = IntertitleCard(text: 'النهاية', subtitle: sub, kind: kind);
            final recorder = ui.PictureRecorder();
            final canvas = ui.Canvas(recorder);
            for (final appear in [0.0, 0.4, 1.0]) {
              painter.paint(canvas, bounds, card, clock, appear: appear, opacity: appear);
            }
            recorder.endRecording().dispose();
            final panel = painter.panelRect(bounds, card);
            expect(bounds.contains(panel.topLeft) && bounds.contains(panel.bottomRight), isTrue, reason: '${era.name} $kind');
          }
        }
        painter.dispose();
      }
    }
  });

  test('long titles wrap inside the panel', () {
    final painter = IntertitlePainter(skin: EraSkins.of(Era.silent));
    const card = IntertitleCard(
      text: 'في مدينة الآلات العملاقة، حيث لا تنام المصانع، يبدأ العرض الكبير',
      subtitle: 'In the city of giant machines, where the factories never sleep, the big show begins',
      kind: IntertitleKind.dialogue,
    );
    final panel = painter.panelRect(bounds, card);
    expect(panel.width, lessThan(bounds.width));
    expect(panel.height, greaterThan(bounds.width * 0.9));
    painter.dispose();
  });
}
