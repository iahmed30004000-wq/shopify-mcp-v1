import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode, lerpDouble;

import 'package:animations/animations.dart' show ContainerTransitionType, OpenContainer, ClosedCallback;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/themes.dart';
import '../design/tokens.dart';
import '../sound/sound_api.dart';
import 'motion.dart';
import 'spring_press.dart';
import 'springs.dart';

/// Axis of a [MadarTransitions.sharedAxis] page.
enum MadarSharedAxis {
  /// Forward navigation enters from the reading-direction end (right in LTR,
  /// left in RTL) and pushes the old page toward the start.
  horizontal,
  vertical,

  /// Zoom in (forward) / zoom out (back).
  scaled,
}

/// Madar's route transitions for go_router.
///
/// Use inside a `GoRoute.pageBuilder`:
/// ```dart
/// pageBuilder: (context, state) => MadarTransitions.sharedAxis(
///   context: context, key: state.pageKey, child: const PrayerScreen()),
/// ```
///
/// Every page also tells the page below how to leave in sync with it
/// (Flutter's `delegatedTransition`), so mixed stacks – a sheet over a planet
/// over the cosmos – stay choreographed. Under reduced motion every
/// transition is a quick cross-fade and pages below stay still.
abstract final class MadarTransitions {
  /// Material fade-through: the old page fades out, the new one fades and
  /// scales (0.92 → 1) in through the theme's deep-space colour.
  static MadarTransitionPage<T> fadeThrough<T>({
    required BuildContext context,
    required Widget child,
    LocalKey? key,
    String? name,
    Object? arguments,
    String? restorationId,
    Duration duration = MadarMotion.medium,
  }) {
    final d = context.motion(duration);
    return MadarTransitionPage<T>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      transitionDuration: d,
      reverseTransitionDuration: d,
      transitionsBuilder: fadeThroughTransitions,
      delegatedTransition: _fadeThroughDelegate,
      child: child,
    );
  }

  /// Shared-axis transition. [MadarSharedAxis.horizontal] follows the reading
  /// direction: in RTL the new page arrives from the left.
  static MadarTransitionPage<T> sharedAxis<T>({
    required BuildContext context,
    required Widget child,
    MadarSharedAxis axis = MadarSharedAxis.horizontal,
    LocalKey? key,
    String? name,
    Object? arguments,
    String? restorationId,
    Duration duration = MadarMotion.medium,
  }) {
    final d = context.motion(duration);
    return MadarTransitionPage<T>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      transitionDuration: d,
      reverseTransitionDuration: d,
      transitionsBuilder: switch (axis) {
        MadarSharedAxis.horizontal => sharedAxisHorizontalTransitions,
        MadarSharedAxis.vertical => sharedAxisVerticalTransitions,
        MadarSharedAxis.scaled => sharedAxisScaledTransitions,
      },
      delegatedTransition: switch (axis) {
        MadarSharedAxis.horizontal => _sharedAxisHorizontalDelegate,
        MadarSharedAxis.vertical => _sharedAxisVerticalDelegate,
        MadarSharedAxis.scaled => _sharedAxisScaledDelegate,
      },
      child: child,
    );
  }

  /// Cinematic fly-in: the new page is revealed through a growing circle
  /// centred on a focal point (a tapped planet) while it scales up from it
  /// and comes into focus (blur → sharp); a glowing rim rides the edge of the
  /// reveal. The page below flies toward the same point.
  ///
  /// [origin] is a global position; [originRect] (global) starts the reveal
  /// at that shape's size, e.g. the planet's bounds. Defaults to the centre.
  static MadarTransitionPage<T> cosmicZoom<T>({
    required BuildContext context,
    required Widget child,
    Offset? origin,
    Rect? originRect,
    LocalKey? key,
    String? name,
    Object? arguments,
    String? restorationId,
    Duration duration = MadarMotion.cinematic,
    Duration reverseDuration = MadarMotion.long,
  }) {
    final focus = originRect?.center ?? origin;
    final startRadius = originRect == null ? 0.0 : originRect.shortestSide / 2;
    return MadarTransitionPage<T>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      transitionDuration: context.motion(duration),
      reverseTransitionDuration: context.motion(reverseDuration),
      transitionsBuilder: (context, animation, secondaryAnimation, child) => _CosmicZoomTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        origin: focus,
        startRadius: startRadius,
        child: child,
      ),
      delegatedTransition: _cosmicDelegateFor(focus),
      child: child,
    );
  }

  /// A full-height sheet page rising from the bottom on a spring, over a
  /// dimmed, dismissible barrier; the page below recedes like a card in a
  /// stack. The [child] decides the sheet's shape (align it to the bottom and
  /// leave the rest transparent for a partial sheet).
  static MadarTransitionPage<T> sheetRise<T>({
    required BuildContext context,
    required Widget child,
    bool dismissible = true,
    Color? barrierColor,
    LocalKey? key,
    String? name,
    Object? arguments,
    String? restorationId,
  }) {
    final tokens = _tokensOf(context);
    return MadarTransitionPage<T>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: restorationId,
      opaque: false,
      barrierDismissible: dismissible,
      barrierColor: barrierColor ?? tokens.space0.withValues(alpha: tokens.isDark ? 0.62 : 0.38),
      barrierLabel: Localizations.of<MaterialLocalizations>(context, MaterialLocalizations)?.modalBarrierDismissLabel,
      transitionDuration: context.motion(_sheetCurve.settleDuration),
      reverseTransitionDuration: context.motion(MadarMotion.medium),
      transitionsBuilder: sheetRiseTransitions,
      delegatedTransition: _sheetDelegate,
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // Raw transition builders (usable in PageTransitionsTheme / other routes).
  // ---------------------------------------------------------------------------

  static Widget fadeThroughTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _Dual(
      animation: animation,
      kind: _Kind.fadeThrough,
      child: _Dual(animation: secondaryAnimation, kind: _Kind.fadeThrough, secondary: true, child: child),
    );
  }

  static Widget sharedAxisHorizontalTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _sharedAxis(_Kind.horizontal, animation, secondaryAnimation, child);

  static Widget sharedAxisVerticalTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _sharedAxis(_Kind.vertical, animation, secondaryAnimation, child);

  static Widget sharedAxisScaledTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _sharedAxis(_Kind.scaled, animation, secondaryAnimation, child);

  static Widget _sharedAxis(_Kind kind, Animation<double> animation, Animation<double> secondary, Widget child) {
    return _Dual(
      animation: animation,
      kind: kind,
      child: _Dual(animation: secondary, kind: kind, secondary: true, child: child),
    );
  }

  static Widget sheetRiseTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _SheetRiseTransition(animation: animation, child: child);

  // Delegates: how the page BELOW moves while a page of this kind enters.

  static Widget? _fadeThroughDelegate(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    if (context.reducedMotion) return null;
    return _Dual(
      animation: secondaryAnimation,
      kind: _Kind.fadeThrough,
      secondary: true,
      child: child ?? const SizedBox.shrink(),
    );
  }

  static Widget? _sharedAxisHorizontalDelegate(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) => _axisDelegate(_Kind.horizontal, context, secondaryAnimation, child);

  static Widget? _sharedAxisVerticalDelegate(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) => _axisDelegate(_Kind.vertical, context, secondaryAnimation, child);

  static Widget? _sharedAxisScaledDelegate(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) => _axisDelegate(_Kind.scaled, context, secondaryAnimation, child);

  static Widget? _axisDelegate(_Kind kind, BuildContext context, Animation<double> secondary, Widget? child) {
    if (context.reducedMotion) return null;
    return _Dual(animation: secondary, kind: kind, secondary: true, child: child ?? const SizedBox.shrink());
  }

  static Widget? _sheetDelegate(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    if (context.reducedMotion) return null;
    return _RecedeTransition(animation: secondaryAnimation, child: child ?? const SizedBox.shrink());
  }

  static DelegatedTransitionBuilder _cosmicDelegateFor(Offset? origin) {
    return (context, animation, secondaryAnimation, allowSnapshotting, child) {
      if (context.reducedMotion) return null;
      return _FlyTowardTransition(
        animation: secondaryAnimation,
        origin: origin,
        child: child ?? const SizedBox.shrink(),
      );
    };
  }

  static final SpringCurve _sheetCurve = SpringCurve(MadarMotion.gentle);
}

/// A go_router page whose route also provides a `delegatedTransition` for the
/// route below it. Returned by every [MadarTransitions] factory.
class MadarTransitionPage<T> extends CustomTransitionPage<T> {
  const MadarTransitionPage({
    required super.child,
    required super.transitionsBuilder,
    this.delegatedTransition,
    super.transitionDuration,
    super.reverseTransitionDuration,
    super.maintainState,
    super.fullscreenDialog,
    super.opaque,
    super.barrierDismissible,
    super.barrierColor,
    super.barrierLabel,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  /// How the page below animates while this one enters / leaves.
  final DelegatedTransitionBuilder? delegatedTransition;

  @override
  Route<T> createRoute(BuildContext context) => _MadarPageRoute<T>(this);
}

class _MadarPageRoute<T> extends PageRoute<T> {
  _MadarPageRoute(MadarTransitionPage<T> page) : super(settings: page);

  MadarTransitionPage<T> get _page => settings as MadarTransitionPage<T>;

  @override
  bool get barrierDismissible => _page.barrierDismissible;

  @override
  Color? get barrierColor => _page.barrierColor;

  @override
  String? get barrierLabel => _page.barrierLabel;

  @override
  Duration get transitionDuration => _page.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _page.reverseTransitionDuration;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  bool get opaque => _page.opaque;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _page.delegatedTransition;

  /// Every pop is heard and felt – the system back button / gesture and a
  /// tap on a sheet's barrier too, not only Madar's own back buttons (their
  /// duplicate is absorbed by the sound retrigger interval and the haptic
  /// rate limiter).
  @override
  bool didPop(T? result) {
    final popped = super.didPop(result);
    if (popped) Fx.fire(opaque ? Sfx.back : Sfx.sheetClose);
    return popped;
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Semantics(scopesRoute: true, explicitChildNodes: true, child: _page.child);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _page.transitionsBuilder(context, animation, secondaryAnimation, child);
}

/// Plugs a Madar transition into [PageTransitionsTheme] so plain
/// `MaterialPageRoute`s match the go_router pages.
class MadarPageTransitionsBuilder extends PageTransitionsBuilder {
  const MadarPageTransitionsBuilder({this.axis});

  /// `null` = fade-through.
  final MadarSharedAxis? axis;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return switch (axis) {
      null => MadarTransitions.fadeThroughTransitions(context, animation, secondaryAnimation, child),
      MadarSharedAxis.horizontal => MadarTransitions.sharedAxisHorizontalTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      ),
      MadarSharedAxis.vertical => MadarTransitions.sharedAxisVerticalTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      ),
      MadarSharedAxis.scaled => MadarTransitions.sharedAxisScaledTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      ),
    };
  }
}

// -----------------------------------------------------------------------------
// Shared helpers.
// -----------------------------------------------------------------------------

MadarTokens _tokensOf(BuildContext context) =>
    Theme.of(context).extension<MadarTokens>() ?? MadarPalettes.tokensFor(MadarThemeId.lapis);

/// Global → navigator-local focal point (pages fill their navigator).
Offset _localFocus(BuildContext context, Offset? global, Size size) {
  if (global == null) return size.center(Offset.zero);
  final box = Navigator.maybeOf(context)?.context.findRenderObject();
  if (box is RenderBox && box.attached && box.hasSize) return box.globalToLocal(global);
  return global;
}

Size _pageSize(BuildContext context) {
  final box = Navigator.maybeOf(context)?.context.findRenderObject();
  if (box is RenderBox && box.hasSize) return box.size;
  return MediaQuery.maybeSizeOf(context) ?? Size.zero;
}

enum _Kind { fadeThrough, horizontal, vertical, scaled }

/// Material's dual-transition pattern in a single, structure-stable layer:
/// the direction of [animation] picks the enter or the exit choreography
/// (an interrupted transition simply plays backwards), and the widget tree
/// never changes shape, so page state survives every transition and every
/// reduced-motion flip.
///
/// For the primary animation a pushed page *enters* and a popped page
/// *exits*; for the secondary animation ([secondary] = true) the covered page
/// *exits* and the uncovered page *enters* again.
class _Dual extends StatefulWidget {
  const _Dual({required this.animation, required this.kind, required this.child, this.secondary = false});

  final Animation<double> animation;
  final _Kind kind;
  final bool secondary;
  final Widget child;

  @override
  State<_Dual> createState() => _DualState();
}

class _DualState extends State<_Dual> {
  static const _fadeInThrough = Interval(0.35, 1, curve: MadarMotion.decelerate);
  static const _fadeOutThrough = Interval(0, 0.35, curve: MadarMotion.accelerate);
  static const _fadeInAxis = Interval(0.3, 1, curve: MadarMotion.decelerate);
  static const _fadeOutAxis = Interval(0, 0.3, curve: MadarMotion.accelerate);
  static const _fillIn = Interval(0, 0.3, curve: Curves.easeOut);
  static const Curve _travel = MadarMotion.emphasized;

  /// Status as seen by the "entering" logic (secondary is mirrored).
  AnimationStatus _status(AnimationStatus s) {
    if (!widget.secondary) return s;
    return switch (s) {
      AnimationStatus.forward => AnimationStatus.reverse,
      AnimationStatus.reverse => AnimationStatus.forward,
      AnimationStatus.dismissed => AnimationStatus.completed,
      AnimationStatus.completed => AnimationStatus.dismissed,
    };
  }

  late AnimationStatus _effective;

  bool get _entering => _effective == AnimationStatus.dismissed || _effective == AnimationStatus.forward;

  @override
  void initState() {
    super.initState();
    _effective = _status(widget.animation.status);
    widget.animation.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus raw) {
    final current = _status(raw);
    final last = _effective;
    // Same rule as DualTransitionBuilder: an interrupted transition keeps its
    // choreography and simply plays it backwards.
    final next = switch (current) {
      AnimationStatus.dismissed || AnimationStatus.completed => current,
      AnimationStatus.forward => last == AnimationStatus.reverse ? last : current,
      AnimationStatus.reverse => last == AnimationStatus.forward ? last : current,
    };
    if (next == last) return;
    final wasEntering = _entering;
    _effective = next;
    if (_entering != wasEntering) setState(() {});
  }

  @override
  void didUpdateWidget(_Dual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_onStatus);
      widget.animation.addStatusListener(_onStatus);
      _onStatus(widget.animation.status);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = context.reducedMotion;
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final fill = _tokensOf(context).space0;
    final secondary = widget.secondary;
    final kind = widget.kind;
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final v = secondary ? 1 - widget.animation.value : widget.animation.value;
        final animating = widget.animation.isAnimating;
        final entering = _entering;
        // Progress of the current choreography, 0 → 1.
        final t = entering ? v : 1 - v;
        var outer = 1.0;
        var inner = 1.0;
        var fillAlpha = 0.0;
        var scale = 1.0;
        var dx = 0.0;
        var dy = 0.0;
        if (reduced) {
          // Quick cross-fade: the pushed / popped page fades, the page below
          // stays still.
          if (!secondary) inner = entering ? t : 1 - t;
        } else if (entering) {
          final e = _travel.transform(t);
          // An arriving page (pushed, or uncovered by a pop) first fades its
          // deep-space base in – so the leaving page dissolves into the theme
          // colour, not into black – then its content. The base only exists
          // while animating: pages paint their own backgrounds at rest.
          if (animating) fillAlpha = _fillIn.transform(t);
          switch (kind) {
            case _Kind.fadeThrough:
              inner = _fadeInThrough.transform(t);
              scale = lerpDouble(0.92, 1, inner)!;
            case _Kind.horizontal:
              inner = _fadeInAxis.transform(t);
              dx = 30.0 * (secondary ? -1 : 1) * (rtl ? -1 : 1) * (1 - e);
            case _Kind.vertical:
              inner = _fadeInAxis.transform(t);
              dy = 30.0 * (secondary ? -1 : 1) * (1 - e);
            case _Kind.scaled:
              inner = _fadeInAxis.transform(t);
              scale = secondary ? lerpDouble(1.1, 1, e)! : lerpDouble(0.8, 1, e)!;
          }
        } else {
          final e = _travel.transform(t);
          final fade = switch (kind) {
            _Kind.fadeThrough => 1 - _fadeOutThrough.transform(t),
            _ => 1 - _fadeOutAxis.transform(t),
          };
          if (secondary) {
            inner = fade;
          } else {
            outer = fade;
          }
          switch (kind) {
            case _Kind.fadeThrough:
              break;
            case _Kind.horizontal:
              dx = 30.0 * (secondary ? -1 : 1) * (rtl ? -1 : 1) * e;
            case _Kind.vertical:
              dy = 30.0 * (secondary ? -1 : 1) * e;
            case _Kind.scaled:
              scale = secondary ? lerpDouble(1, 1.1, e)! : lerpDouble(1, 0.8, e)!;
          }
        }
        final matrix = Matrix4(scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1);
        return Opacity(
          opacity: outer.clamp(0.0, 1.0),
          child: ColoredBox(
            color: fill.withValues(alpha: fill.a * fillAlpha),
            child: Opacity(
              opacity: inner.clamp(0.0, 1.0),
              child: Transform(transform: matrix, alignment: Alignment.center, child: child),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _SheetRiseTransition extends StatelessWidget {
  const _SheetRiseTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = context.reducedMotion;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        double y;
        double opacity;
        if (reduced) {
          y = 0;
          opacity = t;
        } else {
          final reverse = animation.status == AnimationStatus.reverse;
          final e = reverse ? MadarMotion.accelerate.flipped.transform(t) : MadarTransitions._sheetCurve.transform(t);
          y = 1 - e;
          opacity = (t / 0.25).clamp(0.0, 1.0);
        }
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: FractionalTranslation(translation: Offset(0, y), child: child),
        );
      },
      child: child,
    );
  }
}

/// The page below a sheet: recedes into the stack with rounded corners.
class _RecedeTransition extends StatelessWidget {
  const _RecedeTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = _tokensOf(context).radiusXL;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final e = MadarMotion.standard.transform(animation.value.clamp(0.0, 1.0));
        final scale = lerpDouble(1, 0.93, e)!;
        final r = radius * e;
        return Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(r),
            clipBehavior: r > 0.5 ? Clip.antiAlias : Clip.none,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// The page below a cosmic zoom: the camera flies toward the focal point.
class _FlyTowardTransition extends StatelessWidget {
  const _FlyTowardTransition({required this.animation, required this.origin, required this.child});

  final Animation<double> animation;
  final Offset? origin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        final e = MadarMotion.orbital.transform(t);
        final size = _pageSize(context);
        final o = _localFocus(context, origin, size);
        final s = lerpDouble(1, 1.9, e)!;
        final opacity = 1 - const Interval(0.25, 0.95, curve: Curves.easeIn).transform(t);
        final matrix = Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, o.dx * (1 - s), o.dy * (1 - s), 0, 1);
        return Opacity(
          opacity: opacity,
          child: Transform(transform: matrix, child: child),
        );
      },
      child: child,
    );
  }
}

class _CosmicZoomTransition extends StatelessWidget {
  const _CosmicZoomTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.origin,
    required this.startRadius,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Offset? origin;
  final double startRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = context.reducedMotion;
    final tokens = _tokensOf(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        final size = _pageSize(context);
        final done = reduced || t >= 1 || size.isEmpty;
        final o = _localFocus(context, origin, size);
        final e = MadarMotion.orbital.transform(t);

        // Reveal radius: from the focal body to the farthest corner.
        final far = [
          o,
          o - Offset(size.width, 0),
          o - Offset(0, size.height),
          o - Offset(size.width, size.height),
        ].map((d) => d.distance).reduce(math.max);
        final radius = lerpDouble(math.max(startRadius, 6), far + 24, e)!;

        // The world inside grows toward the viewer (forward camera motion)
        // a little ahead of the reveal, so it fills the portal early.
        final startScale = startRadius > 0 && !size.isEmpty
            ? (0.45 + startRadius / size.shortestSide).clamp(0.5, 0.8)
            : 0.6;
        final s = done ? 1.0 : lerpDouble(startScale, 1, Curves.easeOutQuint.transform(t))!;
        final sigma = done ? 0.0 : 12 * math.pow(1 - e, 2).toDouble();
        final opacity = reduced ? t : (t / 0.18).clamp(0.0, 1.0);
        final matrix = Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, o.dx * (1 - s), o.dy * (1 - s), 0, 1);

        return CustomPaint(
          foregroundPainter: done
              ? null
              : _RevealRimPainter(center: o, radius: radius, progress: e, color: tokens.accentGlow),
          child: ClipOval(
            clipper: _CircleClipper(o, radius),
            clipBehavior: done ? Clip.none : Clip.antiAlias,
            child: CustomPaint(
              // Deep space behind the still-small world, so the portal is
              // never see-through at its edges.
              painter: done
                  ? null
                  : _PortalFillPainter(
                      center: o,
                      radius: radius,
                      core: tokens.nebulaA,
                      deep: tokens.space0,
                      opacity: (t / 0.12).clamp(0.0, 1.0),
                    ),
              child: Opacity(
                opacity: opacity,
                child: ImageFiltered(
                  enabled: sigma > 0.3,
                  imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
                  child: Transform(transform: matrix, child: child),
                ),
              ),
            ),
          ),
        );
      },
      child: _SecondaryRecede(animation: secondaryAnimation, child: child),
    );
  }
}

/// A cosmic page covered by another page of the same kind: drift forward.
class _SecondaryRecede extends StatelessWidget {
  const _SecondaryRecede({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = context.reducedMotion;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = reduced ? 0.0 : animation.value.clamp(0.0, 1.0);
        final e = MadarMotion.orbital.transform(t);
        return Opacity(
          opacity: 1 - 0.7 * e,
          child: Transform.scale(scale: lerpDouble(1, 1.12, e)!, child: child),
        );
      },
      child: child,
    );
  }
}

class _CircleClipper extends CustomClipper<Rect> {
  const _CircleClipper(this.center, this.radius);

  final Offset center;
  final double radius;

  @override
  Rect getClip(Size size) => Rect.fromCircle(center: center, radius: radius);

  @override
  bool shouldReclip(_CircleClipper oldClipper) => oldClipper.center != center || oldClipper.radius != radius;
}

/// The deep-space floor of the portal: a faint nebula glow at the focal
/// point fading into the theme's deepest colour.
class _PortalFillPainter extends CustomPainter {
  const _PortalFillPainter({
    required this.center,
    required this.radius,
    required this.core,
    required this.deep,
    required this.opacity,
  });

  final Offset center;
  final double radius;
  final Color core;
  final Color deep;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0 || opacity <= 0) return;
    final a = deep.a * opacity;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(deep, core, 0.35)!.withValues(alpha: a),
          deep.withValues(alpha: a),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_PortalFillPainter old) =>
      old.center != center || old.radius != radius || old.opacity != opacity || old.core != core || old.deep != deep;
}

/// The luminous rim of the cosmic reveal – a glowing edge with a faint
/// astrolabe-like outer circle.
class _RevealRimPainter extends CustomPainter {
  const _RevealRimPainter({required this.center, required this.radius, required this.progress, required this.color});

  final Offset center;
  final double radius;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - progress).clamp(0.0, 1.0);
    if (fade <= 0.01) return;
    final width = lerpDouble(22, 3, progress)!;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color.withValues(alpha: color.a * 0.75 * fade)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 10 * fade);
    canvas.drawCircle(center, radius, glow);
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: math.min(1, color.a * 1.4) * fade);
    canvas.drawCircle(center, radius, core);
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = color.withValues(alpha: color.a * 0.45 * fade);
    canvas.drawCircle(center, radius + 7 + 10 * fade, outer);
  }

  @override
  bool shouldRepaint(_RevealRimPainter old) =>
      old.center != center || old.radius != radius || old.progress != progress || old.color != color;
}

// -----------------------------------------------------------------------------
// Container transform.
// -----------------------------------------------------------------------------

/// Madar's container transform: a card grows into its page. A themed wrapper
/// around `animations`' [OpenContainer] with glass-card closed shape and
/// deep-space open colour, a spring press and feedback on open.
///
/// Reduced motion: the transform collapses to a near-instant swap.
class MadarOpenContainer<T> extends StatelessWidget {
  const MadarOpenContainer({
    super.key,
    required this.closedBuilder,
    required this.openBuilder,
    this.onClosed,
    this.tappable = true,
    this.sfx = Sfx.navigate,
    this.closedColor,
    this.openColor,
    this.closedRadius,
    this.closedBorder = true,
    this.useRootNavigator = false,
    this.duration = MadarMotion.long,
    this.transitionType = ContainerTransitionType.fadeThrough,
    this.routeSettings,
  });

  /// `open` opens the container (use it when [tappable] is false).
  final Widget Function(BuildContext context, VoidCallback open) closedBuilder;

  /// `close` pops the open page with an optional result.
  final Widget Function(BuildContext context, void Function({T? returnValue}) close) openBuilder;
  final ClosedCallback<T?>? onClosed;

  /// Tapping anywhere on the closed card opens it (with a spring press).
  final bool tappable;
  final Sfx? sfx;

  /// Defaults: [MadarTokens.glassFill] closed, [MadarTokens.space0] open.
  final Color? closedColor;
  final Color? openColor;

  /// Defaults to [MadarTokens.radiusL].
  final double? closedRadius;

  /// Hairline brass border on the closed card.
  final bool closedBorder;
  final bool useRootNavigator;
  final Duration duration;
  final ContainerTransitionType transitionType;
  final RouteSettings? routeSettings;

  @override
  Widget build(BuildContext context) {
    final t = _tokensOf(context);
    final radius = closedRadius ?? t.radiusL;
    return OpenContainer<T>(
      closedColor: closedColor ?? t.glassFill,
      openColor: openColor ?? t.space0,
      middleColor: t.space1,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: closedBorder ? BorderSide(color: t.glassBorder, width: 0.8) : BorderSide.none,
      ),
      openShape: const RoundedRectangleBorder(),
      closedShadows: [BoxShadow(color: t.glassShadow, blurRadius: 24, offset: const Offset(0, 10))],
      openShadows: const [],
      tappable: false,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      transitionDuration: context.motion(duration),
      transitionType: transitionType,
      onClosed: onClosed,
      closedBuilder: (context, open) {
        void openWithFeedback() {
          final s = sfx;
          if (s != null) Fx.fire(s);
          open();
        }

        final closed = closedBuilder(context, openWithFeedback);
        if (!tappable) return closed;
        return SpringPress(sfx: null, onTap: openWithFeedback, child: closed);
      },
      openBuilder: (context, close) => openBuilder(context, close),
    );
  }
}
