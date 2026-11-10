import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/kids/core/kids_section.dart';
import 'package:madar/features/kids/learn/data/arabic_letters.dart';
import 'package:madar/features/kids/learn/domain/maths_engine.dart';
import 'package:madar/features/kids/learn/learn.dart';
import 'package:madar/features/kids/learn/letters/letters_screen.dart';
import 'package:madar/features/kids/learn/letters/trace_canvas.dart';
import 'package:madar/features/kids/learn/ui/kids_widgets.dart';
import 'package:madar/features/kids/learn/maths/maths_screen.dart';
import 'package:madar/features/kids/learn/voice/kids_voice.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import 'kids_harness.dart';

class _RecordingVoice implements KidsVoice {
  final played = <String>[];
  @override
  Future<void> play(String id) async => played.add(id);
  @override
  Future<void> stop() async {}
}

void main() {
  late List<String> stars;
  late _RecordingVoice voice;
  late List<Override> overrides;

  setUp(() {
    stars = [];
    voice = _RecordingVoice();
    overrides = [
      kidsStarAwardProvider.overrideWithValue((reason) async => stars.add(reason)),
      kidsVoiceProvider.overrideWithValue(voice),
    ];
  });

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text);
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
  }

  const wrong = ['خطأ', 'غلط', 'Wrong', 'wrong', '✗', '❌'];
  void expectNoWrongWording(WidgetTester tester) {
    for (final w in wrong) {
      expect(find.textContaining(w), findsNothing, reason: 'a child is never told he is wrong ($w)');
    }
  }

  group('sections', () {
    test('the shell can list them: stable ids, titles, not religious', () {
      expect(lettersSection.id, 'letters');
      expect(mathsSection.id, 'maths');
      expect(lettersSection.religious, isFalse);
      expect(mathsSection.religious, isFalse);
    });
  });

  group('letters', () {
    testWidgets('shows the letter, its four forms, the word with its picture and the speakers', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(kidsApp(const LettersScreen(initialIndex: 17), overrides: overrides));
      await tester.pump();
      final l = L10n.of(tester.element(find.byType(LettersScreen)));
      expect(find.text(l.kidsLettersLetterOf('عين')), findsOneWidget);
      for (final t in [l.kidsLettersFormIsolated, l.kidsLettersFormInitial, l.kidsLettersFormMedial, l.kidsLettersFormFinal]) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.byIcon(Icons.volume_up_rounded), findsNWidgets(2), reason: 'letter + word speakers');
      expect(tester.takeException(), isNull);
    });

    testWidgets('every text has a speaker that calls the voice with a stable id', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(kidsApp(const LettersScreen(initialIndex: 17), overrides: overrides));
      await tester.pump();
      final speakers = find.byIcon(Icons.volume_up_rounded);
      await tester.tap(speakers.at(0));
      await tester.tap(speakers.at(1));
      expect(voice.played, ['letter_ain', 'word_ain']);
    });

    testWidgets('next and previous walk the alphabet and wrap', (tester) async {
      setPhone(tester, height: 900);
      await tester.pumpWidget(kidsApp(const LettersScreen(initialIndex: 27), overrides: overrides));
      await tester.pump();
      final l = L10n.of(tester.element(find.byType(LettersScreen)));
      await tapText(tester, l.kidsLettersNext);
      await tester.pump();
      expect(find.text(l.kidsLettersLetterOf('ألف')), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(l.kidsLettersPrevious));
      await tester.pump();
      expect(find.text(l.kidsLettersLetterOf('ياء')), findsOneWidget);
    });

    testWidgets('tracing: a finger leaves ink, a little drawing earns a kind word, clear starts again', (tester) async {
      setPhone(tester, height: 900);
      await tester.pumpWidget(kidsApp(const LettersScreen(initialIndex: 1), overrides: overrides));
      await tester.pump();
      final l = L10n.of(tester.element(find.byType(LettersScreen)));
      await tapText(tester, l.kidsLettersTraceCta);
      await tester.pump();
      expect(find.text(l.kidsLettersTraceHint), findsOneWidget);
      final g = await tester.startGesture(tester.getCenter(find.byType(TraceCanvas)) - const Offset(100, 100));
      for (var i = 0; i < 60; i++) {
        await g.moveBy(const Offset(8, 6));
      }
      await g.up();
      await tester.pump();
      expect(find.text(l.kidsLettersTraceGood), findsOneWidget);
      expectNoWrongWording(tester);
      await tester.tap(find.text(l.kidsLettersTraceClear));
      await tester.pump();
      expect(find.text(l.kidsLettersTraceHint), findsOneWidget);
    });

    testWidgets('quiz: a miss shows the soft amber retry and no wrong wording; the right answer goes on; five earn one star', (tester) async {
      setPhone(tester, height: 900);
      await tester.pumpWidget(kidsApp(const LettersScreen(quizSeed: 5), overrides: overrides));
      await tester.pump();
      final l = L10n.of(tester.element(find.byType(LettersScreen)));
      await tapText(tester, l.kidsLettersQuizCta);
      await tester.pump();

      for (var round = 0; round < kLetterQuizRound; round++) {
        // Work out the target from the engine with the same seed is brittle:
        // instead tap choices until "well done" appears; a miss must be soft.
        final choices = find.byWidgetPredicate((w) => w is Semantics && w.properties.button == true && w.properties.label != null && arabicLetters.any((a) => a.name == w.properties.label));
        expect(choices, findsNWidgets(3));
        var tapped = 0;
        while (find.text(l.kidsLettersQuizGood).evaluate().isEmpty) {
          await tester.tap(choices.at(tapped++));
          await tester.pump();
          if (find.text(l.kidsLettersQuizGood).evaluate().isEmpty) {
            expect(find.text(l.kidsLettersQuizRetry), findsOneWidget);
            expectNoWrongWording(tester);
          }
          expect(tapped, lessThanOrEqualTo(3));
        }
        expect(stars, isEmpty, reason: 'the star comes at the end of the round only');
        await tapText(tester, l.kidsLettersQuizNext);
        await tester.pump();
      }
      expect(find.text(l.kidsLettersQuizDone), findsOneWidget);
      expect(stars, ['letters_quiz']);
    });

    testWidgets('the system back button leaves tracing for the letter card, not the section', (tester) async {
      setPhone(tester, height: 900);
      await tester.pumpWidget(kidsApp(const LettersScreen(), overrides: overrides));
      await tester.pump();
      final l = L10n.of(tester.element(find.byType(LettersScreen)));
      await tapText(tester, l.kidsLettersTraceCta);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text(l.kidsLettersTraceCta), findsOneWidget);
    });
  });

  group('maths', () {
    testWidgets('multiplication shows the sum with Arabic-Indic digits, the dot array and three big answers', (tester) async {
      setPhone(tester, height: 900);
      await tester.pumpWidget(kidsApp(const MathsScreen(seed: 1), overrides: overrides));
      await tester.pump();
      expect(find.textContaining('×'), findsOneWidget);
      final sum = tester.widget<Text>(find.textContaining('×')).data!;
      expect(RegExp(r'[0-9]').hasMatch(sum), isFalse, reason: 'Western digits in Arabic: $sum');
      expect(RegExp(r'[٠-٩]').hasMatch(sum), isTrue);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('English shows Western digits', (tester) async {
      setPhone(tester, height: 900);
      await tester.pumpWidget(kidsApp(const MathsScreen(seed: 1), locale: const Locale('en'), overrides: overrides));
      await tester.pump();
      final sum = tester.widget<Text>(find.textContaining('×')).data!;
      expect(RegExp(r'[٠-٩]').hasMatch(sum), isFalse);
    });

    testWidgets('a set of five: misses are soft, each miss fades its answer, a finished set earns exactly one star', (tester) async {
      setPhone(tester, height: 900);
      await tester.pumpWidget(kidsApp(const MathsScreen(seed: 2), overrides: overrides));
      await tester.pump();
      final l = L10n.of(tester.element(find.byType(MathsScreen)));
      final choice = find.byWidgetPredicate((w) => w is Semantics && w.properties.button == true && (w.properties.label ?? '').startsWith('الجواب'));

      for (var n = 0; n < kMathsSetSize; n++) {
        expect(choice, findsNWidgets(3));
        var tapped = 0;
        while (find.text(l.kidsMathsGood).evaluate().isEmpty) {
          await tester.tap(choice.at(tapped++));
          await tester.pump();
          if (find.text(l.kidsMathsGood).evaluate().isEmpty) {
            expect(find.text(l.kidsMathsTryAgain), findsOneWidget);
            expectNoWrongWording(tester);
          }
          expect(tapped, lessThanOrEqualTo(3));
        }
        expect(stars, isEmpty);
        await tapText(tester, l.kidsMathsNext);
        await tester.pump();
      }
      expect(find.text(l.kidsMathsSetDone), findsOneWidget);
      expect(stars, ['maths_set']);
      await tester.tap(find.text(l.kidsMathsNewSet));
      await tester.pump();
      expect(find.text(l.kidsMathsSetDone), findsNothing);
      expect(stars, hasLength(1));
    });

    for (final tab in [1, 2]) {
      testWidgets('tab $tab (${MathsKind.values[tab].name}) renders and its speaker calls the voice', (tester) async {
        setPhone(tester, height: 900);
        await tester.pumpWidget(kidsApp(const MathsScreen(seed: 8, initialTab: 0), overrides: overrides));
        await tester.pump();
        final l = L10n.of(tester.element(find.byType(MathsScreen)));
        await tester.tap(find.text(tab == 1 ? l.kidsMathsTabDiv : l.kidsMathsTabFrac));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.volume_up_rounded));
        expect(voice.played.single, startsWith('maths_'));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('layout: RTL, text scale 1.3, 320 dp wide', () {
    for (final scale in [1.0, 1.3]) {
      for (final lang in ['ar', 'en']) {
        testWidgets('letters + quiz + trace at ${scale}x $lang have no overflow', (tester) async {
          setPhone(tester, width: 320, height: 640);
          await tester.pumpWidget(kidsApp(const LettersScreen(initialIndex: 17, quizSeed: 3), textScale: scale, locale: Locale(lang), overrides: overrides));
          await tester.pump();
          expect(tester.takeException(), isNull);
          final l = L10n.of(tester.element(find.byType(LettersScreen)));
          await tapText(tester, l.kidsLettersQuizCta);
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.binding.handlePopRoute();
          await tester.pump();
          await tapText(tester, l.kidsLettersTraceCta);
          await tester.pump();
          expect(tester.takeException(), isNull);
        });

        testWidgets('maths (all three tabs) at ${scale}x $lang have no overflow', (tester) async {
          setPhone(tester, width: 320, height: 640);
          await tester.pumpWidget(kidsApp(const MathsScreen(seed: 4), textScale: scale, locale: Locale(lang), overrides: overrides));
          await tester.pump();
          final l = L10n.of(tester.element(find.byType(MathsScreen)));
          for (final t in [l.kidsMathsTabDiv, l.kidsMathsTabFrac, l.kidsMathsTabMul]) {
            await tester.tap(find.text(t));
            await tester.pump();
            expect(tester.takeException(), isNull, reason: t);
          }
        });
      }
    }
  });

  testWidgets('every big button and round button is at least 64 dp, at text scale 1.3 too', (tester) async {
    setPhone(tester, width: 320, height: 900);
    await tester.pumpWidget(kidsApp(const LettersScreen(initialIndex: 3), textScale: 1.3, overrides: overrides));
    await tester.pump();
    for (final type in [KidsButton, KidsRoundButton, SpeakerButton]) {
      for (final e in find.byType(type).evaluate()) {
        final size = tester.getSize(find.byWidget(e.widget));
        expect(size.height, greaterThanOrEqualTo(64), reason: '$type');
        expect(size.width, greaterThanOrEqualTo(64), reason: '$type');
      }
    }
    // the letter strip chips
    final chip = tester.getSize(find.bySemanticsLabel('ثاء').first);
    expect(chip.shortestSide, greaterThanOrEqualTo(64));
  });
}
