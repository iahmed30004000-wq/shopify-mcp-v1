import 'package:flutter/material.dart';

import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../orbit/domain/prayer_schedule.dart';
import '../../prayer/domain/prayer_clock.dart';
import '../../prayer/presentation/prayer_labels.dart' show prayerClockOf;
import '../domain/tracker_day.dart';
import '../domain/tracker_prayers.dart';
import '../domain/tracker_timing.dart';

/// Localised names and statuses of the tracker.
extension TrackerLabels on L10n {
  String trackerPrayerName(Prayer p) => switch (p) {
    Prayer.fajr => prayerFajr,
    Prayer.dhuhr => prayerDhuhr,
    Prayer.asr => prayerAsr,
    Prayer.maghrib => prayerMaghrib,
    Prayer.isha => prayerIsha,
    Prayer.sunnahFajr => trackerSunnahFajr,
    Prayer.sunnahDhuhr => trackerSunnahDhuhr,
    Prayer.sunnahMaghrib => trackerSunnahMaghrib,
    Prayer.sunnahIsha => trackerSunnahIsha,
    Prayer.duha => trackerDuha,
    Prayer.witr => trackerWitr,
    Prayer.qiyam => trackerQiyam,
  };

  String trackerStatusName(PrayerStatus s) => switch (s) {
    PrayerStatus.prayed => trackerStatusPrayed,
    PrayerStatus.late => trackerStatusLate,
    PrayerStatus.missed => trackerStatusMissed,
    PrayerStatus.qada => trackerStatusQada,
  };

  /// The status line of a tracked prayer.
  String trackerSlotStatus(TrackerSlot s) {
    final status = s.status;
    if (status != null) {
      return s.isObligatory || !status.counts ? trackerStatusName(status) : trackerStatusVoluntaryDone;
    }
    return switch (s.timing) {
      SlotTiming.upcoming => trackerStatusUpcoming,
      SlotTiming.open => s.isObligatory ? trackerStatusDue : trackerStatusVoluntaryOpen,
      SlotTiming.closed => trackerStatusUnlogged,
    };
  }

  /// "4 before, 2 after" for a sunnah rātibah (digits localised by [fmt]).
  String trackerRakahText(Prayer sunnah, MadarFormatter fmt) {
    final plan = TrackerPrayers.rakahOf(sunnah);
    if (plan == null) return '';
    final before = plan.before > 0 ? fmt.localizeDigits(trackerRakahBefore(plan.before)) : null;
    final after = plan.after > 0 ? fmt.localizeDigits(trackerRakahAfter(plan.after)) : null;
    if (before != null && after != null) return trackerRakahBoth(before, after);
    return before ?? after ?? '';
  }
}

/// Prayer times as the prayer-times screen and the adhan show them: the
/// location's wall clock (not the device's zone) on the user's 12- or
/// 24-hour prayer clock, in the formatter's digits.
@immutable
class TrackerClock {
  const TrackerClock(this._format, this._schedule);

  factory TrackerClock.of(BuildContext context, PrayerSchedule schedule) =>
      TrackerClock(prayerClockOf(context, schedule.settings), schedule);

  final PrayerClockFormat _format;
  final PrayerSchedule _schedule;

  /// "٣:٥١ م" / "15:51" of the instant [at].
  String call(DateTime at) => _format.format(_schedule.wallClock(at)).joined;
}

/// Icons of the tracker (one place, so rows, menus and cards agree).
abstract final class TrackerIcons {
  static const prayed = Icons.local_fire_department_rounded;
  static const late = Icons.history_rounded;
  static const missed = Icons.nights_stay_outlined;
  static const qada = Icons.replay_rounded;
  static const clear = Icons.undo_rounded;
  static const jamaah = Icons.groups_2_rounded;
  static const mosque = Icons.mosque_rounded;
  static const upcoming = Icons.schedule_rounded;
  static const streak = Icons.local_fire_department_rounded;

  static IconData of(Prayer p) => switch (p) {
    Prayer.fajr || Prayer.sunnahFajr => Icons.wb_twilight_rounded,
    Prayer.duha => Icons.wb_sunny_outlined,
    Prayer.dhuhr || Prayer.sunnahDhuhr => Icons.light_mode_rounded,
    Prayer.asr => Icons.wb_sunny_rounded,
    Prayer.maghrib || Prayer.sunnahMaghrib => Icons.wb_twilight_rounded,
    Prayer.isha || Prayer.sunnahIsha => Icons.nightlight_round,
    Prayer.witr => Icons.star_rounded,
    Prayer.qiyam => Icons.auto_awesome_rounded,
  };

  static IconData status(PrayerStatus s) => switch (s) {
    PrayerStatus.prayed => prayed,
    PrayerStatus.late => late,
    PrayerStatus.missed => missed,
    PrayerStatus.qada => qada,
  };
}
