import 'dart:async';

import 'package:flutter/services.dart';

import 'sound_api.dart';

/// The platform's primitive haptic effects (mockable).
abstract interface class HapticDriver {
  void selectionClick();
  void lightImpact();
  void mediumImpact();
  void heavyImpact();
}

/// [HapticDriver] over Flutter's `HapticFeedback` platform channel.
final class SystemHapticDriver implements HapticDriver {
  const SystemHapticDriver();

  @override
  void selectionClick() => unawaited(HapticFeedback.selectionClick().catchError((Object _) {}));
  @override
  void lightImpact() => unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
  @override
  void mediumImpact() => unawaited(HapticFeedback.mediumImpact().catchError((Object _) {}));
  @override
  void heavyImpact() => unawaited(HapticFeedback.heavyImpact().catchError((Object _) {}));
}

/// Decides whether a haptic may fire now, so fast scrolling ticks, rapid
/// taps and bursts of feedback never turn into a continuous buzz.
///
/// * Each pattern has its own minimum interval (ticks ≈ 22 Hz max, heavy
///   thumps ≥ 120 ms apart, multi-pulse patterns ≥ 250 ms apart).
/// * Across patterns a short global gap applies, except that a *stronger*
///   pattern may always pre-empt a weaker one (an error right after a tick
///   is still felt).
final class HapticRateLimiter {
  HapticRateLimiter({this.globalGap = const Duration(milliseconds: 30), Map<Haptic, Duration>? minIntervals})
      : minIntervals = minIntervals ?? defaultIntervals;

  static const Map<Haptic, Duration> defaultIntervals = {
    Haptic.tick: Duration(milliseconds: 45),
    Haptic.selection: Duration(milliseconds: 45),
    Haptic.light: Duration(milliseconds: 60),
    Haptic.medium: Duration(milliseconds: 90),
    Haptic.heavy: Duration(milliseconds: 120),
    Haptic.warning: Duration(milliseconds: 200),
    Haptic.success: Duration(milliseconds: 250),
    Haptic.error: Duration(milliseconds: 400),
  };

  final Duration globalGap;
  final Map<Haptic, Duration> minIntervals;

  final Map<Haptic, Duration> _last = {};
  Duration? _lastAny;
  int _lastPriority = 0;

  /// Relative strength – a stronger pattern can pre-empt the global gap.
  static int priority(Haptic h) => switch (h) {
        Haptic.none => 0,
        Haptic.tick || Haptic.selection => 1,
        Haptic.light => 2,
        Haptic.medium || Haptic.success || Haptic.warning => 3,
        Haptic.heavy => 4,
        Haptic.error => 5,
      };

  /// Returns true (and records the event) if [h] may fire at [now].
  bool allow(Haptic h, Duration now) {
    if (h == Haptic.none) return false;
    final last = _last[h];
    final interval = minIntervals[h] ?? Duration.zero;
    if (last != null && now - last < interval) return false;
    final p = priority(h);
    final lastAny = _lastAny;
    if (lastAny != null && now - lastAny < globalGap && p <= _lastPriority) return false;
    _last[h] = now;
    _lastAny = now;
    _lastPriority = p;
    return true;
  }

  void reset() {
    _last.clear();
    _lastAny = null;
    _lastPriority = 0;
  }
}

typedef HapticScheduler = void Function(Duration delay, void Function() action);

/// [HapticsService] over the platform haptic engine.
///
/// Patterns: success = two light taps 70 ms apart; warning = medium;
/// error = heavy → light → heavy; tick / selection = selection click.
class PlatformHapticsService implements HapticsService {
  PlatformHapticsService({
    this._driver = const SystemHapticDriver(),
    Duration Function()? clock,
    HapticScheduler? schedule,
    HapticRateLimiter? limiter,
    this._enabled = true,
  })  : _clock = clock ?? _monotonic(),
        _schedule = schedule ?? _timerSchedule,
        _limiter = limiter ?? HapticRateLimiter();

  static const successGap = Duration(milliseconds: 70);
  static const errorGap = Duration(milliseconds: 90);

  final HapticDriver _driver;
  final Duration Function() _clock;
  final HapticScheduler _schedule;
  final HapticRateLimiter _limiter;
  bool _enabled;

  /// Bumped on disable so pending pattern steps are dropped.
  int _epoch = 0;

  static Duration Function() _monotonic() {
    final sw = Stopwatch()..start();
    return () => sw.elapsed;
  }

  static void _timerSchedule(Duration delay, void Function() action) => Timer(delay, action);

  @override
  bool get enabled => _enabled;

  @override
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _epoch++;
    if (value) _limiter.reset();
  }

  @override
  void fire(Haptic haptic) {
    if (!_enabled || haptic == Haptic.none) return;
    if (!_limiter.allow(haptic, _clock())) return;
    switch (haptic) {
      case Haptic.none:
        return;
      case Haptic.selection:
      case Haptic.tick:
        _driver.selectionClick();
      case Haptic.light:
        _driver.lightImpact();
      case Haptic.medium:
      case Haptic.warning:
        _driver.mediumImpact();
      case Haptic.heavy:
        _driver.heavyImpact();
      case Haptic.success:
        _driver.lightImpact();
        _later(successGap, _driver.lightImpact);
      case Haptic.error:
        _driver.heavyImpact();
        _later(errorGap, _driver.lightImpact);
        _later(errorGap * 2, _driver.heavyImpact);
    }
  }

  void _later(Duration delay, void Function() step) {
    final epoch = _epoch;
    _schedule(delay, () {
      if (_enabled && epoch == _epoch) step();
    });
  }
}
