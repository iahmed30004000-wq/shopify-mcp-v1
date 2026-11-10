// A hearing the engine is unsure about is NEVER a mistake.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/kids/core/kids_section.dart';
import 'package:madar/features/kids/faith/domain/recitation_check.dart';
import 'package:madar/features/kids/faith/presentation/kids_recitation_screen.dart';

import 'faith_harness.dart';

class _Checker implements KidsRecitationChecker {
  _Checker(this.script);
  final List<Object> script; // double confidence | Exception to throw
  int calls = 0;

  @override
  Future<KidsRecitationResult> listen({required String expectedText}) async {
    final next = script[calls < script.length ? calls : script.length - 1];
    calls++;
    if (next is Exception) throw next;
    return KidsRecitationResult(confidence: next as double, wordsHeard: const ['x']);
  }
}

const _target = ('78:3', 'AYAH-TEXT one two');

({ProviderContainer c, List<String> stars, _Checker checker}) _setup(List<Object> script) {
  final checker = _Checker(script);
  final stars = <String>[];
  final c = ProviderContainer(
    overrides: [
      kidsRecitationCheckerProvider.overrideWithValue(checker),
      kidsStarAwardProvider.overrideWithValue((reason) async => stars.add(reason)),
    ],
  );
  addTearDown(c.dispose);
  c.listen(kidsRecitationControllerProvider(_target), (_, _) {});
  return (c: c, stars: stars, checker: checker);
}

bool _redish(Color c) => c.r > 0.65 && c.g < 0.4 && c.b < 0.4;

void main() {
  group('the rule', () {
    test('below the threshold is "try again", at or above it is "well done"', () {
      KidsRecitationPhase j(double c) => judgeKidsRecitation(KidsRecitationResult(confidence: c));
      expect(j(0), KidsRecitationPhase.tryAgain);
      expect(j(kidsRecitationThreshold - 0.001), KidsRecitationPhase.tryAgain);
      expect(j(kidsRecitationThreshold), KidsRecitationPhase.wellDone);
      expect(j(1), KidsRecitationPhase.wellDone);
      expect(j(double.nan), KidsRecitationPhase.tryAgain);
    });

    test('there is no "wrong" outcome at all', () {
      expect(
        KidsRecitationPhase.values.map((p) => p.name),
        unorderedEquals(['idle', 'listening', 'tryAgain', 'wellDone']),
      );
    });

    test('a low-confidence hearing awards nothing and ends in try-again', () async {
      final s = _setup([0.2]);
      await s.c.read(kidsRecitationControllerProvider(_target).notifier).listen();
      expect(s.c.read(kidsRecitationControllerProvider(_target)), KidsRecitationPhase.tryAgain);
      expect(s.stars, isEmpty);
    });

    test('ten taps on «عيد» never escalate, never award, never change the state', () async {
      final s = _setup([0.1]);
      final ctrl = s.c.read(kidsRecitationControllerProvider(_target).notifier);
      for (var i = 0; i < 10; i++) {
        await ctrl.listen();
        expect(s.c.read(kidsRecitationControllerProvider(_target)), KidsRecitationPhase.tryAgain);
      }
      expect(s.checker.calls, 10);
      expect(s.stars, isEmpty);
    });

    test('an engine failure (no microphone, a call) is the same soft try-again', () async {
      final s = _setup([Exception('mic busy')]);
      await s.c.read(kidsRecitationControllerProvider(_target).notifier).listen();
      expect(s.c.read(kidsRecitationControllerProvider(_target)), KidsRecitationPhase.tryAgain);
      expect(s.stars, isEmpty);
    });

    test('a confident hearing awards ONE star, even if the child repeats it', () async {
      final s = _setup([0.9, 0.95]);
      final ctrl = s.c.read(kidsRecitationControllerProvider(_target).notifier);
      await ctrl.listen();
      await ctrl.listen();
      expect(s.c.read(kidsRecitationControllerProvider(_target)), KidsRecitationPhase.wellDone);
      expect(s.stars, ['kids_recitation:78:3']);
    });

    test('tries after a failure still earn the star later (nothing was counted against him)', () async {
      final s = _setup([0.1, 0.1, 0.1, 0.8]);
      final ctrl = s.c.read(kidsRecitationControllerProvider(_target).notifier);
      for (var i = 0; i < 4; i++) {
        await ctrl.listen();
      }
      expect(s.stars, hasLength(1));
    });

    test('with no engine installed, listen does nothing', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.listen(kidsRecitationControllerProvider(_target), (_, _) {});
      await c.read(kidsRecitationControllerProvider(_target).notifier).listen();
      expect(c.read(kidsRecitationControllerProvider(_target)), KidsRecitationPhase.idle);
    });
  });

  group('the screen', () {
    Future<_Checker> pump(WidgetTester tester, List<Object> script, List<String> stars) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final checker = _Checker(script);
      await tester.pumpWidget(
        faithApp(
          const KidsRecitationScreen(ayahKey: '78:3', ayahText: 'AYAH-TEXT one two'),
          overrides: [
            kidsRecitationCheckerProvider.overrideWithValue(checker),
            kidsStarAwardProvider.overrideWithValue((r) async => stars.add(r)),
            kidsStarCountProvider.overrideWithValue(25),
          ],
        ),
      );
      return checker;
    }

    void expectNoRed(WidgetTester tester) {
      for (final e in find.byType(Text).evaluate()) {
        final c = (e.widget as Text).style?.color;
        if (c != null) expect(_redish(c), isFalse, reason: 'red text ${(e.widget as Text).data}');
      }
      for (final e in find.byType(DecoratedBox).evaluate()) {
        final d = (e.widget as DecoratedBox).decoration;
        if (d is BoxDecoration) {
          if (d.color != null) expect(_redish(d.color!), isFalse);
          final b = d.border;
          if (b is Border) expect(_redish(b.top.color), isFalse);
        }
      }
    }

    testWidgets('low confidence: «ما سمعت منيح، عيد» in amber, no star, no red, tap «عيد» ten times', (tester) async {
      final stars = <String>[];
      await pump(tester, [0.1], stars);
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();
      expect(find.text('ما سمعت منيح، عيد'), findsOneWidget);
      expect(find.text('نجومك محفوظة زي ما هي'), findsOneWidget);
      expectNoRed(tester);

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('عيد'));
        await tester.pump();
        expect(find.text('ما سمعت منيح، عيد'), findsOneWidget);
      }
      expect(stars, isEmpty);
      expect(find.text('أحسنت!'), findsNothing);

      // The soft card is amber: its decoration uses the retry colours.
      final card = tester.widget<DecoratedBox>(
        find.ancestor(of: find.text('ما سمعت منيح، عيد'), matching: find.byType(DecoratedBox)).first,
      );
      expect((card.decoration as BoxDecoration).color, const Color(0xFFFFEBD0));
    });

    testWidgets('high confidence: «أحسنت!» in teal and one star through the seam', (tester) async {
      final stars = <String>[];
      await pump(tester, [0.95], stars);
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();
      await tester.pump();
      expect(find.text('أحسنت!'), findsOneWidget);
      expect(find.text('ما سمعت منيح، عيد'), findsNothing);
      expect(stars, ['kids_recitation:78:3']);
      expectNoRed(tester);
    });

    testWidgets('buttons are at least 48 dp and the screen survives text scale 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        faithApp(
          const KidsRecitationScreen(ayahKey: '78:3', ayahText: 'AYAH-TEXT one two'),
          textScale: 1.3,
          overrides: [
            kidsRecitationCheckerProvider.overrideWithValue(_Checker([0.1])),
          ],
        ),
      );
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final f in [find.byIcon(Icons.mic_rounded), find.byIcon(Icons.home_rounded)]) {
        final box = tester.getSize(find.ancestor(of: f, matching: find.byType(InkWell)).first);
        expect(box.width, greaterThanOrEqualTo(48));
        expect(box.height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('no engine installed: the calm «قريبًا», no microphone', (tester) async {
      await tester.pumpWidget(faithApp(const KidsRecitationScreen(ayahKey: '78:3', ayahText: 'X')));
      expect(find.text('قريبًا'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
    });
  });
}
