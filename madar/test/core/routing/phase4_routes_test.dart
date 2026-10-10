// Every Phase 4 (health) route builds its screen in Arabic and English inside
// the full app (router, gates, adhan host, app lock), with the app's shared-
// axis transition; the parameters reach the screens; back leaves each page;
// the record's own links (a lab test, the appointments, its tabs) open as
// routes; the location helpers are exact.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/motion/transitions.dart';
import 'package:madar/core/routing/health_route_pages.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/health/meds/meds.dart';
import 'package:madar/features/health/record/record.dart';
import 'package:madar/features/health/wellbeing/wellbeing.dart';
import 'package:madar/features/settings/health_settings_screen.dart';

import '../../features/lock/lock_test_utils.dart';
import '../../helpers/test_app.dart';

void main() {
  group('locations', () {
    test('tabs, ids and patterns are encoded; the home tab is the plain path', () {
      expect(AppRoutes.medsOf(), '/meds');
      expect(AppRoutes.medsOf(tab: 'today'), '/meds');
      expect(AppRoutes.medsOf(tab: 'courses'), '/meds?tab=courses');
      expect(AppRoutes.recordOf(tab: 'labs'), '/record');
      expect(AppRoutes.recordOf(tab: 'questions'), '/record?tab=questions');
      expect(AppRoutes.labTestOf('a b/c'), '/record/lab/a%20b%2Fc');
      expect(AppRoutes.appointmentsOf(), '/record/appointments');
      expect(AppRoutes.appointmentsOf(highlightId: 'x1'), '/record/appointments?highlight=x1');
      expect(AppRoutes.wellbeingOf(tab: 'today'), '/wellbeing');
      expect(AppRoutes.wellbeingOf(tab: 'worries'), '/wellbeing?tab=worries');
      expect(AppRoutes.breathingOf(), '/wellbeing/breathing');
      expect(AppRoutes.breathingOf(pattern: 'box'), '/wellbeing/breathing?pattern=box');
      expect(AppRoutes.healthSettings, '/settings/health');
    });

    test('unknown tab and pattern names fall back', () {
      expect(MedsRoutePage.tabOf('courses'), MedsTab.courses);
      expect(MedsRoutePage.tabOf('nope'), MedsTab.today);
      expect(MedsRoutePage.tabOf(null), MedsTab.today);
      expect(RecordRoutePage.tabOf('conditions'), RecordTab.conditions);
      expect(RecordRoutePage.tabOf(''), RecordTab.labs);
      expect(WellbeingRoutePage.tabOf('insights'), WellbeingTab.insights);
      expect(WellbeingRoutePage.tabOf('x'), WellbeingTab.today);
      expect(BreathingRoutePage.patternOf('box'), 'box');
      expect(BreathingRoutePage.patternOf('478'), '478');
      expect(BreathingRoutePage.patternOf('999'), isNull);
    });
  });

  final routes = <(String, Type)>[
    (AppRoutes.meds, MedsScreen),
    (AppRoutes.medsOf(tab: 'courses'), MedsScreen),
    (AppRoutes.record, RecordScreen),
    (AppRoutes.recordOf(tab: 'questions'), RecordScreen),
    (AppRoutes.appointments, AppointmentsScreen),
    (AppRoutes.labTestOf('missing'), LabTestScreen),
    (AppRoutes.wellbeing, WellbeingScreen),
    (AppRoutes.wellbeingOf(tab: 'habits'), WellbeingScreen),
    (AppRoutes.breathing, BreathingScreen),
    (AppRoutes.healthSettings, HealthSettingsScreen),
  ];

  for (final lang in ['ar', 'en']) {
    group(lang, () {
      for (final (location, type) in routes) {
        testWidgets('$location builds $type', (tester) async {
          final app = await pumpMadarApp(
            tester,
            settings: AppSettings(onboarded: true, languageCode: lang),
            initialLocation: location,
            overrides: LockFixture.empty().overrides,
          );
          expect(find.byType(type), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(app.router.state.uri.toString(), location);
          expect(
            Directionality.of(tester.element(find.byType(type))),
            lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(ModalRoute.of(tester.element(find.byType(type)))!.settings, isA<MadarTransitionPage<void>>());
          // Nested below home (or Settings): back leaves the page.
          await tester.binding.handlePopRoute();
          await settleApp(tester);
          expect(find.byType(type), findsNothing);
          await tester.pump(const Duration(seconds: 6));
        });
      }
    });
  }

  testWidgets('the parameters reach the screens', (tester) async {
    final app = await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.medsOf(tab: 'courses'),
      overrides: LockFixture.empty().overrides,
    );
    expect(tester.widget<MedsScreen>(find.byType(MedsScreen)).initialTab, MedsTab.courses);

    app.router.go(AppRoutes.recordOf(tab: 'conditions'));
    await settleApp(tester);
    expect(tester.widget<RecordScreen>(find.byType(RecordScreen)).initialTab, RecordTab.conditions);

    app.router.go(AppRoutes.appointmentsOf(highlightId: 'appt-1'));
    await settleApp(tester);
    expect(tester.widget<AppointmentsScreen>(find.byType(AppointmentsScreen)).highlightId, 'appt-1');

    app.router.go(AppRoutes.labTestOf('lab-7'));
    await settleApp(tester);
    expect(tester.widget<LabTestScreen>(find.byType(LabTestScreen)).testId, 'lab-7');

    app.router.go(AppRoutes.wellbeingOf(tab: 'worries'));
    await settleApp(tester);
    final wellbeing = tester.widget<WellbeingScreen>(find.byType(WellbeingScreen));
    expect(wellbeing.initialTab, WellbeingTab.worries);
    expect(wellbeing.onBreathe, isNotNull, reason: 'breathing opens as a route');

    app.router.go(AppRoutes.breathingOf(pattern: 'box'));
    await settleApp(tester);
    expect(tester.widget<BreathingScreen>(find.byType(BreathingScreen)).pattern, 'box');

    // An unknown pattern: the user's own last pattern.
    app.router.go('${AppRoutes.breathing}?pattern=nope');
    await settleApp(tester);
    expect(tester.widget<BreathingScreen>(find.byType(BreathingScreen)).pattern, isNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the record opens a lab test and the appointments as routes; back returns', (tester) async {
    late String testId;
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      initialLocation: AppRoutes.record,
      overrides: LockFixture.empty().overrides,
      beforePump: (db) async {
        final service = RecordService(Repositories(db), clock: () => testNow);
        final (row, _) = await service.addTest(name: 'Ferritin', unit: 'ng/mL', low: 15, high: 150);
        testId = row.id;
      },
    );
    expect(app.container.read(recordNavigationProvider), isA<RoutedRecordNavigation>());

    final context = tester.element(find.byType(RecordScreen));
    app.container.read(recordNavigationProvider).openLabTest(context, testId);
    await settleApp(tester);
    expect(find.byType(LabTestScreen), findsOneWidget);
    expect(app.router.state.uri.toString(), AppRoutes.labTestOf(testId));
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(find.byType(LabTestScreen), findsNothing);
    expect(app.router.state.uri.toString(), AppRoutes.record);

    app.container.read(recordNavigationProvider).openAppointments(context, highlightId: 'a1');
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.appointmentsOf(highlightId: 'a1'));
    await tester.pump(const Duration(seconds: 6));
  });
}
