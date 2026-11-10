// Visual critic pass for the prayer tracker: renders the real screens with
// the real fonts and shaders and writes PNGs to
// madar/screenshots/phase2/tracker/*.png.
//
//   flutter test --tags screenshot test/features/prayer_tracker/tracker_screenshot_test.dart
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer_tracker/prayer_tracker.dart';
import 'package:madar/features/prayer_tracker/presentation/charts/segment_ring.dart';

import '../../helpers/screenshot_harness.dart';
import '../../helpers/test_app.dart' show openTestDatabase;
import 'tracker_fixtures.dart';

const _dir = 'phase2/tracker';

Future<MadarDatabase> _seeded(WidgetTester tester, {DateTime? today, bool history = true}) async {
  final db = await openTestDatabase(tester, seed: false);
  if (history) await tester.runAsync(() => seedHistory(Repositories(db), today ?? trackerDay));
  return db;
}

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _scrollBy(WidgetTester tester, double dy) async {
  final list = find.byType(Scrollable).hitTestable().first;
  final state = tester.state<ScrollableState>(list);
  state.position.jumpTo((state.position.pixels + dy).clamp(0, state.position.maxScrollExtent));
  await _frames(tester, 20);
}

Future<void> _openHistory(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).hitTestable());
  await _frames(tester, 24);
}

void main() {
  const ar = Locale('ar');
  const en = Locale('en');

  testWidgets('today – Arabic, Lapis, after Asr', (tester) async {
    final db = await _seeded(tester);
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
      ),
      '$_dir/today_ar_lapis',
    );
  });

  testWidgets('today – English, Pearl, after Asr', (tester) async {
    final db = await _seeded(tester);
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
        theme: MadarThemeId.pearl,
        locale: en,
      ),
      '$_dir/today_en_pearl',
    );
  });

  testWidgets('today – Arabic, Emerald, all five prayed at night, scrolled to the nawafil', (tester) async {
    final db = await _seeded(tester);
    final times = trackerTimes();
    await tester.runAsync(() async {
      final repos = Repositories(db);
      await addLog(repos, trackerDay, Prayer.asr, PrayerStatus.late);
      await addLog(repos, trackerDay, Prayer.maghrib, PrayerStatus.prayed, jamaah: true, mosque: true);
      await addLog(repos, trackerDay, Prayer.sunnahMaghrib, PrayerStatus.prayed);
      await addLog(repos, trackerDay, Prayer.isha, PrayerStatus.prayed, jamaah: true);
      await addLog(repos, trackerDay, Prayer.witr, PrayerStatus.prayed);
    });
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: times.isha.add(const Duration(hours: 1, minutes: 10))),
        theme: MadarThemeId.emerald,
      ),
      '$_dir/today_ar_emerald_complete',
      beforeCapture: (tester) => _scrollBy(tester, 420),
    );
  });

  testWidgets('today – Arabic, Aurora, all five prayed (header)', (tester) async {
    final db = await _seeded(tester);
    final times = trackerTimes();
    await tester.runAsync(() async {
      final repos = Repositories(db);
      await addLog(repos, trackerDay, Prayer.asr, PrayerStatus.prayed);
      await addLog(repos, trackerDay, Prayer.maghrib, PrayerStatus.prayed, jamaah: true);
      await addLog(repos, trackerDay, Prayer.isha, PrayerStatus.late);
    });
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: times.isha.add(const Duration(minutes: 50))),
        theme: MadarThemeId.aurora,
      ),
      '$_dir/today_ar_aurora_complete',
    );
  });

  testWidgets('today – Arabic, Lapis, the fifth prayer lights the ring (celebration)', (tester) async {
    final db = await _seeded(tester);
    final times = trackerTimes();
    await tester.runAsync(() async {
      final repos = Repositories(db);
      await addLog(repos, trackerDay, Prayer.asr, PrayerStatus.prayed);
      await addLog(repos, trackerDay, Prayer.maghrib, PrayerStatus.prayed, jamaah: true);
    });
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: times.isha.add(const Duration(minutes: 20))),
      ),
      '$_dir/today_ar_lapis_celebration',
      beforeCapture: (tester) async {
        await tester.tap(find.text('العشاء').hitTestable());
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 16));
        }
      },
    );
  });

  testWidgets('today – Arabic, Lapis, first launch (empty, before Dhuhr)', (tester) async {
    final db = await _seeded(tester, history: false);
    final times = trackerTimes();
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: times.dhuhr.subtract(const Duration(minutes: 40))),
      ),
      '$_dir/today_ar_lapis_empty',
    );
  });

  testWidgets('history – Arabic, Lapis', (tester) async {
    final db = await _seeded(tester);
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
      ),
      '$_dir/history_ar_lapis',
      beforeCapture: (tester) => _openHistory(tester, 'السجلّ'),
    );
  });

  testWidgets('history – Arabic, Lapis, totals and bars', (tester) async {
    final db = await _seeded(tester);
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
      ),
      '$_dir/history_ar_lapis_totals',
      beforeCapture: (tester) async {
        await _openHistory(tester, 'السجلّ');
        await _scrollBy(tester, 820);
      },
    );
  });

  testWidgets('history – Arabic, Lapis, qada ledger', (tester) async {
    final db = await _seeded(tester);
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
      ),
      '$_dir/history_ar_lapis_qada',
      beforeCapture: (tester) async {
        await _openHistory(tester, 'السجلّ');
        await _scrollBy(tester, 5000);
      },
    );
  });

  testWidgets('history – English, Pearl', (tester) async {
    final db = await _seeded(tester);
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
        theme: MadarThemeId.pearl,
        locale: en,
      ),
      '$_dir/history_en_pearl',
      beforeCapture: (tester) => _openHistory(tester, 'History'),
    );
  });

  testWidgets('history – English, Pearl, totals', (tester) async {
    final db = await _seeded(tester);
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
        theme: MadarThemeId.pearl,
        locale: en,
      ),
      '$_dir/history_en_pearl_totals',
      beforeCapture: (tester) async {
        await _openHistory(tester, 'History');
        await _scrollBy(tester, 820);
      },
    );
  });

  testWidgets('history – Arabic, Desert', (tester) async {
    final db = await _seeded(tester);
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
        theme: MadarThemeId.desert,
      ),
      '$_dir/history_ar_desert',
      beforeCapture: (tester) => _openHistory(tester, 'السجلّ'),
    );
  });

  testWidgets('day sheet – Arabic, Aurora', (tester) async {
    final db = await _seeded(tester);
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
        theme: MadarThemeId.aurora,
      ),
      '$_dir/day_sheet_ar_aurora',
      beforeCapture: (tester) async {
        await _openHistory(tester, 'السجلّ');
        await tester.tap(find.byType(SegmentRing).hitTestable().at(3));
        await _frames(tester, 30);
      },
    );
  });

  testWidgets('long-press menu – Arabic, Lapis', (tester) async {
    final db = await _seeded(tester);
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
      ),
      '$_dir/menu_ar_lapis',
      beforeCapture: (tester) async {
        await tester.longPress(find.text('الظهر').hitTestable());
        await _frames(tester, 24);
      },
    );
  });

  testWidgets('compact card – Arabic, Aurora and English, Pearl', (tester) async {
    final db = await _seeded(tester);
    Widget page() => MadarScaffold(
      title: 'الإيمان',
      body: ListView(
        padding: const EdgeInsetsDirectional.all(Space.gutter),
        children: [PrayerTodayCard(onOpen: () {})],
      ),
    );
    await captureScreen(
      tester,
      trackerTestApp(
        home: page(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
        theme: MadarThemeId.aurora,
      ),
      '$_dir/card_ar_aurora',
      logicalSize: const Size(412, 420),
    );
  });

  testWidgets('compact card – English, Pearl', (tester) async {
    final db = await _seeded(tester);
    Widget page() => MadarScaffold(
      title: 'Faith',
      body: ListView(
        padding: const EdgeInsetsDirectional.all(Space.gutter),
        children: [PrayerTodayCard(onOpen: () {})],
      ),
    );
    await captureScreen(
      tester,
      trackerTestApp(
        home: page(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
        theme: MadarThemeId.pearl,
        locale: en,
      ),
      '$_dir/card_en_pearl',
      logicalSize: const Size(412, 420),
    );
  });

  testWidgets('today – Arabic, Lapis, custom accent', (tester) async {
    final db = await _seeded(tester);
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
        theme: MadarThemeId.lapis,
        locale: ar,
        accent: const Color(0xFF6FD3C1),
      ),
      '$_dir/today_ar_lapis_accent',
    );
  });

  testWidgets('today – Arabic, Pearl, 24-hour prayer clock', (tester) async {
    final db = await _seeded(tester);
    final schedule = PrayerSchedule(hostPrayerSettings().copyWith(clock24h: true));
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: afterAsr(schedule), schedule: schedule),
        theme: MadarThemeId.pearl,
      ),
      '$_dir/today_ar_pearl_24h',
    );
  });

  testWidgets('history – Arabic, Pearl, a long qada backlog a page at a time', (tester) async {
    final db = await _seeded(tester);
    await tester.runAsync(() async {
      final repos = Repositories(db);
      for (var i = 41; i <= 80; i++) {
        await addLog(repos, TrackerDays.add(trackerDay, -i), TrackerPrayers.obligatory[i % 5], PrayerStatus.missed);
      }
    });
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
        theme: MadarThemeId.pearl,
      ),
      '$_dir/history_ar_pearl_qada_more',
      beforeCapture: (tester) async {
        await _openHistory(tester, 'السجلّ');
        // The list is lazy: its extent grows as it scrolls.
        for (var i = 0; i < 6; i++) {
          await _scrollBy(tester, 100000);
        }
      },
    );
  });

  testWidgets('history – Arabic, Emerald, first launch (nothing logged)', (tester) async {
    final db = await _seeded(tester, history: false);
    await captureScreen(
      tester,
      trackerTestApp(
        home: const PrayerTrackerScreen(),
        overrides: trackerOverrides(db: db, now: afterAsr()),
        theme: MadarThemeId.emerald,
      ),
      '$_dir/history_ar_emerald_empty',
      beforeCapture: (tester) => _openHistory(tester, 'السجلّ'),
    );
  });
}
