// The Phase 9 system routes – global search, the notification centre and
// Settings › Notifications – build their screens in Arabic and English
// inside the full app (router, gates, adhan host, app lock), with the app's
// own transitions; their parameters reach the screens; back leaves each
// page; and the location helpers are exact.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/motion/transitions.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/routing/system_route_pages.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/notification_center/notification_center.dart';
import 'package:madar/features/search/search.dart';

import '../../features/lock/lock_test_utils.dart';
import '../../helpers/test_app.dart';

/// The search index inline (the real one builds on an isolate, which never
/// finishes under the test binding) and no typing debounce.
List<Override> _searchOverrides() => [
  searchWorkerFactoryProvider.overrideWithValue(() async => InlineSearchWorker()),
  searchDebounceProvider.overrideWithValue(const Duration(milliseconds: 10)),
];

/// A search screen with a query starts building its index, and its
/// "preparing" loader never stops animating – so these pages are pumped a
/// fixed number of frames instead of settled.
Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('locations', () {
    test('the query and the tab are encoded; an empty one is the plain path', () {
      expect(AppRoutes.search, '/search');
      expect(AppRoutes.searchOf(), '/search');
      expect(AppRoutes.searchOf(query: ''), '/search');
      expect(AppRoutes.searchOf(query: '   '), '/search');
      expect(
        AppRoutes.searchOf(query: 'دواء الضغط'),
        '/search?q=%D8%AF%D9%88%D8%A7%D8%A1+%D8%A7%D9%84%D8%B6%D8%BA%D8%B7',
      );
      expect(AppRoutes.notifications, '/notifications');
      expect(AppRoutes.notificationsOf(), '/notifications');
      expect(AppRoutes.notificationsOf(tab: 'recent'), '/notifications?tab=recent');
      expect(AppRoutes.notificationSettings, '/settings/notifications');
      // Never the Quran's own search.
      expect(AppRoutes.search, isNot(AppRoutes.quranSearch));
    });

    test('an unknown tab name leaves the choice to the centre', () {
      expect(NotificationsRoutePage.tabOf('upcoming'), CenterTab.upcoming);
      expect(NotificationsRoutePage.tabOf('recent'), CenterTab.recent);
      expect(NotificationsRoutePage.tabOf('Recent'), isNull, reason: 'names are exact');
      expect(NotificationsRoutePage.tabOf(null), isNull);
    });

    test('they need onboarding like every page', () {
      for (final loc in [AppRoutes.search, AppRoutes.notifications, AppRoutes.notificationSettings]) {
        expect(onboardingRedirect(onboarded: false, location: loc), AppRoutes.onboarding);
        expect(onboardingRedirect(onboarded: true, location: loc), isNull);
      }
    });
  });

  final routes = <(String, Type)>[
    (AppRoutes.search, GlobalSearchScreen),
    (AppRoutes.searchOf(query: 'دواء'), GlobalSearchScreen),
    (AppRoutes.notifications, NotificationCenterScreen),
    (AppRoutes.notificationsOf(tab: 'upcoming'), NotificationCenterScreen),
    (AppRoutes.notificationsOf(tab: 'recent'), NotificationCenterScreen),
    (AppRoutes.notificationSettings, NotificationSettingsRoutePage),
  ];

  for (final lang in ['ar', 'en']) {
    group(lang, () {
      for (final (location, type) in routes) {
        testWidgets('$location builds $type', (tester) async {
          final app = await pumpMadarApp(
            tester,
            settings: AppSettings(onboarded: true, languageCode: lang),
            initialLocation: location,
            settle: false,
            overrides: [...LockFixture.empty().overrides, ..._searchOverrides()],
          );
          await _frames(tester);
          expect(find.byType(type), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(app.router.state.uri.toString(), location);
          expect(
            Directionality.of(tester.element(find.byType(type))),
            lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(ModalRoute.of(tester.element(find.byType(type)))!.settings, isA<MadarTransitionPage<void>>());
          // Nested below home: back leaves the page.
          await tester.binding.handlePopRoute();
          await _frames(tester);
          expect(find.byType(type), findsNothing);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 6));
        });
      }
    });
  }

  testWidgets('the parameters reach the screens', (tester) async {
    final app = await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.searchOf(query: 'دواء'),
      settle: false,
      overrides: _searchOverrides(),
    );
    await _frames(tester);
    expect(tester.widget<GlobalSearchScreen>(find.byType(GlobalSearchScreen)).initialQuery, 'دواء');

    Future<T> at<T extends Widget>(String location) async {
      app.router.go(location);
      await _frames(tester);
      return tester.widget<T>(find.byType(T));
    }

    expect((await at<NotificationCenterScreen>(AppRoutes.notificationsOf(tab: 'recent'))).initialTab, CenterTab.recent);
    expect(
      (await at<NotificationCenterScreen>(AppRoutes.notificationsOf(tab: 'upcoming'))).initialTab,
      CenterTab.upcoming,
    );
    expect((await at<NotificationCenterScreen>(AppRoutes.notifications)).initialTab, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('battery saver stills the centre\'s backdrop', (tester) async {
    await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, powerMode: PowerMode.batterySaver),
      initialLocation: AppRoutes.notifications,
    );
    expect(tester.widget<NotificationCenterScreen>(find.byType(NotificationCenterScreen)).animateBackdrop, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
