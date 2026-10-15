import 'dart:async';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../domain/list_posting.dart';
import '../domain/record_list.dart';

/// Reverses one change (the UI wraps it in an undo toast), exactly like
/// `NutritionService` and `PlanApplyService`.
typedef ListUndo = Future<void> Function();

/// A new or edited list.
class ListDraft {
  const ListDraft({required this.name, this.currency, this.note});

  /// His own name for it («أغراض البقالة»).
  final String name;

  /// The currency every price on the list is in (null = the base
  /// currency). Set once, when the list is created – changing it later
  /// would re-read every price in another currency.
  final String? currency;

  final String? note;
}

/// A new or edited line.
class ListItemDraft {
  const ListItemDraft({required this.title, this.quantity, this.unit, this.priceMilli, this.note});

  final String title;

  /// How much (null when he gave none).
  final double? quantity;

  /// His own unit word (null when he gave none).
  final String? unit;

  /// Price in milli-units: per [unit] when [quantity] is given, else the
  /// price of the whole line. Null when he gave none.
  final int? priceMilli;

  final String? note;
}

/// A list, its lines and what they add up to – one object for a screen or
/// a tile.
class ListBundle {
  ListBundle({required this.row, required this.items})
    : lines = ListRows.lines(items),
      totals = ListTotals.of(ListRows.lines(items));

  final RecordListRow row;

  /// The lines' rows, in his own order (what a write needs).
  final List<RecordListItemRow> items;

  /// The same lines as pure models, in his own order.
  final List<ListLine> lines;
  final ListTotals totals;

  /// The row behind one line (null once it is gone).
  RecordListItemRow? itemById(String id) {
    for (final r in items) {
      if (r.id == id) return r;
    }
    return null;
  }

  String get id => row.id;
  String get name => row.name;
  ListHost get host => ListHost(row.hostTable, row.hostId);

  /// The currency its prices are in, or null for the base currency.
  String? get currency => row.currency;

  /// Already turned into a money entry (a posted list never posts again).
  bool get posted => row.postedAt != null;

  List<ListLine> get open => [
    for (final l in lines)
      if (!l.done) l,
  ];

  List<ListLine> get ticked => [
    for (final l in lines)
      if (l.done) l,
  ];

  /// What posting would write, given the currency and whether a wallet in
  /// it exists (pure – see [ListPostPlan]).
  ListPostPlan plan({required String currency, required bool hasWallet}) =>
      ListPostPlan.of(totals: totals, currency: currency, posted: posted, hasWallet: hasWallet);
}

/// Row → pure model.
abstract final class ListRows {
  static ListLine line(RecordListItemRow r) => ListLine(
    id: r.id,
    listId: r.listId,
    title: r.title,
    quantity: r.quantity,
    unit: r.unit,
    priceMilli: r.priceMilli,
    done: r.done,
    doneAt: r.doneAt,
    note: r.note,
    sortOrder: r.sortOrder,
  );

  static List<ListLine> lines(Iterable<RecordListItemRow> rows) => [for (final r in rows) line(r)];
}

/// Every read and write of the shared list engine: lists on any host
/// record and their ordered lines.
///
/// One engine, every host. A list is addressed by `(hostTable, hostId)` –
/// the pair `LifeRecordLinks` resolves – so a budget envelope's shopping
/// list, a trip's list and (Part 5) the kitchen pantry are the same rows,
/// the same ticking and the same undo. Nothing here knows what a host is.
///
/// Each write returns a [ListUndo] that restores the exact prior state
/// (deleting a list restores its lines too, with their order and their
/// ticks). Nothing here is ever written on its own: every row comes from
/// something he typed or tapped.
///
/// **Money.** Prices are integer milli-units of the list's own currency
/// and nothing here converts between currencies. The ticked total is a sum
/// of exact ints ([ListTotals]); turning it into a ledger entry is the
/// Money package's job (`ShoppingPostService`), and this service only
/// records **that** it happened ([claimPost]) – which is what makes a
/// second post impossible rather than merely unlikely.
class ListService {
  ListService(this.repos, {DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() clock;

  MadarDatabase get _db => repos.db;

  EntityRepository<$RecordListsTable, RecordListRow> get _lists => repos.recordLists;
  EntityRepository<$RecordListItemsTable, RecordListItemRow> get _items => repos.recordListItems;

  // ------------------------------------------------------------- reads ----

  /// The lists of [host], in his own order.
  Stream<List<RecordListRow>> watchLists(ListHost host) =>
      _lists.watchAll(where: (t) => t.hostTable.equals(host.table) & t.hostId.equals(host.id));

  /// One snapshot of [host]'s lists.
  Future<List<RecordListRow>> listsOf(ListHost host) =>
      _lists.getAll(where: (t) => t.hostTable.equals(host.table) & t.hostId.equals(host.id));

  /// Every list in the database (the search index, the export summary).
  Stream<List<RecordListRow>> watchAllLists() => _lists.watchAll();

  Future<RecordListRow?> list(String id) => _lists.byId(id);

  /// Live view of one list (null once deleted).
  Stream<RecordListRow?> watchList(String id) => _lists.watchById(id);

  Future<RecordListItemRow?> item(String id) => _items.byId(id);

  /// The lines of [listId], in his own order.
  Stream<List<ListLine>> watchLines(String listId) =>
      _items.watchAll(where: (t) => t.listId.equals(listId)).map(ListRows.lines);

  Future<List<ListLine>> lines(String listId) async =>
      ListRows.lines(await _items.getAll(where: (t) => t.listId.equals(listId)));

  Future<List<RecordListItemRow>> itemRows(String listId) => _items.getAll(where: (t) => t.listId.equals(listId));

  /// Live list + lines + totals (null once the list is deleted).
  Stream<ListBundle?> watchBundle(String listId) => _combineLatest2(
    watchList(listId),
    _items.watchAll(where: (t) => t.listId.equals(listId)),
    (RecordListRow? row, List<RecordListItemRow> items) => row == null ? null : ListBundle(row: row, items: items),
  );

  /// One snapshot of list + lines + totals (null when it is gone).
  Future<ListBundle?> bundle(String listId) async {
    final row = await list(listId);
    if (row == null) return null;
    return ListBundle(row: row, items: await itemRows(listId));
  }

  Future<ListTotals> totals(String listId) async => ListTotals.of(await lines(listId));

  /// Totals of every list of [host] (the host's own screen shows them
  /// beside each name), keyed by list id.
  Stream<Map<String, ListTotals>> watchHostTotals(ListHost host) => _combineLatest2(
    watchLists(host),
    _items.watchAll(),
    (List<RecordListRow> rows, List<RecordListItemRow> items) {
      final byList = <String, List<ListLine>>{for (final r in rows) r.id: []};
      for (final i in items) {
        byList[i.listId]?.add(ListRows.line(i));
      }
      return {for (final MapEntry(:key, :value) in byList.entries) key: ListTotals.of(value)};
    },
  );

  /// Totals of every list in the database, keyed by list id (host tiles
  /// across a whole screen, the export summary).
  Stream<Map<String, ListTotals>> watchAllTotals() {
    return _items.watchAll().map((items) {
      final byList = <String, List<ListLine>>{};
      for (final i in items) {
        (byList[i.listId] ??= []).add(ListRows.line(i));
      }
      return {for (final MapEntry(:key, :value) in byList.entries) key: ListTotals.of(value)};
    });
  }

  /// How many lists hang on each host record of [table], keyed by host id
  /// (a budget row shows its list the way it shows its warnings).
  Stream<Map<String, int>> watchHostCounts(String table) {
    return _lists.watchAll(where: (t) => t.hostTable.equals(table)).map((rows) {
      final out = <String, int>{};
      for (final r in rows) {
        out[r.hostId] = (out[r.hostId] ?? 0) + 1;
      }
      return out;
    });
  }

  // ------------------------------------------------------------ lists ----

  RecordListsCompanion _list(ListHost host, ListDraft d) => RecordListsCompanion(
    hostTable: Value(host.table),
    hostId: Value(host.id),
    name: Value(d.name.trim()),
    currency: Value(_code(d.currency)),
    note: Value(_clean(d.note)),
  );

  /// A new list on [host]. Returns the row and the undo that removes it.
  Future<(RecordListRow, ListUndo)> addList(ListHost host, ListDraft d) async {
    final row = await _lists.insert(_list(host, d));
    return (row, () async => _lists.delete(row.id).then((_) {}));
  }

  /// Renames or re-notes a list (its currency is never changed: the prices
  /// on it were typed in that currency).
  Future<ListUndo> updateList(RecordListRow row, ListDraft d) async {
    await _lists.update(
      RecordListsCompanion(id: Value(row.id), name: Value(d.name.trim()), note: Value(_clean(d.note))),
    );
    return () => _lists.update(row);
  }

  /// Deletes a list with its lines; the undo restores both exactly.
  Future<ListUndo> deleteList(String id) async {
    return _db.transaction(() async {
      final items = await _items.deleteWhere((t) => t.listId.equals(id));
      final row = await _lists.delete(id);
      return () async {
        await _db.transaction(() async {
          if (row != null) await _lists.restore(row);
          if (items.isNotEmpty) await _items.restoreAll(items);
        });
      };
    });
  }

  Future<void> reorderLists(List<String> ids) => _lists.reorder(ids);

  /// Copies a list and its lines onto the same host – the way he starts
  /// next week's shopping from this week's. The copy is never posted, and
  /// its lines start **unticked** unless [keepTicks].
  Future<(RecordListRow, ListUndo)> duplicateList(RecordListRow row, {String? name, bool keepTicks = false}) async {
    return _db.transaction(() async {
      final copy = await _lists.insert(
        RecordListsCompanion(
          hostTable: Value(row.hostTable),
          hostId: Value(row.hostId),
          name: Value((name ?? row.name).trim()),
          currency: Value(row.currency),
          note: Value(row.note),
        ),
      );
      final source = await itemRows(row.id);
      for (final i in source) {
        await _items.insert(
          RecordListItemsCompanion(
            listId: Value(copy.id),
            title: Value(i.title),
            quantity: Value(i.quantity),
            unit: Value(i.unit),
            priceMilli: Value(i.priceMilli),
            done: Value(keepTicks && i.done),
            doneAt: Value(keepTicks ? i.doneAt : null),
            note: Value(i.note),
          ),
        );
      }
      return (copy, () => deleteList(copy.id).then((undo) {}));
    });
  }

  /// Deletes every list of [host] and their lines – for a host's own
  /// delete (a deleted envelope leaves no orphan list behind). The undo
  /// restores all of them.
  Future<ListUndo> deleteForHost(ListHost host) => deleteForHosts(host.table, [host.id]);

  /// [deleteForHost] for several records of one table at once (a budget
  /// sub-tree).
  Future<ListUndo> deleteForHosts(String hostTable, Iterable<String> hostIds) async {
    final ids = hostIds.toList();
    if (ids.isEmpty) return () async {};
    return _db.transaction(() async {
      final lists = await _lists.getAll(where: (t) => t.hostTable.equals(hostTable) & t.hostId.isIn(ids));
      if (lists.isEmpty) return () async {};
      final listIds = [for (final l in lists) l.id];
      final items = await _items.deleteWhere((t) => t.listId.isIn(listIds));
      await _lists.deleteWhere((t) => t.id.isIn(listIds));
      return () async {
        await _db.transaction(() async {
          await _lists.restoreAll(lists);
          if (items.isNotEmpty) await _items.restoreAll(items);
        });
      };
    });
  }

  // ------------------------------------------------------------ lines ----

  RecordListItemsCompanion _item(String listId, ListItemDraft d) => RecordListItemsCompanion(
    listId: Value(listId),
    title: Value(d.title.trim()),
    quantity: Value(_positive(d.quantity)),
    unit: Value(_clean(d.unit)),
    priceMilli: Value(_price(d.priceMilli)),
    note: Value(_clean(d.note)),
  );

  /// Adds a line at the end of [listId].
  Future<(RecordListItemRow, ListUndo)> addItem(String listId, ListItemDraft d) async {
    final row = await _items.insert(_item(listId, d));
    return (row, () async => _items.delete(row.id).then((_) {}));
  }

  /// Adds several lines at once (one pasted line per item); blank lines are
  /// skipped. One undo takes all of them back.
  Future<(List<RecordListItemRow>, ListUndo)> addItems(String listId, Iterable<String> titles) async {
    final rows = <RecordListItemRow>[];
    for (final title in titles) {
      if (title.trim().isEmpty) continue;
      rows.add(await _items.insert(_item(listId, ListItemDraft(title: title))));
    }
    return (
      rows,
      () async {
        for (final r in rows) {
          await _items.delete(r.id);
        }
      },
    );
  }

  Future<ListUndo> updateItem(RecordListItemRow row, ListItemDraft d) async {
    await _items.update(_item(row.listId, d).copyWith(id: Value(row.id)));
    return () => _items.update(row);
  }

  /// Ticks or un-ticks one line, stamping the moment he ticked it. The
  /// undo restores the flag **and** the old stamp.
  Future<ListUndo> setDone(RecordListItemRow row, bool done, {DateTime? at}) async {
    await _items.setColumns(row.id, {'done': done, 'done_at': done ? (at ?? clock()) : null});
    return () => _items.setColumns(row.id, {'done': row.done, 'done_at': row.doneAt});
  }

  /// Ticks or un-ticks every line of [listId] ("un-tick the whole list").
  /// The undo puts every line back exactly as it was.
  Future<ListUndo> setAllDone(String listId, bool done, {DateTime? at}) async {
    final rows = await itemRows(listId);
    final when = at ?? clock();
    await _db.transaction(() async {
      for (final r in rows) {
        if (r.done == done) continue;
        await _items.setColumns(r.id, {'done': done, 'done_at': done ? when : null});
      }
    });
    return () async {
      await _db.transaction(() async {
        for (final r in rows) {
          await _items.setColumns(r.id, {'done': r.done, 'done_at': r.doneAt});
        }
      });
    };
  }

  Future<ListUndo> deleteItem(RecordListItemRow row) async {
    final gone = await _items.delete(row.id);
    return () async {
      if (gone != null) await _items.restore(gone);
    };
  }

  /// Clears the ticked lines off [listId] (what he has already bought),
  /// keeping the open ones. The undo brings them back in place.
  Future<(int, ListUndo)> deleteDone(String listId) async {
    final rows = await _items.deleteWhere((t) => t.listId.equals(listId) & t.done.equals(true));
    return (
      rows.length,
      () async {
        if (rows.isNotEmpty) await _items.restoreAll(rows);
      },
    );
  }

  Future<void> reorderItems(List<String> ids) => _items.reorder(ids);

  /// Moves a line to another list (the pantry's «خلص» → the shopping
  /// list), at its end.
  Future<ListUndo> moveItem(RecordListItemRow row, String toListId) async {
    if (toListId == row.listId) return () async {};
    // Its place in the old list has to come back too: a data class never
    // writes `sort_order` (so a stale copy cannot undo a reorder), and
    // moving it to the end changed exactly that.
    final place = row.sortOrder;
    await _items.setColumn(row.id, 'list_id', toListId, moveToEnd: true);
    return () => _items.setColumns(row.id, {'list_id': row.listId, 'sort_order': place});
  }

  // ---------------------------------------------------------- posting ----

  /// Claims the right to post [listId]: marks it posted with what is being
  /// posted, and returns false when it **was already posted** – the guard
  /// that makes a second post impossible instead of merely unlikely.
  ///
  /// Read-then-write inside one database transaction, and drift runs the
  /// app's transactions one at a time on a single connection, so two taps
  /// (or two screens) racing each other cannot both claim it: the second
  /// one reads the first one's stamp and is refused.
  ///
  /// The caller writes the money entry **after** a true claim and names it
  /// with [attachPostTx] (or passes [txId] when it already knows it).
  Future<bool> claimPost(
    String listId, {
    required int amountMilli,
    required int itemCount,
    DateTime? at,
    String? txId,
  }) {
    return _db.transaction(() async {
      final row = await list(listId);
      if (row == null || row.postedAt != null) return false;
      await _lists.setColumns(listId, {
        'posted_at': at ?? clock(),
        'posted_amount_milli': amountMilli,
        'posted_item_count': itemCount,
        'posted_tx_id': txId,
      });
      return true;
    });
  }

  /// Names the entry a claimed post wrote.
  Future<void> attachPostTx(String listId, String txId) => _lists.setColumn(listId, 'posted_tx_id', txId);

  /// Takes the posted mark off [listId] (the undo of a post). The lines
  /// are untouched: he keeps his ticks.
  Future<void> clearPost(String listId) => _lists.setColumns(listId, {
    'posted_at': null,
    'posted_tx_id': null,
    'posted_amount_milli': null,
    'posted_item_count': null,
  });

  // --------------------------------------------------------- helpers ----

  static String? _clean(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  static String? _code(String? s) => _clean(s)?.toUpperCase();

  static double? _positive(double? v) => v == null || v <= 0 ? null : v;

  /// A price is never negative (he types what something costs).
  static int? _price(int? v) => v == null || v < 0 ? null : v;
}

/// The latest value of both streams, combined on every change of either
/// (and only once both have arrived).
///
/// Deliberately not `asyncExpand`: it waits for the inner stream to
/// **complete** before it reads the next outer event, and a drift query
/// stream never completes – so a deleted list kept reading as an empty one
/// and a new list never reached its host's totals.
Stream<R> _combineLatest2<A, B, R>(Stream<A> a, Stream<B> b, R Function(A a, B b) combine) {
  late StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  var hasA = false, hasB = false;
  late A lastA;
  late B lastB;
  void emit() {
    if (hasA && hasB) controller.add(combine(lastA, lastB));
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen((v) {
        lastA = v;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = b.listen((v) {
        lastB = v;
        hasB = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      subA = null;
      subB = null;
    },
  );
  return controller.stream;
}
