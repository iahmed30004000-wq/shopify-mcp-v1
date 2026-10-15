// The second half of the Phase 9 system routes – «بياناتك» and its restore
// flow, the AI chat (a new one, the saved list, one saved chat), Settings ›
// AI, Settings › Home-screen widgets, and Together Mode with its Hall of
// Fame and three couple specials – build their screens in Arabic and
// English inside the full app (router, gates, adhan host, app lock), with
// the app's own transitions; their parameters reach the screens, back
// leaves each page, and the location helpers are exact.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/encryption.dart' show MemorySecretStore;
import 'package:madar/core/motion/transitions.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/ai_chat/ai_chat.dart'
    show AiChatListScreen, AiChatScreen, AiSettingsScreen, aiSecretStoreProvider, aiTransportProvider;
import 'package:madar/features/data/data.dart'
    show DataCentreScreen, RecordingDataFileBridge, RestoreFlow, dataFileBridgeProvider;
import 'package:madar/features/together/pairing/pairing.dart' show togetherSecretsProvider;
import 'package:madar/features/together/specials/specials.dart'
    show CoopGoalScreen, KnowMeScreen, WeeklyChallengeScreen;
import 'package:madar/features/together/together.dart' show HallOfFameScreen, TogetherHomeScreen;
import 'package:madar/features/widgets/widgets.dart' show WidgetsSettingsScreen;

import '../../features/ai_chat/ai_chat_fakes.dart' show FakeTransport;
import '../../features/lock/lock_test_utils.dart';
import '../../helpers/test_app.dart';

/// Nothing may reach a real socket, a real share sheet or the phone's
/// secure storage from a route test: a transport that records (and is never
/// asked), an in-memory vault and a recording file bridge.
List<Override> _systemOverrides(FakeTransport transport) => [
  aiTransportProvider.overrideWithValue(transport),
  aiSecretStoreProvider.overrideWithValue(MemorySecretStore()),
  togetherSecretsProvider.overrideWithValue(MemorySecretStore()),
  dataFileBridgeProvider.overrideWithValue(RecordingDataFileBridge()),
];

/// The notification centre's look timer never stops, so a full-app page is
/// pumped a fixed number of frames instead of settled.
Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('locations', () {
    test('the data centre, the AI chat, the settings pages and Together', () {
      expect(AppRoutes.dataCentre, '/settings/data');
      expect(AppRoutes.dataRestore, '/settings/data/restore');
      expect(AppRoutes.aiSettings, '/settings/ai');
      expect(AppRoutes.widgetsSettings, '/settings/widgets');
      expect(AppRoutes.ai, '/ai');
      expect(AppRoutes.aiChats, '/ai/chats');
      expect(AppRoutes.together, '/together');
      expect(AppRoutes.togetherHallOfFame, '/together/hall-of-fame');
      expect(AppRoutes.togetherKnowMe, '/together/know-me');
      expect(AppRoutes.togetherWeekly, '/together/weekly');
      expect(AppRoutes.togetherGoal, '/together/goal');
    });

    test('a question is encoded into the draft, and an empty one is the plain path', () {
      expect(AppRoutes.aiOf(), '/ai');
      expect(AppRoutes.aiOf(draft: ''), '/ai');
      expect(AppRoutes.aiOf(draft: '   '), '/ai');
      expect(
        AppRoutes.aiOf(draft: 'راجع ميزانيتي'),
        '/ai?q=%D8%B1%D8%A7%D8%AC%D8%B9+%D9%85%D9%8A%D8%B2%D8%A7%D9%86%D9%8A%D8%AA%D9%8A',
      );
    });

    test('a conversation id is escaped into its path', () {
      expect(AppRoutes.aiChatOf('c1'), '/ai/chat/c1');
      expect(AppRoutes.aiChatOf('a/b c'), '/ai/chat/a%2Fb%20c');
      expect(AppRoutes.aiChat, '/ai/chat/:id');
    });

    test('they need onboarding like every page', () {
      for (final loc in [
        AppRoutes.dataCentre,
        AppRoutes.dataRestore,
        AppRoutes.ai,
        AppRoutes.aiChats,
        AppRoutes.aiSettings,
        AppRoutes.widgetsSettings,
        AppRoutes.together,
        AppRoutes.togetherKnowMe,
      ]) {
        expect(onboardingRedirect(onboarded: false, location: loc), AppRoutes.onboarding, reason: loc);
        expect(onboardingRedirect(onboarded: true, location: loc), isNull, reason: loc);
      }
    });
  });

  final routes = <(String, Type)>[
    (AppRoutes.dataCentre, DataCentreScreen),
    (AppRoutes.dataRestore, RestoreFlow),
    (AppRoutes.aiSettings, AiSettingsScreen),
    (AppRoutes.widgetsSettings, WidgetsSettingsScreen),
    (AppRoutes.ai, AiChatScreen),
    (AppRoutes.aiOf(draft: 'راجع ميزانيتي'), AiChatScreen),
    (AppRoutes.aiChats, AiChatListScreen),
    (AppRoutes.aiChatOf('c1'), AiChatScreen),
    (AppRoutes.together, TogetherHomeScreen),
    (AppRoutes.togetherHallOfFame, HallOfFameScreen),
    (AppRoutes.togetherKnowMe, KnowMeScreen),
    (AppRoutes.togetherWeekly, WeeklyChallengeScreen),
    (AppRoutes.togetherGoal, CoopGoalScreen),
  ];

  for (final lang in ['ar', 'en']) {
    group(lang, () {
      for (final (location, type) in routes) {
        testWidgets('$location builds $type', (tester) async {
          final transport = FakeTransport();
          final app = await pumpMadarApp(
            tester,
            settings: AppSettings(onboarded: true, languageCode: lang),
            initialLocation: location,
            settle: false,
            overrides: [...LockFixture.empty().overrides, ..._systemOverrides(transport)],
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
          // Opening a page never sends anything to a service.
          expect(transport.requests, isEmpty);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 6));
        });
      }
    });
  }

  testWidgets('the parameters reach the screens', (tester) async {
    final transport = FakeTransport();
    final app = await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.aiOf(draft: 'راجع ميزانيتي'),
      settle: false,
      overrides: [...LockFixture.empty().overrides, ..._systemOverrides(transport)],
    );
    await _frames(tester);
    final draft = tester.widget<AiChatScreen>(find.byType(AiChatScreen));
    expect(draft.initialDraft, 'راجع ميزانيتي');
    expect(draft.conversationId, isNull);

    app.router.go(AppRoutes.aiChatOf('c1'));
    await _frames(tester);
    final saved = tester.widget<AiChatScreen>(find.byType(AiChatScreen));
    expect(saved.conversationId, 'c1');
    expect(saved.initialDraft, isNull);

    // A draft only fills the field: nothing is sent by arriving there.
    expect(transport.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the restore flow is a child of the data centre, so back returns to it', (tester) async {
    final transport = FakeTransport();
    final app = await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.dataRestore,
      settle: false,
      overrides: [...LockFixture.empty().overrides, ..._systemOverrides(transport)],
    );
    await _frames(tester);
    expect(find.byType(RestoreFlow), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _frames(tester);
    expect(find.byType(DataCentreScreen), findsOneWidget, reason: 'the data centre is underneath');
    expect(app.location, AppRoutes.dataCentre);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('battery saver stills Together\'s backdrop', (tester) async {
    final transport = FakeTransport();
    await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, powerMode: PowerMode.batterySaver),
      initialLocation: AppRoutes.together,
      settle: false,
      overrides: [...LockFixture.empty().overrides, ..._systemOverrides(transport)],
    );
    await _frames(tester);
    expect(tester.widget<TogetherHomeScreen>(find.byType(TogetherHomeScreen)).animateBackdrop, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
