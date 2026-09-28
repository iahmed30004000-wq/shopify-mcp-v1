/// Madar's app lock: fingerprint (local_auth) with the Madar PIN as the
/// fallback, the hold-to-unlock astrolabe, the background time-out and the
/// privacy shield.
///
/// * Gate: `BiometricLockGate` (lib/app/lock_gate.dart) is the default
///   `lockGateProvider`; it hosts the app in [LockGateHost].
/// * Settings: [SecuritySettingsSection].
/// * Flows the rest of the app may reuse: [showPinSetupSheet],
///   [confirmLockIdentity], `LockController.whileSuspended`, [LockExempt].
library;

export 'application/lock_controller.dart';
export 'data/biometric_auth.dart';
export 'data/lock_vault.dart';
export 'domain/lock_record.dart';
export 'domain/lock_session.dart';
export 'domain/pin_hash.dart' show PinHash, PinHasher, PinRules;
export 'presentation/lock_gate_host.dart';
export 'presentation/lock_screen.dart' show LockScreen, LockScreenMode, LockBackHandler;
export 'presentation/pin_pad.dart' show PinDots, PinKeypad;
export 'presentation/pin_sheets.dart';
export 'presentation/security_settings.dart';
export 'render/lock_astrolabe.dart';
