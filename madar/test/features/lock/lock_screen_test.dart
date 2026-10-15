import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/widgets/widgets.dart' show MadarButton, MadarButtonSize;
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/lock/application/lock_controller.dart';
import 'package:madar/features/lock/data/biometric_auth.dart';
import 'package:madar/features/lock/domain/lock_session.dart';
import 'package:madar/features/lock/presentation/lock_gate_host.dart';
import 'package:madar/features/lock/presentation/lock_screen.dart';
import 'package:madar/features/lock/presentation/pin_pad.dart';
import 'package:madar/features/lock/render/lock_astrolabe.dart';

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

/// Pumps the gate over a stand-in app. The app starts in [lifecycle] (on a
/// phone the lock screen appears in the foreground: `resumed`).
Future<ProviderContainer> _pump(
  WidgetTester tester,
  LockFixture fx, {
  Locale locale = const Locale('ar'),
  bool reduced = false,
  AppLifecycleState lifecycle = AppLifecycleState.resumed,
}) async {
  usePhoneSurface(tester);
  _sound = SilentSoundService();
  _haptics = RecordingHaptics();
  Fx.install(FeedbackService(_sound, _haptics));
  tester.binding.handleAppLifecycleStateChanged(lifecycle);
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

/// The system prompt closing: the app regains focus.
Future<void> _promptClosed(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

Future<void> _leave(WidgetTester tester) async {
  for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
}

Future<void> _return(WidgetTester tester) async {
  for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
}

/// The large "Use fingerprint" button of the fingerprint face.
Finder _useFingerprint(String label) =>
    find.byWidgetPredicate((w) => w is MadarButton && w.label == label && w.size == MadarButtonSize.large);

/// Whether the big button is shown (it fades out while the prompt is up).
bool _buttonShown(WidgetTester tester, String label) {
  final button = _useFingerprint(label);
  if (button.evaluate().isEmpty) return false;
  final fade = tester.widget<AnimatedOpacity>(find.ancestor(of: button, matching: find.byType(AnimatedOpacity)).first);
  return fade.opacity == 1;
}

const _useFingerprintAr = 'استخدم البصمة';

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

  group('the fingerprint prompt opens by itself', () {
    testWidgets('on show: no tap – the astrolabe assembles while it reads, then the door opens', (tester) async {
      final fx = await LockFixture.configured();
      fx.bio.holdPrompt = true;
      final c = await _pump(tester, fx);
      expect(fx.bio.prompts, hasLength(1), reason: 'requested right after the first frame');
      expect(fx.bio.prompting, isTrue);
      expect(fx.bio.prompts.single.title, 'افتح مَدار');
      expect(fx.bio.prompts.single.cancel, 'إلغاء');
      expect(find.text('المس مستشعر البصمة'), findsOneWidget);
      expect(_buttonShown(tester, _useFingerprintAr), isFalse, reason: 'the button steps aside while reading');
      // The "being read" state: the dial assembles by itself.
      final lockState = tester.state<LockScreenState>(find.byType(LockScreen));
      final before = tester.widget<LockAstrolabe>(find.byType(LockAstrolabe)).progress.value;
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.widget<LockAstrolabe>(find.byType(LockAstrolabe)).progress.value, greaterThan(before + 0.3));
      expect(lockState.mode, LockScreenMode.hold);
      fx.bio.finish(BiometricOutcome.success);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsNothing);
      expect(c.read(lockControllerProvider).phase, LockPhase.open);
      expect(fx.bio.prompts, hasLength(1));
      await _unmount(tester);
    });

    testWidgets('once only: frames, focus changes and rebuilds never ask twice', (tester) async {
      final fx = await LockFixture.configured();
      fx.bio.holdPrompt = true;
      await _pump(tester, fx);
      expect(fx.bio.prompts, hasLength(1));
      // The prompt itself takes the focus (inactive) and gives it back.
      await _promptClosed(tester);
      await tester.pump(const Duration(seconds: 2));
      await _promptClosed(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(fx.bio.prompts, hasLength(1));
      fx.bio.finish(BiometricOutcome.success);
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsNothing);
      await _unmount(tester);
    });

    testWidgets('cancel: no prompt loop; the large "Use fingerprint" button asks again', (tester) async {
      final fx = await LockFixture.configured();
      fx.bio.outcomes.add(BiometricOutcome.cancelled);
      final c = await _pump(tester, fx);
      await _promptClosed(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(fx.bio.prompts, hasLength(1), reason: 'never re-prompts by itself after a cancel');
      expect(find.byType(PinKeypad), findsNothing, reason: 'still the fingerprint face');
      expect(_buttonShown(tester, _useFingerprintAr), isTrue);
      expect(find.text('افتح مَدار ببصمتك'), findsOneWidget);
      expect(find.text('استخدم الرمز'), findsOneWidget, reason: 'the PIN is one tap away');
      final size = tester.getSize(_useFingerprint(_useFingerprintAr));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(200));
      await tester.tap(_useFingerprint(_useFingerprintAr));
      await tester.pumpAndSettle();
      expect(fx.bio.prompts, hasLength(2));
      expect(find.byType(LockScreen), findsNothing);
      expect(c.read(lockControllerProvider).phase, LockPhase.open);
      await _unmount(tester);
    });

    testWidgets('an error: the message and the button – not an immediate new prompt', (tester) async {
      final fx = await LockFixture.configured();
      fx.bio.outcomes.add(BiometricOutcome.error);
      await _pump(tester, fx, locale: const Locale('en'));
      await _promptClosed(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(fx.bio.prompts, hasLength(1));
      expect(find.text("Couldn't verify your fingerprint. Try again or use your PIN."), findsOneWidget);
      expect(_sound.played, contains(Sfx.error));
      expect(_buttonShown(tester, 'Use fingerprint'), isTrue);
      expect(find.byType(PinKeypad), findsNothing);
      await _unmount(tester);
    });

    testWidgets('locked out → straight to the PIN with an explanation', (tester) async {
      final fx = await LockFixture.configured();
      fx.bio.fallback = BiometricOutcome.lockedOutPermanently;
      await _pump(tester, fx, locale: const Locale('en'));
      await tester.pumpAndSettle();
      expect(fx.bio.prompts, hasLength(1));
      expect(find.byType(PinKeypad), findsOneWidget);
      expect(find.textContaining('Fingerprint is locked until you unlock the phone'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('temporarily locked out → the PIN too', (tester) async {
      final fx = await LockFixture.configured();
      fx.bio.fallback = BiometricOutcome.lockedOut;
      await _pump(tester, fx);
      await tester.pumpAndSettle();
      expect(find.byType(PinKeypad), findsOneWidget);
      expect(find.text('توقّفت البصمة مؤقتًا بعد محاولات كثيرة. استخدم الرمز.'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('never while the app is not in the foreground: it waits for "resumed"', (tester) async {
      final fx = await LockFixture.configured();
      fx.bio.holdPrompt = true;
      await _pump(tester, fx, lifecycle: AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 1));
      expect(fx.bio.prompts, isEmpty);
      expect(find.byType(LockScreen), findsOneWidget);
      expect(_buttonShown(tester, _useFingerprintAr), isTrue, reason: 'never a dead end');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(fx.bio.prompts, hasLength(1));
      fx.bio.finish(BiometricOutcome.success);
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsNothing);
      await _unmount(tester);
    });

    testWidgets('leaving the app with the lock screen up and coming back asks again', (tester) async {
      final fx = await LockFixture.configured();
      fx.bio.outcomes.addAll([BiometricOutcome.cancelled, BiometricOutcome.cancelled]);
      await _pump(tester, fx);
      await _promptClosed(tester);
      await tester.pumpAndSettle();
      expect(fx.bio.prompts, hasLength(1));
      await _leave(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(fx.bio.prompts, hasLength(1), reason: 'not while away');
      await _return(tester);
      await tester.pump();
      expect(fx.bio.prompts, hasLength(2));
      await _unmount(tester);
    });

    testWidgets('the system dropping the prompt as the owner leaves: asked again on return', (tester) async {
      final fx = await LockFixture.configured();
      fx.bio.holdPrompt = true;
      await _pump(tester, fx);
      expect(fx.bio.prompts, hasLength(1));
      await _leave(tester);
      fx.bio.finish(BiometricOutcome.interrupted);
      await tester.pump(const Duration(seconds: 1));
      expect(fx.bio.prompts, hasLength(1));
      fx.bio.holdPrompt = false;
      await _return(tester);
      await tester.pumpAndSettle();
      expect(fx.bio.prompts, hasLength(2));
      expect(find.byType(LockScreen), findsNothing);
      await _unmount(tester);
    });

    testWidgets('resume after the background time-out: the prompt opens by itself again', (tester) async {
      final fx = await LockFixture.configured();
      final c = await _pump(tester, fx);
      await tester.pumpAndSettle();
      expect(fx.bio.prompts, hasLength(1));
      expect(c.read(lockControllerProvider).phase, LockPhase.open);

      await _leave(tester);
      fx.clock.advance(const Duration(minutes: 3));
      fx.bio.holdPrompt = true;
      await _return(tester);
      expect(find.byType(LockScreen), findsOneWidget);
      await tester.pump();
      expect(fx.bio.prompts, hasLength(2), reason: 'no tap needed after the time-out either');
      fx.bio.finish(BiometricOutcome.success);
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsNothing);
      await _unmount(tester);
    });

    testWidgets('a short trip away (no lock) never prompts', (tester) async {
      final fx = await LockFixture.configured();
      await _pump(tester, fx);
      await tester.pumpAndSettle();
      expect(fx.bio.prompts, hasLength(1));
      await _leave(tester);
      fx.clock.advance(const Duration(seconds: 20));
      await _return(tester);
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsNothing);
      expect(fx.bio.prompts, hasLength(1));
      await _unmount(tester);
    });
  });

  testWidgets('holding the astrolabe still asks for the fingerprint (an extra way)', (tester) async {
    final fx = await LockFixture.configured();
    fx.bio.outcomes.add(BiometricOutcome.cancelled);
    final c = await _pump(tester, fx);
    await tester.pumpAndSettle();
    expect(fx.bio.prompts, hasLength(1));
    fx.bio.holdPrompt = true;
    final gesture = await tester.startGesture(tester.getCenter(find.byType(LockAstrolabe)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('أبقِ إصبعك… الأسطرلاب يكتمل'), findsOneWidget);
    expect(fx.bio.prompts, hasLength(1));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 300));
    expect(fx.bio.prompts, hasLength(2), reason: 'the prompt opens once half the dial is built');
    expect(find.text('المس مستشعر البصمة'), findsOneWidget);
    await gesture.up();
    fx.bio.finish(BiometricOutcome.success);
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsNothing);
    expect(c.read(lockControllerProvider).phase, LockPhase.open);
    await _unmount(tester);
  });

  testWidgets('releasing a hold too early rewinds without a prompt', (tester) async {
    final fx = await LockFixture.configured();
    fx.bio.outcomes.add(BiometricOutcome.cancelled);
    await _pump(tester, fx);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.byType(LockAstrolabe)));
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fx.bio.prompts, hasLength(1));
    expect(find.text('أبقِ إصبعك حتى يكتمل الأسطرلاب'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('screen readers: a tap on the astrolabe opens the prompt directly', (tester) async {
    final handle = tester.ensureSemantics();
    final fx = await LockFixture.configured();
    fx.bio.outcomes.add(BiometricOutcome.cancelled);
    await _pump(tester, fx);
    await tester.pumpAndSettle();
    tester.semantics.tap(find.semantics.byLabel('الأسطرلاب. اضغط مطوّلًا لتفتح القفل بالبصمة'));
    await tester.pumpAndSettle();
    expect(fx.bio.prompts, hasLength(2));
    handle.dispose();
    await _unmount(tester);
  });

  testWidgets('"Use PIN" after a cancel: the keypad, whose fingerprint key asks again', (tester) async {
    final fx = await LockFixture.configured();
    fx.bio.fallback = BiometricOutcome.cancelled;
    await _pump(tester, fx);
    await tester.pumpAndSettle();
    await tester.tap(find.text('استخدم الرمز'));
    await tester.pumpAndSettle();
    expect(find.byType(PinKeypad), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('البصمة'));
    await tester.pumpAndSettle();
    expect(fx.bio.prompts, hasLength(2));
    expect(find.byType(PinKeypad), findsNothing, reason: 'a cancel keeps the fingerprint face');
    expect(_buttonShown(tester, _useFingerprintAr), isTrue);
    await _unmount(tester);
  });

  testWidgets('PIN only (fingerprint off): the keypad at once, never a prompt', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    await _pump(tester, fx);
    await tester.pumpAndSettle();
    expect(find.byType(PinKeypad), findsOneWidget);
    expect(fx.bio.prompts, isEmpty);
    expect(_useFingerprint(_useFingerprintAr), findsNothing);
    await _unmount(tester);
  });

  testWidgets('no enrolled fingerprint any more: starts on the PIN without a prompt', (tester) async {
    final fx = await LockFixture.configured(available: BiometricAvailability.notEnrolled);
    await _pump(tester, fx);
    await tester.pumpAndSettle();
    expect(find.byType(PinKeypad), findsOneWidget);
    expect(find.bySemanticsLabel('البصمة'), findsNothing);
    expect(fx.bio.prompts, isEmpty);
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
    fx.bio.outcomes.add(BiometricOutcome.cancelled);
    final c = await _pump(tester, fx, locale: const Locale('en'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use PIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot PIN?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm with fingerprint'));
    await tester.pumpAndSettle();
    expect(fx.bio.prompts, hasLength(2));
    expect(fx.bio.prompts.last.cancel, 'Cancel');
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
    fx.bio.outcomes.add(BiometricOutcome.cancelled);
    await _pump(tester, fx, locale: const Locale('en'));
    await tester.pumpAndSettle();
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
