// Part 7's one route: `/day` – the daily chat. It builds inside the full
// app (router, gates, app lock) in Arabic and English with the app's own
// transition, its parameters reach the screen (and `q` only ever **types** a
// line, never sends one), back leaves it, and it is one tap from where he
// already is: the quick-add bar on the home panel.
//
// Also: every row a chat piece can create leads somewhere
// ([LoggedRecordLinks]), so a filed card can be followed to its record.
@Timeout(Duration(minutes: 6))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/transitions.dart';
import 'package:madar/core/routing/life_route_pages.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/routing/system_route_pages.dart' show DayChatRoutePage;
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/day_chat/day_chat.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';

import '../../features/lock/lock_test_utils.dart';
import '../../features/orbit/presentation/orbit_scene_fixtures.dart' show hostPrayerSettings;
import '../../helpers/test_app.dart';

final _ar = lookupL10n(const Locale('ar'));

void main() {
  group('locations', () {
    test('the chat has its own path, and carries a day, a tab and a draft', () {
      expect(AppRoutes.dayChat, '/day');
      expect(AppRoutes.dayChatOf(), '/day');
      expect(AppRoutes.dayChatOf(tab: 'chat'), '/day', reason: 'the chat is the default tab');
      expect(AppRoutes.dayChatOf(tab: 'summary'), '/day?tab=summary');
      expect(AppRoutes.dayChatOf(day: DateTime(2026, 10, 14)), '/day?day=2026-10-14');
      expect(AppRoutes.dayChatOf(day: DateTime(2026, 1, 2)), '/day?day=2026-01-02');
      expect(AppRoutes.dayChatOf(draft: '   '), '/day', reason: 'an empty draft is no draft');
      expect(
        AppRoutes.dayChatOf(draft: 'صرفت ٥ دنانير قهوة'),
        '/day?q=%D8%B5%D8%B1%D9%81%D8%AA+%D9%A5+%D8%AF%D9%86%D8%A7%D9%86%D9%8A%D8%B1+%D9%82%D9%87%D9%88%D8%A9',
      );
      // Not the AI chat, and not the plans.
      expect(AppRoutes.dayChat, isNot(AppRoutes.ai));
      expect(AppRoutes.dayChat, isNot(startsWith(AppRoutes.plans)));
    });

    test('the chat needs onboarding like every page', () {
      for (final loc in [AppRoutes.dayChat, AppRoutes.dayChatOf(tab: 'summary')]) {
        expect(onboardingRedirect(onboarded: false, location: loc), AppRoutes.onboarding);
        expect(onboardingRedirect(onboarded: true, location: loc), isNull);
      }
    });

    test('the tab and the day of a location reach the screen', () {
      expect(DayChatRoutePage.tabOf(null), isNull);
      expect(DayChatRoutePage.tabOf('summary'), DayChatTab.summary);
      expect(DayChatRoutePage.tabOf('chat'), DayChatTab.chat);
      expect(DayChatRoutePage.tabOf('nonsense'), isNull);
      expect(DayChatRoutePage.dayOf('2026-10-14'), DateTime(2026, 10, 14));
      expect(DayChatRoutePage.dayOf(''), isNull);
      expect(DayChatRoutePage.dayOf('not a day'), isNull);
    });
  });

  group('deep links', () {
    test('every row a chat piece can create leads somewhere', () {
      // The ten tables `DayChatService` writes through.
      const writes = {
        'transactions': null,
        'food_logs': null,
        'workout_logs': null,
        'water_logs': null,
        'pain_entries': null,
        'mood_entries': null,
        'prayer_logs': null,
        'contact_logs': null,
        'custom_entries': null,
        'tasks': 'money',
      };
      for (final entry in writes.entries) {
        expect(
          LoggedRecordLinks.locationOf(entry.key, 'x1', planetKey: entry.value),
          isNotNull,
          reason: entry.key,
        );
      }
      // The exact targets, so the chat and the global search never disagree.
      expect(LoggedRecordLinks.locationOf('transactions', 't1'), AppRoutes.ledger);
      expect(
        LoggedRecordLinks.locationOf('transactions', 't1', walletId: 'w1'),
        AppRoutes.transactionsOf({
          'wallet': ['w1'],
        }),
      );
      expect(LoggedRecordLinks.locationOf('prayer_logs', 'p1'), AppRoutes.prayerTrackerHistory);
      expect(LoggedRecordLinks.locationOf('pain_entries', 'p1'), AppRoutes.wellbeingOf(tab: 'pain'));
      expect(LoggedRecordLinks.locationOf('mood_entries', 'm1'), AppRoutes.wellbeing);
      expect(
        LoggedRecordLinks.locationOf('tasks', 't1', planetKey: 'money'),
        AppRoutes.planetOf('money', item: 'tasks:t1'),
      );
      // A task under no world has nowhere of its own, and says so instead
      // of landing on a planet that is not his.
      expect(LoggedRecordLinks.locationOf('tasks', 't1'), isNull);
      // And the life worlds' own records still go through LifeRecordLinks.
      expect(LoggedRecordLinks.locationOf('water_logs', 'w1'), LifeRecordLinks.locationOf('water_logs', 'w1'));
      expect(LoggedRecordLinks.allTables, containsAll(LifeRecordLinks.tables));
    });
  });

  for (final lang in ['ar', 'en']) {
    group(lang, () {
      testWidgets('/day builds the chat, and back leaves it', (tester) async {
        final app = await pumpMadarApp(
          tester,
          settings: AppSettings(onboarded: true, languageCode: lang),
          initialLocation: AppRoutes.dayChat,
          overrides: LockFixture.empty().overrides,
        );
        expect(find.byType(DayChatScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(app.router.state.uri.toString(), AppRoutes.dayChat);
        expect(
          Directionality.of(tester.element(find.byType(DayChatScreen))),
          lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(ModalRoute.of(tester.element(find.byType(DayChatScreen)))!.settings, isA<MadarTransitionPage<void>>());
        // Nested below home: back leaves the chat.
        await tester.binding.handlePopRoute();
        await settleApp(tester);
        expect(find.byType(DayChatScreen), findsNothing);
        await tester.pump(const Duration(seconds: 6));
      });

      testWidgets('/day?tab=summary opens «شو صار اليوم؟» straight away', (tester) async {
        await pumpMadarApp(
          tester,
          settings: AppSettings(onboarded: true, languageCode: lang),
          initialLocation: AppRoutes.dayChatOf(tab: 'summary'),
          overrides: LockFixture.empty().overrides,
        );
        final screen = tester.widget<DayChatScreen>(find.byType(DayChatScreen));
        expect(screen.initialTab, DayChatTab.summary);
        expect(find.byType(DaySummaryView), findsOneWidget);
        await tester.pump(const Duration(seconds: 6));
      });

      testWidgets('/day?q= only types the line – it is never sent', (tester) async {
        const line = 'صرفت ٥ دنانير قهوة';
        final app = await pumpMadarApp(
          tester,
          settings: AppSettings(onboarded: true, languageCode: lang),
          initialLocation: AppRoutes.dayChatOf(draft: line),
          overrides: LockFixture.empty().overrides,
        );
        final field = tester.widget<TextField>(find.byKey(const ValueKey('dayChat.input')));
        expect(field.controller?.text, line);
        // Nothing was read and nothing was remembered: no bubble, no card,
        // and nothing in his data.
        expect(find.byType(DayChatBubble), findsNothing);
        expect(find.byType(DayChatPieceCard), findsNothing);
        expect(await app.repos.transactions.getAll(), isEmpty);
        await tester.pump(const Duration(seconds: 6));
      });
    });
  }

  testWidgets('the chat is one tap from the home panel, carrying what he already typed', (tester) async {
    const line = 'صرفت ٥ دنانير قهوة، صليت العصر بالمسجد';
    final app = await pumpMadarApp(
      tester,
      overrides: LockFixture.empty().overrides,
      beforePump: (MadarDatabase db) => OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings()),
    );
    await tester.tap(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.label == _ar.orbitUiPanelExpand),
    );
    await settleApp(tester);

    final bar = find.byType(TextField).first;
    await tester.enterText(bar, line);
    await settleApp(tester);
    final open = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == _ar.dayChatOpenFromBar);
    expect(open, findsOneWidget, reason: 'one tap, right where he already types');
    await tester.tap(open);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(DayChatScreen), findsOneWidget);
    expect(app.router.state.uri.toString(), AppRoutes.dayChatOf(draft: line));
    // The same words, in the chat's box – not retyped, and not sent.
    final field = tester.widget<TextField>(find.byKey(const ValueKey('dayChat.input')));
    expect(field.controller?.text, line);
    expect(find.byType(DayChatPieceCard), findsNothing);
    expect(await app.repos.transactions.getAll(), isEmpty);
    await tester.pump(const Duration(seconds: 6));
  });
}
