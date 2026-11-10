import 'package:flutter/foundation.dart';

/// One night of Taraweeh (night 1…30; see `LastTenNights` for the numbering).
@immutable
class TaraweehEntry {
  const TaraweehEntry({required this.night, this.done = true, this.rakaat, this.note});

  factory TaraweehEntry.fromJson(Map<String, dynamic> json) => TaraweehEntry(
    night: json['night'] is int ? json['night'] as int : 0,
    done: json['done'] != false,
    rakaat: json['rakaat'] is int && (json['rakaat'] as int) >= 0 ? json['rakaat'] as int : null,
    note: json['note'] is String && (json['note'] as String).isNotEmpty ? json['note'] as String : null,
  );

  final int night;
  final bool done;

  /// How many rakaat, when he wants to say (optional).
  final int? rakaat;
  final String? note;

  TaraweehEntry copyWith({bool? done, int? rakaat, String? note, bool clearRakaat = false, bool clearNote = false}) =>
      TaraweehEntry(
        night: night,
        done: done ?? this.done,
        rakaat: clearRakaat ? null : (rakaat ?? this.rakaat),
        note: clearNote ? null : (note ?? this.note),
      );

  Map<String, dynamic> toJson() => {
    'night': night,
    'done': done,
    if (rakaat != null) 'rakaat': rakaat,
    if (note != null) 'note': note,
  };

  @override
  bool operator ==(Object other) =>
      other is TaraweehEntry &&
      other.night == night &&
      other.done == done &&
      other.rakaat == rakaat &&
      other.note == note;

  @override
  int get hashCode => Object.hash(night, done, rakaat, note);
}

/// The Taraweeh of one Ramadan, by night.
@immutable
class TaraweehLog {
  TaraweehLog([Iterable<TaraweehEntry> entries = const []])
    : entries = Map.unmodifiable({
        for (final e in entries)
          if (e.night >= 1 && e.night <= maxNights) e.night: e,
      });

  factory TaraweehLog.fromJson(Object? json) {
    final list = json is Map ? json['entries'] : json;
    if (list is! List) return TaraweehLog();
    return TaraweehLog([
      for (final e in list)
        if (e is Map<String, dynamic>) TaraweehEntry.fromJson(e),
    ]);
  }

  static const int maxNights = 30;

  final Map<int, TaraweehEntry> entries;

  TaraweehEntry? entryOf(int night) => entries[night];

  bool isDone(int night) => entries[night]?.done ?? false;

  /// Nights prayed.
  int get nightsPrayed => entries.values.where((e) => e.done).length;

  /// Sum of the rakaat he wrote down (nights without a count add nothing).
  int get totalRakaat => entries.values.where((e) => e.done).fold(0, (a, e) => a + (e.rakaat ?? 0));

  /// Sets or replaces a night (ignored outside 1…30). Returns the new log;
  /// keep the old one to undo.
  TaraweehLog withEntry(TaraweehEntry entry) {
    if (entry.night < 1 || entry.night > maxNights) return this;
    return TaraweehLog([...entries.values.where((e) => e.night != entry.night), entry]);
  }

  /// The one-tap button: marks the night done, or un-marks it when it already
  /// was (a note or rakaat count already written is kept).
  TaraweehLog toggle(int night) {
    final e = entries[night];
    if (e == null) return withEntry(TaraweehEntry(night: night));
    return withEntry(e.copyWith(done: !e.done));
  }

  Map<String, dynamic> toJson() => {
    'entries': [for (final n in entries.keys.toList()..sort()) entries[n]!.toJson()],
  };

  @override
  bool operator ==(Object other) => other is TaraweehLog && mapEquals(other.entries, entries);

  @override
  int get hashCode => Object.hashAll([for (final n in entries.keys.toList()..sort()) entries[n]]);
}
