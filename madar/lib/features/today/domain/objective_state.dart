import 'dart:convert';

/// The three answers to the card: «تم», «بعدين», «تخطّي».
enum ObjectiveMarkKind { done, snoozed, skipped }

/// The lengths «بعدين» offers.
enum SnoozeOption {
  min15(Duration(minutes: 15)),
  min30(Duration(minutes: 30)),
  min60(Duration(minutes: 60));

  const SnoozeOption(this.duration);
  final Duration duration;
}

/// What the user answered to one objective on one day.
class ObjectiveMark {
  const ObjectiveMark({required this.id, required this.day, required this.kind, this.until});

  final String id;

  /// `yyyy-MM-dd` of the snapshot's day the answer was given on.
  final String day;
  final ObjectiveMarkKind kind;

  /// For [ObjectiveMarkKind.snoozed]: the moment it comes back.
  final DateTime? until;

  Map<String, Object?> toJson() => {
    'id': id,
    'day': day,
    'kind': kind.name,
    if (until != null) 'until': until!.toIso8601String(),
  };

  static ObjectiveMark? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final day = json['day'];
    final kindName = json['kind'];
    if (id is! String || id.isEmpty || day is! String || kindName is! String) return null;
    ObjectiveMarkKind? kind;
    for (final k in ObjectiveMarkKind.values) {
      if (k.name == kindName) kind = k;
    }
    if (kind == null) return null;
    DateTime? until;
    final u = json['until'];
    if (u is String) until = DateTime.tryParse(u);
    if (kind == ObjectiveMarkKind.snoozed && until == null) return null;
    return ObjectiveMark(id: id, day: day, kind: kind, until: until);
  }

  @override
  bool operator ==(Object other) =>
      other is ObjectiveMark && other.id == id && other.day == day && other.kind == kind && other.until == until;

  @override
  int get hashCode => Object.hash(id, day, kind, until);

  @override
  String toString() => 'ObjectiveMark($id, $day, ${kind.name}${until == null ? '' : ', until $until'})';
}

/// The user's answers to today's objectives, immutable and serialisable so a
/// skip or a snooze survives the app being closed.
///
/// Marks are kept by (id, day): a mark never leaks into another day, so
/// «تخطّي» clears a recurring item for today only and it is back tomorrow,
/// with no job needed to reset anything. [pruneBefore] only keeps the stored
/// JSON small.
class ObjectiveState {
  const ObjectiveState._(this._marks);

  const ObjectiveState.empty() : _marks = const {};

  /// Bumped when the JSON shape changes.
  static const int version = 1;

  final Map<String, ObjectiveMark> _marks;

  static String _key(String id, String day) => '$day|$id';

  /// `yyyy-MM-dd` of a local calendar day.
  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<ObjectiveMark> get marks {
    final out = _marks.values.toList()..sort((a, b) => _key(a.id, a.day).compareTo(_key(b.id, b.day)));
    return out;
  }

  bool get isEmpty => _marks.isEmpty;

  /// The answer to [id] on [day] (a `yyyy-MM-dd` key), if any.
  ObjectiveMark? markFor(String id, String day) => _marks[_key(id, day)];

  ObjectiveState _with(ObjectiveMark m) => ObjectiveState._({..._marks, _key(m.id, m.day): m});

  /// «تم».
  ObjectiveState markDone(String id, DateTime day) =>
      _with(ObjectiveMark(id: id, day: dayKey(day), kind: ObjectiveMarkKind.done));

  /// «بعدين»: hidden until [until] ([SnoozeOption.duration] after now).
  ObjectiveState snooze(String id, DateTime day, DateTime until) =>
      _with(ObjectiveMark(id: id, day: dayKey(day), kind: ObjectiveMarkKind.snoozed, until: until));

  /// «تخطّي»: hidden for the rest of [day].
  ObjectiveState skip(String id, DateTime day) =>
      _with(ObjectiveMark(id: id, day: dayKey(day), kind: ObjectiveMarkKind.skipped));

  /// Forgets the answer (the undo of any of the three).
  ObjectiveState clear(String id, DateTime day) {
    final k = _key(id, dayKey(day));
    if (!_marks.containsKey(k)) return this;
    return ObjectiveState._({..._marks}..remove(k));
  }

  /// Drops marks of days before [day].
  ObjectiveState pruneBefore(DateTime day) {
    final keep = dayKey(day);
    final next = {
      for (final e in _marks.entries)
        if (e.value.day.compareTo(keep) >= 0) e.key: e.value,
    };
    return next.length == _marks.length ? this : ObjectiveState._(next);
  }

  Map<String, Object?> toJson() => {
    'v': version,
    'marks': [for (final m in marks) m.toJson()],
  };

  String encode() => jsonEncode(toJson());

  /// Reads what [toJson] wrote. Never throws: anything malformed is dropped,
  /// so a corrupt value costs the user a forgotten skip, not a crash.
  factory ObjectiveState.fromJson(Object? json) {
    if (json is! Map) return const ObjectiveState.empty();
    final raw = json['marks'];
    if (raw is! List) return const ObjectiveState.empty();
    final map = <String, ObjectiveMark>{};
    for (final item in raw) {
      final m = ObjectiveMark.tryFromJson(item);
      if (m != null) map[_key(m.id, m.day)] = m;
    }
    return map.isEmpty ? const ObjectiveState.empty() : ObjectiveState._(map);
  }

  factory ObjectiveState.decode(String? source) {
    if (source == null || source.isEmpty) return const ObjectiveState.empty();
    try {
      return ObjectiveState.fromJson(jsonDecode(source));
    } on FormatException {
      return const ObjectiveState.empty();
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is! ObjectiveState || other._marks.length != _marks.length) return false;
    for (final e in _marks.entries) {
      if (other._marks[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(_marks.values);
}
