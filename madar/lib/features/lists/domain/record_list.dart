/// The list engine's pure models and arithmetic: which record a list hangs
/// on, one line of a list, and what a list adds up to.
///
/// Pure Dart (no Flutter, no database): safe in unit tests and isolates.
/// Money is in integer milli-units and every amount that could ever be a
/// fraction of a milli (a price × a quantity) is computed exactly with
/// [Rational] and rounded **once**, half-up – the single rounding rule of
/// all Madar money math.
library;

import 'package:meta/meta.dart';

import '../../../core/domain/money.dart';

/// The record a list belongs to: an SQL table name and that row's id – the
/// same pair `LifeRecordLinks` resolves to a screen.
///
/// The engine never asks what a host *is*. A new host (the kitchen pantry
/// of Part 5, a note, a custom module) is a new [table] value and a screen
/// that shows the list; nothing in here changes.
@immutable
class ListHost {
  const ListHost(this.table, this.id);

  /// A budget envelope («بقالة»): its shopping list, which can be posted
  /// to the ledger as one expense.
  static const String budgetItems = 'budget_items';

  /// A trip: its lists (☐ جواز ☐ شاحن ☐ دوا).
  static const String trips = 'trips';

  /// A dish of «السفرة» (Part 5): the list of what is missing for it.
  static const String recipes = 'recipes';

  /// The pantry of «السفرة» as a **place**: its one standing shopping
  /// list, `('pantry', 'house')`. The pantry is not a row, so this host
  /// has no record to read a name from and the all-lists screen names it
  /// itself.
  static const String pantry = 'pantry';

  /// The hosts that have a screen today. Not a limit of the engine: a list
  /// of any other table still stores, reads and ticks.
  static const Set<String> knownTables = {budgetItems, trips, recipes, pantry};

  final String table;
  final String id;

  bool get isEmpty => table.isEmpty || id.isEmpty;

  @override
  bool operator ==(Object other) => other is ListHost && other.table == table && other.id == id;

  @override
  int get hashCode => Object.hash(table, id);

  @override
  String toString() => 'ListHost($table/$id)';
}

/// One line of a list, as the screens and the arithmetic see it.
@immutable
class ListLine {
  const ListLine({
    required this.id,
    required this.listId,
    required this.title,
    this.quantity,
    this.unit,
    this.priceMilli,
    this.done = false,
    this.doneAt,
    this.note,
    this.sortOrder = 0,
  });

  final String id;
  final String listId;

  /// His own words («رز»).
  final String title;

  /// How much (2 kg, 3 pieces); null when he gave none.
  final double? quantity;

  /// His own unit word; null when he gave none.
  final String? unit;

  /// Price in milli-units of the list's currency: **per [unit]** when
  /// [quantity] is given, else the price of the whole line.
  final int? priceMilli;

  final bool done;

  /// When he ticked it (null while open).
  final DateTime? doneAt;
  final String? note;
  final int sortOrder;

  bool get hasPrice => priceMilli != null;

  /// What this line costs, exactly: the price when he gave no quantity,
  /// else price × quantity rounded half-up once to the milli. Null when he
  /// gave no price (a packing list has none).
  ///
  /// `٢ كيلو × ١٫٥٠٠ د.أ` → 3 000 milli. A half-milli result rounds away
  /// from zero (`0.5 × 1` milli → 1), like every other amount in Madar.
  int? get totalMilli {
    final price = priceMilli;
    if (price == null) return null;
    final q = quantity;
    if (q == null) return price;
    if (q <= 0) return 0;
    return (Rational.fromNum(q) * Rational.fromInt(price)).roundHalfUp();
  }

  ListLine copyWith({bool? done, DateTime? doneAt, bool clearDoneAt = false}) => ListLine(
    id: id,
    listId: listId,
    title: title,
    quantity: quantity,
    unit: unit,
    priceMilli: priceMilli,
    done: done ?? this.done,
    doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
    note: note,
    sortOrder: sortOrder,
  );

  @override
  String toString() => 'ListLine($title${done ? ' ✓' : ''}${priceMilli == null ? '' : ' $priceMilli'})';
}

/// Ticked / total and the exact amounts of one list (pure).
@immutable
class ListTotals {
  const ListTotals({
    required this.total,
    required this.done,
    required this.doneAmountMilli,
    required this.openAmountMilli,
    required this.pricedDone,
  });

  /// The totals of [lines].
  factory ListTotals.of(Iterable<ListLine> lines) {
    var total = 0, ticked = 0, pricedDone = 0, doneAmount = 0, openAmount = 0;
    for (final line in lines) {
      total++;
      final amount = line.totalMilli;
      if (line.done) {
        ticked++;
        if (amount != null) {
          pricedDone++;
          doneAmount += amount;
        }
      } else if (amount != null) {
        openAmount += amount;
      }
    }
    return ListTotals(
      total: total,
      done: ticked,
      doneAmountMilli: doneAmount,
      openAmountMilli: openAmount,
      pricedDone: pricedDone,
    );
  }

  static const empty = ListTotals(total: 0, done: 0, doneAmountMilli: 0, openAmountMilli: 0, pricedDone: 0);

  /// Lines on the list.
  final int total;

  /// Lines he has ticked.
  final int done;

  /// Exact sum of the ticked lines that carry a price (what posting would
  /// charge).
  final int doneAmountMilli;

  /// Exact sum of the lines still open – what the rest would cost.
  final int openAmountMilli;

  /// How many ticked lines carry a price.
  final int pricedDone;

  int get remaining => total - done;

  /// Everything ticked (an empty list is never complete).
  bool get complete => total > 0 && done == total;

  bool get isEmpty => total == 0;

  /// 0‥1 (0 for an empty list).
  double get fraction => total == 0 ? 0 : done / total;

  /// Price of the whole list (ticked and open together).
  int get allAmountMilli => doneAmountMilli + openAmountMilli;

  /// Whether anything on the list carries a price at all.
  bool get hasAmounts => allAmountMilli != 0 || pricedDone > 0;

  @override
  bool operator ==(Object other) =>
      other is ListTotals &&
      other.total == total &&
      other.done == done &&
      other.doneAmountMilli == doneAmountMilli &&
      other.openAmountMilli == openAmountMilli &&
      other.pricedDone == pricedDone;

  @override
  int get hashCode => Object.hash(total, done, doneAmountMilli, openAmountMilli, pricedDone);

  @override
  String toString() => 'ListTotals($done/$total, done $doneAmountMilli, open $openAmountMilli)';
}
