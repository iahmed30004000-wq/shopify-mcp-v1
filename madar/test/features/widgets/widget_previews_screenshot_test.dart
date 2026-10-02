// Screenshots of the home-screen widgets as the Android provider draws them
// (the Flutter preview mirrors its layouts), for visual review:
//   flutter test test/features/widgets --tags screenshot
// → screenshots/widgets/*.png
@Tags(['screenshot'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart' show BudgetPeriod;
import 'package:madar/core/design/themes.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer/domain/time_zones.dart';
import 'package:madar/features/widgets/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../helpers/screenshot_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(MadarTimeZones.ensure);

  final amman = () {
    MadarTimeZones.ensure();
    return tz.getLocation('Asia/Amman');
  }();
  final schedule = PrayerSchedule(
    const PrayerSettings(timeZone: 'Asia/Amman', cityNameAr: 'عمّان', cityNameEn: 'Amman', cityId: 'amman'),
  );
  final now = tz.TZDateTime(amman, 2026, 9, 30, 13, 38);
  final local = DateTime(2026, 9, 30, 13, 38);

  List<(String, WidgetBuild, Size)> widgets(String lang, {required bool details}) {
    final t = WidgetTexts.forLanguage(lang);
    final ar = lang == 'ar';
    final prayer = PrayerWidgetBuilder.build(schedule: schedule, now: now, texts: t, details: details);
    final meds = WidgetBuild(
      MedsWidgetBuilder.build(
        now: local,
        today: [
          WidgetDose(
            name: ar ? 'فيتامين د' : 'Vitamin D',
            dose: ar ? 'كبسولة' : '1 capsule',
            at: DateTime(2026, 9, 30, 8),
            state: WidgetRowState.done,
          ),
          WidgetDose(name: 'Metformin', dose: ar ? '٥٠٠ ملغ' : '500 mg', at: DateTime(2026, 9, 30, 8, 30), state: WidgetRowState.done),
          WidgetDose(name: ar ? 'أوميغا ٣' : 'Omega 3', at: DateTime(2026, 9, 30, 12), state: WidgetRowState.skipped),
          WidgetDose(name: 'Metformin', dose: ar ? '٥٠٠ ملغ' : '500 mg', at: DateTime(2026, 9, 30, 20, 30)),
          WidgetDose(name: ar ? 'مغنيسيوم' : 'Magnesium', at: DateTime(2026, 9, 30, 22)),
        ],
        tomorrow: const [],
        hasMeds: true,
        texts: t,
        details: details,
      ),
    );
    final tasks = WidgetBuild(
      TasksWidgetBuilder.build(
        now: local,
        items: [
          WidgetTask(title: ar ? 'الاتصال بالبنك' : 'Call the bank', done: true, link: WidgetLinks.task('1')),
          WidgetTask(title: ar ? 'إنهاء تقرير الربع الثالث' : 'Finish the Q3 report', link: WidgetLinks.task('2')),
          WidgetTask(title: ar ? 'زيارة الجدة بعد العصر' : 'Visit grandmother after Asr', link: WidgetLinks.task('3')),
        ],
        texts: t,
        details: details,
      ),
    );
    final budget = WidgetBuild(
      BudgetWidgetBuilder.build(
        now: local,
        budget: WidgetBudget(
          period: BudgetPeriod.monthly,
          start: DateTime(2026, 9),
          end: DateTime(2026, 10),
          plannedMilli: 450000,
          spentMilli: 267500,
        ),
        money: (m) => ar ? '${t.fmt.formatNumber(m / 1000, decimals: 3)} د.أ' : 'JOD ${t.fmt.formatNumber(m / 1000, decimals: 3)}',
        texts: t,
        details: details,
      ),
    );
    final over = WidgetBuild(
      BudgetWidgetBuilder.build(
        now: local,
        budget: WidgetBudget(
          period: BudgetPeriod.weekly,
          start: DateTime(2026, 9, 26),
          end: DateTime(2026, 10, 3),
          plannedMilli: 100000,
          spentMilli: 112000,
        ),
        money: (m) => ar ? '${t.fmt.formatNumber(m / 1000, decimals: 3)} د.أ' : 'JOD ${t.fmt.formatNumber(m / 1000, decimals: 3)}',
        texts: t,
        details: details,
      ),
    );
    return [
      ('prayer 2×2', prayer, const Size(130, 130)),
      ('budget 2×2', budget, const Size(130, 130)),
      ('prayer 4×2', prayer, const Size(270, 130)),
      ('meds 4×2', meds, const Size(270, 150)),
      ('tasks 4×2', tasks, const Size(270, 150)),
      ('meds 4×3', meds, const Size(270, 210)),
      ('budget 4×1', over, const Size(270, 110)),
      ('meds 2×2', meds, const Size(130, 130)),
      ('tasks 2×2', tasks, const Size(130, 130)),
    ];
  }

  Widget homeScreen(List<(String, WidgetBuild, Size)> items, {required bool dark, required DateTime at}) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF1B2440), Color(0xFF2E1E3E), Color(0xFF0E2A33)]
            : const [Color(0xFFDCE6F5), Color(0xFFF3E4D6), Color(0xFFD9EFE7)],
      ),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (_, b, s) in items) MadarWidgetPreview(source: b, now: at, size: s, dark: dark),
          ],
        ),
      ),
    ),
  );

  for (final lang in ['ar', 'en']) {
    for (final dark in [true, false]) {
      for (final details in [true, false]) {
        final name = 'widgets/widgets_${lang}_${dark ? 'dark' : 'light'}_${details ? 'details' : 'counts'}';
        testWidgets(name, (tester) async {
          final items = widgets(lang, details: details);
          await captureScreen(
            tester,
            madarScreenshotApp(
              locale: Locale(lang),
              theme: dark ? MadarThemeId.lapis : MadarThemeId.pearl,
              home: homeScreen(items, dark: dark, at: now),
            ),
            name,
            settle: const Duration(milliseconds: 200),
          );
        });
      }
    }
  }

  testWidgets('widgets/widgets_ar_dark_midnight_and_stale', (tester) async {
    final items = widgets('ar', details: true);
    // After the device's midnight (tomorrow's pages) and three days later
    // (stale).
    await captureScreen(
      tester,
      madarScreenshotApp(
        home: Column(
          children: [
            Expanded(child: homeScreen(items.take(5).toList(), dark: true, at: DateTime(2026, 10, 1, 0, 5))),
            Expanded(child: homeScreen(items.take(4).toList(), dark: true, at: DateTime(2026, 10, 4))),
          ],
        ),
      ),
      'widgets/widgets_ar_dark_midnight_and_stale',
      settle: const Duration(milliseconds: 200),
    );
  });

  test('widgets/astro_*.png – the published astrolabe bitmaps', () async {
    final b = PrayerWidgetBuilder.build(schedule: schedule, now: now, texts: WidgetTexts.forLanguage('ar'), details: true);
    Directory('screenshots/widgets').createSync(recursive: true);
    for (final e in b.images.entries) {
      for (final dark in [true, false]) {
        final png = await MiniAstrolabeRenderer.png(e.value, dark: dark);
        File('screenshots/widgets/${e.key}_${dark ? 'dark' : 'light'}.png').writeAsBytesSync(png);
      }
    }
  });
}
