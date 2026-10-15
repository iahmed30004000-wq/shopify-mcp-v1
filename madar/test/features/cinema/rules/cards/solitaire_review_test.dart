// Solitaire (Klondike): adversarial review. The first group holds the cases
// that failed against the first implementation (each names the defect it
// proved); the second checks the engine against independent re-statements of
// the rules on positions reached in seeded play: every possible action is
// accepted exactly when the rules allow it (S-10…S-23, S-32), the score moves
// by exactly the S-40 lines, and undo gives back the previous position.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/core/card_game.dart' show AiLevel;
import 'package:madar/features/cinema/rules/cards/core/card_rng.dart';
import 'package:madar/features/cinema/rules/cards/core/playing_card.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_ai.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_board.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_game.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_options.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_seeds.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_solver.dart';

List<PlayingCard> cards(String ids) => ids.trim().isEmpty ? <PlayingCard>[] : PlayingCard.list(ids);

SolitaireBoard board({
  List<String> columns = const [],
  List<int> down = const [],
  String stock = '',
  String wastePile = '',
  int recycles = 0,
}) => SolitaireBoard.fromPiles(
  columns: [for (final s in columns) cards(s)],
  faceDown: down,
  stock: cards(stock),
  waste: cards(wastePile),
  recycles: recycles,
);

/// Every action a player could try: all piles (plus out-of-range ones) to
/// all piles, every count, and the pile-free actions.
final List<SolitaireAction> everyAction = () {
  final piles = <SolitairePile>[
    SolitairePile.waste,
    for (var c = -1; c <= 7; c++) SolitairePile.column(c),
    for (var p = -1; p <= 4; p++) SolitairePile.foundation(p),
  ];
  return <SolitaireAction>[
    SolitaireAction.draw,
    SolitaireAction.recycle,
    SolitaireAction.autoComplete,
    for (var c = -1; c <= 7; c++) SolitaireAction.flip(c),
    for (final from in piles)
      for (final to in piles)
        for (var n = 0; n <= 14; n++) SolitaireAction.move(from, to, count: n),
  ];
}();

/// The piles of one position, read once through the public views.
class Piles {
  Piles(SolitaireGame g)
    : won = g.state.won,
      recycles = g.state.recycles,
      stock = g.state.stock,
      waste = g.state.waste,
      faceDown = g.state.faceDown,
      columns = g.state.columns,
      foundations = g.state.foundations;

  final bool won;
  final int recycles;
  final List<PlayingCard> stock;
  final List<PlayingCard> waste;
  final List<int> faceDown;
  final List<List<PlayingCard>> columns;
  final List<List<PlayingCard>> foundations;
}

/// The rules of S-10…S-23 and S-32 written again from the piles, without the
/// engine's board code: null when [a] is legal, else a reason.
String? oracle(Piles s, SolitaireOptions o, SolitaireAction a) {
  if (s.won) return 'won';
  final stock = s.stock;
  final waste = s.waste;
  final faceDown = s.faceDown;
  final columns = s.columns;
  final foundations = s.foundations;
  bool inCol(int c) => c >= 0 && c < 7;
  switch (a.kind) {
    case SolitaireActionKind.draw:
      return stock.isNotEmpty ? null : 'stock empty';
    case SolitaireActionKind.recycle:
      if (stock.isNotEmpty || waste.isEmpty) return 'nothing to recycle';
      final limit = o.passLimit;
      return limit == null || s.recycles < limit - 1 ? null : 'no passes left';
    case SolitaireActionKind.flip:
      if (o.autoFlip || !inCol(a.column)) return 'no flip';
      final col = columns[a.column];
      return col.isNotEmpty && faceDown[a.column] == col.length ? null : 'nothing to turn';
    case SolitaireActionKind.autoComplete:
      if (faceDown.any((d) => d > 0)) return 'face-down card left';
      if (stock.isEmpty && waste.isEmpty) return null;
      return o.autoCompleteWithStock && o.drawCount == 1 && o.passLimit == null ? null : 'stock left';
    case SolitaireActionKind.move:
      final from = a.from!;
      final to = a.to!;
      final n = a.count;
      if (n < 1) return 'count';
      final PlayingCard head;
      if (from.isWaste) {
        if (n != 1 || waste.isEmpty) return 'waste';
        head = waste.last;
      } else if (from.isColumn) {
        if (!inCol(from.index)) return 'column';
        final col = columns[from.index];
        if (n > col.length - faceDown[from.index]) return 'not face up';
        head = col[col.length - n];
      } else {
        if (!o.allowFoundationToTableau || n != 1 || from.index < 0 || from.index > 3) return 'foundation';
        final f = foundations[from.index];
        if (f.isEmpty) return 'empty foundation';
        head = f.last;
      }
      if (to.isWaste) return 'to waste';
      if (to.isFoundation) {
        if (from.isFoundation || n != 1 || to.index < 0 || to.index > 3) return 'to foundation';
        final f = foundations[to.index];
        if (f.isEmpty) return solitaireRank(head) == 1 ? null : 'only an ace starts a foundation';
        return f.first.suit == head.suit && solitaireRank(head) == f.length + 1 ? null : 'does not fit home';
      }
      if (!inCol(to.index) || (from.isColumn && from.index == to.index)) return 'to column';
      final target = columns[to.index];
      if (target.isEmpty) return solitaireRank(head) == 13 ? null : 'only a king on an empty column';
      if (faceDown[to.index] == target.length) return 'onto a face-down card';
      final last = target.last;
      final fits = solitaireRank(last) == solitaireRank(head) + 1 && isRedCard(last) != isRedCard(head);
      return fits ? null : 'does not fit column';
  }
}

/// After every action (S-14, S-33): no face-down card waits at the end of a
/// column (with `autoFlip`), and no card the automatic moves would send home
/// is left: an exposed column card, or the waste card in draw one, that
/// fits its foundation and is safe (or any that fits, with `always`).
void expectSettled(SolitaireGame g, String reason) {
  final s = g.state;
  final o = g.options;
  if (s.won) return;
  final columns = s.columns;
  final faceDown = s.faceDown;
  if (o.autoFlip) {
    for (var c = 0; c < 7; c++) {
      expect(columns[c].isNotEmpty && faceDown[c] == columns[c].length, isFalse, reason: '$reason: column $c not turned');
    }
  }
  if (o.autoMoveToFoundation == SolitaireAutoMove.off) return;
  final height = <Suit, int>{for (final f in s.foundations) if (f.isNotEmpty) f.first.suit: f.length};
  bool goesHome(PlayingCard card) {
    final r = solitaireRank(card);
    if (r != (height[card.suit] ?? 0) + 1) return false;
    if (o.autoMoveToFoundation == SolitaireAutoMove.always || r <= 2) return true;
    final others = isRedCard(card) ? const [Suit.clubs, Suit.spades] : const [Suit.diamonds, Suit.hearts];
    return others.every((x) => (height[x] ?? 0) >= r - 1);
  }

  for (var c = 0; c < 7; c++) {
    if (columns[c].length > faceDown[c]) {
      expect(goesHome(columns[c].last), isFalse, reason: '$reason: ${columns[c].last} left in column $c');
    }
  }
  if (o.drawCount == 1 && s.waste.isNotEmpty) {
    expect(goesHome(s.waste.last), isFalse, reason: '$reason: ${s.waste.last} left on the waste');
  }
}

/// The S-40 score change of [a] from [before] to [after], worked out from the
/// piles alone (valid while the floor at 0 cannot be reached).
int expectedPoints(SolitaireState before, SolitaireState after, SolitaireAction a, SolitaireOptions o) {
  var points = 0;
  final leftHome = a.kind == SolitaireActionKind.move && a.from!.isFoundation ? 1 : 0;
  final arrived = after.cardsHome - before.cardsHome + leftHome;
  points += 10 * arrived - 15 * leftHome;
  final turned = before.faceDown.fold<int>(0, (x, y) => x + y) - after.faceDown.fold<int>(0, (x, y) => x + y);
  points += 5 * turned;
  if (a.kind == SolitaireActionKind.move && a.from!.isWaste && a.to!.isColumn) points += 5;
  for (var r = before.recycles + 1; r <= after.recycles; r++) {
    points += o.drawCount == 1 ? -100 : (r >= o.draw3PenaltyFromRecycle ? -20 : 0);
  }
  return points;
}

void main() {
  group('defects found in review (each failed before its fix)', () {
    test('S-75 draw three: a stock card that comes up only after the recycle regroups the triples still counts', () {
      const drawThree = SolitaireOptions(drawCount: 3);
      // Waste 2C 3C 4C 5C; stock (drawn first) 7C AH TC 2D 3D 4D. From here
      // the draws show TC and 4D; after the recycle they show 4C, AH, 3D,
      // 4D, so the ace comes up on the second draw of the next pass.
      final b = board(
        columns: ['5S 9H', '6S 9D'],
        down: [1, 1],
        wastePile: '2C 3C 4C 5C',
        stock: '4D 3D 2D TC AH 7C',
        recycles: 1,
      );
      expect(SolitaireSearch.isStuck(b, drawThree), isFalse);
      expect(SolitaireAutoPlayer.stockUseful(b, drawThree), isTrue);
      for (final level in AiLevel.values) {
        expect(SolitaireAutoPlayer.choose(b, drawThree, level, CardRng(1)), SolitaireAction.draw, reason: level.name);
      }
      final g = SolitaireGame.custom(b, options: drawThree);
      expect(g.hint().technique, SolitaireTechnique.drawStock);
      for (var i = 0; i < 10 && g.state.cardsHome == 0; i++) {
        final a = g.hint().action;
        expect(a, isNotNull, reason: 'the hint gave up after $i steps');
        expect(g.apply(a!), isTrue);
      }
      expect(g.state.cardsHome, 1);
      // The same after one pass of a three-pass limit: one recycle is left.
      const expert = SolitaireOptions.expert();
      expect(SolitaireAutoPlayer.stockUseful(b, expert), isTrue);
      // With no recycle left only the rest of this pass counts: TC and 4D.
      final spent = board(
        columns: ['5S 9H', '6S 9D'],
        down: [1, 1],
        wastePile: '2C 3C 4C 5C',
        stock: '4D 3D 2D TC AH 7C',
        recycles: 2,
      );
      expect(SolitaireAutoPlayer.stockUseful(spent, expert), isFalse);
    });
  });

  test('S-62 every bundled seed (the winnable-deal fallback) is solved again and its plan replays to the win', () {
    // The existing test re-proves the first two of each list; a single bad
    // seed further down would hand an Easy player an unwinnable "winnable"
    // deal, so all of them are checked (about 20 s).
    final sets = {
      SolitaireSeeds.drawOneUnlimited: const SolitaireOptions(),
      SolitaireSeeds.drawOneThreePasses: const SolitaireOptions(passLimit: 3),
      SolitaireSeeds.drawOneOnePass: const SolitaireOptions(passLimit: 1),
      SolitaireSeeds.drawThreeUnlimited: const SolitaireOptions(drawCount: 3),
      SolitaireSeeds.drawThreeThreePasses: const SolitaireOptions(drawCount: 3, passLimit: 3),
      SolitaireSeeds.drawThreeOnePass: const SolitaireOptions(drawCount: 3, passLimit: 1),
    };
    var total = 0;
    for (final e in sets.entries) {
      for (final seed in e.key) {
        final s = const SolitaireSolver().solve(SolitaireBoard.forSeed(seed), e.value);
        expect(s.won, isTrue, reason: 'seed $seed ${e.value.toJson()}');
        final g = SolitaireGame.newDeal(seed: seed, options: e.value);
        for (final a in s.plan) {
          expect(g.apply(a), isTrue, reason: 'seed $seed: $a');
        }
        expect(g.isSolved, isTrue, reason: 'seed $seed');
        total++;
      }
    }
    expect(total, 5 * 40 + 16);
  });

  group('the engine agrees with the rules written again from the piles', () {
    final variants = <String, SolitaireOptions>{
      'jordan': const SolitaireOptions(),
      'expert, no auto-flip, no worrying back': const SolitaireOptions(
        drawCount: 3,
        passLimit: 3,
        autoFlip: false,
        allowFoundationToTableau: false,
      ),
      'easy (auto-complete with stock)': const SolitaireOptions.easy(),
      'windows classic, one pass': const SolitaireOptions(
        drawCount: 3,
        passLimit: 1,
        autoMoveToFoundation: SolitaireAutoMove.off,
        draw3PenaltyFromRecycle: 1,
      ),
      'draw three, always auto-move': const SolitaireOptions(drawCount: 3, autoMoveToFoundation: SolitaireAutoMove.always),
    };
    for (final e in variants.entries) {
      test('${e.key}: every action accepted exactly when legal; legalActions lists them; score and undo', () {
        final o = e.value;
        var positions = 0;
        var legalSeen = 0;
        for (var seed = 1; seed <= 6; seed++) {
          // A high starting score keeps the floor out of the score check.
          final g = SolitaireGame.custom(SolitaireBoard.forSeed(seed), options: o, score: 1000);
          final rng = CardRng(seed * 17 + 3);
          for (var step = 0; step < 90 && !g.isSolved; step++) {
            if (step % 3 == 0) {
              positions++;
              final listed = g.legalActions().toSet();
              final piles = Piles(g);
              for (final a in everyAction) {
                final want = oracle(piles, o, a);
                expect(g.validate(a) == null, want == null, reason: 'seed $seed step $step: $a ($want)');
                if (want != null) continue;
                legalSeen++;
                // legalActions offers every legal action, except that an ace
                // is listed only for its tap place (the leftmost empty one).
                final aceElsewhere =
                    a.kind == SolitaireActionKind.move &&
                    a.to!.isFoundation &&
                    a.to != g.sendHomeAction(a.from!)?.to;
                if (!aceElsewhere) expect(listed, contains(a), reason: 'seed $seed step $step: $a not listed');
              }
              for (final a in listed) {
                expect(oracle(piles, o, a), isNull, reason: 'listed but illegal: $a');
              }
              // S-36: a hint is always a legal action.
              final hint = g.hint().action;
              if (hint != null) expect(g.validate(hint), isNull, reason: 'hint $hint');
            }
            // Play: mostly the medium choice, sometimes a random legal one.
            final legal = g.legalActions();
            if (legal.isEmpty) break;
            final a = rng.nextInt(4) == 0
                ? legal[rng.nextInt(legal.length)]
                : (SolitaireAutoPlayer.choose(g.state.board, o, AiLevel.medium, rng) ?? legal.first);
            final before = g.state.copy();
            final beforeJson = jsonEncode(before.toJson());
            expect(g.apply(a), isTrue);
            expectSettled(g, 'seed $seed after $a');
            if (a.kind == SolitaireActionKind.autoComplete) expect(g.isSolved, isTrue, reason: 'S-32');
            if (!g.isSolved) {
              if (before.score >= 200) {
                expect(g.state.score - before.score, expectedPoints(before, g.state, a, o), reason: '$a');
              }
              expect(g.undo(), isTrue);
              final back = g.state.toJson()
                ..['undos'] = before.undos
                ..['started'] = before.started;
              expect(jsonEncode(back), beforeJson, reason: 'undo of $a');
              expect(g.apply(a), isTrue);
            }
          }
        }
        expect(positions, greaterThan(100));
        expect(legalSeen, greaterThan(positions));
      });
    }
  });
}
