// Regression tests from the adversarial review of the app lock: each one
// pins down a defect that was found (and fixed) in the first version.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/widgets/ambient_motion.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/lock/application/lock_controller.dart';
import 'package:madar/features/lock/data/biometric_auth.dart';
import 'package:madar/features/lock/data/lock_vault.dart';
import 'package:madar/features/lock/domain/lock_record.dart';
import 'package:madar/features/lock/domain/lock_session.dart';
import 'package:madar/features/lock/presentation/lock_gate_host.dart';
import 'package:madar/features/lock/presentation/lock_screen.dart';
import 'package:madar/features/lock/presentation/pin_pad.dart';
import 'package:madar/features/lock/presentation/pin_sheets.dart';
import 'package:madar/features/lock/render/lock_astrolabe.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart' show RecordingHaptics, usePhoneSurface;
import 'lock_test_utils.dart';

const _prompt = BiometricPromptText(reason: 'r', title: 't', hint: 'h', cancel: 'c');

/// A hint store whose writes fail (the process dies / the disk is full
/// between the two writes of a PIN change).
class _FailingHintStore extends MemoryLockHintStore {
  _FailingHintStore();

  bool fail = true;

  @override
  Future<void> write(LockHint hint) async {
    if (fail) throw StateError('killed');
    await super.write(hint);
  }
}

Future<ProviderContainer> _container(LockFixture fx, {AppSettings settings = const AppSettings()}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs), ...fx.overrides]);
  await c.read(appSettingsProvider.notifier).update((_) => settings);
  addTearDown(c.dispose);
  c.read(lockControllerProvider);
  return c;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('home')));
}

Future<ProviderContainer> _pumpGate(WidgetTester tester, LockFixture fx, {Widget home = const _Home()}) async {
  usePhoneSurface(tester);
  Fx.install(FeedbackService(SilentSoundService(), RecordingHaptics()));
  final prefs = await settingsPrefs(tester, const AppSettings(onboarded: true));
  await tester.pumpWidget(
    lockTestApp(
      prefs: prefs,
      overrides: fx.overrides,
      home: home,
      builder: (context, child) => LockGateHost(child: child!),
    ),
  );
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(LockGateHost)));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('time-out', () {
    test('an app-opened flow left open for long still locks on return', () {
      var now = DateTime(2026, 9, 28, 12);
      final s = LockSession(clock: () => now, armed: true, lockAfter: const Duration(minutes: 2))..coldStart();
      s.authenticated();
      s.revealed();
      // A file picker / the fingerprint prompt from Settings (sticky across
      // backgrounding) is open when the owner walks away for an hour.
      s.suspend();
      s.onLifecycle(AppLifecycleState.inactive);
      s.onLifecycle(AppLifecycleState.hidden);
      s.onLifecycle(AppLifecycleState.paused);
      now = now.add(const Duration(hours: 1));
      s.onLifecycle(AppLifecycleState.inactive);
      s.onLifecycle(AppLifecycleState.resumed);
      expect(s.phase, LockPhase.locked);
    });

    test('a short trip into an app-opened flow never locks, even with "immediately"', () {
      var now = DateTime(2026, 9, 28, 12);
      final s = LockSession(clock: () => now, armed: true, lockAfter: Duration.zero)..coldStart();
      s
        ..authenticated()
        ..revealed()
        ..suspend()
        ..onLifecycle(AppLifecycleState.hidden);
      expect(s.shielded, isFalse);
      now = now.add(const Duration(minutes: 4));
      s
        ..onLifecycle(AppLifecycleState.resumed)
        ..unsuspend();
      expect(s.phase, LockPhase.open);
    });

    test('a flow whose result arrives just before "resumed" keeps its grace, but only up to it', () {
      var now = DateTime(2026, 9, 28, 12);
      final s = LockSession(clock: () => now, armed: true, lockAfter: const Duration(minutes: 2))..coldStart();
      s
        ..authenticated()
        ..revealed()
        ..suspend()
        ..onLifecycle(AppLifecycleState.hidden);
      now = now.add(const Duration(minutes: 3));
      // The picked file is delivered before the activity resumes.
      s
        ..unsuspend()
        ..onLifecycle(AppLifecycleState.resumed);
      expect(s.phase, LockPhase.open, reason: 'a 3-minute file pick is not "leaving the app"');
      s
        ..suspend()
        ..onLifecycle(AppLifecycleState.hidden);
      now = now.add(LockSession.suspendedGrace);
      s
        ..unsuspend()
        ..onLifecycle(AppLifecycleState.resumed);
      expect(s.phase, LockPhase.locked);
    });
  });

  group('first-frame hint', () {
    test('a PIN write interrupted before the hint never leaves an unlocked launch', () async {
      final base = LockFixture.empty();
      final hint = _FailingHintStore();
      final fx = LockFixture(vault: base.vault, hint: hint, bio: base.bio, clock: base.clock);
      final c = await _container(fx);
      await expectLater(c.read(lockControllerProvider.notifier).setPin('2580'), throwsStateError);
      // Relaunch with whatever reached storage.
      hint.fail = false;
      final c2 = await _container(fx);
      await _settle();
      if (fx.vault.record.hasPin) {
        expect(c2.read(lockControllerProvider).phase, LockPhase.locked, reason: 'a stored PIN must lock');
      } else {
        expect(c2.read(lockControllerProvider).armed, isFalse);
      }
    });

    test('a vault write failure rolls the hint back (no phantom lock screen)', () async {
      final fx = LockFixture.empty();
      final c = await _container(fx);
      await c.read(lockControllerProvider.notifier).load();
      fx.vault.failWith = StateError('keystore');
      await expectLater(c.read(lockControllerProvider.notifier).setPin('2580'), throwsStateError);
      expect(fx.hint.hint, LockHint.none);
    });

    test('a stored PIN the hint did not know about locks as soon as it is read', () async {
      final fx = await LockFixture.configured();
      fx.hint.hint = LockHint.none; // e.g. preferences restored / lost
      final c = await _container(fx);
      expect(c.read(lockControllerProvider).phase, LockPhase.open);
      await c.read(lockControllerProvider.notifier).load();
      expect(c.read(lockControllerProvider).phase, LockPhase.locked);
      expect(fx.hint.hint.pin, isTrue);
    });
  });

  group('fingerprint', () {
    test('fingerprint never unlocks when the owner switched it off', () async {
      final fx = await LockFixture.configured(biometrics: false);
      fx.hint.hint = const LockHint(pin: true, biometrics: true); // stale
      final c = await _container(fx);
      final outcome = await c.read(lockControllerProvider.notifier).authenticateWithBiometrics(_prompt);
      expect(outcome, isNot(BiometricOutcome.success));
      expect(c.read(lockControllerProvider).phase, LockPhase.locked);
      expect(fx.bio.prompts, isEmpty, reason: 'no prompt for a switched-off method');
    });

    test('enrolling fingerprint in Settings still scans while it is off', () async {
      final fx = await LockFixture.configured(biometrics: false);
      final c = await _container(fx);
      final outcome = await c
          .read(lockControllerProvider.notifier)
          .authenticateWithBiometrics(_prompt, unlock: false, enrolling: true);
      expect(outcome, BiometricOutcome.success);
      expect(fx.bio.prompts, hasLength(1));
    });
  });

  group('back-off and the wall clock', () {
    test('a clock that jumped backwards never stretches a lockout', () async {
      final now = DateTime(2026, 9, 28, 21, 40);
      // Locked out for 30 s … then the clock is corrected back by a day.
      final fx = await LockFixture.configured(
        failures: 5,
        lockedUntil: now.add(const Duration(seconds: 30)),
        now: now.subtract(const Duration(days: 1)),
      );
      final c = await _container(fx);
      await _settle();
      final r = await c.read(lockControllerProvider.notifier).checkPin('2580');
      expect(r.check, PinCheck.lockedOut);
      expect(r.lockout, lessThanOrEqualTo(PinBackoff.lockoutAfter(5)));
      fx.clock.advance(const Duration(seconds: 31));
      expect((await c.read(lockControllerProvider.notifier).checkPin('2580')).accepted, isTrue);
    });

    test('returning to the app re-anchors a lockout the clock stretched', () async {
      final now = DateTime(2026, 9, 28, 21, 40);
      final fx = await LockFixture.configured(
        failures: 5,
        lockedUntil: now.add(const Duration(seconds: 20)),
        now: now,
      );
      final c = await _container(fx);
      await _settle();
      // The network corrects the clock back by five hours while away.
      fx.clock.now = now.subtract(const Duration(hours: 5));
      c.read(lockControllerProvider.notifier).onLifecycle(AppLifecycleState.resumed);
      await _settle();
      final expected = fx.clock.now.add(PinBackoff.lockoutAfter(5));
      expect(c.read(lockControllerProvider).lockedUntil, expected);
      expect(fx.vault.record.lockedUntil, expected, reason: 'persisted');
    });

    test('LockRecord.normalizedAt re-anchors only a stretched lockout', () {
      final now = DateTime(2026, 9, 28, 12);
      final ok = LockRecord(failures: 5, lockedUntil: now.add(const Duration(seconds: 20)));
      expect(ok.normalizedAt(now), ok);
      final skewed = LockRecord(failures: 6, lockedUntil: now.add(const Duration(days: 3)));
      expect(skewed.normalizedAt(now).lockedUntil, now.add(const Duration(minutes: 1)));
      final stray = LockRecord(failures: 2, lockedUntil: now.add(const Duration(minutes: 5)));
      expect(stray.normalizedAt(now).lockedUntil, isNull);
    });
  });

  group('widgets', () {
    testWidgets('closing an exempt screen never shows the locked app, not even mid-transition', (tester) async {
      final fx = await LockFixture.configured(biometrics: false);
      await _pumpGate(tester, fx);
      final nav = tester.state<NavigatorState>(find.byType(Navigator, skipOffstage: false));
      nav.push(MaterialPageRoute<void>(builder: (_) => const LockExempt(child: Scaffold(body: Text('adhan')))));
      await tester.pumpAndSettle();
      expect(find.text('adhan'), findsOneWidget);
      nav.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('home'), findsNothing, reason: 'the page underneath must stay hidden');
      expect(find.byType(LockScreen), findsOneWidget);
      await tester.pumpAndSettle();
      await _unmount(tester);
    });

    testWidgets('LockExempt outside the gated app does not lift the lock', (tester) async {
      final fx = await LockFixture.configured(biometrics: false);
      usePhoneSurface(tester);
      Fx.install(FeedbackService(SilentSoundService(), RecordingHaptics()));
      final prefs = await settingsPrefs(tester, const AppSettings(onboarded: true));
      await tester.pumpWidget(
        lockTestApp(
          prefs: prefs,
          overrides: fx.overrides,
          home: const _Home(),
          // An adhan-like layer above the gate, wrongly marked exempt.
          builder: (context, child) => Stack(
            children: [
              LockGateHost(child: child!),
              const LockExempt(child: SizedBox.shrink()),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.text('home'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('the idle dial drifts on the ambient clock, not on every vsync', (tester) async {
      AmbientMotion.debugOverride = true;
      addTearDown(() => AmbientMotion.debugOverride = null);
      final prefs = await settingsPrefs(tester, const AppSettings());
      await tester.pumpWidget(
        lockTestApp(
          prefs: prefs,
          overrides: const [],
          home: const Center(
            child: LockAstrolabe(progress: AlwaysStoppedAnimation(0.0), size: 240),
          ),
        ),
      );
      await tester.pump();
      expect(
        SchedulerBinding.instance.transientCallbackCount,
        0,
        reason: 'a ticker would request a frame on every vsync (90/120 Hz)',
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the PIN check sheet frees its keypad when a lockout ends', (tester) async {
      usePhoneSurface(tester);
      Fx.install(FeedbackService(SilentSoundService(), RecordingHaptics()));
      final now = DateTime(2026, 9, 28, 21, 40);
      final fx = await LockFixture.configured(
        biometrics: false,
        failures: 5,
        lockedUntil: now.add(const Duration(seconds: 3)),
        now: now,
      );
      final prefs = await settingsPrefs(tester, const AppSettings(onboarded: true, languageCode: 'en'));
      await tester.pumpWidget(
        lockTestApp(
          prefs: prefs,
          overrides: fx.overrides,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(onPressed: () => showPinVerifySheet(context), child: const Text('verify')),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('verify'));
      await tester.pumpAndSettle();
      expect(tester.widget<PinKeypad>(find.byType(PinKeypad)).enabled, isFalse);
      expect(find.textContaining('Try again in'), findsOneWidget);
      fx.clock.advance(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(tester.widget<PinKeypad>(find.byType(PinKeypad)).enabled, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
