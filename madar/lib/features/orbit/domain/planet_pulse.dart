import 'package:flutter/foundation.dart';

/// Where a [PlanetPulse] came from.
enum PulseOrigin {
  /// Logged through the orbit's completion hook (instant).
  recorded,

  /// Seen in the activity stream (logged by any other feature, e.g. a task
  /// completed on home).
  observed,
}

/// "Something was just done for this planet": the scene answers with a
/// `uPulse` burst on the world, particles and a chime.
@immutable
class PlanetPulse {
  const PlanetPulse({
    required this.planetKey,
    required this.kind,
    required this.at,
    this.refTable,
    this.refId,
    this.count = 1,
    this.origin = PulseOrigin.recorded,
    this.activityId,
  });

  final String planetKey;

  /// Activity kind, e.g. `task.done`, `prayer.logged`, `dose.taken`.
  final String kind;
  final DateTime at;
  final String? refTable;
  final String? refId;

  /// Completions coalesced into this pulse (a batch for one planet).
  final int count;
  final PulseOrigin origin;

  /// The `activity_log` row behind it.
  final String? activityId;

  /// Prayer completions ignite the astrolabe pointers (`Sfx.prayerLit`).
  bool get isPrayer => kind.startsWith('prayer');

  @override
  String toString() => 'PlanetPulse($planetKey, $kind, ×$count, ${origin.name})';
}
