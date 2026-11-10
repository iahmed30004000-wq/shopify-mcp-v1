import 'package:flutter/foundation.dart' show listEquals;

import '../../../core/db/repositories/key_value_repository.dart';
import '../domain/khatmah_record.dart';
import '../domain/qadr_supplication.dart';
import '../domain/ramadan_config.dart';
import '../domain/ramadan_year_log.dart';
import '../domain/taraweeh_log.dart';

/// «رمضان»'s records in the encrypted `key_values` table - the same place the
/// fasting reminders and the iqama settings live, so **no schema change**, a
/// backup carries them (it exports every table) and a restore brings them back:
///
/// * `ramadan.config` - the atmosphere, which reminders are on and their lead;
/// * `ramadan.log` - every year's Ramadan log side by side (Taraweeh nights,
///   pages read), keyed by Hijri year, so this year can be read beside last;
/// * `ramadan.khatmah` - one khatmah plan and its progress per Hijri year;
/// * `ramadan.supplication` - the supplication he typed for the last ten
///   nights (text, source, grading);
/// * `ramadan.lastSeen` - the day the app last looked, so an opening after
///   days closed can tell it crossed the start or the Eid.
///
/// Every change is one read-modify-write inside a transaction, so the
/// Taraweeh button answered in the background isolate (its own database
/// connection) and the running app can never lose each other's write.
class RamadanRepository {
  RamadanRepository(this.keyValues);

  static const String configKey = 'ramadan.config';
  static const String logKey = 'ramadan.log';
  static const String khatmahKey = 'ramadan.khatmah';
  static const String supplicationKey = 'ramadan.supplication';
  static const String lastSeenKey = 'ramadan.lastSeen';

  final KeyValueRepository keyValues;

  // Config ------------------------------------------------------------------

  Future<RamadanConfig> config() async => RamadanConfig.fromJson(await _read(configKey));

  Stream<RamadanConfig> watchConfig() => keyValues.watchJson(configKey).map(RamadanConfig.fromJson).distinct();

  Future<void> saveConfig(RamadanConfig config) => keyValues.setJson(configKey, config.toJson());

  // Log ---------------------------------------------------------------------

  Future<RamadanLogBook> logBook() async => RamadanLogBook.fromJson(await _read(logKey));

  Stream<RamadanLogBook> watchLogBook() => keyValues.watchJson(logKey).map(RamadanLogBook.fromJson).distinct();

  /// Sets night [night] of [hijriYear] to [entry]; null removes the night.
  /// Returns what the night held before (null = nothing), for undo.
  Future<TaraweehEntry?> setTaraweeh(int hijriYear, int night, TaraweehEntry? entry) =>
      keyValues.db.transaction(() async {
        final book = await logBook();
        final year = book.ofOrEmpty(hijriYear);
        final previous = year.taraweeh.entryOf(night);
        if (previous == entry) return previous;
        final entries = [
          for (final e in year.taraweeh.entries.values)
            if (e.night != night) e,
          ?entry,
        ];
        await _saveBook(book.withYear(year.copyWith(taraweeh: TaraweehLog(entries))));
        return previous;
      });

  /// What the notification's «صلّيت» does: night [night] is done. Idempotent -
  /// a double tap, or a night already logged with a rakaat count, changes
  /// nothing. True when this call wrote the night.
  Future<bool> markTaraweehDone(int hijriYear, int night) => keyValues.db.transaction(() async {
    final book = await logBook();
    final year = book.ofOrEmpty(hijriYear);
    final existing = year.taraweeh.entryOf(night);
    if (existing != null && existing.done) return false;
    final next = existing == null ? TaraweehEntry(night: night) : existing.copyWith(done: true);
    await _saveBook(book.withYear(year.copyWith(taraweeh: year.taraweeh.withEntry(next))));
    return true;
  });

  /// Replaces [hijriYear]'s whole log (undo of a bigger change). Returns the old one.
  Future<RamadanYearLog?> setYearLog(RamadanYearLog log) => keyValues.db.transaction(() async {
    final book = await logBook();
    final previous = book.of(log.hijriYear);
    await _saveBook(book.withYear(log));
    return previous;
  });

  Future<void> _saveBook(RamadanLogBook book) => keyValues.setJson(logKey, book.toJson());

  // Khatmah -----------------------------------------------------------------

  Future<Map<int, KhatmahRecord>> khatmahs() async => _khatmahs(await _read(khatmahKey));

  Stream<Map<int, KhatmahRecord>> watchKhatmahs() =>
      keyValues.watchJson(khatmahKey).map(_khatmahs).distinct(_sameKhatmahs);

  /// Stores [record] (replacing its year's) and keeps that year's log in step:
  /// the pages read in the month are the plan's frontier. One transaction.
  /// Returns what the year held before (null = nothing stored), for undo.
  Future<KhatmahRecord?> setKhatmah(KhatmahRecord record) => keyValues.db.transaction(() async {
    final all = await khatmahs();
    final previous = all[record.hijriYear];
    if (previous == record) return previous;
    await _saveKhatmahs({...all, record.hijriYear: record});
    await _syncPagesRead(record.hijriYear, record.progress.frontier);
    return previous;
  });

  /// Puts [previous] back as [hijriYear]'s record (null = nothing stored).
  Future<void> restoreKhatmah(int hijriYear, KhatmahRecord? previous) => keyValues.db.transaction(() async {
    final all = await khatmahs();
    if (previous == null) {
      all.remove(hijriYear);
      await _saveKhatmahs(all);
      await _syncPagesRead(hijriYear, 0);
    } else {
      await _saveKhatmahs({...all, hijriYear: previous});
      await _syncPagesRead(hijriYear, previous.progress.frontier);
    }
  });

  Future<void> _syncPagesRead(int hijriYear, int pages) async {
    final book = await logBook();
    final year = book.of(hijriYear);
    if (year == null && pages == 0) return;
    final current = year ?? book.ofOrEmpty(hijriYear);
    if (current.pagesRead == pages) return;
    await _saveBook(book.withYear(current.copyWith(pagesRead: pages)));
  }

  Future<void> _saveKhatmahs(Map<int, KhatmahRecord> all) =>
      keyValues.setJson(khatmahKey, [for (final y in all.keys.toList()..sort()) all[y]!.toJson()]);

  // Supplication ------------------------------------------------------------

  Future<QadrSupplication?> supplication() async => QadrSupplication.fromJson(await _read(supplicationKey));

  Stream<QadrSupplication?> watchSupplication() =>
      keyValues.watchJson(supplicationKey).map(QadrSupplication.fromJson).distinct();

  /// Stores what he typed; null clears it. Returns the previous one, for undo.
  Future<QadrSupplication?> saveSupplication(QadrSupplication? value) async {
    final previous = await supplication();
    if (previous == value) return previous;
    if (value == null) {
      await keyValues.remove(supplicationKey);
    } else {
      await keyValues.setJson(supplicationKey, value.toJson());
    }
    return previous;
  }

  // Last seen ---------------------------------------------------------------

  Future<DateTime?> lastSeen() async {
    final v = await _read(lastSeenKey);
    return v is String ? DateTime.tryParse(v) : null;
  }

  Future<void> setLastSeen(DateTime day) => keyValues.setJson(lastSeenKey, _key(day));

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // -------------------------------------------------------------------------

  /// A damaged value reads as "nothing stored", never as a crash.
  Future<Object?> _read(String key) async {
    try {
      return await keyValues.getJson(key);
    } on FormatException {
      return null;
    }
  }

  static Map<int, KhatmahRecord> _khatmahs(Object? json) {
    final out = <int, KhatmahRecord>{};
    if (json is List) {
      for (final e in json) {
        final r = KhatmahRecord.fromJson(e);
        if (r != null) out[r.hijriYear] = r;
      }
    }
    return out;
  }

  static bool _sameKhatmahs(Map<int, KhatmahRecord> a, Map<int, KhatmahRecord> b) =>
      a.length == b.length && listEquals(a.values.toList(), b.values.toList());
}
