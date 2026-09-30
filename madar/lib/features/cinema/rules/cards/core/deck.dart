/// Deck builders.
library;

import 'playing_card.dart';

/// A fresh, unshuffled deck: [copies] full (or [ranks]-restricted) packs plus
/// [jokers] jokers (joker indices cycle 0..3).
List<PlayingCard> buildDeck({int copies = 1, int jokers = 0, Iterable<Rank>? ranks}) {
  final rs = (ranks ?? Rank.values).toList();
  return [
    for (var c = 0; c < copies; c++)
      for (final s in Suit.values)
        for (final r in rs) PlayingCard(s, r),
    for (var j = 0; j < jokers; j++) PlayingCard.joker(j % PlayingCard.jokerCount),
  ];
}

/// The 32-card pack (7..A) used by Baloot.
final List<Rank> balootRanks = [Rank.seven, Rank.eight, Rank.nine, Rank.ten, Rank.jack, Rank.queen, Rank.king, Rank.ace];
