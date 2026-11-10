import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/kids/core/kids_section.dart';
import 'package:madar/features/kids/games/domain/pairs_game.dart';
import 'package:madar/features/kids/games/games.dart';
import 'package:madar/features/kids/games/presentation/games_screen.dart';
import 'package:madar/features/kids/games/presentation/pairs_play_screen.dart';

import '../../../helpers/screenshot_harness.dart' show loadMadarFonts;

/// Indexes of the two cards that show picture [symbol].
List<int> _pairOf(PairsGame g, int symbol) => [
  for (var i = 0; i < g.deck.length; i++)
    if (g.deck[i] == symbol) i,
];

/// Two positions holding different pictures.
(int, int) _mismatch(PairsGame g) {
  for (var j = 1; j < g.deck.length; j++) {
    if (g.deck[j] != g.deck[0]) return (0, j);
  }
  throw StateError('no mismatch');
}

void main() {
  group('sizes and the deal', () {
    test('three sizes: 6, 8 and 12 pairs', () {
      expect([for (final s in PairsSize.values) s.pairs], [6, 8, 12]);
      for (final s in PairsSize.values) {
        final g = PairsGame(size: s, seed: 1);
        expect(g.deck.length, s.pairs * 2);
        expect(s.cards, s.columns * s.rows - (s.columns * s.rows - s.cards));
        expect(s.columns * s.rows, greaterThanOrEqualTo(s.cards));
      }
    });

    test('every picture appears exactly twice, and only 6/8/12 different ones', () {
      for (final s in PairsSize.values) {
        final g = PairsGame(size: s, seed: 42);
        final counts = <int, int>{};
        for (final c in g.deck) {
          counts[c] = (counts[c] ?? 0) + 1;
        }
        expect(counts.length, s.pairs);
        expect(counts.values.every((n) => n == 2), isTrue);
        expect(counts.keys.every((k) => k >= 0 && k < pairSymbolCount), isTrue);
      }
    });

    test('the shuffle is seeded: same seed same deck, another seed another deck', () {
      final a = PairsGame(size: PairsSize.large, seed: 7).deck;
      expect(PairsGame(size: PairsSize.large, seed: 7).deck, a);
      expect(PairsGame(size: PairsSize.large, seed: 8).deck, isNot(a));
    });

    test('the deck cannot be changed from outside', () {
      final g = PairsGame(size: PairsSize.small, seed: 1);
      expect(() => g.deck[0] = 3, throwsUnsupportedError);
    });
  });

  group('flipping', () {
    test('a first flip waits, a matching second flip keeps the pair open', () {
      final g = PairsGame(size: PairsSize.small, seed: 3);
      final p = _pairOf(g, g.deck[0]);
      expect(g.flip(p[0]), FlipResult.flipped);
      expect(g.isFaceUp(p[0]), isTrue);
      expect(g.flip(p[1]), FlipResult.matched);
      expect(g.isMatched(p[0]) && g.isMatched(p[1]), isTrue);
      expect(g.matchedPairs, 1);
      expect(g.hasPendingMiss, isFalse);
    });

    test('a different second card is a miss: both wait, then turn back with settle', () {
      final g = PairsGame(size: PairsSize.small, seed: 3);
      final (a, b) = _mismatch(g);
      g.flip(a);
      expect(g.flip(b), FlipResult.missed);
      expect(g.hasPendingMiss, isTrue);
      expect(g.isFaceUp(a) && g.isFaceUp(b), isTrue);
      g.settle();
      expect(g.isFaceUp(a) || g.isFaceUp(b), isFalse);
      expect(g.matchedPairs, 0);
    });

    test('no double-flip bugs: the same card twice, a matched card, out of range', () {
      final g = PairsGame(size: PairsSize.small, seed: 3);
      expect(g.flip(0), FlipResult.flipped);
      expect(g.flip(0), FlipResult.ignored, reason: 'tapping the open card again does not pair it with itself');
      expect(g.moves, 0);
      expect(g.flip(-1), FlipResult.ignored);
      expect(g.flip(99), FlipResult.ignored);
      final p = _pairOf(g, g.deck[0]);
      expect(g.flip(p[1]), FlipResult.matched);
      expect(g.flip(p[0]), FlipResult.ignored, reason: 'a matched card stays put');
      expect(g.flip(p[1]), FlipResult.ignored);
    });

    test('a third tap while a miss is showing turns the miss back and opens the new card', () {
      final g = PairsGame(size: PairsSize.small, seed: 3);
      final (a, b) = _mismatch(g);
      g.flip(a);
      g.flip(b);
      final c = [
        for (var i = 0; i < g.deck.length; i++)
          if (i != a && i != b) i,
      ].first;
      expect(g.flip(c), FlipResult.flipped);
      expect(g.isFaceUp(a), isFalse);
      expect(g.isFaceUp(b), isFalse);
      expect(g.isFaceUp(c), isTrue);
    });

    test('a late timer cannot turn back a newer card or pair (settleIf)', () {
      final g = PairsGame(size: PairsSize.small, seed: 3);
      final (a, b) = _mismatch(g);
      g.flip(a);
      g.flip(b);
      final old = g.missSerial;
      // The child taps ahead: a third card opens, the old timer is now stale.
      final c = [
        for (var i = 0; i < g.deck.length; i++)
          if (i != a && i != b) i,
      ].first;
      g.flip(c);
      expect(g.settleIf(old), isFalse, reason: 'only one card is open, nothing to turn back');
      expect(g.isFaceUp(c), isTrue);
      // A fresh miss, then the OLD serial arrives: must not touch it.
      final partner = [
        for (var i = 0; i < g.deck.length; i++)
          if (i != c && g.deck[i] != g.deck[c]) i,
      ].first;
      expect(g.flip(partner), FlipResult.missed);
      expect(g.settleIf(old), isFalse);
      expect(g.hasPendingMiss, isTrue);
      expect(g.settleIf(g.missSerial), isTrue);
      expect(g.hasPendingMiss, isFalse);
    });

    test('settle with nothing waiting changes nothing', () {
      final g = PairsGame(size: PairsSize.small, seed: 3);
      g.flip(0);
      g.settle();
      expect(g.isFaceUp(0), isTrue, reason: 'a lone open card is not a miss');
    });
  });

  group('winning', () {
    for (final size in PairsSize.values) {
      test('${size.pairs} pairs: won exactly when the last pair is found; no timer, no loss', () {
        final g = PairsGame(size: size, seed: 11);
        final symbols = g.deck.toSet().toList();
        for (var i = 0; i < symbols.length; i++) {
          expect(g.won, isFalse);
          // A miss now and then does not hurt.
          if (i == 1 && symbols.length > 1) {
            final (a, b) = _mismatch(g);
            g.flip(a);
            g.flip(b);
            g.settle();
          }
          final p = _pairOf(g, symbols[i]);
          g.flip(p[0]);
          g.flip(p[1]);
          expect(g.matchedPairs, i + 1);
        }
        expect(g.won, isTrue);
        expect(g.matchedPairs, size.pairs);
      });
    }

    test('a clumsy, forgetful player still finishes: no clock, no lives, nothing to lose', () {
      final g = PairsGame(size: PairsSize.small, seed: 5);
      final rnd = math.Random(1);
      var guard = 0;
      while (!g.won && guard++ < 5000) {
        final open = [
          for (var i = 0; i < g.deck.length; i++)
            if (!g.isMatched(i)) i,
        ];
        final a = open[rnd.nextInt(open.length)];
        var b = open[rnd.nextInt(open.length)];
        while (b == a) {
          b = open[rnd.nextInt(open.length)];
        }
        g.flip(a);
        g.flip(b);
        g.settle();
      }
      expect(g.won, isTrue);
      expect(g.moves, greaterThanOrEqualTo(g.size.pairs));
    });
  });

  group('screens', () {
    Future<void> pumpApp(
      WidgetTester tester,
      Widget home, {
      int stars = 0,
      void Function(String)? onAward,
      double scale = 1,
      Size size = const Size(360, 780),
      Locale locale = const Locale('ar'),
    }) async {
      await tester.runAsync(loadMadarFonts);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var count = stars;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            kidsStarCountProvider.overrideWith((ref) => count),
            kidsStarAwardProvider.overrideWith(
              (ref) => (reason) async {
                onAward?.call(reason);
              },
            ),
          ],
          child: MaterialApp(
            locale: locale,
            supportedLocales: L10n.supportedLocales,
            localizationsDelegates: L10n.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: home,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('hub: three sizes, play opens the board of the chosen size', (tester) async {
      await pumpApp(tester, const GamesScreen(seed: 1));
      expect(find.text('٦ أزواج'), findsOneWidget);
      expect(find.text('٨ أزواج'), findsOneWidget);
      expect(find.text('١٢ زوجًا'), findsOneWidget);
      await tester.tap(find.text('٨ أزواج'));
      await tester.pump();
      await tester.ensureVisible(find.text('العب'));
      await tester.tap(find.text('العب'));
      await tester.pumpAndSettle();
      expect(find.byType(PairsPlayScreen), findsOneWidget);
      expect(find.textContaining('من ٨'), findsOneWidget);
    });

    testWidgets('a full game: a miss is kind, no "wrong", and the win awards one star', (tester) async {
      final awards = <String>[];
      await pumpApp(
        tester,
        const PairsPlayScreen(size: PairsSize.small, seed: 9, cardTurn: Duration.zero),
        onAward: awards.add,
      );
      final g = PairsGame(size: PairsSize.small, seed: 9); // same deal as the screen
      final cards = find.bySemanticsLabel(RegExp('بطاقة رقم'));
      expect(cards, findsNWidgets(12));
      Future<void> tapCard(int i) async {
        // Cards are in a grid in deck order.
        await tester.tap(find.byKey(ValueKey('pair-card-$i')));
        await tester.pump();
      }

      final (a, b) = _mismatch(g);
      await tapCard(a);
      await tapCard(b);
      expect(
        find.textContaining('جرّب').evaluate().isNotEmpty || find.textContaining('تذكّر').evaluate().isNotEmpty,
        isTrue,
      );
      expect(find.textContaining('غلط'), findsNothing);
      await tester.pump(const Duration(seconds: 1)); // the pair turns back by itself

      for (final s in g.deck.toSet()) {
        final p = _pairOf(g, s);
        await tapCard(p[0]);
        await tapCard(p[1]);
      }
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('أحسنت!'), findsWidgets);
      expect(awards, ['game.pairs']);
      expect(find.text('العب مرّة ثانية'), findsOneWidget);
    });

    testWidgets('12 pairs at 320 dp, text scale 1.3: no overflow', (tester) async {
      await pumpApp(
        tester,
        const PairsPlayScreen(size: PairsSize.large, seed: 2),
        scale: 1.3,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      await pumpApp(tester, const GamesScreen(), scale: 1.3, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      await pumpApp(tester, const GamesScreen(), scale: 1.3, size: const Size(320, 640), locale: const Locale('en'));
      expect(tester.takeException(), isNull);
    });

    test('the section', () {
      expect(gamesSection.id, 'games');
      expect(gamesSection.religious, isFalse);
    });
  });
}
