import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../data/biometric_auth.dart';
import '../data/lock_vault.dart';
import '../domain/lock_record.dart';
import '../domain/lock_session.dart';
import '../domain/pin_hash.dart';

// ----------------------------------------------------------------- providers

/// Secure storage of the lock record (override with [MemoryLockVault] in
/// tests).
final lockVaultProvider = Provider<LockVault>((ref) => SecretLockVault());

/// The first-frame hint in SharedPreferences.
final lockHintStoreProvider = Provider<LockHintStore>(
  (ref) => PrefsLockHintStore(ref.watch(sharedPreferencesProvider)),
);

/// Fingerprint / face unlock (override with a fake in tests).
final biometricAuthProvider = Provider<BiometricAuth>((ref) => LocalAuthBiometricAuth());

/// PIN hashing (tests use fewer iterations and an inline runner).
final pinHasherProvider = Provider<PinHasher>((ref) => PinHasher());

/// Wall clock of the lock (background time-out and back-off).
final lockClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Whether biometrics can be used right now. Invalidate it when the app
/// returns to the foreground (the owner may have enrolled a finger).
final biometricAvailabilityProvider = FutureProvider<BiometricAvailability>(
  (ref) => ref.watch(biometricAuthProvider).availability(),
  retry: (_, _) => null,
);

/// The app lock.
final lockControllerProvider = NotifierProvider<LockController, AppLockState>(LockController.new);

/// Exempt pages showing above the lock right now: see `LockExempt`.
final lockExemptionsProvider = NotifierProvider<LockExemptions, int>(LockExemptions.new);

/// Exempt routes still coming in or going out while the app is locked: the
/// gate lets the hidden app tick (offstage) until they are through.
final lockExemptTransitionsProvider = NotifierProvider<LockExemptions, int>(LockExemptions.new);

/// Counts `LockExempt` holders.
class LockExemptions extends Notifier<int> {
  @override
  int build() => 0;

  void hold() => state = state + 1;

  void release() {
    if (state > 0) state = state - 1;
  }
}

// --------------------------------------------------------------------- state

/// Result of checking a PIN.
enum PinCheck {
  accepted,
  wrong,

  /// Too many wrong PINs: wait for [PinCheckResult.lockout].
  lockedOut,

  /// The stored hash could not be read (secure storage failed) or no PIN is
  /// set.
  unavailable,

  /// Another check is still running.
  busy,
}

@immutable
class PinCheckResult {
  const PinCheckResult(this.check, {this.remaining = 0, this.lockout = Duration.zero});

  final PinCheck check;

  /// Wrong PINs left before the next lockout.
  final int remaining;

  /// How long the keypad stays locked.
  final Duration lockout;

  bool get accepted => check == PinCheck.accepted;
}

/// What the lock gate, the lock screen and the security settings render.
@immutable
class AppLockState {
  const AppLockState({
    this.phase = LockPhase.open,
    this.shielded = false,
    this.enabled = true,
    this.lockAfter = const Duration(minutes: 2),
    this.hasPin = false,
    this.pinLength = PinRules.minLength,
    this.biometrics = false,
    this.loaded = false,
    this.storageError = false,
    this.failures = 0,
    this.lockedUntil,
  });

  final LockPhase phase;

  /// The privacy cover over an open app (recents / notification shade).
  final bool shielded;

  /// Settings › Security › App lock.
  final bool enabled;
  final Duration lockAfter;

  /// A PIN is set (the lock's root credential).
  final bool hasPin;
  final int pinLength;

  /// Fingerprint unlock switched on.
  final bool biometrics;

  /// The secure record has been read.
  final bool loaded;

  /// Reading or writing secure storage failed.
  final bool storageError;
  final int failures;
  final DateTime? lockedUntil;

  /// The lock is active: enabled and a PIN exists.
  bool get armed => enabled && hasPin;

  /// The lock screen is (still) on top of the app.
  bool get covered => phase != LockPhase.open;

  AppLockState copyWith({
    LockPhase? phase,
    bool? shielded,
    bool? enabled,
    Duration? lockAfter,
    bool? hasPin,
    int? pinLength,
    bool? biometrics,
    bool? loaded,
    bool? storageError,
    int? failures,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
  }) => AppLockState(
    phase: phase ?? this.phase,
    shielded: shielded ?? this.shielded,
    enabled: enabled ?? this.enabled,
    lockAfter: lockAfter ?? this.lockAfter,
    hasPin: hasPin ?? this.hasPin,
    pinLength: pinLength ?? this.pinLength,
    biometrics: biometrics ?? this.biometrics,
    loaded: loaded ?? this.loaded,
    storageError: storageError ?? this.storageError,
    failures: failures ?? this.failures,
    lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
  );

  @override
  bool operator ==(Object other) =>
      other is AppLockState &&
      other.phase == phase &&
      other.shielded == shielded &&
      other.enabled == enabled &&
      other.lockAfter == lockAfter &&
      other.hasPin == hasPin &&
      other.pinLength == pinLength &&
      other.biometrics == biometrics &&
      other.loaded == loaded &&
      other.storageError == storageError &&
      other.failures == failures &&
      other.lockedUntil == lockedUntil;

  @override
  int get hashCode => Object.hash(
    phase,
    shielded,
    enabled,
    lockAfter,
    hasPin,
    pinLength,
    biometrics,
    loaded,
    storageError,
    failures,
    lockedUntil,
  );

  @override
  String toString() => 'AppLockState($phase, armed: $armed, shielded: $shielded, pin: $hasPin, bio: $biometrics)';
}

// ---------------------------------------------------------------- controller

/// The app lock: drives [LockSession] from lifecycle events, verifies the
/// PIN (salted PBKDF2 in secure storage, exponential back-off) and
/// biometrics, and changes the lock's configuration.
///
/// Built once per app run. The first frame is decided synchronously from
/// the settings and the [LockHint]; the secure record is read right after
/// (only when a lock is configured) and reconciles the hint.
class LockController extends Notifier<AppLockState> {
  late LockSession _session;
  LockRecord? _record;
  Future<LockRecord?>? _loading;
  bool _checking = false;

  LockVault get _vault => ref.read(lockVaultProvider);
  PinHasher get _hasher => ref.read(pinHasherProvider);
  DateTime _now() => ref.read(lockClockProvider)();

  @override
  AppLockState build() {
    final settings = ref.read(appSettingsProvider);
    final hint = ref.read(lockHintStoreProvider).read();
    _session = LockSession(
      clock: ref.read(lockClockProvider),
      armed: settings.lockEnabled && hint.pin,
      lockAfter: Duration(seconds: settings.lockAfterSeconds),
    )..coldStart();
    ref.listen(appSettingsProvider.select((s) => (s.lockEnabled, s.lockAfterSeconds)), (_, next) {
      _session.lockAfter = Duration(seconds: next.$2);
      state = state.copyWith(enabled: next.$1, lockAfter: _session.lockAfter);
      _syncArmed();
    });
    final initial = AppLockState(
      phase: _session.phase,
      enabled: settings.lockEnabled,
      lockAfter: _session.lockAfter,
      hasPin: hint.pin,
      biometrics: hint.biometrics,
    );
    if (hint.pin) scheduleMicrotask(() => unawaited(load()));
    return initial;
  }

  // ------------------------------------------------------------------ record

  /// Reads the secure record (once; again after a storage error).
  Future<LockRecord?> load() {
    final pending = _loading;
    if (pending != null) return pending;
    return _loading = _read();
  }

  Future<LockRecord?> _read() async {
    try {
      final stored = await _vault.read();
      if (!ref.mounted) return null;
      final record = stored.normalizedAt(_now());
      _record = record;
      final wasArmed = _session.armed;
      state = _withRecord(state.copyWith(loaded: true, storageError: false), record);
      if (record != stored) unawaited(_vault.write(record).catchError((Object _) {}));
      // A PIN the first frame did not know about (the hint was lost or
      // never written) was never unlocked in this run: when in doubt, lock.
      _syncArmed(lockIfArming: !wasArmed);
      // The hint only speeds up the next launch; the record decides.
      await _saveHintQuietly(record);
      return record;
    } catch (e) {
      if (kDebugMode) debugPrint('Madar lock: secure storage read failed: $e');
      if (!ref.mounted) return null;
      _loading = null;
      state = state.copyWith(loaded: true, storageError: true);
      return null;
    }
  }

  AppLockState _withRecord(AppLockState s, LockRecord r) => s.copyWith(
    hasPin: r.hasPin,
    pinLength: r.pin?.length ?? PinRules.minLength,
    biometrics: r.biometrics && r.hasPin,
    failures: r.failures,
    lockedUntil: r.lockedUntil,
    clearLockedUntil: r.lockedUntil == null,
  );

  /// Stores [record]. The first-frame hint is never allowed to be weaker
  /// than the vault: a new PIN is announced in the hint *before* it is
  /// stored (and the announcement withdrawn if storing fails), and a removed
  /// PIN leaves the hint only after it has left the vault. A crash between
  /// the two writes therefore costs at most one needless lock screen – never
  /// an unlocked launch with a PIN in the vault.
  Future<void> _save(LockRecord record) async {
    final store = ref.read(lockHintStoreProvider);
    final before = store.read();
    final announce = record.hasPin && !before.pin;
    if (announce) await store.write(LockHint.of(record));
    try {
      await _vault.write(record);
    } catch (_) {
      if (announce) {
        try {
          await store.write(before);
        } catch (_) {
          // A stale "PIN" hint only shows one lock screen that disarms itself.
        }
      }
      rethrow;
    }
    _record = record;
    if (!ref.mounted) return;
    state = _withRecord(state.copyWith(storageError: false), record);
    _syncArmed();
    await _saveHintQuietly(record);
  }

  Future<void> _saveHint(LockRecord record) async {
    final store = ref.read(lockHintStoreProvider);
    final hint = LockHint.of(record);
    if (store.read() != hint) await store.write(hint);
  }

  /// Hint updates that can only make it weaker than or equal to the vault
  /// (a removed PIN, the fingerprint flag): a failure leaves the safe side.
  Future<void> _saveHintQuietly(LockRecord record) async {
    try {
      await _saveHint(record);
    } catch (e) {
      if (kDebugMode) debugPrint('Madar lock: hint not saved: $e');
    }
  }

  /// Keeps the session's armed flag in step with settings + record. With
  /// [lockIfArming] a lock that becomes armed also locks at once.
  void _syncArmed({bool lockIfArming = false}) {
    final armed = state.armed;
    if (armed != _session.armed) _session.setArmed(armed, lockNow: armed && lockIfArming);
    _publish();
  }

  /// Re-anchors a lockout the wall clock stretched (see
  /// [LockRecord.normalizedAt]). The lock screen and the PIN sheets call it
  /// while they count down; it also runs on every return to the app.
  void refreshLockout() {
    final record = _record;
    if (record == null || record.lockedUntil == null) return;
    final next = record.normalizedAt(_now());
    if (next == record) return;
    unawaited(_trySave(next));
  }

  void _publish() {
    if (!ref.mounted) return;
    state = state.copyWith(phase: _session.phase, shielded: _session.shielded);
  }

  // --------------------------------------------------------------- lifecycle

  /// Feeds an app lifecycle change (the gate's `AppLifecycleListener`).
  void onLifecycle(AppLifecycleState lifecycle) {
    _session.onLifecycle(lifecycle);
    _publish();
    if (lifecycle == AppLifecycleState.resumed) refreshLockout();
  }

  /// Locks now (when armed).
  void lockNow() {
    _session.lock();
    _publish();
  }

  /// Opens the lock after the owner proved themselves another way (the
  /// lock screen's "forgot PIN" reset: fingerprint, then a new PIN).
  void unlockVerified() {
    _session.authenticated();
    _publish();
  }

  /// The lock screen finished its opening animation.
  void revealed() {
    _session.revealed();
    _publish();
  }

  /// Runs [action] (a file picker, a permission screen, a share sheet the
  /// app opened itself) without the privacy shield or the time-out lock.
  Future<T> whileSuspended<T>(Future<T> Function() action) async {
    _session.suspend();
    try {
      return await action();
    } finally {
      _session.unsuspend();
    }
  }

  // ------------------------------------------------------------------ unlock

  /// Checks [pin]. With [unlock] a correct PIN opens the lock screen;
  /// without it the check only confirms the owner (settings flows). Wrong
  /// PINs count towards the back-off either way.
  Future<PinCheckResult> checkPin(String pin, {bool unlock = true}) async {
    if (_checking) return const PinCheckResult(PinCheck.busy);
    _checking = true;
    try {
      final loaded = _record ?? await load();
      if (loaded == null || loaded.pin == null) return const PinCheckResult(PinCheck.unavailable);
      final now = _now();
      final record = loaded.normalizedAt(now);
      if (record != loaded) await _trySave(record);
      if (record.lockedOutAt(now)) {
        return PinCheckResult(PinCheck.lockedOut, lockout: record.remainingLockout(now));
      }
      final stored = record.pin!;
      final ok = await _hasher.verify(pin, stored);
      if (!ref.mounted) return const PinCheckResult(PinCheck.unavailable);
      if (ok) {
        var next = record.afterSuccess();
        if (_hasher.needsRehash(stored)) next = next.copyWith(pin: await _hasher.hash(pin));
        if (next != record) await _trySave(next);
        if (unlock) {
          _session.authenticated();
          _publish();
        }
        return const PinCheckResult(PinCheck.accepted);
      }
      final next = record.afterFailure(_now());
      await _trySave(next);
      final wait = next.remainingLockout(_now());
      if (wait > Duration.zero) return PinCheckResult(PinCheck.lockedOut, lockout: wait);
      return PinCheckResult(PinCheck.wrong, remaining: PinBackoff.remainingBeforeLockout(next.failures));
    } finally {
      _checking = false;
    }
  }

  Future<void> _trySave(LockRecord record) async {
    try {
      await _save(record);
    } catch (e) {
      // Keep the in-memory counter even when storage fails.
      _record = record;
      if (ref.mounted) state = _withRecord(state.copyWith(storageError: true), record);
    }
  }

  /// Shows the biometric prompt. On success with [unlock] the lock screen
  /// opens; a success also clears the wrong-PIN counter.
  ///
  /// Only while fingerprint unlock is switched on (the stored record
  /// decides; the first-frame hint only while secure storage can't be read)
  /// – otherwise no prompt is shown and [BiometricOutcome.disabled] comes
  /// back. [enrolling] is the one exception: the scan that switches it on
  /// in Settings (the owner is already inside the unlocked app).
  Future<BiometricOutcome> authenticateWithBiometrics(
    BiometricPromptText text, {
    bool unlock = true,
    bool enrolling = false,
  }) async {
    _session.suspend();
    try {
      if (!enrolling) {
        final record = _record ?? await load();
        if (!ref.mounted) return BiometricOutcome.disabled;
        final enabled = record != null ? record.biometrics && record.hasPin : state.biometrics;
        if (!enabled) return BiometricOutcome.disabled;
      }
      final outcome = await ref.read(biometricAuthProvider).authenticate(text);
      if (!ref.mounted) return outcome;
      if (outcome == BiometricOutcome.success) {
        final record = _record ?? await load();
        if (record != null && (record.failures > 0 || record.lockedUntil != null)) {
          await _trySave(record.afterSuccess());
        }
        if (unlock) _session.authenticated();
      }
      return outcome;
    } finally {
      _session.unsuspend();
      _publish();
    }
  }

  // ----------------------------------------------------------- configuration

  /// Sets a new PIN (first PIN, change, or reset after "forgot PIN") and
  /// turns the lock on. [biometrics] also switches fingerprint unlock.
  Future<void> setPin(String pin, {bool? biometrics}) async {
    final record = _record ?? await load() ?? LockRecord.empty;
    final hash = await _hasher.hash(pin);
    await _save(record.copyWith(pin: hash, biometrics: biometrics).afterSuccess());
    await _setEnabled(true);
  }

  /// Switches fingerprint unlock (the caller has authenticated).
  Future<void> setBiometrics(bool on) async {
    final record = _record ?? await load();
    if (record == null) throw StateError('secure storage unavailable');
    await _save(record.copyWith(biometrics: on && record.hasPin));
  }

  /// Removes the PIN (and with it fingerprint unlock): the lock is off.
  Future<void> removePin() async {
    await _vault.clear();
    _record = LockRecord.empty;
    if (ref.mounted) {
      state = _withRecord(state, LockRecord.empty);
      _syncArmed();
    }
    await _saveHintQuietly(LockRecord.empty);
  }

  /// Turns the lock on or off (the caller has authenticated). Turning it on
  /// needs a PIN ([setPin] does both).
  Future<void> setEnabled(bool on) async {
    if (on && !state.hasPin) throw StateError('set a PIN first');
    await _setEnabled(on);
  }

  Future<void> _setEnabled(bool on) async {
    if (ref.read(appSettingsProvider).lockEnabled == on) return;
    await ref.read(appSettingsProvider.notifier).update((s) => s.copyWith(lockEnabled: on));
  }

  /// "Lock after" in Settings (0 = immediately).
  Future<void> setLockAfter(Duration after) =>
      ref.read(appSettingsProvider.notifier).update((s) => s.copyWith(lockAfterSeconds: after.inSeconds));
}

/// "Lock after" choices offered in Settings (0 = immediately).
const List<Duration> lockAfterChoices = [
  Duration.zero,
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
  Duration(minutes: 15),
];
