/// Baloot (بلوت) rules: two-round auction (Hokom / Sun), doubling ladder,
/// projects (sira / 50 / 100 / 400), belote, trick play and scoring to 152.
/// See RULES.md for every choice made.
library;

import '../core/card_game.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';
import 'baloot_state.dart';

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

  /// Game points of the buyers from their card points: Sun divides by 5,
  /// Hokom by 10 with a half rounding down; the defenders get the rest.
  static int buyerAbnat(BalootMode mode, int raw) => mode == BalootMode.sun ? (raw * 2 + 5) ~/ 10 : (raw + 4) ~/ 10;

  static bool doublingAllowed(BalootState s) {
    if (!s.options.doubling) return false;
    if (s.mode == BalootMode.hokom) return true;
    if (!s.options.sunDoubleOnlyWhenBehind) return true;
    final bt = s.buyer % 2;
    return s.teamScores[bt] > 100 && s.teamScores[1 - bt] < 100;
  }

  // ------------------------------------------------------------- projects

  /// The best set of non-overlapping projects in [hand].
  static List<BalootProject> detectProjects(List<PlayingCard> hand, int seat, BalootMode mode) {
    final candidates = <BalootProject>[];
    for (final r in [Rank.ace, Rank.ten, Rank.king, Rank.queen, Rank.jack]) {
      final four = [for (final s in Suit.values) PlayingCard(s, r)];
      if (four.every(hand.contains)) {
        final type = r == Rank.ace && mode == BalootMode.sun ? BalootProjectType.fourHundred : BalootProjectType.hundred;
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
          candidates.add(
            BalootProject(type, seat, [for (var k = 0; k < len; k++) ranksByIndex[start + k]!]),
          );
        }
      }
    }
    var best = <BalootProject>[];
    var bestValue = 0;
    void dfs(int i, Set<PlayingCard> used, List<BalootProject> chosen, int value) {
      if (value > bestValue) {
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

  /// Team whose projects count (the single best project wins: value, then
  /// top card, then the seat nearer the first player), or null.
  static int? projectTeam(List<BalootProject> projects, int firstPlayer, BalootMode mode) {
    if (projects.isEmpty) return null;
    BalootProject? best;
    for (final p in projects) {
      if (best == null) {
        best = p;
        continue;
      }
      final dv = p.value(mode) - best.value(mode);
      final dt = p.topIndex - best.topIndex;
      final dist = (p.seat - firstPlayer + 4) % 4 - (best.seat - firstPlayer + 4) % 4;
      if (dv > 0 || (dv == 0 && (dt > 0 || (dt == 0 && dist < 0)))) best = p;
    }
    return best!.seat % 2;
  }

  // ---------------------------------------------------------------- legal

  static List<PlayingCard> playable(BalootState s, int seat) {
    final hand = s.hands[seat];
    final trick = s.trick!;
    final led = trick.ledSuit;
    if (led == null) return List.of(hand);
    final follow = hand.where((c) => c.suit == led).toList();
    if (s.mode == BalootMode.sun) return follow.isNotEmpty ? follow : List.of(hand);
    final trump = s.trump!;
    var bestTrump = -1;
    for (final c in trick.cards) {
      if (c.suit == trump && trumpRank(c.rank) > bestTrump) bestTrump = trumpRank(c.rank);
    }
    if (led == trump) {
      if (follow.isEmpty) return List.of(hand);
      if (s.options.mustOvertrump) {
        final higher = follow.where((c) => trumpRank(c.rank) > bestTrump).toList();
        if (higher.isNotEmpty) return higher;
      }
      return follow;
    }
    if (follow.isNotEmpty) return follow;
    final trumps = hand.where((c) => c.suit == trump).toList();
    if (trumps.isEmpty) return List.of(hand);
    final winIdx = trick.winningIndex((c, l) => power(c, l, s.mode, s.trump));
    final partnerWinning = trick.seats[winIdx] % 2 == seat % 2;
    if (partnerWinning && !s.options.mustTrumpWhenPartnerWinning) return List.of(hand);
    if (bestTrump >= 0 && s.options.mustOvertrump) {
      final higher = trumps.where((c) => trumpRank(c.rank) > bestTrump).toList();
      // Unable to over-trump: free to play anything.
      return higher.isNotEmpty ? higher : List.of(hand);
    }
    return trumps;
  }

  @override
  List<BalootMove> legalMoves(BalootState s, int seat) {
    if (s.isOver || s.turn != seat) return const [];
    switch (s.phase) {
      case BalootPhase.bidding:
        if (s.mode == BalootMode.hokom) return const [BalootMove.pass(), BalootMove.sun()];
        final up = s.upCard!.suit;
        return [
          const BalootMove.pass(),
          if (s.bidRound == 1)
            BalootMove.hokom(up)
          else
            for (final suit in Suit.values)
              if (suit != up) BalootMove.hokom(suit),
          const BalootMove.sun(),
        ];
      case BalootPhase.doubling:
        return const [BalootMove.pass(), BalootMove.raise()];
      case BalootPhase.playing:
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
      if (!s.hands[seat].contains(m.card)) return 'cardNotInHand';
      final led = s.trick!.ledSuit;
      if (led != null && s.hands[seat].any((c) => c.suit == led) && m.card!.suit != led) return 'mustFollowSuit';
      return m.card!.suit == s.trump ? 'mustOvertrump' : 'mustTrump';
    }
    if (m.kind == BalootMoveKind.hokom && s.phase == BalootPhase.bidding) return 'hokomSuitNotAllowed';
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
        _play(s, seat, m.card!, ev);
      case BalootPhase.over:
        throw StateError('Match over');
    }
  }

  void _bid(BalootState s, int seat, BalootMove m, List<CardEvent>? ev) {
    switch (m.kind) {
      case BalootMoveKind.pass:
        s.bidQueue.removeAt(0);
        ev?.add(CardEvent(CardEventType.pass, seat: seat));
      case BalootMoveKind.hokom:
        s.mode = BalootMode.hokom;
        s.trump = m.suit;
        s.buyer = seat;
        s.bidQueue = [for (var i = 1; i < 4; i++) (seat + i) % 4];
        ev?.add(CardEvent(CardEventType.bid, seat: seat, suit: m.suit, detail: BalootMode.hokom.name));
      case BalootMoveKind.sun:
        s.mode = BalootMode.sun;
        s.trump = null;
        s.buyer = seat;
        s.bidQueue = [];
        ev?.add(CardEvent(CardEventType.bid, seat: seat, detail: BalootMode.sun.name));
        return _endBidding(s, ev);
      default:
        throw StateError('Not a bid: $m');
    }
    if (s.bidQueue.isNotEmpty) {
      s.turn = s.bidQueue.first;
    } else if (s.mode == BalootMode.hokom) {
      _endBidding(s, ev);
    } else if (s.bidRound == 1) {
      s.bidRound = 2;
      s.bidQueue = [for (var i = 0; i < 4; i++) (s.firstPlayer + i) % 4];
      s.turn = s.bidQueue.first;
    } else {
      ev?.add(const CardEvent(CardEventType.redeal));
      s.dealer = (s.dealer + 1) % 4;
      s.dealFromRng();
      ev?.add(CardEvent(CardEventType.dealt, seat: s.dealer));
    }
  }

  void _endBidding(BalootState s, List<CardEvent>? ev) {
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
    // Raise.
    if (s.level == 1) {
      s.level = 2;
      s.doubler = seat;
      s.doublingQueue = [];
      ev?.add(CardEvent(CardEventType.doubled, seat: seat, value: 2));
      if (s.mode == BalootMode.sun) return _startPlay(s, ev);
      s.turn = s.buyer;
    } else if (s.level < 4) {
      s.level++;
      ev?.add(CardEvent(CardEventType.doubled, seat: seat, value: s.level));
      s.turn = seat == s.buyer ? s.doubler : s.buyer;
    } else {
      s.gahwa = true;
      ev?.add(CardEvent(CardEventType.doubled, seat: seat, value: 5, detail: 'gahwa'));
      _startPlay(s, ev);
    }
  }

  void _startPlay(BalootState s, List<CardEvent>? ev) {
    s.phase = BalootPhase.playing;
    s.projects = [for (var seat = 0; seat < 4; seat++) ...detectProjects(s.hands[seat], seat, s.mode!)];
    s.belote = -1;
    if (s.mode == BalootMode.hokom) {
      final k = PlayingCard(s.trump!, Rank.king);
      final q = PlayingCard(s.trump!, Rank.queen);
      for (var seat = 0; seat < 4; seat++) {
        if (s.hands[seat].contains(k) && s.hands[seat].contains(q)) s.belote = seat;
      }
    }
    for (var seat = 0; seat < 4; seat++) {
      final mine = s.projects.where((p) => p.seat == seat).toList();
      if (mine.isNotEmpty) {
        ev?.add(CardEvent(CardEventType.projectsDeclared, seat: seat, cards: [for (final p in mine) ...p.cards]));
      }
    }
    s.trick = Trick(s.firstPlayer);
    s.turn = s.firstPlayer;
  }

  void _play(BalootState s, int seat, PlayingCard card, List<CardEvent>? ev) {
    s.hands[seat].remove(card);
    final trick = s.trick!..add(seat, card);
    ev?.add(CardEvent(CardEventType.cardPlayed, seat: seat, cards: [card]));
    if (seat == s.belote && card.suit == s.trump && (card.rank == Rank.king || card.rank == Rank.queen)) {
      final other = PlayingCard(s.trump!, card.rank == Rank.king ? Rank.queen : Rank.king);
      if (!s.hands[seat].contains(other)) ev?.add(CardEvent(CardEventType.belote, seat: seat));
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

  /// Scores the finished deal: points per team and whether the buyers made.
  static BalootRoundResult dealResult(BalootState s) {
    final mode = s.mode!;
    final bt = s.buyer % 2;
    final dt = 1 - bt;
    final raw = rawPoints(s);
    final tricksWon = [0, 0];
    for (final t in s.tricks) {
      tricksWon[t.winner((c, led) => power(c, led, s.mode, s.trump)) % 2]++;
    }
    final proj = [0, 0];
    final pt = projectTeam(s.projects, s.firstPlayer, mode);
    if (pt != null) {
      for (final p in s.projects.where((p) => p.seat % 2 == pt)) {
        proj[pt] += p.value(mode);
      }
    }
    final bel = [0, 0];
    if (mode == BalootMode.hokom && s.belote >= 0) bel[s.belote % 2] = 2;
    final base = basePoints(mode);
    final pts = [0, 0];
    final kabootTeam = tricksWon[0] == 8 ? 0 : (tricksWon[1] == 8 ? 1 : null);
    final int winner;
    if (kabootTeam != null) {
      winner = kabootTeam;
    } else {
      final ba = buyerAbnat(mode, raw[bt]);
      final buyerTotal = ba + proj[bt] + bel[bt];
      final defTotal = base - ba + proj[dt] + bel[dt];
      final made = buyerTotal > defTotal || (buyerTotal == defTotal && s.options.buyerWinsTies);
      winner = made ? bt : dt;
      if (s.level == 1 && !s.gahwa && made) {
        pts[bt] = buyerTotal;
        pts[dt] = defTotal;
        return _result(s, raw, pts, true);
      }
    }
    final loser = 1 - winner;
    final dealValue = (kabootTeam != null ? kabootPoints(mode) : base) + proj[0] + proj[1];
    final mult = s.gahwa ? 1 : s.level;
    pts[winner] = dealValue * mult + bel[winner];
    pts[loser] = bel[loser];
    return _result(s, raw, pts, winner == bt);
  }

  static BalootRoundResult _result(BalootState s, List<int> raw, List<int> pts, bool made) => BalootRoundResult(
    buyer: s.buyer,
    mode: s.mode!,
    trump: s.trump,
    raw: raw,
    points: pts,
    level: s.gahwa ? 5 : s.level,
    made: made,
  );

  void _scoreDeal(BalootState s, List<CardEvent>? ev) {
    final r = dealResult(s);
    s.results.add(r);
    for (var t = 0; t < 2; t++) {
      s.teamScores[t] += r.points[t];
    }
    ev?.add(CardEvent(CardEventType.roundScored, seat: s.buyer, value: r.points[s.buyer % 2]));
    final bt = s.buyer % 2;
    if (s.gahwa) {
      s.winnerTeam = r.made ? bt : 1 - bt;
    } else if (s.teamScores[0] >= s.options.targetScore || s.teamScores[1] >= s.options.targetScore) {
      final a = s.teamScores[0];
      final b = s.teamScores[1];
      s.winnerTeam = a > b ? 0 : (b > a ? 1 : bt);
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
