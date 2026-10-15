// Art-direction matrix of the second half of the system shell inside the
// real app (router, AppGate, app lock, real fonts and shaders): the new
// Settings rows (notifications, widgets, Together, AI and «بياناتك»), the
// data centre, Settings › AI, Settings › Home-screen widgets and Together
// Mode – in Arabic and English, across Lapis, Pearl and Aurora, plus text
// scale 1.3 (a layout overflow fails the test). Writes PNGs to
// madar/screenshots/phase9b/.
//
//   TZ=Asia/Amman flutter test --tags screenshot test/app/phase9b_screenshot_test.dart
@Tags(['screenshot'])
@Timeout(Duration(minutes: 60))
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/encryption.dart' show MemorySecretStore;
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/ai_chat/ai_chat.dart'
    show AiKeyStore, AiProviderId, aiSecretStoreProvider, aiTransportProvider;
import 'package:madar/features/data/data.dart' show RecordingDataFileBridge, dataFileBridgeProvider, lastBackupKey;
import 'package:madar/features/together/pairing/pairing.dart' show togetherSecretsProvider;
import 'package:madar/features/together/together.dart'
    show MatchOutcome, MatchRecord, TogetherRepository, togetherClockProvider;

import '../features/ai_chat/ai_chat_fakes.dart' show FakeTransport;
import '../features/lock/lock_test_utils.dart';
import '../features/orbit/presentation/orbit_scene_fixtures.dart' show preloadOrbitShaders;
import '../helpers/screenshot_harness.dart';
import '../helpers/test_app.dart';

const _dir = 'phase9b';

final DateTime _now = testNow;

/// A lived-in phone: food he logged, two players with a history, and a
/// backup he made last week.
Future<void> _seed(MadarDatabase db, {required bool arabic}) async {
  String tr(String ar, String en) => arabic ? ar : en;
  final repos = Repositories(db);
  await repos.foods.insert(
    FoodsCompanion.insert(
      id: const Value('f1'),
      name: tr('مقلوبة', 'Maqlouba'),
      tags: Value([tr('نشويات', 'starchy'), tr('مقلي', 'fried')]),
      defaultPortion: const Value(1.5),
      unit: Value(tr('طبق', 'plate')),
    ),
  );
  await repos.foodLogs.insert(
    FoodLogsCompanion.insert(
      foodId: const Value('f1'),
      name: tr('مقلوبة', 'Maqlouba'),
      at: _now.subtract(const Duration(hours: 2)),
      portion: const Value(1),
      unit: Value(tr('طبق', 'plate')),
    ),
  );
  await repos.tasks.insert(
    TasksCompanion.insert(
      title: tr('شراء دواء الضغط من الصيدلية', 'Buy the blood pressure medicine'),
      window: const Value(PrayerWindow.dhuhr),
      date: Value(DateTime(_now.year, _now.month, _now.day)),
      isTop3: const Value(true),
      planetKey: const Value('health'),
    ),
  );
  await repos.medications.insert(
    MedicationsCompanion.insert(
      name: tr('دواء الضغط', 'Blood pressure tablet'),
      dose: const Value('10 mg'),
      times: const Value(['08:00']),
    ),
  );
  // His last backup, so «بياناتك» shows a date instead of "no backup yet".
  await repos.keyValues.setJson(lastBackupKey, _now.subtract(const Duration(days: 6)).toUtc().toIso8601String());
  // Two games played together, so the head-to-head is not empty.
  final together = TogetherRepository(db);
  await together.recordMatch(
    MatchRecord(
      id: 'm1',
      gameId: 'fourInARow',
      endedAt: _now.subtract(const Duration(days: 1)),
      outcome: MatchOutcome.oneWon,
    ),
  );
  await together.recordMatch(
    MatchRecord(
      id: 'm2',
      gameId: 'fourInARow',
      endedAt: _now.subtract(const Duration(hours: 5)),
      outcome: MatchOutcome.draw,
    ),
  );
}

List<Override> _overrides() => [
  ...LockFixture.empty().overrides,
  aiTransportProvider.overrideWithValue(FakeTransport()),
  // A key is saved, so Settings › AI shows the real "key saved" state –
  // only its last four characters ever appear.
  aiSecretStoreProvider.overrideWithValue(
    MemorySecretStore({AiKeyStore.storageKey(AiProviderId.anthropic): 'sk-ant-${'x' * 36}9f4d'}),
  ),
  togetherSecretsProvider.overrideWithValue(MemorySecretStore()),
  dataFileBridgeProvider.overrideWithValue(RecordingDataFileBridge()),
  togetherClockProvider.overrideWithValue(() => _now),
];

Future<void> _frames(WidgetTester tester, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Scrolls the page so [text] is in the middle of the picture.
Future<void> _scrollTo(WidgetTester tester, String text) async {
  final row = find.text(text);
  await tester.scrollUntilVisible(row.first, 200, scrollable: find.byType(Scrollable).first);
  await _frames(tester, 6);
  await Scrollable.ensureVisible(tester.element(row.last), alignment: 0.5);
  await _frames(tester, 6);
}

typedef _Screen = ({String name, String start, Future<void> Function(WidgetTester tester, L10n l)? before});

final List<_Screen> _screens = [
  // The way in: the four new Settings groups, and «بياناتك» below them.
  (
    name: 'settings_system',
    start: AppRoutes.settings,
    before: (tester, l) => _scrollTo(tester, l.systemShellNotificationCenterRow),
  ),
  (name: 'settings_data', start: AppRoutes.settings, before: (tester, l) => _scrollTo(tester, l.systemShellDataRow)),
  (name: 'data_centre', start: AppRoutes.dataCentre, before: null),
  (name: 'restore', start: AppRoutes.dataRestore, before: null),
  (name: 'ai_settings', start: AppRoutes.aiSettings, before: null),
  (name: 'ai_chat', start: AppRoutes.ai, before: null),
  (name: 'widgets_settings', start: AppRoutes.widgetsSettings, before: null),
  (name: 'together', start: AppRoutes.together, before: null),
];

Future<void> _shot(
  WidgetTester tester,
  _Screen screen, {
  required String lang,
  required MadarThemeId theme,
  double textScale = 1,
}) async {
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await preloadOrbitShaders(tester);
  final setup = await buildMadarTestApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
    initialLocation: screen.start,
    now: _now,
    beforePump: (db) => _seed(db, arabic: lang == 'ar'),
    overrides: _overrides(),
  );
  final suffix = textScale == 1 ? '' : '_x${(textScale * 10).round()}';
  await captureScreen(
    tester,
    setup.app,
    '$_dir/${screen.name}_${lang}_${theme.name}$suffix',
    settle: const Duration(milliseconds: 1200),
    beforeCapture: (tester) async {
      await _frames(tester, 10);
      await screen.before?.call(tester, lookupL10n(Locale(lang)));
      await _frames(tester, 10);
      expect(tester.takeException(), isNull);
    },
    trailingFrames: 6,
  );
}

void main() {
  const themes = [MadarThemeId.lapis, MadarThemeId.pearl, MadarThemeId.aurora];
  for (final s in _screens) {
    for (final lang in ['ar', 'en']) {
      for (final theme in themes) {
        testWidgets('${s.name} $lang ${theme.name}', (tester) async {
          await _shot(tester, s, lang: lang, theme: theme);
        });
      }
      testWidgets('${s.name} $lang text x1.3', (tester) async {
        await _shot(
          tester,
          s,
          lang: lang,
          theme: lang == 'ar' ? MadarThemeId.lapis : MadarThemeId.pearl,
          textScale: 1.3,
        );
      });
    }
  }
}
