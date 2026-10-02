import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../application/adhan_providers.dart';
import '../domain/adhan_event.dart';
import 'adhan_screen.dart';

/// Keeps the adhan alive in the app and presents the [AdhanScreen] over
/// everything when an adhan / reminder notification is tapped, launches the
/// app full-screen, or the adhan time comes while Madar is open.
///
/// Wire it once, **outside the lock gate** (the adhan must show over the
/// biometric lock – it reveals nothing personal) but inside the database
/// gate, under `MaterialApp`'s builder so it has the theme, locale and media
/// query – e.g. in `AppFrame`:
///
/// ```dart
/// AppGate(
///   child: AdhanHost(
///     backButtonDispatcher: ref.watch(routerProvider).backButtonDispatcher,
///     child: lockGate.wrap(context, child),
///   ),
/// )
/// ```
///
/// * Until the launch notification has been read (a frame or two) it keeps
///   the app unpainted, so nothing flashes over the lock screen before the
///   adhan covers it; after an adhan that may have shown over the lock
///   screen closes, the app stays unpainted until the phone is unlocked
///   ([adhanVeilProvider]).
/// * While the adhan shows, the system back button closes it (pass the
///   router's [backButtonDispatcher]) – it never pops the hidden app's pages
///   or leaves the app underneath.
/// * It also watches [adhanSyncProvider] (alarms re-planned on every
///   relevant change) and [adhanQuietProvider] (game music / ambience muted
///   during the adhan and the prayer).
class AdhanHost extends ConsumerStatefulWidget {
  const AdhanHost({super.key, required this.child, this.backButtonDispatcher});

  final Widget child;

  /// The app router's back button dispatcher (`GoRouter.backButtonDispatcher`).
  /// The host sits above the router, so without it the back button reaches
  /// the hidden app while the adhan covers it.
  final BackButtonDispatcher? backButtonDispatcher;

  @override
  ConsumerState<AdhanHost> createState() => _AdhanHostState();
}

class _AdhanHostState extends ConsumerState<AdhanHost> {
  ChildBackButtonDispatcher? _back;
  bool _wantBack = false;
  bool _backScheduled = false;

  @override
  void didUpdateWidget(AdhanHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backButtonDispatcher != widget.backButtonDispatcher) _releaseBack(oldWidget.backButtonDispatcher);
  }

  @override
  void dispose() {
    _releaseBack(widget.backButtonDispatcher);
    super.dispose();
  }

  /// Takes the back button while an adhan shows – after the frame, because
  /// the router (below) registers its own callback as it builds – and again
  /// on every rebuild, so it stays ahead of the lock gate's.
  void _syncBack(bool showing) {
    _wantBack = showing;
    if (!showing && _back == null) return;
    if (_backScheduled) return;
    _backScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _backScheduled = false;
      if (!mounted) return;
      final root = widget.backButtonDispatcher;
      if (!_wantBack) {
        _releaseBack(root);
        return;
      }
      if (root is! RootBackButtonDispatcher) return;
      _back ??= root.createChildBackButtonDispatcher()..addCallback(_onBack);
      _back!.takePriority();
      // Let the system hand the back gesture to Flutter even when the hidden
      // app is on its first page (Android 14+ predictive back).
      const NavigationNotification(canHandlePop: true).dispatch(context);
    });
  }

  void _releaseBack(BackButtonDispatcher? root) {
    final child = _back;
    if (child == null) return;
    child.removeCallback(_onBack);
    if (root is RootBackButtonDispatcher) root.forget(child);
    _back = null;
  }

  Future<bool> _onBack() {
    if (ref.read(adhanEventProvider) == null) return SynchronousFuture(false);
    ref.read(adhanEventProvider.notifier).dismiss();
    return SynchronousFuture(true);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(adhanSyncProvider);
    ref.watch(adhanQuietProvider);
    final event = ref.watch(adhanEventProvider);
    final checked = ref.watch(adhanLaunchCheckedProvider);
    final veiled = ref.watch(adhanVeilProvider);
    _syncBack(event != null);
    return Stack(
      fit: StackFit.expand,
      children: [
        // The app underneath stops ticking and hides from accessibility
        // while the adhan covers it. It is not painted at all while the
        // launch notification is unread, when the adhan came from a
        // notification (that may be over the lock screen, and the adhan
        // screen fades in) and after such an adhan closed until the phone is
        // unlocked (the window is dropping behind the keyguard).
        Offstage(
          offstage:
              veiled || (!checked && event == null) || (event != null && event.source != AdhanEventSource.foreground),
          child: TickerMode(
            enabled: event == null,
            child: ExcludeSemantics(excluding: event != null, child: widget.child),
          ),
        ),
        AnimatedSwitcher(
          duration: context.motion(MadarMotion.long),
          switchInCurve: MadarMotion.decelerate,
          switchOutCurve: MadarMotion.accelerate,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(animation), child: child),
          ),
          child: event == null
              ? const SizedBox.shrink(key: ValueKey('no-adhan'))
              // The host sits above the app's navigator: the screen gets an
              // overlay of its own (the tooltips of its buttons).
              : Overlay.wrap(
                  key: ValueKey(event.key),
                  child: AdhanScreen(event: event, onClose: () => ref.read(adhanEventProvider.notifier).dismiss()),
                ),
        ),
      ],
    );
  }
}
