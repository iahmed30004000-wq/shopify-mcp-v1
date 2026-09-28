import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/lock/application/lock_controller.dart';
import 'package:madar/features/lock/data/biometric_auth.dart';
import 'package:madar/features/lock/domain/lock_session.dart';
import 'package:madar/features/lock/presentation/lock_gate_host.dart';
import 'package:madar/features/lock/presentation/lock_screen.dart';
import 'package:madar/features/lock/presentation/pin_pad.dart';

import '../../helpers/test_app.dart' show RecordingHaptics, usePhoneSurface;
import 'lock_test_utils.dart';

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(onPressed: () => setState(() => taps++), child: Text('home $taps')),
    ),
  );
}

late SilentSoundService _sound;
late RecordingHaptics _haptics;

Future<ProviderContainer> _pump(
  WidgetTester tester,
  LockFixture fx, {
  Locale locale = const Locale('ar'),
  bool reduced = false,
}) async {
  usePhoneSurface(tester);
  _sound = SilentSoundService();
  _haptics = RecordingHaptics();
  Fx.install(FeedbackService(_sound, _haptics));
  final prefs = await settingsPrefs(tester, AppSettings(onboarded: true, languageCode: locale.languageCode));
  await tester.pumpWidget(
    lockTestApp(
      prefs: prefs,
      overrides: fx.overrides,
      locale: locale,
      reduced: reduced,
      home: const _Home(),
      builder: (context, child) => LockGateHost(child: child!),
    ),
  );
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(LockGateHost)));
}

Future<void> _type(WidgetTester tester, String digits) async {
  for (final c in digits.split('')) {
    await tester.tap(find.bySemanticsLabel(c).last);
    await tester.pump(const Duration(milliseconds: 50));
  }
}

String _ar(String western) => western.split('').map((c) => '٠١٢٣٤٥٦٧٨٩'[int.parse(c)]).join();

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('fresh install: no lock screen, the app is interactive', (tester) async {
    await _pump(tester, LockFixture.empty());
    expect(find.byType(LockScreen), findsNothing);
    await tester.tap(find.text('home 0'));
    await tester.pump();
    expect(find.text('home 1'), findsOneWidget);
  });

  testWidgets('locked: covers the app from the first frame; the app keeps its state', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    final c = await _pump(tester, fx);
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('home 0'), findsNothing, reason: 'offstage – never painted');
    expect(find.text('home 0', skipOffstage: false), findsOneWidget, reason: 'but mounted');
    expect(c.read(lockControllerProvider).phase, LockPhase.locked);

    await _type(tester, _ar('2580'));
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsNothing);
    expect(find.text('home 0'), findsOneWidget);
    expect(c.read(lockControllerProvider).phase, LockPhase.open);
    expect(_sound.played, contains(Sfx.complete), reason: 'the chime');
    await _unmount(tester);
  });

  testWidgets('Arabic keypad shows Arabic-Indic digits; English shows Western digits', (tester) async {
    await _pump(tester, await LockFixture.configured(biometrics: false));
    for (var d = 0; d <= 9; d++) {
      expect(find.text(_ar('$d')), findsOneWidget);
    }
    expect(find.text('5'), findsNothing);
    await _unmount(tester);

    await _pump(tester, await LockFixture.configured(biometrics: false), locale: const Locale('en'));
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Enter your Madar PIN'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('every key plays a sound with its haptic', (tester) async {
    await _pump(tester, await LockFixture.configured(biometrics: false));
    _sound.played.clear();
    _haptics.fired.clear();
    await _type(tester, _ar('25'));
    expect(_sound.played.where((s) => s == Sfx.tap), hasLength(2));
    expect(_haptics.fired.where((h) => h == Haptic.selection), hasLength(2));
    await tester.tap(find.bySemanticsLabel('حذف'));
    await tester.pump();
    expect(_sound.played.last, Sfx.back);
    await _unmount(tester);
  });

  testWidgets('wrong PIN: error sound, shake, message with tries left, dots cleared', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    await _pump(tester, fx);
    await _type(tester, _ar('1111'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_sound.played, contains(Sfx.error));
    expect(_haptics.fired, contains(Haptic.error));
    expect(find.text('رمز غير صحيح · تبقّت ٤ محاولات قبل الإيقاف المؤقت'), findsOneWidget);
    final dots = tester.widget<PinDots>(find.byType(PinDots));
    expect(dots.filled, 0);
    expect(dots.error, isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    final shake = find.descendant(of: find.byType(PinDots), matching: find.byType(Transform));
    expect(tester.widget<Transform>(shake.first).transform.getTranslation().x, isNot(0));
    await tester.pumpAndSettle();
    expect(fx.vault.record.failures, 1);
    await _unmount(tester);
  });

  testWidgets('five wrong PINs lock the keypad with a countdown, then it frees up', (tester) async {
    final fx = await LockFixture.configured(biometrics: false, failures: 4);
    await _pump(tester, fx);
    await _type(tester, _ar('0000'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('محاولات كثيرة'), findsOneWidget);
    expect(find.textContaining('٣٠ ثانية'), findsOneWidget);
    expect(tester.widget<PinKeypad>(find.byType(PinKeypad)).enabled, isFalse);
    fx.clock.advance(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('٢٠ ثانية'), findsOneWidget);
    fx.clock.advance(const Duration(seconds: 21));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.widget<PinKeypad>(find.byType(PinKeypad)).enabled, isTrue);
    await _unmount(tester);
  });

  testWidgets('hold the astrolabe → the fingerprint prompt → the app opens', (tester) async {
    final fx = await LockFixture.configured();
    fx.bio.holdPrompt = true;
    final c = await _pump(tester, fx);
    expect(find.text('اضغط مطوّلًا على الأسطرلاب لتفتح مَدار'), findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(LockScreen)) - const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('أبقِ إصبعك… الأسطرلاب يكتمل'), findsOneWidget);
    expect(fx.bio.prompts, isEmpty);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 300));
    expect(fx.bio.prompts, hasLength(1), reason: 'the prompt opens once half the dial is built');
    expect(fx.bio.prompts.single.title, 'افتح مَدار');
    expect(fx.bio.prompts.single.cancel, 'استخدم الرمز');
    expect(find.text('المس مستشعر البصمة'), findsOneWidget);
    await gesture.up();
    fx.bio.finish(BiometricOutcome.success);
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsNothing);
    expect(c.read(lockControllerProvider).phase, LockPhase.open);
    await _unmount(tester);
  });

  testWidgets('releasing too early rewinds without a prompt', (tester) async {
    final fx = await LockFixture.configured();
    await _pump(tester, fx);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(LockScreen)) - const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fx.bio.prompts, isEmpty);
    expect(find.text('أبقِ إصبعك حتى يكتمل الأسطرلاب'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('screen readers: a tap on the astrolabe opens the prompt directly', (tester) async {
    final handle = tester.ensureSemantics();
    final fx = await LockFixture.configured();
    await _pump(tester, fx);
    tester.semantics.tap(find.semantics.byLabel('الأسطرلاب. اضغط مطوّلًا لتفتح القفل بالبصمة'));
    await tester.pumpAndSettle();
    expect(fx.bio.prompts, hasLength(1));
    handle.dispose();
    await _unmount(tester);
  });

  testWidgets('cancelling the prompt ("Use PIN") switches to the keypad', (tester) async {
    final fx = await LockFixture.configured();
    fx.bio.fallback = BiometricOutcome.cancelled;
    await _pump(tester, fx);
    await tester.tap(
      find.bySemanticsLabel('البصمة').evaluate().isEmpty ? find.text('استخدم الرمز') : find.text('استخدم الرمز'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PinKeypad), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('البصمة'));
    await tester.pumpAndSettle();
    expect(fx.bio.prompts, hasLength(1));
    expect(find.byType(PinKeypad), findsOneWidget, reason: 'cancel → back to the PIN');
    await _unmount(tester);
  });

  testWidgets('fingerprint locked out → PIN with an explanation', (tester) async {
    final fx = await LockFixture.configured();
    fx.bio.fallback = BiometricOutcome.lockedOutPermanently;
    await _pump(tester, fx, locale: const Locale('en'));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(LockScreen)) - const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(PinKeypad), findsOneWidget);
    expect(find.textContaining('Fingerprint is locked until you unlock the phone'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('no enrolled fingerprint any more: starts on the PIN', (tester) async {
    final fx = await LockFixture.configured(available: BiometricAvailability.notEnrolled);
    await _pump(tester, fx);
    await tester.pumpAndSettle();
    expect(find.byType(PinKeypad), findsOneWidget);
    expect(find.bySemanticsLabel('البصمة'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('forgot PIN without fingerprint: honest explanation, no reset', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    await _pump(tester, fx, locale: const Locale('en'));
    await tester.tap(find.text('Forgot PIN?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no account and no server'), findsOneWidget);
    expect(find.textContaining('Clear data'), findsOneWidget);
    expect(find.text('Confirm with fingerprint'), findsNothing);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(PinKeypad), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('forgot PIN with fingerprint: verify, choose and confirm a new PIN, unlock', (tester) async {
    final fx = await LockFixture.configured();
    final c = await _pump(tester, fx, locale: const Locale('en'));
    await tester.tap(find.text('Use PIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot PIN?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm with fingerprint'));
    await tester.pumpAndSettle();
    expect(fx.bio.prompts.single.cancel, 'Cancel');
    expect(find.text('Choose a new PIN'), findsOneWidget);
    await _type(tester, '97531');
    await tester.tap(find.bySemanticsLabel('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm your PIN'), findsOneWidget);
    await _type(tester, '97531');
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsNothing);
    expect(c.read(lockControllerProvider).pinLength, 5);
    expect((await c.read(lockControllerProvider.notifier).checkPin('97531', unlock: false)).accepted, isTrue);
    await _unmount(tester);
  });

  testWidgets('new PIN mismatch starts again', (tester) async {
    final fx = await LockFixture.configured();
    await _pump(tester, fx, locale: const Locale('en'));
    await tester.tap(find.text('Use PIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot PIN?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm with fingerprint'));
    await tester.pumpAndSettle();
    await _type(tester, '8642');
    await tester.tap(find.bySemanticsLabel('Done'));
    await tester.pumpAndSettle();
    await _type(tester, '8641');
    await tester.pumpAndSettle();
    expect(find.text("Those PINs don't match. Let's start again."), findsOneWidget);
    expect(find.text('Choose a new PIN'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('reduced motion: unlocking is a calm fade', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    await _pump(tester, fx, reduced: true);
    await _type(tester, _ar('2580'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsNothing);
    await _unmount(tester);
  });

  testWidgets('privacy shield covers the open app while inactive', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    final c = await _pump(tester, fx);
    await _type(tester, _ar('2580'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(PrivacyShield), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(PrivacyShield), findsNothing);
    expect(c.read(lockControllerProvider).phase, LockPhase.open);
    await _unmount(tester);
  });

  testWidgets('LockExempt shows its screen above the lock, then the lock returns', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    final c = await _pump(tester, fx);
    final nav = tester.state<NavigatorState>(find.byType(Navigator, skipOffstage: false));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const LockExempt(child: Scaffold(body: Text('adhan'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('adhan'), findsOneWidget);
    expect(find.byType(LockScreen), findsNothing);
    expect(c.read(lockControllerProvider).phase, LockPhase.locked);
    nav.pop();
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsOneWidget);
    await _unmount(tester);
  });
}
