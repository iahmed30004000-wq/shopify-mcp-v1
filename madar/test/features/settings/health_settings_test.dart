// Settings › Health, inside the full app: every health preference on one
// page, saved through its package's own service (so reminders re-plan at
// once) – dose reminders (asking for notification permission once, saying
// why nothing will arrive when refused), the notification snooze, meal
// times (the medications' own sheet), appointment reminders, the lab
// "borderline" margin, the doctor report's period, sections and name, the
// worry window, the emergency number and the breathing sound. Settings'
// root shows a Health entry with the reminders on and the number.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/health/meds/meds.dart';
import 'package:madar/features/health/record/record.dart';
import 'package:madar/features/health/wellbeing/wellbeing.dart';
import 'package:madar/features/settings/health_settings_screen.dart';
import 'package:madar/features/settings/widgets/settings_widgets.dart';

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';

final _en = lookupL10n(const Locale('en'));

/// Scrolls the page until [finder] is built, then centres it (clear of the
/// frosted app bar the page scrolls under).
Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.5);
  await tester.pumpAndSettle();
}

/// Lets database writes started by a tap land.
Future<void> _writes(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Finder _switch(String title) => find.byWidgetPredicate((w) => w is MadarSwitch && w.semanticLabel == title);

Future<TestApp> _page(WidgetTester tester, {String lang = 'en', FakeNotificationPlatform? notifications}) =>
    pumpMadarApp(
      tester,
      settings: AppSettings(onboarded: true, languageCode: lang),
      initialLocation: AppRoutes.healthSettings,
      notifications: notifications,
      overrides: LockFixture.empty().overrides,
    );

void main() {
  group('pure', () {
    test('reminders on: doses, appointments, the worry window', () {
      expect(
        HealthSettingsSummary.remindersOn(meds: const MedsSettings(), record: const RecordSettings(), worryOn: false),
        2,
      );
      expect(
        HealthSettingsSummary.remindersOn(
          meds: const MedsSettings(notify: false),
          record: const RecordSettings(remindersEnabled: false),
          worryOn: true,
        ),
        1,
      );
    });

    test('a margin set elsewhere (7 %) stays selectable', () {
      expect(HealthSettingsSummary.marginsWith(0.05), [0, 5, 10, 15, 20]);
      expect(HealthSettingsSummary.marginsWith(0.07), [0, 5, 7, 10, 15, 20]);
      expect(HealthSettingsSummary.marginsWith(0.25), [0, 5, 10, 15, 20, 25]);
    });
  });

  for (final lang in ['ar', 'en']) {
    testWidgets('$lang: the four groups and the privacy note', (tester) async {
      await _page(tester, lang: lang);
      final l = lookupL10n(Locale(lang));
      expect(find.byType(HealthSettingsScreen), findsOneWidget);
      expect(find.text(l.medsTitle), findsOneWidget);
      expect(find.text(l.medsReminders), findsOneWidget);
      // The meal times read as a sentence; dinner is named as a meal
      // («وجبة العشاء») so it never reads as the Isha prayer.
      // Each meal keeps its time on its line (no-break spaces).
      String nb(String s) => s.replaceAll(' ', '\u00A0');
      final meals = find.textContaining(nb(l.medsMealDinner));
      await _show(tester, meals);
      final summary = tester.widget<Text>(meals.first).data!;
      expect(summary, startsWith(nb(l.medsMealBreakfastTitle)));
      expect(summary, contains(l.medsMealLunch));
      expect(summary, contains(l.medsMealBedtime));
      await _show(tester, find.text(l.healthHubSettingsReportSection));
      await _show(tester, find.text(l.wbSettingsSupportNumber));
      await _show(tester, find.text(l.healthHubSettingsPrivacy));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('medications: reminders off and on (permission asked, refusal explained), snooze', (tester) async {
    final notifications = FakeNotificationPlatform(enabled: false);
    final app = await _page(tester, notifications: notifications);
    final service = MedsService(Repositories(app.db));
    await tester.tap(_switch(_en.medsReminders));
    await _writes(tester);
    expect((await tester.runAsync(service.settings))!.notify, isFalse);
    expect(notifications.requestNotificationsCalls, 0, reason: 'switching off asks nothing');

    await tester.tap(_switch(_en.medsReminders));
    await _writes(tester);
    expect((await tester.runAsync(service.settings))!.notify, isTrue);
    expect(notifications.requestNotificationsCalls, 1);
    expect(find.text(_en.healthHubSettingsDenied), findsOneWidget);

    final thirty = find.text(MedsTexts(_en, const MadarFormatter(languageCode: 'en')).duration(30)).first;
    await _show(tester, thirty);
    await tester.tap(thirty);
    await _writes(tester);
    expect((await tester.runAsync(service.settings))!.snoozeMinutes, 30);

    // Meal times open the medications' own settings sheet.
    await _show(tester, find.text(_en.medsMealTimes));
    await tester.tap(find.text(_en.medsMealTimes));
    await tester.pumpAndSettle();
    expect(find.text(_en.medsSettingsTitle), findsOneWidget);
  });

  testWidgets('appointments and labs: reminders, the borderline margin', (tester) async {
    final app = await _page(tester);
    final service = RecordService(Repositories(app.db));
    await _show(tester, _switch(_en.recordSettingsReminders));
    await tester.tap(_switch(_en.recordSettingsReminders));
    await _writes(tester);
    expect((await tester.runAsync(service.settings))!.remindersEnabled, isFalse);
    final times = find.ancestor(of: find.text(_en.recordSettingsReminderTimes), matching: find.byType(SettingsTile));
    expect(find.descendant(of: times, matching: find.text(_en.healthHubSettingsOff)), findsOneWidget);

    await _show(tester, find.text('10%'));
    await tester.tap(find.text('10%'));
    await _writes(tester);
    expect((await tester.runAsync(service.settings))!.borderlineMargin, closeTo(0.10, 1e-9));
  });

  testWidgets('doctor report: period, sections and a name kept only when typed', (tester) async {
    final app = await _page(tester);
    final service = RecordService(Repositories(app.db));
    final texts = RecordTexts(_en, const MadarFormatter(languageCode: 'en'));
    await _show(tester, find.text(texts.reportPeriod(ReportPeriod.months12)));
    await tester.tap(find.text(texts.reportPeriod(ReportPeriod.months12)));
    await _writes(tester);
    expect((await tester.runAsync(service.settings))!.reportPeriod, ReportPeriod.months12);

    await _show(tester, find.text(_en.healthHubSettingsReportNameNone));
    await tester.tap(find.text(_en.healthHubSettingsReportNameNone));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Sara');
    await tester.tap(find.text(_en.recordSave).last);
    await _writes(tester);
    expect((await tester.runAsync(service.settings))!.reportName, 'Sara');

    await _show(tester, find.text(_en.healthHubSettingsReportSectionsAll));
    await tester.tap(find.text(_en.healthHubSettingsReportSectionsAll));
    await tester.pumpAndSettle();
    await tester.tap(find.text(texts.section(ReportSection.mood)).last);
    await tester.pump();
    await tester.tap(find.text(_en.recordSave).last);
    await _writes(tester);
    final sections = (await tester.runAsync(service.settings))!.reportSections!;
    expect(sections, isNot(contains(ReportSection.mood)));
    expect(sections.length, ReportSection.values.length - 1);
  });

  testWidgets('wellbeing: the worry window and emergency number sheets, the breathing sound', (tester) async {
    final app = await _page(tester);
    final service = WellbeingService(Repositories(app.db));
    await _show(tester, _switch(_en.wbSettingsBreathingSound));
    await tester.tap(_switch(_en.wbSettingsBreathingSound));
    await _writes(tester);
    expect((await tester.runAsync(service.settings))!.breathingSound, isFalse);

    await _show(tester, find.text(_en.wbWorryWindowTitle));
    await tester.tap(find.text(_en.wbWorryWindowTitle));
    await tester.pumpAndSettle();
    expect(find.byType(WorryWindowSheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await _show(tester, find.text(_en.wbSettingsSupportNumber));
    await tester.tap(find.text(_en.wbSettingsSupportNumber));
    await tester.pumpAndSettle();
    expect(find.byType(WellbeingSettingsSheet), findsOneWidget);
  });

  testWidgets("Settings' root shows the Health entry and opens its page", (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      initialLocation: AppRoutes.settings,
      overrides: LockFixture.empty().overrides,
    );
    await _show(tester, find.text(_en.healthHubSettingsTitle));
    expect(
      find.text(_en.healthHubSettingsEntrySummary(_en.healthHubSettingsRemindersOn(2, '2'), BidiIsolate.ltr('911'))),
      findsOneWidget,
    );
    await tester.tap(find.text(_en.healthHubSettingsTitle));
    await tester.pumpAndSettle();
    expect(app.location, AppRoutes.healthSettings);
    expect(find.byType(HealthSettingsScreen), findsOneWidget);
  });
}
