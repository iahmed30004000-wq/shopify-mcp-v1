import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/haptics.dart';
import 'package:madar/core/sound/sound_api.dart';

import 'sound_fakes.dart';

void main() {
  late FakeTime time;
  late FakeHapticDriver driver;
  late PlatformHapticsService haptics;

  setUp(() {
    time = FakeTime();
    driver = FakeHapticDriver(time);
    haptics = PlatformHapticsService(driver: driver, clock: time.clock, schedule: time.schedule);
  });

  void fireAndSettle(Haptic h) {
    haptics.fire(h);
    time.advance(const Duration(seconds: 1));
  }

  group('patterns', () {
    test('primitives map to the platform effects', () {
      fireAndSettle(Haptic.selection);
      fireAndSettle(Haptic.tick);
      fireAndSettle(Haptic.light);
      fireAndSettle(Haptic.medium);
      fireAndSettle(Haptic.heavy);
      fireAndSettle(Haptic.warning);
      fireAndSettle(Haptic.none);
      expect(driver.names, ['selection', 'selection', 'light', 'medium', 'heavy', 'medium']);
    });

    test('success = two light taps 70 ms apart', () {
      haptics.fire(Haptic.success);
      time.advance(const Duration(milliseconds: 200));
      expect(driver.events, [('light', Duration.zero), ('light', const Duration(milliseconds: 70))]);
    });

    test('error = heavy → light → heavy', () {
      haptics.fire(Haptic.error);
      time.advance(const Duration(milliseconds: 300));
      expect(driver.names, ['heavy', 'light', 'heavy']);
      expect(driver.events[1].$2, const Duration(milliseconds: 90));
      expect(driver.events[2].$2, const Duration(milliseconds: 180));
    });
  });

  group('enabled flag', () {
    test('disabled service fires nothing', () {
      haptics.enabled = false;
      for (final h in Haptic.values) {
        haptics.fire(h);
      }
      time.advance(const Duration(seconds: 1));
      expect(driver.events, isEmpty);
    });

    test('disabling mid-pattern drops the pending steps', () {
      haptics.fire(Haptic.error);
      time.advance(const Duration(milliseconds: 100)); // heavy + light
      haptics.enabled = false;
      time.advance(const Duration(milliseconds: 200));
      expect(driver.names, ['heavy', 'light']);
    });
  });

  group('rate limiting (fake clock)', () {
    test('fast scrolling ticks are thinned to ≈22 Hz instead of a continuous buzz', () {
      // A tick every 8 ms for 400 ms (a fling through a wheel picker).
      for (var t = 0; t < 400; t += 8) {
        haptics.fire(Haptic.tick);
        time.advance(const Duration(milliseconds: 8));
      }
      final n = driver.events.length;
      expect(n, inInclusiveRange(7, 10), reason: '$n ticks in 400 ms');
      for (var i = 1; i < n; i++) {
        expect(driver.events[i].$2 - driver.events[i - 1].$2, greaterThanOrEqualTo(const Duration(milliseconds: 45)));
      }
    });

    test('a stronger pattern pre-empts a recent weaker one; a weaker one waits', () {
      haptics.fire(Haptic.tick);
      time.advance(const Duration(milliseconds: 5));
      haptics.fire(Haptic.heavy); // stronger → allowed immediately
      time.advance(const Duration(milliseconds: 5));
      haptics.fire(Haptic.light); // weaker within the global gap → dropped
      expect(driver.names, ['selection', 'heavy']);
      time.advance(const Duration(milliseconds: 40));
      haptics.fire(Haptic.light); // after the gap → allowed
      expect(driver.names, ['selection', 'heavy', 'light']);
    });

    test('repeated heavy thumps are spaced by their own interval', () {
      haptics.fire(Haptic.heavy);
      time.advance(const Duration(milliseconds: 60));
      haptics.fire(Haptic.heavy);
      time.advance(const Duration(milliseconds: 70));
      haptics.fire(Haptic.heavy);
      expect(driver.names, ['heavy', 'heavy']);
    });

    test('HapticRateLimiter is a pure function of time', () {
      final limiter = HapticRateLimiter();
      expect(limiter.allow(Haptic.none, Duration.zero), isFalse);
      expect(limiter.allow(Haptic.selection, Duration.zero), isTrue);
      expect(limiter.allow(Haptic.selection, const Duration(milliseconds: 44)), isFalse);
      expect(limiter.allow(Haptic.selection, const Duration(milliseconds: 45)), isTrue);
      expect(HapticRateLimiter.priority(Haptic.error), greaterThan(HapticRateLimiter.priority(Haptic.heavy)));
    });
  });

  testWidgets('SystemHapticDriver drives HapticFeedback on the platform channel', (tester) async {
    final log = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      log.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    const d = SystemHapticDriver();
    d.selectionClick();
    d.lightImpact();
    d.mediumImpact();
    d.heavyImpact();
    await tester.pump();
    expect(log.map((c) => c.arguments), [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });
}
