import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode, lerpDouble;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart';
import 'springs.dart';

/// The side an entering element travels in from.
enum EntranceFrom {
  /// The reading-direction start (left in LTR, right in RTL). Default.
  start,

  /// The reading-direction end.
  end,
  top,
  bottom,
}

/// Pure timing maths of Madar entrances (unit-tested).
abstract final class EntranceTiming {
  static final SpringSimulation _sim = SpringSimulation(
    MadarMotion.gentle,
    0,
    1,
    0,
    tolerance: const Tolerance(distance: 2e-3, velocity: 2e-2),
  );

  /// Seconds the entrance spring needs to settle.
  static final double settleSeconds = () {
    var t = 0.0;
    while (t < 3 && !_sim.isDone(t)) {
      t += 1 / 240;
    }
    return t;
  }();

  /// Delay of the [index]-th sibling: [step] per index, capped at [cap].
  static Duration delayFor(
    int index, {
    Duration step = MadarMotion.staggerStep,
    Duration cap = MadarMotion.staggerCap,
  }) {
    final d = step * math.max(0, index);
    return d > cap ? cap : d;
  }

  /// Spring progress (0 → 1, may overshoot a hair) [seconds] after an
  /// element's own start.
  static double progress(double seconds) {
    if (seconds <= 0) return 0;
    if (seconds >= settleSeconds || _sim.isDone(seconds)) return 1;
    return _sim.x(seconds);
  }

  /// Linear quick fade used under reduced motion.
  static double reducedProgress(double seconds) =>
      (seconds / (MadarMotion.reduced.inMicroseconds / Duration.microsecondsPerSecond)).clamp(0.0, 1.0);

  /// Total time a choreography with [count] staggered items needs.
  static double totalSeconds({
    required bool reduced,
    Duration step = MadarMotion.staggerStep,
    Duration cap = MadarMotion.staggerCap,
    int? count,
  }) {
    if (reduced) return MadarMotion.reduced.inMicroseconds / Duration.microsecondsPerSecond;
    final lastDelay = count == null ? cap : delayFor(count - 1, step: step, cap: cap);
    return lastDelay.inMicroseconds / Duration.microsecondsPerSecond + settleSeconds;
  }
}

/// The visual state of an entering element at progress `p` (pure; tested).
@immutable
class EntranceFrame {
  const EntranceFrame({required this.opacity, required this.offset, required this.scale, required this.blurSigma});

  static const settled = EntranceFrame(opacity: 1, offset: Offset.zero, scale: 1, blurSigma: 0);

  final double opacity;
  final Offset offset;
  final double scale;
  final double blurSigma;

  bool get isSettled => opacity >= 1 && offset == Offset.zero && scale == 1 && blurSigma == 0;

  /// Full choreography: fade + slide from [from] + scale 0.98 → 1 + blur → 0.
  factory EntranceFrame.at(
    double p, {
    required TextDirection textDirection,
    EntranceFrom from = EntranceFrom.start,
    double distance = 18,
    double fromScale = 0.98,
    double blur = 6,
  }) {
    if (p >= 1) return settled;
    final q = p.clamp(0.0, 1.0);
    final rest = 1 - p;
    final unit = switch (from) {
      EntranceFrom.start => Offset(textDirection == TextDirection.rtl ? 1 : -1, 0),
      EntranceFrom.end => Offset(textDirection == TextDirection.rtl ? -1 : 1, 0),
      EntranceFrom.top => const Offset(0, -1),
      EntranceFrom.bottom => const Offset(0, 1),
    };
    // Opacity leads the motion so text is readable before it lands.
    final opacity = Curves.easeOut.transform((q * 1.35).clamp(0.0, 1.0));
    final sharp = (1 - q) * (1 - q);
    return EntranceFrame(
      opacity: opacity,
      offset: unit * (distance * rest),
      scale: lerpDouble(fromScale, 1, p)!,
      blurSigma: blur * sharp,
    );
  }

  /// Reduced motion: a plain fade, nothing moves.
  factory EntranceFrame.fade(double p) =>
      p >= 1 ? settled : EntranceFrame(opacity: p.clamp(0.0, 1.0), offset: Offset.zero, scale: 1, blurSigma: 0);
}

/// A shared entrance clock: one ticker drives every [StaggerItem] /
/// [AnimatedReveal] below an [EntranceChoreo].
class EntranceClock extends ChangeNotifier {
  EntranceClock({
    required this.reduced,
    this.step = MadarMotion.staggerStep,
    this.cap = MadarMotion.staggerCap,
    this._completed = false,
  });

  /// Reduced motion: every item fades together, quickly.
  bool reduced;
  final Duration step;
  final Duration cap;

  double _seconds = 0;
  bool _started = false;
  bool _completed;
  double _until = 0;

  /// Latest settle time any item asked for (items with extra delays).
  double get requiredSeconds => _until;

  double get seconds => _seconds;
  bool get isStarted => _started || _completed;
  bool get isComplete => _completed;

  /// Seconds after which the item at [index] (plus [extraDelay]) is settled.
  double _itemEnd(int index, Duration extraDelay) {
    if (reduced) return _secondsOf(extraDelay) + EntranceTiming.totalSeconds(reduced: true);
    return _secondsOf(EntranceTiming.delayFor(index, step: step, cap: cap) + extraDelay) + EntranceTiming.settleSeconds;
  }

  /// Progress (0 → 1) of the item at [index].
  double progressOf(int index, {Duration extraDelay = Duration.zero}) {
    if (_completed) return 1;
    if (!_started) return 0;
    if (reduced) return EntranceTiming.reducedProgress(_seconds - _secondsOf(extraDelay));
    final start = _secondsOf(EntranceTiming.delayFor(index, step: step, cap: cap) + extraDelay);
    return EntranceTiming.progress(_seconds - start);
  }

  /// Whether the item at [index] has fully landed. Also records how long the
  /// timeline must keep running for it.
  bool isItemSettled(int index, {Duration extraDelay = Duration.zero}) {
    if (_completed) return true;
    final end = _itemEnd(index, extraDelay);
    if (end > _until) _until = end;
    return _started && _seconds >= end;
  }

  void _start() {
    _started = true;
    notifyListeners();
  }

  void _tick(double seconds) {
    _seconds = seconds;
    notifyListeners();
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    notifyListeners();
  }
}

double _secondsOf(Duration d) => d.inMicroseconds / Duration.microsecondsPerSecond;

/// Runs an entrance for everything below it **once per route**: all
/// [StaggerItem]s, [StaggerIn]s and [AnimatedReveal]s inside share one ticker
/// and one timeline.
///
/// * Starts on first build while tickers are enabled (an offstage page does
///   not burn its entrance invisibly).
/// * Give it an [id] to make the entrance survive the subtree being rebuilt
///   from scratch within the same route (tabs, recycled lists): once played
///   for that route + id, it shows settled immediately.
/// * Reduced motion: a single quick fade, no stagger.
class EntranceChoreo extends StatefulWidget {
  const EntranceChoreo({
    super.key,
    required this.child,
    this.id,
    this.delay = Duration.zero,
    this.step = MadarMotion.staggerStep,
    this.cap = MadarMotion.staggerCap,
    this.enabled = true,
    this.onComplete,
  });

  final Widget child;

  /// Identity for the once-per-route memory.
  final Object? id;

  /// Wait before the first item starts (e.g. let a page transition lead).
  final Duration delay;
  final Duration step;
  final Duration cap;

  /// `false` shows everything settled.
  final bool enabled;
  final VoidCallback? onComplete;

  /// The nearest clock, registering a dependency.
  static EntranceClock? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_EntranceScope>()?.clock;

  /// Whether an [EntranceChoreo] is above [context] (no dependency).
  static bool isPresent(BuildContext context) => context.getInheritedWidgetOfExactType<_EntranceScope>() != null;

  static final Expando<Set<Object>> _played = Expando<Set<Object>>('EntranceChoreo.played');

  /// Whether the entrance [id] already played for [route].
  @visibleForTesting
  static bool hasPlayed(Route<dynamic> route, Object id) => _played[route]?.contains(id) ?? false;

  @override
  State<EntranceChoreo> createState() => _EntranceChoreoState();
}

class _EntranceChoreoState extends State<EntranceChoreo> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  EntranceClock? _clock;
  ModalRoute<dynamic>? _route;
  double _startAt = 0;

  EntranceClock get clock => _clock!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = context.reducedMotion;
    final route = _route = ModalRoute.of(context);
    if (_clock == null) {
      final id = widget.id;
      final alreadyPlayed = route != null && id != null && EntranceChoreo.hasPlayed(route, id);
      _clock = EntranceClock(
        reduced: reduced,
        step: widget.step,
        cap: widget.cap,
        completed: !widget.enabled || alreadyPlayed,
      );
    } else {
      _clock!.reduced = reduced;
    }
    _maybeStart();
  }

  @override
  void didUpdateWidget(EntranceChoreo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _finish();
  }

  void _maybeStart() {
    final clock = _clock!;
    if (clock.isStarted || clock.isComplete) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    _startAt = _secondsOf(widget.delay);
    clock._start();
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final clock = _clock!;
    final t = _secondsOf(elapsed) - _startAt;
    clock._tick(t);
    final total = math.max(
      EntranceTiming.totalSeconds(reduced: clock.reduced, step: widget.step, cap: widget.cap),
      clock.requiredSeconds,
    );
    if (t >= total) _finish();
  }

  void _finish() {
    if (_ticker.isActive) _ticker.stop();
    final clock = _clock;
    if (clock == null || clock.isComplete) return;
    clock._complete();
    final id = widget.id;
    final route = _route;
    if (id != null && route != null) (EntranceChoreo._played[route] ??= <Object>{}).add(id);
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EntranceScope(clock: clock, child: widget.child);
}

class _EntranceScope extends InheritedWidget {
  const _EntranceScope({required this.clock, required super.child});

  final EntranceClock clock;

  @override
  bool updateShouldNotify(_EntranceScope oldWidget) => oldWidget.clock != clock;
}

/// One staggered element under an [EntranceChoreo] (or a [StaggerIn]).
///
/// Use directly for lazily built lists:
/// `ListView.builder(itemBuilder: (_, i) => StaggerItem(index: i, child: ...))`.
/// Items built after the entrance finished (scrolled into view later) appear
/// settled. Without an [EntranceChoreo] ancestor the child shows as is.
class StaggerItem extends StatelessWidget {
  const StaggerItem({
    super.key,
    required this.index,
    required this.child,
    this.from = EntranceFrom.start,
    this.distance = 18,
    this.blur = true,
    this.extraDelay = Duration.zero,
  });

  final int index;
  final Widget child;
  final EntranceFrom from;

  /// Travel in logical pixels (12–24 reads best).
  final double distance;

  /// Blur 6 → 0 while entering. Turn off for very large or text-dense items.
  final bool blur;
  final Duration extraDelay;

  @override
  Widget build(BuildContext context) {
    final clock = EntranceChoreo.maybeOf(context);
    if (clock == null) return child;
    return _EntranceTransition(
      clock: clock,
      index: index,
      from: from,
      distance: distance,
      blur: blur,
      extraDelay: extraDelay,
      child: child,
    );
  }
}

class _EntranceTransition extends AnimatedWidget {
  const _EntranceTransition({
    required EntranceClock clock,
    required this.index,
    required this.from,
    required this.distance,
    required this.blur,
    required this.extraDelay,
    required this.child,
  }) : super(listenable: clock);

  final int index;
  final EntranceFrom from;
  final double distance;
  final bool blur;
  final Duration extraDelay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clock = listenable as EntranceClock;
    final EntranceFrame frame;
    if (clock.isItemSettled(index, extraDelay: extraDelay)) {
      frame = EntranceFrame.settled;
    } else {
      final p = clock.progressOf(index, extraDelay: extraDelay);
      frame = clock.reduced
          ? EntranceFrame.fade(p)
          : EntranceFrame.at(
              p,
              textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
              from: from,
              distance: distance,
              blur: blur ? 6 : 0,
            );
    }
    return EntranceFrameView(frame: frame, child: child);
  }
}

/// Paints [child] in an [EntranceFrame]. The widget structure never changes
/// between frames, so the child's state survives the entrance, and a settled
/// frame costs nothing (no layers).
class EntranceFrameView extends StatelessWidget {
  const EntranceFrameView({super.key, required this.frame, required this.child});

  final EntranceFrame frame;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final f = frame;
    final blurOn = f.blurSigma > 0.25;
    final s = f.scale;
    // Column-major: scale, then translate.
    final matrix = Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, f.offset.dx, f.offset.dy, 0, 1);
    return Opacity(
      opacity: f.opacity,
      child: Transform(
        transform: matrix,
        alignment: Alignment.center,
        child: ImageFiltered(
          enabled: blurOn,
          imageFilter: blurOn
              ? ImageFilter.blur(sigmaX: f.blurSigma, sigmaY: f.blurSigma, tileMode: TileMode.decal)
              : _noBlur,
          child: child,
        ),
      ),
    );
  }

  static final ImageFilter _noBlur = ImageFilter.blur();
}

/// Children enter one after another: fade + slide from the reading-direction
/// start + scale 0.98 → 1 + blur 6 → 0, spring-driven, staggered by
/// [MadarMotion.staggerStep] and capped at [MadarMotion.staggerCap].
///
/// Lays the children out in a [Flex] (a column by default). `Expanded` /
/// `Flexible` children keep working; `Spacer`s are left unanimated.
/// Inside an [EntranceChoreo] it joins that timeline (offset by [startIndex]);
/// otherwise it runs its own, once.
class StaggerIn extends StatelessWidget {
  const StaggerIn({
    super.key,
    required this.children,
    this.direction = Axis.vertical,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.mainAxisSize = MainAxisSize.min,
    this.spacing = 0,
    this.from = EntranceFrom.start,
    this.distance = 18,
    this.blur = true,
    this.startIndex = 0,
    this.delay = Duration.zero,
    this.id,
  });

  final List<Widget> children;
  final Axis direction;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double spacing;
  final EntranceFrom from;
  final double distance;
  final bool blur;

  /// Index of the first child in an enclosing choreography.
  final int startIndex;

  /// Delay of this group (own choreography) or extra delay (shared one).
  final Duration delay;

  /// Once-per-route id for the own choreography.
  final Object? id;

  @override
  Widget build(BuildContext context) {
    final shared = EntranceChoreo.isPresent(context);
    final extra = shared ? delay : Duration.zero;
    var index = startIndex;
    Widget wrap(Widget child) {
      if (child is Spacer) return child;
      StaggerItem item(Widget c) =>
          StaggerItem(index: index++, from: from, distance: distance, blur: blur, extraDelay: extra, child: c);
      if (child is Flexible) {
        return Flexible(key: child.key, flex: child.flex, fit: child.fit, child: item(child.child));
      }
      return item(child);
    }

    final flex = Flex(
      direction: direction,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      spacing: spacing,
      children: [for (final c in children) wrap(c)],
    );
    if (shared) return flex;
    return EntranceChoreo(id: id, delay: delay, child: flex);
  }
}

/// Reveals / hides a single child with the entrance choreography (spring
/// fade + slide + scale + blur). Plays on first build when [appear] is true;
/// toggling [visible] animates both ways. Hidden children ignore pointers and
/// are excluded from semantics.
///
/// Reduced motion: a plain quick fade.
class AnimatedReveal extends StatefulWidget {
  const AnimatedReveal({
    super.key,
    required this.child,
    this.visible = true,
    this.appear = true,
    this.delay = Duration.zero,
    this.from = EntranceFrom.bottom,
    this.distance = 16,
    this.blur = true,
    this.spring,
    this.onRevealed,
  });

  final Widget child;
  final bool visible;

  /// Animate in on first build (otherwise start in the [visible] state).
  final bool appear;
  final Duration delay;
  final EntranceFrom from;
  final double distance;
  final bool blur;

  /// Defaults to [MadarMotion.gentle].
  final SpringDescription? spring;
  final VoidCallback? onRevealed;

  @override
  State<AnimatedReveal> createState() => _AnimatedRevealState();
}

class _AnimatedRevealState extends State<AnimatedReveal> with SingleTickerProviderStateMixin {
  late final SpringValue _p = SpringValue(
    vsync: this,
    value: widget.appear ? 0 : (widget.visible ? 1 : 0),
    spring: widget.spring ?? MadarMotion.gentle,
  )..addStatusListener(_onStatus);
  bool _started = false;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.visible && _p.value >= 1) widget.onRevealed?.call();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (widget.appear) _go(delay: widget.delay);
    }
  }

  @override
  void didUpdateWidget(AnimatedReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) _go();
  }

  void _go({Duration delay = Duration.zero}) {
    final reduced = context.reducedMotion;
    _p.animateTo(
      widget.visible ? 1 : 0,
      spring: reduced ? MadarSprings.quickFade : (widget.spring ?? MadarMotion.gentle),
      delay: reduced ? Duration.zero : delay,
    );
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = !widget.visible;
    return IgnorePointer(
      ignoring: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: AnimatedBuilder(
          animation: _p,
          builder: (context, child) {
            final p = _p.value;
            final settled = !_p.isAnimating && p >= 1;
            final frame = settled
                ? EntranceFrame.settled
                : context.reducedMotion
                ? EntranceFrame(opacity: p.clamp(0.0, 1.0), offset: Offset.zero, scale: 1, blurSigma: 0)
                : EntranceFrame.at(
                    p,
                    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
                    from: widget.from,
                    distance: widget.distance,
                    blur: widget.blur ? 6 : 0,
                  );
            return EntranceFrameView(frame: frame, child: child!);
          },
          child: widget.child,
        ),
      ),
    );
  }
}
