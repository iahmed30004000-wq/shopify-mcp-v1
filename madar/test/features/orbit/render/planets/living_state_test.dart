import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/orbit/render/planets/planets.dart';

/// Advances [a] by [seconds] in 60 Hz steps, returning the sampled values of
/// [sample] after each step.
List<double> _run(LivingStateAnimator a, double seconds, double Function() sample) {
  final out = <double>[];
  const dt = 1 / 60;
  for (var t = 0.0; t < seconds - 1e-9; t += dt) {
    a.advance(dt);
    out.add(sample());
  }
  return out;
}

void main() {
  group('PulseEnvelope', () {
    test('0 → 1 → 0 over 1.5 s', () {
      expect(PulseEnvelope.at(0), 0);
      expect(PulseEnvelope.at(-1), 0);
      expect(PulseEnvelope.at(PulseEnvelope.attack), closeTo(1, 1e-9));
      expect(PulseEnvelope.at(PulseEnvelope.duration), 0);
      expect(PulseEnvelope.at(PulseEnvelope.duration - 0.01), lessThan(0.001));
      expect(PulseEnvelope.duration, closeTo(1.5, 1e-9));
    });

    test('rises monotonically, then decays monotonically', () {
      double prev = 0;
      for (var t = 0.0; t <= PulseEnvelope.attack; t += 0.01) {
        final v = PulseEnvelope.at(t);
        expect(v, greaterThanOrEqualTo(prev - 1e-12));
        prev = v;
      }
      prev = 1;
      for (var t = PulseEnvelope.attack; t < PulseEnvelope.duration; t += 0.01) {
        final v = PulseEnvelope.at(t);
        expect(v, lessThanOrEqualTo(prev + 1e-12));
        prev = v;
      }
    });

    test('still clearly visible half a second after the peak', () {
      expect(PulseEnvelope.at(0.7), inInclusiveRange(0.25, 0.7));
    });
  });

  group('LivingStateAnimator', () {
    test('a new key shows its score at once', () {
      final a = LivingStateAnimator();
      expect(a.setScore('family', 0.8), isFalse);
      expect(a.score('family'), 0.8);
      expect(a.isAnimating, isFalse);
      expect(a.score('unknown'), 0.6, reason: 'calm default');
    });

    test('the displayed score morphs to a new score over ~1.2 s, without overshoot', () {
      final a = LivingStateAnimator()..setScore('body', 0.2);
      expect(a.setScore('body', 0.9), isTrue);
      expect(a.isAnimating, isTrue);
      final values = _run(a, 2, () => a.score('body'));
      // Visible morph: a third of the way at 0.2 s, not yet there at 0.5 s.
      expect(values[11], inInclusiveRange(0.3, 0.75));
      expect(values[29], lessThan(0.9 - 0.02));
      // Visually settled by ~1.2 s.
      expect((values[71] - 0.9).abs(), lessThan(0.9 * 0.03));
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThanOrEqualTo(values[i - 1] - 1e-9), reason: 'monotonic');
        expect(values[i], lessThanOrEqualTo(0.9 + 1e-9), reason: 'no overshoot');
      }
      expect(a.isAnimating, isFalse);
      expect(a.score('body'), 0.9);
    });

    test('retargeting mid-morph keeps the motion continuous', () {
      final a = LivingStateAnimator()..setScore('work', 0);
      a.setScore('work', 1);
      _run(a, 0.3, () => 0);
      final mid = a.score('work');
      a.setScore('work', 0.1);
      a.advance(1 / 60);
      expect((a.score('work') - mid).abs(), lessThan(0.05), reason: 'no jump');
      _run(a, 3, () => 0);
      expect(a.score('work'), closeTo(0.1, 1e-9));
    });

    test('scores are clamped to 0..1', () {
      final a = LivingStateAnimator()..setScore('x', 3);
      expect(a.score('x'), 1);
      a.setScore('x', -1, animate: false);
      expect(a.score('x'), 0);
    });

    test('a pulse flares 0 → strength → 0 over ~1.5 s', () {
      final a = LivingStateAnimator()..setScore('faith', 0.8);
      expect(a.pulseOf('faith'), 0);
      a.pulse('faith', strength: 0.9);
      expect(a.isAnimating, isTrue);
      final values = _run(a, 1.6, () => a.pulseOf('faith'));
      final peak = values.reduce((x, y) => x > y ? x : y);
      expect(peak, closeTo(0.9, 0.02));
      expect(values.indexOf(peak), lessThan(20), reason: 'fast rise');
      expect(values.last, 0);
      expect(a.isAnimating, isFalse);
    });

    test('a weaker pulse never dims a bright one; a new pulse rises from the current level', () {
      final a = LivingStateAnimator()..setScore('k', 0.5);
      a.pulse('k');
      _run(a, 0.3, () => 0);
      final bright = a.pulseOf('k');
      a.pulse('k', strength: 0.2);
      expect(a.pulseOf('k'), bright);
      _run(a, 0.9, () => 0);
      final dim = a.pulseOf('k');
      expect(dim, lessThan(0.4));
      a.pulse('k');
      expect(a.pulseOf('k'), closeTo(dim, 0.02), reason: 'no dip on retrigger');
      a.advance(0.05);
      expect(a.pulseOf('k'), greaterThan(dim));
    });

    test('pulses for unknown keys are ignored', () {
      final a = LivingStateAnimator()..pulse('ghost');
      expect(a.pulseOf('ghost'), 0);
      expect(a.isAnimating, isFalse);
    });

    test('reduced motion: scores jump, pulses do not flare', () {
      final a = LivingStateAnimator()..setScore('k', 0.2);
      a.setScore('k', 0.8);
      a.reducedMotion = true;
      expect(a.score('k'), 0.8, reason: 'settled when switched on');
      a.setScore('k', 0.3);
      expect(a.score('k'), 0.3);
      a.pulse('k');
      expect(a.pulseOf('k'), 0);
      expect(a.isAnimating, isFalse);
    });

    test('retain forgets removed bodies', () {
      final a = LivingStateAnimator()
        ..setScore('a', 1)
        ..setScore('b', 1);
      a.retain({'a'});
      expect(a.contains('a'), isTrue);
      expect(a.contains('b'), isFalse);
    });
  });

  group('OpacityFader', () {
    test('fades toward its target, frame-rate independent', () {
      final a = OpacityFader(timeConstant: 0.2)..target('x', 1);
      expect(a.of('x'), 0, reason: 'a new label fades in');
      for (var i = 0; i < 12; i++) {
        a.advance(1 / 60);
      }
      final at60 = a.of('x');
      final b = OpacityFader(timeConstant: 0.2)..target('x', 1);
      for (var i = 0; i < 6; i++) {
        b.advance(1 / 30);
      }
      expect(b.of('x'), closeTo(at60, 1e-9));
      expect(at60, closeTo(1 - 0.36788, 0.01));
      expect(a.isAnimating, isTrue);
      a.advance(2);
      expect(a.of('x'), 1);
      expect(a.isAnimating, isFalse);
    });

    test('snap, settle and retain', () {
      final a = OpacityFader()..target('x', 0.7, snap: true);
      expect(a.of('x'), 0.7);
      a.target('x', 0);
      a.settle();
      expect(a.of('x'), 0);
      a.retain({});
      expect(a.of('x'), 0);
      expect(a.isAnimating, isFalse);
    });
  });
}
