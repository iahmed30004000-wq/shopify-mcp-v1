import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/health/meds/data/meds_providers.dart';
import 'package:madar/features/health/meds/domain/dose_scheduler.dart';
import 'package:madar/features/health/meds/domain/med_models.dart';
import 'package:madar/features/home/home_providers.dart' show appForegroundProvider;
import 'package:madar/features/money/budget/data/budget_providers.dart';
import 'package:madar/features/money/budget/data/budget_repository.dart' show BudgetCurrencies;
import 'package:madar/features/orbit/data/orbit_providers.dart' show prayerScheduleProvider, prayerSettingsProvider;
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer/domain/time_zones.dart';
import 'package:madar/features/widgets/widgets.dart';
import 'package:madar/features/work/data/work_providers.dart' show workTop3Provider;
import 'package:madar/features/work/domain/top3.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Now" frozen for the snapshots.
class _FixedNow extends WidgetNow {
  _FixedNow(this.at);

  final DateTime at;

  @override
  DateTime build() => at;
}

/// A counter the fake builds read (a data change).
class _Rev extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final _revProvider = NotifierProvider<_Rev, int>(_Rev.new);

/// The app lock, switchable (turned on / off in the settings).
class _Lock extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool on) => state = on;
}

final _lockProvider = NotifierProvider<_Lock, bool>(_Lock.new);

WidgetBuild _fakeBuild(MadarWidgetKind kind, int rev) => WidgetBuild(
  WidgetSnapshot(
    kind: kind,
    languageCode: 'en',
    private: true,
    title: kind.wire,
    until: DateTime(2026, 10, 2),
    stale: 'stale',
    pages: [WidgetPage(from: null, headline: '$rev')],
  ),
);

Future<void> _settle(ProviderContainer c) async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  await c.read(widgetSyncProvider.notifier).idle;
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(MadarTimeZones.ensure);

  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'madar.settings.v1': jsonEncode({'languageCode': 'en', 'onboarded': true}),
    });
    prefs = await SharedPreferences.getInstance();
  });

  final now = DateTime(2026, 9, 30, 13, 5);

  ProviderContainer container(FakeWidgetPlatform platform, {List<Override> overrides = const [], bool lockOn = true}) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        widgetPlatformProvider.overrideWithValue(platform),
        widgetBridgeProvider.overrideWith(
          (ref) => WidgetBridge(platform, renderImage: (s, {required dark}) async => Uint8List(1)),
        ),
        widgetSyncDebounceProvider.overrideWithValue(Duration.zero),
        widgetNowProvider.overrideWith(() => _FixedNow(now)),
        widgetAppLockOnProvider.overrideWithValue(lockOn),
        appForegroundProvider.overrideWithValue(ValueNotifier(true)),
        ...overrides,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('sync', () {
    List<Override> fakeBuilds() => [
      widgetBuildProvider.overrideWith((ref, kind) => AsyncData(_fakeBuild(kind, ref.watch(_revProvider)))),
    ];

    test('writes only the widgets on the home screen, once per change', () async {
      final platform = FakeWidgetPlatform(installed: {MadarWidgetKind.meds, MadarWidgetKind.budget});
      final c = container(platform, overrides: fakeBuilds());
      c.listen(widgetSyncProvider, (_, _) {});
      await _settle(c);
      expect(platform.published.map((p) => p.kind), unorderedEquals([MadarWidgetKind.meds, MadarWidgetKind.budget]));
      expect(c.read(widgetSyncProvider), {MadarWidgetKind.meds, MadarWidgetKind.budget});

      // A data change rewrites both; an unchanged rebuild writes nothing.
      c.read(_revProvider.notifier).bump();
      await _settle(c);
      expect(platform.published, hasLength(4));
      c.invalidate(widgetBuildProvider);
      await _settle(c);
      expect(platform.published, hasLength(4));
    });

    test('a widget added or removed while the app runs: rewritten / left alone', () async {
      final platform = FakeWidgetPlatform(installed: {MadarWidgetKind.meds});
      final c = container(platform, overrides: fakeBuilds());
      c.listen(widgetSyncProvider, (_, _) {});
      await _settle(c);
      expect(platform.published, hasLength(1));

      platform.installedKinds.add(MadarWidgetKind.prayer);
      platform.emit(WidgetPlatformEvent.changed);
      await _settle(c);
      expect(platform.published.first.kind, MadarWidgetKind.meds);
      expect(platform.published.skip(1).map((p) => p.kind), unorderedEquals([MadarWidgetKind.meds, MadarWidgetKind.prayer]));

      // Same widgets, but Android may have dropped data: written again.
      platform.emit(WidgetPlatformEvent.changed);
      await _settle(c);
      expect(platform.published, hasLength(5));

      platform.installedKinds.clear();
      platform.emit(WidgetPlatformEvent.changed);
      await _settle(c);
      c.read(_revProvider.notifier).bump();
      await _settle(c);
      expect(platform.published, hasLength(5), reason: 'nothing written for widgets not on a home screen');
    });

    test('nothing installed: nothing is built or written', () async {
      var built = 0;
      final platform = FakeWidgetPlatform();
      final c = container(
        platform,
        overrides: [
          widgetBuildProvider.overrideWith((ref, kind) {
            built++;
            return AsyncData(_fakeBuild(kind, 0));
          }),
        ],
      );
      c.listen(widgetSyncProvider, (_, _) {});
      await _settle(c);
      expect(built, 0);
      expect(platform.published, isEmpty);
    });
  });

  group('snapshots from the app data', () {
    test('prayer: waits for the stored settings, then follows them', () async {
      const settings = PrayerSettings(timeZone: 'Asia/Amman', cityNameEn: 'Amman');
      final platform = FakeWidgetPlatform(installed: {MadarWidgetKind.prayer});
      final c = container(
        platform,
        lockOn: false,
        overrides: [
          prayerSettingsProvider.overrideWith((ref) => Stream.value(settings)),
          prayerScheduleProvider.overrideWithValue(PrayerSchedule(settings)),
        ],
      );
      final sub = c.listen(widgetBuildProvider(MadarWidgetKind.prayer), (_, _) {});
      expect(sub.read().isLoading, isTrue);
      await _settle(c);
      final snapshot = sub.read().requireValue.snapshot;
      expect(snapshot.languageCode, 'en');
      expect(snapshot.private, isFalse, reason: 'app lock off: details by default');
      expect(snapshot.pages.first.note, contains('Amman'));
      expect(sub.read().requireValue.images, isNotEmpty);
    });

    test('meds: today\'s plan with the log, counts only while the lock is on', () async {
      final metformin = MedSpec(
        id: 'm1',
        name: 'Metformin',
        dose: '500 mg',
        slots: const [MedSlot(ClockHm(8, 0)), MedSlot(ClockHm(20, 0))],
      );
      final platform = FakeWidgetPlatform(installed: {MadarWidgetKind.meds});
      final c = container(
        platform,
        overrides: [
          medsSchedulerProvider.overrideWithValue(DoseScheduler(meds: [metformin])),
          medsListProvider.overrideWith((ref) => Stream.value([metformin])),
          medLogsProvider.overrideWith(
            (ref) => Stream.value([
              DoseLog(
                id: 'l1',
                medId: 'm1',
                status: DoseStatus.taken,
                slot: DateTime(2026, 9, 30, 8),
                at: DateTime(2026, 9, 30, 8, 10),
              ),
            ]),
          ),
        ],
      );
      c.listen(widgetSyncProvider, (_, _) {});
      await _settle(c);
      final json = platform.stored[MadarWidgetKind.meds]!;
      final s = WidgetSnapshot.decode(json)!;
      expect(s.private, isTrue);
      expect(json, isNot(contains('Metformin')));
      expect(s.pages.first.headline, '1/2');
      expect(s.pages[1].headline, '0/2', reason: 'tomorrow from midnight');

      await c.read(widgetPrefsProvider.notifier).setDetails(MadarWidgetKind.meds, true);
      await _settle(c);
      final shown = WidgetSnapshot.decode(platform.stored[MadarWidgetKind.meds]!)!;
      expect(shown.private, isFalse);
      expect(shown.pages.first.rows.map((r) => r.state), [WidgetRowState.done, WidgetRowState.open]);
      expect(shown.pages.first.rows.first.text, contains('Metformin'));
      expect(prefs.getString(WidgetPrefsController.key), contains('"meds":true'));
    });

    test('Top 3: today\'s items with their links', () async {
      final state = Top3State(
        today: DateTime(2026, 9, 30),
        items: const [
          FocusItem(kind: FocusKind.task, id: 't1', title: 'Report', done: true, flagged: true),
          FocusItem(kind: FocusKind.card, id: 'c1', title: 'Launch', boardId: 'b1', flagged: true),
        ],
      );
      final platform = FakeWidgetPlatform(installed: {MadarWidgetKind.tasks});
      final c = container(platform, lockOn: false, overrides: [workTop3Provider.overrideWithValue(AsyncData(state))]);
      c.listen(widgetSyncProvider, (_, _) {});
      await _settle(c);
      final s = WidgetSnapshot.decode(platform.stored[MadarWidgetKind.tasks]!)!;
      expect(s.pages.first.headline, '1/2');
      expect(s.pages.first.rows.map((r) => r.link), [WidgetLinks.task('t1'), WidgetLinks.card('c1', boardId: 'b1')]);
    });

    test('budget: this month (or week) from the plan and the expenses', () async {
      final math = BudgetMath(const [BudgetNode(id: 'food', name: 'Food', amountMilli: 450000)]);
      final txs = [
        BudgetTx(budgetItemId: 'food', amountMilli: 200000, date: DateTime(2026, 9, 10)),
        BudgetTx(budgetItemId: 'food', amountMilli: 67500, date: DateTime(2026, 9, 29)),
        BudgetTx(budgetItemId: 'food', amountMilli: 99000, date: DateTime(2026, 8, 20)),
      ];
      final platform = FakeWidgetPlatform(installed: {MadarWidgetKind.budget});
      final c = container(
        platform,
        lockOn: false,
        overrides: [
          budgetMathProvider.overrideWithValue(AsyncData(math)),
          budgetExpensesProvider.overrideWithValue(AsyncData(txs)),
          budgetCurrenciesProvider.overrideWith((ref) => Stream.value(const BudgetCurrencies(base: 'JOD'))),
        ],
      );
      c.listen(widgetSyncProvider, (_, _) {});
      await _settle(c);
      final s = WidgetSnapshot.decode(platform.stored[MadarWidgetKind.budget]!)!;
      expect(s.pages.first.headline, contains('182.500'));
      expect(s.pages.first.bar, 406);

      await c.read(widgetPrefsProvider.notifier).setBudgetPeriod(BudgetPeriod.weekly);
      await c.read(widgetPrefsProvider.notifier).setDetails(MadarWidgetKind.budget, false);
      await _settle(c);
      final weekly = WidgetSnapshot.decode(platform.stored[MadarWidgetKind.budget]!)!;
      expect(weekly.private, isTrue);
      expect(weekly.pages.first.detail, 'left this week');
      expect(platform.stored[MadarWidgetKind.budget], isNot(contains('JOD')));
    });
  });

  group('privacy', () {
    ProviderContainer lockable() {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          widgetAppLockOnProvider.overrideWith((ref) => ref.watch(_lockProvider)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a "show details" chosen while App Lock is off does not outlive turning the lock on', () async {
      final c = lockable();
      final prefsCtl = c.read(widgetPrefsProvider.notifier);
      bool shows(MadarWidgetKind k) => c.read(widgetShowsDetailsProvider(k));
      expect(shows(MadarWidgetKind.meds), isTrue, reason: 'lock off: details by default');

      // Switched off and on again with the lock off: back to the default.
      await prefsCtl.setDetails(MadarWidgetKind.meds, false);
      await prefsCtl.setDetails(MadarWidgetKind.meds, true);
      expect(shows(MadarWidgetKind.meds), isTrue);

      // The lock goes on: counts only, as for a widget never touched.
      c.read(_lockProvider.notifier).set(true);
      expect(shows(MadarWidgetKind.meds), isFalse);
      expect(shows(MadarWidgetKind.budget), isFalse);
      // Nothing personal is stored as a choice either.
      expect(c.read(widgetPrefsProvider).details, isEmpty);
    });

    test('a choice that differs from the lock\'s default is kept, both ways', () async {
      final c = lockable();
      final prefsCtl = c.read(widgetPrefsProvider.notifier);
      bool shows(MadarWidgetKind k) => c.read(widgetShowsDetailsProvider(k));

      // Hidden with the lock off: stays hidden whatever the lock does.
      await prefsCtl.setDetails(MadarWidgetKind.budget, false);
      c.read(_lockProvider.notifier).set(true);
      expect(shows(MadarWidgetKind.budget), isFalse);
      c.read(_lockProvider.notifier).set(false);
      expect(shows(MadarWidgetKind.budget), isFalse);

      // Shown on purpose while the lock is on: the user's explicit opt-in.
      c.read(_lockProvider.notifier).set(true);
      await prefsCtl.setDetails(MadarWidgetKind.tasks, true);
      expect(shows(MadarWidgetKind.tasks), isTrue);
      c.read(_lockProvider.notifier).set(false);
      c.read(_lockProvider.notifier).set(true);
      expect(shows(MadarWidgetKind.tasks), isTrue);

      // Hidden again under the lock: the default, not a stored choice.
      await prefsCtl.setDetails(MadarWidgetKind.tasks, false);
      expect(shows(MadarWidgetKind.tasks), isFalse);
      expect(c.read(widgetPrefsProvider).details, {MadarWidgetKind.budget: false});
      // Stored for the next run.
      expect(prefs.getString(WidgetPrefsController.key), contains('"budget":false'));
    });
  });

  group('launch routing', () {
    test('opens an allowed location from a widget tap, cold and warm', () async {
      final opened = <String>[];
      final platform = FakeWidgetPlatform()..pendingLaunch = WidgetLinks.meds;
      final c = container(platform, overrides: [widgetOpenLocationProvider.overrideWithValue(opened.add)]);
      c.read(widgetLaunchRouterProvider);
      await _settle(c);
      expect(opened, [WidgetLinks.meds]);

      platform.pendingLaunch = WidgetLinks.task('t9');
      platform.emit(WidgetPlatformEvent.launch);
      await _settle(c);
      expect(opened, [WidgetLinks.meds, WidgetLinks.task('t9')]);
    });

    test('ignores forged locations and taps before onboarding', () async {
      final opened = <String>[];
      final platform = FakeWidgetPlatform()..pendingLaunch = '/settings/security';
      final c = container(platform, overrides: [widgetOpenLocationProvider.overrideWithValue(opened.add)]);
      c.read(widgetLaunchRouterProvider);
      await _settle(c);
      expect(opened, isEmpty);

      await c.read(appSettingsProvider.notifier).update((s) => s.copyWith(onboarded: false));
      platform.pendingLaunch = WidgetLinks.meds;
      platform.emit(WidgetPlatformEvent.launch);
      await _settle(c);
      expect(opened, isEmpty);
    });
  });
}
