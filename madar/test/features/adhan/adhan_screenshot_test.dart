@Tags(['screenshot'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/features/adhan/adhan.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';

import '../../helpers/screenshot_harness.dart';
import 'adhan_test_app.dart';

const _dir = 'phase2/adhan';

DateTime _timeOf(AdhanSlot slot) {
  final t = PrayerSchedule(ammanPrayerSettings).timesFor(DateTime(2026, 9, 28));
  return switch (slot) {
    AdhanSlot.fajr => t.fajr,
    AdhanSlot.sunrise => t.sunrise,
    AdhanSlot.dhuhr => t.dhuhr,
    AdhanSlot.asr => t.asr,
    AdhanSlot.maghrib => t.maghrib,
    AdhanSlot.isha => t.isha,
  }.toUtc();
}

Future<void> _shot(
  WidgetTester tester,
  String name, {
  required AdhanEvent event,
  required DateTime now,
  MadarThemeId theme = MadarThemeId.lapis,
  String language = 'ar',
  AdhanSettings settings = const AdhanSettings(),
}) async {
  final h = await buildAdhanTestApp(
    tester,
    home: AdhanScreen(event: event, onClose: () {}),
    theme: theme,
    language: language,
    now: now,
    settings: settings,
  );
  await captureScreen(tester, h.app, '$_dir/$name', settle: const Duration(milliseconds: 2400));
}

void main() {
  for (final slot in AdhanSlot.prayers) {
    testWidgets('adhan ${slot.name} ar lapis', (tester) async {
      final at = _timeOf(slot);
      await _shot(
        tester,
        'adhan_${slot.name}_ar_lapis',
        event: adhanEventFor(
          slot,
          prayerAt: at,
          sound: AdhanSoundRef.tone(slot == AdhanSlot.fajr ? TanbihTone.dawn : TanbihTone.brass),
        ),
        now: at.add(const Duration(seconds: 5)),
      );
    });
  }

  for (final slot in AdhanSlot.prayers) {
    testWidgets('adhan ${slot.name} en pearl', (tester) async {
      final at = _timeOf(slot);
      await _shot(
        tester,
        'adhan_${slot.name}_en_pearl',
        event: adhanEventFor(
          slot,
          prayerAt: at,
          sound: AdhanSoundRef.tone(slot == AdhanSlot.fajr ? TanbihTone.dawn : TanbihTone.brass),
        ),
        now: at.add(const Duration(seconds: 5)),
        theme: MadarThemeId.pearl,
        language: 'en',
      );
    });
  }

  testWidgets('after the adhan: the supplication (ar, emerald)', (tester) async {
    final at = _timeOf(AdhanSlot.maghrib);
    await _shot(
      tester,
      'adhan_after_ar_emerald',
      event: adhanEventFor(AdhanSlot.maghrib, prayerAt: at),
      now: at.add(const Duration(minutes: 3)),
      theme: MadarThemeId.emerald,
    );
  });

  testWidgets('after the adhan: the supplication (en, desert)', (tester) async {
    final at = _timeOf(AdhanSlot.isha);
    await _shot(
      tester,
      'adhan_after_en_desert',
      event: adhanEventFor(AdhanSlot.isha, prayerAt: at),
      now: at.add(const Duration(minutes: 3)),
      theme: MadarThemeId.desert,
      language: 'en',
    );
  });

  testWidgets('after the adhan: the supplication (ar, pearl)', (tester) async {
    final at = _timeOf(AdhanSlot.fajr);
    await _shot(
      tester,
      'adhan_after_ar_pearl',
      event: adhanEventFor(AdhanSlot.fajr, prayerAt: at, sound: const AdhanSoundRef.tone(TanbihTone.dawn)),
      now: at.add(const Duration(minutes: 3)),
      theme: MadarThemeId.pearl,
    );
  });

  testWidgets('reminder with countdown (en, pearl)', (tester) async {
    final at = _timeOf(AdhanSlot.isha);
    await _shot(
      tester,
      'adhan_reminder_en_pearl',
      event: adhanEventFor(
        AdhanSlot.isha,
        kind: AdhanKind.preAdhan,
        prayerAt: at,
        firedAt: at.subtract(const Duration(minutes: 15)),
        sound: null,
        minutesBefore: 15,
      ),
      now: at.subtract(const Duration(minutes: 14, seconds: 12)),
      theme: MadarThemeId.pearl,
      language: 'en',
    );
  });

  testWidgets('reminder with countdown (ar, aurora)', (tester) async {
    final at = _timeOf(AdhanSlot.asr);
    await _shot(
      tester,
      'adhan_reminder_ar_aurora',
      event: adhanEventFor(
        AdhanSlot.asr,
        kind: AdhanKind.preAdhan,
        prayerAt: at,
        firedAt: at.subtract(const Duration(minutes: 10)),
        sound: null,
        minutesBefore: 10,
      ),
      now: at.subtract(const Duration(minutes: 9, seconds: 40)),
      theme: MadarThemeId.aurora,
    );
  });

  testWidgets('sunrise alert (en, lapis)', (tester) async {
    final at = _timeOf(AdhanSlot.sunrise);
    await _shot(
      tester,
      'adhan_sunrise_en_lapis',
      event: adhanEventFor(AdhanSlot.sunrise, kind: AdhanKind.sunrise, prayerAt: at, sound: null),
      now: at.add(const Duration(seconds: 20)),
      language: 'en',
    );
  });
}
