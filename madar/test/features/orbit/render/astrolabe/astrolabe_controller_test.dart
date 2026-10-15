import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe.dart';

import 'astrolabe_fixtures.dart';

void main() {
  final now = AmmanDay.at(16, 2);
  AstrolabeState withPrayed(Set<Prayer> prayed) => AmmanDay.state(now, prayed: prayed);

  test('the first state shows lit prayers at once, without celebrating', () {
    final c = AstrolabeController();
    final lit = <Prayer>[];
    c.addIgniteListener(lit.add);
    expect(c.update(withPrayed({Prayer.fajr, Prayer.dhuhr})), isEmpty);
    expect(c.ignition(Prayer.fajr), 1);
    expect(c.ignition(Prayer.dhuhr), 1);
    expect(c.ignition(Prayer.asr), 0);
    expect(c.pulse, 0);
    expect(c.isAnimating, isFalse);
    expect(lit, isEmpty);
  });

  test('a newly logged prayer ignites 0 → 1 over 0.8 s and flares the star', () {
    final c = AstrolabeController(state: withPrayed({Prayer.fajr}));
    final lit = <Prayer>[];
    c.addIgniteListener(lit.add);
    expect(c.update(withPrayed({Prayer.fajr, Prayer.asr})), [Prayer.asr]);
    expect(lit, [Prayer.asr]);
    expect(c.ignition(Prayer.asr), lessThan(0.01));
    expect(c.pulse, greaterThan(0.5));
    expect(c.isAnimating, isTrue);
    c.advance(const Duration(milliseconds: 400));
    expect(c.ignition(Prayer.asr), closeTo(0.5, 0.02));
    c.advance(const Duration(milliseconds: 420));
    expect(c.ignition(Prayer.asr), 1);
    // the flare fades out afterwards
    c.advance(const Duration(seconds: 2));
    expect(c.pulse, 0);
    expect(c.isAnimating, isFalse);
    expect(c.ignition(Prayer.fajr), 1);
  });

  test('an undone log goes out quickly', () {
    final c = AstrolabeController(state: withPrayed({Prayer.asr}));
    c.update(withPrayed(const {}));
    expect(c.ignition(Prayer.asr), 1);
    c.advance(const Duration(milliseconds: 150));
    expect(c.ignition(Prayer.asr), closeTo(0.5, 0.02));
    c.advance(const Duration(milliseconds: 200));
    expect(c.ignition(Prayer.asr), 0);
  });

  test('animate: false applies a state silently', () {
    final c = AstrolabeController(state: withPrayed(const {}));
    final lit = <Prayer>[];
    c.addIgniteListener(lit.add);
    c.update(withPrayed({Prayer.maghrib}), animate: false);
    expect(c.ignition(Prayer.maghrib), 1);
    expect(lit, isEmpty);
  });

  test('reduced motion: the hook still fires but nothing animates', () {
    final c = AstrolabeController(state: withPrayed(const {}))..reducedMotion = true;
    final lit = <Prayer>[];
    c.addIgniteListener(lit.add);
    final t0 = c.time;
    c.update(withPrayed({Prayer.dhuhr}));
    expect(lit, [Prayer.dhuhr]);
    expect(c.ignition(Prayer.dhuhr), 1);
    expect(c.pulse, 0);
    c.advance(const Duration(seconds: 1));
    expect(c.time, t0);
    expect(c.isAnimating, isFalse);
  });

  test('turning reduced motion on settles running animations', () {
    final c = AstrolabeController(state: withPrayed(const {}))..update(withPrayed({Prayer.isha}));
    expect(c.isAnimating, isTrue);
    c.reducedMotion = true;
    expect(c.ignition(Prayer.isha), 1);
    expect(c.pulse, 0);
    expect(c.isAnimating, isFalse);
  });

  test('the shader clock runs with the scene ticker', () {
    final c = AstrolabeController(initialTime: 3);
    c.advanceSeconds(0.25);
    c.advance(const Duration(milliseconds: 250));
    expect(c.time, closeTo(3.5, 1e-9));
    c.advanceSeconds(-1);
    expect(c.time, closeTo(3.5, 1e-9));
  });

  test('celebrate flares the core star', () {
    final c = AstrolabeController();
    c.celebrate(strength: 0.4);
    expect(c.pulse, 0.4);
    c.celebrate(strength: 0.2);
    expect(c.pulse, 0.4, reason: 'a weaker flare never dims a stronger one');
    c.celebrate(strength: 3);
    expect(c.pulse, 1);
  });

  test('tilt swings the brass light and notifies the painter', () {
    final c = AstrolabeController();
    var notified = 0;
    c.addListener(() => notified++);
    final flat = c.light;
    expect(flat.distance, closeTo(1, 1e-9));
    expect(flat.dy, lessThan(0), reason: 'lit from above');
    c.tilt = const AstrolabeTilt(pitch: 0.2, yaw: 0.3);
    expect(notified, 1);
    expect(c.light, isNot(flat));
    expect(c.light.distance, closeTo(1, 1e-9));
    c.tilt = const AstrolabeTilt(pitch: 0.2, yaw: 0.3);
    expect(notified, 1, reason: 'same tilt, no repaint');
    expect(AstrolabeController.lightFor(AstrolabeTilt.flat), flat);
  });

  test('every change repaints through the listenable, never a rebuild', () {
    final c = AstrolabeController(state: withPrayed(const {}));
    var notified = 0;
    c.addListener(() => notified++);
    c
      ..advance(const Duration(milliseconds: 16))
      ..update(withPrayed({Prayer.fajr}))
      ..celebrate();
    expect(notified, 3);
    c.removeIgniteListener((_) {});
    c.dispose();
  });

  test('ignition of voluntary prayers is always zero', () {
    final c = AstrolabeController(state: withPrayed({Prayer.fajr}));
    expect(c.ignition(Prayer.witr), 0);
    expect(c.state, isNotNull);
    expect(const Offset(0, 0), Offset.zero);
  });
}
