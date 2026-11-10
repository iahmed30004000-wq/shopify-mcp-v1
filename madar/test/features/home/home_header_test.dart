// The home header's two new doors: search everything, and the bell with its
// unread badge. This is how the owner reaches both features at all, so it is
// checked in Arabic and English, with a badge, at 320 dp and 1.3× text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/notification_center/notification_center.dart';
import 'package:madar/features/search/search.dart';

import '../../helpers/test_app.dart';

/// Two notifications that arrived after the Recent tab was last seen.
Future<void> _twoUnread(MadarDatabase db) async {
  final store = NotificationCenterStore(Repositories(db).keyValues);
  CenterNotice notice(int id, DateTime at) => CenterNotice(
    id: id,
    namespace: NotificationNamespaces.adhkar.name,
    at: at.toUtc(),
    data: const {'set': 'morning'},
    title: 'أذكار',
    body: 'x',
  );
  await store.saveSeenAt(testNow.subtract(const Duration(hours: 3)));
  await store.saveHistory(
    NotificationHistory.empty.recordAll([
      HistoryEntry(
        notice: notice(110001, testNow.subtract(const Duration(hours: 2))),
        status: HistoryStatus.delivered,
        recordedAt: testNow.subtract(const Duration(hours: 2)),
      ),
      HistoryEntry(
        notice: notice(110002, testNow.subtract(const Duration(hours: 1))),
        status: HistoryStatus.delivered,
        recordedAt: testNow.subtract(const Duration(hours: 1)),
      ),
    ], now: testNow),
  );
}

void main() {
  for (final lang in ['ar', 'en']) {
    final l = lookupL10n(Locale(lang));

    testWidgets('$lang: the header opens the search, and back returns home', (tester) async {
      final app = await pumpMadarApp(tester, settings: AppSettings(onboarded: true, languageCode: lang));
      expect(find.bySemanticsLabel(l.searchLauncherTooltip), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(l.searchLauncherTooltip));
      await settleApp(tester);
      expect(app.location, AppRoutes.search);
      expect(find.byType(GlobalSearchScreen), findsOneWidget);
      expect(app.sound.played, isNotEmpty, reason: 'every action has its sound');

      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(app.location, AppRoutes.home);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('$lang: the bell shows the unread count and opens the centre', (tester) async {
      final app = await pumpMadarApp(
        tester,
        settings: AppSettings(onboarded: true, languageCode: lang),
        beforePump: _twoUnread,
      );
      expect(find.byType(NotificationBell), findsOneWidget);
      // The badge, in the language's digits.
      final two = MadarFormatter(languageCode: lang).formatInt(2);
      expect(
        find.descendant(of: find.byType(NotificationBell), matching: find.text(two)),
        findsOneWidget,
        reason: 'the badge must say how many are new',
      );
      // TalkBack says what it is and how many.
      expect(find.bySemanticsLabel(CenterTexts.forLanguage(lang).digits(l.ncBellLabel(2))), findsOneWidget);

      await tester.tap(find.byType(NotificationBell));
      await settleApp(tester);
      expect(app.location, AppRoutes.notifications);
      expect(find.byType(NotificationCenterScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(app.location, AppRoutes.home);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('$lang: both are 48 dp and fit a 320 dp phone at 1.3× text', (tester) async {
      tester.view.physicalSize = const Size(320, 640) * 3;
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpMadarApp(
        tester,
        phone: false,
        settings: AppSettings(onboarded: true, languageCode: lang),
        beforePump: _twoUnread,
      );
      expect(tester.takeException(), isNull);
      for (final finder in [find.bySemanticsLabel(l.searchLauncherTooltip), find.byType(NotificationBell)]) {
        final size = tester.getSize(finder.first);
        expect(size.width, greaterThanOrEqualTo(44), reason: 'tap target: $size');
        expect(size.height, greaterThanOrEqualTo(44), reason: 'tap target: $size');
      }
      await tester.pump(const Duration(seconds: 6));
    });
  }
}
