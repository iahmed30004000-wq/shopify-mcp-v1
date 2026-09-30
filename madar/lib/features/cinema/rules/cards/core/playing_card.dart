/// Suits, ranks and cards shared by every Madar Cinema card game.
///
/// A [PlayingCard] is a canonical value (one instance per card code), so two
/// copies of the same card from a double deck compare equal: every game that
/// uses two decks treats duplicates as interchangeable.
library;

/// The four French suits. [code] is the stable single-letter id used in JSON.
enum Suit {
  clubs('C'),
  diamonds('D'),
  hearts('H'),
  spades('S');

  const Suit(this.code);

  final String code;

  static Suit fromCode(String code) =>
      values.firstWhere((s) => s.code == code, orElse: () => throw FormatException('Unknown suit', code));
}

/// The thirteen ranks, two to ace. [value] is 2..14 (ace high); each game
/// applies its own ordering and point values on top of this.
enum Rank {
  two(2, '2'),
  three(3, '3'),
  four(4, '4'),
  five(5, '5'),
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, 'T'),
  jack(11, 'J'),
  queen(12, 'Q'),
  king(13, 'K'),
  ace(14, 'A');

  const Rank(this.value, this.code);

  final int value;
  final String code;

  bool get isFace => this == jack || this == queen || this == king;

  static Rank fromValue(int value) => values[value - 2];

  static Rank fromCode(String code) =>
      values.firstWhere((r) => r.code == code, orElse: () => throw FormatException('Unknown rank', code));
}

/// One card. Normal cards have codes 0..51 (`suit.index * 13 + rank.index`);
/// jokers have codes 52..55.
final class PlayingCard implements Comparable<PlayingCard> {
  const PlayingCard._(this.code);

  /// The canonical card of [suit] and [rank].
  factory PlayingCard(Suit suit, Rank rank) => _all[suit.index * 13 + rank.index];

  /// One of the four jokers (the index only tells them apart in a deck).
  factory PlayingCard.joker([int index = 0]) {
    RangeError.checkValueInInterval(index, 0, jokerCount - 1, 'index');
    return _all[jokerBase + index];
  }

  factory PlayingCard.fromCode(int code) => _all[code];

  /// Parses an [id] such as `AS`, `TD`, `7H` or `X0` (joker).
  factory PlayingCard.parse(String id) {
    if (id.length != 2) throw FormatException('Bad card id', id);
    if (id[0] == 'X') return PlayingCard.joker(int.parse(id[1]));
    return PlayingCard(Suit.fromCode(id[1]), Rank.fromCode(id[0]));
  }

  static const int jokerBase = 52;
  static const int jokerCount = 4;

  static final List<PlayingCard> _all = List<PlayingCard>.generate(
    jokerBase + jokerCount,
    PlayingCard._,
    growable: false,
  );

  /// Parses a whitespace-separated list of ids: `'AS KD 7H'`.
  static List<PlayingCard> list(String ids) =>
      [for (final id in ids.split(RegExp(r'\s+')).where((s) => s.isNotEmpty)) PlayingCard.parse(id)];

  final int code;

  bool get isJoker => code >= jokerBase;

  Suit get suit {
    if (isJoker) throw StateError('A joker has no suit');
    return Suit.values[code ~/ 13];
  }

  Rank get rank {
    if (isJoker) throw StateError('A joker has no rank');
    return Rank.values[code % 13];
  }

  /// Stable id used in JSON and by the UI to look up card art.
  String get id => isJoker ? 'X${code - jokerBase}' : '${rank.code}${suit.code}';

  @override
  int compareTo(PlayingCard other) => code - other.code;

  @override
  bool operator ==(Object other) => other is PlayingCard && other.code == code;

  @override
  int get hashCode => code;

  @override
  String toString() => id;
}

/// JSON helpers: cards are stored by [PlayingCard.id].
List<String> cardsToJson(Iterable<PlayingCard> cards) => [for (final c in cards) c.id];

List<PlayingCard> cardsFromJson(Object? json) => [for (final id in json! as List) PlayingCard.parse(id as String)];

List<List<String>> handsToJson(List<List<PlayingCard>> hands) => [for (final h in hands) cardsToJson(h)];

List<List<PlayingCard>> handsFromJson(Object? json) => [for (final h in json! as List) cardsFromJson(h)];

/// Sorts a copy of [cards] by code: used to compare multisets of cards.
List<PlayingCard> sortedCards(Iterable<PlayingCard> cards) => cards.toList()..sort();
