import 'package:flutter/foundation.dart';

/// One kanban column as stored in `Boards.columns` (`{"id":…,"label":…}`).
///
/// The column whose id is [BoardColumns.doneId] is the board's "done"
/// column: a card there is finished (the orbit reads `columnId == 'done'`
/// for the Work planet's score and moons, so the id – not a flag – carries
/// the meaning). A board has at most one; it may have none.
@immutable
class BoardColumn {
  const BoardColumn({required this.id, required this.label});

  final String id;

  /// What the user named it. The seeded English defaults ("To-do", "Doing",
  /// "Done") are shown localised – see [BoardColumns.defaultKindOf].
  final String label;

  bool get isDone => id == BoardColumns.doneId;

  BoardColumn copyWith({String? id, String? label}) => BoardColumn(id: id ?? this.id, label: label ?? this.label);

  Map<String, Object?> toJson() => {'id': id, 'label': label};

  @override
  bool operator ==(Object other) => other is BoardColumn && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);

  @override
  String toString() => 'BoardColumn($id, $label)';
}

/// The stored default columns, recognised to show them in the user's
/// language until renamed.
enum DefaultColumnKind { todo, doing, done }

/// A change to a board's columns: the new list and how cards move
/// (`old column id → new column id`; applied simultaneously).
@immutable
class ColumnsEdit {
  const ColumnsEdit(this.columns, [this.remap = const {}]);

  final List<BoardColumn> columns;
  final Map<String, String> remap;

  bool get changesCards => remap.isNotEmpty;
}

/// Pure rules for a board's columns: parsing the stored JSON tolerantly,
/// the done column, neighbours for "move forward / back", and every edit
/// (add, rename, reorder, delete, mark as done) as a [ColumnsEdit].
abstract final class BoardColumns {
  static const String todoId = 'todo';
  static const String doingId = 'doing';
  static const String doneId = 'done';

  /// English labels written by the database default (and by new boards).
  static const Map<DefaultColumnKind, String> defaultLabels = {
    DefaultColumnKind.todo: 'To-do',
    DefaultColumnKind.doing: 'Doing',
    DefaultColumnKind.done: 'Done',
  };

  static const int maxColumns = 12;
  static const int maxLabelLength = 40;

  /// To-do / Doing / Done.
  static List<BoardColumn> defaults() => const [
    BoardColumn(id: todoId, label: 'To-do'),
    BoardColumn(id: doingId, label: 'Doing'),
    BoardColumn(id: doneId, label: 'Done'),
  ];

  /// Reads `Boards.columns`: skips malformed entries and duplicate ids;
  /// falls back to [defaults] when nothing usable is left.
  static List<BoardColumn> parse(List<Object?>? json) {
    final out = <BoardColumn>[];
    final seen = <String>{};
    for (final e in json ?? const <Object?>[]) {
      if (e is! Map) continue;
      final id = e['id'];
      if (id is! String || id.trim().isEmpty || !seen.add(id)) continue;
      final label = e['label'];
      out.add(BoardColumn(id: id, label: label is String ? label : ''));
    }
    return out.isEmpty ? defaults() : out;
  }

  static List<Map<String, Object?>> encode(List<BoardColumn> columns) => [for (final c in columns) c.toJson()];

  /// Which default the label still is (null once renamed). Matches on the
  /// label alone, so a re-keyed "Done" column keeps its localised name.
  static DefaultColumnKind? defaultKindOf(BoardColumn c) {
    final label = c.label.trim();
    if (label.isEmpty) {
      return switch (c.id) {
        todoId => DefaultColumnKind.todo,
        doingId => DefaultColumnKind.doing,
        doneId => DefaultColumnKind.done,
        _ => null,
      };
    }
    for (final e in defaultLabels.entries) {
      if (e.value.toLowerCase() == label.toLowerCase()) return e.key;
    }
    return null;
  }

  static int indexOf(List<BoardColumn> columns, String id) => columns.indexWhere((c) => c.id == id);

  static BoardColumn? byId(List<BoardColumn> columns, String id) {
    final i = indexOf(columns, id);
    return i < 0 ? null : columns[i];
  }

  static bool hasDone(List<BoardColumn> columns) => columns.any((c) => c.isDone);

  /// Where a reopened card goes: the first column that is not done.
  static String firstOpenId(List<BoardColumn> columns) =>
      columns.firstWhere((c) => !c.isDone, orElse: () => columns.first).id;

  /// Where a card whose column no longer exists is shown.
  static String resolve(List<BoardColumn> columns, String columnId) =>
      indexOf(columns, columnId) >= 0 ? columnId : firstOpenId(columns);

  /// The next column in reading order ("forward"), or null at the end.
  static String? nextId(List<BoardColumn> columns, String id) {
    final i = indexOf(columns, id);
    return i < 0 || i + 1 >= columns.length ? null : columns[i + 1].id;
  }

  /// The previous column ("back"), or null at the start.
  static String? previousId(List<BoardColumn> columns, String id) {
    final i = indexOf(columns, id);
    return i <= 0 ? null : columns[i - 1].id;
  }

  // ------------------------------------------------------------- edits ----

  static String _clean(String label) {
    final s = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    return s.length > maxLabelLength ? s.substring(0, maxLabelLength) : s;
  }

  /// A fresh id not used by [columns] (`c1`, `c2`, …).
  static String freshId(List<BoardColumn> columns) {
    final used = {for (final c in columns) c.id};
    var n = columns.length + 1;
    while (used.contains('c$n')) {
      n++;
    }
    return 'c$n';
  }

  /// Adds a column named [label] just before the done column (the done
  /// column stays last), or at the end when there is none.
  static ColumnsEdit add(List<BoardColumn> columns, String label) {
    final l = _clean(label);
    if (l.isEmpty || columns.length >= maxColumns) return ColumnsEdit(columns);
    final c = BoardColumn(id: freshId(columns), label: l);
    final out = [...columns];
    final done = out.indexWhere((x) => x.isDone);
    if (done >= 0 && done == out.length - 1) {
      out.insert(done, c);
    } else {
      out.add(c);
    }
    return ColumnsEdit(out);
  }

  static ColumnsEdit rename(List<BoardColumn> columns, String id, String label) {
    final l = _clean(label);
    if (l.isEmpty) return ColumnsEdit(columns);
    return ColumnsEdit([for (final c in columns) c.id == id ? c.copyWith(label: l) : c]);
  }

  /// Puts the columns in [idsInOrder]; unknown ids are ignored and missing
  /// ones keep their relative order at the end.
  static ColumnsEdit reorder(List<BoardColumn> columns, List<String> idsInOrder) {
    final byId = {for (final c in columns) c.id: c};
    final out = <BoardColumn>[for (final id in idsInOrder) ?byId.remove(id)];
    out.addAll(columns.where((c) => byId.containsKey(c.id)));
    return ColumnsEdit(out);
  }

  /// Removes column [id]. Its cards move to [moveCardsTo] (default: the
  /// neighbour before it, else the one after). The last column cannot go.
  static ColumnsEdit remove(List<BoardColumn> columns, String id, {String? moveCardsTo}) {
    final i = indexOf(columns, id);
    if (i < 0 || columns.length <= 1) return ColumnsEdit(columns);
    final out = [...columns]..removeAt(i);
    var target = moveCardsTo;
    if (target == null || target == id || indexOf(out, target) < 0) {
      target = out[i > 0 ? i - 1 : 0].id;
    }
    return ColumnsEdit(out, {id: target});
  }

  /// Makes [id] the board's done column (null: the board has none). The
  /// column is re-keyed to [doneId] and the previous done column gets a
  /// fresh id; [ColumnsEdit.remap] moves their cards along.
  static ColumnsEdit markDone(List<BoardColumn> columns, String? id) {
    if (id == doneId) return ColumnsEdit(columns);
    if (id != null && indexOf(columns, id) < 0) return ColumnsEdit(columns);
    final remap = <String, String>{};
    final previous = indexOf(columns, doneId);
    var out = [...columns];
    if (previous >= 0) {
      final fresh = freshId(out);
      out[previous] = out[previous].copyWith(id: fresh);
      remap[doneId] = fresh;
    }
    if (id != null) {
      final i = indexOf(out, id);
      out[i] = out[i].copyWith(id: doneId);
      remap[id] = doneId;
    }
    out = List.unmodifiable(out);
    return ColumnsEdit(out, remap);
  }

  /// Applies [remap] to one card's column id.
  static String remapped(Map<String, String> remap, String columnId) => remap[columnId] ?? columnId;
}
