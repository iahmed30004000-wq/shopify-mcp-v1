import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Extra springs of the motion kit (the core ones live in [MadarMotion]).
abstract final class MadarSprings {
  /// Critically damped and very stiff: settles in ~100 ms without overshoot.
  /// Used wherever reduced motion replaces a physical move by a quick fade.
  static final SpringDescription quickFade = SpringDescription.withDampingRatio(mass: 1, stiffness: 1600, ratio: 1.0);

  /// Rolling digits: brisk with a small, mechanical overshoot.
  static final SpringDescription roll = SpringDescription.withDampingRatio(mass: 1, stiffness: 300, ratio: 0.74);

  /// Default tolerance for unit-scale (0..1) values.
  static const Tolerance unit = Tolerance(distance: 1e-3, velocity: 1e-2);

  /// Default tolerance for pixel-scale values.
  static const Tolerance pixel = Tolerance(distance: 0.05, velocity: 0.5);
}

/// A retargetable one-dimensional spring, independent of any widget or ticker.
///
/// Time is supplied by the caller as an absolute, monotonic clock in seconds
/// ([advanceTo]). [retarget] re-seeds the underlying [SpringSimulation] from
/// the current position *and velocity*, so changing the target mid-flight
/// never produces a velocity discontinuity.
class SpringMotion {
  SpringMotion({required this._spring, double value = 0, this.tolerance = MadarSprings.unit})
    : _value = value,
      _target = value;

  SpringDescription _spring;
  final Tolerance tolerance;

  SpringSimulation? _sim;
  double _start = 0;
  double _time = 0;
  double _value;
  double _velocity = 0;
  double _target;

  /// Position at the last [advanceTo].
  double get value => _value;

  /// Velocity (units / second) at the last [advanceTo].
  double get velocity => _velocity;

  double get target => _target;

  /// Clock time of the last [advanceTo] / [retarget].
  double get time => _time;

  bool get isAtRest => _sim == null;

  SpringDescription get spring => _spring;

  /// Changes the spring, keeping the current position and velocity.
  set spring(SpringDescription value) {
    if (identical(value, _spring)) return;
    _spring = value;
    if (_sim != null) retarget(_target);
  }

  /// Advances the simulation to the absolute clock [time] (seconds).
  void advanceTo(double time) {
    _time = math.max(_time, time);
    final sim = _sim;
    if (sim == null) return;
    final t = _time - _start;
    if (sim.isDone(t)) {
      _value = _target;
      _velocity = 0;
      _sim = null;
      return;
    }
    _value = sim.x(t);
    _velocity = sim.dx(t);
  }

  /// Heads for [target] from the current state. When [time] is given the
  /// state is first advanced to it. [velocity] overrides the current velocity
  /// (e.g. a fling).
  void retarget(double target, {double? time, double? velocity}) {
    if (time != null) advanceTo(time);
    _target = target;
    final v = velocity ?? _velocity;
    _velocity = v;
    if ((target - _value).abs() <= tolerance.distance && v.abs() <= tolerance.velocity) {
      _value = target;
      _velocity = 0;
      _sim = null;
      return;
    }
    _start = _time;
    _sim = SpringSimulation(_spring, _value, target, v, tolerance: tolerance);
  }

  /// Teleports to [value] and stops.
  void jumpTo(double value) {
    _value = value;
    _target = value;
    _velocity = 0;
    _sim = null;
  }
}

/// Converts a spring into a [Curve] (0 → 1, possibly overshooting) so springs
/// can drive duration-based transitions such as route pages.
class SpringCurve extends Curve {
  SpringCurve(SpringDescription spring, {Tolerance tolerance = MadarSprings.unit})
    : _sim = SpringSimulation(spring, 0, 1, 0, tolerance: tolerance),
      settleSeconds = _settle(spring, tolerance);

  final SpringSimulation _sim;

  /// Physical time the spring needs to settle; the curve's `t = 1` maps here.
  final double settleSeconds;

  /// [settleSeconds] as a [Duration] – the natural duration for this curve.
  Duration get settleDuration => Duration(microseconds: (settleSeconds * 1e6).round());

  static double _settle(SpringDescription spring, Tolerance tolerance) {
    final sim = SpringSimulation(spring, 0, 1, 0, tolerance: tolerance);
    const step = 1 / 240;
    var t = 0.0;
    while (t < 5 && !sim.isDone(t)) {
      t += step;
    }
    return math.max(t, step);
  }

  @override
  double transformInternal(double t) => _sim.x(t * settleSeconds);
}

/// Shared ticker plumbing for [SpringValue] and [SpringOffsetValue].
///
/// The clock only advances while the ticker runs, which is fine because the
/// springs are at rest whenever it is stopped.
mixin _SpringTicking {
  Ticker? _ticker;
  double _clock = 0;
  double _tickBase = 0;
  double _delayUntil = 0;
  bool _hasPending = false;

  bool get _ticking => _ticker?.isActive ?? false;

  void _initTicker(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    _clock = _tickBase + elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (_hasPending && _clock >= _delayUntil) {
      _hasPending = false;
      _applyPending(_clock);
    }
    _advance(_clock);
    _notifyValue();
    if (_atRest && !_hasPending) {
      _ticker!.stop();
      _notifyStatus();
    }
  }

  void _ensureTicking() {
    final ticker = _ticker!;
    if (ticker.isActive) return;
    _tickBase = _clock;
    ticker.start();
    _notifyStatus();
  }

  /// Schedules the pending retarget [delay] from now.
  void _schedule(Duration delay) {
    _hasPending = true;
    _delayUntil = _clock + delay.inMicroseconds / Duration.microsecondsPerSecond;
    _ensureTicking();
  }

  bool get _atRest;
  void _advance(double time);
  void _applyPending(double time);
  void _notifyValue();
  void _notifyStatus();

  void _disposeTicker() {
    _ticker?.dispose();
    _ticker = null;
  }
}

/// A spring-driven, retargetable animation of a double.
///
/// Unlike an [AnimationController] it has no duration: [animateTo] simply
/// moves the target and the value follows physically, keeping its velocity.
/// It is an [Animation<double>], so it plugs into [AnimatedBuilder],
/// [ScaleTransition], [FadeTransition]...
class SpringValue extends Animation<double>
    with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin, AnimationEagerListenerMixin, _SpringTicking {
  SpringValue({
    required TickerProvider vsync,
    double value = 0,
    SpringDescription? spring,
    Tolerance tolerance = MadarSprings.unit,
  }) : _motion = SpringMotion(spring: spring ?? MadarMotion.gentle, value: value, tolerance: tolerance) {
    _initTicker(vsync);
  }

  final SpringMotion _motion;
  AnimationStatus _lastStatus = AnimationStatus.completed;

  @override
  double get value => _motion.value;

  double get velocity => _motion.velocity;

  double get target => _motion.target;

  @override
  bool get isAnimating => _ticking;

  SpringDescription get spring => _motion.spring;
  set spring(SpringDescription value) => _motion.spring = value;

  @override
  AnimationStatus get status {
    if (!_ticking) return AnimationStatus.completed;
    return _motion.target >= _motion.value ? AnimationStatus.forward : AnimationStatus.reverse;
  }

  /// Springs toward [target], preserving the current velocity unless
  /// [velocity] is given. [delay] holds the start (the value keeps still).
  void animateTo(double target, {double? velocity, SpringDescription? spring, Duration delay = Duration.zero}) {
    if (spring != null) _motion.spring = spring;
    _pendingTarget = target;
    _pendingVelocity = velocity;
    if (delay > Duration.zero) {
      _schedule(delay);
      return;
    }
    _hasPending = false;
    _applyPending(_clock);
    if (_motion.isAtRest) {
      _ticker?.stop();
      notifyListeners();
      _notifyStatus();
      return;
    }
    _ensureTicking();
  }

  /// Stops and sets [value] immediately.
  void jumpTo(double value) {
    _hasPending = false;
    _ticker?.stop();
    _motion.jumpTo(value);
    notifyListeners();
    _notifyStatus();
  }

  double _pendingTarget = 0;
  double? _pendingVelocity;

  @override
  void _applyPending(double time) => _motion.retarget(_pendingTarget, time: time, velocity: _pendingVelocity);

  @override
  bool get _atRest => _motion.isAtRest;

  @override
  void _advance(double time) => _motion.advanceTo(time);

  @override
  void _notifyValue() => notifyListeners();

  @override
  void _notifyStatus() {
    final s = status;
    if (s != _lastStatus) {
      _lastStatus = s;
      notifyStatusListeners(s);
    }
  }

  @override
  void dispose() {
    _disposeTicker();
    clearListeners();
    clearStatusListeners();
    super.dispose();
  }
}

/// Two-dimensional counterpart of [SpringValue] (e.g. a card following a
/// finger, a planet re-centring).
class SpringOffsetValue extends Animation<Offset>
    with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin, AnimationEagerListenerMixin, _SpringTicking {
  SpringOffsetValue({
    required TickerProvider vsync,
    Offset value = Offset.zero,
    SpringDescription? spring,
    Tolerance tolerance = MadarSprings.pixel,
  }) : _x = SpringMotion(spring: spring ?? MadarMotion.gentle, value: value.dx, tolerance: tolerance),
       _y = SpringMotion(spring: spring ?? MadarMotion.gentle, value: value.dy, tolerance: tolerance) {
    _initTicker(vsync);
  }

  final SpringMotion _x;
  final SpringMotion _y;
  AnimationStatus _lastStatus = AnimationStatus.completed;

  @override
  Offset get value => Offset(_x.value, _y.value);

  Offset get velocity => Offset(_x.velocity, _y.velocity);

  Offset get target => Offset(_x.target, _y.target);

  @override
  bool get isAnimating => _ticking;

  @override
  AnimationStatus get status => _ticking ? AnimationStatus.forward : AnimationStatus.completed;

  void animateTo(Offset target, {Offset? velocity, SpringDescription? spring, Duration delay = Duration.zero}) {
    if (spring != null) {
      _x.spring = spring;
      _y.spring = spring;
    }
    _pendingTarget = target;
    _pendingVelocity = velocity;
    if (delay > Duration.zero) {
      _schedule(delay);
      return;
    }
    _hasPending = false;
    _applyPending(_clock);
    if (_atRest) {
      _ticker?.stop();
      notifyListeners();
      _notifyStatus();
      return;
    }
    _ensureTicking();
  }

  Offset _pendingTarget = Offset.zero;
  Offset? _pendingVelocity;

  @override
  void _applyPending(double time) {
    _x.retarget(_pendingTarget.dx, time: time, velocity: _pendingVelocity?.dx);
    _y.retarget(_pendingTarget.dy, time: time, velocity: _pendingVelocity?.dy);
  }

  void jumpTo(Offset value) {
    _hasPending = false;
    _ticker?.stop();
    _x.jumpTo(value.dx);
    _y.jumpTo(value.dy);
    notifyListeners();
    _notifyStatus();
  }

  @override
  bool get _atRest => _x.isAtRest && _y.isAtRest;

  @override
  void _advance(double time) {
    _x.advanceTo(time);
    _y.advanceTo(time);
  }

  @override
  void _notifyValue() => notifyListeners();

  @override
  void _notifyStatus() {
    final s = status;
    if (s != _lastStatus) {
      _lastStatus = s;
      notifyStatusListeners(s);
    }
  }

  @override
  void dispose() {
    _disposeTicker();
    clearListeners();
    clearStatusListeners();
    super.dispose();
  }
}

/// Animates a double toward [value] on a spring and rebuilds [builder] with
/// the current position. Changing [value] mid-flight retargets smoothly.
///
/// Under reduced motion the value jumps to the target.
class SpringBuilder extends StatefulWidget {
  const SpringBuilder({
    super.key,
    required this.value,
    required this.builder,
    this.from,
    this.spring,
    this.tolerance = MadarSprings.unit,
    this.child,
  });

  /// Target value.
  final double value;

  /// Initial value on first build (animates `from → value`); defaults to
  /// [value] (no entrance).
  final double? from;

  /// Defaults to [MadarMotion.gentle].
  final SpringDescription? spring;
  final Tolerance tolerance;
  final ValueWidgetBuilder<double> builder;
  final Widget? child;

  @override
  State<SpringBuilder> createState() => _SpringBuilderState();
}

class _SpringBuilderState extends State<SpringBuilder> with SingleTickerProviderStateMixin {
  late final SpringValue _v = SpringValue(
    vsync: this,
    value: widget.from ?? widget.value,
    spring: widget.spring,
    tolerance: widget.tolerance,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _moveTo(widget.value);
    }
  }

  void _moveTo(double target) {
    if (context.reducedMotion) {
      _v.jumpTo(target);
    } else {
      _v.animateTo(target, spring: widget.spring);
    }
  }

  @override
  void didUpdateWidget(SpringBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value || widget.spring != oldWidget.spring) _moveTo(widget.value);
  }

  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _v,
      builder: (context, child) => widget.builder(context, _v.value, child),
      child: widget.child,
    );
  }
}

/// [SpringBuilder] for an [Offset].
class SpringOffsetBuilder extends StatefulWidget {
  const SpringOffsetBuilder({
    super.key,
    required this.value,
    required this.builder,
    this.from,
    this.spring,
    this.tolerance = MadarSprings.pixel,
    this.child,
  });

  final Offset value;
  final Offset? from;
  final SpringDescription? spring;
  final Tolerance tolerance;
  final ValueWidgetBuilder<Offset> builder;
  final Widget? child;

  @override
  State<SpringOffsetBuilder> createState() => _SpringOffsetBuilderState();
}

class _SpringOffsetBuilderState extends State<SpringOffsetBuilder> with SingleTickerProviderStateMixin {
  late final SpringOffsetValue _v = SpringOffsetValue(
    vsync: this,
    value: widget.from ?? widget.value,
    spring: widget.spring,
    tolerance: widget.tolerance,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _moveTo(widget.value);
    }
  }

  void _moveTo(Offset target) {
    if (context.reducedMotion) {
      _v.jumpTo(target);
    } else {
      _v.animateTo(target, spring: widget.spring);
    }
  }

  @override
  void didUpdateWidget(SpringOffsetBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value || widget.spring != oldWidget.spring) _moveTo(widget.value);
  }

  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _v,
      builder: (context, child) => widget.builder(context, _v.value, child),
      child: widget.child,
    );
  }
}
