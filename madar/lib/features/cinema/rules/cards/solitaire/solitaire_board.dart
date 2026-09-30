/// Solitaire (Klondike): piles, actions, and the compact board that holds
/// every rule of play (S-1…S-33).
///
/// One implementation of the rules is shared by the game, the exact
/// "stuck" search, the solver and the auto-player, so they can never
/// disagree. The board is a small byte array: cheap to copy and to hash.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/card_rng.dart';
import '../core/deck.dart';
import '../core/playing_card.dart';
import 'solitaire_options.dart';

/// Solitaire rank: ace 1, 2…10, jack 11, queen 12, king 13 (S-1).
int solitaireRank(PlayingCard c) => c.rank == Rank.ace ? 1 : c.rank.value;

/// Hearts and diamonds are red; clubs and spades black.
bool isRedCard(PlayingCard c) => c.suit == Suit.hearts || c.suit == Suit.diamonds;

/// A pile: the waste, a column (0–6) or a foundation place (0–3).
enum SolitairePileKind { waste, column, foundation }

final class SolitairePile {
  const SolitairePile._(this.kind, this.index);

  const SolitairePile.column(int index) : this._(SolitairePileKind.column, index);

  const SolitairePile.foundation(int index) : this._(SolitairePileKind.foundation, index);

  /// Parses [toJson]: `w`, `c0`…`c6`, `f0`…`f3`.
  factory SolitairePile.fromJson(String id) => switch (id[0]) {
    'w' => waste,
    'c' => SolitairePile.column(int.parse(id.substring(1))),
    'f' => SolitairePile.foundation(int.parse(id.substring(1))),
    _ => throw FormatException('Unknown pile', id),
  };

  static const SolitairePile waste = SolitairePile._(SolitairePileKind.waste, 0);

  final SolitairePileKind kind;
  final int index;

  bool get isWaste => kind == SolitairePileKind.waste;
  bool get isColumn => kind == SolitairePileKind.column;
  bool get isFoundation => kind == SolitairePileKind.foundation;

  String toJson() => switch (kind) {
    SolitairePileKind.waste => 'w',
    SolitairePileKind.column => 'c$index',
    SolitairePileKind.foundation => 'f$index',
  };

  @override
  bool operator ==(Object other) => other is SolitairePile && other.kind == kind && other.index == index;

  @override
  int get hashCode => kind.index * 16 + index;

  @override
  String toString() => toJson();
}

enum SolitaireActionKind {
  /// Tap on the stock: turn one (or three) cards onto the waste (S-20, S-21).
  draw,

  /// Tap on the empty stock: the waste becomes the stock again (S-22).
  recycle,

  /// Move a card or a run (S-10…S-16).
  move,

  /// Turn up the face-down card at the end of a column (only when
  /// `autoFlip` is off).
  flip,

  /// Send every card home (S-32).
  autoComplete,
}

/// One player action. Value object with JSON.
final class SolitaireAction {
  const SolitaireAction._(this.kind, {this.from, this.to, this.count = 1, this.column = -1});

  /// Moves [count] cards: the last [count] of a column, or the top card of
  /// the waste or of a foundation (count 1).
  const SolitaireAction.move(SolitairePile from, SolitairePile to, {int count = 1})
    : this._(SolitaireActionKind.move, from: from, to: to, count: count);

  const SolitaireAction.flip(int column) : this._(SolitaireActionKind.flip, column: column);

  factory SolitaireAction.fromJson(Map<String, Object?> j) {
    final kind = SolitaireActionKind.values.byName(j['k']! as String);
    return switch (kind) {
      SolitaireActionKind.draw => draw,
      SolitaireActionKind.recycle => recycle,
      SolitaireActionKind.autoComplete => autoComplete,
      SolitaireActionKind.flip => SolitaireAction.flip(j['c']! as int),
      SolitaireActionKind.move => SolitaireAction.move(
        SolitairePile.fromJson(j['f']! as String),
        SolitairePile.fromJson(j['t']! as String),
        count: j['n']! as int,
      ),
    };
  }

  static const SolitaireAction draw = SolitaireAction._(SolitaireActionKind.draw);
  static const SolitaireAction recycle = SolitaireAction._(SolitaireActionKind.recycle);
  static const SolitaireAction autoComplete = SolitaireAction._(SolitaireActionKind.autoComplete);

  final SolitaireActionKind kind;
  final SolitairePile? from;
  final SolitairePile? to;
  final int count;
  final int column;

  Map<String, Object?> toJson() => {
    'k': kind.name,
    if (kind == SolitaireActionKind.move) ...{'f': from!.toJson(), 't': to!.toJson(), 'n': count},
    if (kind == SolitaireActionKind.flip) 'c': column,
  };

  @override
  bool operator ==(Object other) =>
      other is SolitaireAction &&
      other.kind == kind &&
      other.from == from &&
      other.to == to &&
      other.count == count &&
      other.column == column;

  @override
  int get hashCode => Object.hash(kind, from, to, count, column);

  @override
  String toString() => switch (kind) {
    SolitaireActionKind.move => 'move($from→$to${count > 1 ? ' ×$count' : ''})',
    SolitaireActionKind.flip => 'flip($column)',
    _ => kind.name,
  };
}

/// What happened, for the animations (see `SolitaireEvent`).
enum SolitaireEventType {
  stockDrawn,
  wasteRecycled,
  cardTurnedUp,

  /// Cards went onto a column (from the waste or another column).
  cardsMoved,
  toFoundation,
  fromFoundation,

  /// A card went home by itself (S-33).
  autoMoved,

  /// Auto-complete started; its cards follow as `toFoundation` events.
  autoCompleted,
  won,

  /// The clock took 2 points (S-46).
  timePenalty,

  /// The time bonus at the win (S-47).
  timeBonus,

  /// The last action was undone (S-35).
  undone,
}

/// Receives each rule event: [cards] are card codes, [points] the score
/// line (S-40), [isMove] whether it counts as a move (S-72).
typedef SolitaireJournal =
    void Function(
      SolitaireEventType type,
      List<int> cards,
      SolitairePile? from,
      SolitairePile? to,
      int points,
      bool isMove,
    );

// Card tables over codes 0–51 (`PlayingCard.code`) plus 52 = a card the
// viewer cannot see (a masked face-down or unseen stock card).
const int unknownCard = 52;
final Uint8List _rankOf = Uint8List.fromList([
  for (var c = 0; c < 52; c++) c % 13 == 12 ? 1 : c % 13 + 2,
  99,
]);
final Uint8List _redOf = Uint8List.fromList([
  for (var c = 0; c < 52; c++) (c ~/ 13 == 1 || c ~/ 13 == 2) ? 1 : 0,
  2,
]);

/// The code of the card of [suit] (0–3, `Suit.index`) and solitaire [rank].
int _code(int suit, int rank) => suit * 13 + (rank == 1 ? 12 : rank - 2);

// Layout of the byte array.
const int _fh = 0; // 4 foundation heights, by suit
const int _fp = 4; // 4 foundation places, by suit (255 = none)
const int _len = 8; // 7 column lengths
const int _down = 15; // 7 face-down counts
const int _tlen = 22; // talon length
const int _tpos = 23; // cards of the talon in the waste
const int _talon = 24; // 24 talon cards
const int _cols = 48; // 7 × 19 column cards, deepest first
const int _cap = 19;
const int _size = _cols + 7 * _cap;
const int _none = 255;

/// The cards of one deal. The talon is the stock and the waste read as one
/// sequence: `talon[0 … wasteCount − 1]` is the waste (bottom to top) and
/// `talon[wasteCount …]` the stock (top first). A draw moves the boundary,
/// a recycle resets it to 0, so a recycle keeps the order (S-22).
final class SolitaireBoard {
  SolitaireBoard._(this._b, this.recycles);

  factory SolitaireBoard._blank() {
    final b = Uint8List(_size);
    for (var s = 0; s < 4; s++) {
      b[_fp + s] = _none;
    }
    return SolitaireBoard._(b, 0);
  }

  /// The S-4 deal of a shuffled pack: in rows, row r (0–6) gives one card to
  /// each column r…6 left to right; the card that lands on column r in row
  /// r is face up. The next card is the top of the stock.
  factory SolitaireBoard.deal(List<PlayingCard> shuffled) {
    if (shuffled.length != 52) throw ArgumentError('A deal needs 52 cards');
    final board = SolitaireBoard._blank();
    var i = 0;
    for (var r = 0; r < 7; r++) {
      for (var c = r; c < 7; c++) {
        board._push(c, shuffled[i++].code);
      }
    }
    for (var c = 0; c < 7; c++) {
      board._b[_down + c] = c;
    }
    board._b[_tlen] = 24;
    for (var k = 0; k < 24; k++) {
      board._b[_talon + k] = shuffled[28 + k].code;
    }
    return board;
  }

  /// Deal number [seed]: the pack shuffled by `CardRng(seed)` (Fisher–Yates),
  /// then dealt as S-4. The same number gives the same deal everywhere.
  factory SolitaireBoard.forSeed(int seed) {
    final deck = buildDeck();
    CardRng(seed).shuffle(deck);
    return SolitaireBoard.deal(deck);
  }

  /// A position given pile by pile ([stock] and [waste] with the top card
  /// last; [foundations] by place, each from the ace up).
  factory SolitaireBoard.fromPiles({
    required List<List<PlayingCard>> columns,
    required List<int> faceDown,
    List<PlayingCard> stock = const [],
    List<PlayingCard> waste = const [],
    List<List<PlayingCard>> foundations = const [[], [], [], []],
    int recycles = 0,
  }) {
    final board = SolitaireBoard._blank()..recycles = recycles;
    for (var c = 0; c < 7; c++) {
      final col = c < columns.length ? columns[c] : const <PlayingCard>[];
      if (col.length > _cap) throw ArgumentError('Column $c is too long');
      for (final card in col) {
        board._push(c, card.code);
      }
      board._b[_down + c] = c < faceDown.length ? faceDown[c] : 0;
    }
    final talon = [...waste, ...stock.reversed];
    if (talon.length > 24) throw ArgumentError('At most 24 cards in the stock and waste');
    board._b[_tlen] = talon.length;
    board._b[_tpos] = waste.length;
    for (var k = 0; k < talon.length; k++) {
      board._b[_talon + k] = talon[k].code;
    }
    for (var p = 0; p < foundations.length && p < 4; p++) {
      final f = foundations[p];
      if (f.isEmpty) continue;
      final suit = f.first.suit.index;
      board._b[_fp + suit] = p;
      board._b[_fh + suit] = f.length;
    }
    return board;
  }

  final Uint8List _b;

  /// Recycles made so far in this deal.
  int recycles;

  SolitaireBoard copy() => SolitaireBoard._(Uint8List.fromList(_b), recycles);

  // ---------------------------------------------------------------------------
  // Reading.

  int colLen(int c) => _b[_len + c];

  /// Face-down cards at the start of column [c].
  int down(int c) => _b[_down + c];

  /// Card code at depth [i] of column [c] (0 = deepest).
  int at(int c, int i) => _b[_cols + c * _cap + i];

  /// Cards home in the foundation of [suit].
  int height(int suit) => _b[_fh + suit];

  /// Foundation place of [suit] (0–3), or −1 before its ace is home.
  int placeOf(int suit) => _b[_fp + suit] == _none ? -1 : _b[_fp + suit];

  /// Suit whose foundation is at [place], or −1 when the place is empty.
  int suitAt(int place) {
    for (var s = 0; s < 4; s++) {
      if (_b[_fp + s] == place) return s;
    }
    return -1;
  }

  int get talonLength => _b[_tlen];
  int get wasteCount => _b[_tpos];
  int get stockCount => _b[_tlen] - _b[_tpos];
  int talonAt(int i) => _b[_talon + i];

  /// Code of the top waste card, or −1.
  int get wasteTop => wasteCount == 0 ? -1 : _b[_talon + wasteCount - 1];

  int get cardsHome => _b[_fh] + _b[_fh + 1] + _b[_fh + 2] + _b[_fh + 3];

  bool get won => cardsHome == 52;

  int get faceDownTotal {
    var n = 0;
    for (var c = 0; c < 7; c++) {
      n += _b[_down + c];
    }
    return n;
  }

  /// True while some stock card has never been turned (S-36a): before the
  /// first recycle, the cards still in the stock.
  bool get stockUnseen => recycles == 0 && stockCount > 0;

  static int rankOfCode(int code) => _rankOf[code];

  static bool redCode(int code) => _redOf[code] == 1;

  static PlayingCard cardOf(int code) => PlayingCard.fromCode(code);

  // ---------------------------------------------------------------------------
  // Views for the game and the UI.

  List<PlayingCard> column(int c) => [for (var i = 0; i < colLen(c); i++) PlayingCard.fromCode(at(c, i))];

  /// The stock, top card last.
  List<PlayingCard> get stock => [
    for (var i = talonLength - 1; i >= wasteCount; i--) PlayingCard.fromCode(talonAt(i)),
  ];

  /// The waste, top card last.
  List<PlayingCard> get waste => [for (var i = 0; i < wasteCount; i++) PlayingCard.fromCode(talonAt(i))];

  /// The foundation at [place], from the ace up.
  List<PlayingCard> foundation(int place) {
    final s = suitAt(place);
    if (s < 0) return const [];
    return [for (var r = 1; r <= height(s); r++) PlayingCard.fromCode(_code(s, r))];
  }

  /// Every card of the deal (card conservation).
  List<PlayingCard> allCards() => [
    for (var c = 0; c < 7; c++) ...column(c),
    ...stock,
    ...waste,
    for (var p = 0; p < 4; p++) ...foundation(p),
  ];

  /// A copy in which every card [SolitaireBoard] viewer cannot see is
  /// [unknownCard]: the face-down column cards, and the stock while it is
  /// unseen (S-36a). Decisions made on it cannot depend on hidden cards.
  SolitaireBoard masked() {
    final m = copy();
    for (var c = 0; c < 7; c++) {
      for (var i = 0; i < down(c); i++) {
        m._b[_cols + c * _cap + i] = unknownCard;
      }
    }
    if (stockUnseen) {
      for (var i = wasteCount; i < talonLength; i++) {
        m._b[_talon + i] = unknownCard;
      }
    }
    return m;
  }

  /// A position key: the foundations, the talon, the recycles when they
  /// limit play, and the columns in sorted order (column order never changes
  /// what can be reached).
  String key({required bool withRecycles}) {
    final cols = <String>[
      for (var c = 0; c < 7; c++)
        String.fromCharCodes(Uint8List.sublistView(_b, _cols + c * _cap, _cols + c * _cap + colLen(c))) +
            String.fromCharCode(100 + down(c)),
    ]..sort();
    return String.fromCharCodes(Uint8List.sublistView(_b, _fh, _fh + 4)) +
        String.fromCharCode(100 + wasteCount) +
        String.fromCharCodes(Uint8List.sublistView(_b, _talon, _talon + talonLength)) +
        String.fromCharCode(150 + (withRecycles ? recycles : 0)) +
        cols.join();
  }

  // ---------------------------------------------------------------------------
  // Rules.

  /// Whether the run headed by [head] may go onto column [c] (S-11, S-13).
  bool fitsColumn(int head, int c) {
    final len = colLen(c);
    if (len == 0) return _rankOf[head] == 13;
    if (len == down(c)) return false;
    final last = at(c, len - 1);
    return _rankOf[last] == _rankOf[head] + 1 && _redOf[last] != _redOf[head];
  }

  int _leftmostEmptyPlace() {
    for (var p = 0; p < 4; p++) {
      if (suitAt(p) < 0) return p;
    }
    return -1;
  }

  /// Where [card] goes home when tapped (its suit's place, or the leftmost
  /// empty place for an ace), or −1 when it cannot go home (S-5, S-10).
  int homePlace(int card) {
    if (card >= 52) return -1;
    final s = card ~/ 13;
    final h = height(s);
    if (_rankOf[card] != h + 1) return -1;
    return h == 0 ? _leftmostEmptyPlace() : placeOf(s);
  }

  /// Whether [card] may go onto foundation [place].
  bool fitsPlace(int card, int place) {
    if (card >= 52 || place < 0 || place > 3) return false;
    final s = suitAt(place);
    if (s < 0) return _rankOf[card] == 1;
    return s == card ~/ 13 && _rankOf[card] == height(s) + 1;
  }

  /// Safe to send home (S-33): an ace or a two, or both other-colour
  /// foundations have reached rank − 1.
  bool isSafeHome(int card) {
    final r = _rankOf[card];
    if (r <= 2) return true;
    final (a, b) = _redOf[card] == 1 ? (0, 3) : (1, 2);
    return height(a) >= r - 1 && height(b) >= r - 1;
  }

  bool recycleAllowed(SolitaireOptions o) {
    final max = o.maxRecycles;
    return max == null || recycles < max;
  }

  /// Auto-complete is offered (S-32).
  bool canAutoComplete(SolitaireOptions o) {
    if (won || faceDownTotal > 0) return false;
    if (talonLength == 0) return true;
    return o.autoCompleteWithStock && o.drawCount == 1 && o.passLimit == null;
  }

  /// Every legal action (one foundation target per card: the tap target).
  List<SolitaireAction> legalActions(SolitaireOptions o) {
    final out = <SolitaireAction>[];
    if (won) return out;
    if (stockCount > 0) {
      out.add(SolitaireAction.draw);
    } else if (wasteCount > 0 && recycleAllowed(o)) {
      out.add(SolitaireAction.recycle);
    }
    if (!o.autoFlip) {
      for (var c = 0; c < 7; c++) {
        if (colLen(c) > 0 && down(c) == colLen(c)) out.add(SolitaireAction.flip(c));
      }
    }
    final top = wasteTop;
    if (top >= 0) {
      final p = homePlace(top);
      if (p >= 0) out.add(SolitaireAction.move(SolitairePile.waste, SolitairePile.foundation(p)));
      for (var t = 0; t < 7; t++) {
        if (fitsColumn(top, t)) out.add(SolitaireAction.move(SolitairePile.waste, SolitairePile.column(t)));
      }
    }
    for (var c = 0; c < 7; c++) {
      final len = colLen(c);
      final d = down(c);
      if (len == d) continue;
      final p = homePlace(at(c, len - 1));
      if (p >= 0) out.add(SolitaireAction.move(SolitairePile.column(c), SolitairePile.foundation(p)));
      for (var k = d; k < len; k++) {
        final head = at(c, k);
        for (var t = 0; t < 7; t++) {
          if (t != c && fitsColumn(head, t)) {
            out.add(SolitaireAction.move(SolitairePile.column(c), SolitairePile.column(t), count: len - k));
          }
        }
      }
    }
    if (o.allowFoundationToTableau) {
      for (var p = 0; p < 4; p++) {
        final s = suitAt(p);
        if (s < 0) continue;
        final card = _code(s, height(s));
        for (var t = 0; t < 7; t++) {
          if (fitsColumn(card, t)) {
            out.add(SolitaireAction.move(SolitairePile.foundation(p), SolitairePile.column(t)));
          }
        }
      }
    }
    if (canAutoComplete(o)) out.add(SolitaireAction.autoComplete);
    return out;
  }

  /// Null when [a] is legal, else a stable error id.
  String? check(SolitaireAction a, SolitaireOptions o) {
    if (won) return 'gameWon';
    switch (a.kind) {
      case SolitaireActionKind.draw:
        return stockCount > 0 ? null : 'stockEmpty';
      case SolitaireActionKind.recycle:
        if (stockCount > 0) return 'stockNotEmpty';
        if (wasteCount == 0) return 'wasteEmpty';
        return recycleAllowed(o) ? null : 'noPassesLeft';
      case SolitaireActionKind.flip:
        final c = a.column;
        if (o.autoFlip || c < 0 || c > 6) return 'illegalMove';
        return colLen(c) > 0 && down(c) == colLen(c) ? null : 'nothingToTurn';
      case SolitaireActionKind.autoComplete:
        return canAutoComplete(o) ? null : 'cannotAutoComplete';
      case SolitaireActionKind.move:
        return _checkMove(a.from!, a.to!, a.count, o);
    }
  }

  String? _checkMove(SolitairePile from, SolitairePile to, int count, SolitaireOptions o) {
    if (count < 1) return 'illegalMove';
    final int head;
    switch (from.kind) {
      case SolitairePileKind.waste:
        if (count != 1) return 'onlyTopWasteCard';
        if (wasteCount == 0) return 'wasteEmpty';
        head = wasteTop;
      case SolitairePileKind.column:
        final c = from.index;
        if (c < 0 || c > 6) return 'illegalMove';
        final len = colLen(c);
        if (count > len - down(c)) return len == 0 ? 'emptyPile' : 'faceDownCard';
        head = at(c, len - count);
        if (to.isColumn && to.index == c) return 'sameColumn';
      case SolitairePileKind.foundation:
        if (!o.allowFoundationToTableau) return 'foundationLocked';
        if (count != 1) return 'illegalMove';
        final s = suitAt(from.index);
        if (s < 0) return 'emptyPile';
        head = _code(s, height(s));
    }
    switch (to.kind) {
      case SolitairePileKind.waste:
        return 'illegalMove';
      case SolitairePileKind.foundation:
        if (from.isFoundation) return 'illegalMove';
        if (count != 1) return 'oneCardHome';
        return fitsPlace(head, to.index) ? null : 'doesNotFitFoundation';
      case SolitairePileKind.column:
        if (to.index < 0 || to.index > 6) return 'illegalMove';
        if (fitsColumn(head, to.index)) return null;
        return colLen(to.index) == 0 ? 'onlyKingOnEmpty' : 'doesNotFitColumn';
    }
  }

  // ---------------------------------------------------------------------------
  // Changing the board. The caller checks legality first.

  void _push(int c, int card) {
    final len = _b[_len + c];
    _b[_cols + c * _cap + len] = card;
    _b[_len + c] = len + 1;
  }

  int _popWaste() {
    final pos = _b[_tpos];
    final len = _b[_tlen];
    final card = _b[_talon + pos - 1];
    for (var i = pos - 1; i < len - 1; i++) {
      _b[_talon + i] = _b[_talon + i + 1];
    }
    _b[_tlen] = len - 1;
    _b[_tpos] = pos - 1;
    return card;
  }

  void _toFoundation(int card, int place) {
    final s = card ~/ 13;
    if (_b[_fp + s] == _none) _b[_fp + s] = place;
    _b[_fh + s]++;
  }

  int _fromFoundation(int place) {
    final s = suitAt(place);
    final h = _b[_fh + s];
    _b[_fh + s] = h - 1;
    if (h == 1) _b[_fp + s] = _none;
    return _code(s, h);
  }

  /// Applies a legal [a] and its automatic follow-ups: turning up exposed
  /// cards (S-14) and the automatic moves home (S-33). [journal] hears every
  /// scored event in order.
  void apply(SolitaireAction a, SolitaireOptions o, [SolitaireJournal? journal]) {
    switch (a.kind) {
      case SolitaireActionKind.draw:
        _draw(o, journal);
      case SolitaireActionKind.recycle:
        _recycle(o, journal);
      case SolitaireActionKind.flip:
        _flip(a.column, journal);
      case SolitaireActionKind.autoComplete:
        _autoComplete(o, journal);
      case SolitaireActionKind.move:
        _move(a.from!, a.to!, a.count, o, journal);
    }
    if (!won) autoMoves(o, journal);
  }

  void _draw(SolitaireOptions o, SolitaireJournal? journal) {
    final pos = wasteCount;
    final n = math.min(o.drawCount, stockCount);
    _b[_tpos] = pos + n;
    journal?.call(
      SolitaireEventType.stockDrawn,
      [for (var i = pos; i < pos + n; i++) talonAt(i)],
      null,
      SolitairePile.waste,
      0,
      true,
    );
  }

  /// S-22, S-40f, S-40g.
  void _recycle(SolitaireOptions o, SolitaireJournal? journal) {
    recycles++;
    _b[_tpos] = 0;
    final points = o.drawCount == 1 ? -100 : (recycles >= o.draw3PenaltyFromRecycle ? -20 : 0);
    journal?.call(SolitaireEventType.wasteRecycled, const [], SolitairePile.waste, null, points, true);
  }

  void _flip(int c, SolitaireJournal? journal) {
    final len = colLen(c);
    _b[_down + c] = len - 1;
    journal?.call(SolitaireEventType.cardTurnedUp, [at(c, len - 1)], SolitairePile.column(c), null, 5, false);
  }

  void _autoFlip(int c, SolitaireOptions o, SolitaireJournal? journal) {
    final len = colLen(c);
    if (o.autoFlip && len > 0 && down(c) == len) _flip(c, journal);
  }

  void _move(SolitairePile from, SolitairePile to, int count, SolitaireOptions o, SolitaireJournal? journal) {
    final cards = <int>[];
    switch (from.kind) {
      case SolitairePileKind.waste:
        cards.add(_popWaste());
      case SolitairePileKind.foundation:
        cards.add(_fromFoundation(from.index));
      case SolitairePileKind.column:
        final c = from.index;
        final len = colLen(c);
        for (var i = len - count; i < len; i++) {
          cards.add(at(c, i));
        }
        _b[_len + c] = len - count;
    }
    final SolitaireEventType type;
    final int points;
    if (to.isFoundation) {
      _toFoundation(cards.single, to.index);
      type = SolitaireEventType.toFoundation;
      points = 10;
    } else {
      for (final card in cards) {
        _push(to.index, card);
      }
      type = from.isFoundation ? SolitaireEventType.fromFoundation : SolitaireEventType.cardsMoved;
      points = switch (from.kind) {
        SolitairePileKind.waste => 5,
        SolitairePileKind.foundation => -15,
        SolitairePileKind.column => 0,
      };
    }
    journal?.call(type, cards, from, to, points, true);
    if (from.isColumn) _autoFlip(from.index, o, journal);
  }

  /// The automatic moves home after an action (S-33): repeatedly the waste
  /// card (draw one only) and exposed column cards, safe ones only unless
  /// the option says `always`.
  void autoMoves(SolitaireOptions o, SolitaireJournal? journal) {
    final mode = o.autoMoveToFoundation;
    if (mode == SolitaireAutoMove.off) return;
    final always = mode == SolitaireAutoMove.always;
    while (true) {
      var moved = false;
      final top = wasteTop;
      if (o.drawCount == 1 && top >= 0) {
        final p = homePlace(top);
        if (p >= 0 && (always || isSafeHome(top))) {
          _popWaste();
          _toFoundation(top, p);
          journal?.call(SolitaireEventType.autoMoved, [top], SolitairePile.waste, SolitairePile.foundation(p), 10, true);
          moved = true;
        }
      }
      if (!moved) {
        for (var c = 0; c < 7; c++) {
          final len = colLen(c);
          if (len == down(c)) continue;
          final card = at(c, len - 1);
          final p = homePlace(card);
          if (p < 0 || !(always || isSafeHome(card))) continue;
          _b[_len + c] = len - 1;
          _toFoundation(card, p);
          journal?.call(
            SolitaireEventType.autoMoved,
            [card],
            SolitairePile.column(c),
            SolitairePile.foundation(p),
            10,
            true,
          );
          _autoFlip(c, o, journal);
          moved = true;
          break;
        }
      }
      if (!moved || won) return;
    }
  }

  /// S-32: the waste card home if it can go; else the lowest-ranked column
  /// card that can (ties: leftmost); else draw, or recycle an empty stock.
  void _autoComplete(SolitaireOptions o, SolitaireJournal? journal) {
    journal?.call(SolitaireEventType.autoCompleted, const [], null, null, 0, false);
    for (var guard = 0; guard < 20000 && !won; guard++) {
      final top = wasteTop;
      if (top >= 0) {
        final p = homePlace(top);
        if (p >= 0) {
          _move(SolitairePile.waste, SolitairePile.foundation(p), 1, o, journal);
          continue;
        }
      }
      var best = -1;
      for (var c = 0; c < 7; c++) {
        final len = colLen(c);
        if (len == 0 || len == down(c)) continue;
        final card = at(c, len - 1);
        if (homePlace(card) < 0) continue;
        if (best < 0 || _rankOf[card] < _rankOf[at(best, colLen(best) - 1)]) best = c;
      }
      if (best >= 0) {
        final card = at(best, colLen(best) - 1);
        _move(SolitairePile.column(best), SolitairePile.foundation(homePlace(card)), 1, o, journal);
        continue;
      }
      if (stockCount > 0) {
        _draw(o, journal);
      } else if (wasteCount > 0) {
        _recycle(o, journal);
      } else {
        return;
      }
    }
  }
}
