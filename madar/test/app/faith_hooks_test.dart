// The Phase 3 features wired together in the full app (router, gates, app
// lock, the real providers over the harness's platform fakes):
// * the Quran reader's "Add to Hifz" adds through Hifz's import, with undo;
// * the wird's "read now" opens the reader route where the plan stands;
// * a wird reminder tap opens its plan; a tap on the recitation's media
//   notification opens the full player (only while reciting);
// * recitation downloads open as a route;
// * Hifz's "listen" plays through the app's recitation player.
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_audio.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/hifz/hifz.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/presentation/planet/faith_hub.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/quran/presentation/widgets/verse_list.dart' show VerseCard;
import 'package:madar/features/quran/quran.dart';
import 'package:madar/features/recitation/recitation.dart';
import 'package:madar/features/wird/wird.dart';

import '../features/lock/lock_test_utils.dart';
import '../features/orbit/presentation/orbit_scene_fixtures.dart' show hostPrayerSettings;
import '../helpers/test_app.dart';

final _en = lookupL10n(const Locale('en'));
const _english = AppSettings(onboarded: true, languageCode: 'en');

Future<void> _frames(WidgetTester tester, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lets database writes started by a tap land (outside the fake clock).
Future<void> _writes(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The reader shows one sura as a list of ayah cards.
Future<void> _listMode(MadarDatabase db) =>
    QuranPrefsStore(Repositories(db).keyValues).updatePrefs((p) => p.copyWith(mode: QuranReaderMode.list));

Future<List<HifzCard>> _cards(WidgetTester tester, TestApp app) async =>
    (await tester.runAsync(() => app.container.read(hifzServiceProvider).watchCards().first))!;

/// A two-pages-a-day wird from al-Baqarah after Asr; returns its id.
Future<String> _seedWird(MadarDatabase db) async {
  await OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings());
  final (plan, _) = await WirdService(Repositories(db), clock: () => testNow).create(
    WirdDraft(
      name: 'Baqarah',
      template: WirdTemplate.pages,
      start: const AyahRef(2, 1),
      startDate: DateTime(2026, 9, 27),
      window: PrayerWindow.asr,
    ),
  );
  return plan.id;
}

RawNotificationTap _wirdTap(String planId) {
  final id = NotificationNamespaces.wird.first;
  return RawNotificationTap(
    id: id,
    fromLaunch: false,
    payload: NotificationEnvelope.encode(
      NotificationRequest(
        namespace: NotificationNamespaces.wird,
        id: id,
        channelId: 'madar.wird.reminder.1',
        title: 'Wird',
        body: '',
        at: testNow,
        data: {'plan': planId},
      ),
    ),
  );
}

void main() {
  testWidgets('the reader adds an ayah to Hifz with undo; again, it is already there', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      initialLocation: AppRoutes.quranReaderOf(ayah: const AyahRef(112, 1)),
      beforePump: _listMode,
      overrides: LockFixture.empty().overrides,
    );
    Future<void> addFirstAyah() async {
      await tester.tap(find.byType(VerseCard).first);
      await settleApp(tester);
      expect(find.text(_en.quranActionHifz), findsOneWidget);
      app.sound.played.clear();
      await tester.tap(find.text(_en.quranActionHifz));
      await _writes(tester);
    }

    await addFirstAyah();
    var cards = await _cards(tester, app);
    expect(cards, hasLength(1));
    expect(cards.single.range, const AyahRange.single(AyahRef(112, 1)));
    expect(app.sound.played, contains(Sfx.complete));
    // The undo toast (not the reader's plain "added" toast).
    expect(find.text(_en.hifzAdded(1)), findsOneWidget);
    expect(find.text(_en.quranHifzAdded), findsNothing);
    await tester.tap(find.text(_en.actionUndo));
    await _writes(tester);
    expect(await _cards(tester, app), isEmpty);
    await tester.pump(const Duration(seconds: 6));

    await addFirstAyah();
    expect(await _cards(tester, app), hasLength(1));
    await tester.pump(const Duration(seconds: 6));
    await addFirstAyah();
    cards = await _cards(tester, app);
    expect(cards, hasLength(1), reason: 'the chunk is already there');
    expect(find.text(_en.faithHubHifzAlready), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets("the wird's read now opens the reader where the plan stands; all plans the wird page", (tester) async {
    String? planId;
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      initialLocation: AppRoutes.planetOf('faith'),
      beforePump: (db) async => planId = await _seedWird(db),
      overrides: LockFixture.empty().overrides,
      settle: false,
    );
    await _frames(tester, 40);
    await settleApp(tester);
    final scrollable = find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byType(WirdTodayCard), 250, scrollable: scrollable);
    await tester.ensureVisible(find.byType(WirdTodayCard));
    await tester.pumpAndSettle();
    app.sound.played.clear();
    await tester.tap(find.bySemanticsLabel(_en.wirdReadNow));
    await settleApp(tester);
    expect(find.byType(QuranReaderScreen), findsOneWidget);
    expect(app.router.state.uri.toString(), AppRoutes.quranReaderOf(ayah: const AyahRef(2, 1)));
    expect(tester.widget<QuranReaderScreen>(find.byType(QuranReaderScreen)).start, const AyahRef(2, 1));
    expect(app.sound.played, contains(Sfx.navigate));
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(find.byType(FaithHub), findsOneWidget);

    await tester.tap(find.text(_en.wirdOpenAll));
    await settleApp(tester);
    expect(find.byType(WirdScreen), findsOneWidget);
    expect(app.location, AppRoutes.wird);
    expect(planId, isNotNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a wird reminder tap opens the wird page on its plan', (tester) async {
    String? planId;
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      beforePump: (db) async => planId = await _seedWird(db),
      overrides: LockFixture.empty().overrides,
    );
    app.notifications.tap(_wirdTap(planId!));
    await settleApp(tester);
    expect(app.router.state.uri.toString(), AppRoutes.wirdOf(planId));
    expect(tester.widget<WirdScreen>(find.byType(WirdScreen)).initialPlanId, planId);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the media notification opens the full player – only while reciting', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.quran, overrides: LockFixture.empty().overrides);
    app.faith.recitationClicks.add(true);
    await settleApp(tester);
    expect(app.location, AppRoutes.quran, reason: 'nothing plays');

    unawaited(app.container.read(quranAudioProvider).play(const AyahRange(AyahRef(1, 1), AyahRef(1, 7))));
    await _frames(tester);
    app.faith.recitationClicks.add(true);
    await _frames(tester);
    expect(app.location, AppRoutes.nowPlaying);
    expect(find.byType(NowPlayingSheet), findsOneWidget);
    // A second click while it shows changes nothing.
    app.faith.recitationClicks.add(true);
    await _frames(tester);
    expect(find.byType(NowPlayingSheet), findsOneWidget);
    await app.container.read(quranAudioProvider).stop();
    await _frames(tester, 20);
    expect(find.byType(NowPlayingSheet), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('recitation downloads open as a route', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      initialLocation: AppRoutes.recitationSettings,
      overrides: LockFixture.empty().overrides,
    );
    await tester.scrollUntilVisible(
      find.text(_en.recitationChooseSurahs),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    app.sound.played.clear();
    await tester.tap(find.text(_en.recitationChooseSurahs));
    await settleApp(tester);
    expect(find.byType(RecitationDownloadsScreen), findsOneWidget);
    expect(app.router.state.uri.toString(), AppRoutes.recitationDownloadsOf(Reciters.fallback.id));
    expect(app.sound.played, contains(Sfx.navigate));
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.recitationSettings);
  });

  testWidgets("Hifz's listen plays the item's ayat through the app's recitation player", (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      initialLocation: AppRoutes.hifzReview,
      beforePump: (db) => Repositories(db).hifzItems.insert(
        HifzItemsCompanion.insert(
          kind: const Value(HifzKind.ayat),
          surah: const Value(112),
          ayahFrom: const Value(1),
          ayahTo: const Value(4),
        ),
      ),
      overrides: LockFixture.empty().overrides,
    );
    final listen = find.textContaining(_en.hifzListen);
    await tester.ensureVisible(listen.first);
    await tester.pumpAndSettle();
    await tester.tap(listen.first);
    await _frames(tester);
    final engine = app.faith.engine;
    expect(engine.playing, isTrue);
    final files = engine.sources.map((s) => s.uri.toString()).toList();
    expect(files, contains(endsWith('/112001.mp3')));
    expect(files.where((f) => f.endsWith('/112001.mp3')).length, greaterThan(1), reason: 'repeated');
    final playback = app.container.read(quranAudioProvider).value;
    expect(playback.range, const AyahRange(AyahRef(112, 1), AyahRef(112, 4)));
    await app.container.read(quranAudioProvider).stop();
    await _frames(tester);
    await tester.pump(const Duration(seconds: 6));
  });
}
