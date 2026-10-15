/// When each tracked prayer can be logged: its window within the prayer day,
/// computed from the real prayer schedule. A prayer is *upcoming* before its
/// window opens (it cannot be logged yet), *open* while its time runs and
/// *closed* afterwards. Pure Dart.
library;

import 'package:flutter/foundation.dart' show immutable;

import '../../../core/domain/enums.dart';
import '../../orbit/domain/prayer_schedule.dart';

enum SlotTiming { upcoming, open, closed }

/// The span in which a prayer is performed (start inclusive, end exclusive).
@immutable
class SlotWindow {
  const SlotWindow(this.start, this.end);

  final DateTime start;
  final DateTime end;

  SlotTiming at(DateTime now) {
    if (now.isBefore(start)) return SlotTiming.upcoming;
    if (now.isBefore(end)) return SlotTiming.open;
    return SlotTiming.closed;
  }

  /// Time left until the window opens (zero once it has).
  Duration untilStart(DateTime now) => now.isBefore(start) ? start.difference(now) : Duration.zero;

  /// Time left until the window closes (zero once it has).
  Duration untilEnd(DateTime now) => now.isBefore(end) ? end.difference(now) : Duration.zero;

  @override
  bool operator ==(Object other) => other is SlotWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'SlotWindow($start → $end)';
}

abstract final class TrackerTiming {
  /// Duha begins once the sun has risen "a spear's length" – about a quarter
  /// of an hour after sunrise (praying right at sunrise is disliked).
  static const duhaDelay = Duration(minutes: 15);

  /// The window of [prayer] on the prayer day [day]; [nextDay] supplies the
  /// following Fajr, which ends the night (Isha, its sunnah, Witr, Qiyam).
  ///
  /// * Fajr and its sunnah: Fajr → sunrise.
  /// * Duha: sunrise + [duhaDelay] → Dhuhr.
  /// * Dhuhr and its sunnah: Dhuhr → Asr. Asr: Asr → Maghrib.
  /// * Maghrib and its sunnah: Maghrib → Isha.
  /// * Isha, its sunnah, Witr and Qiyam: Isha → the next Fajr.
  static SlotWindow windowOf(Prayer prayer, DayTimes day, DayTimes nextDay) => switch (prayer) {
    Prayer.fajr || Prayer.sunnahFajr => SlotWindow(day.fajr, day.sunrise),
    Prayer.duha => SlotWindow(day.sunrise.add(duhaDelay), day.dhuhr),
    Prayer.dhuhr || Prayer.sunnahDhuhr => SlotWindow(day.dhuhr, day.asr),
    Prayer.asr => SlotWindow(day.asr, day.maghrib),
    Prayer.maghrib || Prayer.sunnahMaghrib => SlotWindow(day.maghrib, day.isha),
    Prayer.isha || Prayer.sunnahIsha || Prayer.witr || Prayer.qiyam => SlotWindow(day.isha, nextDay.fajr),
  };

  /// The due time of [prayer] (the start of its window).
  static DateTime startOf(Prayer prayer, DayTimes day, DayTimes nextDay) => windowOf(prayer, day, nextDay).start;
}
