// Settings' Phase 3 entries, grouped under Faith on the settings root:
// Quran reading (the reader's own preferences), recitation, and one
// Reminders page for the adhkar and every wird plan – in Arabic and English.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/quran/quran.dart';
import 'package:madar/features/recitation/recitation.dart';
import 'package:madar/features/settings/quran_settings_screen.dart';
import 'package:madar/features/settings/reminders_settings_screen.dart';
import 'package:madar/features/wird/wird.dart';

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';
import '../orbit/presentation/orbit_scene_fixtures.dart' show hostPrayerSettings;

final _en = lookupL10n(const Locale('en'));
const _english = AppSettings(onboarded: true, languageCode: 'en');

/// Scrolls [finder] to the middle of the list (clear of the app bar).
Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.runAsync(() async {});
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.5);
  await tester.pumpAndSettle();
}

/// Lets database writes started by a tap land.
Future<void> _writes(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await settleApp(tester);
}

Finder _switch(String title) => find.byWidgetPredicate((w) => w is MadarSwitch && w.semanticLabel == title);

Future<QuranReaderPrefs> _prefs(WidgetTester tester, TestApp app) async =>
    (await tester.runAsync(() => app.container.read(quranPrefsStoreProvider).prefs()))!;

Future<List<WirdPlan>> _plans(WidgetTester tester, TestApp app) async =>
    (await tester.runAsync(() => app.container.read(wirdServiceProvider).plans()))!;

/// A plan after Asr (reminders on by default), and one without a prayer.
Future<void> _seedPlans(MadarDatabase db) async {
  await OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings());
  final service = WirdService(Repositories(db), clock: () => testNow);
  await service.create(
    WirdDraft(
      name: 'Baqarah',
      template: WirdTemplate.pages,
      start: const AyahRef(2, 1),
      startDate: DateTime(2026, 9, 27),
      window: PrayerWindow.asr,
    ),
  );
  await service.create(
    WirdDraft(name: 'Juz Amma', template: WirdTemplate.ayat, start: const AyahRef(78, 1), startDate: DateTime(2026, 9, 27)),
  );
}

Iterable<int> _wirdIds(TestApp app) => app.notifications.scheduled.keys.where(NotificationNamespaces.wird.contains);

void main() {
  for (final lang in ['ar', 'en']) {
    testWidgets('$lang: Faith groups prayer, adhan, Quran, recitation and reminders; each opens its page', (tester) async {
      final l = lookupL10n(Locale(lang));
      final app = await pumpMadarApp(
        tester,
        settings: AppSettings(onboarded: true, languageCode: lang),
        initialLocation: AppRoutes.settings,
        overrides: LockFixture.empty().overrides,
      );
      await _show(tester, find.text(l.settingsFaithSection));
      expect(find.text(l.settingsFaithSectionHint), findsOneWidget);
      // The reader's layout and tajweed; the reciter; nothing reminded yet.
      await _show(tester, find.text(l.settingsQuran));
      expect(find.text(l.orbitUiListSeparator(l.quranModeMushaf, l.settingsQuranTajweedOn)), findsOneWidget);
      expect(find.text(Reciters.fallback.name(arabic: lang == 'ar')), findsOneWidget);
      expect(find.text(l.settingsRemindersCount(0)), findsOneWidget);
      final pages = <String, (String, Type)>{
        l.settingsQuran: (AppRoutes.quranSettings, QuranSettingsScreen),
        l.settingsRecitation: (AppRoutes.recitationSettings, RecitationSettingsScreen),
        l.settingsReminders: (AppRoutes.reminders, RemindersSettingsScreen),
      };
      for (final MapEntry(key: title, value: (location, type)) in pages.entries) {
        await _show(tester, find.text(title));
        app.sound.played.clear();
        await tester.tap(find.text(title));
        await settleApp(tester);
        expect(find.byType(type), findsOneWidget, reason: title);
        expect(app.location, location);
        expect(app.sound.played, isNotEmpty);
        await tester.binding.handlePopRoute();
        await settleApp(tester);
        expect(app.location, AppRoutes.settings);
      }
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    });
  }

  testWidgets('Quran reading: layout, text size, tajweed and translation are the reader\'s own preferences', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      initialLocation: AppRoutes.quranSettings,
      overrides: LockFixture.empty().overrides,
    );
    expect(await _prefs(tester, app), const QuranReaderPrefs());

    await tester.tap(find.text(_en.quranModeList));
    await _writes(tester);
    expect((await _prefs(tester, app)).mode, QuranReaderMode.list);

    await tester.tap(find.bySemanticsLabel(_en.quranFontLarger));
    await _writes(tester);
    expect((await _prefs(tester, app)).fontSize, QuranReaderPrefs.defaultFontSize + QuranReaderPrefs.fontStep);

    await _show(tester, _switch(_en.quranTajweedColors));
    await tester.tap(_switch(_en.quranTajweedColors));
    await _writes(tester);
    expect((await _prefs(tester, app)).tajweed, isFalse);

    // Quran.com tajweed: says what is on the device (nothing yet).
    await _show(tester, find.text(_en.quranTajweedSourceQuranCom));
    await tester.tap(find.text(_en.quranTajweedSourceQuranCom));
    await _writes(tester);
    expect((await _prefs(tester, app)).tajweedSource, TajweedSource.quranCom);
    expect(find.text(_en.settingsQuranDownloaded(0)), findsOneWidget);

    await _show(tester, _switch(_en.quranTranslationShow));
    await tester.tap(_switch(_en.quranTranslationShow));
    await _writes(tester);
    expect((await _prefs(tester, app)).translation, isTrue);
    expect(find.text(_en.orbitUiListSeparator(_en.quranTranslationName, _en.settingsQuranDownloaded(0))), findsOneWidget);
    expect(app.haptics.fired, isNotEmpty);

    // The legend opens as a sheet.
    await _show(tester, find.text(_en.quranTajweedLegend));
    app.sound.played.clear();
    await tester.tap(find.text(_en.quranTajweedLegend));
    await settleApp(tester);
    expect(find.byType(TajweedLegendSheet), findsOneWidget);
    expect(app.sound.played, contains(Sfx.sheetOpen));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Reminders: a wird plan after Asr is reminded; off, then back at 30 minutes', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      initialLocation: AppRoutes.reminders,
      beforePump: _seedPlans,
      overrides: LockFixture.empty().overrides,
    );
    await _writes(tester);
    await tester.pump(WirdReminderSync.debounce);
    await _writes(tester);
    // Planned at start by the app's wird reminder sync.
    expect(_wirdIds(app), isNotEmpty);

    await _show(tester, find.text(_en.settingsWirdReminders));
    final after = _en.orbitUiListSeparator(
      _en.wirdWindowAfter(_en.prayerAsr),
      _en.settingsAdhkarAfter(_en.adhkarReminderOffset(15)),
    );
    await _show(tester, find.text(after));
    expect(find.text(after), findsOneWidget);
    // The plan without a prayer says so and offers its editor.
    expect(find.text(_en.settingsWirdNoWindow), findsOneWidget);
    expect(find.text(_en.settingsWirdEditPlan), findsOneWidget);

    await tester.tap(_switch('Baqarah'));
    await _writes(tester);
    var plans = await _plans(tester, app);
    expect(plans.firstWhere((p) => p.name == 'Baqarah').meta.remind, isFalse);
    expect(_wirdIds(app), isEmpty);
    expect(find.text(_en.settingsAdhkarOff), findsWidgets);

    await tester.tap(_switch('Baqarah'));
    await _writes(tester);
    await _show(tester, find.byKey(ValueKey('wird-offset-${plans.first.id}')));
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('wird-offset-${plans.firstWhere((p) => p.name == 'Baqarah').id}')),
        matching: find.text(_en.adhkarReminderOffset(30)),
      ),
    );
    await _writes(tester);
    plans = await _plans(tester, app);
    final baqarah = plans.firstWhere((p) => p.name == 'Baqarah');
    expect(baqarah.meta.remind, isTrue);
    expect(baqarah.meta.remindOffsetMin, 30);
    // The plan itself is untouched (pace, prayer).
    expect(baqarah.window, PrayerWindow.asr);
    expect(baqarah.amountPerDay, 2);
    expect(_wirdIds(app), isNotEmpty);
    // Settings' Faith entry counts it.
    expect(app.container.read(faithRemindersOnProvider), 1);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Reminders without a wird plan invite to start one', (tester) async {
    await pumpMadarApp(
      tester,
      settings: _english,
      initialLocation: AppRoutes.reminders,
      overrides: LockFixture.empty().overrides,
    );
    await _show(tester, find.text(_en.settingsWirdNoPlans));
    expect(find.text(_en.wirdStartPlanCta), findsOneWidget);
    await tester.tap(find.text(_en.wirdStartPlanCta));
    await settleApp(tester);
    expect(find.byType(WirdPlanSheet), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}
