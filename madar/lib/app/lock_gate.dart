import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seam for the Phase 2 app lock (fingerprint / device credential).
///
/// The app shell wraps the unlocked app in [wrap] once the encrypted
/// database is open. A real implementation returns a widget that covers
/// [app] with the lock screen on launch and again after the app has been in
/// the background longer than `AppSettings.lockAfterSeconds` (when
/// `AppSettings.lockEnabled`), and reveals it after a successful
/// authentication. It must keep [app] mounted underneath so navigation state
/// survives locking.
abstract class LockGate {
  const LockGate();

  Widget wrap(BuildContext context, Widget app);
}

/// Phase 0: no lock – the app is shown as soon as the data is unlocked.
class NoLockGate extends LockGate {
  const NoLockGate();

  @override
  Widget wrap(BuildContext context, Widget app) => app;
}

/// The active [LockGate]; Phase 2 overrides it with the biometric gate.
final lockGateProvider = Provider<LockGate>((ref) => const NoLockGate());
