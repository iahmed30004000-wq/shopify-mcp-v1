/// Melds for the rummy games (Hand, Konkan): sets and runs with jokers,
/// lay-offs, joker swaps, and the search for the best melds in a hand.
library;

import '../core/playing_card.dart';

enum MeldKind {
  /// Three or four cards of one rank in different suits.
  set,

  /// Three or more consecutive cards of one suit (ace low A-2-3 or high
  /// Q-K-A, never round the corner).
  run,
}

/// Opening value of a card standing for [position] (1 = ace low … 14 = ace
/// high): 2–10 face value, J Q K 10, ace 11 (1 when low).
int meldPositionValue(int position) => position == 1 ? 1 : (position == 14 ? 11 : (position > 10 ? 10 : position));

/// A meld on the table (or a candidate). Runs keep their cards in position
/// order with each joker in the slot it fills.
class Meld {
  const Meld._(this.kind, this.cards, this.low, this.suit, this.owner);

  factory Meld.fromJson(Map<String, Object?> j) => Meld._(
    MeldKind.values.byName(j['kind']! as String),
    cardsFromJson(j['cards']),
    j['low']! as int,
    j['suit'] == null ? null : Suit.fromCode(j['suit']! as String),
    j['owner']! as int,
  );

  final MeldKind kind;
  final List<PlayingCard> cards;

  /// Run: position of the first card (1..12). Set: the rank value.
  final int low;
  final Suit? suit;

  /// Seat that put it down (-1 for a candidate).
  final int owner;

  int get high => kind == MeldKind.run ? low + cards.length - 1 : low;
  int get jokers => cards.where((c) => c.isJoker).length;
  int get naturals => cards.length - jokers;

  int get value => kind == MeldKind.run
      ? [for (var i = 0; i < cards.length; i++) meldPositionValue(low + i)].fold(0, (a, b) => a + b)
      : meldPositionValue(low) * cards.length;

  Meld withOwner(int seat) => Meld._(kind, cards, low, suit, seat);

  /// Sorted codes: identifies the multiset of cards.
  String get key => (cards.map((c) => c.code).toList()..sort()).join(',');

  static int _pos(PlayingCard c, bool aceHigh) => c.rank == Rank.ace ? (aceHigh ? 14 : 1) : c.rank.value;

  /// Arranges [cards] into a valid meld, or null. A meld has at least two
  /// natural cards and fewer jokers than natural cards.
  static Meld? arrange(List<PlayingCard> cards, {int owner = -1}) {
    if (cards.length < 3) return null;
    final nat = cards.where((c) => !c.isJoker).toList();
    final jokers = cards.where((c) => c.isJoker).toList();
    if (nat.length < 2 || jokers.length > nat.length - 1) return null;
    final rank = nat.first.rank;
    if (nat.every((c) => c.rank == rank)) {
      if (cards.length > 4) return null;
      if (nat.map((c) => c.suit).toSet().length != nat.length) return null;
      nat.sort((a, b) => a.suit.index - b.suit.index);
      return Meld._(MeldKind.set, [...nat, ...jokers], rank.value, null, owner);
    }
    final suit = nat.first.suit;
    if (!nat.every((c) => c.suit == suit)) return null;
    for (final aceHigh in [true, false]) {
      final byPos = <int, PlayingCard>{};
      var dup = false;
      for (final c in nat) {
        final p = _pos(c, aceHigh);
        if (byPos.containsKey(p)) dup = true;
        byPos[p] = c;
      }
      if (dup) continue;
      final ps = byPos.keys.toList()..sort();
      var lo = ps.first;
      var hi = ps.last;
      final gaps = hi - lo + 1 - ps.length;
      if (gaps > jokers.length || hi - lo > 12) continue;
      var extra = jokers.length - gaps;
      while (extra > 0 && hi < 14 && hi - lo < 12) {
        hi++;
        extra--;
      }
      while (extra > 0 && lo > 1 && hi - lo < 12) {
        lo--;
        extra--;
      }
      if (extra > 0) continue;
      var j = 0;
      final ordered = [for (var p = lo; p <= hi; p++) byPos[p] ?? jokers[j++]];
      return Meld._(MeldKind.run, ordered, lo, suit, owner);
    }
    return null;
  }

  /// This meld with [card] laid off on it, or null.
  Meld? withCard(PlayingCard card) {
    if (card.isJoker) {
      if (jokers + 1 > naturals - 1) return null;
      if (kind == MeldKind.set) {
        return cards.length >= 4 ? null : Meld._(kind, [...cards, card], low, suit, owner);
      }
      if (high < 14 && high - low < 12) return Meld._(kind, [...cards, card], low, suit, owner);
      if (low > 1 && high - low < 12) return Meld._(kind, [card, ...cards], low - 1, suit, owner);
      return null;
    }
    if (kind == MeldKind.set) {
      if (card.rank.value != low || cards.length >= 4) return null;
      if (cards.any((c) => !c.isJoker && c.suit == card.suit)) return null;
      final nat = [...cards.where((c) => !c.isJoker), card]..sort((a, b) => a.suit.index - b.suit.index);
      return Meld._(kind, [...nat, ...cards.where((c) => c.isJoker)], low, suit, owner);
    }
    if (card.suit != suit || high - low >= 12) return null;
    for (final p in card.rank == Rank.ace ? [14, 1] : [card.rank.value]) {
      if (p == high + 1) return Meld._(kind, [...cards, card], low, suit, owner);
      if (p == low - 1) return Meld._(kind, [card, ...cards], low - 1, suit, owner);
    }
    return null;
  }

  /// Replaces a joker standing for [natural] with it: the new meld and the
  /// freed joker, or null.
  (Meld, PlayingCard)? swapJoker(PlayingCard natural) {
    if (natural.isJoker || jokers == 0) return null;
    if (kind == MeldKind.set) {
      if (natural.rank.value != low) return null;
      if (cards.any((c) => !c.isJoker && c.suit == natural.suit)) return null;
      final joker = cards.firstWhere((c) => c.isJoker);
      final rest = List.of(cards)..remove(joker);
      final nat = [...rest.where((c) => !c.isJoker), natural]..sort((a, b) => a.suit.index - b.suit.index);
      return (Meld._(kind, [...nat, ...rest.where((c) => c.isJoker)], low, suit, owner), joker);
    }
    if (natural.suit != suit) return null;
    for (var i = 0; i < cards.length; i++) {
      if (!cards[i].isJoker) continue;
      final p = low + i;
      final match = natural.rank == Rank.ace ? (p == 1 || p == 14) : natural.rank.value == p;
      if (match) {
        final next = List.of(cards);
        final joker = next[i];
        next[i] = natural;
        return (Meld._(kind, next, low, suit, owner), joker);
      }
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'cards': cardsToJson(cards),
    'low': low,
    'suit': suit?.code,
    'owner': owner,
  };

  @override
  String toString() => 'Meld(${kind.name} $cards)';
}

/// Card multiset over codes 0..55.
List<int> cardCounts(Iterable<PlayingCard> cards) {
  final counts = List.filled(PlayingCard.jokerBase + PlayingCard.jokerCount, 0);
  for (final c in cards) {
    counts[c.code]++;
  }
  return counts;
}

/// Every distinct meld that can be formed from [hand].
List<Meld> candidateMelds(List<PlayingCard> hand) {
  final jokers = hand.where((c) => c.isJoker).toList();
  final seen = <String>{};
  final out = <Meld>[];
  void add(List<PlayingCard> cards) {
    final m = Meld.arrange(cards);
    if (m != null && seen.add(m.key)) out.add(m);
  }

  // Sets.
  for (final rank in Rank.values) {
    final suits = <Suit, PlayingCard>{};
    for (final c in hand) {
      if (!c.isJoker && c.rank == rank) suits[c.suit] = c;
    }
    if (suits.length + jokers.length < 3 || suits.length < 2) continue;
    final list = suits.values.toList();
    for (var mask = 0; mask < 1 << list.length; mask++) {
      final chosen = [
        for (var i = 0; i < list.length; i++)
          if (mask & (1 << i) != 0) list[i],
      ];
      if (chosen.length < 2) continue;
      for (var k = 0; k <= jokers.length && k <= chosen.length - 1; k++) {
        final size = chosen.length + k;
        if (size < 3 || size > 4) continue;
        add([...chosen, ...jokers.take(k)]);
      }
    }
  }
  // Runs.
  for (final suit in Suit.values) {
    final byPos = <int, PlayingCard>{};
    for (final c in hand) {
      if (c.isJoker || c.suit != suit) continue;
      if (c.rank == Rank.ace) {
        byPos[1] = c;
        byPos[14] = c;
      } else {
        byPos[c.rank.value] = c;
      }
    }
    if (byPos.length < 2) continue;
    for (var lo = 1; lo <= 12; lo++) {
      for (var hi = lo + 2; hi <= 14 && hi - lo <= 12; hi++) {
        if (!byPos.containsKey(lo) && !byPos.containsKey(hi)) continue;
        final nat = [
          for (var p = lo; p <= hi; p++)
            if (byPos.containsKey(p)) byPos[p]!,
        ];
        final len = hi - lo + 1;
        final missing = len - nat.length;
        if (nat.length < 2 || missing > jokers.length || missing > nat.length - 1) continue;
        final m = Meld.arrange([...nat, ...jokers.take(missing)]);
        if (m != null && m.low == lo && m.high == hi && seen.add(m.key)) out.add(m);
      }
    }
  }
  return out;
}

/// A choice of disjoint melds from a hand.
class MeldPlan {
  const MeldPlan(this.melds);

  static const empty = MeldPlan([]);

  final List<Meld> melds;

  int get value => melds.fold(0, (a, m) => a + m.value);
  int get cardCount => melds.fold(0, (a, m) => a + m.cards.length);
  bool get hasRun => melds.any((m) => m.kind == MeldKind.run);
  bool uses(PlayingCard card) => melds.any((m) => m.cards.contains(card));
}

/// Visits combinations of disjoint melds from [candidates] that fit in
/// [hand] (at most [maxCards] cards in total), largest melds first, up to
/// [nodeCap] search nodes. [visit] returns false to stop.
void searchPlans(
  List<PlayingCard> hand,
  List<Meld> candidates,
  bool Function(MeldPlan plan) visit, {
  int? maxCards,
  int nodeCap = 4000,
}) {
  final counts = cardCounts(hand);
  final limit = maxCards ?? hand.length;
  final sorted = List.of(candidates)..sort((a, b) => b.value - a.value);
  final needs = [for (final m in sorted) cardCounts(m.cards)];
  var nodes = 0;
  var stop = false;
  final chosen = <Meld>[];
  void dfs(int start, int used) {
    if (stop) return;
    for (var i = start; i < sorted.length && !stop; i++) {
      if (++nodes > nodeCap) {
        stop = true;
        return;
      }
      final m = sorted[i];
      if (used + m.cards.length > limit) continue;
      final need = needs[i];
      var ok = true;
      for (final c in m.cards) {
        if (counts[c.code] < need[c.code]) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      for (final c in m.cards) {
        counts[c.code]--;
      }
      chosen.add(m);
      if (!visit(MeldPlan(List.of(chosen)))) stop = true;
      dfs(i + 1, used + m.cards.length);
      chosen.removeLast();
      for (final c in m.cards) {
        counts[c.code]++;
      }
    }
  }

  dfs(0, 0);
}

/// The plan with the highest value (then most cards) satisfying [accept].
MeldPlan bestPlan(
  List<PlayingCard> hand, {
  int keep = 0,
  bool Function(MeldPlan plan)? accept,
  List<Meld>? candidates,
  int nodeCap = 4000,
}) {
  var best = MeldPlan.empty;
  searchPlans(
    hand,
    candidates ?? candidateMelds(hand),
    (p) {
      if (accept != null && !accept(p)) return true;
      if (p.value > best.value || (p.value == best.value && p.cardCount > best.cardCount)) best = p;
      return true;
    },
    maxCards: hand.length - keep,
    nodeCap: nodeCap,
  );
  return best;
}
