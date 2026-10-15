import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion.dart';
import '../application/lock_controller.dart';
import '../domain/lock_session.dart';
import 'lock_screen.dart';

/// Hosts the app under the app lock.
///
/// * The app ([child]) stays mounted the whole time, so navigation state
///   survives locking; while locked it is offstage, its tickers are paused
///   and it is hidden from accessibility and focus – nothing of it is ever
///   painted before the owner unlocks (the lock decides on the very first
///   frame, see [LockController]).
/// * Lifecycle changes go to the controller (time-out lock, privacy shield);
///   biometric availability is re-checked on every return.
/// * While locked, the system back button goes to the lock screen (leave
///   the PIN pad …) and otherwise leaves the app – it never pops the hidden
///   app's routes. Pass the router's [backButtonDispatcher] for that.
/// * [LockExempt] screens (the full-screen adhan) show above the lock.
class LockGateHost extends ConsumerStatefulWidget {
  const LockGateHost({super.key, required this.child, this.backButtonDispatcher});

  final Widget child;
  final BackButtonDispatcher? backButtonDispatcher;

  @override
  ConsumerState<LockGateHost> createState() => _LockGateHostState();
}

class _LockGateHostState extends ConsumerState<LockGateHost> {
  late final AppLifecycleListener _lifecycle;
  final ValueNotifier<double> _reveal = ValueNotifier(0);
  final LockBackHandler _back = LockBackHandler();
  ChildBackButtonDispatcher? _backChild;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  void _onLifecycle(AppLifecycleState state) {
    ref.read(lockControllerProvider.notifier).onLifecycle(state);
    if (state == AppLifecycleState.resumed) ref.invalidate(biometricAvailabilityProvider);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _releaseBack();
    _reveal.dispose();
    super.dispose();
  }

  // Back button while locked. The router registers its own callback when
  // it builds (below this widget), so priority is taken after the frame.
  bool _wantBack = false;
  bool _backScheduled = false;

  void _syncBack(bool locked) {
    _wantBack = locked;
    if (_backScheduled) return;
    _backScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _backScheduled = false;
      if (!mounted) return;
      final root = widget.backButtonDispatcher;
      if (_wantBack && _backChild == null && root is RootBackButtonDispatcher) {
        if (!root.hasCallbacks) return _syncBack(true);
        _backChild = root.createChildBackButtonDispatcher()
          ..addCallback(_onBack)
          ..takePriority();
      } else if (!_wantBack) {
        _releaseBack();
      }
    });
  }

  void _releaseBack() {
    final child = _backChild;
    if (child == null) return;
    child.removeCallback(_onBack);
    final root = widget.backButtonDispatcher;
    if (root is RootBackButtonDispatcher) root.forget(child);
    _backChild = null;
  }

  Future<bool> _onBack() {
    if (!_back.handle()) unawaited(SystemNavigator.pop());
    return SynchronousFuture(true);
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockControllerProvider);
    final exempt = ref.watch(lockExemptionsProvider) > 0;
    // An exempt route still coming in / going out: it animates offstage.
    final moving = ref.watch(lockExemptTransitionsProvider) > 0;
    final locked = lock.phase == LockPhase.locked && !exempt;
    final showLock = lock.phase != LockPhase.open && !exempt;
    _syncBack(showLock);

    return Stack(
      fit: StackFit.expand,
      children: [
        _AppLayer(
          hidden: locked,
          ticking: moving,
          reveal: lock.phase == LockPhase.revealing ? _reveal : null,
          child: _GatedApp(child: widget.child),
        ),
        AnimatedSwitcher(
          duration: context.motion(MadarMotion.medium),
          switchInCurve: MadarMotion.decelerate,
          switchOutCurve: MadarMotion.accelerate,
          child: showLock
              ? Overlay.wrap(
                  key: const ValueKey('lock'),
                  child: LockScreen(reveal: _reveal, backHandler: _back),
                )
              : const SizedBox.shrink(key: ValueKey('open')),
        ),
        if (lock.shielded && !showLock) const PrivacyShield(),
      ],
    );
  }
}

/// The app beneath the lock: offstage (no paint, no hit tests, no tickers,
/// no semantics, no focus) while locked; zoomed in behind the opening door
/// while revealing. [ticking] lets a [LockExempt] route finish its
/// transition while still hidden.
class _AppLayer extends StatelessWidget {
  const _AppLayer({required this.hidden, required this.child, this.ticking = false, this.reveal});

  final bool hidden;
  final bool ticking;
  final ValueListenable<double>? reveal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget app = ExcludeFocus(
      excluding: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: TickerMode(
          enabled: !hidden || ticking,
          child: Offstage(offstage: hidden, child: child),
        ),
      ),
    );
    final r = reveal;
    return ValueListenableBuilder<double>(
      valueListenable: r ?? const _Zero(),
      child: app,
      // Always the same widget shape, so the app's state is never rebuilt.
      builder: (context, v, child) {
        final k = r == null || context.reducedMotion ? 1.0 : Curves.easeOutCubic.transform(v.clamp(0.0, 1.0));
        return Transform.scale(scale: 1.1 - 0.1 * k, child: child);
      },
    );
  }
}

class _Zero implements ValueListenable<double> {
  const _Zero();

  @override
  double get value => 0;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// The cover shown over an unlocked app while it is not in the foreground
/// (recents, the notification shade, a system dialog), so its content never
/// appears in the recents thumbnail. Instant to show, quick to lift.
class PrivacyShield extends StatelessWidget {
  const PrivacyShield({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: L10n.of(context).lockShieldSemantics,
      child: ColoredBox(
        color: t.space0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(radius: 0.9, colors: [Color.lerp(t.space2, t.accent, 0.08)!, t.space0]),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IslamicStar(size: 56, glow: true, color: t.gold),
                const SizedBox(height: Space.l),
                Text(
                  L10n.of(context).appName,
                  style: Theme.of(context).textTheme.headlineMedium!.copyWith(color: t.gold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks the subtree the gate hides while locked (see [LockExempt]).
class _GatedApp extends InheritedWidget {
  const _GatedApp({required super.child});

  @override
  bool updateShouldNotify(_GatedApp oldWidget) => false;
}

/// Lets one full-screen page of the (locked) app show above the app lock –
/// for a screen that must appear even when Madar is locked and reveals
/// nothing personal. The app stays locked: when the page goes away the lock
/// screen returns.
///
/// Safe by construction, because while the exemption holds the gate has to
/// show the app's navigator:
/// * it only applies to the root of an **opaque route** of the gated app
///   (anywhere else – e.g. a layer above the gate such as `AdhanHost`,
///   which needs no exemption at all – it does nothing);
/// * the route's entrance plays **hidden** (only its own ticker time is
///   granted) and the page shows once it is fully in, so the page
///   underneath never shows through the transition;
/// * the exemption ends **synchronously** the moment the route starts
///   leaving or another route starts covering it – before the next frame –
///   and that transition, too, finishes hidden.
class LockExempt extends ConsumerStatefulWidget {
  const LockExempt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockExempt> createState() => _LockExemptState();
}

class _LockExemptState extends ConsumerState<LockExempt> {
  late final LockExemptions _shown = ref.read(lockExemptionsProvider.notifier);
  late final LockExemptions _moving = ref.read(lockExemptTransitionsProvider.notifier);
  ModalRoute<Object?>? _route;
  bool _holdsShown = false;
  bool _holdsMoving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _detach();
      _route = route;
      route?.animation?.addStatusListener(_onStatus);
      route?.secondaryAnimation?.addStatusListener(_onStatus);
    }
    // Providers can't change while the tree builds.
    scheduleMicrotask(() {
      if (mounted) _update();
    });
  }

  void _detach() {
    _route?.animation?.removeStatusListener(_onStatus);
    _route?.secondaryAnimation?.removeStatusListener(_onStatus);
  }

  /// Runs inside `Navigator.pop` / `push` or a ticker – before the next
  /// frame is built.
  void _onStatus(AnimationStatus _) {
    try {
      _update();
    } catch (_) {
      // Popped from inside a build: apply as soon as that build is over.
      scheduleMicrotask(() {
        if (mounted) _update();
      });
    }
  }

  void _update() {
    final route = _route;
    final gated = mounted && route != null && context.getInheritedWidgetOfExactType<_GatedApp>() != null;
    if (!gated) return _apply(shown: false, moving: false);
    final entrance = route.animation?.status ?? AnimationStatus.completed;
    final cover = route.secondaryAnimation?.status ?? AnimationStatus.dismissed;
    final shown =
        route.isCurrent && route.opaque && entrance == AnimationStatus.completed && cover == AnimationStatus.dismissed;
    _apply(shown: shown, moving: !shown && (entrance.isAnimating || cover.isAnimating));
  }

  void _apply({required bool shown, required bool moving}) {
    // Grant ticker time before withdrawing the exemption (and the other
    // way round), so the gate never sees a frame with neither.
    if (moving && !_holdsMoving) {
      _holdsMoving = true;
      _moving.hold();
    }
    if (shown != _holdsShown) {
      _holdsShown = shown;
      shown ? _shown.hold() : _shown.release();
    }
    if (!moving && _holdsMoving) {
      _holdsMoving = false;
      _moving.release();
    }
  }

  @override
  void dispose() {
    _detach();
    final shown = _holdsShown, moving = _holdsMoving;
    _holdsShown = _holdsMoving = false;
    if (shown || moving) {
      final a = _shown, b = _moving;
      scheduleMicrotask(() {
        try {
          if (shown) a.release();
          if (moving) b.release();
        } catch (_) {
          // The app (and its provider scope) is going away too.
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
