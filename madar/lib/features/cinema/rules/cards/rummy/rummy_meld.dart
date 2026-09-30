/// Melds for the rummy games (Hand, Konkan): sets and runs with wild cards,
/// lay-offs, wild swaps, and the search for melds in a hand.
///
/// Which cards are wild depends on the round (the printed jokers, or with
/// the indicator option the two aces of one suit), so every operation goes
/// through a [MeldRules] built from the options and the round.
library;

import '../core/playing_card.dart';

enum MeldKind {
  /// Three or four cards of one rank in different suits.
  set,

  /// Three to thirteen consecutive cards of one suit (ace low A-2-3 or high
  /// Q-K-A, never round the corner).
  run,
}

int _bitCount(int x) {
  var n = 0;
  for (var v = x; v != 0; v &= v - 1) {
    n++;
  }
  return n;
}

int _jokerMask(List<PlayingCard> cards) {
  var mask = 0;
  for (var i = 0; i < cards.length; i++) {
    if (cards[i].isJoker) mask |= 1 << i;
  }
  return mask;
}

/// A meld on the table (or a candidate). A run keeps its cards in position
/// order with each wild in the slot it stands for; a set keeps its natural
/// cards by suit, then its wild.
class Meld {
  const Meld._(this.kind, this.cards, this.low, this.suit, this.owner, this.wildMask, this.value);

  factory Meld.fromJson(Map<String, Object?> j) {
    final cards = cardsFromJson(j['cards']);
    return Meld._(
      MeldKind.values.byName(j['kind']! as String),
      cards,
      j['low']! as int,
      j['suit'] == null ? null : Suit.fromCode(j['suit']! as String),
      j['owner']! as int,
      j['w'] as int? ?? _jokerMask(cards),
      j['v'] as int? ?? 0,
    );
  }

  final MeldKind kind;
  final List<PlayingCard> cards;

  /// Run: position of the first card (1 = ace low … 14 = ace high). Set: the
  /// rank value (2..14).
  final int low;

  /// A run's suit.
  final Suit? suit;

  /// Seat that put it down (-1 for a candidate).
  final int owner;

  /// Bit i set: `cards[i]` is a wild card.
  final int wildMask;

  /// Opening value when it was formed.
  final int value;

  int get high => kind == MeldKind.run ? low + cards.length - 1 : low;
  int get wilds => _bitCount(wildMask);
  int get naturals => cards.length - wilds;
  bool isWildAt(int i) => wildMask & (1 << i) != 0;

  /// The wild cards of this meld.
  List<PlayingCard> get wildCards => [
    for (var i = 0; i < cards.length; i++)
      if (isWildAt(i)) cards[i],
  ];

  /// A set's rank.
  Rank get rank => Rank.fromValue(low);

  Meld withOwner(int seat) => Meld._(kind, cards, low, suit, seat, wildMask, value);

  /// Identifies the meld: the multiset of cards (and a run's first position,
  /// which tells apart the two places of an end wild).
  String get key => '${(cards.map((c) => c.code).toList()..sort()).join(',')}${kind == MeldKind.run ? '@$low' : ''}';

  /// A run whose wild stands at its low end although the high end was free
  /// too: the placement the player chose (`wildLow` in a move).
  bool get wildPlacedLow => kind == MeldKind.run && isWildAt(0) && high < 14;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'cards': cardsToJson(cards),
    'low': low,
    'suit': suit?.code,
    'owner': owner,
    'w': wildMask,
    'v': value,
  };

  @override
  bool operator ==(Object other) =>
      other is Meld && other.kind == kind && other.low == low && other.owner == owner && other._codes == _codes;

  String get _codes => '${cards.map((c) => c.code).join(',')}:$wildMask';

  @override
  int get hashCode => Object.hash(kind, low, owner, _codes);

  @override
  String toString() => 'Meld(${kind.name} $cards)';
}

/// Which cards are wild in a round and how melds are valued and changed.
class MeldRules {
  const MeldRules({
    this.wildAceSuit,
    this.maxWilds = 1,
    this.aceLowValue = 11,
    this.aceHighValue = 11,
    this.setSwapNeedsBoth = true,
  });

  /// With the indicator option: the two aces of this suit are wild and the
  /// printed jokers are natural aces of it. Null: the printed jokers are the
  /// wild cards.
  final Suit? wildAceSuit;

  /// Wilds allowed in one meld; a meld always has more naturals than wilds.
  final int maxWilds;

  /// Opening value of an ace in A-2-3 and in Q-K-A (an ace in a set is 11).
  final int aceLowValue;
  final int aceHighValue;

  /// A set of two naturals and a wild frees its wild only with both missing
  /// suits at once.
  final bool setSwapNeedsBoth;

  bool isWild(PlayingCard c) =>
      wildAceSuit == null ? c.isJoker : (!c.isJoker && c.rank == Rank.ace && c.suit == wildAceSuit);

  /// Suit of a natural card (a printed joker is a natural ace of
  /// [wildAceSuit]).
  Suit suitOf(PlayingCard c) => c.isJoker ? wildAceSuit! : c.suit;

  /// Rank of a natural card.
  Rank rankOf(PlayingCard c) => c.isJoker ? Rank.ace : c.rank;

  /// Whether a natural card is the card at run [position] of [suit].
  bool isCardAt(PlayingCard c, Suit suit, int position) {
    if (isWild(c) || suitOf(c) != suit) return false;
    final r = rankOf(c);
    return r == Rank.ace ? (position == 1 || position == 14) : r.value == position;
  }

  /// Opening value of the card at run [position].
  int positionValue(int position) =>
      position == 1 ? aceLowValue : (position == 14 ? aceHighValue : (position > 10 ? 10 : position));

  int _setCardValue(Rank r) => r == Rank.ace ? 11 : (r.value > 10 ? 10 : r.value);

  Meld _set(Rank rank, List<PlayingCard> nats, List<PlayingCard> wilds, int owner) {
    final ns = List.of(nats)..sort((a, b) => suitOf(a).index - suitOf(b).index);
    final cards = [...ns, ...wilds];
    var mask = 0;
    for (var i = ns.length; i < cards.length; i++) {
      mask |= 1 << i;
    }
    return Meld._(MeldKind.set, cards, rank.value, null, owner, mask, _setCardValue(rank) * cards.length);
  }

  Meld _run(Suit suit, int low, List<PlayingCard> cards, int mask, int owner) {
    var v = 0;
    for (var i = 0; i < cards.length; i++) {
      v += positionValue(low + i);
    }
    return Meld._(MeldKind.run, cards, low, suit, owner, mask, v);
  }

  /// Arranges [cards] into a valid meld, or null. A spare wild in a run goes
  /// to the high end unless [wildLow] (or the high end is closed).
  Meld? arrange(List<PlayingCard> cards, {int owner = -1, bool wildLow = false}) {
    if (cards.length < 3 || cards.length > 13) return null;
    final wild = <PlayingCard>[];
    final nat = <PlayingCard>[];
    for (final c in cards) {
      (isWild(c) ? wild : nat).add(c);
    }
    if (wild.length > maxWilds || wild.length >= nat.length) return null;
    final rank = rankOf(nat.first);
    if (nat.every((c) => rankOf(c) == rank)) {
      if (cards.length > 4) return null;
      if (nat.map(suitOf).toSet().length != nat.length) return null;
      return _set(rank, nat, wild, owner);
    }
    final suit = suitOf(nat.first);
    if (!nat.every((c) => suitOf(c) == suit)) return null;
    for (final aceHigh in [true, false]) {
      final byPos = <int, PlayingCard>{};
      var dup = false;
      for (final c in nat) {
        final r = rankOf(c);
        final p = r == Rank.ace ? (aceHigh ? 14 : 1) : r.value;
        if (byPos.containsKey(p)) dup = true;
        byPos[p] = c;
      }
      if (dup) continue;
      final ps = byPos.keys.toList()..sort();
      var lo = ps.first;
      var hi = ps.last;
      final gaps = hi - lo + 1 - ps.length;
      if (gaps > wild.length || hi - lo > 12) continue;
      var extra = wild.length - gaps;
      void up() {
        while (extra > 0 && hi < 14 && hi - lo < 12) {
          hi++;
          extra--;
        }
      }

      void down() {
        while (extra > 0 && lo > 1 && hi - lo < 12) {
          lo--;
          extra--;
        }
      }

      if (wildLow) {
        down();
        up();
      } else {
        up();
        down();
      }
      if (extra > 0) continue;
      var j = 0;
      var mask = 0;
      final ordered = <PlayingCard>[];
      for (var p = lo; p <= hi; p++) {
        final c = byPos[p];
        if (c == null) mask |= 1 << (p - lo);
        ordered.add(c ?? wild[j++]);
      }
      return _run(suit, lo, ordered, mask, owner);
    }
    return null;
  }

  /// The suits a set's wild may stand for (the suits no natural card has).
  List<Suit> missingSuits(Meld m) {
    final have = {
      for (var i = 0; i < m.cards.length; i++)
        if (!m.isWildAt(i)) suitOf(m.cards[i]),
    };
    return [
      for (final s in Suit.values)
        if (!have.contains(s)) s,
    ];
  }

  /// [m] with [card] laid off on it, or null. A wild goes to the high end of
  /// a run unless [atLow] (or the high end is closed).
  Meld? withCard(Meld m, PlayingCard card, {bool atLow = false}) {
    if (isWild(card)) {
      if (m.wilds + 1 > maxWilds || m.wilds + 1 >= m.naturals) return null;
      if (m.kind == MeldKind.set) {
        if (m.cards.length >= 4) return null;
        return Meld._(m.kind, [...m.cards, card], m.low, m.suit, m.owner, m.wildMask | (1 << m.cards.length), m.value);
      }
      if (m.cards.length >= 13) return null;
      final canHigh = m.high < 14;
      final canLow = m.low > 1;
      if (canLow && (atLow || !canHigh)) {
        return _run(m.suit!, m.low - 1, [card, ...m.cards], m.wildMask << 1 | 1, m.owner);
      }
      if (canHigh) return _run(m.suit!, m.low, [...m.cards, card], m.wildMask | (1 << m.cards.length), m.owner);
      return null;
    }
    if (m.kind == MeldKind.set) {
      if (rankOf(card) != m.rank || m.cards.length >= 4) return null;
      if (!missingSuits(m).contains(suitOf(card))) return null;
      final nats = [
        for (var i = 0; i < m.cards.length; i++)
          if (!m.isWildAt(i)) m.cards[i],
        card,
      ];
      return _set(m.rank, nats, m.wildCards, m.owner);
    }
    if (suitOf(card) != m.suit || m.cards.length >= 13) return null;
    final r = rankOf(card);
    for (final p in r == Rank.ace ? const [14, 1] : [r.value]) {
      if (p == m.high + 1) return _run(m.suit!, m.low, [...m.cards, card], m.wildMask, m.owner);
      if (p == m.low - 1) return _run(m.suit!, m.low - 1, [card, ...m.cards], m.wildMask << 1, m.owner);
    }
    return null;
  }

  /// Puts the natural card(s) [nats] in place of a wild of [m]: the new meld
  /// and the freed wild, or null. A run takes the exact card of the wild's
  /// position; a set of three naturals and a wild takes the missing suit; a
  /// set of two naturals and a wild takes both missing suits
  /// ([setSwapNeedsBoth]) or either one.
  (Meld, PlayingCard)? swap(Meld m, List<PlayingCard> nats) {
    if (m.wilds == 0 || nats.isEmpty || nats.any(isWild)) return null;
    if (m.kind == MeldKind.set) {
      final missing = missingSuits(m);
      if (nats.any((c) => rankOf(c) != m.rank || !missing.contains(suitOf(c)))) return null;
      if (nats.map(suitOf).toSet().length != nats.length) return null;
      // Three naturals and a wild: the missing suit. Two and a wild: both
      // missing suits, or (without [setSwapNeedsBoth]) either one too.
      final ok = m.cards.length == 4 ? nats.length == 1 : (nats.length == 2 || (!setSwapNeedsBoth && nats.length == 1));
      if (!ok) return null;
      final wilds = m.wildCards;
      final freed = wilds.first;
      final nat = [
        for (var i = 0; i < m.cards.length; i++)
          if (!m.isWildAt(i)) m.cards[i],
        ...nats,
      ];
      return (_set(m.rank, nat, wilds.sublist(1), m.owner), freed);
    }
    if (nats.length != 1) return null;
    final natural = nats.single;
    for (var i = 0; i < m.cards.length; i++) {
      if (m.isWildAt(i) && isCardAt(natural, m.suit!, m.low + i)) {
        final next = List.of(m.cards);
        final freed = next[i];
        next[i] = natural;
        return (_run(m.suit!, m.low, next, m.wildMask & ~(1 << i), m.owner), freed);
      }
    }
    return null;
  }

  /// Every distinct meld that can be formed from [hand] (both places of an
  /// end wild, each distinct wild card).
  List<Meld> candidates(List<PlayingCard> hand) {
    final sorted = List.of(hand)..sort();
    final wilds = sorted.where(isWild).toList();
    final nats = sorted.where((c) => !isWild(c)).toList();
    final combos = <int, List<List<PlayingCard>>>{};
    List<List<PlayingCard>> wildCombos(int k) => combos.putIfAbsent(k, () => _combos(wilds, k));
    final seen = <String>{};
    final out = <Meld>[];
    void add(Meld m) {
      if (seen.add(m.key)) out.add(m);
    }

    // Sets.
    for (final rank in Rank.values) {
      final bySuit = <Suit, PlayingCard>{};
      for (final c in nats) {
        if (rankOf(c) == rank) bySuit[suitOf(c)] = c;
      }
      if (bySuit.length < 2) continue;
      final list = [
        for (final s in Suit.values)
          if (bySuit.containsKey(s)) bySuit[s]!,
      ];
      for (var mask = 0; mask < 1 << list.length; mask++) {
        final chosen = [
          for (var i = 0; i < list.length; i++)
            if (mask & (1 << i) != 0) list[i],
        ];
        if (chosen.length < 2) continue;
        for (var k = 0; k <= maxWilds && k < chosen.length; k++) {
          final size = chosen.length + k;
          if (size < 3 || size > 4) continue;
          for (final w in wildCombos(k)) {
            add(_set(rank, chosen, w, -1));
          }
        }
      }
    }
    // Runs.
    for (final suit in Suit.values) {
      final byPos = <int, PlayingCard>{};
      for (final c in nats) {
        if (suitOf(c) != suit) continue;
        final r = rankOf(c);
        if (r == Rank.ace) {
          byPos[1] = c;
          byPos[14] = c;
        } else {
          byPos[r.value] = c;
        }
      }
      if (byPos.length < 2) continue;
      for (var lo = 1; lo <= 12; lo++) {
        for (var hi = lo + 2; hi <= 14 && hi - lo <= 12; hi++) {
          var n = 0;
          for (var p = lo; p <= hi; p++) {
            if (byPos.containsKey(p)) n++;
          }
          final missing = hi - lo + 1 - n;
          if (n < 2 || missing > maxWilds || missing >= n || missing > wilds.length) continue;
          for (final w in wildCombos(missing)) {
            var j = 0;
            var mask = 0;
            final cards = <PlayingCard>[];
            for (var p = lo; p <= hi; p++) {
              final c = byPos[p];
              if (c == null) mask |= 1 << (p - lo);
              cards.add(c ?? w[j++]);
            }
            add(_run(suit, lo, cards, mask, -1));
          }
        }
      }
    }
    return out;
  }

  /// Whether the wild [card] of [m] stands for an ace (and, for a wild ace,
  /// for the ace of its own suit): the use allowed for a wild taken from the
  /// discard pile with the indicator option.
  bool wildUsedAsAce(Meld m, PlayingCard card) {
    final ownSuit = card.isJoker ? null : card.suit;
    if (m.kind == MeldKind.set) {
      return m.rank == Rank.ace && (ownSuit == null || missingSuits(m).contains(ownSuit));
    }
    for (var i = 0; i < m.cards.length; i++) {
      if (!m.isWildAt(i) || m.cards[i] != card) continue;
      final p = m.low + i;
      if ((p == 1 || p == 14) && (ownSuit == null || m.suit == ownSuit)) return true;
    }
    return false;
  }
}

/// The distinct k-card combinations of a sorted multiset.
List<List<PlayingCard>> _combos(List<PlayingCard> items, int k) {
  final out = <List<PlayingCard>>[];
  final pick = <PlayingCard>[];
  void go(int start) {
    if (pick.length == k) {
      out.add(List.of(pick));
      return;
    }
    for (var i = start; i < items.length; i++) {
      if (i > start && items[i] == items[i - 1]) continue;
      pick.add(items[i]);
      go(i + 1);
      pick.removeLast();
    }
  }

  go(0);
  return out;
}

/// Card multiset over codes 0..55.
List<int> cardCounts(Iterable<PlayingCard> cards) {
  final counts = List.filled(PlayingCard.jokerBase + PlayingCard.jokerCount, 0);
  for (final c in cards) {
    counts[c.code]++;
  }
  return counts;
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
  List<PlayingCard> get cards => [for (final m in melds) ...m.cards];

  /// Identifies the plan (order of melds ignored).
  String get key => (melds.map((m) => m.key).toList()..sort()).join('|');
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

/// Visits plans of disjoint melds that leave between 1 and [maxLeft] cards
/// of [hand] uncovered (an exact cover of the hand with a few cards left
/// over), up to [nodeCap] nodes. [visit] gets the plan and the cards left
/// and returns false to stop. Used to find the ways to go out in one turn.
void coverPlans(
  List<PlayingCard> hand,
  List<Meld> candidates,
  int maxLeft,
  bool Function(MeldPlan plan, List<PlayingCard> left) visit, {
  int nodeCap = 3000,
}) {
  final counts = cardCounts(hand);
  final sorted = List.of(candidates)..sort((a, b) => b.cards.length - a.cards.length);
  final needs = [for (final m in sorted) cardCounts(m.cards)];
  final byCard = List.generate(counts.length, (_) => <int>[]);
  for (var i = 0; i < sorted.length; i++) {
    for (final code in {for (final c in sorted[i].cards) c.code}) {
      byCard[code].add(i);
    }
  }
  final chosen = <Meld>[];
  final left = <PlayingCard>[];
  var nodes = 0;
  var stop = false;
  bool fits(int i) {
    final need = needs[i];
    for (final c in sorted[i].cards) {
      if (need[c.code] > counts[c.code]) return false;
    }
    return true;
  }

  void dfs(int skips) {
    if (stop) return;
    if (++nodes > nodeCap) {
      stop = true;
      return;
    }
    var code = -1;
    for (var c = 0; c < counts.length; c++) {
      if (counts[c] > 0) {
        code = c;
        break;
      }
    }
    if (code < 0) {
      if (left.isNotEmpty && chosen.isNotEmpty && !visit(MeldPlan(List.of(chosen)), List.of(left))) stop = true;
      return;
    }
    for (final i in byCard[code]) {
      if (!fits(i)) continue;
      for (final c in sorted[i].cards) {
        counts[c.code]--;
      }
      chosen.add(sorted[i]);
      dfs(skips);
      chosen.removeLast();
      for (final c in sorted[i].cards) {
        counts[c.code]++;
      }
      if (stop) return;
    }
    if (skips > 0) {
      counts[code]--;
      left.add(PlayingCard.fromCode(code));
      dfs(skips - 1);
      left.removeLast();
      counts[code]++;
    }
  }

  dfs(maxLeft);
}

/// The plan with the highest value (then most cards) satisfying [accept].
MeldPlan bestPlan(
  List<PlayingCard> hand,
  MeldRules rules, {
  int keep = 0,
  bool Function(MeldPlan plan)? accept,
  List<Meld>? candidates,
  int nodeCap = 4000,
}) {
  var best = MeldPlan.empty;
  searchPlans(
    hand,
    candidates ?? rules.candidates(hand),
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
