import '../domain/adhkar_models.dart';
import '../domain/adhkar_session.dart';
import '../domain/adhkar_timing.dart';

/// How adhkar show up in the activity stream, which feeds the Faith planet's
/// `adhkar` score source (`OrbitRepository._practices` counts kinds
/// `adhkar` / `adhkar.*` per day).
abstract final class AdhkarActivity {
  /// The planet the entries belong to.
  static const String planetKey = 'faith';

  /// `refTable` of set completions (their `refId` is [refIdFor]).
  static const String refTable = 'adhkar';

  /// `refTable` of tasbeeh sessions (their `refId` is the session id).
  static const String tasbeehRefTable = 'tasbeeh';

  /// Kind of a finished set: `adhkar.morning`, `adhkar.afterPrayer` …
  static String kindFor(AdhkarCategoryId category) => 'adhkar.${category.name}';

  /// Kind of a tasbeeh session (value = the count).
  static const String tasbeehKind = 'adhkar.tasbeeh';

  /// One completion per set and day: `morning:2026-09-28`,
  /// `afterPrayer.fajr:2026-09-28`.
  static String refIdFor(AdhkarSetKey set, DateTime day) => '${set.storageKey}:${AdhkarTiming.dayKey(day)}';
}

/// Writes one activity entry (the default goes through the orbit's pulse
/// hub, so the Faith world pulses at once).
typedef AdhkarCompletionRecorder = Future<void> Function({
  required String kind,
  required String refTable,
  required String refId,
  required DateTime at,
  double? value,
  Map<String, Object?> payload,
});
