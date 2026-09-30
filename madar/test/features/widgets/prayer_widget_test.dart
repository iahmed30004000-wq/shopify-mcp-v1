import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/settings/app_settings.dart' show DigitStyle;
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer/application/prayer_providers.dart' show hijriAt;
import 'package:madar/features/prayer/domain/time_zones.dart';
import 'package:madar/features/prayer/presentation/prayer_labels.dart';
import 'package:madar/features/widgets/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(MadarTimeZones.ensure);

  late tz.Location amman;
  late PrayerSchedule schedule;
  setUp(() {
    amman = tz.getLocation('Asia/Amman');
    schedule = PrayerSchedule(
      const PrayerSettings(timeZone: 'Asia/Amman', cityNameAr: 'عمّان', cityNameEn: 'Amman', cityId: 'amman'),
    );
  });

  final ar = WidgetTexts.forLanguage('ar');
  final en = WidgetTexts.forLanguage('en');

  WidgetBuild build(DateTime now, {WidgetTexts? texts, bool details = true, PrayerSchedule? s}) =>
      PrayerWidgetBuilder.build(schedule: s ?? schedule, now: now, texts: texts ?? ar, details: details);

  test('the first page counts down to the next prayer (Amman, afternoon)', () {
    final today = schedule.timesFor(DateTime(2026, 9, 30));
    final now = today.dhuhr.add(const Duration(hours: 1));
    final b = build(now);
    final first = b.snapshot.pages.first;
    expect(first.from, isNull);
    expect(first.headline, ar.l.ptAsr);
    expect(first.countdownTo, today.asr);
    expect(first.countdownFormat, 'بعد %s');
    expect(first.image, 'astro_asr');
    final wall = schedule.wallClock(today.asr);
    expect(first.detail, contains(Digits.toArabicIndic('${wall.hour % 12 == 0 ? 12 : wall.hour % 12}:')));
    expect(first.detail, endsWith(ar.l.ptPm));
    expect(b.snapshot.link, WidgetLinks.prayer);
    expect(b.snapshot.kind, MadarWidgetKind.prayer);
  });

  test('a page starts at every prayer and every location midnight, for three days', () {
    final day = DateTime(2026, 9, 30);
    final now = tz.TZDateTime(amman, 2026, 9, 30, 13, 30);
    final b = build(now);
    final starts = [for (final p in b.snapshot.pages.skip(1)) p.from!];
    expect(starts, orderedEquals([...starts]..sort()));
    for (final s in starts) {
      expect(s.isAfter(now), isTrue);
      expect(s.isBefore(b.snapshot.until), isTrue);
    }
    // Every prayer time from now to the end of the third day starts a page.
    for (var i = 0; i < 3; i++) {
      for (final (_, at) in schedule.timesFor(DateTime(day.year, day.month, day.day + i)).obligatory) {
        if (at.isAfter(now)) expect(starts, contains(at));
      }
    }
    final midnight1 = tz.TZDateTime(amman, 2026, 10, 1);
    final midnight2 = tz.TZDateTime(amman, 2026, 10, 2);
    expect(starts.map((s) => s.millisecondsSinceEpoch), containsAll([midnight1, midnight2].map((m) => m.millisecondsSinceEpoch)));
    expect(b.snapshot.until.millisecondsSinceEpoch, tz.TZDateTime(amman, 2026, 10, 3).millisecondsSinceEpoch);
    // Each page names the prayer that follows its start.
    for (final p in b.snapshot.pages.skip(1)) {
      final w = schedule.windowAt(p.from!);
      expect(p.countdownTo, w.nextPrayerAt);
      expect(p.image, PrayerWidgetBuilder.imageKey(w.nextPrayer));
    }
  });

  test('midnight rollover: the Hijri date turns on the page that starts at midnight', () {
    final now = tz.TZDateTime(amman, 2026, 9, 30, 21, 0);
    final b = build(now, details: false);
    final midnight = tz.TZDateTime(amman, 2026, 10, 1);
    final atMidnight = b.snapshot.pages.firstWhere((p) => p.from?.millisecondsSinceEpoch == midnight.millisecondsSinceEpoch);
    final before = b.snapshot.pageAt(midnight.subtract(const Duration(minutes: 1)))!;
    final settings = schedule.settings;
    expect(before.note, ar.l.hijriDate(hijriAt(schedule, settings, now), ar.fmt));
    expect(atMidnight.note, ar.l.hijriDate(hijriAt(schedule, settings, midnight), ar.fmt));
    expect(atMidnight.note, isNot(before.note));
    // Before and after midnight the next prayer is the same Fajr.
    expect(atMidnight.headline, ar.l.ptFajr);
    expect(before.headline, ar.l.ptFajr);
    expect(atMidnight.countdownTo, before.countdownTo);
    // The widget reads its page from the same timeline at any moment.
    expect(b.snapshot.pageAt(midnight.add(const Duration(minutes: 1)))!.note, atMidnight.note);
  });

  test('with the Maghrib rollover the Hijri date turns at Maghrib instead', () {
    final s = PrayerSchedule(const PrayerSettings(timeZone: 'Asia/Amman', hijriAtMaghrib: true));
    final maghrib = s.timesFor(DateTime(2026, 9, 30)).maghrib;
    final b = build(maghrib.subtract(const Duration(hours: 1)), s: s, details: false);
    final beforePage = b.snapshot.pages.first;
    final atMaghrib = b.snapshot.pages.firstWhere((p) => p.from == maghrib);
    expect(atMaghrib.note, isNot(beforePage.note));
    expect(atMaghrib.headline, ar.l.ptIsha);
  });

  test('English, Western digits, 24-hour clock, Jumuʿah on Fridays', () {
    final s = PrayerSchedule(const PrayerSettings(timeZone: 'Asia/Amman', clock24h: true));
    // 2 October 2026 is a Friday.
    final friday = s.timesFor(DateTime(2026, 10, 2));
    final b = build(friday.fajr.add(const Duration(hours: 1)), texts: en, s: s);
    final p = b.snapshot.pages.first;
    expect(b.snapshot.languageCode, 'en');
    expect(b.snapshot.rtl, isFalse);
    expect(p.headline, en.l.ptJumuah);
    final wall = s.wallClock(friday.dhuhr);
    expect(p.detail, '${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}');
    expect(p.countdownFormat, 'in %s');
    expect(Digits.hasEasternDigits(b.snapshot.encode()), isFalse);
  });

  test('Arabic with Western digits when the user chose them', () {
    final texts = WidgetTexts.forLanguage('ar', digits: DigitStyle.western);
    final b = build(tz.TZDateTime(amman, 2026, 9, 30, 13), texts: texts);
    expect(Digits.hasEasternDigits(b.snapshot.pages.first.detail!), isFalse);
    expect(b.snapshot.pages.first.headline, texts.l.ptAsr);
  });

  test('counts only drops the location name; details add it after the Hijri date', () {
    final now = tz.TZDateTime(amman, 2026, 9, 30, 13);
    final shown = build(now);
    final hidden = build(now, details: false);
    expect(shown.snapshot.private, isFalse);
    expect(hidden.snapshot.private, isTrue);
    expect(shown.snapshot.pages.first.note, contains('عمّان'));
    expect(jsonEncode(hidden.snapshot.toJson()), isNot(contains('عمّان')));
    expect(jsonEncode(hidden.snapshot.toJson()), isNot(contains('Amman')));
    expect(hidden.snapshot.pages.first.headline, shown.snapshot.pages.first.headline);
  });

  test('one astrolabe per prayer the pages name, lit on that prayer, drawn from today', () {
    final b = build(tz.TZDateTime(amman, 2026, 9, 30, 13));
    expect(b.images.keys.toSet(), b.snapshot.imageKeys);
    expect(b.images.keys, containsAll(['astro_fajr', 'astro_dhuhr', 'astro_asr', 'astro_maghrib', 'astro_isha']));
    final asr = b.images['astro_asr']!;
    expect(asr.next, 2);
    final t = schedule.timesFor(DateTime(2026, 9, 30));
    expect(asr.asr, closeTo(PrayerSchedule.dialFraction(schedule.wallClock(t.asr)), 1e-9));
    expect(asr.window, (asr.dhuhr, asr.asr));
    expect(b.images['astro_fajr']!.window, (asr.isha, asr.fajr), reason: 'Fajr is lit from Isha, across midnight');
    // Rebuilt a minute later the drawings are identical (nothing re-rendered).
    final later = build(tz.TZDateTime(amman, 2026, 9, 30, 13, 1));
    expect(WidgetBridge.imageSignature(later.images), WidgetBridge.imageSignature(b.images));
  });

  test('rebuilding within a window gives the same JSON (nothing rewritten)', () {
    final a = build(tz.TZDateTime(amman, 2026, 9, 30, 13, 0));
    final b = build(tz.TZDateTime(amman, 2026, 9, 30, 13, 40));
    expect(b.snapshot.encode(), a.snapshot.encode());
  });

  test('the device zone does not matter: the location zone sets the pages', () {
    final zoned = build(tz.TZDateTime(amman, 2026, 9, 30, 23, 30));
    final first = zoned.snapshot.pages[1].from!;
    // Just after 23:30 in Amman the next page is Amman's midnight.
    expect(first.millisecondsSinceEpoch, tz.TZDateTime(amman, 2026, 10, 1).millisecondsSinceEpoch);
  });

  test('Prayer names in both languages come from the prayer feature', () {
    expect(ar.l.prayerName(Prayer.maghrib), ar.l.ptMaghrib);
    expect(en.l.prayerName(Prayer.dhuhr, friday: true), en.l.ptJumuah);
  });
}
