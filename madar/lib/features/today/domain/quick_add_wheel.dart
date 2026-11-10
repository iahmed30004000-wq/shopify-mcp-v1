import 'dart:convert';

/// The actions the quick-add wheel can hold, as ids (the UI maps each id to an
/// icon and a label; this file holds no text).
enum QuickAddAction {
  task('task'),
  expense('expense'),
  medicineTaken('medicine_taken'),
  meal('meal'),
  water('water'),
  prayerLog('prayer_log'),
  note('note'),
  workout('workout');

  const QuickAddAction(this.id);

  /// Persisted id: never rename.
  final String id;

  static QuickAddAction? tryParse(Object? id) {
    for (final a in values) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// The long-press wheel of the ＋ button: exactly [slotCount] slots, each an
/// action id, no id twice, in the user's order.
///
/// Immutable: every change returns a new wheel. Ids are strings so the wheel
/// can hold actions added later (pass a larger [catalog]); with the default
/// catalog it is always a permutation of the eight built-in actions.
class QuickAddWheel {
  const QuickAddWheel._(this.slots);

  /// The wheel has eight slices.
  static const int slotCount = 8;

  /// Bumped when the JSON shape changes.
  static const int version = 1;

  /// The ids the wheel accepts by default.
  static final Set<String> defaultCatalog = {for (final a in QuickAddAction.values) a.id};

  /// The factory default: task, expense, medicine taken, meal, water, prayer
  /// log, note, workout - clockwise from the top.
  static final QuickAddWheel defaults = QuickAddWheel._(List.unmodifiable([for (final a in QuickAddAction.values) a.id]));

  /// Slot 0 is the top slice, then clockwise.
  final List<String> slots;

  /// Moves the slice at [from] to [to], shifting the ones between (a drag).
  QuickAddWheel move(int from, int to) {
    if (!_valid(from) || !_valid(to) || from == to) return this;
    final next = [...slots];
    final item = next.removeAt(from);
    next.insert(to, item);
    return QuickAddWheel._(List.unmodifiable(next));
  }

  /// Swaps two slices.
  QuickAddWheel swap(int a, int b) {
    if (!_valid(a) || !_valid(b) || a == b) return this;
    final next = [...slots];
    final t = next[a];
    next[a] = next[b];
    next[b] = t;
    return QuickAddWheel._(List.unmodifiable(next));
  }

  /// Puts [id] in [slot]. When [id] already sits in another slot the two swap
  /// (so no id is ever lost or doubled); an id outside [catalog] is ignored.
  QuickAddWheel assign(int slot, String id, {Set<String>? catalog}) {
    if (!_valid(slot) || !(catalog ?? defaultCatalog).contains(id)) return this;
    final at = slots.indexOf(id);
    if (at == slot) return this;
    if (at >= 0) return swap(slot, at);
    final next = [...slots];
    next[slot] = id;
    return QuickAddWheel._(List.unmodifiable(next));
  }

  /// The factory order again.
  QuickAddWheel reset() => defaults;

  bool get isDefault => _eq(slots, defaults.slots);

  static bool _eq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _valid(int i) => i >= 0 && i < slots.length;

  Map<String, Object?> toJson() => {'v': version, 'slots': slots};

  String encode() => jsonEncode(toJson());

  /// Reads what [toJson] wrote. Never throws and always returns a full wheel:
  /// unknown ids and repeats are dropped, missing slices are refilled from the
  /// defaults (in default order), extra ones are cut. A broken value gives the
  /// default wheel.
  factory QuickAddWheel.fromJson(Object? json, {Set<String>? catalog}) {
    final allowed = catalog ?? defaultCatalog;
    final raw = json is Map ? json['slots'] : null;
    final out = <String>[];
    if (raw is List) {
      for (final v in raw) {
        if (v is String && allowed.contains(v) && !out.contains(v) && out.length < slotCount) out.add(v);
      }
    }
    for (final a in QuickAddAction.values) {
      if (out.length >= slotCount) break;
      if (allowed.contains(a.id) && !out.contains(a.id)) out.add(a.id);
    }
    // A catalog without enough ids cannot fill the wheel: fall back.
    if (out.length != slotCount) return defaults;
    return QuickAddWheel._(List.unmodifiable(out));
  }

  factory QuickAddWheel.decode(String? source, {Set<String>? catalog}) {
    if (source == null || source.isEmpty) return defaults;
    try {
      return QuickAddWheel.fromJson(jsonDecode(source), catalog: catalog);
    } on FormatException {
      return defaults;
    }
  }

  @override
  bool operator ==(Object other) => other is QuickAddWheel && _eq(other.slots, slots);

  @override
  int get hashCode => Object.hashAll(slots);

  @override
  String toString() => 'QuickAddWheel($slots)';
}
