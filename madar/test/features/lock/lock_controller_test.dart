import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/lock/application/lock_controller.dart';
import 'package:madar/features/lock/data/biometric_auth.dart';
import 'package:madar/features/lock/domain/lock_record.dart';
import 'package:madar/features/lock/domain/lock_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lock_test_utils.dart';

const _prompt = BiometricPromptText(reason: 'r', title: 't', hint: 'h', cancel: 'c');

/// A container whose lock controller is already built (as on the app's
/// first frame).
Future<ProviderContainer> _container(LockFixture fx, {AppSettings settings = const AppSettings()}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs), ...fx.overrides]);
  await c.read(appSettingsProvider.notifier).update((_) => settings);
  addTearDown(c.dispose);
  c.read(lockControllerProvider);
  return c;
}

/// Lets the post-build vault read finish.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('fresh install: no lock, nothing read from secure storage', () async {
    final fx = LockFixture.empty();
    fx.vault.failWith = StateError('must not be read');
    final c = await _container(fx);
    final s = c.read(lockControllerProvider);
    await _settle();
    expect(s.phase, LockPhase.open);
    expect(s.armed, isFalse);
    expect(c.read(lockControllerProvider).storageError, isFalse);
  });

  test('configured: the first frame is already locked; the record loads', () async {
    final fx = await LockFixture.configured(pin: '482915');
    final c = await _container(fx);
    expect(c.read(lockControllerProvider).phase, LockPhase.locked);
    await _settle();
    final s = c.read(lockControllerProvider);
    expect(s.loaded, isTrue);
    expect(s.pinLength, 6);
    expect(s.biometrics, isTrue);
  });

  test('lock disabled in settings: never locks even with a PIN', () async {
    final fx = await LockFixture.configured();
    final c = await _container(fx, settings: const AppSettings(lockEnabled: false));
    expect(c.read(lockControllerProvider).phase, LockPhase.open);
  });

  test('a stale hint (data wiped) disarms once the empty vault is read', () async {
    final fx = await LockFixture.configured();
    fx.vault.record = LockRecord.empty;
    final c = await _container(fx);
    expect(c.read(lockControllerProvider).phase, LockPhase.locked);
    await _settle();
    expect(c.read(lockControllerProvider).phase, LockPhase.open);
    expect(fx.hint.hint, LockHint.none);
  });

  test('correct PIN unlocks (revealing → open)', () async {
    final fx = await LockFixture.configured();
    final c = await _container(fx);
    final r = await c.read(lockControllerProvider.notifier).checkPin('2580');
    expect(r.accepted, isTrue);
    expect(c.read(lockControllerProvider).phase, LockPhase.revealing);
    c.read(lockControllerProvider.notifier).revealed();
    expect(c.read(lockControllerProvider).phase, LockPhase.open);
  });

  test('wrong PINs: counted, locked out from the fifth, persisted, reset by success', () async {
    final fx = await LockFixture.configured();
    final c = await _container(fx);
    final lock = c.read(lockControllerProvider.notifier);
    for (var i = 1; i <= 4; i++) {
      final r = await lock.checkPin('0000');
      expect(r.check, PinCheck.wrong);
      expect(r.remaining, 5 - i);
    }
    final fifth = await lock.checkPin('0000');
    expect(fifth.check, PinCheck.lockedOut);
    expect(fifth.lockout, const Duration(seconds: 30));
    expect(fx.vault.record.failures, 5, reason: 'the counter survives a restart');
    // Even the right PIN is refused during the lockout.
    expect((await lock.checkPin('2580')).check, PinCheck.lockedOut);
    fx.clock.advance(const Duration(seconds: 31));
    final sixth = await lock.checkPin('1111');
    expect(sixth.check, PinCheck.lockedOut);
    expect(sixth.lockout, const Duration(minutes: 1));
    fx.clock.advance(const Duration(minutes: 1, seconds: 1));
    expect((await lock.checkPin('2580')).accepted, isTrue);
    expect(fx.vault.record.failures, 0);
    expect(fx.vault.record.lockedUntil, isNull);
  });

  test('a restart keeps the lockout', () async {
    final now = DateTime(2026, 9, 28, 21, 40);
    final fx = await LockFixture.configured(failures: 6, lockedUntil: now.add(const Duration(seconds: 40)), now: now);
    final c = await _container(fx);
    await _settle();
    expect(c.read(lockControllerProvider).lockedUntil, now.add(const Duration(seconds: 40)));
    expect((await c.read(lockControllerProvider.notifier).checkPin('2580')).check, PinCheck.lockedOut);
  });

  test('checking without unlocking (settings) never opens the lock', () async {
    final fx = await LockFixture.configured();
    final c = await _container(fx);
    expect((await c.read(lockControllerProvider.notifier).checkPin('2580', unlock: false)).accepted, isTrue);
    expect(c.read(lockControllerProvider).phase, LockPhase.locked);
  });

  test('fingerprint success unlocks and clears the wrong-PIN counter', () async {
    final fx = await LockFixture.configured(failures: 3);
    final c = await _container(fx);
    await _settle();
    final outcome = await c.read(lockControllerProvider.notifier).authenticateWithBiometrics(_prompt);
    expect(outcome, BiometricOutcome.success);
    expect(c.read(lockControllerProvider).phase, LockPhase.revealing);
    expect(fx.vault.record.failures, 0);
    expect(fx.bio.prompts.single.reason, 'r');
  });

  test('fingerprint failures keep the lock', () async {
    for (final o in [BiometricOutcome.cancelled, BiometricOutcome.lockedOut, BiometricOutcome.error]) {
      final fx = await LockFixture.configured();
      fx.bio.fallback = o;
      final c = await _container(fx);
      expect(await c.read(lockControllerProvider.notifier).authenticateWithBiometrics(_prompt), o);
      expect(c.read(lockControllerProvider).phase, LockPhase.locked);
    }
  });

  test('never two prompts at once: a request while one is up is turned away', () async {
    final fx = await LockFixture.configured();
    fx.bio.holdPrompt = true;
    final c = await _container(fx);
    await _settle();
    final lock = c.read(lockControllerProvider.notifier);
    final first = lock.authenticateWithBiometrics(_prompt);
    await _settle();
    expect(fx.bio.prompts, hasLength(1));
    expect(lock.prompting, isTrue);
    expect(await lock.authenticateWithBiometrics(_prompt), BiometricOutcome.interrupted);
    expect(fx.bio.prompts, hasLength(1), reason: 'the plugin is never asked twice');
    fx.bio.finish(BiometricOutcome.success);
    expect(await first, BiometricOutcome.success);
    expect(lock.prompting, isFalse);
    expect(c.read(lockControllerProvider).phase, LockPhase.revealing);
    // Free again afterwards.
    fx.bio.holdPrompt = false;
    expect(await lock.authenticateWithBiometrics(_prompt, unlock: false), BiometricOutcome.success);
    expect(fx.bio.prompts, hasLength(2));
  });

  test('background time-out through the controller (fake clock + lifecycle)', () async {
    final fx = await LockFixture.configured();
    final c = await _container(fx);
    final lock = c.read(lockControllerProvider.notifier);
    await lock.checkPin('2580');
    lock.revealed();
    void cycle(Duration away) {
      lock
        ..onLifecycle(AppLifecycleState.inactive)
        ..onLifecycle(AppLifecycleState.hidden);
      expect(c.read(lockControllerProvider).shielded, isTrue);
      fx.clock.advance(away);
      lock
        ..onLifecycle(AppLifecycleState.inactive)
        ..onLifecycle(AppLifecycleState.resumed);
    }

    cycle(const Duration(seconds: 90));
    expect(c.read(lockControllerProvider).phase, LockPhase.open);
    expect(c.read(lockControllerProvider).shielded, isFalse);
    cycle(const Duration(minutes: 2));
    expect(c.read(lockControllerProvider).phase, LockPhase.locked);
  });

  test('"lock after" follows the settings live', () async {
    final fx = await LockFixture.configured();
    final c = await _container(fx);
    final lock = c.read(lockControllerProvider.notifier);
    await lock.checkPin('2580');
    lock.revealed();
    await lock.setLockAfter(const Duration(minutes: 15));
    expect(c.read(appSettingsProvider).lockAfterSeconds, 900);
    expect(c.read(lockControllerProvider).lockAfter, const Duration(minutes: 15));
    lock.onLifecycle(AppLifecycleState.hidden);
    fx.clock.advance(const Duration(minutes: 10));
    lock.onLifecycle(AppLifecycleState.resumed);
    expect(c.read(lockControllerProvider).phase, LockPhase.open);
  });

  test('whileSuspended: an own prompt / picker never locks or shields', () async {
    final fx = await LockFixture.configured();
    final c = await _container(fx, settings: const AppSettings(lockAfterSeconds: 0));
    final lock = c.read(lockControllerProvider.notifier);
    await lock.checkPin('2580');
    lock.revealed();
    await lock.whileSuspended(() async {
      lock.onLifecycle(AppLifecycleState.hidden);
      expect(c.read(lockControllerProvider).shielded, isFalse);
      fx.clock.advance(const Duration(minutes: 3));
      lock.onLifecycle(AppLifecycleState.resumed);
    });
    expect(c.read(lockControllerProvider).phase, LockPhase.open);
  });

  test('setPin arms the lock without locking; the hint follows; never plaintext', () async {
    final fx = LockFixture.empty();
    final c = await _container(fx);
    final lock = c.read(lockControllerProvider.notifier);
    await lock.setPin('1397', biometrics: true);
    final s = c.read(lockControllerProvider);
    expect(s.armed, isTrue);
    expect(s.phase, LockPhase.open, reason: 'the owner is here');
    expect(s.biometrics, isTrue);
    expect(fx.hint.hint, const LockHint(pin: true, biometrics: true));
    expect(fx.vault.record.encode(), isNot(contains('1397')));
    // Next launch is locked.
    final c2 = await _container(fx);
    expect(c2.read(lockControllerProvider).phase, LockPhase.locked);
  });

  test('setPin also re-enables a lock that was switched off', () async {
    final fx = await LockFixture.configured();
    final c = await _container(fx, settings: const AppSettings(lockEnabled: false));
    await c.read(lockControllerProvider.notifier).setPin('8642');
    expect(c.read(appSettingsProvider).lockEnabled, isTrue);
    expect(c.read(lockControllerProvider).armed, isTrue);
  });

  test('switching off keeps the PIN; switching on needs one', () async {
    final fx = await LockFixture.configured();
    final c = await _container(fx);
    await _settle();
    final lock = c.read(lockControllerProvider.notifier);
    await lock.setEnabled(false);
    expect(c.read(lockControllerProvider).phase, LockPhase.open);
    expect(c.read(lockControllerProvider).hasPin, isTrue);
    await lock.setEnabled(true);
    expect(c.read(lockControllerProvider).armed, isTrue);

    final empty = await _container(LockFixture.empty());
    expect(() => empty.read(lockControllerProvider.notifier).setEnabled(true), throwsStateError);
  });

  test('disabling fingerprint keeps the PIN; removing the PIN disarms', () async {
    final fx = await LockFixture.configured();
    final c = await _container(fx);
    await _settle();
    final lock = c.read(lockControllerProvider.notifier);
    await lock.setBiometrics(false);
    expect(c.read(lockControllerProvider).biometrics, isFalse);
    expect(c.read(lockControllerProvider).hasPin, isTrue);
    expect(fx.hint.hint, const LockHint(pin: true));
    await lock.removePin();
    expect(c.read(lockControllerProvider).armed, isFalse);
    expect(c.read(lockControllerProvider).phase, LockPhase.open);
    expect(fx.vault.record, LockRecord.empty);
    expect(fx.hint.hint, LockHint.none);
  });

  test('secure storage failing: PIN unavailable, fingerprint still works', () async {
    final fx = await LockFixture.configured();
    fx.vault.failWith = StateError('keystore');
    final c = await _container(fx);
    await _settle();
    expect(c.read(lockControllerProvider).storageError, isTrue);
    expect(c.read(lockControllerProvider).phase, LockPhase.locked);
    expect((await c.read(lockControllerProvider.notifier).checkPin('2580')).check, PinCheck.unavailable);
    expect(await c.read(lockControllerProvider.notifier).authenticateWithBiometrics(_prompt), BiometricOutcome.success);
    // Retry once storage is back.
    fx.vault.failWith = null;
    await c.read(lockControllerProvider.notifier).load();
    expect(c.read(lockControllerProvider).storageError, isFalse);
  });

  test('unlockVerified (forgot-PIN reset) opens the lock', () async {
    final fx = await LockFixture.configured();
    final c = await _container(fx);
    c.read(lockControllerProvider.notifier).unlockVerified();
    expect(c.read(lockControllerProvider).phase, LockPhase.revealing);
  });

  test('exemptions count holders', () async {
    final c = await _container(LockFixture.empty());
    final e = c.read(lockExemptionsProvider.notifier);
    e
      ..hold()
      ..hold()
      ..release();
    expect(c.read(lockExemptionsProvider), 1);
    e
      ..release()
      ..release();
    expect(c.read(lockExemptionsProvider), 0);
  });
}
