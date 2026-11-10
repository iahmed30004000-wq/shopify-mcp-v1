// Shared fixtures of the prayer tracker tests: an app shell around a
// tracker widget (real theme, locale, motion scope, celebration overlay),
// prayer times that look like Amman's on any host, and a seeded history.
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/orbit/data/orbit_providers.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer_tracker/data/tracker_providers.dart';
import 'package:madar/features/prayer_tracker/domain/tracker_days.dart';
import 'package:madar/features/prayer_tracker/domain/tracker_prayers.dart';

/// Prayer settings whose local times look like Amman's on any host
/// (Amman's latitude; a longitude matching the host's UTC offset).
PrayerSettings hostPrayerSettings() {
  final offset = DateTime(2026, 9, 28, 12).timeZoneOffset.inMinutes / 60;
  if (offset == 3) return const PrayerSettings();
  return PrayerSettings(longitude: offset * 15 - 9.09);
}

PrayerSchedule hostSchedule() => PrayerSchedule(hostPrayerSettings());

/// The fixed "today" of the tracker tests.
final DateTime trackerDay = DateTime(2026, 9, 28);

/// [trackerDay]'s prayer times on this host.
DayTimes trackerTimes([PrayerSchedule? schedule]) => (schedule ?? hostSchedule()).timesFor(trackerDay);

/// A moment in the Asr window of [trackerDay] (Fajr, Dhuhr, Asr due;
/// Maghrib and Isha still to come).
DateTime afterAsr([PrayerSchedule? schedule]) => trackerTimes(schedule).asr.add(const Duration(minutes: 25));

/// Overrides that pin the tracker to [db], [now] and [schedule].
List<Override> trackerOverrides({required MadarDatabase db, required DateTime now, PrayerSchedule? schedule}) {
  final s = schedule ?? hostSchedule();
  return [
    databaseProvider.overrideWithValue(db),
    homeClockProvider.overrideWithValue(() => now),
    trackerNowProvider.overrideWithValue(now),
    prayerScheduleProvider.overrideWithValue(s),
  ];
}

/// A MaterialApp like the real one (theme, locale, digit scope, motion
/// scope, celebration overlay) around [home].
Widget trackerTestApp({
  required Widget home,
  required List<Override> overrides,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  bool reducedMotion = false,
  Color? accent,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMadarTheme(theme, customAccent: accent, arabic: locale.languageCode == 'ar'),
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      builder: (context, child) => MadarFormatScope(
        digits: DigitStyle.auto,
        child: MotionScope(
          reduced: reducedMotion,
          child: CelebrationOverlay(child: child!),
        ),
      ),
      home: home,
    ),
  );
}

/// Inserts one prayer log.
Future<PrayerLogRow> addLog(
  Repositories repos,
  DateTime day,
  Prayer prayer,
  PrayerStatus status, {
  bool jamaah = false,
  bool mosque = false,
  DateTime? loggedAt,
}) => repos.prayerLogs.insert(
  PrayerLogsCompanion.insert(
    day: TrackerDays.key(day),
    prayer: prayer,
    status: Value(status),
    inJamaah: Value(jamaah),
    atMosque: Value(mosque),
    loggedAt: Value(loggedAt ?? day.add(const Duration(hours: 12))),
  ),
);

/// A believable month of history before [today] (deterministic): mostly
/// complete days, some late or in jamaah / at the mosque, a few missed
/// (some made up), rawatib, Duha, Witr and a little Qiyam. [today] itself
/// gets Fajr in jamaah, Dhuhr at the mosque and their sunnah.
Future<void> seedHistory(Repositories repos, DateTime today, {int days = 40}) async {
  final rnd = math.Random(7);
  const fard = [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];
  for (var i = days; i >= 1; i--) {
    final day = TrackerDays.add(today, -i);
    // A gap day with nothing logged, to break a streak mid-month.
    if (i == 17) continue;
    for (final p in fard) {
      final r = rnd.nextDouble();
      final status = switch (r) {
        < 0.06 => PrayerStatus.missed,
        < 0.09 => PrayerStatus.qada,
        < 0.2 => PrayerStatus.late,
        _ => PrayerStatus.prayed,
      };
      // The last 9 days are all complete (a current streak).
      final s = i <= 9 && status == PrayerStatus.missed ? PrayerStatus.prayed : status;
      final jamaah = s.counts && rnd.nextDouble() < (p == Prayer.fajr || p == Prayer.isha ? 0.55 : 0.35);
      final mosque = jamaah && rnd.nextDouble() < 0.6;
      await addLog(repos, day, p, s, jamaah: jamaah, mosque: mosque);
    }
    for (final p in const [Prayer.sunnahFajr, Prayer.sunnahDhuhr, Prayer.sunnahMaghrib, Prayer.sunnahIsha]) {
      if (rnd.nextDouble() < 0.6) await addLog(repos, day, p, PrayerStatus.prayed);
    }
    if (rnd.nextDouble() < 0.35) await addLog(repos, day, Prayer.duha, PrayerStatus.prayed);
    if (rnd.nextDouble() < 0.7) await addLog(repos, day, Prayer.witr, PrayerStatus.prayed);
    if (rnd.nextDouble() < 0.12) await addLog(repos, day, Prayer.qiyam, PrayerStatus.prayed);
  }
  await addLog(repos, today, Prayer.fajr, PrayerStatus.prayed, jamaah: true, mosque: true);
  await addLog(repos, today, Prayer.sunnahFajr, PrayerStatus.prayed);
  await addLog(repos, today, Prayer.dhuhr, PrayerStatus.prayed, jamaah: true);
  await addLog(repos, today, Prayer.sunnahDhuhr, PrayerStatus.prayed);
}
