// Every «الحفظ» route (Part 14, step 2) builds its screen in Arabic and
// English inside the full app (router, gates, app lock), with the app's
// shared-axis transition; back leaves each page; and both of «الحفظ»'s
// own tables have a deep link that never dead-ends.
@Timeout(Duration(minutes: 4))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/motion/transitions.dart';
import 'package:madar/core/routing/life_route_pages.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/hifz/hifz_plan.dart';

import '../../features/lock/lock_test_utils.dart';
import '../../helpers/test_app.dart';

void main() {
  group('locations', () {
    test('«الحفظ» has its own paths, under /hifz where he looks for them', () {
      expect(AppRoutes.hifzPlan, '/hifz/plan');
      expect(AppRoutes.hifzMap, '/hifz/plan/map');
      expect(AppRoutes.hifzGoals, '/hifz/plan/goals');
      expect(AppRoutes.hifzFind, '/hifz/find');
      expect(AppRoutes.hifzFindOf(null), '/hifz/find');
      expect(AppRoutes.hifzFindOf(''), '/hifz/find');
      expect(AppRoutes.hifzFindOf('قل هو'), '/hifz/find?q=%D9%82%D9%84+%D9%87%D9%88');
      // Never the SM-2 review screens.
      expect(AppRoutes.hifzPlan, isNot(AppRoutes.hifzReview));
    });

    test('they need onboarding like every page', () {
      for (final loc in [AppRoutes.hifzPlan, AppRoutes.hifzMap, AppRoutes.hifzGoals, AppRoutes.hifzFind]) {
        expect(onboardingRedirect(onboarded: false, location: loc), AppRoutes.onboarding);
        expect(onboardingRedirect(onboarded: true, location: loc), isNull);
      }
    });
  });

  group('deep links', () {
    test('both of «الحفظ»'"'"'s tables lead somewhere, with or without an id', () {
      expect(LifeRecordLinks.locationOf('hifz_goals', 'g1'), AppRoutes.hifzGoals);
      expect(LifeRecordLinks.locationOf('hifz_goals', null), AppRoutes.hifzGoals);
      expect(LifeRecordLinks.locationOf('hifz_marks', 'm1'), AppRoutes.hifzMap);
      expect(LifeRecordLinks.locationOf('hifz_marks', null), AppRoutes.hifzMap);
      expect(LifeRecordLinks.tables, containsAll(['hifz_goals', 'hifz_marks']));
      for (final table in LifeRecordLinks.tables) {
        expect(LifeRecordLinks.locationOf(table, 'x'), isNotNull, reason: table);
      }
    });
  });

  final routes = <(String, Type)>[
    (AppRoutes.hifzPlan, HifzPlanScreen),
    (AppRoutes.hifzMap, HifzMapScreen),
    (AppRoutes.hifzGoals, HifzGoalsScreen),
    (AppRoutes.hifzFind, HifzFindScreen),
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
        });
      }
    });
  }

  testWidgets('the finder opens already holding the phrase from the link', (tester) async {
    await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true),
      initialLocation: AppRoutes.hifzFindOf('قل هو الله أحد'),
      overrides: LockFixture.empty().overrides,
    );
    expect(find.byType(HifzFindScreen), findsOneWidget);
    expect(find.text('قل هو الله أحد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
