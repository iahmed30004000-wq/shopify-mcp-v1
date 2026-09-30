/// Basra (باصرة) rules: capture by rank or sum, jacks sweep, basra bonuses,
/// the 7♦ special. See RULES.md.
library;

import '../core/card_game.dart';
import '../core/playing_card.dart';
import 'basra_state.dart';

/// What one card does to the table.
class BasraCapture {
  const BasraCapture(this.cards, this.basraPoints);

  /// Table cards taken (empty: the card stays on the table).
  final List<PlayingCard> cards;
  final int basraPoints;

  bool get isCapture => cards.isNotEmpty;
}

final PlayingCard sevenOfDiamonds = PlayingCard(Suit.diamonds, Rank.seven);

class BasraRules extends CardRules<BasraState, BasraMove> {
  const BasraRules();

  /// Numeral value (A = 1 … 10); faces have none.
  static int? numeral(PlayingCard c) => c.rank == Rank.ace ? 1 : (c.rank.value <= 10 ? c.rank.value : null);

  /// Scoring value of a captured card.
  static int cardPoints(PlayingCard c) {
    if (c.rank == Rank.jack || c.rank == Rank.ace) return 1;
    if (c.rank == Rank.two && c.suit == Suit.clubs) return 2;
    if (c.rank == Rank.ten && c.suit == Suit.diamonds) return 3;
    return 0;
  }

  /// The largest set of [numerals] that splits into groups each adding up to
  /// [value] (a single card of that value is such a group).
  static List<PlayingCard> bestSumCapture(List<PlayingCard> numerals, int value) {
    final cards = numerals.where((c) => numeral(c)! <= value).toList();
    final n = cards.length;
    if (n == 0) return const [];
    if (n > 18) {
      // Pathological tables: same-rank cards only.
      return cards.where((c) => numeral(c) == value).toList();
    }
    final vals = [for (final c in cards) numeral(c)!];
    final groups = <int>[];
    for (var mask = 1; mask < 1 << n; mask++) {
      var sum = 0;
      for (var i = 0; i < n && sum <= value; i++) {
        if (mask & (1 << i) != 0) sum += vals[i];
      }
      if (sum == value) groups.add(mask);
    }
    if (groups.isEmpty) return const [];
    final memo = <int, int>{};
    final choice = <int, int>{};
    int best(int avail) {
      if (avail == 0) return 0;
      final cached = memo[avail];
      if (cached != null) return cached;
      final low = avail & -avail;
      var result = best(avail & ~low);
      var pick = 0;
      for (final g in groups) {
        if (g & low == 0 || g & ~avail != 0) continue;
        final r = _bits(g) + best(avail & ~g);
        if (r > result) {
          result = r;
          pick = g;
        }
      }
      memo[avail] = result;
      choice[avail] = pick;
      return result;
    }

    var avail = (1 << n) - 1;
    best(avail);
    var taken = 0;
    while (avail != 0) {
      best(avail);
      final g = choice[avail]!;
      if (g == 0) {
        avail &= ~(avail & -avail);
      } else {
        taken |= g;
        avail &= ~g;
      }
    }
    return [
      for (var i = 0; i < n; i++)
        if (taken & (1 << i) != 0) cards[i],
    ];
  }

  static int _bits(int x) {
    var c = 0;
    while (x != 0) {
      x &= x - 1;
      c++;
    }
    return c;
  }

  /// What [card] takes from [table] (before the last-card rule).
  static BasraCapture captureFor(List<PlayingCard> table, PlayingCard card, BasraOptions o) {
    if (table.isEmpty) return const BasraCapture([], 0);
    if (card.rank == Rank.jack) {
      final lone = table.length == 1 && table.first.rank == Rank.jack;
      return BasraCapture(List.of(table), lone ? o.jackBasraPoints : 0);
    }
    if (card == sevenOfDiamonds && o.sevenDiamonds == BasraSevenDiamonds.sweep) {
      final nums = table.map(numeral).toList();
      final allNumerals = nums.every((v) => v != null);
      final sum = allNumerals ? nums.fold<int>(0, (a, v) => a + v!) : 0;
      return BasraCapture(List.of(table), allNumerals && sum <= o.sevenDiamondsBasraMaxSum ? o.basraPoints : 0);
    }
    final List<PlayingCard> taken;
    final v = numeral(card);
    if (v == null) {
      taken = table.where((c) => c.rank == card.rank).toList();
    } else {
      taken = bestSumCapture(table.where((c) => numeral(c) != null).toList(), v);
    }
    final sweep = taken.isNotEmpty && taken.length == table.length;
    return BasraCapture(taken, sweep ? o.basraPoints : 0);
  }

  @override
  List<BasraMove> legalMoves(BasraState s, int seat) {
    if (s.isOver || s.turn != seat) return const [];
    return [for (final c in s.hands[seat].toSet()) BasraMove(c)];
  }

  @override
  String? validate(BasraState s, int seat, BasraMove m) {
    final base = super.validate(s, seat, m);
    return base == 'illegalMove' ? 'cardNotInHand' : base;
  }

  @override
  BasraMove moveFromJson(Map<String, Object?> json) => BasraMove.fromJson(json);

  @override
  void apply(BasraState s, BasraMove m, [List<CardEvent>? ev]) {
    final seat = s.turn;
    final card = m.card;
    s.hands[seat].remove(card);
    final cap = captureFor(s.table, card, s.options);
    ev?.add(CardEvent(CardEventType.cardPlayed, seat: seat, cards: [card]));
    if (!cap.isCapture) {
      s.table.add(card);
      ev?.add(CardEvent(CardEventType.cardToTable, seat: seat, cards: [card]));
    } else {
      for (final c in cap.cards) {
        s.table.remove(c);
      }
      final side = s.teamOf(seat);
      s.piles[side]
        ..addAll(cap.cards)
        ..add(card);
      s.lastCapturer = seat;
      ev?.add(CardEvent(CardEventType.captured, seat: seat, cards: [...cap.cards, card]));
      final lastCard = s.stock.isEmpty && s.hands.every((h) => h.isEmpty);
      if (cap.basraPoints > 0 && (!lastCard || s.options.basraOnLastCard)) {
        s.basraScore[side] += cap.basraPoints;
        ev?.add(CardEvent(CardEventType.basra, seat: seat, value: cap.basraPoints));
      }
    }
    s.turn = (seat + 1) % s.playerCount;
    if (s.hands.every((h) => h.isEmpty)) {
      if (s.stock.isNotEmpty) {
        s.dealRound();
        ev?.add(CardEvent(CardEventType.dealt, seat: s.dealer));
      } else {
        _endDeal(s, ev);
      }
    }
  }

  /// Points per side for piles and basras.
  static List<int> dealPoints(BasraOptions o, List<List<PlayingCard>> piles, List<int> basras) {
    final pts = [for (var i = 0; i < piles.length; i++) piles[i].fold<int>(0, (a, c) => a + cardPoints(c)) + basras[i]];
    final counts = [for (final p in piles) p.length];
    final most = counts.reduce((a, b) => a > b ? a : b);
    if (counts.where((c) => c == most).length == 1) pts[counts.indexOf(most)] += o.majorityPoints;
    return pts;
  }

  void _endDeal(BasraState s, List<CardEvent>? ev) {
    if (s.table.isNotEmpty) {
      final taker = s.lastCapturer ?? s.dealer;
      s.piles[s.teamOf(taker)].addAll(s.table);
      ev?.add(CardEvent(CardEventType.captured, seat: taker, cards: List.of(s.table)));
      s.table = [];
    }
    final pts = dealPoints(s.options, s.piles, s.basraScore);
    for (var i = 0; i < pts.length; i++) {
      s.sideScores[i] += pts[i];
    }
    s.results.add(BasraDealResult(pts, [for (final p in s.piles) p.length], List.of(s.basraScore)));
    ev?.add(CardEvent(CardEventType.roundScored, seat: s.dealer));
    final best = s.sideScores.reduce((a, b) => a > b ? a : b);
    if (best >= s.options.targetScore && s.sideScores.where((x) => x == best).length == 1) {
      s.over = true;
      ev?.add(const CardEvent(CardEventType.matchOver));
      return;
    }
    s.dealer = (s.dealer + 1) % s.playerCount;
    s.dealFromRng();
    ev?.add(CardEvent(CardEventType.dealt, seat: s.dealer));
  }
}

class BasraEngine extends RulesEngine<BasraState, BasraMove> {
  BasraEngine(BasraState state) : super(const BasraRules(), state);

  factory BasraEngine.newMatch({BasraOptions options = const BasraOptions(), required int seed}) =>
      BasraEngine(BasraState.newMatch(options: options, seed: seed));

  factory BasraEngine.fromJson(Map<String, Object?> json) => BasraEngine(BasraState.fromJson(json));
}
