import 'dart:math' as math;

/// The three sizes of «أزواج النجوم»: pairs and the grid they sit in.
enum PairsSize {
  small(pairs: 6, columns: 3),
  medium(pairs: 8, columns: 4),
  large(pairs: 12, columns: 4);

  const PairsSize({required this.pairs, required this.columns});

  final int pairs;
  final int columns;

  int get cards => pairs * 2;
  int get rows => (cards / columns).ceil();
}

/// What one tap did.
enum FlipResult {
  /// Nothing changed: out of range, already open or matched.
  ignored,

  /// A first card turned over, waiting for its partner.
  flipped,

  /// The second card matched the first: the pair stays open.
  matched,

  /// The second card was a different one: the two wait to be turned back
  /// ([PairsGame.settle]). No penalty, no counter of mistakes.
  missed,
}

/// How many different pictures exist (each size picks that many from them).
const int pairSymbolCount = 12;

/// The rules of the memory-pairs game, with no Flutter in it.
///
/// A [seed] fixes the shuffle, so a test (or a "play the same game again")
/// gets the same deck. There is no clock and no score to lose: the game is
/// over when every pair is open.
class PairsGame {
  PairsGame({required this.size, required this.seed}) : deck = _deal(size, seed);

  final PairsSize size;
  final int seed;

  /// The picture id (0 to [pairSymbolCount] - 1) at each position.
  final List<int> deck;

  final Set<int> _matched = <int>{};
  final List<int> _up = <int>[];
  int _moves = 0;
  int _missSerial = 0;

  static List<int> _deal(PairsSize size, int seed) {
    final rnd = math.Random(seed);
    final symbols = List<int>.generate(pairSymbolCount, (i) => i)..shuffle(rnd);
    final cards = <int>[
      for (final s in symbols.take(size.pairs)) ...[s, s],
    ]..shuffle(rnd);
    return List<int>.unmodifiable(cards);
  }

  /// Pairs found so far.
  int get matchedPairs => _matched.length ~/ 2;

  /// Every pair is open.
  bool get won => _matched.length == deck.length;

  /// Second-card turns so far (shown to nobody as a score).
  int get moves => _moves;

  /// Whether the card at [index] shows its picture.
  bool isFaceUp(int index) => _matched.contains(index) || _up.contains(index);

  bool isMatched(int index) => _matched.contains(index);

  /// Two different cards are open and waiting to be turned back.
  bool get hasPendingMiss => _up.length == 2;

  /// Changes with every miss, so a delayed [settleIf] cannot turn back a
  /// newer pair.
  int get missSerial => _missSerial;

  /// Turns the card at [index].
  ///
  /// A tap while two unmatched cards are still open turns those back first
  /// and then opens the new card: a child never has to wait.
  FlipResult flip(int index) {
    if (index < 0 || index >= deck.length) return FlipResult.ignored;
    if (_matched.contains(index) || _up.contains(index)) return FlipResult.ignored;
    if (_up.length == 2) _up.clear();
    _up.add(index);
    if (_up.length == 1) return FlipResult.flipped;
    _moves++;
    final a = _up[0], b = _up[1];
    if (deck[a] == deck[b]) {
      _matched
        ..add(a)
        ..add(b);
      _up.clear();
      return FlipResult.matched;
    }
    _missSerial++;
    return FlipResult.missed;
  }

  /// Turns a waiting pair back. Does nothing when no pair is waiting.
  void settle() {
    if (_up.length == 2) _up.clear();
  }

  /// [settle], but only when the pair that was waiting at [serial] is still
  /// the one waiting now (a later tap may already have turned it back).
  bool settleIf(int serial) {
    if (serial != _missSerial || _up.length != 2) return false;
    _up.clear();
    return true;
  }
}
