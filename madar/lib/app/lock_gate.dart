import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routing/router.dart';
import '../features/kids/shell/application/kids_providers.dart' show kidsModeOnProvider;
import '../features/lock/presentation/lock_gate_host.dart';

/// Seam for the app lock (fingerprint + PIN).
///
/// The app shell wraps the unlocked app in [wrap] once the encrypted
/// database is open. An implementation returns a widget that covers [app]
/// with the lock screen on launch and again after the app has been in the
/// background longer than `AppSettings.lockAfterSeconds` (when
/// `AppSettings.lockEnabled`), and reveals it after a successful
/// authentication. It must keep [app] mounted underneath so navigation state
/// survives locking.
abstract class LockGate {
  const LockGate();

  Widget wrap(BuildContext context, Widget app);
}

/// No lock – the app is shown as soon as the data is unlocked (tests and
/// previews may override [lockGateProvider] with it).
class NoLockGate extends LockGate {
  const NoLockGate();

  @override
  Widget wrap(BuildContext context, Widget app) => app;
}

/// The Phase 2 app lock: fingerprint (local_auth; the system prompt opens by
/// itself on the lock screen while the astrolabe assembles) with the Madar
/// PIN as fallback, the background time-out and the privacy shield
/// ([LockGateHost]).
///
/// It is always installed and follows Settings › Security: the lock is only
/// active when `AppSettings.lockEnabled` is on and a PIN has been set, so a
/// fresh install opens straight into the app until the owner turns it on.
///
/// «مدار الصغار»: while kids mode is on the lock host is simply not mounted
/// (see [_KidsAwareLock]).
class BiometricLockGate extends LockGate {
  const BiometricLockGate();

  @override
  Widget wrap(BuildContext context, Widget app) => _KidsAwareLock(app: app);
}

/// The app lock around the app, except while kids mode is on.
///
/// The kids shell is its own gate: the adult app is unreachable from it (the
/// router redirects every location into `/kids`) and leaving takes the
/// parent's PIN or fingerprint, so a child who resumes the phone must never be
/// stopped at the adult lock screen, and a relaunch with kids mode on lands
/// in the kids home with no lock screen (and no fingerprint prompt) in between.
/// The app is held under a [GlobalKey], so switching between the two shapes
/// moves it without rebuilding it: its navigation stays. When kids mode is
/// left the parent has just proved who they are, and the exit tells the lock
/// so (`KidsActions.leave`): no second lock screen.
class _KidsAwareLock extends ConsumerStatefulWidget {
  const _KidsAwareLock({required this.app});

  final Widget app;

  @override
  ConsumerState<_KidsAwareLock> createState() => _KidsAwareLockState();
}

class _KidsAwareLockState extends ConsumerState<_KidsAwareLock> {
  final GlobalKey _appKey = GlobalKey(debugLabel: 'madar-app-under-lock');

  @override
  Widget build(BuildContext context) {
    final app = KeyedSubtree(key: _appKey, child: widget.app);
    if (ref.watch(kidsModeOnProvider)) return app;
    return LockGateHost(backButtonDispatcher: ref.watch(routerProvider).backButtonDispatcher, child: app);
  }
}

/// The active [LockGate].
final lockGateProvider = Provider<LockGate>((ref) => const BiometricLockGate());
