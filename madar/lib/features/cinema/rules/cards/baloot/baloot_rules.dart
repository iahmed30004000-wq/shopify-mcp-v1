/// Baloot (بلوت) rules as commonly played in Jordan (the Saudi game): the
/// two-round auction with Ashkal, Sun priority and the Hokom confirmation,
/// the doubling ladder with locked play, projects (sira / 50 / 100 / 400),
/// belote, the Saudi trumping rules with Ekka, counting-team scoring with
/// the rounding tie-break, kaboot and the match to 152. See RULES.md for
/// every choice made.
library;

import '../core/card_game.dart';
import '../core/deck.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';
import 'baloot_state.dart';

/// The outcome of [BalootRules.scoreFigures].
class BalootDealScore {
  const BalootDealScore(this.points, this.winner, this.countingTeam, this.gamePoints);

  /// Game points scored per team.
  final List<int> points;

  /// The team that won the deal.
  final int winner;

  /// The team whose card points were converted (null for a kaboot).
  final int? countingTeam;

  /// Card points as game points per team (for a kaboot: 25 / 44 to the
  /// kaboot team).
  final List<int> gamePoints;

  @override
  String toString() => 'BalootDealScore($points, winner: $winner, counting: $countingTeam)';
}

class BalootRules extends CardRules<BalootState, BalootMove> {
  const BalootRules();

  /// Order without trumps: 7 8 9 J Q K 10 A.
  static int sunRank(Rank r) => switch (r) {
    Rank.seven => 0,
    Rank.eight => 1,
    Rank.nine => 2,
    Rank.jack => 3,
    Rank.queen => 4,
    Rank.king => 5,
    Rank.ten => 6,
    Rank.ace => 7,
    _ => -1,
  };

  /// Trump order: 7 8 Q K 10 A 9 J.
  static int trumpRank(Rank r) => switch (r) {
    Rank.seven => 0,
    Rank.eight => 1,
    Rank.queen => 2,
    Rank.king => 3,
    Rank.ten => 4,
    Rank.ace => 5,
    Rank.nine => 6,
    Rank.jack => 7,
    _ => -1,
  };

  static bool isTrump(PlayingCard c, BalootMode? mode, Suit? trump) => mode == BalootMode.hokom && c.suit == trump;

  static int cardPoints(PlayingCard c, BalootMode? mode, Suit? trump) {
    if (isTrump(c, mode, trump)) {
      return switch (c.rank) {
        Rank.jack => 20,
        Rank.nine => 14,
        Rank.ace => 11,
        Rank.ten => 10,
        Rank.king => 4,
        Rank.queen => 3,
        _ => 0,
      };
    }
    return switch (c.rank) {
      Rank.ace => 11,
      Rank.ten => 10,
      Rank.king => 4,
      Rank.queen => 3,
      Rank.jack => 2,
      _ => 0,
    };
  }

  static int power(PlayingCard c, Suit led, BalootMode? mode, Suit? trump) {
    if (isTrump(c, mode, trump)) return 100 + trumpRank(c.rank);
    if (c.suit == led) return sunRank(c.rank);
    return -1;
  }

  /// Base game points of a deal (26 Sun, 16 Hokom) and of a kaboot (all
  /// eight tricks: 44 Sun, 25 Hokom).
  static int basePoints(BalootMode mode) => mode == BalootMode.sun ? 26 : 16;
  static int kabootPoints(BalootMode mode) => mode == BalootMode.sun ? 44 : 25;

  /// Card points per game point: 5 in Sun, 10 in Hokom.
  static int unit(BalootMode mode) => mode == BalootMode.sun ? 5 : 10;

  /// Converts the counting team's card points to game points. Hokom: to the
  /// nearest ten, a 5 rounding down, then ÷ 10. Sun: to the nearest ten,
  /// except that a total ending in 5 is kept, then ÷ 5. The other team gets
  /// the rest of 16 / 26.
  static int gamePoints(BalootMode mode, int countingRaw) {
    if (mode == BalootMode.hokom) return (countingRaw + 4) ~/ 10;
    if (countingRaw % 10 == 5) return countingRaw ~/ 5;
    return 2 * ((countingRaw + 5) ~/ 10);
  }

  static bool doublingAllowed(BalootState s) {
    if (!s.options.doubling) return false;
    if (s.mode == BalootMode.hokom) return true;
    final takers = s.teamScores[s.buyer % 2];
    final defenders = s.teamScores[1 - s.buyer % 2];
    return switch (s.options.sunDoubleRule) {
      BalootSunDoubleRule.takersOver100DoublersUnder100 => takers > 100 && defenders < 100,
      BalootSunDoubleRule.oneOver100OneUnder => (takers > 100 && defenders < 100) || (defenders > 100 && takers < 100),
      BalootSunDoubleRule.always => true,
      BalootSunDoubleRule.never => false,
    };
  }

  // ---------------------------------------------------------------- auction

  /// Ashkal is open to the 3rd and 4th speakers while nobody has bid, in
  /// round 1 (and round 2 with `ashkalInRound2`), not on an up-turned Ace
  /// unless `ashkalOnAce`.
  static bool ashkalAllowed(BalootState s, int seat) {
    final o = s.options;
    if (!o.ashkal || s.bidStage != BalootBidStage.open || s.mode != null) return false;
    if (!(s.bidRound == 1 || (s.bidRound == 2 && o.ashkalInRound2))) return false;
    if (s.speakerIndex(seat) < 2) return false;
    return s.upCard!.rank != Rank.ace || o.ashkalOnAce;
  }

  /// Kawesh: in round 1, at the player's turn, a five-card hand of 7s, 8s
  /// and 9s only.
  static bool kaweshAllowed(BalootState s, int seat) {
    if (!s.options.kawesh || s.bidRound != 1 || s.bidStage != BalootBidStage.open) return false;
    final hand = s.hands[seat];
    return hand.length == 5 && hand.every((c) => c.rank == Rank.seven || c.rank == Rank.eight || c.rank == Rank.nine);
  }

  List<BalootMove> _bidMoves(BalootState s, int seat) {
    switch (s.bidStage) {
      case BalootBidStage.confirm:
        return const [BalootMove.confirm(), BalootMove.sun()];
      case BalootBidStage.priority:
        return const [BalootMove.pass(), BalootMove.sun()];
      case BalootBidStage.open:
        final up = s.upCard!.suit;
        return [
          const BalootMove.pass(),
          if (s.mode == null)
            for (final suit in Suit.values)
              if (s.bidRound == 1 ? suit == up : (s.bidRound == 2 ? suit != up : true)) BalootMove.hokom(suit),
          const BalootMove.sun(),
          if (ashkalAllowed(s, seat)) const BalootMove.ashkal(),
          if (kaweshAllowed(s, seat)) const BalootMove.kawesh(),
        ];
    }
  }

  // ------------------------------------------------------------- projects

  /// The best set of non-overlapping projects in [hand] (by total value,
  /// then by the best single project).
  static List<BalootProject> detectProjects(List<PlayingCard> hand, int seat, BalootMode mode) {
    final candidates = <BalootProject>[];
    for (final r in [Rank.ace, Rank.ten, Rank.king, Rank.queen, Rank.jack]) {
      final four = [for (final s in Suit.values) PlayingCard(s, r)];
      if (four.every(hand.contains)) {
        final type = r == Rank.ace && mode == BalootMode.sun
            ? BalootProjectType.fourHundred
            : BalootProjectType.hundred;
        candidates.add(BalootProject(type, seat, four));
      }
    }
    for (final suit in Suit.values) {
      final idx = ofSuit(hand, suit).map((c) => naturalIndex(c.rank)).toSet();
      final ranksByIndex = {for (final c in ofSuit(hand, suit)) naturalIndex(c.rank): c};
      for (var start = 0; start <= 5; start++) {
        for (var len = 3; len <= 5 && start + len <= 8; len++) {
          if (!Iterable<int>.generate(len, (k) => start + k).every(idx.contains)) break;
          final type = len == 3
              ? BalootProjectType.sira
              : (len == 4 ? BalootProjectType.fifty : BalootProjectType.hundred);
          candidates.add(BalootProject(type, seat, [for (var k = 0; k < len; k++) ranksByIndex[start + k]!]));
        }
      }
    }
    var best = <BalootProject>[];
    var bestValue = 0;
    void dfs(int i, Set<PlayingCard> used, List<BalootProject> chosen, int value) {
      if (value > bestValue ||
          (value == bestValue &&
              value > 0 &&
              compareProjects(_strongest(chosen, mode), _strongest(best, mode), 0, mode) > 0)) {
        bestValue = value;
        best = List.of(chosen);
      }
      for (var j = i; j < candidates.length; j++) {
        final p = candidates[j];
        if (p.cards.any(used.contains)) continue;
        chosen.add(p);
        dfs(j + 1, {...used, ...p.cards}, chosen, value + p.value(mode));
        chosen.removeLast();
      }
    }

    dfs(0, {}, [], 0);
    return best;
  }

  static BalootProject _strongest(List<BalootProject> ps, BalootMode mode) =>
      ps.reduce((a, b) => compareProjects(a, b, 0, mode) >= 0 ? a : b);

  /// > 0 when [a] beats [b]: higher value; among hundreds, four of a kind
  /// beats a sequence (or the reverse with `sequenceBeatsCarre`); the higher
  /// top card; with `trumpSequencePriority`, a trump sequence; then the
  /// player nearer the first speaker ([firstPlayer]).
  static int compareProjects(
    BalootProject a,
    BalootProject b,
    int firstPlayer,
    BalootMode mode, {
    Suit? trump,
    BalootOptions options = const BalootOptions(),
  }) {
    final dv = a.value(mode) - b.value(mode);
    if (dv != 0) return dv;
    if (a.type == BalootProjectType.hundred && a.isCarre != b.isCarre) {
      return (a.isCarre != options.sequenceBeatsCarre) ? 1 : -1;
    }
    final dt = a.topIndex - b.topIndex;
    if (dt != 0) return dt;
    if (options.trumpSequencePriority && mode == BalootMode.hokom && trump != null && !a.isCarre && !b.isCarre) {
      final at = a.cards.first.suit == trump;
      final bt = b.cards.first.suit == trump;
      if (at != bt) return at ? 1 : -1;
    }
    return ((b.seat - firstPlayer + 4) % 4) - ((a.seat - firstPlayer + 4) % 4);
  }

  /// Team whose projects count (the owner of the single best project), or
  /// null.
  static int? projectTeam(
    List<BalootProject> projects,
    int firstPlayer,
    BalootMode mode, {
    Suit? trump,
    BalootOptions options = const BalootOptions(),
  }) {
    if (projects.isEmpty) return null;
    var best = projects.first;
    for (final p in projects.skip(1)) {
      if (compareProjects(p, best, firstPlayer, mode, trump: trump, options: options) > 0) best = p;
    }
    return best.seat % 2;
  }

  /// The seat that held the K and Q of trumps when play started (hand plus
  /// the cards it has played), or -1.
  static int beloteHolder(BalootState s) {
    if (s.mode != BalootMode.hokom || s.trump == null) return -1;
    final k = PlayingCard(s.trump!, Rank.king);
    final q = PlayingCard(s.trump!, Rank.queen);
    for (var seat = 0; seat < 4; seat++) {
      final held = <PlayingCard>{...s.hands[seat]};
      for (final t in [...s.tricks, ?s.trick]) {
        final c = t.cardOf(seat);
        if (c != null) held.add(c);
      }
      if (held.contains(k) && held.contains(q)) return seat;
    }
    return -1;
  }

  /// Whether the belote counts: it does not when its holder's team scores
  /// its projects and the holder's own hundred contains the trump K or Q.
  static bool beloteCounts(BalootState s) {
    if (s.belote < 0 || s.mode != BalootMode.hokom) return false;
    final pt = projectTeam(s.projects, s.firstPlayer, s.mode!, trump: s.trump, options: s.options);
    if (pt != s.belote % 2) return true;
    final k = PlayingCard(s.trump!, Rank.king);
    final q = PlayingCard(s.trump!, Rank.queen);
    return !s.projects.any(
      (p) =>
          p.seat == s.belote &&
          p.type == BalootProjectType.hundred &&
          (p.cards.contains(k) || p.cards.contains(q)),
    );
  }

  // ---------------------------------------------------------------- legal

  /// A side-suit lead in Hokom that is the highest card of its suit not yet
  /// played in an earlier trick (an Ace always is).
  static bool isEkka(BalootState s, PlayingCard lead) {
    if (s.mode != BalootMode.hokom || lead.suit == s.trump) return false;
    final played = {for (final t in s.tricks) ...t.cards};
    for (final r in balootRanks) {
      if (sunRank(r) > sunRank(lead.rank) && !played.contains(PlayingCard(lead.suit, r))) return false;
    }
    return true;
  }

  static List<PlayingCard> playable(BalootState s, int seat) {
    final hand = s.hands[seat];
    final trick = s.trick!;
    final led = trick.ledSuit;
    final o = s.options;
    if (led == null) {
      if (s.locked && s.mode == BalootMode.hokom) {
        final side = hand.where((c) => c.suit != s.trump).toList();
        if (side.isNotEmpty) return side;
      }
      return List.of(hand);
    }
    final follow = hand.where((c) => c.suit == led).toList();
    if (s.mode == BalootMode.sun) return follow.isNotEmpty ? follow : List.of(hand);
    final trump = s.trump!;
    var bestTrump = -1;
    for (final c in trick.cards) {
      if (c.suit == trump && trumpRank(c.rank) > bestTrump) bestTrump = trumpRank(c.rank);
    }
    final winIdx = trick.winningIndex((c, l) => power(c, l, s.mode, s.trump));
    final partnerWinning = trick.seats[winIdx] % 2 == seat % 2;
    if (led == trump) {
      if (follow.isEmpty) return List.of(hand);
      final mustBeat =
          o.mustOvertrump && (!partnerWinning || o.trumpLedOvertrump == BalootTrumpLedOvertrump.always);
      if (mustBeat) {
        final higher = follow.where((c) => trumpRank(c.rank) > bestTrump).toList();
        if (higher.isNotEmpty) return higher;
      }
      return follow;
    }
    if (follow.isNotEmpty) return follow;
    final trumps = hand.where((c) => c.suit == trump).toList();
    if (trumps.isEmpty || !o.voidMustTrump) return List.of(hand);
    if (partnerWinning) {
      switch (o.partnerWinningVoid) {
        case BalootPartnerWinningVoid.free:
          return List.of(hand);
        case BalootPartnerWinningVoid.saudi:
          // 4th to play: free. 3rd to play (the partner led and is winning):
          // free after an Ace or an Ekka, otherwise any trump.
          if (trick.length == 3) return List.of(hand);
          final lead = trick.cards.first;
          if (lead.rank == Rank.ace || isEkka(s, lead)) return List.of(hand);
          return trumps;
        case BalootPartnerWinningVoid.alwaysTrump:
          break;
      }
    }
    if (bestTrump >= 0 && o.mustOvertrump) {
      final higher = trumps.where((c) => trumpRank(c.rank) > bestTrump).toList();
      // Unable to over-trump: free to play anything.
      return higher.isNotEmpty ? higher : List.of(hand);
    }
    return trumps;
  }

  /// Manual declaration: [seat] must declare or skip before its first card.
  static bool mustDecideProjects(BalootState s, int seat) =>
      s.phase == BalootPhase.playing &&
      s.options.declareProjects == BalootDeclareProjects.manual &&
      s.tricks.isEmpty &&
      !s.projectsDecided[seat] &&
      s.trick != null &&
      !s.trick!.seats.contains(seat) &&
      detectProjects(s.hands[seat], seat, s.mode!).isNotEmpty;

  @override
  List<BalootMove> legalMoves(BalootState s, int seat) {
    if (s.isOver || s.turn != seat) return const [];
    switch (s.phase) {
      case BalootPhase.bidding:
        return _bidMoves(s, seat);
      case BalootPhase.doubling:
        final lockable = s.mode == BalootMode.hokom && (s.level == 1 || s.level == 3);
        return [
          const BalootMove.pass(),
          const BalootMove.raise(),
          if (lockable) const BalootMove.raise(locked: true),
        ];
      case BalootPhase.playing:
        if (mustDecideProjects(s, seat)) return const [BalootMove.declareProjects(), BalootMove.skipProjects()];
        return [for (final c in playable(s, seat)) BalootMove.play(c)];
      case BalootPhase.over:
        return const [];
    }
  }

  @override
  String? validate(BalootState s, int seat, BalootMove m) {
    final base = super.validate(s, seat, m);
    if (base != 'illegalMove') return base;
    if (m.kind == BalootMoveKind.play && s.phase == BalootPhase.playing) {
      if (mustDecideProjects(s, seat)) return 'declareProjectsFirst';
      if (!s.hands[seat].contains(m.card)) return 'cardNotInHand';
      final led = s.trick!.ledSuit;
      if (led == null) return 'lockedTrumpLead';
      if (s.hands[seat].any((c) => c.suit == led) && m.card!.suit != led) return 'mustFollowSuit';
      return m.card!.suit == s.trump ? 'mustOvertrump' : 'mustTrump';
    }
    if (s.phase == BalootPhase.bidding) {
      return switch (m.kind) {
        BalootMoveKind.hokom => 'hokomSuitNotAllowed',
        BalootMoveKind.ashkal => 'ashkalNotAllowed',
        BalootMoveKind.kawesh => 'kaweshNotAllowed',
        _ => 'wrongPhase',
      };
    }
    if (s.phase == BalootPhase.doubling && m.kind == BalootMoveKind.raise) return 'lockNotAllowed';
    return 'wrongPhase';
  }

  @override
  BalootMove moveFromJson(Map<String, Object?> json) => BalootMove.fromJson(json);

  @override
  void apply(BalootState s, BalootMove m, [List<CardEvent>? ev]) {
    final seat = s.turn;
    switch (s.phase) {
      case BalootPhase.bidding:
        _bid(s, seat, m, ev);
      case BalootPhase.doubling:
        _double(s, seat, m, ev);
      case BalootPhase.playing:
        switch (m.kind) {
          case BalootMoveKind.declareProjects:
            s.projectsDecided[seat] = true;
            final mine = detectProjects(s.hands[seat], seat, s.mode!);
            s.projects.addAll(mine);
            ev?.add(CardEvent(CardEventType.projectsDeclared, seat: seat, cards: [for (final p in mine) ...p.cards]));
          case BalootMoveKind.skipProjects:
            s.projectsDecided[seat] = true;
            ev?.add(CardEvent(CardEventType.pass, seat: seat, detail: 'noProjects'));
          default:
            _play(s, seat, m.card!, ev);
        }
      case BalootPhase.over:
        throw StateError('Match over');
    }
  }

  // ------------------------------------------------------------- bidding

  List<int> _speakers(BalootState s, int from, int to) => [for (var i = from; i < to; i++) (s.firstPlayer + i) % 4];

  void _bid(BalootState s, int seat, BalootMove m, List<CardEvent>? ev) {
    switch (m.kind) {
      case BalootMoveKind.pass:
        ev?.add(CardEvent(CardEventType.pass, seat: seat));
        s.bidQueue.removeAt(0);
        return _advanceBidding(s, ev);
      case BalootMoveKind.kawesh:
        ev?.add(CardEvent(CardEventType.redeal, seat: seat, detail: 'kawesh'));
        return _redeal(s, ev);
      case BalootMoveKind.confirm:
        ev?.add(CardEvent(CardEventType.bid, seat: seat, suit: s.trump, detail: 'confirm'));
        return _endBidding(s, ev);
      case BalootMoveKind.hokom:
        s.mode = BalootMode.hokom;
        s.trump = m.suit;
        s.bidder = seat;
        s.buyer = seat;
        s.ashkal = false;
        ev?.add(CardEvent(CardEventType.bid, seat: seat, suit: m.suit, detail: BalootMode.hokom.name));
        s.bidQueue.removeAt(0);
        if (s.bidRound == 3) return _endBidding(s, ev);
        return _advanceBidding(s, ev);
      case BalootMoveKind.sun:
      case BalootMoveKind.ashkal:
        final isAshkal = m.kind == BalootMoveKind.ashkal;
        final switching = s.bidStage == BalootBidStage.confirm;
        s.mode = BalootMode.sun;
        s.trump = null;
        s.bidder = seat;
        s.ashkal = isAshkal;
        s.buyer = isAshkal ? (seat + 2) % 4 : seat;
        ev?.add(CardEvent(CardEventType.bid, seat: seat, detail: switching ? 'switchToSun' : m.kind.name));
        if (s.bidStage == BalootBidStage.open && s.bidRound == 1 && s.options.sunPriority) {
          final earlier = _speakers(s, 0, s.speakerIndex(seat));
          if (earlier.isNotEmpty) {
            s.bidStage = BalootBidStage.priority;
            s.bidQueue = earlier;
            s.turn = earlier.first;
            return;
          }
        }
        return _endBidding(s, ev);
      default:
        throw StateError('Not a bid: $m');
    }
  }

  void _advanceBidding(BalootState s, List<CardEvent>? ev) {
    if (s.bidQueue.isNotEmpty) {
      s.turn = s.bidQueue.first;
      return;
    }
    if (s.bidStage == BalootBidStage.priority) {
      // Nobody took it over.
      if (s.mode == BalootMode.sun) return _endBidding(s, ev);
      return _confirmOrEnd(s, ev);
    }
    // End of the pass-through.
    if (s.mode == BalootMode.hokom) {
      if (s.bidRound == 1) {
        // Earlier speakers (even those who passed) may still say Sun.
        final earlier = _speakers(s, 0, s.speakerIndex(s.bidder));
        if (earlier.isNotEmpty) {
          s.bidStage = BalootBidStage.priority;
          s.bidQueue = earlier;
          s.turn = earlier.first;
          return;
        }
      }
      return _confirmOrEnd(s, ev);
    }
    if (s.bidRound == 1 || (s.bidRound == 2 && s.options.aceThirdRound && s.upCard!.rank == Rank.ace)) {
      s.bidRound++;
      s.bidQueue = s.bidRound == 3 ? [s.firstPlayer] : _speakers(s, 0, 4);
      s.turn = s.bidQueue.first;
      return;
    }
    ev?.add(const CardEvent(CardEventType.redeal));
    _redeal(s, ev);
  }

  void _confirmOrEnd(BalootState s, List<CardEvent>? ev) {
    if (!s.options.takerMaySwitchToSun) return _endBidding(s, ev);
    s.bidStage = BalootBidStage.confirm;
    s.bidQueue = [s.bidder];
    s.turn = s.bidder;
  }

  void _redeal(BalootState s, List<CardEvent>? ev) {
    s.dealer = (s.dealer + 1) % 4;
    s.dealFromRng();
    ev?.add(CardEvent(CardEventType.dealt, seat: s.dealer));
  }

  void _endBidding(BalootState s, List<CardEvent>? ev) {
    s.bidQueue = [];
    ev?.add(
      CardEvent(
        CardEventType.contractChosen,
        seat: s.buyer,
        suit: s.trump,
        detail: s.ashkal ? 'ashkal' : s.mode!.name,
      ),
    );
    s.hands[s.buyer].add(s.upCard!);
    s.upCard = null;
    for (var i = 0; i < 4; i++) {
      final seat = (s.firstPlayer + i) % 4;
      final n = seat == s.buyer ? 2 : 3;
      for (var k = 0; k < n; k++) {
        s.hands[seat].add(s.stock.removeLast());
      }
      s.hands[seat].sort();
    }
    ev?.add(CardEvent(CardEventType.dealt, seat: s.dealer));
    if (doublingAllowed(s)) {
      s.phase = BalootPhase.doubling;
      s.doublingQueue = [(s.buyer + 1) % 4, (s.buyer + 3) % 4];
      s.turn = s.doublingQueue.first;
    } else {
      _startPlay(s, ev);
    }
  }

  void _double(BalootState s, int seat, BalootMove m, List<CardEvent>? ev) {
    if (m.kind == BalootMoveKind.pass) {
      ev?.add(CardEvent(CardEventType.pass, seat: seat));
      if (s.level == 1) {
        s.doublingQueue.removeAt(0);
        if (s.doublingQueue.isNotEmpty) {
          s.turn = s.doublingQueue.first;
          return;
        }
      }
      return _startPlay(s, ev);
    }
    final hokom = s.mode == BalootMode.hokom;
    if (s.level == 1) {
      s.level = 2;
      s.doubler = seat;
      s.locked = hokom && m.locked;
      s.doublingQueue = [];
      ev?.add(CardEvent(CardEventType.doubled, seat: seat, value: 2, detail: s.locked ? 'locked' : 'open'));
      if (!hokom) return _startPlay(s, ev);
      s.turn = s.buyer;
    } else if (s.level == 2) {
      s.level = 3;
      s.locked = false;
      ev?.add(CardEvent(CardEventType.doubled, seat: seat, value: 3, detail: 'open'));
      s.turn = s.doubler;
    } else if (s.level == 3) {
      s.level = 4;
      s.locked = m.locked;
      ev?.add(CardEvent(CardEventType.doubled, seat: seat, value: 4, detail: s.locked ? 'locked' : 'open'));
      s.turn = s.buyer;
    } else {
      s.gahwa = true;
      s.locked = false;
      ev?.add(CardEvent(CardEventType.doubled, seat: seat, value: 5, detail: 'gahwa'));
      _startPlay(s, ev);
    }
  }

  // ----------------------------------------------------------------- play

  void _startPlay(BalootState s, List<CardEvent>? ev) {
    s.phase = BalootPhase.playing;
    s.belote = beloteHolder(s);
    if (s.options.declareProjects == BalootDeclareProjects.auto) {
      s.projects = [for (var seat = 0; seat < 4; seat++) ...detectProjects(s.hands[seat], seat, s.mode!)];
      s.projectsDecided = List.filled(4, true);
      for (var seat = 0; seat < 4; seat++) {
        final mine = s.projects.where((p) => p.seat == seat).toList();
        if (mine.isNotEmpty) {
          ev?.add(CardEvent(CardEventType.projectsDeclared, seat: seat, cards: [for (final p in mine) ...p.cards]));
        }
      }
    } else {
      s.projects = [];
      s.projectsDecided = List.filled(4, false);
    }
    final leader = s.options.firstLead == BalootFirstLead.taker ? s.buyer : s.firstPlayer;
    s.trick = Trick(leader);
    s.turn = leader;
  }

  void _play(BalootState s, int seat, PlayingCard card, List<CardEvent>? ev) {
    final ekka = s.trick!.isEmpty && isEkka(s, card);
    s.hands[seat].remove(card);
    final trick = s.trick!..add(seat, card);
    ev?.add(CardEvent(CardEventType.cardPlayed, seat: seat, cards: [card], detail: ekka ? 'ekka' : null));
    if (seat == s.belote && card.suit == s.trump && (card.rank == Rank.king || card.rank == Rank.queen)) {
      final other = PlayingCard(s.trump!, card.rank == Rank.king ? Rank.queen : Rank.king);
      if (!s.hands[seat].contains(other)) ev?.add(CardEvent(CardEventType.belote, seat: seat, value: 2));
    }
    if (trick.length < 4) {
      s.turn = (seat + 1) % 4;
      return;
    }
    final winner = trick.winner((c, led) => power(c, led, s.mode, s.trump));
    s.tricks.add(trick);
    s.trick = null;
    ev?.add(CardEvent(CardEventType.trickWon, seat: winner, cards: List.of(trick.cards)));
    if (s.tricks.length == 8) return _scoreDeal(s, ev);
    s.trick = Trick(winner);
    s.turn = winner;
  }

  // -------------------------------------------------------------- scoring

  /// Card points per team (last trick included) of the completed tricks.
  static List<int> rawPoints(BalootState s) {
    final raw = [0, 0];
    for (var i = 0; i < s.tricks.length; i++) {
      final t = s.tricks[i];
      final w = t.winner((c, led) => power(c, led, s.mode, s.trump)) % 2;
      raw[w] += t.cards.fold<int>(0, (a, c) => a + cardPoints(c, s.mode, s.trump));
      if (i == 7) raw[w] += 10;
    }
    return raw;
  }

  /// Scores a deal from its figures (RULES.md, Baloot scoring):
  /// 1. a kaboot scores 25 / 44 × level plus the kaboot team's own counted
  ///    projects (× min(level, cap)) and belote; the other team scores
  ///    nothing;
  /// 2. otherwise one team counts: the defenders, or in a doubled deal the
  ///    opponents of the last raiser (Double / Four → the taker's team,
  ///    Triple / Gahwa → the defenders); its card points become game points
  ///    ([gamePoints]) and the other team gets the rest of 16 / 26;
  /// 3. totals = game points + projects + belote; the higher wins; a tie
  ///    goes to the team that lost more card points to rounding, then to the
  ///    taker's team;
  /// 4. no double and the taker's team won → each team scores its total;
  ///    otherwise the winner scores 16 / 26 × level + all projects ×
  ///    min(level, cap) + the belote as [beloteOnLoss] says; the loser
  ///    nothing (or its own belote with `keptByHolder`).
  ///
  /// [raw] is the card points per team (162 / 130 in all), [projects] the
  /// counted projects per team (one team at most), [belote] the counted
  /// belote per team, [level] 1–4; with [gahwa] the figures are those of
  /// level 1.
  static BalootDealScore scoreFigures({
    required BalootMode mode,
    required int takerTeam,
    required List<int> raw,
    List<int> projects = const [0, 0],
    List<int> belote = const [0, 0],
    int level = 1,
    bool gahwa = false,
    int? kabootTeam,
    BalootBeloteOnLoss beloteOnLoss = BalootBeloteOnLoss.toWinner,
    int? projectMultiplierCap = 2,
  }) {
    final tt = takerTeam;
    final base = basePoints(mode);
    final m = gahwa ? 1 : level;
    final cap = projectMultiplierCap;
    final pm = cap == null || m < cap ? m : cap;
    if (kabootTeam != null) {
      final pts = [0, 0];
      pts[kabootTeam] = kabootPoints(mode) * m + projects[kabootTeam] * pm + belote[kabootTeam];
      final g = [0, 0]..[kabootTeam] = kabootPoints(mode);
      return BalootDealScore(pts, kabootTeam, null, g);
    }
    final raiser = gahwa || level == 3 ? tt : (level == 2 || level == 4 ? 1 - tt : null);
    final counting = raiser == null ? 1 - tt : 1 - raiser;
    final other = 1 - counting;
    final g = [0, 0];
    g[counting] = gamePoints(mode, raw[counting]);
    g[other] = base - g[counting];
    final tot = [for (var t = 0; t < 2; t++) g[t] + projects[t] + belote[t]];
    final int winner;
    if (tot[0] != tot[1]) {
      winner = tot[0] > tot[1] ? 0 : 1;
    } else {
      final lossCounting = raw[counting] - g[counting] * unit(mode);
      final lossOther = raw[other] - g[other] * unit(mode);
      winner = lossCounting > lossOther ? counting : (lossOther > lossCounting ? other : tt);
    }
    if (level == 1 && !gahwa && winner == tt) return BalootDealScore(tot, winner, counting, g);
    final loser = 1 - winner;
    final pts = [0, 0];
    pts[winner] = base * m + (projects[0] + projects[1]) * pm;
    switch (beloteOnLoss) {
      case BalootBeloteOnLoss.toWinner:
        pts[winner] += belote[0] + belote[1];
      case BalootBeloteOnLoss.keptByHolder:
        pts[winner] += belote[winner];
        pts[loser] += belote[loser];
      case BalootBeloteOnLoss.voided:
        pts[winner] += belote[winner];
    }
    return BalootDealScore(pts, winner, counting, g);
  }

  /// Scores the finished deal of [s] ([scoreFigures] on its tricks,
  /// projects, belote and doubling).
  static BalootRoundResult dealResult(BalootState s) {
    final mode = s.mode!;
    final o = s.options;
    final raw = rawPoints(s);
    final tricksWon = [0, 0];
    for (final t in s.tricks) {
      tricksWon[t.winner((c, led) => power(c, led, s.mode, s.trump)) % 2]++;
    }
    final proj = [0, 0];
    final pt = projectTeam(s.projects, s.firstPlayer, mode, trump: s.trump, options: o);
    if (pt != null) {
      for (final p in s.projects.where((p) => p.seat % 2 == pt)) {
        proj[pt] += p.value(mode);
      }
    }
    final bel = [0, 0];
    if (beloteCounts(s)) bel[s.belote % 2] = 2;
    final kabootTeam = tricksWon[0] == 8 ? 0 : (tricksWon[1] == 8 ? 1 : null);
    final r = scoreFigures(
      mode: mode,
      takerTeam: s.buyer % 2,
      raw: raw,
      projects: proj,
      belote: bel,
      level: s.level,
      gahwa: s.gahwa,
      kabootTeam: kabootTeam,
      beloteOnLoss: o.beloteOnLoss,
      projectMultiplierCap: o.projectMultiplierCap,
    );
    return BalootRoundResult(
      buyer: s.buyer,
      bidder: s.bidder,
      ashkal: s.ashkal,
      mode: mode,
      trump: s.trump,
      raw: raw,
      points: r.points,
      level: s.gahwa ? 5 : s.level,
      locked: s.locked,
      made: r.winner == s.buyer % 2,
      countingTeam: r.countingTeam,
      gamePoints: r.gamePoints,
      projectPoints: proj,
      belotePoints: bel,
      kabootTeam: kabootTeam,
      winner: r.winner,
    );
  }

  void _scoreDeal(BalootState s, List<CardEvent>? ev) {
    final r = dealResult(s);
    s.results.add(r);
    for (var t = 0; t < 2; t++) {
      s.teamScores[t] += r.points[t];
    }
    ev?.add(CardEvent(CardEventType.roundScored, seat: s.buyer, value: r.points[s.buyer % 2]));
    if (s.gahwa) {
      s.winnerTeam = r.winner;
    } else if (s.teamScores[0] >= s.options.targetScore || s.teamScores[1] >= s.options.targetScore) {
      final a = s.teamScores[0];
      final b = s.teamScores[1];
      // An exact tie at or above the target: another deal is played.
      if (a != b) s.winnerTeam = a > b ? 0 : 1;
    }
    if (s.winnerTeam != null) {
      s.phase = BalootPhase.over;
      ev?.add(CardEvent(CardEventType.matchOver, seat: s.winnerTeam));
      return;
    }
    s.dealer = (s.dealer + 1) % 4;
    s.dealFromRng();
    ev?.add(CardEvent(CardEventType.dealt, seat: s.dealer));
  }
}

class BalootEngine extends RulesEngine<BalootState, BalootMove> {
  BalootEngine(BalootState state) : super(const BalootRules(), state);

  factory BalootEngine.newMatch({BalootOptions options = const BalootOptions(), required int seed}) =>
      BalootEngine(BalootState.newMatch(options: options, seed: seed));

  factory BalootEngine.fromJson(Map<String, Object?> json) => BalootEngine(BalootState.fromJson(json));
}
