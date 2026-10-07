// Probe (Life integration, notification deep links and routes):
// * a fasting notice opens the FASTING tab, a document reminder the
//   DOCUMENTS tab – also when the user is already on that page's link but
//   had switched to another tab (e.g. Body › Fasting from the planet, then
//   Water, then "fasting goal reached" is tapped);
// * a packing-template link to a template that no longer exists (the route
//   search results use, C1) ends in a page, not an endless loader.
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/widgets/orbit_loader.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/body/body.dart';
import 'package:madar/features/travel/travel.dart';

import '../features/lock/lock_test_utils.dart';
import '../helpers/test_app.dart';

final DateTime _now = DateTime(2026, 9, 29, 7, 30);
const _english = AppSettings(onboarded: true, languageCode: 'en');

RawNotificationTap _tap(int id, Map<String, Object?> data) => RawNotificationTap(
  id: id,
  payload: NotificationEnvelope.encode(
    NotificationRequest(
      namespace: NotificationNamespaces.reminders,
      id: id,
      channelId: 'x',
      title: 't',
      body: '',
      at: _now,
      data: data,
    ),
  ),
);

RawNotificationTap _fasting() =>
    _tap(BodyReminderIds.goal, {'kind': NotificationBodyReminderScheduler.kind, 'notice': 'goal'});
RawNotificationTap _document() => _tap(TravelReminderIds.idFor(0, DocumentReminderKind.values.first), {
  'feature': 'travel',
  'documentId': 'd1',
  'kind': DocumentReminderKind.values.first.name,
});

void main() {
  testWidgets('a fasting notice shows the fasting tab even if the user moved to another tab', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      now: _now,
      initialLocation: AppRoutes.bodyOf(tab: BodyTab.fasting.name),
      overrides: LockFixture.empty().overrides,
    );
    BodyTabBar<BodyTab> bar() => tester.widget<BodyTabBar<BodyTab>>(find.byType(BodyTabBar<BodyTab>));
    expect(bar().value, BodyTab.fasting);
    bar().onChanged(BodyTab.water);
    await settleApp(tester);
    expect(bar().value, BodyTab.water);

    app.notifications.tap(_fasting());
    await settleApp(tester);
    final location = app.router.state.uri.toString();
    final tab = bar().value;
    // Take the app down and let its timers run out before checking (the
    // runner otherwise stalls after a failed check).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    expect(location, '/body?tab=fasting');
    expect(tab, BodyTab.fasting, reason: 'the tapped fasting notice left the user on the water tab');
  });

  testWidgets('a document reminder shows the documents tab even if the user moved to another tab', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      now: _now,
      initialLocation: AppRoutes.travelOf(tab: TravelTab.documents.name),
      overrides: LockFixture.empty().overrides,
    );
    TravelTabBar<TravelTab> bar() => tester.widget<TravelTabBar<TravelTab>>(find.byType(TravelTabBar<TravelTab>));
    expect(bar().value, TravelTab.documents);
    bar().onChanged(TravelTab.trips);
    await settleApp(tester);
    expect(bar().value, TravelTab.trips);

    app.notifications.tap(_document());
    await settleApp(tester);
    final location = app.router.state.uri.toString();
    final tab = bar().value;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    expect(location, '/travel?tab=documents');
    expect(tab, TravelTab.documents, reason: 'the tapped document reminder left the user on the trips tab');
  });

  testWidgets('a link to a packing template that is gone does not load forever', (tester) async {
    // settle: false – pumpAndSettle never returns while the loader spins.
    final app = await pumpMadarApp(
      tester,
      settings: _english,
      now: _now,
      initialLocation: AppRoutes.travelTemplateOf('gone'),
      overrides: LockFixture.empty().overrides,
      settle: false,
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 500));
    }
    final location = app.router.state.uri.toString();
    final screens = find.byType(PackingTemplateScreen).evaluate().length;
    final spinning = find.byType(OrbitLoader).evaluate().isNotEmpty;
    // Take the endless loader down before the checks (it never settles).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    expect(location, '/travel/template/gone');
    expect(screens, 1);
    expect(spinning, isFalse, reason: 'still spinning after 5 s for a deleted template');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
