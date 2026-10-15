import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/rig/rig_kit.dart';

// Budget checks for the rig: draw ops per drawing, drawings per second,
// steady-state path pools, and (printed) build / replay timings. Timings in
// `flutter test` are JIT + asserts – a release build on a phone is several
// times faster; the numbers are for comparing characters, not absolutes.
void main() {
  setUpAll(() async {
    await CinemaShaders.preload();
  });

  test('every cast member stays inside the draw budget', () {
    final report = StringBuffer('\nrig budget (per character, 2 s at 60 Hz, rubber-hose / vhs):\n');
    for (final era in [Era.rubberHose, Era.vhs]) {
      for (final m in RigCast.all) {
        final rig = m.build() as HoseRig;
        final clock = FilmClock(boilFps: EraSkins.of(era).ink.boilFps);
        final ctx = RigPaintContext(skin: EraSkins.of(era), clock: clock);
        rig
          ..speed = m.height * 1.8
          ..act(RigAction.run);
        final sw = Stopwatch();
        var maxOps = 0;
        var paints = 0;
        // Warm up (pools fill).
        for (var i = 0; i < 30; i++) {
          rig.update(1 / 60);
          clock.advance(1 / 60);
          final rec = PictureRecorder();
          rig.paint(Canvas(rec), ctx);
          rec.endRecording().dispose();
        }
        final pool = rig.ink.list.pathPool;
        final d0 = rig.drawings;
        for (var i = 0; i < 120; i++) {
          rig.update(1 / 60);
          clock.advance(1 / 60);
          final rec = PictureRecorder();
          final canvas = Canvas(rec);
          sw.start();
          rig.paint(canvas, ctx);
          sw.stop();
          paints++;
          rec.endRecording().dispose();
          if (rig.ink.list.opCount > maxOps) maxOps = rig.ink.list.opCount;
        }
        final drawings = rig.drawings - d0;
        // Build alone (a new drawing) vs replay alone (cached).
        final bw = Stopwatch()..start();
        for (var i = 0; i < 40; i++) {
          rig.build(ctx);
        }
        bw.stop();
        final rw = Stopwatch();
        for (var i = 0; i < 40; i++) {
          final rec = PictureRecorder();
          final canvas = Canvas(rec);
          rw.start();
          rig.ink.list.replay(canvas);
          rw.stop();
          rec.endRecording().dispose();
        }
        report.writeln(
          '  ${era.name.padRight(10)} ${m.id.padRight(9)} ops≤$maxOps  drawings/s=${(drawings / 2).toStringAsFixed(0)}'
          '  paint avg=${(sw.elapsedMicroseconds / paints).toStringAsFixed(0)}µs'
          '  build=${(bw.elapsedMicroseconds / 40).toStringAsFixed(0)}µs  replay=${(rw.elapsedMicroseconds / 40).toStringAsFixed(0)}µs'
          '  paths=${rig.ink.list.pathPool}',
        );
        expect(maxOps, lessThan(700), reason: '${m.id}: too many draw ops per drawing');
        expect(drawings, lessThanOrEqualTo(era == Era.vhs ? 121 : 52), reason: '${m.id}: drawings are cached');
        expect(rig.ink.list.pathPool, lessThanOrEqualTo(pool + 12), reason: '${m.id}: path pool is stable');
        rig.dispose();
      }
    }
    // ignore: avoid_print
    print(report);
  });
}
