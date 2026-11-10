import 'package:flutter/foundation.dart' show listEquals;

import '../../../core/db/repositories/key_value_repository.dart';
import '../../wird/domain/calendar_days.dart';
import '../domain/fasting_log.dart';
import '../domain/fasting_models.dart';

/// «صيامي»'s three records in the encrypted `key_values` table - the same
/// place the Hajj round counter and the iqama settings live, so **no schema
/// change** and a backup carries them (it exports every table) and a restore
/// brings them back:
///
/// * `fastingReminders.config` - which kinds are on, the Shawwal start day;
/// * `fastingReminders.intentions` - his «ناوي» / «لأ», one per fasting day;
/// * `fastingReminders.log` - the days he fasted, one entry per day.
///
/// The Hijri shift is **not** stored here: it is the prayer settings'
/// `hijriOffsetDays` (one setting, never two). [saveConfig] writes 0 for it
/// and the app lays the prayer setting over the loaded config.
///
/// Every change is one read-modify-write inside a transaction, so the
/// notification button answered in the background isolate (its own database
/// connection) and the running app can never lose each other's write, and a
/// day always holds exactly one record.
class FastingRepository {
  FastingRepository(this.keyValues);

  static const String configKey = 'fastingReminders.config';
  static const String intentionsKey = 'fastingReminders.intentions';
  static const String logKey = 'fastingReminders.log';

  /// Answers older than this (before the newest one) are dropped when a new
  /// one is written - a year of history is plenty for "already answered".
  static const int keepIntentionDays = 400;

  final KeyValueRepository keyValues;

  // Config ------------------------------------------------------------------

  Future<FastingConfig> config() async => FastingConfig.fromJson(await _read(configKey));

  Stream<FastingConfig> watchConfig() => keyValues.watchJson(configKey).map(FastingConfig.fromJson).distinct();

  Future<void> saveConfig(FastingConfig config) =>
      keyValues.setJson(configKey, config.copyWith(hijriOffset: 0).toJson());

  // Intentions --------------------------------------------------------------

  Future<List<FastIntention>> intentions() async => _intentions(await _read(intentionsKey));

  Stream<List<FastIntention>> watchIntentions() =>
      keyValues.watchJson(intentionsKey).map(_intentions).distinct(listEquals);

  /// Records [intention] for its day (replacing that day's earlier answer).
  /// Returns what that day held before (null = nothing), for undo.
  Future<FastIntention?> setIntention(FastIntention intention) => keyValues.db.transaction(() async {
    final all = await intentions();
    final key = CalendarDays.key(intention.day);
    FastIntention? previous;
    for (final i in all) {
      if (CalendarDays.key(i.day) == key) previous = i;
    }
    if (previous == intention) return previous; // a double tap writes nothing new
    final floor = CalendarDays.add(intention.day, -keepIntentionDays);
    final next = [
      for (final i in all)
        if (CalendarDays.key(i.day) != key && !i.day.isBefore(floor)) i,
      intention,
    ]..sort((a, b) => a.day.compareTo(b.day));
    await keyValues.setJson(intentionsKey, [for (final i in next) i.toJson()]);
    return previous;
  });

  /// Removes the answer of [day] (undo of a first answer).
  Future<void> removeIntention(DateTime day) => keyValues.db.transaction(() async {
    final key = CalendarDays.key(day);
    final all = await intentions();
    final next = [
      for (final i in all)
        if (CalendarDays.key(i.day) != key) i,
    ];
    if (next.length != all.length) await keyValues.setJson(intentionsKey, [for (final i in next) i.toJson()]);
  });

  // Log ---------------------------------------------------------------------

  Future<List<FastLogEntry>> log() async => _log(await _read(logKey));

  Stream<List<FastLogEntry>> watchLog() => keyValues.watchJson(logKey).map(_log).distinct(listEquals);

  /// Records [entry] for its day (one entry per day). Returns what that day
  /// held before (null = nothing), for undo.
  Future<FastLogEntry?> setLogEntry(FastLogEntry entry) => keyValues.db.transaction(() async {
    final all = await log();
    final key = CalendarDays.key(entry.day);
    FastLogEntry? previous;
    for (final e in all) {
      if (CalendarDays.key(e.day) == key) previous = e;
    }
    if (previous == entry) return previous;
    final next = FastLogEntry.upsert(all, entry)..sort((a, b) => a.day.compareTo(b.day));
    await keyValues.setJson(logKey, [for (final e in next) e.toJson()]);
    return previous;
  });

  /// Removes the entry of [day]. Returns it (null = there was none).
  Future<FastLogEntry?> removeLogEntry(DateTime day) => keyValues.db.transaction(() async {
    final key = CalendarDays.key(day);
    final all = await log();
    FastLogEntry? removed;
    final next = <FastLogEntry>[];
    for (final e in all) {
      if (CalendarDays.key(e.day) == key) {
        removed = e;
      } else {
        next.add(e);
      }
    }
    if (removed != null) await keyValues.setJson(logKey, [for (final e in next) e.toJson()]);
    return removed;
  });

  // -------------------------------------------------------------------------

  /// A damaged value reads as "nothing stored", never as a crash.
  Future<Object?> _read(String key) async {
    try {
      return await keyValues.getJson(key);
    } on FormatException {
      return null;
    }
  }

  static List<FastIntention> _intentions(Object? json) => json is! List
      ? const []
      : [for (final e in json) ?FastIntention.fromJson(e)];

  static List<FastLogEntry> _log(Object? json) => json is! List
      ? const []
      : [for (final e in json) ?FastLogEntry.fromJson(e)];
}
