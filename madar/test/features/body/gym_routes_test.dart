// Every gym route (Part 8, «#24 – Body / gym») builds its screen in Arabic
// and English inside the full app (router, gates, app lock), with the app's
// shared-axis transition; and every one of the gym's own tables has a deep
// link that never dead-ends.
@Timeout(Duration(minutes: 4))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/motion/transitions.dart';
import 'package:madar/core/routing/life_route_pages.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/body/body.dart';

import '../lock/lock_test_utils.dart';
import '../../helpers/test_app.dart';

void main() {
  group('locations', () {
    test('the gym lives under /body, where he looks for it', () {
      expect(AppRoutes.gymSession, '/body/gym/session');
      expect(AppRoutes.gymTemplates, '/body/gym/days');
      expect(AppRoutes.gymExercise, '/body/gym/exercise/:id');
      expect(AppRoutes.gymExerciseOf('ex-1'), '/body/gym/exercise/ex-1');
      // An id with anything odd in it is still one location.
      expect(AppRoutes.gymExerciseOf('a b/c'), '/body/gym/exercise/a%20b%2Fc');
      expect(AppRoutes.gymSession, isNot(AppRoutes.body));
    });

    test('they need onboarding like every page', () {
      for (final loc in [AppRoutes.gymSession, AppRoutes.gymTemplates, AppRoutes.gymExerciseOf('ex-1')]) {
        expect(onboardingRedirect(onboarded: false, location: loc), AppRoutes.onboarding);
        expect(onboardingRedirect(onboarded: true, location: loc), isNull);
      }
    });
  });

  group('deep links', () {
    test("every table of the gym leads somewhere, with or without an id", () {
      expect(LifeRecordLinks.locationOf('exercises', 'ex-1'), AppRoutes.gymExerciseOf('ex-1'));
      expect(LifeRecordLinks.locationOf('exercises', null), AppRoutes.bodyOf(tab: 'plan'));
      expect(
        LifeRecordLinks.locationOf('workout_logs', 'l1', extra: const {'exerciseId': 'ex-1'}),
        AppRoutes.gymExerciseOf('ex-1'),
      );
      expect(LifeRecordLinks.locationOf('workout_logs', 'l1'), AppRoutes.bodyOf(tab: 'plan'));
      expect(LifeRecordLinks.locationOf('workout_sets', 's1'), AppRoutes.bodyOf(tab: 'plan'));
      expect(LifeRecordLinks.locationOf('workout_templates', 'wt-1'), AppRoutes.gymTemplates);
      expect(LifeRecordLinks.locationOf('workout_template_items', 'i1'), AppRoutes.gymTemplates);
      expect(
        LifeRecordLinks.tables,
        containsAll(['exercises', 'workout_logs', 'workout_sets', 'workout_templates', 'workout_template_items']),
      );
    });
  });

  final routes = <(String, Type)>[
    (AppRoutes.gymSession, GymSessionScreen),
    (AppRoutes.gymTemplates, GymTemplatesScreen),
    (AppRoutes.gymExerciseOf('ex-1'), GymExerciseScreen),
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

  testWidgets('a link to an exercise he has deleted says so instead of dead-ending', (tester) async {
    await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true),
      initialLocation: AppRoutes.gymExerciseOf('gone'),
      overrides: LockFixture.empty().overrides,
    );
    expect(find.byType(GymExerciseScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('gym.exercise.gone')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
