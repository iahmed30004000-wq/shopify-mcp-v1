import 'package:timezone/timezone.dart' as tz;

import '../../../core/domain/enums.dart';
import '../../orbit/domain/prayer_schedule.dart';
import '../../prayer/application/prayer_providers.dart' show hijriAt;
import '../../prayer/domain/prayer_clock.dart';
import '../../prayer/presentation/prayer_labels.dart';
import 'widget_build.dart';
import 'widget_kind.dart';
import 'widget_links.dart';
import 'widget_snapshot.dart';
import 'widget_texts.dart';

/// The next-prayer widget's snapshot (pure): one page per window of the
/// next [PrayerWidgetBuilder.horizonDays] location days – each prayer time
/// and each midnight starts a page – so the widget moves on to the next
/// prayer by itself, its countdown ticking in Android.
///
/// A page: the next prayer's name (Jumuʿah on Fridays), its time on the
/// user's 12 / 24-hour clock, the countdown to it, the Hijri date (with the
/// user's offset and Maghrib rollover) and, with details shown, the
/// location's name. The images: one mini astrolabe per prayer, lit on it,
/// drawn from today's times.
abstract final class PrayerWidgetBuilder {
  static const int horizonDays = 3;

  static WidgetBuild build({
    required PrayerSchedule schedule,
    required DateTime now,
    required WidgetTexts texts,
    required bool details,
    int days = horizonDays,
  }) {
    final settings = schedule.settings;
    final today = schedule.dateOf(now);
    final until = locationMidnight(schedule, DateTime(today.year, today.month, today.day + days));
    final starts = <DateTime>[];
    for (var i = 0; i < days; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      for (final (_, at) in schedule.timesFor(day).obligatory) {
        starts.add(at);
      }
      if (i > 0) starts.add(locationMidnight(schedule, day));
    }
    starts
      ..removeWhere((s) => !s.isAfter(now) || !s.isBefore(until))
      ..sort();

    final clock = PrayerClockFormat(texts.fmt, h24: settings.clock24h, am: texts.l.ptAm, pm: texts.l.ptPm);
    final place = details ? settings.placeName(texts.languageCode)?.trim() : null;

    WidgetPage page(DateTime? from, DateTime at) {
      final w = schedule.windowAt(at);
      final wall = schedule.wallClock(w.nextPrayerAt);
      final hijri = texts.l.hijriDate(hijriAt(schedule, settings, at), texts.fmt);
      return WidgetPage(
        from: from,
        headline: texts.l.prayerName(w.nextPrayer, friday: wall.weekday == DateTime.friday),
        detail: clock.format(wall).joined,
        note: place == null || place.isEmpty ? hijri : texts.l.widgetsPrayerNotePlace(hijri, texts.name(place)),
        countdownTo: w.nextPrayerAt,
        countdownFormat: texts.l.widgetsCountdown('%s'),
        image: imageKey(w.nextPrayer),
      );
    }

    final pages = [page(null, now), for (final s in starts) page(s, s)];
    return WidgetBuild(
      WidgetSnapshot(
        kind: MadarWidgetKind.prayer,
        languageCode: texts.languageCode,
        private: !details,
        title: texts.title(MadarWidgetKind.prayer),
        until: until,
        stale: texts.stale,
        link: WidgetLinks.prayer,
        pages: pages,
      ),
      images: imagesFor(schedule, today, keys: {for (final p in pages) ?p.image}),
    );
  }

  /// `astro_<prayer>`.
  static String imageKey(Prayer p) => 'astro_${p.name}';

  /// The astrolabes of [day]'s times, lit on each prayer in [keys].
  static Map<String, MiniAstrolabeSpec> imagesFor(PrayerSchedule schedule, DateTime day, {required Set<String> keys}) {
    final t = schedule.timesFor(day);
    double f(DateTime at) => PrayerSchedule.dialFraction(schedule.wallClock(at));
    final out = <String, MiniAstrolabeSpec>{};
    const order = [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];
    for (var i = 0; i < order.length; i++) {
      final key = imageKey(order[i]);
      if (!keys.contains(key)) continue;
      out[key] = MiniAstrolabeSpec(
        fajr: f(t.fajr),
        sunrise: f(t.sunrise),
        dhuhr: f(t.dhuhr),
        asr: f(t.asr),
        maghrib: f(t.maghrib),
        isha: f(t.isha),
        next: i,
      );
    }
    return out;
  }

  /// The instant the location's calendar day [date] begins.
  static DateTime locationMidnight(PrayerSchedule schedule, DateTime date) {
    final zone = schedule.zone;
    if (zone == null) return DateTime(date.year, date.month, date.day);
    return tz.TZDateTime(zone, date.year, date.month, date.day);
  }
}
