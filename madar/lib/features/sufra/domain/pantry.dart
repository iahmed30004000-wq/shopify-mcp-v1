/// The pantry: what is in the house, and the one view she opens first –
/// «شو قلّ أو خلص».
///
/// Pure Dart (no Flutter, no database). A pantry item is **stock**, not a
/// tick line: it has a quantity that goes down, a unit the matcher does
/// arithmetic in, a place in the house, an expiry day and a low mark. The
/// shopping list that comes out of it is Part 3b's list engine, unchanged.
library;

import 'package:meta/meta.dart';

import '../../search/domain/search_text.dart';
import 'kitchen_units.dart';

/// One thing in the house (a plain copy of a `pantry_items` row).
@immutable
class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    this.aliases = const [],
    this.quantity,
    this.unit,
    this.place,
    this.lowAt,
    this.low = false,
    this.expires,
    this.staple = false,
    this.note,
    this.archived = false,
  });

  final String id;

  /// Her own word («رز»).
  final String name;

  /// Her own other words for the same thing («طماطم» ↔ «بندورة»).
  final List<String> aliases;

  /// How much there is, in [unit]. Null = «في», amount unknown.
  final double? quantity;

  /// Her own unit word.
  final String? unit;

  /// Where it is kept, in her words.
  final String? place;

  /// At or below this much it counts low.
  final double? lowAt;

  /// She marked it low herself.
  final bool low;

  /// The expiry calendar day.
  final DateTime? expires;

  /// Always keep it in the house.
  final bool staple;
  final String? note;
  final bool archived;

  /// Nothing left: she typed a quantity and it is zero or less.
  bool get out => (quantity ?? 1) <= 0;

  /// She never said how much – «في رز» with no number.
  bool get amountUnknown => quantity == null;

  /// Her unit, folded.
  KitchenUnit get kitchenUnit => KitchenUnits.normalize(unit);

  /// Every word this item answers to, folded (its name and its aliases).
  List<String> get words => [
    for (final w in [name, ...aliases])
      if (SearchText.fold(w).isNotEmpty) SearchText.fold(w),
  ];

  @override
  String toString() => 'PantryItem($id, $name, ${quantity ?? '؟'} ${unit ?? ''})';
}

/// How an item stands today. One item can be both low and near its expiry;
/// [PantryStock.of] returns the one that matters most for the "what needs
/// attention" view, and the flags underneath stay readable.
enum PantryState {
  /// Nothing left (a typed quantity of zero).
  out,

  /// Low: at or below her threshold, or she marked it low.
  low,

  /// Past its expiry day.
  expired,

  /// Its expiry day is inside the warning window.
  expiringSoon,

  /// Fine.
  ok,
}

/// One item, judged against a day. Pure: give it the day and it answers.
@immutable
class PantryStock {
  const PantryStock({
    required this.item,
    required this.state,
    required this.isOut,
    required this.isLow,
    required this.daysToExpiry,
  });

  /// How many days before the expiry day an item starts to warn, unless she
  /// chose otherwise.
  static const int defaultExpiryWarningDays = 3;

  /// [item] judged on [today], warning [warningDays] before an expiry.
  factory PantryStock.of(PantryItem item, {required DateTime today, int warningDays = defaultExpiryWarningDays}) {
    final day = DateTime(today.year, today.month, today.day);
    final expires = item.expires;
    final days = expires == null
        ? null
        : DateTime(expires.year, expires.month, expires.day).difference(day).inDays;
    final isOut = item.out;
    final threshold = item.lowAt;
    final quantity = item.quantity;
    final isLow =
        !isOut &&
        (item.low || (threshold != null && quantity != null && quantity <= threshold + 1e-9));
    final state = isOut
        ? PantryState.out
        : days != null && days < 0
        ? PantryState.expired
        : isLow
        ? PantryState.low
        : days != null && days <= warningDays
        ? PantryState.expiringSoon
        : PantryState.ok;
    return PantryStock(item: item, state: state, isOut: isOut, isLow: isLow, daysToExpiry: days);
  }

  final PantryItem item;
  final PantryState state;

  /// Nothing left.
  final bool isOut;

  /// Low (independent of the expiry, so a low item near its date still
  /// reads as low).
  final bool isLow;

  /// Days until the expiry day (negative once it has passed, null when she
  /// gave no date).
  final int? daysToExpiry;

  bool get expired => daysToExpiry != null && daysToExpiry! < 0;

  /// On the list she actually acts on: finished, low, or expired.
  bool get needsAttention => state != PantryState.ok;

  /// It belongs on the shopping list: finished or low (an expired thing is
  /// a thing to throw out, which is a different decision – unless she keeps
  /// it as a staple, and then it is both).
  bool get shouldBuy => isOut || isLow || (staleStaple);

  bool get staleStaple => item.staple && expired;

  @override
  String toString() => 'PantryStock(${item.name}, ${state.name})';
}

/// The whole pantry, judged on one day: the attention list, the places she
/// keeps things in, and the index the matcher looks ingredients up in.
@immutable
class PantryBoard {
  PantryBoard._(this.today, this.stocks, this.warningDays)
    : _byWord = {
        for (final s in stocks)
          if (!s.item.archived)
            for (final w in s.item.words) w: s,
      };

  /// Judges [items] on [today]. Archived items are kept in [stocks] (so a
  /// screen can show them) but never resolve a recipe's ingredient.
  factory PantryBoard.of(
    Iterable<PantryItem> items, {
    required DateTime today,
    int warningDays = PantryStock.defaultExpiryWarningDays,
  }) => PantryBoard._(
    DateTime(today.year, today.month, today.day),
    List.unmodifiable([for (final i in items) PantryStock.of(i, today: today, warningDays: warningDays)]),
    warningDays,
  );

  final DateTime today;

  /// Every item with its verdict, in her own order.
  final List<PantryStock> stocks;
  final int warningDays;

  /// Folded word (name or alias) → the item it belongs to. The **last**
  /// item wins a word two items share, which is the same "latest spelling
  /// wins" rule `FoodLookup` uses.
  final Map<String, PantryStock> _byWord;

  /// The live items (what the matcher sees).
  List<PantryStock> get live => [
    for (final s in stocks)
      if (!s.item.archived) s,
  ];

  /// Finished, low or expired – the running «شو قلّ أو خلص» view, worst
  /// first (out, then expired, then low, then expiring soon) and inside a
  /// group in her own order.
  List<PantryStock> get attention {
    const rank = {
      PantryState.out: 0,
      PantryState.expired: 1,
      PantryState.low: 2,
      PantryState.expiringSoon: 3,
      PantryState.ok: 4,
    };
    final out = [
      for (final s in live)
        if (s.needsAttention) s,
    ];
    final order = {for (var i = 0; i < out.length; i++) out[i].item.id: i};
    out.sort((a, b) {
      final byState = rank[a.state]!.compareTo(rank[b.state]!);
      return byState != 0 ? byState : order[a.item.id]!.compareTo(order[b.item.id]!);
    });
    return out;
  }

  /// What belongs on the shopping list right now.
  List<PantryStock> get toBuy => [
    for (final s in attention)
      if (s.shouldBuy) s,
  ];

  /// Her places, in the order she first used them, with the item count.
  /// Items with no place land under [noPlace].
  static const String noPlace = '';

  Map<String, List<PantryStock>> get byPlace {
    final out = <String, List<PantryStock>>{};
    for (final s in live) {
      final place = s.item.place?.trim();
      (out[place == null || place.isEmpty ? noPlace : place] ??= []).add(s);
    }
    return out;
  }

  /// The item that answers to [word] (its name or one of her aliases),
  /// folded. Null when the house has no such thing.
  PantryStock? exact(String word) {
    final folded = SearchText.fold(word);
    return folded.isEmpty ? null : _byWord[folded];
  }

  /// Items whose word contains [word] or the other way round – the loose
  /// candidates for «رز» against «رز بسمتي». Only ever used after [exact]
  /// fails, and the matcher marks such a match so she can see it.
  List<PantryStock> contains(String word) {
    final folded = SearchText.fold(word);
    if (folded.isEmpty) return const [];
    final out = <String, PantryStock>{};
    for (final s in live) {
      for (final w in s.item.words) {
        if (w == folded) continue;
        if (w.contains(folded) || folded.contains(w)) {
          out[s.item.id] = s;
          break;
        }
      }
    }
    return out.values.toList();
  }

  int get length => live.length;
  bool get isEmpty => live.isEmpty;
}
