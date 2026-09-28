import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routing/router.dart';
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

/// The Phase 2 app lock: fingerprint (local_auth) with the Madar PIN as
/// fallback, the hold-to-unlock astrolabe, the background time-out and the
/// privacy shield ([LockGateHost]).
///
/// It is always installed and follows Settings › Security: the lock is only
/// active when `AppSettings.lockEnabled` is on and a PIN has been set, so a
/// fresh install opens straight into the app until the owner turns it on.
class BiometricLockGate extends LockGate {
  const BiometricLockGate();

  @override
  Widget wrap(BuildContext context, Widget app) => Consumer(
    builder: (context, ref, child) =>
        LockGateHost(backButtonDispatcher: ref.watch(routerProvider).backButtonDispatcher, child: child!),
    child: app,
  );
}

/// The active [LockGate].
final lockGateProvider = Provider<LockGate>((ref) => const BiometricLockGate());
