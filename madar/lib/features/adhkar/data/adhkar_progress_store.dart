import 'dart:async';

import '../../../core/db/repositories/repositories.dart';
import '../domain/adhkar_session.dart';
import '../domain/adhkar_timing.dart';

/// Progress of every set, by day key (`yyyy-MM-dd`).
typedef AdhkarProgressDays = Map<String, Map<AdhkarSetKey, AdhkarProgress>>;

/// The reader's progress of the last few days, kept in the encrypted
/// key/value store under [key] as
/// `{"days": {"2026-09-28": {"morning": {…}, "afterPrayer.fajr": {…}}, "2026-09-29": {"waking": {…}}}}`.
///
/// Sets do not all share one day: the on-waking set said before Fajr belongs
/// to the coming day while the others still belong to the prayer day (see
/// `AdhkarTiming.dayFor`), so the [keepDays] most recent days are kept and
/// older ones dropped on the next save. Completions live on in the activity
/// log. The older one-day layout `{"day": …, "sets": {…}}` is still read.
class AdhkarProgressStore {
  AdhkarProgressStore(this.kv);

  static const String key = 'adhkar.progress';

  /// Days kept (older progress is of no use to the reader).
  static const int keepDays = 3;

  final KeyValueRepository kv;
  Future<void> _queue = Future.value();

  Future<AdhkarProgress?> load(DateTime day, AdhkarSetKey set) async => (await loadDay(day))[set];

  /// Every set's progress for [day].
  Future<Map<AdhkarSetKey, AdhkarProgress>> loadDay(DateTime day) async =>
      decode(await kv.getJson(key))[AdhkarTiming.dayKey(day)] ?? {};

  Stream<Map<AdhkarSetKey, AdhkarProgress>> watchDay(DateTime day) {
    final k = AdhkarTiming.dayKey(day);
    return kv.watchJson(key).map((j) => decode(j)[k] ?? {});
  }

  /// Every kept day.
  Stream<AdhkarProgressDays> watchDays() => kv.watchJson(key).map(decode);

  Future<void> save(DateTime day, AdhkarSetKey set, AdhkarProgress progress) => _serial(() async {
    final days = decode(await kv.getJson(key));
    (days[AdhkarTiming.dayKey(day)] ??= {})[set] = progress;
    await _write(days);
  });

  Future<void> remove(DateTime day, AdhkarSetKey set) => _serial(() async {
    final days = decode(await kv.getJson(key));
    if (days[AdhkarTiming.dayKey(day)]?.remove(set) != null) await _write(days);
  });

  Future<void> _serial(Future<void> Function() job) {
    final next = _queue.then((_) => job());
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _write(AdhkarProgressDays days) {
    final keys = days.keys.where((k) => days[k]!.isNotEmpty).toList()..sort((a, b) => b.compareTo(a));
    return kv.setJson(key, {
      'days': {
        for (final k in keys.take(keepDays)) k: {for (final e in days[k]!.entries) e.key.storageKey: e.value.toJson()},
      },
    });
  }

  /// Parses the stored JSON (tolerant: anything malformed reads as empty).
  static AdhkarProgressDays decode(Object? json) {
    if (json is! Map) return {};
    final out = <String, Map<AdhkarSetKey, AdhkarProgress>>{};
    final days = json['days'];
    if (days is Map) {
      for (final e in days.entries) {
        if (e.key is String) out[e.key as String] = _sets(e.value);
      }
    } else if (json['day'] is String) {
      out[json['day'] as String] = _sets(json['sets']);
    }
    return out;
  }

  static Map<AdhkarSetKey, AdhkarProgress> _sets(Object? raw) {
    if (raw is! Map) return {};
    return {
      for (final e in raw.entries)
        if (e.key is String && AdhkarSetKey.parse(e.key as String) != null)
          AdhkarSetKey.parse(e.key as String)!: AdhkarProgress.fromJson(e.value),
    };
  }
}
