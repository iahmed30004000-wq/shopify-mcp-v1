import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/orbit/presentation/scene/adaptive_quality.dart';
import 'package:madar/features/orbit/presentation/scene/gyro_parallax.dart';
import 'package:madar/features/orbit/presentation/scene/scene_governor.dart';

void main() {
  group('SceneGovernor', () {
    test('maps inputs to modes', () {
      const base = SceneInputs();
      expect(SceneGovernor.modeFor(base), SceneMode.idle);
      expect(SceneGovernor.modeFor(base.copyWith(visible: false)), SceneMode.paused);
      expect(SceneGovernor.modeFor(base.copyWith(visible: false, animating: true)), SceneMode.paused);
      expect(SceneGovernor.modeFor(base.copyWith(interacting: true)), SceneMode.live);
      expect(SceneGovernor.modeFor(base.copyWith(animating: true)), SceneMode.live);
      expect(SceneGovernor.modeFor(base.copyWith(batterySaver: true)), SceneMode.still);
      expect(SceneGovernor.modeFor(base.copyWith(batterySaver: true, interacting: true)), SceneMode.live);
      expect(SceneGovernor.modeFor(base.copyWith(reducedMotion: true)), SceneMode.frozen);
      expect(SceneGovernor.modeFor(base.copyWith(ambient: false)), SceneMode.frozen);
      expect(SceneGovernor.modeFor(base.copyWith(reducedMotion: true, animating: true)), SceneMode.live);
    });

    test('only live and idle run the ticker', () {
      final g = SceneGovernor();
      for (final (inputs, ticks) in [
        (const SceneInputs(), true),
        (const SceneInputs(interacting: true), true),
        (const SceneInputs(visible: false), false),
        (const SceneInputs(batterySaver: true), false),
        (const SceneInputs(reducedMotion: true), false),
      ]) {
        g.update(inputs);
        expect(g.wantsTicker, ticks, reason: '$inputs');
      }
    });

    test('behind an open planet page the scene steps at 10 fps (its blurs are redone a third as often)', () {
      const page = SceneInputs(pageOpen: true);
      expect(SceneGovernor.modeFor(page), SceneMode.backdrop);
      expect(SceneGovernor.modeFor(page.copyWith(interacting: true)), SceneMode.live);
      expect(SceneGovernor.modeFor(page.copyWith(animating: true)), SceneMode.live, reason: 'a fly-out');
      expect(SceneGovernor.modeFor(page.copyWith(batterySaver: true)), SceneMode.still);
      expect(SceneGovernor.modeFor(page.copyWith(visible: false)), SceneMode.paused);
      for (final hz in [60.0, 120.0]) {
        final g = SceneGovernor(inputs: page);
        expect(g.wantsTicker, isTrue);
        var rendered = 0;
        for (var i = 0; i < hz * 2; i++) {
          if (g.admit(1 / hz) != null) rendered++;
        }
        expect(rendered, inInclusiveRange(19, 21), reason: '$hz Hz');
      }
    });

    test('update reports mode changes', () {
      final g = SceneGovernor();
      expect(g.update(const SceneInputs()), isFalse);
      expect(g.update(const SceneInputs(interacting: true)), isTrue);
      expect(g.mode, SceneMode.live);
      expect(g.update(const SceneInputs(interacting: true, animating: true)), isFalse);
      expect(g.update(const SceneInputs(visible: false)), isTrue);
      expect(g.mode, SceneMode.paused);
    });

    test('live renders every vsync', () {
      final g = SceneGovernor(inputs: const SceneInputs(interacting: true));
      var rendered = 0;
      for (var i = 0; i < 120; i++) {
        if (g.admit(1 / 120) != null) rendered++;
      }
      expect(rendered, 120);
    });

    test('idle drops to 30 fps on 60 Hz and 120 Hz panels', () {
      for (final hz in [60.0, 90.0, 120.0]) {
        final g = SceneGovernor();
        var rendered = 0;
        var advanced = 0.0;
        for (var i = 0; i < hz * 2; i++) {
          final step = g.admit(1 / hz);
          if (step != null) {
            rendered++;
            advanced += step;
          }
        }
        expect(rendered, inInclusiveRange(58, 62), reason: '$hz Hz: $rendered frames in 2 s');
        // No time is lost: skipped vsyncs are folded into the next step.
        expect(advanced, closeTo(2, 1 / 30 + 1e-9), reason: '$hz Hz');
      }
    });

    test('idle at 60 Hz skips exactly every other frame, with jitter', () {
      final g = SceneGovernor();
      final pattern = [for (var i = 0; i < 8; i++) g.admit(i.isEven ? 0.0165 : 0.0168) != null];
      expect(pattern, [false, true, false, true, false, true, false, true]);
    });

    test('paused, still and frozen render nothing', () {
      for (final inputs in const [
        SceneInputs(visible: false),
        SceneInputs(batterySaver: true),
        SceneInputs(reducedMotion: true),
      ]) {
        final g = SceneGovernor(inputs: inputs);
        expect(g.admit(1 / 60), isNull, reason: '$inputs');
      }
    });

    test('a long hitch never advances more than maxStep', () {
      final g = SceneGovernor(inputs: const SceneInputs(interacting: true));
      expect(g.admit(2.5), SceneGovernor.maxStep);
      expect(g.admit(double.nan), isNull);
      expect(g.admit(-1), isNull);
    });

    test('SceneClock turns ticker time into steps', () {
      final c = SceneClock();
      expect(c.tick(const Duration(milliseconds: 100)), 0);
      expect(c.tick(const Duration(milliseconds: 116)), closeTo(0.016, 1e-9));
      c.restart();
      expect(c.tick(const Duration(seconds: 5)), 0);
      expect(c.frames, 1);
      c.advanced(0.5);
      expect(c.seconds, 0.5);
    });
  });

  group('AdaptiveQuality', () {
    test('steps down after sustained raster overruns and back up with hysteresis', () {
      final q = AdaptiveQuality(window: 10, downAfter: 2, upAfter: 3);
      expect(q.budgetMs, closeTo(16.67, 0.01));
      void feed(double ms, int windows) {
        for (var i = 0; i < 10 * windows; i++) {
          q.addFrame(rasterMs: ms);
        }
      }

      feed(12, 4);
      expect(q.quality, SceneQuality.high);
      feed(25, 1);
      expect(q.quality, SceneQuality.high, reason: 'one bad window is a hitch, not a trend');
      feed(25, 1);
      expect(q.quality, SceneQuality.balanced);
      expect(q.lensFlare, isFalse);
      expect(q.starNames, isFalse);
      expect(q.depthOfField, isTrue);
      feed(25, 2);
      expect(q.quality, SceneQuality.low);
      expect(q.depthOfField, isFalse);
      expect(q.zoomedLabels, isFalse);
      feed(25, 4);
      expect(q.quality, SceneQuality.low);
      feed(12, 6);
      expect(q.quality, SceneQuality.low, reason: 'in budget but not comfortably');
      feed(5, 3);
      expect(q.quality, SceneQuality.balanced);
      feed(5, 3);
      expect(q.quality, SceneQuality.high);
    });

    test('a 120 Hz panel that holds 60 fps keeps its polish (the gate is 60 fps)', () {
      final q = AdaptiveQuality(window: 4, downAfter: 1)..refreshRate = 120;
      expect(q.budgetMs, closeTo(16.67, 0.01));
      for (var i = 0; i < 4; i++) {
        q.addFrame(rasterMs: 11);
      }
      expect(q.quality, SceneQuality.high);
      for (var i = 0; i < 4; i++) {
        q.addFrame(rasterMs: 19);
      }
      expect(q.quality, SceneQuality.balanced);
    });

    test('a 48 Hz panel budgets its own frame', () {
      final q = AdaptiveQuality()..refreshRate = 48;
      expect(q.budgetMs, closeTo(20.83, 0.01));
    });

    test('build overruns count too', () {
      final q = AdaptiveQuality(window: 4, downAfter: 1);
      for (var i = 0; i < 4; i++) {
        q.addFrame(rasterMs: 3, buildMs: 30);
      }
      expect(q.quality, SceneQuality.balanced);
    });
  });

  group('GyroParallax', () {
    test('integrates rotation into a few degrees, clamped', () {
      final g = GyroParallax();
      for (var i = 0; i < 100; i++) {
        g.addRates(0, 2, 1 / 60);
      }
      for (var i = 0; i < 30; i++) {
        g.advance(1 / 60);
      }
      expect(g.yaw, greaterThan(0.02));
      expect(g.yaw, lessThanOrEqualTo(g.maxAngle));
      expect(g.degrees.dx, lessThanOrEqualTo(4.02));
    });

    test('ignores sensor noise below the dead zone', () {
      final g = GyroParallax();
      for (var i = 0; i < 600; i++) {
        g.addRates(0.01, -0.012, 1 / 60);
        g.advance(1 / 60);
      }
      expect(g.yaw, 0);
      expect(g.pitch, 0);
      expect(g.isSettled, isTrue);
    });

    test('eases back to rest when the phone is still', () {
      final g = GyroParallax()..addRates(1.5, 0, 0.04);
      g.advance(1 / 60);
      expect(g.pitch, greaterThan(0));
      expect(g.isSettled, isFalse);
      for (var i = 0; i < 60 * 20; i++) {
        g.advance(1 / 60);
      }
      expect(g.pitch.abs(), lessThan(1e-4));
      expect(g.isSettled, isTrue);
    });

    test('drops samples with a broken clock', () {
      final g = GyroParallax()
        ..addRates(3, 3, 0.5)
        ..addRates(3, 3, -1)
        ..addRates(double.nan, 3, 0.01);
      g.advance(1);
      expect(g.pitch, 0);
      expect(g.yaw, greaterThan(0));
    });
  });
}
