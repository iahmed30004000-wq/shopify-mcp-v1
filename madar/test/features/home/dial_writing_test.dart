// The writing on the home screen must not quietly disappear.
//
// The owner reported that the text that used to be on the astrolabe was gone
// (the date and the time). Rendering the first Phase 1 build, APK #15 and this
// one through the same fixtures showed the same writing in all three, so the
// loss never reached the test renderer. These tests are the net for it:
// they look for the date line, for the dial's spoken countdown, and for real
// ink in the engraved hub ring where the countdown is cut – not just for a
// widget that claims to be there.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe.dart';
import 'package:madar/features/prayer/prayer.dart' show PrayerLabels, hijriDateProvider;

import '../../helpers/test_app.dart';

/// How much lettering the dial has actually drawn: the opaque pixels of the
/// countdown image the painter cut for the engraved hub ring. A font that
/// fails to load, an empty string or a swallowed exception all leave it blank
/// or null – which is exactly how the writing would vanish.
Future<({int ink, int width, int height})> _countdownInk(WidgetTester tester) async {
  final finder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is AstrolabePainter);
  final painter = tester.widget<CustomPaint>(finder.first).painter! as AstrolabePainter;
  final image = painter.cache.countdownImage;
  expect(image, isNotNull, reason: 'the dial rendered its countdown lettering');
  final bytes = (await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  final data = bytes.buffer.asUint8List();
  var ink = 0;
  for (var i = 3; i < data.length; i += 4) {
    if (data[i] > 128) ink++;
  }
  return (ink: ink, width: image!.width, height: image.height);
}

void main() {
  for (final lang in ['ar', 'en']) {
    final l = lookupL10n(Locale(lang));

    testWidgets('$lang: the date line (Gregorian and Hijri) is on the home header', (tester) async {
      await pumpMadarApp(tester, settings: AppSettings(onboarded: true, languageCode: lang));
      final context = tester.element(find.byType(Scaffold).first);
      final fmt = MadarFormatter.of(context);
      final hijri = ProviderScope.containerOf(context).read(hijriDateProvider(testNow));
      final date = l.homeDateWithHijri(
        fmt.formatDate(testNow, style: MadarDateStyle.weekdayDayMonth),
        l.hijriDayMonth(hijri, fmt),
      );
      expect(find.text(date), findsOneWidget, reason: 'the day in both calendars sits under the app name');
      expect(find.text(l.appName), findsWidgets);
    });

    testWidgets('$lang: the dial speaks its countdown and has lettering cut into its hub ring', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpMadarApp(tester, settings: AppSettings(onboarded: true, languageCode: lang));

      // Clock frozen at 13:10 (after Dhuhr): the next prayer is Asr.
      expect(find.bySemanticsLabel(RegExp(l.prayerAsr)), findsWidgets, reason: 'the dial names the next prayer');

      final ink = await _countdownInk(tester);
      // ignore: avoid_print
      print('countdown lettering ($lang): ${ink.ink} opaque px in ${ink.width}x${ink.height}');
      expect(ink.ink, greaterThan(200), reason: 'engraved countdown lettering has real ink');
      handle.dispose();
    });
  }
}
