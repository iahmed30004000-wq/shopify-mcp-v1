import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/kids/core/kids_section.dart';
import 'package:madar/features/kids/stories/application/story_providers.dart';
import 'package:madar/features/kids/stories/application/voice_providers.dart';
import 'package:madar/features/kids/stories/data/voice_recorder.dart';
import 'package:madar/features/kids/stories/presentation/interactive_story_screen.dart';

import 'voice_fakes.dart';
import '../../../helpers/screenshot_harness.dart' show loadMadarFonts;

class _Env {
  final meter = FakeSoundMeter();
  Duration clock = Duration.zero;
  final awards = <String>[];
  bool parentSaysYes = true;
  bool reduced = false;
  int stars = 24;
}

Future<void> _pump(
  WidgetTester tester,
  _Env env, {
  double scale = 1,
  Size size = const Size(360, 780),
  Locale locale = const Locale('ar'),
}) async {
  await tester.runAsync(loadMadarFonts);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        soundMeterProvider.overrideWithValue(env.meter as SoundMeter),
        storyClockProvider.overrideWithValue(() => env.clock),
        kidsParentAskProvider.overrideWithValue(() async => env.parentSaysYes),
        kidsStarCountProvider.overrideWith((ref) => env.stars),
        kidsStarAwardProvider.overrideWith(
          (ref) =>
              (reason) async => env.awards.add(reason),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: env.reduced),
          child: child!,
        ),
        home: const InteractiveStoryScreen(),
      ),
    ),
  );
  await tester.pump(); // the first frame starts the first beat
  await tester.pump();
}

/// Lets the current beat's movement finish.
Future<void> _finishMove(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 3500));
  await tester.pump();
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('story-next')));
  await tester.pump();
}

/// Plays beats 0, 1 so the story waits at beat 2 (which asks for a word).
Future<void> _toFirstPrompt(WidgetTester tester) async {
  await _finishMove(tester);
  await _next(tester);
  await _finishMove(tester);
  await _next(tester);
  await _finishMove(tester);
}

/// A voice: loud readings for a while.
Future<void> _speak(WidgetTester tester, _Env env, {int steps = 12}) async {
  for (var i = 0; i < steps; i++) {
    env.clock += const Duration(milliseconds: 100);
    env.meter.level.add(0.6);
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('beat one: the story text, a still-then-moving scene, and «التالي» once the star has moved', (
    tester,
  ) async {
    final env = _Env();
    await _pump(tester, env);
    expect(find.textContaining('نجمة صغيرة تلمع'), findsOneWidget);
    expect(find.text('التالي'), findsNothing, reason: 'the star is still moving');
    await _finishMove(tester);
    expect(find.text('التالي'), findsOneWidget);
    expect(env.meter.starts, 0, reason: 'this beat asks for no word: the microphone is not on');
  });

  testWidgets('a word is asked: «قُل: ضوء!», the microphone listens, and the skip button is there', (tester) async {
    final env = _Env();
    await _pump(tester, env);
    await _toFirstPrompt(tester);
    expect(find.text('قُل: ضوء!'), findsOneWidget);
    expect(find.text('ما بقدر أحكي هلأ'), findsOneWidget);
    expect(env.meter.starts, 1);
    expect(env.meter.listening, isTrue);
  });

  testWidgets('a sound moves the story on, the microphone goes off, and nothing claims the word was understood', (
    tester,
  ) async {
    final env = _Env();
    await _pump(tester, env);
    await _toFirstPrompt(tester);
    await _speak(tester, env);
    expect(find.textContaining('رأت النجمة فانوسًا'), findsOneWidget, reason: 'beat four');
    expect(env.meter.listening, isFalse);
    for (final claim in ['أحسنت', 'صح', 'سمعتك', 'فهمت', 'غلط', 'جرّب']) {
      expect(find.textContaining(claim), findsNothing, reason: claim);
    }
  });

  testWidgets('a quiet room does not move the story; a click does not either', (tester) async {
    final env = _Env();
    await _pump(tester, env);
    await _toFirstPrompt(tester);
    for (var i = 0; i < 20; i++) {
      env.clock += const Duration(milliseconds: 100);
      env.meter.level.add(0.02);
      await tester.pump(const Duration(milliseconds: 100));
    }
    env.clock += const Duration(milliseconds: 100);
    env.meter.level.add(0.95); // one click
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 5; i++) {
      env.clock += const Duration(milliseconds: 100);
      env.meter.level.add(0.02);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('قُل: ضوء!'), findsOneWidget);
  });

  testWidgets('«ما بقدر أحكي هلأ» goes on without the microphone', (tester) async {
    final env = _Env();
    await _pump(tester, env);
    await _toFirstPrompt(tester);
    await tester.tap(find.text('ما بقدر أحكي هلأ'));
    await tester.pump();
    expect(find.textContaining('رأت النجمة فانوسًا'), findsOneWidget);
    expect(env.meter.listening, isFalse);
  });

  testWidgets('microphone not allowed: a calm line, a parent-only way to allow it, and the story still works', (
    tester,
  ) async {
    final env = _Env()..meter.granted = false;
    await _pump(tester, env);
    await _toFirstPrompt(tester);
    expect(env.meter.starts, 0, reason: 'never listens without permission');
    expect(find.textContaining('المايك مش شغّال'), findsOneWidget);
    expect(find.text('للأهل: شغّل المايك'), findsOneWidget);

    // The parent allows it: only after the gate.
    env.parentSaysYes = false;
    await tester.tap(find.text('للأهل: شغّل المايك'));
    await tester.pump();
    await tester.pump();
    expect(env.meter.askedWithRequest, isFalse, reason: 'the gate said no');
    env.parentSaysYes = true;
    await tester.tap(find.text('للأهل: شغّل المايك'));
    await tester.pump();
    await tester.pump();
    expect(env.meter.askedWithRequest, isTrue);
    expect(env.meter.listening, isTrue);

    await tester.tap(find.text('ما بقدر أحكي هلأ'));
    await tester.pump();
    expect(find.textContaining('رأت النجمة فانوسًا'), findsOneWidget);
  });

  testWidgets('the whole story to the end: one star for the story, then «القصة من جديد»', (tester) async {
    final env = _Env();
    await _pump(tester, env);
    var guard = 0;
    while (find.text('النهاية').evaluate().isEmpty && guard++ < 20) {
      await _finishMove(tester);
      if (find.text('ما بقدر أحكي هلأ').evaluate().isNotEmpty) {
        await tester.tap(find.text('ما بقدر أحكي هلأ'));
        await tester.pump();
      } else if (find.text('التالي').evaluate().isNotEmpty) {
        await _next(tester);
      }
    }
    await tester.pump();
    expect(find.text('النهاية'), findsOneWidget);
    expect(env.awards, ['story.little_star']);
    await tester.tap(find.text('القصة من جديد'));
    await tester.pump();
    expect(find.textContaining('نجمة صغيرة تلمع'), findsOneWidget);
    expect(find.text('النهاية'), findsNothing);
  });

  testWidgets('reduced motion: the beat is a still picture and «التالي» is there at once', (tester) async {
    final env = _Env()..reduced = true;
    await _pump(tester, env);
    await tester.pump();
    expect(find.text('التالي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving the app switches the microphone off', (tester) async {
    final env = _Env();
    await _pump(tester, env);
    await _toFirstPrompt(tester);
    expect(env.meter.listening, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();
    expect(env.meter.listening, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(env.meter.listening, isTrue, reason: 'it picks the question up again');
  });

  for (final locale in [const Locale('ar'), const Locale('en')]) {
    testWidgets('text scale 1.3 at 320x568, ${locale.languageCode}: no overflow on a prompt beat', (tester) async {
      final env = _Env();
      await _pump(tester, env, scale: 1.3, size: const Size(320, 568), locale: locale);
      await _toFirstPrompt(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(InteractiveStoryScreen), findsOneWidget);
    });
  }
}
