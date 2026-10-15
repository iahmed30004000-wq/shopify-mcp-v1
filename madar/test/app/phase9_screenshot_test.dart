// Art-direction matrix of the two system entries inside the real app
// (router, AppGate, app lock, real fonts and shaders): the home header with
// its search button and the bell's unread badge, the global search with a
// query and its results, and the notification centre on both tabs – in
// Arabic and English, across Lapis, Pearl and Aurora, plus text scale 1.3
// (a layout overflow fails the test). Writes PNGs to
// madar/screenshots/phase9/.
//
//   TZ=Asia/Amman flutter test --tags screenshot test/app/phase9_screenshot_test.dart
@Tags(['screenshot'])
@Timeout(Duration(minutes: 60))
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/notification_center/notification_center.dart';
import 'package:madar/features/search/search.dart' show InlineSearchWorker, searchDebounceProvider, searchWorkerFactoryProvider;

import '../features/lock/lock_test_utils.dart';
import '../features/orbit/presentation/orbit_scene_fixtures.dart' show preloadOrbitShaders;
import '../helpers/screenshot_harness.dart';
import '../helpers/test_app.dart';

const _dir = 'phase9';

/// Sunday 27 Sep 2026, 13:10 – the app's own test "now".
final DateTime _now = testNow;

/// A lived-in phone: records to find, and notifications that arrived while
/// he was away.
Future<void> _seed(MadarDatabase db, {required bool arabic}) async {
  String tr(String ar, String en) => arabic ? ar : en;
  final repos = Repositories(db);
  final today = DateTime(_now.year, _now.month, _now.day);
  await repos.tasks.insert(
    TasksCompanion.insert(
      title: tr('شراء دواء الضغط من الصيدلية', 'Buy the blood pressure medicine'),
      window: const Value(PrayerWindow.dhuhr),
      date: Value(today),
      notes: Value(tr('الصيدلية قرب المسجد', 'The pharmacy by the mosque')),
      planetKey: const Value('health'),
    ),
  );
  await repos.tasks.insert(
    TasksCompanion.insert(
      title: tr('متابعة فاتورة الدواء مع التأمين', 'Follow up the medicine invoice with insurance'),
      date: Value(today.add(const Duration(days: 1))),
      planetKey: const Value('money'),
    ),
  );
  await repos.people.insert(
    PeopleCompanion.insert(name: tr('أمي', 'Mum'), relation: const Value('mother'), phone: Value(tr('٠٧٩', '079'))),
  );
  await repos.medications.insert(
    MedicationsCompanion.insert(
      name: tr('دواء الضغط', 'Blood pressure tablet'),
      dose: const Value('10 mg'),
      times: const Value(['08:00']),
    ),
  );

  // What arrived this morning, and one group he muted.
  final store = NotificationCenterStore(repos.keyValues);
  CenterNotice notice(int id, DateTime at, String namespace, Map<String, Object?> data, String title, String body) =>
      CenterNotice(id: id, namespace: namespace, at: at.toUtc(), data: data, title: title, body: body);
  await store.saveSeenAt(_now.subtract(const Duration(hours: 9)));
  await store.saveHistory(
    NotificationHistory.empty.recordAll([
      HistoryEntry(
        notice: notice(
          110001,
          today.add(const Duration(hours: 5, minutes: 2)),
          NotificationNamespaces.adhkar.name,
          const {'set': 'morning'},
          tr('أذكار الصباح', 'Morning adhkar'),
          tr('ابدأ يومك بذكر الله', 'Begin your day with remembrance'),
        ),
        status: HistoryStatus.opened,
        recordedAt: today.add(const Duration(hours: 5, minutes: 4)),
      ),
      HistoryEntry(
        notice: notice(
          120011,
          today.add(const Duration(hours: 8)),
          NotificationNamespaces.meds.name,
          const {'k': 'dose', 'm': 'm1', 's': 0, 'l': 'ar'},
          tr('حان موعد دواء الضغط', 'Time for the blood pressure tablet'),
          tr('١٠ مغ · مع الفطور', '10 mg · with breakfast'),
        ),
        status: HistoryStatus.delivered,
        recordedAt: today.add(const Duration(hours: 8)),
      ),
      HistoryEntry(
        notice: notice(
          100003,
          today.add(const Duration(hours: 11, minutes: 36)),
          NotificationNamespaces.adhan.name,
          const {'kind': 'adhan', 'slot': 'dhuhr'},
          tr('أذان الظهر', 'Dhuhr adhan'),
          tr('حيّ على الصلاة', 'Time to pray'),
        ),
        status: HistoryStatus.delivered,
        recordedAt: today.add(const Duration(hours: 11, minutes: 36)),
      ),
    ], now: _now),
  );
  await store.savePolicy(
    CenterPolicy.empty.mute(NotificationGroup.family, today.add(const Duration(days: 1, hours: 7))),
  );
}

/// What is still to come, as the features would have armed it: the next
/// adhan, tonight's dose, a document that expires this week.
Future<FakeNotificationPlatform> _upcoming({required bool arabic}) async {
  String tr(String ar, String en) => arabic ? ar : en;
  final platform = FakeNotificationPlatform();
  final today = DateTime(_now.year, _now.month, _now.day);
  final requests = [
    NotificationRequest(
      namespace: NotificationNamespaces.adhan,
      id: 100010,
      channelId: 'madar.adhan.call',
      title: tr('أذان العصر', 'Asr adhan'),
      body: tr('حيّ على الصلاة', 'Time to pray'),
      at: today.add(const Duration(hours: 16, minutes: 22)),
      data: const {'kind': 'adhan', 'slot': 'asr'},
    ),
    NotificationRequest(
      namespace: NotificationNamespaces.meds,
      id: 120042,
      channelId: 'madar.meds.doses',
      title: tr('حان موعد دواء الضغط', 'Time for the blood pressure tablet'),
      body: tr('١٠ مغ · مع العشاء', '10 mg · with dinner'),
      at: today.add(const Duration(hours: 20)),
      data: const {'k': 'dose', 'm': 'm1', 's': 0, 'l': 'ar'},
    ),
    NotificationRequest(
      namespace: NotificationNamespaces.adhkar,
      id: 110020,
      channelId: 'madar.adhkar',
      title: tr('أذكار المساء', 'Evening adhkar'),
      body: tr('بعد العصر بعشرين دقيقة', 'Twenty minutes after Asr'),
      at: today.add(const Duration(hours: 16, minutes: 42)),
      data: const {'set': 'evening'},
    ),
    NotificationRequest(
      namespace: NotificationNamespaces.reminders,
      id: 138010,
      channelId: 'madar.reminders',
      title: tr('جواز السفر يقارب الانتهاء', 'The passport is near its expiry'),
      body: tr('باقي ٣٠ يومًا', '30 days left'),
      at: today.add(const Duration(days: 2, hours: 9)),
      data: const {'feature': 'travel', 'documentId': 'doc1'},
    ),
  ];
  for (final r in requests) {
    await platform.schedule(r, NotificationEnvelope.encode(r), timing: r.timing);
  }
  return platform;
}

Future<void> _frames(WidgetTester tester, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

typedef _Screen = ({String name, String start, Future<void> Function(WidgetTester tester)? before});

final List<_Screen> _screens = [
  // The way in: the header's search button and the bell with its badge.
  (name: 'home_header', start: AppRoutes.home, before: null),
  (
    name: 'search_results',
    start: AppRoutes.search,
    before: (tester) async {
      await tester.enterText(find.byType(TextField).first, 'دواء');
      await _frames(tester, 20);
    },
  ),
  (name: 'search_empty', start: AppRoutes.search, before: null),
  (name: 'centre_upcoming', start: AppRoutes.notificationsOf(tab: 'upcoming'), before: null),
  (name: 'centre_recent', start: AppRoutes.notificationsOf(tab: 'recent'), before: null),
  (name: 'centre_groups', start: AppRoutes.notificationSettings, before: null),
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
    notifications: await _upcoming(arabic: lang == 'ar'),
    beforePump: (db) => _seed(db, arabic: lang == 'ar'),
    overrides: [
      ...LockFixture.empty().overrides,
      // The index inline, so the results are on the picture (the real
      // worker builds on an isolate that never finishes under the binding).
      searchWorkerFactoryProvider.overrideWithValue(() async => InlineSearchWorker()),
      searchDebounceProvider.overrideWithValue(const Duration(milliseconds: 10)),
    ],
  );
  final suffix = textScale == 1 ? '' : '_x${(textScale * 10).round()}';
  await captureScreen(
    tester,
    setup.app,
    '$_dir/${screen.name}_${lang}_${theme.name}$suffix',
    settle: const Duration(milliseconds: 1200),
    beforeCapture: (tester) async {
      await _frames(tester, 10);
      await screen.before?.call(tester);
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
