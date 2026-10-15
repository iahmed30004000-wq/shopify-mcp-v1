import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import 'adhkar_models.dart';

/// The night of a prayer day: from its Maghrib to the next Fajr (where the
/// next prayer day begins).
@immutable
class AdhkarNight {
  const AdhkarNight({required this.maghrib, required this.fajr});

  final DateTime maghrib;

  /// The next day's Fajr.
  final DateTime fajr;

  Duration get length => fajr.difference(maghrib);

  /// The middle of the night (Islamic midnight).
  DateTime get midpoint => maghrib.add(length ~/ 2);

  /// The start of the last third of the night (the time of Qiyam).
  DateTime get lastThird => maghrib.add(length * 2 ~/ 3);

  @override
  bool operator ==(Object other) => other is AdhkarNight && other.maghrib == maghrib && other.fajr == fajr;

  @override
  int get hashCode => Object.hash(maghrib, fajr);
}

/// Which set fits the moment, and which day a set's progress belongs to.
abstract final class AdhkarTiming {
  /// The set to suggest in [window]: morning adhkar from Fajr until Dhuhr,
  /// the after-prayer set at Dhuhr, evening adhkar from Asr until Isha and
  /// the sleep adhkar after Isha.
  static AdhkarCategoryId suggested(PrayerWindow window) => switch (window) {
    PrayerWindow.fajr || PrayerWindow.duha => AdhkarCategoryId.morning,
    PrayerWindow.dhuhr => AdhkarCategoryId.afterPrayer,
    PrayerWindow.asr || PrayerWindow.maghrib => AdhkarCategoryId.evening,
    PrayerWindow.isha => AdhkarCategoryId.sleep,
    PrayerWindow.anytime => AdhkarCategoryId.morning,
  };

  /// The set to suggest at [now], which is in [window] of the prayer day
  /// whose night is [night]:
  /// * by the window ([suggested]), except that late in the night – past
  ///   its middle once the sleep adhkar were said, or in its last third –
  ///   it is the on-waking set;
  /// * when that (morning, evening or sleep) set is already done but the
  ///   adhkar after the prayer just due ([lastPrayer]) are not, those
  ///   instead.
  ///
  /// [isDone] tells whether a set (the after-prayer set: after that prayer)
  /// was finished on its day.
  static AdhkarCategoryId suggestAt({
    required PrayerWindow window,
    required DateTime now,
    required AdhkarNight night,
    required bool Function(AdhkarCategoryId category, Prayer? prayer) isDone,
  }) {
    var primary = suggested(window);
    if (window == PrayerWindow.isha && !now.isBefore(night.midpoint)) {
      final wake = !now.isBefore(night.lastThird) || isDone(AdhkarCategoryId.sleep, null);
      if (wake) primary = AdhkarCategoryId.waking;
    }
    final prayer = lastPrayer(window);
    const fallsBack = {AdhkarCategoryId.morning, AdhkarCategoryId.evening, AdhkarCategoryId.sleep};
    // (Not in the forenoon: Fajr's own adhkar belong right after it.)
    if (fallsBack.contains(primary) &&
        window != PrayerWindow.anytime &&
        window != PrayerWindow.duha &&
        isDone(primary, null) &&
        !isDone(AdhkarCategoryId.afterPrayer, prayer)) {
      return AdhkarCategoryId.afterPrayer;
    }
    return primary;
  }

  /// The obligatory prayer most recently due in [window] (whose after-prayer
  /// adhkar apply now).
  static Prayer lastPrayer(PrayerWindow window) => switch (window) {
    PrayerWindow.fajr || PrayerWindow.duha || PrayerWindow.anytime => Prayer.fajr,
    PrayerWindow.dhuhr => Prayer.dhuhr,
    PrayerWindow.asr => Prayer.asr,
    PrayerWindow.maghrib => Prayer.maghrib,
    PrayerWindow.isha => Prayer.isha,
  };

  /// The day the on-waking adhkar said at [now] belong to. Every other set
  /// follows the prayer day ([prayerDay], which starts at Fajr, so sleep
  /// adhkar said after midnight still count for the evening before); waking
  /// before Fajr – for the night prayer or for Fajr itself – is the start
  /// of the coming day, so from the middle of the night on the on-waking set
  /// belongs to the next day.
  static DateTime wakingDay(DateTime prayerDay, DateTime now, AdhkarNight night) =>
      now.isBefore(night.midpoint) ? prayerDay : DateTime(prayerDay.year, prayerDay.month, prayerDay.day + 1);

  /// The day [category]'s progress at [now] belongs to.
  static DateTime dayFor(AdhkarCategoryId category, DateTime prayerDay, DateTime now, AdhkarNight night) =>
      category == AdhkarCategoryId.waking ? wakingDay(prayerDay, now, night) : prayerDay;

  /// The next moment at which the day or the suggestion can change after
  /// [now]: the end of the current prayer window ([windowEnd]), the night's
  /// middle and last third, or local midnight – whichever comes first.
  static DateTime nextBoundary(DateTime now, {required DateTime windowEnd, required AdhkarNight night}) {
    final midnight = DateTime(now.year, now.month, now.day + 1);
    var next = midnight;
    for (final t in [windowEnd, night.midpoint, night.lastThird]) {
      if (t.isAfter(now) && t.isBefore(next)) next = t;
    }
    return next;
  }

  /// `yyyy-MM-dd` of a local calendar day.
  static String dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  /// Local midnight of [t].
  static DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);
}
