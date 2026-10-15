import 'package:flutter/foundation.dart';

import '../../../core/i18n/formatters.dart';

/// A prayer time split for typography: the clock digits and the day-period
/// word shown smaller beside them ("٤:٥٢" + "ص", "4:52" + "AM").
@immutable
class PrayerClockText {
  const PrayerClockText(this.clock, this.period);

  final String clock;

  /// Null on a 24-hour clock.
  final String? period;

  /// Clock and period as one string ("٤:٥٢ ص" / "4:52 AM").
  String get joined => period == null ? clock : '$clock\u00A0$period';

  @override
  String toString() => joined;
}

/// Formats wall-clock times of prayers on a 12- or 24-hour clock, in the
/// formatter's digits (Arabic-Indic in Arabic by default).
///
/// The period words come from the caller (localised strings), so this stays
/// pure: `PrayerClockFormat(fmt, h24: false, am: l.ptAm, pm: l.ptPm)`.
@immutable
class PrayerClockFormat {
  const PrayerClockFormat(this.formatter, {required this.h24, required this.am, required this.pm});

  final MadarFormatter formatter;
  final bool h24;
  final String am;
  final String pm;

  /// [wallClock] is read by its hour and minute (pass a location wall-clock
  /// time, e.g. `PrayerSchedule.wallClock`).
  PrayerClockText format(DateTime wallClock) => formatHm(wallClock.hour, wallClock.minute);

  PrayerClockText formatHm(int hour, int minute) {
    final mm = minute.toString().padLeft(2, '0');
    if (h24) {
      return PrayerClockText(formatter.localizeDigits('${hour.toString().padLeft(2, '0')}:$mm'), null);
    }
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return PrayerClockText(formatter.localizeDigits('$h:$mm'), hour < 12 ? am : pm);
  }

  /// A countdown `h:mm:ss` (or `m:ss` under an hour) in the formatter's
  /// digits, forced left-to-right so it never reorders in Arabic.
  String countdown(Duration d) {
    final v = d.isNegative ? Duration.zero : d;
    final h = v.inHours;
    final m = v.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = v.inSeconds.remainder(60).toString().padLeft(2, '0');
    final raw = h > 0 ? '$h:$m:$s' : '${v.inMinutes}:$s';
    return BidiIsolate.ltr(formatter.localizeDigits(raw));
  }
}
