import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/orbit/data/orbit_providers.dart';
import 'package:madar/features/prayer_tracker/prayer_tracker.dart';
import 'package:madar/features/prayer_tracker/presentation/charts/breakdown_bars.dart';
import 'package:madar/features/prayer_tracker/presentation/charts/month_heatmap.dart';

import 'tracker_fixtures.dart';

void main() {
  late MadarDatabase db;
  setUp(() async => db = await openInMemoryMadarDatabase());
  tearDown(() => db.close());

  ProviderContainer container(DateTime now) {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        homeClockProvider.overrideWithValue(() => now),
        trackerNowProvider.overrideWithValue(now),
        prayerScheduleProvider.overrideWithValue(hostSchedule()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<T> settled<T>(ProviderContainer c, ProviderListenable<AsyncValue<T>> p) async {
    final sub = c.listen(p, (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 50; i++) {
      final v = c.read(p);
      if (v.hasValue) return v.requireValue;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('no value');
  }

  test('before Fajr the tracker still shows yesterday\'s prayer day', () {
    final t = trackerTimes();
    expect(container(t.fajr.subtract(const Duration(minutes: 5))).read(trackerTodayProvider), DateTime(2026, 9, 27));
    expect(container(t.fajr.add(const Duration(minutes: 5))).read(trackerTodayProvider), trackerDay);
  });

  test('the day view and the history follow the writes', () async {
    final c = container(afterAsr());
    final view = await settled(c, trackerTodayViewProvider);
    expect(view.prayedCount, 0);
    expect(view.nextUpcoming?.prayer, Prayer.maghrib);

    final repo = c.read(prayerTrackerRepositoryProvider);
    for (var i = 1; i <= 2; i++) {
      for (final p in TrackerPrayers.obligatory) {
        await repo.setStatus(TrackerDays.add(trackerDay, -i), p, PrayerStatus.prayed);
      }
    }
    await repo.setStatus(trackerDay, Prayer.fajr, PrayerStatus.prayed);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((await settled(c, trackerTodayViewProvider)).prayedCount, 1);
    final history = await settled(c, trackerHistoryProvider);
    expect((history.streaks.current, history.streaks.best), (2, 2));
    expect(history.dayOf(trackerDay).fardPrayed, 1);
  });

  test('the heatmap month never goes past the current month', () {
    final c = container(afterAsr());
    final sub = c.listen(trackerMonthProvider, (_, _) {});
    addTearDown(sub.close);
    final month = c.read(trackerMonthProvider.notifier);
    expect(c.read(trackerMonthProvider), DateTime(2026, 9));
    expect(month.canGoForward, isFalse);
    month.next();
    expect(c.read(trackerMonthProvider), DateTime(2026, 9));
    month.previous();
    month.previous();
    expect(c.read(trackerMonthProvider), DateTime(2026, 7));
    expect(month.canGoForward, isTrue);
    month.next();
    expect(c.read(trackerMonthProvider), DateTime(2026, 8));
  });

  test('the qada filter', () {
    final c = container(afterAsr());
    final sub = c.listen(qadaFilterProvider, (_, _) {});
    addTearDown(sub.close);
    expect(c.read(qadaFilterProvider), isNull);
    c.read(qadaFilterProvider.notifier).select(Prayer.isha);
    expect(c.read(qadaFilterProvider), Prayer.isha);
  });

  group('chart geometry', () {
    test('heatmap cells map to taps and back, in both reading directions', () {
      for (final dir in TextDirection.values) {
        final layout = HeatmapLayout(size: const Size(350, 300), rows: 5, textDirection: dir);
        for (var i = 0; i < 35; i++) {
          expect(layout.indexAt(layout.rectOf(i).center), i, reason: '$dir cell $i');
        }
        expect(layout.indexAt(const Offset(-4, 10)), isNull);
        expect(layout.indexAt(const Offset(10, 310)), isNull, reason: 'below the last row');
        // A gap belongs half to each neighbour: no dead spot between days.
        final first = dir == TextDirection.rtl ? 6 : 0;
        final second = dir == TextDirection.rtl ? 5 : 1;
        expect(layout.indexAt(Offset(layout.cell + 2, 10)), first, reason: 'the near half of the gap');
        expect(layout.indexAt(Offset(layout.cell + 4, 10)), second, reason: 'the far half of the gap');
        expect(layout.targetOf(0).width, closeTo(layout.cell + layout.gap, 1e-9));
      }
      final rtl = HeatmapLayout(size: const Size(350, 300), rows: 5, textDirection: TextDirection.rtl);
      expect(rtl.rectOf(0).right, closeTo(350, 0.01), reason: 'the week starts at the right in Arabic');
      expect(HeatmapLayout.heightFor(350, 5), closeTo(5 * rtl.cell + 4 * 6, 1e-9));
    });

    test('only a complete day is full gold; four of five stays clearly short of it', () {
      expect(MonthHeatmapPainter.strengthOf(1), 1);
      expect(MonthHeatmapPainter.strengthOf(0.8), lessThan(0.6));
      expect(MonthHeatmapPainter.strengthOf(0.2), lessThan(MonthHeatmapPainter.strengthOf(0.4)));
    });

    test('breakdown bars split the span into on time, late, made up and missed', () {
      const b = PrayerBreakdown(onTime: 20, late: 4, madeUp: 1, missed: 2);
      final f = BreakdownBarPainter.fractions(b, 30);
      expect(f, [20 / 30, 4 / 30, 1 / 30, 2 / 30]);
      expect(BreakdownBarPainter.fractions(const PrayerBreakdown(), 0), [0, 0, 0, 0]);
      // More logs than days (never) cannot overflow the bar.
      expect(BreakdownBarPainter.fractions(const PrayerBreakdown(onTime: 3), 2).first, 1);
    });
  });

  test('repository writes through Repositories directly are seen by the history', () async {
    final c = container(afterAsr());
    await settled(c, trackerHistoryProvider);
    await addLog(Repositories(db), DateTime(2026, 9, 3), Prayer.asr, PrayerStatus.missed);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final h = await settled(c, trackerHistoryProvider);
    expect(h.qada.outstanding.single.prayer, Prayer.asr);
  });
}
