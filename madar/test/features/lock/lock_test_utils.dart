// Fakes and builders for the app-lock tests.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/lock/application/lock_controller.dart';
import 'package:madar/features/lock/data/biometric_auth.dart';
import 'package:madar/features/lock/data/lock_vault.dart';
import 'package:madar/features/lock/domain/lock_record.dart';
import 'package:madar/features/lock/domain/pin_hash.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scriptable [BiometricAuth].
class FakeBiometricAuth implements BiometricAuth {
  FakeBiometricAuth({this.available = BiometricAvailability.available, List<BiometricOutcome>? outcomes})
    : outcomes = outcomes ?? [];

  BiometricAvailability available;

  /// Outcomes returned in order; then [fallback].
  final List<BiometricOutcome> outcomes;
  BiometricOutcome fallback = BiometricOutcome.success;

  /// When true, [authenticate] waits for [finish].
  bool holdPrompt = false;
  Completer<BiometricOutcome>? _pending;
  final List<BiometricPromptText> prompts = [];
  int cancels = 0;

  bool get prompting => _pending != null && !_pending!.isCompleted;

  void finish(BiometricOutcome outcome) => _pending?.complete(outcome);

  @override
  Future<BiometricAvailability> availability() async => available;

  @override
  Future<BiometricOutcome> authenticate(BiometricPromptText text) {
    prompts.add(text);
    if (holdPrompt) {
      _pending = Completer();
      return _pending!.future;
    }
    return Future.value(outcomes.isNotEmpty ? outcomes.removeAt(0) : fallback);
  }

  @override
  Future<void> cancel() async => cancels++;
}

/// PBKDF2 with few iterations on the calling isolate (fast, deterministic
/// timing in fake-async tests).
PinHasher fastHasher() => PinHasher(iterations: 64, runner: PinHasher.inlineRunner);

/// A settable wall clock.
class TestClock {
  TestClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);
}

/// The lock's storage, preset.
class LockFixture {
  LockFixture({required this.vault, required this.hint, required this.bio, required this.clock});

  final MemoryLockVault vault;
  final MemoryLockHintStore hint;
  final FakeBiometricAuth bio;
  final TestClock clock;

  List<Override> get overrides => [
    lockVaultProvider.overrideWithValue(vault),
    lockHintStoreProvider.overrideWithValue(hint),
    biometricAuthProvider.overrideWithValue(bio),
    pinHasherProvider.overrideWithValue(fastHasher()),
    lockClockProvider.overrideWithValue(clock.call),
  ];

  /// No lock configured (a fresh install).
  static LockFixture empty({DateTime? now, BiometricAvailability available = BiometricAvailability.available}) =>
      LockFixture(
        vault: MemoryLockVault(),
        hint: MemoryLockHintStore(),
        bio: FakeBiometricAuth(available: available),
        clock: TestClock(now ?? DateTime(2026, 9, 28, 21, 40)),
      );

  /// A lock with PIN [pin] and fingerprint unlock [biometrics].
  static Future<LockFixture> configured({
    String pin = '2580',
    bool biometrics = true,
    int failures = 0,
    DateTime? lockedUntil,
    DateTime? now,
    BiometricAvailability available = BiometricAvailability.available,
  }) async {
    final record = LockRecord(
      pin: await fastHasher().hash(pin),
      biometrics: biometrics,
      failures: failures,
      lockedUntil: lockedUntil,
    );
    return LockFixture(
      vault: MemoryLockVault(record),
      hint: MemoryLockHintStore(LockHint.of(record)),
      bio: FakeBiometricAuth(available: available),
      clock: TestClock(now ?? DateTime(2026, 9, 28, 21, 40)),
    );
  }
}

/// Mock SharedPreferences holding [settings] (outside the fake-async zone).
Future<SharedPreferences> settingsPrefs(WidgetTester tester, AppSettings settings) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final probe = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  await tester.runAsync(() => probe.read(appSettingsProvider.notifier).update((_) => settings));
  probe.dispose();
  return prefs;
}

/// A MaterialApp configured like Madar's (theme, locale, digit style,
/// motion scope and the celebration layer) around [builder]'s widget, in a
/// ProviderScope with [overrides].
Widget lockTestApp({
  required SharedPreferences prefs,
  required List<Override> overrides,
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  bool reduced = false,
  Color? customAccent,
  TransitionBuilder? builder,
}) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs), ...overrides],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMadarTheme(theme, customAccent: customAccent, arabic: locale.languageCode == 'ar'),
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      builder: (context, child) => MadarFormatScope(
        digits: DigitStyle.auto,
        child: MotionScope(
          reduced: reduced,
          child: CelebrationOverlay(child: builder == null ? child! : builder(context, child)),
        ),
      ),
      home: home,
    ),
  );
}
