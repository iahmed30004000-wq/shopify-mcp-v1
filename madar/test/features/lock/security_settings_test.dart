import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/lock/application/lock_controller.dart';
import 'package:madar/features/lock/data/biometric_auth.dart';
import 'package:madar/features/lock/domain/lock_record.dart';
import 'package:madar/features/lock/domain/lock_session.dart';
import 'package:madar/features/lock/presentation/pin_sheets.dart';
import 'package:madar/features/lock/presentation/security_settings.dart';

import '../../helpers/test_app.dart' show RecordingHaptics, usePhoneSurface;
import 'lock_test_utils.dart';

class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) => const MadarScaffold(
    body: SingleChildScrollView(padding: EdgeInsets.symmetric(horizontal: 20), child: SecuritySettingsSection()),
  );
}

Future<ProviderContainer> _pump(WidgetTester tester, LockFixture fx, {AppSettings? settings}) async {
  usePhoneSurface(tester);
  Fx.install(FeedbackService(SilentSoundService(), RecordingHaptics()));
  final prefs = await settingsPrefs(tester, settings ?? const AppSettings(onboarded: true, languageCode: 'en'));
  await tester.pumpWidget(
    lockTestApp(prefs: prefs, overrides: fx.overrides, locale: const Locale('en'), home: const _Page()),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(SecuritySettingsSection)));
}

Future<void> _type(WidgetTester tester, String digits) async {
  for (final c in digits.split('')) {
    await tester.tap(find.bySemanticsLabel(c).last);
    await tester.pump(const Duration(milliseconds: 30));
  }
}

Future<void> _switch(WidgetTester tester, String title) async {
  await tester.tap(find.byWidgetPredicate((w) => w is MadarSwitch && w.semanticLabel == title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fresh install: lock off; turning it on chooses and confirms a PIN, offers fingerprint', (tester) async {
    final fx = LockFixture.empty();
    final c = await _pump(tester, fx);
    expect(find.text('Protect your data with a PIN and fingerprint'), findsOneWidget);
    expect(find.text('Change PIN'), findsNothing);
    await _switch(tester, 'App lock');
    expect(find.text('Choose a PIN for Madar'), findsOneWidget);
    await _type(tester, '2580');
    await tester.tap(find.bySemanticsLabel('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm your PIN'), findsOneWidget);
    await _type(tester, '2580');
    await tester.pumpAndSettle();
    expect(find.text('Unlock with your fingerprint too?'), findsOneWidget);
    await tester.tap(find.text('Use fingerprint'));
    await tester.pumpAndSettle();
    final s = c.read(lockControllerProvider);
    expect(s.armed, isTrue);
    expect(s.biometrics, isTrue);
    expect(s.phase, LockPhase.open);
    expect(fx.hint.hint, const LockHint(pin: true, biometrics: true));
    expect(find.text('PIN saved. Madar is now locked for you alone.'), findsOneWidget);
    expect(find.text('Change PIN'), findsOneWidget);
    expect(find.text('Lock after leaving the app'), findsOneWidget);
  });

  testWidgets('dismissing the PIN sheet leaves the lock off', (tester) async {
    final fx = LockFixture.empty(available: BiometricAvailability.noHardware);
    final c = await _pump(tester, fx);
    await _switch(tester, 'App lock');
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(c.read(lockControllerProvider).armed, isFalse);
    expect(fx.vault.writes, 0);
  });

  testWidgets('turning the lock off needs the owner (fingerprint)', (tester) async {
    final fx = await LockFixture.configured();
    final c = await _pump(tester, fx);
    // Unlock first (the section lives inside the unlocked app).
    await c.read(lockControllerProvider.notifier).checkPin('2580');
    await _switch(tester, 'App lock');
    expect(fx.bio.prompts.single.reason, 'Confirm it\'s you to change the lock settings');
    expect(c.read(appSettingsProvider).lockEnabled, isFalse);
    expect(c.read(lockControllerProvider).hasPin, isTrue, reason: 'the PIN is kept');
  });

  testWidgets('turning the lock off with a wrong PIN changes nothing', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    final c = await _pump(tester, fx);
    await _switch(tester, 'App lock');
    expect(find.byType(PinVerifySheet), findsOneWidget);
    await _type(tester, '1111');
    await tester.pumpAndSettle();
    expect(find.textContaining('Wrong PIN'), findsOneWidget);
    await _type(tester, '2580');
    await tester.pumpAndSettle();
    expect(find.byType(PinVerifySheet), findsNothing);
    expect(c.read(appSettingsProvider).lockEnabled, isFalse);
  });

  testWidgets('fingerprint off keeps the PIN; on needs a successful scan', (tester) async {
    final fx = await LockFixture.configured();
    final c = await _pump(tester, fx);
    await _switch(tester, 'Fingerprint unlock');
    expect(c.read(lockControllerProvider).biometrics, isFalse);
    expect(c.read(lockControllerProvider).hasPin, isTrue);

    fx.bio.fallback = BiometricOutcome.cancelled;
    await _switch(tester, 'Fingerprint unlock');
    expect(c.read(lockControllerProvider).biometrics, isFalse);
    fx.bio.fallback = BiometricOutcome.success;
    await _switch(tester, 'Fingerprint unlock');
    expect(c.read(lockControllerProvider).biometrics, isTrue);
  });

  testWidgets('change PIN: current, new, confirm', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    final c = await _pump(tester, fx);
    await tester.tap(find.text('Change PIN'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your current PIN'), findsOneWidget);
    await _type(tester, '2580');
    await tester.pumpAndSettle();
    expect(find.text('Choose a new PIN'), findsOneWidget);
    await _type(tester, '739164');
    await tester.tap(find.bySemanticsLabel('Done'));
    await tester.pumpAndSettle();
    await _type(tester, '739164');
    await tester.pumpAndSettle();
    expect(find.text('PIN changed'), findsOneWidget);
    expect(c.read(lockControllerProvider).pinLength, 6);
    expect((await c.read(lockControllerProvider.notifier).checkPin('739164', unlock: false)).accepted, isTrue);
  });

  testWidgets('remove PIN: confirm, authenticate, lock off', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    final c = await _pump(tester, fx);
    await tester.tap(find.text('Remove PIN'));
    await tester.pumpAndSettle();
    expect(find.text('Remove your PIN?'), findsOneWidget);
    await tester.tap(find.text('Remove PIN').last);
    await tester.pumpAndSettle();
    await _type(tester, '2580');
    await tester.pumpAndSettle();
    expect(c.read(lockControllerProvider).armed, isFalse);
    expect(fx.vault.record, LockRecord.empty);
    expect(find.text('Change PIN'), findsNothing);
  });

  testWidgets('"lock after" choices update the setting', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    final c = await _pump(tester, fx);
    for (final label in ['Immediately', '1 minute', '2 minutes', '5 minutes', '15 minutes']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('5 minutes'));
    await tester.pumpAndSettle();
    expect(c.read(appSettingsProvider).lockAfterSeconds, 300);
  });

  testWidgets('no sensor: the fingerprint row is hidden', (tester) async {
    final fx = await LockFixture.configured(biometrics: false, available: BiometricAvailability.noHardware);
    await _pump(tester, fx);
    expect(find.text('Fingerprint unlock'), findsNothing);
  });
}
