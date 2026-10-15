/// Shared trick-taking helpers (Tarneeb, Trix, Baloot).
library;

import 'playing_card.dart';

/// A trick in progress or completed. `seats[i]` played `cards[i]`.
class Trick {
  Trick(this.leader, {List<int>? seats, List<PlayingCard>? cards})
    : seats = seats ?? <int>[],
      cards = cards ?? <PlayingCard>[];

  factory Trick.fromJson(Map<String, Object?> json) => Trick(
    json['leader']! as int,
    seats: (json['seats']! as List).cast<int>().toList(),
    cards: cardsFromJson(json['cards']),
  );

  final int leader;
  final List<int> seats;
  final List<PlayingCard> cards;

  bool get isEmpty => cards.isEmpty;
  int get length => cards.length;
  Suit? get ledSuit => cards.isEmpty ? null : cards.first.suit;

  void add(int seat, PlayingCard card) {
    seats.add(seat);
    cards.add(card);
  }

  /// Index (into [cards]) of the strongest card by [power]; ties keep the
  /// earliest play.
  int winningIndex(int Function(PlayingCard card, Suit led) power) {
    final led = cards.first.suit;
    var best = 0;
    var bestPower = power(cards[0], led);
    for (var i = 1; i < cards.length; i++) {
      final p = power(cards[i], led);
      if (p > bestPower) {
        best = i;
        bestPower = p;
      }
    }
    return best;
  }

  int winner(int Function(PlayingCard card, Suit led) power) => seats[winningIndex(power)];

  PlayingCard? cardOf(int seat) {
    final i = seats.indexOf(seat);
    return i < 0 ? null : cards[i];
  }

  Trick copy() => Trick(leader, seats: List.of(seats), cards: List.of(cards));

  Map<String, Object?> toJson() => {'leader': leader, 'seats': seats, 'cards': cardsToJson(cards)};
}

/// Power of a card in a plain trump game with ace high: trumps beat the led
/// suit, other suits never win.
int standardPower(PlayingCard card, Suit led, Suit? trump) {
  if (trump != null && card.suit == trump) return 100 + card.rank.value;
  if (card.suit == led) return card.rank.value;
  return -1;
}

/// Cards of [hand] in [suit].
Iterable<PlayingCard> ofSuit(Iterable<PlayingCard> hand, Suit suit) => hand.where((c) => !c.isJoker && c.suit == suit);

/// Suits each seat has shown void in during [tricks] (failed to follow).
List<Set<Suit>> voidsFromTricks(Iterable<Trick> tricks, int seats) {
  final voids = [for (var i = 0; i < seats; i++) <Suit>{}];
  for (final t in tricks) {
    if (t.cards.isEmpty) continue;
    final led = t.cards.first.suit;
    for (var i = 1; i < t.cards.length; i++) {
      if (t.cards[i].suit != led) voids[t.seats[i]].add(led);
    }
  }
  return voids;
}
