import 'package:flutter/foundation.dart';

import 'fast_countdown.dart';
import 'last_ten_nights.dart';
import 'prayer_times_of.dart';
import 'ramadan_calendar.dart';

/// Where Ramadan stands right now: the one value the Faith card, the
/// atmosphere and the Ramadan screen read.
///
/// Pure: the same inputs always give the same answer, so a frozen test clock,
/// a traveller's new prayer times or a phone clock changed by hand are just
/// different inputs.
@immutable
class RamadanToday {
  const RamadanToday({
    required this.date,
    required this.status,
    required this.span,
    required this.nightNow,
    required this.tonight,
    required this.countdown,
  });

  /// How many days before Ramadan the "countdown to Ramadan" card appears.
  static const int countdownWindowDays = 30;

  /// [now] may be a zone-aware wall-clock time (`PrayerSchedule.wallClock`):
  /// its y/m/d pick the civil day, comparisons are by instant.
  factory RamadanToday.compute({
    required DateTime now,
    required RamadanCalendar calendar,
    required PrayerTimesOf timesOf,
  }) {
    final date = civilDay(now);
    final status = calendar.statusOn(date);
    final nightNow = calendar.nightAt(now, timesOf);
    // Night 1 begins at the Maghrib of the day before the first: that evening
    // is already Ramadan's, though the calendar day still is not.
    final span = status.isRamadan
        ? calendar.spanContaining(date)
        : (nightNow != null ? calendar.nextSpanAfter(date) : null);
    return RamadanToday(
      date: date,
      status: status,
      span: span,
      nightNow: nightNow,
      tonight: nightNow ?? calendar.dayOfRamadan(addCivilDays(date, 1)),
      countdown: FastCountdown.compute(now: now, timesOf: timesOf, calendar: calendar),
    );
  }

  /// The civil day.
  final DateTime date;
  final RamadanStatus status;

  /// The Ramadan being lived (null outside it).
  final RamadanSpan? span;

  /// The night in progress (Maghrib to Fajr), if any.
  final int? nightNow;

  /// The night whose Taraweeh is the next one to pray (or being prayed): the
  /// night in progress, or the one that begins this evening. Null when the
  /// coming evening is not a Ramadan night.
  final int? tonight;

  /// Iftar / end of suhoor, with the time left.
  final FastCountdown countdown;

  /// In Ramadan by the calendar day, or in its first night.
  bool get inRamadan => span != null;

  /// 1…30 by the calendar day; null on the first night before the first day.
  int? get dayOfRamadan => status.dayOfRamadan;

  /// The Hijri year of the Ramadan being lived.
  int? get hijriYear => span?.hijriYear;

  int get monthLength => span?.length ?? 30;

  /// The number to name the moment with: the day, or night 1 before day 1.
  int? get headlineNumber => dayOfRamadan ?? nightNow;

  /// The last-ten-nights strip applies tonight.
  bool get lastTenTonight => inRamadan && tonight != null && LastTenNights.isLastTen(tonight!, monthLength: monthLength);

  /// Whether the "countdown to Ramadan" card shows (the last 30 days).
  bool get comingSoon =>
      !inRamadan && status.daysUntilNextRamadan >= 1 && status.daysUntilNextRamadan <= countdownWindowDays;

  int get daysUntilRamadan => status.daysUntilNextRamadan;
}
