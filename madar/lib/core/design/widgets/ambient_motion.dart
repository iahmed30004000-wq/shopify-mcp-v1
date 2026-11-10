import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../motion/motion.dart';

/// Global switch for purely decorative, never-ending ambient motion: the
/// cosmos drift, the glass sheen and the empty-state illustration loops.
///
/// Under `flutter test` it defaults to **off**, so any screen built on
/// `MadarScaffold` / `GlassPanel` still lets `pumpAndSettle` settle (each
/// surface then renders one static, fully-composed frame). Tests that want
/// the live motion opt back in with [debugOverride]. Loaders (`OrbitLoader`)
/// are not ambient: like any progress indicator they always animate.
///
/// Per subtree, [AmbientMotionScope] turns the loops off too (battery
/// saver), and reduced motion always does – see [AmbientMotionContext].
abstract final class AmbientMotion {
  static bool? _override;

  static final bool _underTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// Whether ambient loops may run (reduced motion, [AmbientMotionScope] and
  /// TickerMode still apply on top of this).
  static bool get enabled => _override ?? !_underTest;

  /// Forces ambient motion on/off; `null` restores the default.
  @visibleForTesting
  static set debugOverride(bool? value) => _override = value;
}

/// Turns every ambient loop below it off – the app shell inserts it with
/// `enabled: false` in battery saver, so the cosmos, glass sheens and empty
/// states render one static frame and schedule no frames at all.
class AmbientMotionScope extends InheritedWidget {
  const AmbientMotionScope({super.key, required this.enabled, required super.child});

  final bool enabled;

  /// The nearest scope's switch (true without a scope). Establishes a
  /// dependency, so `didChangeDependencies` re-runs when it flips.
  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AmbientMotionScope>()?.enabled ?? true;

  @override
  bool updateShouldNotify(AmbientMotionScope oldWidget) => oldWidget.enabled != enabled;
}

extension AmbientMotionContext on BuildContext {
  /// Whether ambient loops may run here: [AmbientMotion.enabled], the
  /// nearest [AmbientMotionScope] (battery saver) and not reduced motion.
  bool get ambientMotion => AmbientMotion.enabled && AmbientMotionScope.enabledOf(this) && !reducedMotion;
}

/// One app-wide clock for the ambient loops (cosmos drift, glass sheen).
///
/// A running [Ticker] schedules a frame on *every* vsync (90/120 Hz on
/// Android once the high refresh rate is requested) even when its callback
/// only updates a value every few frames, so throttling inside the callback
/// saves nothing: the full-screen shader and every backdrop blur still run
/// at the display rate. This clock instead ticks a periodic [Timer] at
/// [rate] (30 Hz) and only its listeners mark paints dirty, so an idle
/// screen composites ~30 frames a second, and every subscriber repaints in
/// the same frame.
///
/// The timer runs only while at least one listener is subscribed (no
/// pending timers once every ambient widget is gone or paused).
final class AmbientClock {
  AmbientClock._();

  /// The shared clock.
  static final AmbientClock instance = AmbientClock._();

  /// Tick period (~30 Hz).
  static const Duration rate = Duration(microseconds: 33333);

  static final double _rateSeconds = rate.inMicroseconds / Duration.microsecondsPerSecond;

  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  Timer? _timer;
  int _listeners = 0;

  /// Seconds accumulated by previous runs (the clock only advances while it
  /// has listeners).
  double _offset = 0;
  int _runTicks = 0;

  /// Monotonic seconds of ambient time.
  double get seconds => _offset + _runTicks * _rateSeconds;

  /// Tick counter (listen with [addListener]).
  int get tick => _tick.value;

  /// Number of subscribed listeners (tests).
  @visibleForTesting
  int get debugListeners => _listeners;

  /// Whether the periodic timer is running (tests).
  @visibleForTesting
  bool get debugRunning => _timer?.isActive ?? false;

  void addListener(VoidCallback listener) {
    _tick.addListener(listener);
    if (_listeners++ == 0) {
      _runTicks = 0;
      _timer = Timer.periodic(rate, (t) {
        // `t.tick` counts skipped periods too, so a late timer never slows
        // the drift down.
        _runTicks = t.tick;
        _tick.value++;
      });
    }
  }

  void removeListener(VoidCallback listener) {
    _tick.removeListener(listener);
    if (--_listeners == 0) {
      _timer?.cancel();
      _timer = null;
      _offset += _runTicks * _rateSeconds;
      _runTicks = 0;
    }
  }
}
