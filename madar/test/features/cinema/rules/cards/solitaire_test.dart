// Solitaire (سوليتير, Klondike): one test per rule and scoring line of the
// Madar spec (§2–§4), named after the rule ids (S-…).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/core/card_game.dart' show AiLevel;
import 'package:madar/features/cinema/rules/cards/core/card_rng.dart';
import 'package:madar/features/cinema/rules/cards/core/deck.dart';
import 'package:madar/features/cinema/rules/cards/core/playing_card.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_board.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_game.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_options.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_solver.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_stats.dart';

List<PlayingCard> cards(String ids) => ids.trim().isEmpty ? <PlayingCard>[] : PlayingCard.list(ids);

/// No automatic moves: each test sees exactly the action it plays.
const manual = SolitaireOptions(autoMoveToFoundation: SolitaireAutoMove.off);

const waste = SolitairePile.waste;
SolitairePile col(int i) => SolitairePile.column(i);
SolitairePile home(int i) => SolitairePile.foundation(i);
SolitaireAction mv(SolitairePile from, SolitairePile to, [int count = 1]) =>
    SolitaireAction.move(from, to, count: count);

/// All 13 cards of [suit] from the ace up to [upTo], as ids.
String suitUpTo(String suit, int upTo) =>
    ['A', '2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K'].take(upTo).map((r) => '$r$suit').join(' ');

/// A position: [columns] deepest card first, [down] face-down counts,
/// [stock] and [waste] with the top card last, [foundations] by place.
SolitaireGame position({
  List<String> columns = const [],
  List<int> down = const [],
  String stock = '',
  String wastePile = '',
  List<String> foundations = const [],
  SolitaireOptions options = manual,
  int score = 0,
  int recycles = 0,
}) => SolitaireGame.custom(
  SolitaireBoard.fromPiles(
    columns: [for (final s in columns) cards(s)],
    faceDown: down,
    stock: cards(stock),
    waste: cards(wastePile),
    foundations: [for (final s in foundations) cards(s), for (var i = foundations.length; i < 4; i++) <PlayingCard>[]],
    recycles: recycles,
  ),
  options: options,
  score: score,
);

List<SolitaireEventType> types(SolitaireGame g) => [for (final e in g.lastEvents) e.type];

void play(SolitaireGame g, SolitaireAction a) {
  final error = g.validate(a);
  expect(error, isNull, reason: '$a');
  expect(g.apply(a), isTrue);
}

void main() {
  group('presets and options (§3)', () {
    test('const SolitaireOptions() is the Jordan preset with every §3.1 value', () {
      const o = SolitaireOptions();
      expect(o, const SolitaireOptions.jordan());
      expect(o.drawCount, 1);
      expect(o.passLimit, isNull);
      expect(o.scoring, SolitaireScoring.standard);
      expect(o.draw3PenaltyFromRecycle, 3);
      expect(o.timedScoring, isFalse);
      expect(o.allowFoundationToTableau, isTrue);
      expect(o.autoFlip, isTrue);
      expect(o.autoMoveToFoundation, SolitaireAutoMove.safeOnly);
      expect(o.autoCompleteWithStock, isFalse);
      expect(o.winnableOnly, isFalse);
      expect(o.solverHints, isFalse);
      expect(o.undoPenalty, 0);
      expect(o.hintLevel, AiLevel.hard);
    });

    test('§3.2 presets differ from the default only as listed', () {
      const base = SolitaireOptions();
      expect(const SolitaireOptions.easy(), base.copyWith(winnableOnly: true, autoCompleteWithStock: true));
      expect(const SolitaireOptions.hard(), base.copyWith(drawCount: 3));
      expect(const SolitaireOptions.expert(), base.copyWith(drawCount: 3, passLimit: 3));
      expect(
        const SolitaireOptions.windowsClassic(),
        base.copyWith(drawCount: 3, timedScoring: true, autoMoveToFoundation: SolitaireAutoMove.off),
      );
    });

    test('options survive JSON', () {
      for (final o in [
        const SolitaireOptions(),
        const SolitaireOptions.expert(),
        const SolitaireOptions.windowsClassic(),
        const SolitaireOptions(
          passLimit: 1,
          scoring: SolitaireScoring.none,
          draw3PenaltyFromRecycle: 4,
          allowFoundationToTableau: false,
          autoFlip: false,
          autoMoveToFoundation: SolitaireAutoMove.always,
          undoPenalty: 5,
          hintLevel: AiLevel.easy,
        ),
      ]) {
        expect(SolitaireOptions.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, Object?>), o);
      }
      expect(const SolitaireOptions.expert().copyWith(unlimitedPasses: true).passLimit, isNull);
    });
  });

  group('cards and the deal (S-1…S-5)', () {
    test('S-1 aces are low (A = 1 … K = 13); hearts and diamonds are red', () {
      expect(solitaireRank(PlayingCard.parse('AS')), 1);
      expect(solitaireRank(PlayingCard.parse('TD')), 10);
      expect(solitaireRank(PlayingCard.parse('KH')), 13);
      expect(isRedCard(PlayingCard.parse('5H')), isTrue);
      expect(isRedCard(PlayingCard.parse('5D')), isTrue);
      expect(isRedCard(PlayingCard.parse('5C')), isFalse);
      expect(isRedCard(PlayingCard.parse('5S')), isFalse);
    });

    test('S-2/S-3 seven columns of 1…7 cards, the last one up; 24 in the stock; waste and foundations empty', () {
      final g = SolitaireGame.newDeal(seed: 1);
      final s = g.state;
      expect([for (final c in s.columns) c.length], [1, 2, 3, 4, 5, 6, 7]);
      expect(s.faceDown, [0, 1, 2, 3, 4, 5, 6]);
      expect(s.stock.length, 24);
      expect(s.waste, isEmpty);
      expect(s.foundations.every((f) => f.isEmpty), isTrue);
      expect(sortedCards(s.board.allCards()), sortedCards(buildDeck()));
    });

    test('S-4 the deal goes in rows and the next card is the top of the stock', () {
      final d = buildDeck();
      final b = SolitaireBoard.deal(d);
      expect(b.column(0), [d[0]]);
      expect(b.column(1), [d[1], d[7]]);
      expect(b.column(3), [d[3], d[9], d[14], d[18]]);
      expect(b.column(6), [d[6], d[12], d[17], d[21], d[24], d[26], d[27]]);
      expect(b.stock.last, d[28]);
      expect(b.stock.first, d[51]);
      final shuffled = buildDeck();
      CardRng(77).shuffle(shuffled);
      expect(
        jsonEncode(SolitaireGame.newDeal(seed: 77).toJson()['state']),
        jsonEncode(SolitaireGame.custom(SolitaireBoard.deal(shuffled)).toJson()['state']),
      );
    });

    test('S-5 any ace starts any empty foundation; a tap uses the leftmost empty place', () {
      final g = position(wastePile: 'AH', foundations: ['AS']);
      expect(g.legalActions(), contains(mv(waste, home(1))));
      expect(g.sendHomeAction(waste), mv(waste, home(1)));
      expect(g.sendHomeAction(col(0)), isNull);
      expect(g.validate(mv(waste, home(3))), isNull);
      play(g, mv(waste, home(3)));
      expect(g.state.foundations[3], cards('AH'));
    });
  });

  group('moves (S-10…S-17)', () {
    test('S-10 foundations go up by suit, one card at a time, never from another foundation', () {
      final g = position(columns: ['3H', '3S', '4C 3D', '2D'], foundations: ['AS 2S', 'AD']);
      expect(g.validate(mv(col(0), home(0))), 'doesNotFitFoundation');
      expect(g.validate(mv(col(1), home(0))), isNull);
      expect(g.validate(mv(col(2), home(1), 2)), 'oneCardHome');
      expect(g.validate(mv(home(1), home(2))), 'illegalMove');
      expect(g.validate(mv(col(3), home(2))), 'doesNotFitFoundation');
      expect(g.validate(mv(col(3), home(1))), isNull);
    });

    test('S-11/S-12 any face-up run moves onto a card one higher of the other colour', () {
      final g = position(columns: ['QD 9H 8S 7H', '9D', '8C', '8D'], down: [1]);
      expect(g.validate(mv(col(0), col(1), 2)), isNull);
      expect(g.validate(mv(col(0), col(2))), isNull);
      expect(g.validate(mv(col(0), col(3))), 'doesNotFitColumn');
      expect(g.validate(mv(col(0), col(0))), 'sameColumn');
      play(g, mv(col(0), col(1), 2));
      expect(g.state.columns[1], cards('9D 8S 7H'));
      expect(g.state.columns[0], cards('QD 9H'));
      expect(g.state.faceDown[0], 1);
    });

    test('S-12 a run cannot start at a face-down card', () {
      final g = position(columns: ['QD 9H 8S', 'KC'], down: [1]);
      expect(g.validate(mv(col(0), col(1), 3)), 'faceDownCard');
    });

    test('S-13 an empty column refuses a queen-headed run and takes a king from the waste, a foundation or a column', () {
      final queen = position(columns: ['', 'QS JH']);
      expect(queen.validate(mv(col(1), col(0), 2)), 'onlyKingOnEmpty');
      final fromWaste = position(columns: [''], wastePile: 'KS');
      expect(fromWaste.validate(mv(waste, col(0))), isNull);
      final fromHome = position(columns: [''], foundations: [suitUpTo('D', 13)]);
      expect(fromHome.validate(mv(home(0), col(0))), isNull);
      final fromColumn = position(columns: ['', '5C KH QS'], down: [0, 1]);
      expect(fromColumn.validate(mv(col(1), col(0), 2)), isNull);
    });

    test('S-14 a face-down card left at the end of a column turns up by itself (+5)', () {
      final g = position(columns: ['8C 7H', '8S'], down: [1]);
      play(g, mv(col(0), col(1)));
      expect(g.state.faceDown[0], 0);
      expect(types(g), [SolitaireEventType.cardsMoved, SolitaireEventType.cardTurnedUp]);
      expect(g.state.score, 5);
    });

    test('S-14 with autoFlip off the card stays down until the flip action; nothing goes onto it', () {
      final g = position(columns: ['8C 7H', '8S', '7D'], down: [1], options: manual.copyWith(autoFlip: false));
      play(g, mv(col(0), col(1)));
      expect(g.state.faceDown[0], 1);
      expect(g.validate(mv(col(2), col(0))), 'doesNotFitColumn');
      expect(g.legalActions(), contains(const SolitaireAction.flip(0)));
      play(g, const SolitaireAction.flip(0));
      expect(g.state.faceDown[0], 0);
      expect(g.state.score, 5);
      expect(g.validate(const SolitaireAction.flip(0)), 'nothingToTurn');
    });

    test('S-15 only the top waste card can move', () {
      final g = position(columns: ['6C'], wastePile: 'AH 5H');
      expect(g.validate(mv(waste, col(0), 2)), 'onlyTopWasteCard');
      expect(g.validate(mv(waste, col(0))), isNull);
    });

    test('S-16 foundation to column: the top card, onto an accepting column only; option off locks it', () {
      final g = position(columns: ['4S', '4H', ''], foundations: ['AH 2H 3H'], score: 20);
      expect(g.validate(mv(home(0), col(1))), 'doesNotFitColumn');
      expect(g.validate(mv(home(0), col(2))), 'onlyKingOnEmpty');
      expect(g.validate(mv(home(0), col(0), 2)), 'illegalMove');
      play(g, mv(home(0), col(0)));
      expect(g.state.columns[0], cards('4S 3H'));
      expect(g.state.foundations[0], cards('AH 2H'));
      final locked = position(
        columns: ['4S'],
        foundations: ['AH 2H 3H'],
        options: manual.copyWith(allowFoundationToTableau: false),
      );
      expect(locked.validate(mv(home(0), col(0))), 'foundationLocked');
      expect(locked.legalActions().where((a) => a.from?.isFoundation ?? false), isEmpty);
    });

    test('S-17 nothing goes back to the stock or the waste', () {
      final g = position(columns: ['5C'], wastePile: '6H');
      expect(g.validate(mv(col(0), waste)), 'illegalMove');
    });
  });

  group('stock, waste and passes (S-20…S-24)', () {
    test('S-20 draw one turns the top stock card onto the waste', () {
      final g = position(stock: 'AS 2S 3S');
      play(g, SolitaireAction.draw);
      expect(g.state.waste, cards('3S'));
      expect(g.state.stock, cards('AS 2S'));
      expect(types(g), [SolitaireEventType.stockDrawn]);
    });

    test('S-21 draw three turns three (the third on top), and exactly two when two are left', () {
      final g = position(stock: '2C 3C 4C 5C 6C', options: manual.copyWith(drawCount: 3));
      play(g, SolitaireAction.draw);
      expect(g.state.waste, cards('6C 5C 4C'));
      play(g, SolitaireAction.draw);
      expect(g.state.waste, cards('6C 5C 4C 3C 2C'));
      expect(g.lastEvents.single.cards, cards('3C 2C'));
      expect(g.state.stock, isEmpty);
    });

    test('S-21 in draw three the card under the played top card plays next', () {
      final g = position(columns: ['5H', '6H'], stock: '4S 5C 4C', options: manual.copyWith(drawCount: 3));
      play(g, SolitaireAction.draw); // waste 4C 5C 4S, top 4S
      play(g, mv(waste, col(0))); // 4S on 5H
      expect(g.validate(mv(waste, col(1))), isNull); // 5C on 6H
    });

    test('S-22 a recycle keeps the order; with stock and waste empty the stock does nothing', () {
      final g = position(stock: 'KC 7D 3S');
      for (var i = 0; i < 3; i++) {
        play(g, SolitaireAction.draw);
      }
      expect(g.validate(SolitaireAction.draw), 'stockEmpty');
      play(g, SolitaireAction.recycle);
      expect(g.state.stock, cards('KC 7D 3S'));
      play(g, SolitaireAction.draw);
      expect(g.state.waste, cards('3S'));
      final empty = position(columns: ['5C 4D'], down: [1]);
      expect(empty.tapStock(), isFalse);
      expect(empty.legalActions().any((a) => a.kind != SolitaireActionKind.move), isFalse);
      expect(empty.validate(SolitaireAction.recycle), 'wasteEmpty');
    });

    test('S-23 passLimit 1 allows no recycle, 3 allows exactly two, unlimited any number', () {
      for (final (limit, recycles) in [(1, 0), (3, 2), (null, 5)]) {
        final g = position(stock: 'KC 7D', options: manual.copyWith(passLimit: limit, unlimitedPasses: limit == null));
        var done = 0;
        for (var i = 0; i < 5; i++) {
          play(g, SolitaireAction.draw);
          play(g, SolitaireAction.draw);
          if (g.validate(SolitaireAction.recycle) != null) break;
          play(g, SolitaireAction.recycle);
          done++;
        }
        expect(done, recycles, reason: 'passLimit $limit');
        if (limit != null) expect(g.validate(SolitaireAction.recycle), 'noPassesLeft');
      }
    });

    test('S-24 there is no money scoring mode', () {
      expect(SolitaireScoring.values.map((v) => v.name), ['standard', 'none']);
    });
  });

  group('winning, auto-complete and auto-move (S-30…S-33)', () {
    SolitaireGame nearlyWon({SolitaireOptions options = manual, int score = 0}) => position(
      columns: ['KS', 'QS'],
      foundations: [suitUpTo('C', 13), suitUpTo('D', 13), suitUpTo('H', 13), suitUpTo('S', 11)],
      options: options,
      score: score,
    );

    test('S-30 the deal is won with 52 cards home; undo is then disabled', () {
      final g = nearlyWon();
      play(g, mv(col(1), home(3)));
      expect(g.isSolved, isFalse);
      play(g, mv(col(0), home(3)));
      expect(g.isSolved, isTrue);
      expect(g.isOver, isTrue);
      expect(types(g).last, SolitaireEventType.won);
      expect(g.canUndo, isFalse);
      expect(g.undo(), isFalse);
      expect(g.legalActions(), isEmpty);
      expect(g.validate(SolitaireAction.draw), 'gameWon');
    });

    SolitaireGame endgame({String stock = '', List<int> down = const [], SolitaireOptions options = manual}) =>
        position(
          columns: ['KC QD JS', 'KD QC', 'KH QS', 'KS', 'JC', 'TS'],
          down: down,
          stock: stock,
          foundations: [suitUpTo('C', 10), suitUpTo('D', 11), suitUpTo('H', 12), suitUpTo('S', 9)],
          options: options,
        );

    test('S-32 auto-complete with no face-down card and an empty stock: lowest rank first, ties leftmost', () {
      final g = endgame();
      expect(g.canAutoComplete, isTrue);
      play(g, SolitaireAction.autoComplete);
      expect(g.isSolved, isTrue);
      final homeCards = [
        for (final e in g.lastEvents)
          if (e.type == SolitaireEventType.toFoundation) e.cards.single,
      ];
      expect(homeCards, cards('TS JS JC QD QC QS KC KD KH KS'));
      expect(g.state.score, 100);
      expect(types(g).first, SolitaireEventType.autoCompleted);
    });

    test('S-32 not offered with a face-down card left, nor with stock left unless autoCompleteWithStock + draw one + unlimited', () {
      expect(endgame(down: [1]).canAutoComplete, isFalse);
      expect(endgame(down: [1]).validate(SolitaireAction.autoComplete), 'cannotAutoComplete');
      final withStock = position(
        columns: ['KC QD', 'KD QC', 'KH QS', 'KS', 'JC'],
        stock: 'TS JS',
        foundations: [suitUpTo('C', 10), suitUpTo('D', 11), suitUpTo('H', 12), suitUpTo('S', 9)],
      );
      expect(withStock.canAutoComplete, isFalse);
      SolitaireGame again(SolitaireOptions o) => position(
        columns: ['KC QD', 'KD QC', 'KH QS', 'KS', 'JC'],
        stock: 'TS JS',
        foundations: [suitUpTo('C', 10), suitUpTo('D', 11), suitUpTo('H', 12), suitUpTo('S', 9)],
        options: o,
      );
      const on = SolitaireOptions(autoMoveToFoundation: SolitaireAutoMove.off, autoCompleteWithStock: true);
      expect(again(on.copyWith(drawCount: 3)).canAutoComplete, isFalse);
      expect(again(on.copyWith(passLimit: 3)).canAutoComplete, isFalse);
      final g = again(on);
      expect(g.canAutoComplete, isTrue);
      play(g, SolitaireAction.autoComplete);
      expect(g.isSolved, isTrue);
      // The columns first (JC QD QC KC KD), then the stock: JS cannot go up
      // until TS has been drawn and sent home.
      expect(types(g), contains(SolitaireEventType.stockDrawn));
    });

    test('S-32 with stock, auto-complete recycles when it must and each draw-one recycle costs −100', () {
      final g = position(
        columns: ['KC QD', 'KD QC', 'KH QS', 'KS', 'JC'],
        stock: 'JS TS',
        foundations: [suitUpTo('C', 10), suitUpTo('D', 11), suitUpTo('H', 12), suitUpTo('S', 9)],
        options: const SolitaireOptions(autoMoveToFoundation: SolitaireAutoMove.off, autoCompleteWithStock: true),
        score: 500,
      );
      play(g, SolitaireAction.autoComplete);
      expect(g.isSolved, isTrue);
      // Draw TS (home), draw JS (home): no recycle needed here.
      expect(types(g), isNot(contains(SolitaireEventType.wasteRecycled)));
      final h = position(
        columns: ['KC QD', 'KD QC', 'KH QS', 'KS', 'JC'],
        wastePile: 'TS JS',
        foundations: [suitUpTo('C', 10), suitUpTo('D', 11), suitUpTo('H', 12), suitUpTo('S', 9)],
        options: const SolitaireOptions(autoMoveToFoundation: SolitaireAutoMove.off, autoCompleteWithStock: true),
        score: 500,
      );
      play(h, SolitaireAction.autoComplete);
      expect(h.isSolved, isTrue);
      expect(types(h).where((t) => t == SolitaireEventType.wasteRecycled).length, 1);
      expect(h.state.score, 500 + 10 * 10 - 100);
    });

    test('S-33 safe auto-move: aces, twos, and cards whose two other-colour foundations reached rank − 1', () {
      SolitaireGame g(String clubs) => position(
        columns: ['9D 5H'],
        stock: 'KC',
        foundations: [suitUpTo('H', 4), clubs, suitUpTo('S', 4)],
        options: const SolitaireOptions(),
      );
      final notYet = g(suitUpTo('C', 3));
      play(notYet, SolitaireAction.draw);
      expect(notYet.state.columns[0], cards('9D 5H'));
      final safe = g(suitUpTo('C', 4));
      play(safe, SolitaireAction.draw);
      expect(safe.state.columns[0], cards('9D'));
      expect(types(safe), contains(SolitaireEventType.autoMoved));
      expect(safe.state.score, 10);
    });

    test('S-33 draw three: a safe waste card is not auto-moved, a safe column card is', () {
      final three = position(
        columns: ['2C'],
        stock: '2D 8S 9S',
        foundations: ['AD', 'AC'],
        options: const SolitaireOptions(drawCount: 3),
      );
      play(three, SolitaireAction.draw);
      expect(three.state.waste.last, PlayingCard.parse('2D'));
      expect(three.state.columns[0], isEmpty);
      final one = position(stock: '2D', foundations: ['AD'], options: const SolitaireOptions());
      play(one, SolitaireAction.draw);
      expect(one.state.waste, isEmpty);
      expect(one.state.foundations[0], cards('AD 2D'));
    });

    test('S-33 always sends every card that fits; off sends none', () {
      final always = position(
        columns: ['7H'],
        stock: 'KC',
        foundations: [suitUpTo('H', 6)],
        options: const SolitaireOptions(autoMoveToFoundation: SolitaireAutoMove.always),
      );
      play(always, SolitaireAction.draw);
      expect(always.state.columns[0], isEmpty);
      final off = position(columns: ['2H'], stock: 'KC', foundations: ['AH']);
      play(off, SolitaireAction.draw);
      expect(off.state.columns[0], cards('2H'));
    });
  });

  group('undo (S-35)', () {
    test('undo restores cards, recycles, cards home and moves; a −100 recycle can be undone (S-41 edge 4)', () {
      final g = position(wastePile: 'KC 7D', score: 40, options: const SolitaireOptions());
      play(g, SolitaireAction.recycle);
      expect(g.state.score, 0);
      expect(g.state.recycles, 1);
      expect(g.undo(), isTrue);
      expect(g.state.score, 40);
      expect(g.state.recycles, 0);
      expect(g.state.waste, cards('KC 7D'));
      expect(g.state.moves, 0);
      expect(g.lastEvents.single.type, SolitaireEventType.undone);
      expect(g.undo(), isFalse);
    });

    test('undoPenalty is taken off per undo, never below 0', () {
      final g = position(columns: ['8S'], wastePile: '7H', score: 3, options: manual.copyWith(undoPenalty: 5));
      play(g, mv(waste, col(0)));
      expect(g.state.score, 8);
      g.undo();
      expect(g.state.score, 0);
      expect(g.state.undos, 1);
    });

    test('undo keeps the last 1000 snapshots', () {
      final g = SolitaireGame.newDeal(seed: 3, options: manual);
      for (var i = 0; i < 1005; i++) {
        expect(g.tapStock(), isTrue);
      }
      var undone = 0;
      while (g.undo()) {
        undone++;
      }
      expect(undone, SolitaireGame.undoLimit);
    });
  });

  group('standard scoring (S-40…S-43)', () {
    test('S-40a waste to column +5', () {
      final g = position(columns: ['8S'], wastePile: '7H');
      play(g, mv(waste, col(0)));
      expect(g.state.score, 5);
    });

    test('S-40b waste to foundation +10', () {
      final g = position(wastePile: '2S', foundations: ['AS']);
      play(g, mv(waste, home(0)));
      expect(g.state.score, 10);
    });

    test('S-40c/S-40d column to foundation +10, then the card turned up +5 (edge 6)', () {
      final g = position(columns: ['9D 2S'], down: [1], foundations: ['AS']);
      play(g, mv(col(0), home(0)));
      expect(types(g), [SolitaireEventType.toFoundation, SolitaireEventType.cardTurnedUp]);
      expect(g.lastEvents.map((e) => e.points), [10, 5]);
      expect(g.state.score, 15);
    });

    test('S-40e foundation to column −15', () {
      final g = position(columns: ['4S'], foundations: ['AH 2H 3H'], score: 20);
      play(g, mv(home(0), col(0)));
      expect(g.state.score, 5);
      expect(g.lastEvents.single.type, SolitaireEventType.fromFoundation);
    });

    test('S-40f every draw-one recycle −100', () {
      final g = position(wastePile: 'KC', score: 250);
      play(g, SolitaireAction.recycle);
      play(g, SolitaireAction.draw);
      play(g, SolitaireAction.recycle);
      expect(g.state.score, 50);
    });

    test('S-40g draw three: −20 from recycle 3 by default, from recycle 4 or on every recycle as options (edge 5)', () {
      for (final (from, penalties) in [
        (3, [0, 0, -20, -20]),
        (4, [0, 0, 0, -20]),
        (1, [-20, -20, -20, -20]),
      ]) {
        final g = position(
          stock: 'KC',
          score: 1000,
          options: manual.copyWith(drawCount: 3, draw3PenaltyFromRecycle: from),
        );
        final got = <int>[];
        for (var i = 0; i < 4; i++) {
          play(g, SolitaireAction.draw);
          final before = g.state.score;
          play(g, SolitaireAction.recycle);
          got.add(g.state.score - before);
        }
        expect(got, penalties, reason: 'draw3PenaltyFromRecycle $from');
      }
    });

    test('S-40h column to column, a draw and an undo score 0', () {
      final g = position(columns: ['8S', '7H', ''], stock: 'KC', score: 30);
      play(g, mv(col(1), col(0)));
      play(g, SolitaireAction.draw);
      g.undo();
      expect(g.state.score, 30);
    });

    test('S-41 the score never goes below 0', () {
      final g = position(columns: ['4S'], foundations: ['AH 2H 3H'], score: 10);
      play(g, mv(home(0), col(0)));
      expect(g.state.score, 0);
    });

    test('S-42 waste → column → foundation earns 15; foundation → column → foundation nets −5', () {
      final g = position(columns: ['3C'], wastePile: '2H', foundations: ['AH']);
      play(g, mv(waste, col(0)));
      play(g, mv(col(0), home(0)));
      expect(g.state.score, 15);
      final h = position(columns: ['4S'], foundations: ['AH 2H 3H'], score: 20);
      play(h, mv(home(0), col(0)));
      play(h, mv(col(0), home(0)));
      expect(h.state.score, 15);
    });

    test('S-49 cards home: +1 per card sent up, −1 per card taken back', () {
      final g = position(columns: ['4S', '3H'], foundations: ['AH 2H']);
      play(g, mv(col(1), home(0)));
      expect(g.state.cardsHome, 3);
      play(g, mv(home(0), col(0)));
      expect(g.state.cardsHome, 2);
    });

    test('S-50 scoring none hides the score (time, moves and cards home remain)', () {
      final g = position(columns: ['8S'], wastePile: '7H', options: manual.copyWith(scoring: SolitaireScoring.none));
      play(g, mv(waste, col(0)));
      expect(g.displayScore, isNull);
      expect(g.state.moves, 1);
      expect(position(columns: ['8S']).displayScore, 0);
    });
  });

  group('timed scoring (S-45…S-48)', () {
    const timed = SolitaireOptions(timedScoring: true, autoMoveToFoundation: SolitaireAutoMove.off);
    SolitaireGame nearlyWon({int score = 0}) => position(
      columns: ['KS', 'QS'],
      foundations: [suitUpTo('C', 13), suitUpTo('D', 13), suitUpTo('H', 13), suitUpTo('S', 11)],
      options: timed,
      score: score,
    );

    test('S-45 the clock starts at the first action and stops at the win', () {
      final g = nearlyWon();
      expect(g.advanceClock(const Duration(seconds: 50)), isEmpty);
      expect(g.state.elapsedMs, 0);
      play(g, mv(col(1), home(3)));
      g.advanceClock(const Duration(seconds: 5));
      expect(g.state.elapsed, const Duration(seconds: 5));
      play(g, mv(col(0), home(3)));
      g.advanceClock(const Duration(seconds: 5));
      expect(g.state.elapsed, const Duration(seconds: 5));
    });

    test('S-46 −2 each time the play time reaches a multiple of 10 s (edge 14)', () {
      final g = nearlyWon(score: 100);
      play(g, mv(col(1), home(3)));
      expect(g.advanceClock(const Duration(seconds: 9)), isEmpty);
      expect(g.advanceClock(const Duration(seconds: 1)).single.points, -2);
      expect(g.advanceClock(const Duration(seconds: 10)).length, 1);
      expect(g.state.score, 106);
      expect(g.state.timeDeductions, 2);
      final untimed = position(columns: ['8S'], wastePile: '7H');
      play(untimed, mv(waste, col(0)));
      untimed.advanceClock(const Duration(seconds: 60));
      expect(untimed.state.score, 5);
    });

    test('S-47 a win at 29 s gets no bonus, at 30 s ⌊700 000 / 30⌋ = 23 333 (edge 14)', () {
      final a = nearlyWon();
      play(a, mv(col(1), home(3)));
      a.advanceClock(const Duration(seconds: 29));
      play(a, mv(col(0), home(3)));
      expect(a.state.score, 10 - 4 + 10);
      expect(types(a), isNot(contains(SolitaireEventType.timeBonus)));
      final b = nearlyWon();
      play(b, mv(col(1), home(3)));
      b.advanceClock(const Duration(seconds: 30));
      play(b, mv(col(0), home(3)));
      expect(b.lastEvents.last.points, 23333);
      expect(b.state.score, 10 - 6 + 10 + 23333);
    });

    test('S-48 the worked example: 520 move points, won at 150 s → 5 156', () {
      final g = nearlyWon(score: 500);
      play(g, mv(col(1), home(3)));
      g.advanceClock(const Duration(seconds: 150));
      play(g, mv(col(0), home(3)));
      expect(g.state.score, 5156);
    });

    test('S-35 undo never gives back time deductions (edge 15)', () {
      final g = position(columns: ['8S', '7H 2C'], wastePile: '6S', foundations: ['AC'], options: timed);
      play(g, mv(col(1), home(0))); // +10
      play(g, mv(col(1), col(0))); // 0 … score 10
      play(g, mv(waste, col(0))); // +5 → 15
      g.advanceClock(const Duration(seconds: 20)); // −4 → 11
      expect(g.state.score, 11);
      g.undo();
      expect(g.state.score, 6);
      expect(g.state.timeDeductions, 2);
      expect(g.state.elapsed, const Duration(seconds: 20));
    });
  });

  group('game and records (S-64, S-71, S-72)', () {
    test('S-64 the same deal number gives the same deal; deal of the day is yyyymmdd', () {
      expect(jsonEncode(SolitaireGame.newDeal(seed: 9).toJson()), jsonEncode(SolitaireGame.newDeal(seed: 9).toJson()));
      expect(
        jsonEncode(SolitaireGame.newDeal(seed: 9).toJson()['state']),
        isNot(jsonEncode(SolitaireGame.newDeal(seed: 10).toJson()['state'])),
      );
      expect(SolitaireDeals.dayNumber(DateTime(2026, 9, 30)), 20260930);
    });

    test('S-71 one deal is one game: it is over only when won', () {
      final g = SolitaireGame.newDeal(seed: 2);
      expect(g.isOver, isFalse);
      expect(g.isSolved, isFalse);
    });

    test('S-72 moves count draws, recycles and card movements (automatic ones too), not turn-ups or undo', () {
      final g = position(columns: ['9D 8S', '9H'], down: [1], stock: 'KC AH', options: const SolitaireOptions());
      play(g, SolitaireAction.draw); // draw, the ace goes home by itself
      expect(g.state.moves, 2);
      play(g, mv(col(0), col(1))); // one move; 9D turns up (not a move)
      expect(g.state.moves, 3);
      play(g, SolitaireAction.draw);
      play(g, SolitaireAction.recycle);
      expect(g.state.moves, 5);
      g.undo();
      expect(g.state.moves, 4);
    });

    test('S-72 statistics per draw mode: streaks, bests on wins only, average cards home', () {
      final stats = SolitaireStats();
      final won = position(
        columns: ['KS'],
        foundations: [suitUpTo('C', 13), suitUpTo('D', 13), suitUpTo('H', 13), suitUpTo('S', 12)],
      );
      play(won, mv(col(0), home(3)));
      stats.record(won);
      stats.record(SolitaireGame.newDeal(seed: 1));
      stats.record(won);
      stats.record(SolitaireGame.newDeal(seed: 1, options: const SolitaireOptions.hard()));
      final one = stats.drawOne;
      expect(one.played, 3);
      expect(one.won, 2);
      expect(one.currentStreak, 1);
      expect(one.bestStreak, 1);
      expect(one.fewestMoves, 1);
      expect(one.bestScore, 10);
      expect(one.averageCardsHome, closeTo((52 + 0 + 52) / 3, 1e-9));
      expect(stats.drawThree.played, 1);
      final back = SolitaireStats.fromJson(jsonDecode(jsonEncode(stats.toJson())) as Map<String, Object?>);
      expect(jsonEncode(back.toJson()), jsonEncode(stats.toJson()));
    });
  });

  test('save / resume keeps stock order, recycles, score, deductions, time and undo history (edge 19)', () {
    final g = SolitaireGame.newDeal(seed: 12, options: const SolitaireOptions.windowsClassic());
    for (var i = 0; i < 12; i++) {
      g.tapStock();
    }
    g.advanceClock(const Duration(seconds: 25));
    final json = jsonDecode(jsonEncode(g.toJson())) as Map<String, Object?>;
    expect(json['kind'], 'solitaire');
    final back = SolitaireGame.fromJson(json);
    expect(jsonEncode(back.toJson()), jsonEncode(json));
    expect(back.state.recycles, g.state.recycles);
    expect(back.state.timeDeductions, 2);
    expect(back.state.stock, g.state.stock);
    for (var i = 0; i < 5; i++) {
      g.undo();
      back.undo();
      g.tapStock();
      back.tapStock();
    }
    expect(jsonEncode(back.toJson()), jsonEncode(g.toJson()));
    expect(() => SolitaireGame.fromJson({'kind': 'mahjong'}), throwsFormatException);
  });
}
