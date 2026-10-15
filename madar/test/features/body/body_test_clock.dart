import 'package:madar/features/body/body.dart';

/// A time zone with one offset change at [transition] (UTC): [before] hours
/// east of UTC until then, [after] from then on. Instants are UTC; days are
/// plain local-midnight `DateTime`s like the app's.
///
/// Spring forward (+2 → +3 at 00:00 local): 00:00–00:59 do not exist and
/// resolve forward. Fall back (+3 → +2 at 01:00 local): 00:00–00:59 happen
/// twice; the first occurrence wins.
class FakeZoneClock implements BodyWallClock {
  const FakeZoneClock({required this.transition, required this.before, required this.after});

  /// Europe-like spring forward on Friday 26 March 2027 (the night of
  /// 25 → 26 March loses an hour).
  factory FakeZoneClock.spring() =>
      FakeZoneClock(transition: DateTime.utc(2027, 3, 25, 22), before: 2, after: 3);

  /// Fall back on Friday 29 October 2027 (that night gains an hour).
  factory FakeZoneClock.fall() => FakeZoneClock(transition: DateTime.utc(2027, 10, 28, 22), before: 3, after: 2);

  /// A fixed +3 zone (Amman) with no change.
  factory FakeZoneClock.fixed(int hours) =>
      FakeZoneClock(transition: DateTime.utc(3000), before: hours, after: hours);

  final DateTime transition;
  final int before;
  final int after;

  Duration offsetAt(DateTime instant) =>
      Duration(hours: instant.toUtc().isBefore(transition) ? before : after);

  @override
  DateTime at(DateTime day, int minutes) {
    final naive = DateTime.utc(day.year, day.month, day.day).add(Duration(minutes: minutes));
    final first = naive.subtract(Duration(hours: before));
    if (first.isBefore(transition)) return first;
    final second = naive.subtract(Duration(hours: after));
    if (!second.isBefore(transition)) return second;
    // Skipped by a spring-forward: resolve forward.
    return first;
  }

  @override
  DateTime dayOf(DateTime instant) {
    final local = instant.toUtc().add(offsetAt(instant));
    return DateTime(local.year, local.month, local.day);
  }

  /// The local wall time of [instant] as "HH:mm".
  String wall(DateTime instant) {
    final local = instant.toUtc().add(offsetAt(instant));
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
