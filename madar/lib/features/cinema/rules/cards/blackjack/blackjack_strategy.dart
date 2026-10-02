/// Blackjack basic strategy (the chart behind the advisor and the AI seats).
///
/// The chart is the standard one for 4–8 packs, dealer stands on soft 17,
/// double after split, dealer peek (§5.8 of the Madar spec), with the
/// published changes for H17, no double after split and the European table.
/// It reads only the hand being played, the dealer's up card and the table
/// options: never the hole card and never the shoe (B-76).
library;

import '../core/playing_card.dart';
import 'blackjack_state.dart';

/// One cell of the chart. The short codes are the usual ones: H, S, D, Ds,
/// P, Rh, Rs, Rp.
enum BlackjackChartCode {
  /// H: hit.
  hit,

  /// S: stand.
  stand,

  /// D: double, or hit when doubling is not allowed.
  doubleOrHit,

  /// Ds: double, or stand when doubling is not allowed.
  doubleOrStand,

  /// P: split.
  split,

  /// Rh: surrender, or hit when surrender is not allowed.
  surrenderOrHit,

  /// Rs: surrender, or stand when surrender is not allowed.
  surrenderOrStand,

  /// Rp: surrender, or split when surrender is not allowed.
  surrenderOrSplit,
}

/// The advisor's answer for the hand being played.
class BlackjackAdvice {
  const BlackjackAdvice(this.action, this.code, {this.approximate = false});

  /// The recommended legal action.
  final BlackjackAction action;

  /// The chart cell it came from.
  final BlackjackChartCode code;

  /// True with 1–2 packs: the multi-pack chart is used as it is.
  final bool approximate;

  @override
  String toString() => 'BlackjackAdvice(${action.name}, ${code.name}${approximate ? ', approximate' : ''})';
}

abstract final class BlackjackStrategy {
  /// The dealer's up card as the chart reads it: 2–10, ace = 11.
  static int upValue(PlayingCard up) {
    final v = blackjackCardValue(up);
    return v == 1 ? 11 : v;
  }

  /// European table where a dealer natural takes every hand's full value.
  static bool _allLost(BlackjackOptions o) => o.european && !o.originalOnly;

  /// Hard totals (B9 hard table, H17 and European changes).
  static BlackjackChartCode hardCode(int total, int up, BlackjackOptions o) {
    final h17 = o.dealerHitsSoft17;
    if (total <= 8) return BlackjackChartCode.hit;
    switch (total) {
      case 9:
        return up >= 3 && up <= 6 ? BlackjackChartCode.doubleOrHit : BlackjackChartCode.hit;
      case 10:
        return up <= 9 ? BlackjackChartCode.doubleOrHit : BlackjackChartCode.hit;
      case 11:
        if (_allLost(o) && up >= 10) return BlackjackChartCode.hit;
        if (up == 11 && !h17) return BlackjackChartCode.hit;
        return BlackjackChartCode.doubleOrHit;
      case 12:
        return up >= 4 && up <= 6 ? BlackjackChartCode.stand : BlackjackChartCode.hit;
      case 13:
      case 14:
        return up <= 6 ? BlackjackChartCode.stand : BlackjackChartCode.hit;
      case 15:
        if (up <= 6) return BlackjackChartCode.stand;
        if (up == 10 || (up == 11 && h17)) return BlackjackChartCode.surrenderOrHit;
        return BlackjackChartCode.hit;
      case 16:
        if (up <= 6) return BlackjackChartCode.stand;
        return up >= 9 ? BlackjackChartCode.surrenderOrHit : BlackjackChartCode.hit;
      case 17:
        return up == 11 && h17 ? BlackjackChartCode.surrenderOrStand : BlackjackChartCode.stand;
      default:
        return BlackjackChartCode.stand;
    }
  }

  /// Soft totals 12–21 (B9 soft table; soft 12 is a pair of aces that may
  /// not split).
  static BlackjackChartCode softCode(int total, int up, BlackjackOptions o) {
    final h17 = o.dealerHitsSoft17;
    switch (total) {
      case 12:
        return BlackjackChartCode.hit;
      case 13:
      case 14:
        return up == 5 || up == 6 ? BlackjackChartCode.doubleOrHit : BlackjackChartCode.hit;
      case 15:
      case 16:
        return up >= 4 && up <= 6 ? BlackjackChartCode.doubleOrHit : BlackjackChartCode.hit;
      case 17:
        return up >= 3 && up <= 6 ? BlackjackChartCode.doubleOrHit : BlackjackChartCode.hit;
      case 18:
        if (up == 2) return h17 ? BlackjackChartCode.doubleOrStand : BlackjackChartCode.stand;
        if (up <= 6) return BlackjackChartCode.doubleOrStand;
        if (up <= 8) return BlackjackChartCode.stand;
        return BlackjackChartCode.hit;
      case 19:
        return up == 6 && h17 ? BlackjackChartCode.doubleOrStand : BlackjackChartCode.stand;
      default:
        return BlackjackChartCode.stand;
    }
  }

  /// Pairs (value 1 = aces, 2–10): the split cell, or null when the chart
  /// plays the pair as a total instead.
  static BlackjackChartCode? pairCode(int value, int up, BlackjackOptions o) {
    final das = o.doubleAfterSplit;
    switch (value) {
      case 1:
        return _allLost(o) && up == 11 ? null : BlackjackChartCode.split;
      case 10:
      case 5:
        return null;
      case 9:
        return up == 7 || up >= 10 ? null : BlackjackChartCode.split;
      case 8:
        // The European change comes first: with no peek, splitting 8-8
        // against a 10 or an ace only doubles what a dealer natural takes.
        if (_allLost(o) && up >= 10) return null;
        if (up == 11 && o.dealerHitsSoft17) return BlackjackChartCode.surrenderOrSplit;
        return BlackjackChartCode.split;
      case 7:
        return up <= 7 ? BlackjackChartCode.split : null;
      case 6:
        return (das ? up <= 6 : up >= 3 && up <= 6) ? BlackjackChartCode.split : null;
      case 4:
        return das && (up == 5 || up == 6) ? BlackjackChartCode.split : null;
      default: // 2, 3
        return (das ? up <= 7 : up >= 4 && up <= 7) ? BlackjackChartCode.split : null;
    }
  }

  /// The chart cell for [hand] against [up] (the pair cell only when the
  /// hand may split now).
  static BlackjackChartCode chartCode(BlackjackHand hand, PlayingCard up, BlackjackOptions o, {required bool canSplit}) {
    final u = upValue(up);
    final t = blackjackTotal(hand.cards);
    if (canSplit && hand.cards.length == 2) {
      final pair = pairCode(blackjackCardValue(hand.cards.first), u, o);
      if (pair != null) return pair;
    }
    return t.soft ? softCode(t.total, u, o) : hardCode(t.total, u, o);
  }

  /// Turns a chart cell into a legal action (§5.8: D → H, Ds → S, Rh → H
  /// when the first choice is not allowed).
  static BlackjackAction resolve(
    BlackjackChartCode code, {
    required bool canHit,
    required bool canDouble,
    required bool canSplit,
    required bool canSurrender,
    required BlackjackChartCode Function() totalCode,
  }) {
    BlackjackAction hitOrStand(BlackjackAction a) =>
        a == BlackjackAction.hit && !canHit ? BlackjackAction.stand : a;
    switch (code) {
      case BlackjackChartCode.hit:
        return hitOrStand(BlackjackAction.hit);
      case BlackjackChartCode.stand:
        return BlackjackAction.stand;
      case BlackjackChartCode.doubleOrHit:
        return canDouble ? BlackjackAction.double : hitOrStand(BlackjackAction.hit);
      case BlackjackChartCode.doubleOrStand:
        return canDouble ? BlackjackAction.double : BlackjackAction.stand;
      case BlackjackChartCode.surrenderOrHit:
        return canSurrender ? BlackjackAction.surrender : hitOrStand(BlackjackAction.hit);
      case BlackjackChartCode.surrenderOrStand:
        return canSurrender ? BlackjackAction.surrender : BlackjackAction.stand;
      case BlackjackChartCode.surrenderOrSplit:
        if (canSurrender) return BlackjackAction.surrender;
        if (canSplit) return BlackjackAction.split;
        return resolve(
          totalCode(),
          canHit: canHit,
          canDouble: canDouble,
          canSplit: false,
          canSurrender: false,
          totalCode: totalCode,
        );
      case BlackjackChartCode.split:
        if (canSplit) return BlackjackAction.split;
        return resolve(
          totalCode(),
          canHit: canHit,
          canDouble: canDouble,
          canSplit: false,
          canSurrender: canSurrender,
          totalCode: totalCode,
        );
    }
  }

  /// The advice for the hand being played, or null when no hand is.
  static BlackjackAdvice? advise(BlackjackState s) {
    final hand = s.activeHand;
    final up = s.upCard;
    if (hand == null || up == null || hand.done) return null;
    final o = s.options;
    final canSplit = s.canSplit;
    final code = chartCode(hand, up, o, canSplit: canSplit);
    BlackjackChartCode totalCode() {
      final t = blackjackTotal(hand.cards);
      final u = upValue(up);
      return t.soft ? softCode(t.total, u, o) : hardCode(t.total, u, o);
    }

    final action = resolve(
      code,
      canHit: s.canHit,
      canDouble: s.canDouble,
      canSplit: canSplit,
      canSurrender: s.canSurrender,
      totalCode: totalCode,
    );
    return BlackjackAdvice(action, code, approximate: o.decks < 4);
  }

  /// How the easy seat plays (B-70): like the dealer, hit to 16 and on a
  /// soft 17 only when the table's dealer does; never double, split or
  /// surrender.
  static BlackjackAction dealerLike(BlackjackState s) {
    final hand = s.activeHand;
    if (hand == null) return BlackjackAction.stand;
    final t = blackjackTotal(hand.cards);
    final wantsCard = t.total <= 16 || (t.total == 17 && t.soft && s.options.dealerHitsSoft17);
    return wantsCard && s.canHit ? BlackjackAction.hit : BlackjackAction.stand;
  }
}
